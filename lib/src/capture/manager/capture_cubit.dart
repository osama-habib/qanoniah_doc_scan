import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/doc_scan_event.dart';
import '../../core/failures.dart';
import '../../core/session/scan_session.dart';
import '../../core/session/scan_session_repo.dart';
import '../../page_prep/data/page_preparer.dart';
import '../../recognition/data/recognition_repo.dart';
import '../data/camera_source.dart';
import '../data/edge_detector.dart';
import '../data/permission_repo.dart';

part 'capture_cubit.freezed.dart';

enum CapturePhase { checking, denied, permanentlyDenied, unavailable, ready }

/// Which hint the sheet shows under the frame.
enum CaptureHint { auto, manual, nextPage, lowLight, holdSteady }

@freezed
abstract class CaptureState with _$CaptureState {
  const factory CaptureState({
    required CapturePhase phase,
    required CaptureMode mode,

    /// Tracked page corners in the latest frame, normalized.
    Quad? quad,
    required CaptureHint hint,
    required int pageCount,
    @Default(false) bool capturing,

    /// Increments on every capture; drives the flash, the flying thumbnail and
    /// the «تم التقاط الصفحة» toast.
    @Default(0) int shots,
    File? lastThumbnail,
    @Default(false) bool limitReached,
    @Default(false) bool storageFull,

    /// Replace mode only: the replacement was taken, so the flow returns to review.
    @Default(false) bool replaced,

    /// Manual capture: the photo waiting for «حفظ الصفحة» or «إعادة الالتقاط»,
    /// with the corners found on it (design `scanAdj`).
    File? adjustFile,
    Quad? adjustQuad,

    /// The corner step's clockwise quarter turns to upright (found on capture,
    /// changed with «تدوير»).
    @Default(0) int adjustTurns,

    /// The page being straightened on screen: its photo, corners and turns.
    /// [straightens] counts them, so each one plays once.
    File? straightenFile,
    Quad? straightenQuad,
    @Default(0) int straightenTurns,
    @Default(0) int straightens,

    /// The flash for the next stills (pk3); automatic at the start of a scan
    /// (z8y71x6uuw).
    @Default(ScanFlash.off) ScanFlash flash,

    /// False on a camera without a flash: the flash button hides.
    @Default(true) bool hasFlash,

    /// The camera paused itself after [CaptureCubit.idleAfter] without a capture,
    /// so the phone does not heat up; «استئناف الكاميرا» wakes it (pk5).
    @Default(false) bool idle,

    /// The camera is off while the corner step covers it: the camera runs only
    /// while it is on screen (owner, 2026-11-10). Turns false once it is back,
    /// so the preview rebuilds on the reopened camera.
    @Default(false) bool cameraOff,
  }) = _CaptureState;
}

/// Auto and manual capture (FR-003 to FR-009).
///
/// Auto fires once the corners move less than [steadyTolerance] of the width for
/// [steadyFor] and the frame is sharp and bright enough. After a capture it waits
/// for the page to leave or move before it can fire again, so one page is never
/// captured twice.
class CaptureCubit extends Cubit<CaptureState> {
  CaptureCubit({
    required CameraSource camera,
    required EdgeDetector edges,
    required PermissionRepo permissions,
    required PagePreparer preparer,
    required ScanSessionRepo sessions,
    required RecognitionRepo recognition,
    required void Function(DocScanEvent) onEvent,
    this.replacePageId,
    DateTime Function()? now,
    this.steadyTolerance = 0.02,
    this.steadyFor = const Duration(milliseconds: 600),
    this.minSharpness = 60,
    this.minLuminance = 60,
    this.rearmDistance = 0.1,
    this.rearmContentChange = 18,
    this.idleAfter,
    ScanFlash initialFlash = ScanFlash.off,
    this.onFlashChanged,
  }) : _camera = camera,
       _edges = edges,
       _permissions = permissions,
       _preparer = preparer,
       _sessions = sessions,
       _recognition = recognition,
       _onEvent = onEvent,
       _now = now ?? DateTime.now,
       super(
         CaptureState(
           phase: CapturePhase.checking,
           mode: sessions.session.captureMode,
           hint: sessions.session.pages.isEmpty ? CaptureHint.auto : CaptureHint.nextPage,
           pageCount: sessions.session.pages.length,
           limitReached: _atLimit(sessions.session),
           flash: initialFlash,
         ),
       );

  final CameraSource _camera;
  final EdgeDetector _edges;
  final PermissionRepo _permissions;
  final PagePreparer _preparer;
  final ScanSessionRepo _sessions;
  final RecognitionRepo _recognition;
  final void Function(DocScanEvent) _onEvent;
  final DateTime Function() _now;

