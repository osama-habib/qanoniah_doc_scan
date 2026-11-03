import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qanoniah_doc_scan/qanoniah_doc_scan.dart';
import 'package:qanoniah_doc_scan/src/capture/data/camera_source.dart';
import 'package:qanoniah_doc_scan/src/capture/data/edge_detector.dart';
import 'package:qanoniah_doc_scan/src/core/doc_scan.dart';
import 'package:qanoniah_doc_scan/src/core/failures.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session_repo.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/text_recognizer.dart';

import '../fakes/fake_edge_detector.dart';
import '../helpers/test_host.dart';

/// A camera whose stills are real JPEGs, so the real PDF builder can read them.
class JpegCamera implements CameraSource {
  JpegCamera(this.dir);
  final Directory dir;
  int shots = 0;

  @override
  Future<Either<CameraFailure, Unit>> initialize() async => const Right<CameraFailure, Unit>(unit);
  @override
  Widget preview() => const SizedBox.expand();
  @override
  Stream<CameraFrame> get frames => const Stream<CameraFrame>.empty();
  @override
  Future<Either<CameraFailure, File>> takePicture() async {
    final File f = File('${dir.path}/shot${shots++}.jpg')
      ..writeAsBytesSync(img.encodeJpg(img.Image(width: 120, height: 160)));
    return Right<CameraFailure, File>(f);
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> dispose() async {}
}

class WordsRecognizer implements TextRecognizer {
  @override
  Future<Either<RecognitionFailure, RawRecognition>> recognize(File image, RecognitionLanguage language) async =>
      Right<RecognitionFailure, RawRecognition>(
        RawRecognition(blocksAreParagraphs: false, blocks: <List<Word>>[
          <Word>[Word(text: 'حكم', box: const Rect.fromLTWH(10, 10, 40, 20), confidence: 0.95)],
        ]),
      );
}

void main() {
  late Directory tmp;
  late Directory shots;
  final List<DocScanEvent> events = <DocScanEvent>[];

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('flow');
    shots = await Directory('${tmp.path}/shots').create();
    events.clear();
    DocScan.debugDeps = () => ScanFlowDeps(
      sessions: ScanSessionRepo(tempRoot: () async => tmp),
      recognizer: WordsRecognizer(),
      newCamera: () => JpegCamera(shots),
      newEdgeDetector: () => FakeEdgeDetector(const FrameAnalysis(quad: null, sharpness: 0, luminance: 0)),
      permissions: FakePermissionRepo(),
      preparer: FakePagePreparer(),
    );
  });

  tearDown(() async {
    DocScan.debugDeps = null;
    await tmp.delete(recursive: true);
  });

  DocScanConfig config() => DocScanConfig(
    pdfFont: File('example/assets/fonts/NotoSansArabic-Regular.ttf').readAsBytesSync(),
    pdfFontFallback: File('example/assets/fonts/NotoSans-Regular.ttf').readAsBytesSync(),
    onEvent: events.add,
  );

  Future<void> settle(WidgetTester t, Finder f, {int tries = 100}) async {
    for (int i = 0; i < tries && f.evaluate().isEmpty; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(f, findsWidgets);
  }

  List<String> sessionDirs() => tmp
      .listSync(recursive: true)
      .whereType<Directory>()
      .where((Directory d) => d.parent.path.endsWith('qanoniah_doc_scan') && !d.path.endsWith('/out'))
      .map((Directory d) => d.path)
      .toList();

  Widget host(void Function(Future<DocScanResult?>) onResult) => testApp(
    Builder(
      builder: (BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(onPressed: () => onResult(DocScan.start(context, config())), child: const Text('scan')),
        ),
      ),
    ),
  );

  /// Shutter, then «حفظ الصفحة» on the corner step.
  Future<void> capturePage(WidgetTester t) async {
    await t.tap(find.bySemanticsLabel('التقاط'));
    await settle(t, find.text('حفظ الصفحة'));
    await t.tap(find.text('حفظ الصفحة'));
    await settle(t, find.text('حفظ (1)'));
  }

  testWidgets('capture, review, build, preview, attach returns one PDF and cleans up', (WidgetTester t) async {
    late Future<DocScanResult?> result;
    await t.pumpWidget(host((Future<DocScanResult?> f) => result = f));
    await t.tap(find.text('scan'));
    await settle(t, find.bySemanticsLabel('التقاط'));
    await capturePage(t);
    await t.tap(find.text('حفظ (1)'));
    // The camera hands over to «توضيح الصفحات»; «التالي» goes to review.
    await settle(t, find.text('توضيح الصفحات'));
    expect(find.text('صفحة 1 / 1'), findsOneWidget);
    await t.tap(find.text('التالي'));
    await settle(t, find.bySemanticsLabel('إنشاء مستند قابل للتعديل'));
    expect(find.bySemanticsLabel('إرفاق كملف PDF'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('إنشاء مستند قابل للتعديل'));
    await settle(t, find.bySemanticsLabel('معاينة ملف PDF'), tries: 200);
    expect(find.text('حكم'), findsWidgets);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('إرفاق كملف PDF').last);
    DocScanResult? r;
    for (int i = 0; i < 100 && r == null; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump();
      unawaited(result.then((DocScanResult? v) => r = v));
    }
    expect(r, isNotNull);
    expect(r!.pageCount, 1);
    expect(r!.form, DocScanPdfForm.image);
    expect(r!.fileName, 'مستند-ممسوح-01.pdf');
    expect(r!.pageTexts.single, 'حكم');
    expect(r!.pdf.existsSync(), isTrue);
    expect(sessionDirs(), isEmpty);
    expect(events.map((DocScanEvent e) => e.name), containsAllInOrder(<String>[
      'scan_started', 'scan_page_captured', 'scan_review_opened', 'scan_build_started',
      'scan_build_completed', 'scan_preview_opened', 'scan_attached',
    ]));
  });

  testWidgets('cancel returns null and leaves no files; a second start throws', (WidgetTester t) async {
    late Future<DocScanResult?> result;
    late BuildContext ctx;
    await t.pumpWidget(host((Future<DocScanResult?> f) => result = f));
    ctx = t.element(find.text('scan'));
    await t.tap(find.text('scan'));
    await settle(t, find.bySemanticsLabel('التقاط'));
    expect(() => DocScan.start(ctx, config()), throwsStateError);
    await t.tap(find.text('إلغاء'));
    await settle(t, find.text('scan'));
    final DocScanResult? r = await t.runAsync<DocScanResult?>(() => result);
    expect(r, isNull);
    expect(sessionDirs(), isEmpty);
    expect(events.last.name, 'scan_cancelled');
  });

  testWidgets('camera cancel with captured pages opens review and keeps them', (WidgetTester t) async {
    late Future<DocScanResult?> result;
    await t.pumpWidget(host((Future<DocScanResult?> f) => result = f));
    await t.tap(find.text('scan'));
    await settle(t, find.bySemanticsLabel('التقاط'));
    await capturePage(t);
    await t.tap(find.text('إلغاء'));
    await settle(t, find.text('اسحب الصفحة لتغيير ترتيبها في الملف.'));
    expect(sessionDirs(), hasLength(1));
    expect(events.map((DocScanEvent e) => e.name), isNot(contains('scan_cancelled')));
    // Review's «إلغاء» still discards the scan.
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('إلغاء').last);
    await settle(t, find.text('scan'));
    expect(await t.runAsync<DocScanResult?>(() => result), isNull);
    expect(sessionDirs(), isEmpty);
  });

  testWidgets('«إرفاق كملف PDF» on review goes straight to the photo preview', (WidgetTester t) async {
    await t.pumpWidget(host((Future<DocScanResult?> _) {}));
    await t.tap(find.text('scan'));
    await settle(t, find.bySemanticsLabel('التقاط'));
    await capturePage(t);
    await t.tap(find.text('حفظ (1)'));
    await settle(t, find.text('التالي'));
    await t.tap(find.text('التالي'));
    await settle(t, find.bySemanticsLabel('إرفاق كملف PDF'));
    await t.tap(find.bySemanticsLabel('إرفاق كملف PDF'));
    await settle(t, find.bySemanticsLabel('معاينة ملف PDF'), tries: 200);
    // Photo pages: no text tip, no word selection.
    expect(find.text('يمكنك تحديد أي نص لحجبه أو تعديله قبل الإرسال.'), findsNothing);
  });
}
