// ignore_for_file: avoid_print, avoid_relative_lib_imports
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/qanoniah_doc_scan.dart';
import 'package:qanoniah_doc_scan/src/capture/data/edge_detector.dart';
import 'package:qanoniah_doc_scan/src/capture/manager/capture_cubit.dart';
import 'package:qanoniah_doc_scan/src/capture/presentation/camera_sheet.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session_repo.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/recognition_repo.dart';

import '../../example/lib/fallback_theme.dart';
import '../fakes/fake_camera_source.dart';
import '../fakes/fake_edge_detector.dart';
import '../fakes/fake_text_recognizer.dart';
import '../helpers/test_host.dart';

/// Host probe: the camera header's flash button in each state, and the note
/// after a change, to PROBE_OUT. The flash glyphs come from PROBE_FLASH_ICONS
/// (flash.svg, flash_filled.svg, flash_slash.svg), the host's own files.
/// Skips without both.
final Map<String, String> env = Platform.environment;

class _Assets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final String k = Uri.decodeFull(key);
    final File f = k.startsWith('probe-icons/')
        ? File('${env['PROBE_FLASH_ICONS']}/${k.substring(12)}')
        : File('example/$k');
    return ByteData.sublistView(f.readAsBytesSync());
  }
}

void main() {
  testWidgets('flash', (WidgetTester t) async {
    final String out = env['PROBE_OUT']!;
    Directory(out).createSync(recursive: true);
    final Directory tmp = Directory.systemTemp.createTempSync('flashprobe');
    await t.runAsync(() async {
      final FontLoader l = FontLoader('NotoSansArabic');
      for (final String f in <String>['NotoSansArabic-Regular.ttf', 'NotoSansArabic-Medium.ttf']) {
        l.addFont(Future<ByteData>.value(ByteData.sublistView(File('example/assets/fonts/$f').readAsBytesSync())));
      }
      await l.load();
    });
    final DocScanIcons base = fallbackTheme.icons;
    final DocScanIcons icons = DocScanIcons(
      close: base.close,
      capture: base.capture,
      autoMode: base.autoMode,
      manualMode: base.manualMode,
      addPage: base.addPage,
      retake: base.retake,
      delete: base.delete,
      crop: base.crop,
      filters: base.filters,
      redact: base.redact,
      reveal: base.reveal,
      edit: base.edit,
      document: base.document,
      back: base.back,
      done: base.done,
      photoView: base.photoView,
      undo: base.undo,
      dragHandle: base.dragHandle,
      pages: base.pages,
      search: base.search,
      chevronUp: base.chevronUp,
      chevronDown: base.chevronDown,
      pdf: base.pdf,
      flash: 'probe-icons/flash.svg',
      flashOn: 'probe-icons/flash_filled.svg',
      flashOff: 'probe-icons/flash_slash.svg',
    );
    final ScanSessionRepo sessions = ScanSessionRepo(tempRoot: () async => tmp);
    await t.runAsync(sessions.start);
    final RecognitionRepo recognition = RecognitionRepo(
      recognizer: FakeTextRecognizer(),
      sessions: sessions,
      enabled: false,
    );
    final CaptureCubit cubit = CaptureCubit(
      camera: FakeCameraSource(outDir: tmp),
      edges: FakeEdgeDetector(const FrameAnalysis(quad: null, sharpness: 0, luminance: 0)),
      permissions: FakePermissionRepo(),
      preparer: FakePagePreparer(),
      sessions: sessions,
      recognition: recognition,
      onEvent: (DocScanEvent _) {},
      idleAfter: const Duration(hours: 1),
    );
    await t.runAsync(cubit.start);
    const Size size = Size(402, 874);
    await t.binding.setSurfaceSize(size);
    t.view.physicalSize = size * 3;
    t.view.devicePixelRatio = 3;
    final GlobalKey shotKey = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: shotKey,
        child: DefaultAssetBundle(
          bundle: _Assets(),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar'),
            supportedLocales: const <Locale>[Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: ThemeData(
              fontFamily: 'NotoSansArabic',
              extensions: <ThemeExtension<dynamic>>[fallbackTheme.copyWith(icons: icons)],
            ),
            home: Scaffold(
              body: BlocProvider<CaptureCubit>.value(
                value: cubit,
                child: CameraSheet(
                  strings: DocScanStrings.ar(),
                  preview: () => const ColoredBox(color: Color(0xff2a2f3a)),
                  onCancel: () {},
                  onReview: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Future<void> shot(String name) async {
      for (int i = 0; i < 8; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await t.pump(const Duration(milliseconds: 40));
      }
      final ui.Image im = await (shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(
        pixelRatio: 2,
      );
      final ByteData? png = await t.runAsync<ByteData?>(() => im.toByteData(format: ui.ImageByteFormat.png));
      File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      print('[SHOT] $name');
    }

    await shot('flash_1_auto');
    await t.tap(find.bySemanticsLabel('الفلاش، تلقائي'));
    await shot('flash_2_on_note');
    await t.pump(const Duration(seconds: 2));
    await shot('flash_3_on');
    await t.tap(find.bySemanticsLabel('الفلاش، تشغيل'));
    await t.pump(const Duration(seconds: 2));
    await shot('flash_4_off');
    await t.pumpWidget(const SizedBox());
    await t.runAsync(cubit.close);
    recognition.dispose();
  }, skip: env['PROBE_OUT'] == null || env['PROBE_FLASH_ICONS'] == null);
}
