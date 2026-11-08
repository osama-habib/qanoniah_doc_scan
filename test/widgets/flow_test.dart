import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  Future<void> setFlash(ScanFlash flash) async {}
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
        RawRecognition(
          blocksAreParagraphs: false,
          blocks: <List<Word>>[
            <Word>[Word(text: 'حكم', box: const Rect.fromLTWH(10, 10, 40, 20), confidence: 0.95)],
          ],
        ),
      );
}

void main() {
  late Directory tmp;
  late Directory shots;
  final List<DocScanEvent> events = <DocScanEvent>[];
  // Events that reached the host during a build: a host calling setState there crashes.
  final List<String> midBuild = <String>[];

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('flow');
    shots = await Directory('${tmp.path}/shots').create();
    events.clear();
    midBuild.clear();
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
    expect(midBuild, isEmpty, reason: 'onEvent was called during a build');
    DocScan.debugDeps = null;
    await tmp.delete(recursive: true);
  });

  DocScanConfig config({bool recognizeText = true}) => DocScanConfig(
    recognizeText: recognizeText,
    pdfFont: File('example/assets/fonts/NotoSansArabic-Regular.ttf').readAsBytesSync(),
    pdfFontFallback: File('example/assets/fonts/NotoSans-Regular.ttf').readAsBytesSync(),
    onEvent: (DocScanEvent e) {
      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) midBuild.add(e.name);
      events.add(e);
    },
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

  Widget host(void Function(Future<DocScanResult?>) onResult, {bool recognizeText = true}) => testApp(
    Builder(
      builder: (BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => onResult(DocScan.start(context, config(recognizeText: recognizeText))),
            child: const Text('scan'),
          ),
        ),
      ),
    ),
  );

  /// Lets a sheet or card finish sliding in or out (camera animations never
  /// settle, so no pumpAndSettle).
  Future<void> frames(WidgetTester t) async {
    for (int i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

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
    expect(find.bySemanticsLabel('معاينة'), findsOneWidget);
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
    expect(
      events.map((DocScanEvent e) => e.name),
      containsAllInOrder(<String>[
        'scan_started',
        'scan_page_captured',
        'scan_review_opened',
        'scan_build_started',
        'scan_build_completed',
        'scan_preview_opened',
        'scan_attached',
      ]),
    );
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

  testWidgets('[UT] «إلغاء» with pages asks «تجاهل المسح؟»: keep goes on, discard closes with nothing (pk2)', (
    WidgetTester t,
  ) async {
    late Future<DocScanResult?> result;
    await t.pumpWidget(host((Future<DocScanResult?> f) => result = f));
    await t.tap(find.text('scan'));
    await settle(t, find.bySemanticsLabel('التقاط'));
    await capturePage(t);
    await t.tap(find.text('إلغاء'));
    await settle(t, find.text('تجاهل المسح؟'));
    await frames(t);
    // «متابعة المسح»: nothing is lost, the camera stays.
    await t.tap(find.text('متابعة المسح'));
    await frames(t);
    expect(find.text('تجاهل المسح؟'), findsNothing);
    expect(find.bySemanticsLabel('التقاط'), findsOneWidget);
    expect(sessionDirs(), hasLength(1));
    expect(events.map((DocScanEvent e) => e.name), isNot(contains('scan_cancelled')));
    // «تجاهل المسح»: the scan closes, nothing attached, no files left.
    await t.tap(find.text('إلغاء'));
    await settle(t, find.text('تجاهل المسح؟'));
    await frames(t);
    await t.tap(find.text('تجاهل المسح'));
    await settle(t, find.text('scan'));
    expect(await t.runAsync<DocScanResult?>(() => result), isNull);
    expect(sessionDirs(), isEmpty);
    expect(events.last.name, 'scan_cancelled');
  });

  testWidgets('[UT] pulling the sheet down from any step closes the scan (pk2)', (WidgetTester t) async {
    late Future<DocScanResult?> result;
    await t.pumpWidget(host((Future<DocScanResult?> f) => result = f, recognizeText: false));
    await t.tap(find.text('scan'));
    await settle(t, find.bySemanticsLabel('التقاط'));
    await capturePage(t);
    await t.tap(find.text('حفظ (1)'));
    await settle(t, find.text('التالي'));
    await t.tap(find.text('التالي'));
    await settle(t, find.text('مراجعة الصفحات'));
    // Review: a pull from the header, past the threshold.
    await t.dragFrom(t.getCenter(find.text('مراجعة الصفحات')), const Offset(0, 300));
    await settle(t, find.text('تجاهل المسح؟'));
    await frames(t);
    await t.tap(find.text('تجاهل المسح'));
    await settle(t, find.text('scan'));
    expect(await t.runAsync<DocScanResult?>(() => result), isNull);
    expect(sessionDirs(), isEmpty);
  });

  testWidgets('[UT] a short pull springs back and keeps the scan', (WidgetTester t) async {
    await t.pumpWidget(host((Future<DocScanResult?> _) {}));
    await t.tap(find.text('scan'));
    await settle(t, find.bySemanticsLabel('التقاط'));
    await t.dragFrom(t.getCenter(find.text('مسح مستند')), const Offset(0, 40));
    await frames(t);
    expect(find.bySemanticsLabel('التقاط'), findsOneWidget);
    expect(find.text('تجاهل المسح؟'), findsNothing);
    // Close the empty scan for the next test.
    await t.tap(find.text('إلغاء'));
    await settle(t, find.text('scan'));
  });

  testWidgets('without text recognition review offers only the photo PDF, and nothing is read', (WidgetTester t) async {
    late Future<DocScanResult?> result;
    await t.pumpWidget(host((Future<DocScanResult?> f) => result = f, recognizeText: false));
    await t.tap(find.text('scan'));
    await settle(t, find.bySemanticsLabel('التقاط'));
    await capturePage(t);
    await t.tap(find.text('حفظ (1)'));
    await settle(t, find.text('التالي'));
    await t.tap(find.text('التالي'));
    await settle(t, find.bySemanticsLabel('معاينة'));
    expect(find.bySemanticsLabel('إنشاء مستند قابل للتعديل'), findsNothing);
    await t.tap(find.bySemanticsLabel('معاينة'));
    await settle(t, find.bySemanticsLabel('معاينة ملف PDF'), tries: 200);
    expect(find.text('حكم'), findsNothing);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('إرفاق كملف PDF').last);
    DocScanResult? r;
    for (int i = 0; i < 100 && r == null; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump();
      unawaited(result.then((DocScanResult? v) => r = v));
    }
    expect(r!.form, DocScanPdfForm.image);
    expect(r!.pageTexts.single, isEmpty);
  });

  testWidgets('[IT] review offers «معاينة», not «إرفاق»: attaching comes only after the preview (pk6)', (WidgetTester t) async {
    await t.pumpWidget(host((Future<DocScanResult?> _) {}));
    await t.tap(find.text('scan'));
    await settle(t, find.bySemanticsLabel('التقاط'));
    await capturePage(t);
    await t.tap(find.text('حفظ (1)'));
    await settle(t, find.text('التالي'));
    await t.tap(find.text('التالي'));
    await settle(t, find.bySemanticsLabel('معاينة'));
    expect(find.text('إرفاق كملف PDF'), findsNothing, reason: 'review never attaches');
    await t.tap(find.bySemanticsLabel('معاينة'));
    await settle(t, find.bySemanticsLabel('معاينة ملف PDF'), tries: 200);
    expect(find.text('إرفاق كملف PDF'), findsWidgets, reason: 'the preview attaches');
    // Photo pages: no text tip, no word selection.
    expect(find.text('يمكنك تحديد أي نص لحجبه أو تعديله قبل الإرسال.'), findsNothing);
  });
}