  /// When set, the next capture replaces this page (retake) instead of appending.
  final String? replacePageId;

  final double steadyTolerance;
  final Duration steadyFor;
  final double minSharpness;
  final double minLuminance;
  final double rearmDistance;

  /// Without a capture or a tap for this long the camera pauses itself (pk5).
  /// Null, the default since 2026-11-10: the owner found the pause tiresome;
  /// the camera is off on every step where it is not on screen instead.
  final Duration? idleAfter;

  /// The flow keeps the flash between camera visits.
  final void Function(ScanFlash flash)? onFlashChanged;

  Timer? _idle;

  /// Restarts the idle countdown: a capture or any action on the camera.
  void _stillHere() {
    _idle?.cancel();
    final Duration? after = idleAfter;
    if (after == null || isClosed || state.phase != CapturePhase.ready) return;
    _idle = Timer(after, _sleep);
  }

  Future<void> _sleep() async {
    if (isClosed || state.idle || state.capturing) return;
    emit(state.copyWith(idle: true, quad: null));
    await _camera.pause();
  }

  /// «استئناف الكاميرا» after the camera paused itself.
  Future<void> wake() async {
    if (!state.idle) return;
    await _camera.resume();
    if (isClosed) return;
    // After the camera is back, so the preview rebuilds on it.
    emit(state.copyWith(idle: false));
    _resetSteady();
    _stillHere();
  }

  /// «الكشاف» (design 02-c): the steady light on or off.
  Future<void> toggleTorch() => _setLight(state.flash == ScanFlash.torch ? ScanFlash.off : ScanFlash.torch);

  // TODO(unused): the three-state still flash (z8y71x6uuw) before the torch
  // design (02-c, 2026-11-10); kept in case a host wants it back.
  /// The flash button: automatic, then on, then off, then automatic again.
  Future<void> cycleFlash() => _setLight(switch (state.flash) {
    ScanFlash.auto => ScanFlash.on,
    ScanFlash.on => ScanFlash.off,
    ScanFlash.off || ScanFlash.torch => ScanFlash.auto,
  });

  Future<void> _setLight(ScanFlash next) async {
    emit(state.copyWith(flash: next));
    onFlashChanged?.call(next);
    _stillHere();
    await _camera.setFlash(next);
  }

  /// Re-arms auto capture when the frame's content changed this much (mean
  /// absolute difference of signatures, 0 to 255): a new page laid on the same
  /// spot as the last one.
  final double rearmContentChange;

  StreamSubscription<CameraFrame>? _frames;
  DateTime? _steadySince;
  Quad? _steadyQuad;
  Quad? _lastCaptured;
  List<int> _lastSignature = const <int>[];
  List<int> _capturedSignature = const <int>[];
  bool _armed = true;

  /// Checks the permission, then opens the camera.
  Future<void> start() async {
    final Either<CameraFailure, Unit> allowed = await _permissions.ensureCamera();
    if (isClosed) return;
    if (allowed.isLeft()) return _denied(allowed);
    final Either<CameraFailure, Unit> opened = await _camera.initialize();
    if (isClosed) return;
    if (opened.isLeft()) return _denied(opened);
    await _camera.setFlash(state.flash);
    if (isClosed) return;
    emit(state.copyWith(phase: CapturePhase.ready, hasFlash: _camera.hasFlash));
    _frames = _camera.frames.listen(_onFrame);
    _stillHere();
  }

  /// After the user comes back from settings or taps retry.
  Future<void> recheckPermission() => start();

  Future<void> openSettings() => _permissions.openSettings();

  void setMode(CaptureMode mode) {
    _sessions.setCaptureMode(mode);
    _resetSteady();
    _stillHere();
    emit(state.copyWith(mode: mode, hint: _idleHint(mode)));
  }

  Future<void> pauseCamera() => _camera.pause();

  /// Back from the background; a camera that paused itself, or that the
  /// corner step covers, stays paused.
  Future<void> resumeCamera() async {
    if (state.idle || state.cameraOff) return;
    await _camera.resume();
    _stillHere();
  }

