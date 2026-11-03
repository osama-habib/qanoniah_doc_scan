import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../../core/session/scan_session.dart';
import 'camera_source.dart';

/// What one frame shows: the page corners, if any, and whether the frame is good
/// enough to capture (FR-003).
@immutable
class FrameAnalysis {
  const FrameAnalysis({
    required this.quad,
    required this.sharpness,
    required this.luminance,
  });

  /// Null when no page edges were found.
  final Quad? quad;

  /// Variance of the Laplacian; higher is sharper.
  final double sharpness;

  /// Mean luminance, 0 to 255.
  final double luminance;
}

/// Live page-edge detection, behind a port so capture logic is testable without
/// image processing (constitution P5).
abstract interface class EdgeDetector {
  Future<FrameAnalysis> analyze(CameraFrame frame);
  Future<void> dispose();
}

/// [EdgeDetector] over OpenCV, run off the UI isolate (research R2).
///
/// Per frame: blur, Canny, contours, and the largest convex quadrilateral covering at
/// least [minAreaRatio] of the frame. Frames that arrive while one is being analyzed
/// get the previous result, so the camera never queues work.
class OpenCvEdgeDetector implements EdgeDetector {
  OpenCvEdgeDetector({this.minAreaRatio = 0.2});

  final double minAreaRatio;
  bool _busy = false;
  FrameAnalysis _last = const FrameAnalysis(quad: null, sharpness: 0, luminance: 0);

  @override
  Future<FrameAnalysis> analyze(CameraFrame frame) async {
    if (_busy) return _last;
    _busy = true;
    try {
      final Uint8List bytes = frame.luminance;
      final int w = frame.width;
      final int h = frame.height;
      final double ratio = minAreaRatio;
      _last = await Isolate.run(() => analyzeLuminance(bytes, w, h, ratio));
      return _last;
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> dispose() async {}
}

/// The detection itself; synchronous so tests and the isolate share it.
FrameAnalysis analyzeLuminance(Uint8List bytes, int width, int height, double minAreaRatio) {
  final cv.Mat gray = cv.Mat.fromList(height, width, cv.MatType.CV_8UC1, bytes);
  final cv.Mat lap = cv.laplacian(gray, cv.MatType.CV_64F);
  final (cv.Scalar _, cv.Scalar lapStd) = cv.meanStdDev(lap);
  final double sharpness = lapStd.val1 * lapStd.val1;
  final double luminance = cv.mean(gray).val1;

  final cv.Mat blurred = cv.gaussianBlur(gray, (5, 5), 0);
  final cv.Mat edges = cv.canny(blurred, 50, 150);
  final cv.Mat closed = cv.morphologyEx(
    edges,
    cv.MORPH_CLOSE,
    cv.getStructuringElement(cv.MORPH_RECT, (5, 5)),
  );
  final (cv.Contours contours, cv.VecVec4i _) =
      cv.findContours(closed, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);

  final double minArea = width * height * minAreaRatio;
  cv.VecPoint? best;
  double bestArea = 0;
  for (final cv.VecPoint c in contours) {
    final double peri = cv.arcLength(c, true);
    final cv.VecPoint approx = cv.approxPolyDP(c, 0.02 * peri, true);
    if (approx.length != 4 || !cv.isContourConvex(approx)) continue;
    final double area = cv.contourArea(approx);
    if (area >= minArea && area > bestArea) {
      bestArea = area;
      best = approx;
    }
  }
  return FrameAnalysis(
    quad: best == null ? null : orderCorners(best.map((cv.Point p) => Offset(p.x / width, p.y / height)).toList()),
    sharpness: sharpness,
    luminance: luminance,
  );
}

/// Orders four normalized points as top-left, top-right, bottom-right, bottom-left.
Quad orderCorners(List<Offset> pts) {
  Offset by(double Function(Offset) score, bool max) =>
      pts.reduce((Offset a, Offset b) => (score(a) > score(b)) == max ? a : b);
  return Quad(
    topLeft: by((Offset p) => p.dx + p.dy, false),
    bottomRight: by((Offset p) => p.dx + p.dy, true),
    topRight: by((Offset p) => p.dx - p.dy, true),
    bottomLeft: by((Offset p) => p.dx - p.dy, false),
  );
}

/// Largest corner movement between two quads, in normalized units.
double quadDistance(Quad a, Quad b) => <double>[
  (a.topLeft - b.topLeft).distance,
  (a.topRight - b.topRight).distance,
  (a.bottomRight - b.bottomRight).distance,
  (a.bottomLeft - b.bottomLeft).distance,
].reduce(math.max);
