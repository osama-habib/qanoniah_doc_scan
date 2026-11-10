import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/qanoniah_doc_scan.dart';
import 'package:qanoniah_doc_scan/src/capture/data/edge_detector.dart';
import 'package:qanoniah_doc_scan/src/capture/manager/capture_cubit.dart';
import 'package:qanoniah_doc_scan/src/capture/presentation/camera_sheet.dart';
import 'package:qanoniah_doc_scan/src/core/doc_scan_icons.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session_repo.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/recognition_repo.dart';

import '../fakes/fake_camera_source.dart';
import '../fakes/fake_edge_detector.dart';
import '../fakes/fake_text_recognizer.dart';
import '../helpers/test_host.dart';

/// «الكشاف» on the camera (design 02-c; ClickUp z8y71x6uuw).
void main() {
  late Directory tmp;
  late ScanSessionRepo sessions;
  late RecognitionRepo recognition;

  // One glyph per state, so the test can tell them apart.
  const DocScanIcons icons = DocScanIcons(
    close: 'i.svg',
    capture: 'i.svg',
    autoMode: 'i.svg',
    manualMode: 'i.svg',
    addPage: 'i.svg',
    retake: 'i.svg',
    delete: 'i.svg',
    crop: 'i.svg',
    filters: 'i.svg',
    redact: 'i.svg',
    reveal: 'i.svg',
    edit: 'i.svg',
    document: 'i.svg',
    back: 'i.svg',
    done: 'i.svg',
    photoView: 'i.svg',
    undo: 'i.svg',
    dragHandle: 'i.svg',
    pages: 'i.svg',
    search: 'i.svg',
    chevronUp: 'i.svg',
    chevronDown: 'i.svg',
    pdf: 'i.svg',
    flash: 'flash-auto.svg',
    flashOn: 'flash-on.svg',
    flashOff: 'flash-off.svg',
    torchOn: 'torch-on.svg',
    torchOff: 'torch-off.svg',
  );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('flash');
    sessions = ScanSessionRepo(tempRoot: () async => tmp);
    await sessions.start();
    recognition = RecognitionRepo(recognizer: FakeTextRecognizer(), sessions: sessions, enabled: false);
  });

  tearDown(() async {
    recognition.dispose();
    await tmp.delete(recursive: true);
  });

  Future<CaptureCubit> pump(WidgetTester t, {bool hasFlash = true}) async {
    final FakeCameraSource camera = FakeCameraSource(outDir: tmp, hasFlash: hasFlash);
    final CaptureCubit cubit = CaptureCubit(
      camera: camera,
      edges: FakeEdgeDetector(const FrameAnalysis(quad: null, sharpness: 0, luminance: 0)),
      permissions: FakePermissionRepo(),
      preparer: FakePagePreparer(),
      sessions: sessions,
      recognition: recognition,
      onEvent: (DocScanEvent _) {},
      idleAfter: const Duration(hours: 1),
    );
    await t.runAsync(cubit.start);
    await t.binding.setSurfaceSize(const Size(402, 874));
    await t.pumpWidget(
      testApp(
        Builder(
          builder: (BuildContext context) => Theme(
            data: Theme.of(context).copyWith(extensions: <ThemeExtension<dynamic>>[testTheme.copyWith(icons: icons)]),
            child: Scaffold(
              body: BlocProvider<CaptureCubit>.value(
                value: cubit,
                child: CameraSheet(
                  strings: DocScanStrings.ar(),
                  preview: () => const SizedBox.expand(),
                  onCancel: () {},
                  onReview: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    return cubit;
  }

  Finder glyph(String asset) => find.byWidgetPredicate((Widget w) => w is DocScanIcon && w.assetPath == asset);

  // The on glyph keeps its own colors: drawn without a tint.
  Finder ownColors(String asset) => find.byWidgetPredicate(
    (Widget w) =>
        w is SvgPicture && w.bytesLoader is SvgAssetLoader && (w.bytesLoader as SvgAssetLoader).assetName == asset,
  );

  Color disc(WidgetTester t) {
    final AnimatedContainer c = t.widget<AnimatedContainer>(
      find.descendant(of: find.bySemanticsLabel(RegExp('الكشاف')), matching: find.byType(AnimatedContainer)),
    );
    return (c.decoration! as BoxDecoration).color!;
  }

  Future<void> close(WidgetTester t, CaptureCubit cubit) async {
    // Unmount before closing: a cubit still watched closes only as frames pump.
    await t.pumpWidget(const SizedBox());
    await t.runAsync(cubit.close);
  }

  testWidgets('[UT] a scan opens with the torch off; a tap turns it on, yellow, and another off', (
    WidgetTester t,
  ) async {
    final CaptureCubit cubit = await pump(t);
    expect(find.bySemanticsLabel('تشغيل الكشاف'), findsOneWidget, reason: 'off: the button says what a tap does');
    expect(glyph('torch-off.svg'), findsOneWidget);
    expect(disc(t), testTheme.onCameraSurface.withValues(alpha: 0.16));

    await t.tap(find.bySemanticsLabel('تشغيل الكشاف'));
    await t.pump(const Duration(milliseconds: 250));
    expect(find.bySemanticsLabel('إيقاف الكشاف'), findsOneWidget);
    expect(ownColors('torch-on.svg'), findsOneWidget);
    expect(disc(t), testTheme.torchActive, reason: 'the yellow disc');
    expect(
      t.getSemantics(find.bySemanticsLabel('إيقاف الكشاف')),
      containsSemantics(hasToggledState: true, isToggled: true),
    );

    await t.tap(find.bySemanticsLabel('إيقاف الكشاف'));
    await t.pump(const Duration(milliseconds: 250));
    expect(find.bySemanticsLabel('تشغيل الكشاف'), findsOneWidget, reason: 'back off');
    await close(t, cubit);
  });

  testWidgets('[UT] a 36 disc, 44 x 44 to touch', (WidgetTester t) async {
    final CaptureCubit cubit = await pump(t);
    final Size touch = t.getSize(find.bySemanticsLabel('تشغيل الكشاف'));
    expect(touch, const Size(44, 44));
    final Size seen = t.getSize(
      find.descendant(of: find.bySemanticsLabel('تشغيل الكشاف'), matching: find.byType(AnimatedContainer)),
    );
    expect(seen, const Size(36, 36));
    await close(t, cubit);
  });

  testWidgets('[UT] no note over the picture when the torch changes (the design shows none)', (WidgetTester t) async {
    final CaptureCubit cubit = await pump(t);
    await t.tap(find.bySemanticsLabel('تشغيل الكشاف'));
    await t.pump();
    expect(find.textContaining('الفلاش'), findsNothing);
    expect(find.textContaining('الكشاف'), findsNothing);
    await close(t, cubit);
  });

  testWidgets('[UT] no torch button on a camera without a light', (WidgetTester t) async {
    final CaptureCubit cubit = await pump(t, hasFlash: false);
    expect(find.bySemanticsLabel(RegExp('الكشاف')), findsNothing);
    expect(glyph('torch-off.svg'), findsNothing);
    await close(t, cubit);
  });
}
