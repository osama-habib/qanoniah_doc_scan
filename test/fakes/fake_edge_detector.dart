import 'dart:io';

import 'package:qanoniah_doc_scan/src/capture/data/camera_source.dart';
import 'package:qanoniah_doc_scan/src/capture/data/edge_detector.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';

/// Returns [next] for every frame; tests change it between frames.
class FakeEdgeDetector implements EdgeDetector {
  FakeEdgeDetector(this.next);

  FrameAnalysis next;
  int analyzed = 0;

  @override
  Future<FrameAnalysis> analyze(CameraFrame frame) async {
    analyzed++;
    return next;
  }

  /// What [detectInPhoto] finds; null keeps the live corners.
  Quad? photoQuad;

  @override
  Future<Quad?> detectInPhoto(File photo) async => photoQuad;

  /// What [uprightTurns] reports.
  int turns = 0;

  @override
  Future<int> uprightTurns(File photo, Quad corners) async => turns;

  @override
  Future<void> dispose() async {}
}
