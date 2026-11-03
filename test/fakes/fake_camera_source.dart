import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/widgets.dart';
import 'package:qanoniah_doc_scan/src/capture/data/camera_source.dart';
import 'package:qanoniah_doc_scan/src/core/failures.dart';

/// Camera with scripted frames and stills written into [outDir].
class FakeCameraSource implements CameraSource {
  FakeCameraSource({required this.outDir, this.initResult});

  final Directory outDir;

  /// Null initializes successfully.
  final CameraFailure? initResult;
  final StreamController<CameraFrame> _frames =
      StreamController<CameraFrame>.broadcast();
  int pictures = 0;
  bool paused = false;
  bool disposed = false;

  void emit(CameraFrame frame) => _frames.add(frame);

  @override
  Future<Either<CameraFailure, Unit>> initialize() async {
    final CameraFailure? f = initResult;
    return f == null ? const Right<CameraFailure, Unit>(unit) : Left<CameraFailure, Unit>(f);
  }

  @override
  Widget preview() => const SizedBox.expand();

  @override
  Stream<CameraFrame> get frames => _frames.stream;

  @override
  Future<Either<CameraFailure, File>> takePicture() async {
    pictures++;
    final File f = File('${outDir.path}/shot_$pictures.jpg')
      ..writeAsBytesSync(<int>[0xFF, 0xD8, 0xFF, 0xD9]);
    return Right<CameraFailure, File>(f);
  }

  @override
  Future<void> pause() async => paused = true;

  @override
  Future<void> resume() async => paused = false;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _frames.close();
  }
}