  /// Manual capture; also what auto mode calls. A manual capture stops on the
  /// corner step first; an auto capture stores the page at once.
  Future<void> capture() async {
    if (state.idle) return;
    _stillHere();
    if (state.capturing ||
        state.limitReached ||
        state.phase != CapturePhase.ready ||
        state.replaced ||
        state.adjustFile != null) {
      return;
    }
    final bool adjust = state.mode == CaptureMode.manual;
    emit(state.copyWith(capturing: true));
    final Quad corners = state.quad ?? Quad.fullFrame;
    final Either<CameraFailure, File> shot = await _camera.takePicture();
    if (isClosed) return;
    await shot.fold(
      (CameraFailure _) async => emit(state.copyWith(capturing: false, phase: CapturePhase.unavailable)),
      (File file) async {
        final File? raw = await _keepRaw(file);
        if (raw == null || isClosed) return;
        // Like a scanner: find the page again on the full-resolution photo; the
        // live frame's corners are the fallback, the whole photo the last resort.
        final Quad found = await _edges.detectInPhoto(raw) ?? corners;
        if (isClosed) return;
        // Then which way is up: a page held sideways or upside down comes out
        // upright, from the direction of its text.
        final Future<int> turns = _edges.uprightTurns(raw, found);
        if (!adjust) {
          final int upright = await turns;
          if (isClosed) return;
          _straighten(raw, found, upright);
          return _store(raw, found, upright);
        }
        // The corner step opens at once; the page turns upright when that is
        // known, unless the user turned it first.
        _rotatedByHand = false;
        emit(
          state.copyWith(capturing: false, shots: state.shots + 1, adjustFile: raw, adjustQuad: found, adjustTurns: 0),
        );
        _offScreen();
        final int upright = await turns;
        if (isClosed || _rotatedByHand || state.adjustFile?.path != raw.path) return;
        emit(state.copyWith(adjustTurns: upright));
      },
    );
  }

  /// «حفظ الصفحة» on the corner step.
  Future<void> keepAdjusted(Quad corners) async {
    final File? raw = state.adjustFile;
    if (raw == null || state.capturing) return;
    _stillHere();
    final int turns = state.adjustTurns;
    emit(state.copyWith(capturing: true, adjustFile: null, adjustQuad: null, adjustTurns: 0));
    _onScreen();
    _straighten(raw, corners, turns);
    await _store(raw, corners, turns);
  }

  void _straighten(File raw, Quad corners, int turns) => emit(
    state.copyWith(
      straightenFile: raw,
      straightenQuad: corners,
      straightenTurns: turns,
      straightens: state.straightens + 1,
    ),
  );

  /// Camera switches run one after another, so a quick retake cannot reopen
  /// the camera while it is still closing.
  Future<void> _cameraSwitch = Future<void>.value();

  /// The corner step covers the camera: it closes until the step ends.
  void _offScreen() {
    _resetSteady();
    emit(state.copyWith(cameraOff: true, quad: null));
    _cameraSwitch = _cameraSwitch.then((_) => _camera.pause());
  }

  /// The camera is on screen again: it reopens, then the preview rebuilds.
  void _onScreen() {
    if (!state.cameraOff) return;
    _cameraSwitch = _cameraSwitch.then((_) async {
      await _camera.resume();
      if (!isClosed) emit(state.copyWith(cameraOff: false));
    });
  }

  /// «تدوير» on the corner step: a quarter turn counter-clockwise.
  void rotateAdjusted() {
    if (state.adjustFile == null) return;
    _stillHere();
    _rotatedByHand = true;
    emit(state.copyWith(adjustTurns: (state.adjustTurns + 3) % 4));
  }

  /// Set once the user turned the corner step's page; the found turns then no
  /// longer apply.
  bool _rotatedByHand = false;

  /// «إعادة الالتقاط» on the corner step: the photo is dropped.
  Future<void> retakeAdjusted() async {
    final File? raw = state.adjustFile;
    if (raw == null) return;
    _stillHere();
    emit(state.copyWith(adjustFile: null, adjustQuad: null, adjustTurns: 0));
    _onScreen();
    try {
      await raw.delete();
    } on FileSystemException catch (_) {}
  }

  /// Tells the session nothing; the flow decides between back-to-review and cancel.
  void cancelled() => _onEvent(DocScanEvent.cancelled(step: ScanStep.capture));

  /// Moves the camera's photo into the session folder.
  Future<File?> _keepRaw(File shot) async {
    final File raw = _sessions.newFile('jpg');
    try {
      await shot.copy(raw.path);
      await shot.delete();
    } on FileSystemException catch (e) {
      _storageError(e);
      return null;
    }
    return raw;
  }

