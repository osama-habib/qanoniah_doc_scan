import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

/// The flash button on the camera (ClickUp z8y71x6uuw).
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
            data: Theme.of(context).copyWith(
              extensions: <ThemeExtension<dynamic>>[testTheme.copyWith(icons: icons)],
            ),
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

  Finder glyph(String asset) =>
      find.byWidgetPredicate((Widget w) => w is DocScanIcon && w.assetPath == asset);

  Future<void> close(WidgetTester t, CaptureCubit cubit) async {
    // Unmount before closing: a cubit still watched closes only as frames pump.
    await t.pumpWidget(const SizedBox());
    await t.runAsync(cubit.close);
  }

  testWidgets('[UT] a scan opens on «تلقائي»; taps go on, off, auto, each with its own glyph', (WidgetTester t) async {
    final CaptureCubit cubit = await pump(t);
    expect(find.bySemanticsLabel('الفلاش، تلقائي'), findsOneWidget, reason: 'a new scan starts automatic');
    expect(glyph('flash-auto.svg'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('الفلاش، تلقائي'));
    await t.pump();
    expect(find.bySemanticsLabel('الفلاش، تشغيل'), findsOneWidget);
    expect(glyph('flash-on.svg'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('الفلاش، تشغيل'));
    await t.pump();
    expect(find.bySemanticsLabel('الفلاش، إيقاف'), findsOneWidget);
    expect(glyph('flash-off.svg'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('الفلاش، إيقاف'));
    await t.pump();
    expect(find.bySemanticsLabel('الفلاش، تلقائي'), findsOneWidget, reason: 'back to the start');
    await close(t, cubit);
  });

  testWidgets('[UT] the button is 44 x 44 to touch', (WidgetTester t) async {
    final CaptureCubit cubit = await pump(t);
    final Size size = t.getSize(find.bySemanticsLabel('الفلاش، تلقائي'));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
    await close(t, cubit);
  });

  testWidgets('[UT] the new state shows as «الفلاش: …» for about a second, only after a change', (WidgetTester t) async {
    final CaptureCubit cubit = await pump(t);
    double opacity() => t
        .widget<AnimatedOpacity>(
          find.ancestor(of: find.textContaining('الفلاش:'), matching: find.byType(AnimatedOpacity)),
        )
        .opacity;
    expect(find.textContaining('الفلاش:'), findsNothing, reason: 'nothing before the first change');

    await t.tap(find.bySemanticsLabel('الفلاش، تلقائي'));
    await t.pump();
    expect(find.text('الفلاش: تشغيل'), findsOneWidget);
    expect(opacity(), 1);

    await t.pump(const Duration(milliseconds: 1300));
    expect(opacity(), 0, reason: 'gone after about a second');
    await close(t, cubit);
  });

  testWidgets('[UT] no flash button on a camera without a flash', (WidgetTester t) async {
    final CaptureCubit cubit = await pump(t, hasFlash: false);
    expect(find.bySemanticsLabel(RegExp('^الفلاش')), findsNothing);
    expect(glyph('flash-auto.svg'), findsNothing);
    await close(t, cubit);
  });
}
