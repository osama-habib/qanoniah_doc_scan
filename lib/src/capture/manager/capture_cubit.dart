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

  StreamSubscription<CameraFrame>? _frames;
  DateTime? _steadySince;
  Quad? _steadyQuad;
  Quad? _lastCaptured;
  bool _armed = true;

  /// Checks the permission, then opens the camera.
  Future<void> start() async {
    final Either<CameraFailure, Unit> allowed = await _permissions.ensureCamera();
    if (isClosed) return;
    if (allowed.isLeft()) return _denied(allowed);
    final Either<CameraFailure, Unit> opened = await _camera.initialize();
    if (isClosed) return;
    if (opened.isLeft()) return _denied(opened);
    emit(state.copyWith(phase: CapturePhase.ready));
    _frames = _camera.frames.listen(_onFrame);
  }

  /// After the user comes back from settings or taps retry.
  Future<void> recheckPermission() => start();

  Future<void> openSettings() => _permissions.openSettings();

  void setMode(CaptureMode mode) {
    _sessions.setCaptureMode(mode);
    _resetSteady();
    emit(state.copyWith(mode: mode, hint: _idleHint(mode)));
  }

  Future<void> pauseCamera() => _camera.pause();
  Future<void> resumeCamera() => _camera.resume();

  /// Manual capture; also what auto mode calls.
  Future<void> capture() async {
    if (state.capturing || state.limitReached || state.phase != CapturePhase.ready || state.replaced) {
      return;
    }
    emit(state.copyWith(capturing: true));
    final Quad corners = state.quad ?? Quad.fullFrame;
    final Either<CameraFailure, File> shot = await _camera.takePicture();
    if (isClosed) return;
    await shot.fold(
      (CameraFailure _) async => emit(state.copyWith(capturing: false, phase: CapturePhase.unavailable)),
      (File file) => _store(file, corners),
    );
  }

  /// Tells the session nothing; the flow decides between back-to-review and cancel.
  void cancelled() => _onEvent(DocScanEvent.cancelled(step: ScanStep.capture));

  Future<void> _store(File shot, Quad corners) async {
    final File raw = _sessions.newFile('jpg');
    try {
      await shot.copy(raw.path);
      await shot.delete();
    } on FileSystemException catch (e) {
      return _storageError(e);
    }
    final File prepared = _sessions.newFile('jpg');
    final File ocr = _sessions.newFile('png');
    final Either<StorageFailure, Unit> ok = await _preparer.prepare(
      raw: raw,
      corners: corners,
      filters: const <PageFilter>{PageFilter.original},
      prepared: prepared,
      ocrInput: ocr,
    );
    if (isClosed) return;
    if (ok.isLeft()) return emit(state.copyWith(capturing: false, storageFull: true));

    final String? replacing = replacePageId;
    final CapturedPage page = CapturedPage(
      id: replacing ?? _sessions.newPageId(),
      rawFile: raw,
      corners: corners,
      filters: const <PageFilter>{PageFilter.original},
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
    _armed = false;
    _resetSteady();
    _onEvent(DocScanEvent.pageCaptured(mode: state.mode, pageCount: s.pages.length));
    final bool limit = replacing == null && _atLimit(s);
    if (limit) _onEvent(DocScanEvent.pageLimitReached(maxPages: s.maxPages!));
    emit(
      state.copyWith(
        capturing: false,
        shots: state.shots + 1,
        pageCount: s.pages.length,
        lastThumbnail: prepared,
        hint: state.mode == CaptureMode.auto ? CaptureHint.nextPage : CaptureHint.manual,
        limitReached: limit,
        replaced: replacing != null,
      ),
    );
  }

  Future<void> _onFrame(CameraFrame frame) async {
    if (state.capturing || state.phase != CapturePhase.ready) return;
    final FrameAnalysis a = await _edges.analyze(frame);
    if (isClosed || state.capturing) return;
    final Quad? q = a.quad;

    if (!_armed && (q == null || (_lastCaptured != null && quadDistance(q, _lastCaptured!) > rearmDistance))) {
      _armed = true;
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

  static CaptureHint _idleHint(CaptureMode mode) =>
      mode == CaptureMode.auto ? CaptureHint.auto : CaptureHint.manual;

  static bool _atLimit(ScanSession s) => s.maxPages != null && s.pages.length >= s.maxPages!;

  @override
  Future<void> close() async {
    await _frames?.cancel();
    await _camera.dispose();
    return super.close();
  }
}
