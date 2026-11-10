// ignore_for_file: avoid_print, avoid_relative_lib_imports
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qanoniah_doc_scan/qanoniah_doc_scan.dart';
import 'package:qanoniah_doc_scan/src/capture/data/camera_source.dart';
import 'package:qanoniah_doc_scan/src/capture/data/edge_detector.dart';
import 'package:qanoniah_doc_scan/src/core/doc_scan.dart';
import 'package:qanoniah_doc_scan/src/core/failures.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session_repo.dart';
import 'package:qanoniah_doc_scan/src/page_prep/data/page_preparer.dart';

import '../../example/lib/fallback_theme.dart';
import '../fakes/fake_edge_detector.dart';
import '../fakes/fake_text_recognizer.dart';
import '../helpers/test_host.dart';

/// Host probe: screenshots of every step of the real flow, with the example's
/// theme, fonts and icons, to PROBE_OUT (and PROBE_PHOTO as the captured page).
/// Skips without PROBE_OUT.
final Map<String, String> env = Platform.environment;

/// Reads the example app's assets from disk.
class _ExampleAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File('example/${Uri.decodeFull(key)}').readAsBytesSync());
}

class _PhotoCamera implements CameraSource {
  _PhotoCamera(this.dir);
  final Directory dir;
  int shots = 0;

  @override
  Future<Either<CameraFailure, Unit>> initialize() async => const Right<CameraFailure, Unit>(unit);
  @override
  Widget preview() => const ColoredBox(color: Color(0xff2a2f3a));
  @override
  Stream<CameraFrame> get frames => const Stream<CameraFrame>.empty();
  @override
  Future<Either<CameraFailure, File>> takePicture() async {
    final File f = File('${dir.path}/shot${shots++}.jpg');
    final String? photo = env['PROBE_PHOTO'];
    if (photo != null) {
      await File(photo).copy(f.path);
    } else {
      final img.Image im = img.Image(width: 600, height: 800);
      img.fill(im, color: img.ColorRgb8(70, 70, 70));
      img.fillRect(im, x1: 80, y1: 100, x2: 520, y2: 700, color: img.ColorRgb8(240, 240, 235));
      f.writeAsBytesSync(img.encodeJpg(im));
    }
    return Right<CameraFailure, File>(f);
  }

  @override
  Future<void> setFlash(ScanFlash flash) async {}
  @override
  bool get hasFlash => true;
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('screens', (WidgetTester t) async {
    final String out = env['PROBE_OUT']!;
    Directory(out).createSync(recursive: true);
    final Directory tmp = Directory.systemTemp.createTempSync('screens');
    await t.runAsync(() async {
      for (final (String fam, List<String> files) in <(String, List<String>)>[
        ('NotoSansArabic', <String>['NotoSansArabic-Regular.ttf', 'NotoSansArabic-Medium.ttf', 'NotoSansArabic-SemiBold.ttf']),
        ('NotoSans', <String>['NotoSans-Regular.ttf']),
      ]) {
        final FontLoader l = FontLoader(fam);
        for (final String f in files) {
          l.addFont(Future<ByteData>.value(ByteData.sublistView(File('example/assets/fonts/$f').readAsBytesSync())));
        }
        await l.load();
      }
    });
    const Size size = Size(402, 874);
    await t.binding.setSurfaceSize(size);
    t.view.physicalSize = size * 3;
    t.view.devicePixelRatio = 3;
    final FakeEdgeDetector edges = FakeEdgeDetector(const FrameAnalysis(quad: null, sharpness: 0, luminance: 0))
      ..photoQuad = const Quad(
        topLeft: Offset(0.093, 0.227),
        topRight: Offset(0.935, 0.232),
        bottomRight: Offset(0.995, 0.943),
        bottomLeft: Offset(0.065, 0.922),
      );
    DocScan.debugDeps = () => ScanFlowDeps(
      sessions: ScanSessionRepo(tempRoot: () async => tmp),
      recognizer: FakeTextRecognizer(),
      newCamera: () => _PhotoCamera(tmp),
      newEdgeDetector: () => edges,
      permissions: FakePermissionRepo(),
      preparer: const PagePreparer(native: false),
    );
    final GlobalKey shotKey = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: shotKey,
        child: DefaultAssetBundle(
          bundle: _ExampleAssets(),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar'),
            supportedLocales: const <Locale>[Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: ThemeData(fontFamily: 'NotoSansArabic', extensions: <ThemeExtension<dynamic>>[fallbackTheme]),
            home: Builder(
              builder: (BuildContext context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => DocScan.start(
                      context,
                      DocScanConfig(
                        pdfFont: File('example/assets/fonts/NotoSansArabic-Regular.ttf').readAsBytesSync(),
                        pdfFontFallback: File('example/assets/fonts/NotoSans-Regular.ttf').readAsBytesSync(),
                      ),
                    ),
                    child: const Text('scan'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Future<void> wait([int n = 20]) async {
      for (int i = 0; i < n; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await t.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> until(Finder f, {int tries = 200}) async {
      for (int i = 0; i < tries && f.evaluate().isEmpty; i++) {
        await wait(1);
      }
      expect(f, findsWidgets);
    }

    Future<void> shot(String name) async {
      await wait(12);
      final ui.Image im = await (shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(
        pixelRatio: 2,
      );
      final ByteData? png = await t.runAsync<ByteData?>(() => im.toByteData(format: ui.ImageByteFormat.png));
      File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      print('[SHOT] $name');
    }

    final List<String> only = (env['PROBE_STEPS'] ?? 'camera,corners,filters,review,preview').split(',');
    await t.tap(find.text('scan'));
    await until(find.bySemanticsLabel('التقاط'));
    if (only.contains('camera')) await shot('1_camera');
    // 11 s without a capture: the camera pauses itself.
    await t.pump(const Duration(seconds: 11));
    await until(find.text('استئناف الكاميرا'));
    if (only.contains('camera')) await shot('1b_paused');
    await t.tap(find.text('استئناف الكاميرا'));
    await until(find.bySemanticsLabel('التقاط'));
    await t.tap(find.bySemanticsLabel('التقاط'));
    await until(find.text('حفظ الصفحة'));
    if (only.contains('corners')) {
      await shot('2_corners');
      // Mid-drag on the top edge: the magnifier.
      await wait(10);
      final Rect area = t.getRect(find.byType(Image).last);
      final TestGesture g = await t.startGesture(Offset(area.center.dx, area.top + area.height * 0.23));
      await g.moveBy(const Offset(0, 24));
      await g.moveBy(const Offset(0, 6));
      await t.pump();
      await shot('2b_edge_drag');
      await g.up();
      await t.pump();
    }
    await t.tap(find.text('حفظ الصفحة'));
    await until(find.text('حفظ (1)'));
    await wait(30);
    await t.tap(find.text('حفظ (1)'));
    await until(find.text('توضيح الصفحات'));
    if (only.contains('filters')) await shot('3_filters');
    await t.tap(find.text('التالي'));
    await until(find.bySemanticsLabel('معاينة'));
    if (only.contains('review')) await shot('4_review');
    await t.tap(find.bySemanticsLabel('معاينة'));
    await until(find.bySemanticsLabel('معاينة ملف PDF'), tries: 400);
    if (only.contains('preview')) await shot('5_preview');
    // Pull the sheet down from the header: «تجاهل المسح؟».
    await t.dragFrom(const Offset(201, 60), const Offset(0, 300));
    await until(find.text('تجاهل المسح؟'));
    await wait(12);
    await shot('6_discard');
    DocScan.debugDeps = null;
  }, skip: env['PROBE_OUT'] == null);
}