  Future<void> _store(File raw, Quad corners, int turns) async {
    final File prepared = _sessions.newFile('jpg');
    final File ocr = _sessions.newFile('png');
    final Either<StorageFailure, Unit> ok = await _preparer.prepare(
      raw: raw,
      corners: corners,
      filters: const <PageFilter>{PageFilter.original},
      prepared: prepared,
      ocrInput: ocr,
      turns: turns,
    );
    if (isClosed) return;
    if (ok.isLeft()) return emit(state.copyWith(capturing: false, storageFull: true));

    final String? replacing = replacePageId;
    final CapturedPage page = CapturedPage(
      id: replacing ?? _sessions.newPageId(),
      rawFile: raw,
      corners: corners,
      filters: const <PageFilter>{PageFilter.original},
      turns: turns,
      preparedFile: prepared,
      ocrInputFile: ocr,
      recognition: const RecognitionState.pending(),
    );
    if (replacing != null) {
      final Either<StorageFailure, ScanSession> r = await _sessions.replacePage(page);
      if (r.isLeft()) return emit(state.copyWith(capturing: false, storageFull: true));
      _onEvent(DocScanEvent.pageRetaken());
    } else {
      _sessions.addPage(page);
    }
    _recognition.enqueue(page);

    final ScanSession s = _sessions.session;
    _lastCaptured = corners;
    _capturedSignature = _lastSignature;
    _armed = false;
    _resetSteady();
    _onEvent(DocScanEvent.pageCaptured(mode: state.mode, pageCount: s.pages.length));
    final bool limit = replacing == null && _atLimit(s);
    if (limit) _onEvent(DocScanEvent.pageLimitReached(maxPages: s.maxPages!));
    emit(
      state.copyWith(
        capturing: false,
        shots: state.mode == CaptureMode.manual ? state.shots : state.shots + 1,
        pageCount: s.pages.length,
        lastThumbnail: prepared,
        hint: state.mode == CaptureMode.auto ? CaptureHint.nextPage : CaptureHint.manual,
        limitReached: limit,
        replaced: replacing != null,
      ),
    );
  }

  Future<void> _onFrame(CameraFrame frame) async {
    if (state.capturing || state.phase != CapturePhase.ready || state.adjustFile != null) return;
    final FrameAnalysis a = await _edges.analyze(frame);
    if (isClosed || state.capturing) return;
    final Quad? q = a.quad;
    _lastSignature = a.signature;

    // After a capture, wait for something new: the page left, moved, or was
    // replaced by another page in the same place.
    if (!_armed &&
        (q == null ||
            (_lastCaptured != null && quadDistance(q, _lastCaptured!) > rearmDistance) ||
            signatureDistance(a.signature, _capturedSignature) > rearmContentChange)) {
      _armed = true;
      _resetSteady();
    }

    CaptureHint hint = state.pageCount > 0 && state.mode == CaptureMode.auto
        ? CaptureHint.nextPage
        : _idleHint(state.mode);
    if (q != null && a.luminance < minLuminance) {
      hint = CaptureHint.lowLight;
    } else if (q != null && a.sharpness < minSharpness) {
      hint = CaptureHint.holdSteady;
    }
    emit(state.copyWith(quad: q, hint: hint));

    if (state.mode != CaptureMode.auto || !_armed || q == null) return _resetSteady();
    if (a.luminance < minLuminance || a.sharpness < minSharpness) return _resetSteady();

    final Quad? prev = _steadyQuad;
    if (prev == null || quadDistance(prev, q) > steadyTolerance) {
      _steadyQuad = q;
      _steadySince = _now();
      return;
    }
    if (_now().difference(_steadySince!) >= steadyFor) await capture();
  }

  void _denied(Either<CameraFailure, Unit> failure) {
    final CameraFailure f = failure.fold((CameraFailure f) => f, (_) => const CameraFailure.unavailable());
    final CapturePhase phase = switch (f) {
      CameraPermissionDenied() => CapturePhase.denied,
      CameraPermanentlyDenied() => CapturePhase.permanentlyDenied,
      CameraUnavailable() => CapturePhase.unavailable,
    };
    if (phase == CapturePhase.denied) _onEvent(DocScanEvent.permissionDenied());
    if (phase == CapturePhase.permanentlyDenied) _onEvent(DocScanEvent.permissionPermanentlyDenied());
    emit(state.copyWith(phase: phase));
  }

  void _storageError(FileSystemException e) {
    emit(state.copyWith(capturing: false, storageFull: e.osError?.errorCode == 28));
  }

  void _resetSteady() {
    _steadyQuad = null;
    _steadySince = null;
  }

  static CaptureHint _idleHint(CaptureMode mode) => mode == CaptureMode.auto ? CaptureHint.auto : CaptureHint.manual;

  static bool _atLimit(ScanSession s) => s.maxPages != null && s.pages.length >= s.maxPages!;

  @override
  Future<void> close() async {
    _idle?.cancel();
    await _frames?.cancel();
    await _camera.dispose();
    return super.close();
  }
}
