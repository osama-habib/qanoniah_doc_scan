import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

/// [EdgeDetector] in pure Dart, off the UI isolate; the same code on every device
/// and simulator (research R2 revised 2026-11-03).
///
/// A page is the largest bright region of the frame: Otsu threshold on a 160 px
/// copy, the largest connected component, and its four extreme corners. It is
/// accepted only when it covers [minAreaRatio] of the frame and fills its own
/// quadrilateral. Frames that arrive while one is being analyzed get the previous
/// result, so the camera never queues work.
class DartEdgeDetector implements EdgeDetector {
  DartEdgeDetector({this.minAreaRatio = 0.2});

  final double minAreaRatio;
  bool _busy = false;
  FrameAnalysis _last = const FrameAnalysis(
    quad: null,
    sharpness: 0,
    luminance: 0,
  );

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

/// [EdgeDetector] on iOS: Apple Vision's rectangle detector finds the page, and the
/// shared Dart code measures sharpness and light. Falls back to [DartEdgeDetector]
/// when the channel is unavailable.
class VisionEdgeDetector implements EdgeDetector {
  VisionEdgeDetector({MethodChannel? channel, DartEdgeDetector? fallback})
    : _channel =
          channel ?? const MethodChannel('qanoniah_doc_scan/recognition'),
      _fallback = fallback ?? DartEdgeDetector();

  final MethodChannel _channel;
  final DartEdgeDetector _fallback;
  bool _busy = false;
  bool _useFallback = false;
  FrameAnalysis _last = const FrameAnalysis(
    quad: null,
    sharpness: 0,
    luminance: 0,
  );

