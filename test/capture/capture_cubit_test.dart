import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/src/capture/data/camera_source.dart';
import 'package:qanoniah_doc_scan/src/capture/data/edge_detector.dart';
import 'package:qanoniah_doc_scan/src/capture/manager/capture_cubit.dart';
import 'package:qanoniah_doc_scan/src/core/doc_scan_event.dart';
import 'package:qanoniah_doc_scan/src/core/failures.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session_repo.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/recognition_repo.dart';

import '../fakes/fake_camera_source.dart';
import '../fakes/fake_edge_detector.dart';
import '../fakes/fake_text_recognizer.dart';
import '../helpers/test_host.dart';

const Quad page = Quad(
  topLeft: Offset(0.1, 0.1),
  topRight: Offset(0.9, 0.1),
  bottomRight: Offset(0.9, 0.9),
  bottomLeft: Offset(0.1, 0.9),
);

const FrameAnalysis good = FrameAnalysis(quad: page, sharpness: 200, luminance: 140);

void main() {
  late Directory tmp;
  late ScanSessionRepo sessions;
  late FakeCameraSource camera;
  late FakeEdgeDetector edges;
  late FakePermissionRepo permissions;
  late RecognitionRepo recognition;
  late List<DocScanEvent> events;
  late DateTime clock;
  late FakePagePreparer preparer;

  CaptureCubit cubit({
    String? replacing,
    Duration idleAfter = const Duration(seconds: 10),
    ScanFlash initialFlash = ScanFlash.off,
    void Function(ScanFlash)? onFlashChanged,
  }) => CaptureCubit(
    camera: camera,
    edges: edges,
    permissions: permissions,
    preparer: preparer,
    sessions: sessions,
    recognition: recognition,
    onEvent: events.add,
    replacePageId: replacing,
    now: () => clock,
    idleAfter: idleAfter,
    initialFlash: initialFlash,
    onFlashChanged: onFlashChanged,
  );

  Future<void> feed(int n, {Duration step = const Duration(milliseconds: 200)}) async {
    for (int i = 0; i < n; i++) {
      camera.emit(CameraFrame(luminance: Uint8List(1), width: 1, height: 1));
      await pumpEventQueue();
      clock = clock.add(step);
    }
  }

  /// A manual shot through the corner step, keeping the corners it found.
  Future<void> shoot(CaptureCubit c) async {
    await c.capture();
    final Quad? q = c.state.adjustQuad;
    if (q != null) await c.keepAdjusted(q);
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cap');
    sessions = ScanSessionRepo(tempRoot: () async => tmp);
    await sessions.start(maxPages: 2);
    camera = FakeCameraSource(outDir: tmp);
    edges = FakeEdgeDetector(good);
    permissions = FakePermissionRepo();
    recognition = RecognitionRepo(recognizer: FakeTextRecognizer(), sessions: sessions);
    events = <DocScanEvent>[];
    clock = DateTime(2026);
    preparer = FakePagePreparer();
  });

  tearDown(() async {
    recognition.dispose();
    await tmp.delete(recursive: true);
  });

  test('steady, sharp, bright frames capture exactly once', () async {
    final CaptureCubit c = cubit();
    await c.start();
    c.setMode(CaptureMode.auto);
    await feed(8);
    if (c.state.pageCount == 0) {
      await c.stream.firstWhere((CaptureState s) => s.pageCount > 0).timeout(const Duration(seconds: 5));
    }
    await feed(4);
    expect(camera.pictures, 1);
    expect(c.state.pageCount, 1);
    expect(events.where((DocScanEvent e) => e.name == 'scan_page_captured').length, 1);
    await c.close();
  });

  test('dark or blurred frames never auto-capture and show a hint', () async {
    edges.next = const FrameAnalysis(quad: page, sharpness: 200, luminance: 10);
    final CaptureCubit c = cubit();
    await c.start();
    c.setMode(CaptureMode.auto);
    await feed(8);
    expect(c.state.hint, CaptureHint.lowLight);
    edges.next = const FrameAnalysis(quad: page, sharpness: 5, luminance: 140);
    await feed(8);
    expect(c.state.hint, CaptureHint.holdSteady);
    expect(camera.pictures, 0);
    await c.close();
  });

  test('manual capture works with no corners and uses the full frame', () async {
    edges.next = const FrameAnalysis(quad: null, sharpness: 0, luminance: 0);
    final CaptureCubit c = cubit();
    await c.start();
    c.setMode(CaptureMode.manual);
    await shoot(c);
    expect(sessions.session.pages.single.corners, Quad.fullFrame);
    await c.close();
  });

  test('the page limit stops capture', () async {
    final CaptureCubit c = cubit();
    await c.start();
    c.setMode(CaptureMode.manual);
    await shoot(c);
    await shoot(c);
    await shoot(c);
    expect(sessions.session.pages.length, 2);
    expect(c.state.limitReached, isTrue);
    expect(events.map((DocScanEvent e) => e.name), contains('scan_page_limit_reached'));
    await c.close();
  });

  test('denied and permanently denied permissions', () async {
    permissions.result = const CameraFailure.permissionDenied();
    final CaptureCubit a = cubit();
    await a.start();
    expect(a.state.phase, CapturePhase.denied);
    permissions.result = const CameraFailure.permanentlyDenied();
    final CaptureCubit b = cubit();
    await b.start();
    expect(b.state.phase, CapturePhase.permanentlyDenied);
    expect(
      events.map((DocScanEvent e) => e.name),
      containsAll(<String>['scan_permission_denied', 'scan_permission_permanently_denied']),
    );
    await a.close();
    await b.close();
  });

  test('retake replaces the page in place and flags replaced', () async {
    final CaptureCubit first = cubit();
    await first.start();
    first.setMode(CaptureMode.manual);
    await shoot(first);
    await first.close();
    final String id = sessions.session.pages.single.id;

    camera = FakeCameraSource(outDir: tmp);
    final CaptureCubit retake = cubit(replacing: id);
    await retake.start();
    await shoot(retake);
    expect(sessions.session.pages.length, 1);
    expect(sessions.session.pages.single.id, id);
    expect(retake.state.replaced, isTrue);
    await retake.close();
  });

  test('a new page in the same place re-arms auto capture (a stack of pages)', () async {
    final CaptureCubit c = cubit();
    await c.start();
    c.setMode(CaptureMode.auto);
    edges.next = FrameAnalysis(quad: page, sharpness: 200, luminance: 140, signature: List<int>.filled(256, 200));
    await feed(8);
    if (c.state.pageCount == 0) {
      await c.stream.firstWhere((CaptureState s) => s.pageCount > 0).timeout(const Duration(seconds: 5));
    }
    // Same corners, same content: no second capture.
    await feed(8);
    expect(camera.pictures, 1);
    // Same corners, different content: the next page was laid on top.
    edges.next = FrameAnalysis(quad: page, sharpness: 200, luminance: 140, signature: List<int>.filled(256, 120));
    await feed(10);
    if (camera.pictures < 2) {
      await c.stream.firstWhere((CaptureState s) => s.pageCount > 1).timeout(const Duration(seconds: 5));
    }
    expect(camera.pictures, 2);
    await c.close();
  });

  test('the corners found on the photo win over the live frame', () async {
    const Quad still = Quad(
      topLeft: Offset(0.2, 0.2),
      topRight: Offset(0.8, 0.2),
      bottomRight: Offset(0.8, 0.8),
      bottomLeft: Offset(0.2, 0.8),
    );
    edges.photoQuad = still;
    final CaptureCubit c = cubit();
    await c.start();
    c.setMode(CaptureMode.manual);
    await shoot(c);
    expect(sessions.session.pages.single.corners, still);
    await c.close();
  });

  test('manual capture is the default and stops on the corner step', () async {
    final CaptureCubit c = cubit();
    await c.start();
    expect(c.state.mode, CaptureMode.manual);
    await feed(1);
    await c.capture();
    expect(c.state.adjustFile, isNotNull);
    expect(c.state.adjustQuad, page);
    expect(sessions.session.pages, isEmpty);
    // A second tap while the corner step is open takes nothing.
    await c.capture();
    expect(camera.pictures, 1);
    await c.close();
  });

  test('«حفظ الصفحة» keeps the dragged corners; «إعادة الالتقاط» drops the photo', () async {
    const Quad dragged = Quad(
      topLeft: Offset(0.15, 0.12),
      topRight: Offset(0.85, 0.1),
      bottomRight: Offset(0.9, 0.88),
      bottomLeft: Offset(0.1, 0.9),
    );
    final CaptureCubit c = cubit();
    await c.start();
    await c.capture();
    final File photo = c.state.adjustFile!;
    await c.retakeAdjusted();
    expect(c.state.adjustFile, isNull);
    expect(photo.existsSync(), isFalse);
    expect(sessions.session.pages, isEmpty);

    await c.capture();
    await c.keepAdjusted(dragged);
    expect(c.state.adjustFile, isNull);
    expect(sessions.session.pages.single.corners, dragged);
    await c.close();
  });

  test('[UT] the page comes out upright: the turns found on the photo reach preparation', () async {
    edges.turns = 2;
    final CaptureCubit c = cubit();
    await c.start();
    c.setMode(CaptureMode.manual);
    await c.capture();
    await pumpEventQueue();
    // The corner step shows the photo upright.
    expect(c.state.adjustTurns, 2);
    await c.keepAdjusted(c.state.adjustQuad!);
    expect(preparer.turns.single, 2);
    expect(sessions.session.pages.single.turns, 2);
    await c.close();
  });

  test('[UT] «تدوير» on the corner step turns a quarter counter-clockwise and wins over the found turns', () async {
    final CaptureCubit c = cubit();
    await c.start();
    c.setMode(CaptureMode.manual);
    await c.capture();
    await pumpEventQueue();
    c.rotateAdjusted();
    expect(c.state.adjustTurns, 3);
    c.rotateAdjusted();
    expect(c.state.adjustTurns, 2);
    await c.keepAdjusted(c.state.adjustQuad!);
    expect(preparer.turns.single, 2);
    // The next page starts from the found turns again.
    expect(c.state.adjustTurns, 0);
    await c.close();
  });

  test('[UT] the flash goes off, auto, on, off; the camera and the flow get each choice (pk3)', () async {
    final List<ScanFlash> told = <ScanFlash>[];
    final CaptureCubit c = cubit(initialFlash: ScanFlash.auto, onFlashChanged: told.add);
    await c.start();
    // The visit opens with the flow's last choice.
    expect(camera.flash, ScanFlash.auto);
    await c.cycleFlash();
    expect((c.state.flash, camera.flash), (ScanFlash.on, ScanFlash.on));
    await c.cycleFlash();
    expect((c.state.flash, camera.flash), (ScanFlash.off, ScanFlash.off));
    await c.cycleFlash();
    expect((c.state.flash, camera.flash), (ScanFlash.auto, ScanFlash.auto));
    expect(told, <ScanFlash>[ScanFlash.on, ScanFlash.off, ScanFlash.auto]);
    await c.close();
  });

  test('[UT] without a capture the camera pauses itself; «استئناف الكاميرا» brings it back (pk5)', () async {
    final CaptureCubit c = cubit(idleAfter: const Duration(milliseconds: 120));
    await c.start();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(c.state.idle, isFalse, reason: 'not yet');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(c.state.idle, isTrue);
    expect(camera.paused, isTrue);
    // While paused the shutter takes nothing.
    await c.capture();
    expect(camera.pictures, 0);
    // Coming back from the background does not wake it either.
    await c.resumeCamera();
    expect(camera.paused, isTrue);
    await c.wake();
    expect(c.state.idle, isFalse);
    expect(camera.paused, isFalse);
    await c.close();
  });

  test('[UT] each capture or tap restarts the idle countdown', () async {
    final CaptureCubit c = cubit(idleAfter: const Duration(milliseconds: 150));
    await c.start();
    for (int i = 0; i < 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await c.cycleFlash();
    }
    expect(c.state.idle, isFalse, reason: '300 ms in, but never 150 ms without a tap');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(c.state.idle, isTrue);
    await c.close();
  });

  test('[UT] closing the camera step cancels the countdown and releases the camera', () async {
    final CaptureCubit c = cubit(idleAfter: const Duration(milliseconds: 80));
    await c.start();
    await c.close();
    expect(camera.disposed, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(camera.paused, isFalse, reason: 'no pause after close');
  });
}
