import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/failures.dart';

/// One downscaled luminance frame from the live preview, for edge detection.
@immutable
class CameraFrame {
  const CameraFrame({
    required this.luminance,
    required this.width,
    required this.height,
  });

  /// One byte per pixel, row-major, `width * height` long.
  final Uint8List luminance;
  final int width;
  final int height;
}

/// The camera, behind a port so capture logic is testable without hardware
/// (constitution P5).
abstract interface class CameraSource {
  Future<Either<CameraFailure, Unit>> initialize();

  /// The live preview. Only valid after [initialize] succeeds.
  Widget preview();

  /// Downscaled frames for edge detection, while not paused.
  Stream<CameraFrame> get frames;

  /// A full-resolution still, written to a file the caller owns.
  Future<Either<CameraFailure, File>> takePicture();

  /// Releases the camera while the app is in the background.
  Future<void> pause();
  Future<void> resume();
  Future<void> dispose();
}

/// [CameraSource] over the `camera` plugin (research R2).
///
/// Frames are the Y plane of the YUV stream, rotated upright by the sensor
/// orientation and subsampled to [frameLongEdge], so the detected corners use the
/// same upright coordinates as the preview and the still.
class CameraPluginSource implements CameraSource {
  CameraPluginSource({this.frameLongEdge = 640, this.minFrameGap = const Duration(milliseconds: 110)});

  final int frameLongEdge;

  /// Frames closer together are dropped; about 8 to 9 per second.
  final Duration minFrameGap;

  final StreamController<CameraFrame> _frames = StreamController<CameraFrame>.broadcast();
  CameraController? _controller;
  CameraDescription? _description;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  bool _streaming = false;

  @override
  Future<Either<CameraFailure, Unit>> initialize() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) return const Left<CameraFailure, Unit>(CameraFailure.unavailable());
      _description = cameras.firstWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      await _open();
      return const Right<CameraFailure, Unit>(unit);
    } on CameraException catch (e) {
      return Left<CameraFailure, Unit>(_map(e));
    } on PlatformException {
      return const Left<CameraFailure, Unit>(CameraFailure.unavailable());
    }
  }

  Future<void> _open() async {
    final CameraController c = CameraController(
      _description!,
      // 1080p is enough for an A4 page and keeps Dart decoding fast.
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await c.initialize();
    await c.setFlashMode(FlashMode.off);
    await c.lockCaptureOrientation(DeviceOrientation.portraitUp);
    _controller = c;
    await _startStream();
  }

  @override
  Widget preview() {
    final CameraController? c = _controller;
    if (c == null || !c.value.isInitialized) return const SizedBox.expand();
    return CameraPreview(c);
  }

  @override
  Stream<CameraFrame> get frames => _frames.stream;

  @override
  Future<Either<CameraFailure, File>> takePicture() async {
    final CameraController? c = _controller;
    if (c == null) return const Left<CameraFailure, File>(CameraFailure.unavailable());
    try {
      await _stopStream();
      final XFile shot = await c.takePicture();
      await _startStream();
      return Right<CameraFailure, File>(File(shot.path));
    } on CameraException catch (e) {
      await _startStream();
      return Left<CameraFailure, File>(_map(e));
    }
  }

  @override
  Future<void> pause() async {
    final CameraController? c = _controller;
    _controller = null;
    _streaming = false;
    await c?.dispose();
  }

  @override
  Future<void> resume() async {
    if (_controller != null || _description == null) return;
    try {
      await _open();
    } on CameraException {
      // The sheet shows the unavailable state on the next capture attempt.
    }
  }

  @override
  Future<void> dispose() async {
    await pause();
    await _frames.close();
  }

  Future<void> _startStream() async {
    final CameraController? c = _controller;
    if (c == null || _streaming) return;
    _streaming = true;
    await c.startImageStream(_onImage);
  }

  Future<void> _stopStream() async {
    final CameraController? c = _controller;
    if (c == null || !_streaming) return;
    _streaming = false;
    await c.stopImageStream();
  }

  void _onImage(CameraImage image) {
    final DateTime now = DateTime.now();
    if (now.difference(_lastFrame) < minFrameGap || !_frames.hasListener) return;
    _lastFrame = now;
    // The UI is locked to portrait. iOS already delivers upright frames once the
    // capture orientation is locked; Android delivers them in sensor orientation.
    // Rotating only a landscape frame handles both.
    final int rotation = image.width > image.height ? (_description?.sensorOrientation ?? 0) : 0;
    _frames.add(_downscale(image.planes.first, image.width, image.height, rotation));
  }

  /// Subsamples the luminance plane and rotates it upright.
  CameraFrame _downscale(Plane y, int width, int height, int rotation) {
    final int step = math.max(1, (math.max(width, height) / frameLongEdge).ceil());
    final int sw = width ~/ step;
    final int sh = height ~/ step;
    final bool swap = rotation == 90 || rotation == 270;
    final int ow = swap ? sh : sw;
    final int oh = swap ? sw : sh;
    final Uint8List out = Uint8List(ow * oh);
    final Uint8List src = y.bytes;
    final int stride = y.bytesPerRow;
    for (int sy = 0; sy < sh; sy++) {
      final int row = sy * step * stride;
      for (int sx = 0; sx < sw; sx++) {
        final int v = src[row + sx * step];
        final int dx;
        final int dy;
        switch (rotation) {
          case 90:
            dx = sh - 1 - sy;
            dy = sx;
          case 180:
            dx = sw - 1 - sx;
            dy = sh - 1 - sy;
          case 270:
            dx = sy;
            dy = sw - 1 - sx;
          default:
            dx = sx;
            dy = sy;
        }
        out[dy * ow + dx] = v;
      }
    }
    return CameraFrame(luminance: out, width: ow, height: oh);
  }

  static CameraFailure _map(CameraException e) => switch (e.code) {
    'CameraAccessDenied' || 'cameraPermission' => const CameraFailure.permissionDenied(),
    'CameraAccessDeniedWithoutPrompt' || 'CameraAccessRestricted' =>
      const CameraFailure.permanentlyDenied(),
    _ => const CameraFailure.unavailable(),
  };
}