  @override
  Future<FrameAnalysis> analyze(CameraFrame frame) async {
    if (_useFallback) return _fallback.analyze(frame);
    if (_busy) return _last;
    _busy = true;
    try {
      final Uint8List bytes = frame.luminance;
      final int w = frame.width;
      final int h = frame.height;
      final Future<(double, double)> stats = Isolate.run(
        () => frameStats(bytes, w, h),
      );
      final List<Object?>? corners = await _channel.invokeListMethod<Object?>(
        'detectRectangle',
        <String, Object>{'bytes': bytes, 'width': w, 'height': h},
      );
      final (double sharpness, double luminance) = await stats;
      Quad? quad;
      if (corners != null && corners.length == 8) {
        final List<double> c = corners
            .map((Object? v) => (v as num?)?.toDouble() ?? 0)
            .toList();
        quad = orderCorners(<Offset>[
          for (int i = 0; i < 8; i += 2) Offset(c[i], c[i + 1]),
        ]);
      }
      return _last = FrameAnalysis(
        quad: quad,
        sharpness: sharpness,
        luminance: luminance,
      );
    } on MissingPluginException {
      _useFallback = true;
      return _fallback.analyze(frame);
    } on PlatformException {
      _useFallback = true;
      return _fallback.analyze(frame);
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> dispose() => _fallback.dispose();
}

/// Variance of the Laplacian (sharpness) and mean luminance of a frame.
(double, double) frameStats(Uint8List g, int w, int h) {
  double sum = 0;
  double sumSq = 0;
  int n = 0;
  int total = 0;
  for (int i = 0; i < g.length; i++) {
    total += g[i];
  }
  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      final int i = y * w + x;
      final int lap = g[i - 1] + g[i + 1] + g[i - w] + g[i + w] - 4 * g[i];
      sum += lap;
      sumSq += lap * lap;
      n++;
    }
  }
  final double mean = n == 0 ? 0 : sum / n;
  return (
    n == 0 ? 0 : sumSq / n - mean * mean,
    g.isEmpty ? 0 : total / g.length,
  );
}

/// The detection itself; synchronous so tests and the isolate share it.
FrameAnalysis analyzeLuminance(
  Uint8List bytes,
  int width,
  int height,
  double minAreaRatio,
) {
  final (double sharpness, double luminance) = frameStats(bytes, width, height);

  // A small copy: the page outline needs no detail.
  final int step = math.max(1, (math.max(width, height) / 160).ceil());
  final int sw = width ~/ step;
  final int sh = height ~/ step;
  final Uint8List small = Uint8List(sw * sh);
  for (int y = 0; y < sh; y++) {
    for (int x = 0; x < sw; x++) {
      small[y * sw + x] = bytes[(y * step) * width + x * step];
    }
  }

  // Otsu's threshold.
  final List<int> hist = List<int>.filled(256, 0);
  for (final int v in small) {
    hist[v]++;
  }
  final int total = small.length;
  double sumAll = 0;
  for (int i = 0; i < 256; i++) {
    sumAll += i * hist[i];
  }
  double sumB = 0;
  int wB = 0;
  double best = -1;
  int threshold = 128;
  for (int t = 0; t < 256; t++) {
    wB += hist[t];
    if (wB == 0) continue;
    final int wF = total - wB;
    if (wF == 0) break;
    sumB += t * hist[t];
    final double mB = sumB / wB;
    final double mF = (sumAll - sumB) / wF;
    final double between = wB * wF * (mB - mF) * (mB - mF);
    if (between > best) {
      best = between;
      threshold = t;
    }
  }

  // Largest bright 4-connected component.
  final Int32List label = Int32List(sw * sh);
  final List<int> stack = <int>[];
  int bestLabel = 0;
  int bestSize = 0;
  int next = 0;
  for (int start = 0; start < small.length; start++) {
    if (small[start] <= threshold || label[start] != 0) continue;
    next++;
    int size = 0;
    stack.add(start);
    label[start] = next;
    while (stack.isNotEmpty) {
      final int i = stack.removeLast();
      size++;
      final int x = i % sw;
      final int y = i ~/ sw;
      for (final int j in <int>[
        if (x > 0) i - 1,
        if (x < sw - 1) i + 1,
        if (y > 0) i - sw,
        if (y < sh - 1) i + sw,
      ]) {
        if (label[j] == 0 && small[j] > threshold) {
          label[j] = next;
          stack.add(j);
        }
      }
    }
    if (size > bestSize) {
      bestSize = size;
      bestLabel = next;
    }
  }

  Quad? quad;
  if (bestSize >= sw * sh * minAreaRatio) {
    Offset tl = const Offset(double.infinity, 0),
        br = const Offset(-double.infinity, 0);
    Offset tr = const Offset(-double.infinity, 0),
        bl = const Offset(double.infinity, 0);
    double tlS = double.infinity,
        brS = -double.infinity,
        trS = -double.infinity,
        blS = double.infinity;
    for (int i = 0; i < label.length; i++) {
      if (label[i] != bestLabel) continue;
      final double x = (i % sw).toDouble();
      final double y = (i ~/ sw).toDouble();
      if (x + y < tlS) {
        tlS = x + y;
        tl = Offset(x, y);
      }
      if (x + y > brS) {
        brS = x + y;
        br = Offset(x, y);
      }
      if (x - y > trS) {
        trS = x - y;
        tr = Offset(x, y);
      }
      if (x - y < blS) {
        blS = x - y;
        bl = Offset(x, y);
      }
    }
    final double area =
        0.5 *
        ((tl.dx * tr.dy - tr.dx * tl.dy) +
                (tr.dx * br.dy - br.dx * tr.dy) +
                (br.dx * bl.dy - bl.dx * br.dy) +
                (bl.dx * tl.dy - tl.dx * bl.dy))
            .abs();
    // The region must fill its quadrilateral, or it is not a page.
    if (area > 0 && bestSize / area >= 0.85 && area >= sw * sh * minAreaRatio) {
      Offset n(Offset p) =>
          Offset(p.dx / math.max(1, sw - 1), p.dy / math.max(1, sh - 1));
      quad = Quad(
        topLeft: n(tl),
        topRight: n(tr),
        bottomRight: n(br),
        bottomLeft: n(bl),
      );
    }
  }
  return FrameAnalysis(quad: quad, sharpness: sharpness, luminance: luminance);
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
