import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../core/failures.dart';
import '../../core/session/scan_session.dart';

/// Layer 1 of the OCR service: one image pipeline that serves the page the user sees
/// and the hidden recognition input (FR-051, research R3).
///
/// On iOS the work runs on the GPU through Core Image (`preparePage` on the
/// `qanoniah_doc_scan/prep` channel): a page takes a fraction of a second. Where the
/// channel is missing (tests, other platforms) it falls back to the pure Dart
/// pipeline below over the `image` package (research R2/R3 revised 2026-11-03:
/// opencv_dart had no arm64 simulator build and added about 155 MB of static code).
class PagePreparer {
  const PagePreparer({
    this.maxLongEdge = 2200,
    this.jpegQuality = 90,
    this.native = true,
    MethodChannel channel = const MethodChannel('qanoniah_doc_scan/prep'),
  }) : _channel = channel;

  /// False forces the Dart pipeline (benchmarks, tests).
  final bool native;
  final MethodChannel _channel;

  /// Set once the platform has no native pipeline, so later pages skip the call.
  static bool _nativeMissing = false;

  /// Prepared pages are never larger than this; the size fitter may shrink further.
  final int maxLongEdge;
  final int jpegQuality;

  /// Warps [raw] to [corners], applies [filters] in a fixed order, and writes the
  /// visible page to [prepared] and the recognition input to [ocrInput].
  Future<Either<StorageFailure, Unit>> prepare({
    required File raw,
    required Quad corners,
    required Set<PageFilter> filters,
    required File prepared,
    required File ocrInput,
  }) async {
    final String rawPath = raw.path;
    final String preparedPath = prepared.path;
    final String ocrPath = ocrInput.path;
    final List<double> quad = _flatten(corners);
    final List<int> filterIndexes = filters.map((PageFilter f) => f.index).toList();
    final int longEdge = maxLongEdge;
    final int quality = jpegQuality;
    if (native && !_nativeMissing) {
      try {
        await _channel.invokeMapMethod<String, Object?>('preparePage', <String, Object>{
          'raw': rawPath,
          'quad': quad,
          'filters': filters.map((PageFilter f) => f.name).toList(),
          'prepared': preparedPath,
          'ocr': ocrPath,
          'maxLongEdge': longEdge,
          'quality': quality,
        });
        return const Right<StorageFailure, Unit>(unit);
      } on MissingPluginException {
        _nativeMissing = true;
      } on PlatformException {
        // Fall through to the Dart pipeline for this page.
      }
    }
    try {
      final bool ok = await Isolate.run(
        () => preparePage(rawPath, quad, filterIndexes, preparedPath, ocrPath, longEdge, quality),
      );
      return ok
          ? const Right<StorageFailure, Unit>(unit)
          : const Left<StorageFailure, Unit>(StorageFailure.unknown());
    } on FileSystemException catch (e) {
      return Left<StorageFailure, Unit>(
        e.osError?.errorCode == 28 ? const StorageFailure.full() : const StorageFailure.unknown(),
      );
    }
  }

  static List<double> _flatten(Quad q) => <double>[
    q.topLeft.dx, q.topLeft.dy, q.topRight.dx, q.topRight.dy, //
    q.bottomRight.dx, q.bottomRight.dy, q.bottomLeft.dx, q.bottomLeft.dy,
  ];
}

/// The pipeline itself; synchronous so the isolate and tests share it.
///
/// Filter order is fixed: shadows, auto, contrast, text, gray, black and white.
bool preparePage(
  String rawPath,
  List<double> quad,
  List<int> filterIndexes,
  String preparedPath,
  String ocrPath,
  int maxLongEdge,
  int jpegQuality,
) {
  final img.Image? decoded = img.decodeImage(File(rawPath).readAsBytesSync());
  if (decoded == null) return false;
  final Set<PageFilter> filters = filterIndexes.map((int i) => PageFilter.values[i]).toSet();

  img.Image page = warp(img.bakeOrientation(decoded), quad, maxLongEdge);
  if (filters.contains(PageFilter.removeShadows)) page = removeShadows(page);
  if (filters.contains(PageFilter.autoEnhance)) page = _sharpen(img.normalize(page, min: 0, max: 255), 0.5);
  if (filters.contains(PageFilter.highContrast)) page = img.contrast(page, contrast: 140);
  if (filters.contains(PageFilter.sharpenText)) page = _sharpen(page, 1.5);
  if (filters.contains(PageFilter.grayscale)) page = img.grayscale(page);
  if (filters.contains(PageFilter.blackWhite)) page = _toImage(adaptiveThreshold(luminanceOf(page), page.width, page.height), page.width, page.height);

  // The JPEG encoder mishandles one-channel images: write black and white as RGB.
  final img.Image visible = page.numChannels == 1 ? page.convert(numChannels: 3) : page;
  File(preparedPath).writeAsBytesSync(img.encodeJpg(visible, quality: jpegQuality), flush: true);

  // Recognition input: shadows removed and binarized on top of the user's filters.
  Uint8List gray = luminanceOf(page);
  if (!filters.contains(PageFilter.removeShadows)) gray = removeShadowsGray(gray, page.width, page.height);
  final Uint8List bw = adaptiveThreshold(gray, page.width, page.height);
  File(ocrPath).writeAsBytesSync(img.encodePng(_toImage(bw, page.width, page.height)), flush: true);
  return true;
}

/// Perspective-corrects [src] to the normalized [q] (tl, tr, br, bl).
img.Image warp(img.Image src, List<double> q, int maxLongEdge) {
  final double w = src.width.toDouble();
  final double h = src.height.toDouble();
  final List<math.Point<double>> p = <math.Point<double>>[
    for (int i = 0; i < 8; i += 2) math.Point<double>(q[i] * (w - 1), q[i + 1] * (h - 1)),
  ];
  // Corner distances count gaps between pixels; the page has one more pixel.
  double outW = math.max(p[0].distanceTo(p[1]), p[3].distanceTo(p[2])) + 1;
  double outH = math.max(p[0].distanceTo(p[3]), p[1].distanceTo(p[2])) + 1;
  final double? aspect = pageAspect(q, w, h);
  if (aspect != null) outW = outH * aspect;
  final double scale = math.min(1, maxLongEdge / math.max(outW, outH));
  final int ow = math.max(1, (outW * scale).round());
  final int oh = math.max(1, (outH * scale).round());
  img.Point pt(math.Point<double> v) => img.Point(v.x, v.y);
  return img.copyRectify(
    src,
    topLeft: pt(p[0]),
    topRight: pt(p[1]),
    bottomRight: pt(p[2]),
    bottomLeft: pt(p[3]),
    interpolation: img.Interpolation.linear,
    toImage: img.Image(width: ow, height: oh, numChannels: src.numChannels),
  );
}

/// The page's real width / height, recovered from the perspective of its corners
/// [q] (tl, tr, br, bl normalized) in a [w] x [h] photo, with the camera's focal
/// length estimated from the same corners (Zhang and He, "Whiteboard scanning
/// and image enhancement", 2007). When the corners cannot fix the focal length
/// (one edge pair parallel, or noise) a typical phone lens is assumed: about 0.75
/// of the long side. Null only for degenerate corners.
double? pageAspect(List<double> q, double w, double h) {
  final double u0 = w / 2;
  final double v0 = h / 2;
  List<double> m(int i) => <double>[q[i] * w, q[i + 1] * h, 1];
  final List<double> m1 = m(0); // tl
  final List<double> m2 = m(2); // tr
  final List<double> m3 = m(6); // bl
  final List<double> m4 = m(4); // br
  List<double> cross(List<double> a, List<double> b) =>
      <double>[a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  double dot(List<double> a, List<double> b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  final double d2 = dot(cross(m2, m4), m3);
  final double d3 = dot(cross(m3, m4), m2);
  if (d2.abs() < 1e-9 || d3.abs() < 1e-9) return null;
  final double k2 = dot(cross(m1, m4), m3) / d2;
  final double k3 = dot(cross(m1, m4), m2) / d3;
  final List<double> n2 = <double>[k2 * m2[0] - m1[0], k2 * m2[1] - m1[1], k2 * m2[2] - m1[2]];
  final List<double> n3 = <double>[k3 * m3[0] - m1[0], k3 * m3[1] - m1[1], k3 * m3[2] - m1[2]];
  final double fallback = 0.75 * math.max(w, h);
  final double f2 = -((n2[0] * n3[0] - (n2[0] * n3[2] + n2[2] * n3[0]) * u0 + n2[2] * n3[2] * u0 * u0) +
          (n2[1] * n3[1] - (n2[1] * n3[2] + n2[2] * n3[1]) * v0 + n2[2] * n3[2] * v0 * v0)) /
      (n2[2] * n3[2] == 0 ? 1e-12 : n2[2] * n3[2]);
  // With an edge pair (almost) parallel its vanishing point is at infinity and the
  // focal length is not observable; a value outside a phone's range means noise.
  bool parallel(List<double> n) => n[2].abs() * math.max(w, h) < 0.02 * math.sqrt(n[0] * n[0] + n[1] * n[1]);
  final double solved = !parallel(n2) && !parallel(n3) && f2.isFinite && f2 > 0 ? math.sqrt(f2) : 0;
  final double f = solved >= 0.5 * math.max(w, h) && solved <= 3 * math.max(w, h) ? solved : fallback;
  // (A^-T A^-1) n, with A the camera matrix.
  double norm(List<double> n) {
    final double x = (n[0] - u0 * n[2]) / f;
    final double y = (n[1] - v0 * n[2]) / f;
    return x * x + y * y + n[2] * n[2];
  }

  final double r = math.sqrt(norm(n2) / norm(n3));
  return r.isFinite && r > 0.2 && r < 5 ? r : null;
}

/// 8-bit luminance (Rec. 709) of every pixel, row-major.
Uint8List luminanceOf(img.Image src) {
  final Uint8List out = Uint8List(src.width * src.height);
  int i = 0;
  for (final img.Pixel p in src) {
    out[i++] = (0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b).round().clamp(0, 255);
  }
  return out;
}

/// The paper's brightness without the text: a heavy blur at 1/8 scale, read back
/// bilinearly. Dividing by it flattens shadows and uneven light.
Float32List _background(Uint8List gray, int w, int h) {
  const int f = 8;
  final int sw = math.max(1, w ~/ f);
  final int sh = math.max(1, h ~/ f);
  final img.Image small = img.Image(width: sw, height: sh, numChannels: 1);
  for (int y = 0; y < sh; y++) {
    for (int x = 0; x < sw; x++) {
      // Max over the block keeps the paper, not the ink.
      int m = 0;
      for (int dy = 0; dy < f && y * f + dy < h; dy++) {
        final int row = (y * f + dy) * w;
        for (int dx = 0; dx < f && x * f + dx < w; dx++) {
          final int v = gray[row + x * f + dx];
          if (v > m) m = v;
        }
      }
      small.setPixelR(x, y, m);
    }
  }
  final img.Image blurred = img.gaussianBlur(small, radius: 6);
  final Float32List bg = Float32List(w * h);
  for (int y = 0; y < h; y++) {
    final double sy = math.min(sh - 1.0, y / f);
    for (int x = 0; x < w; x++) {
      final double sx = math.min(sw - 1.0, x / f);
      bg[y * w + x] = math.max(1, blurred.getPixelLinear(sx, sy).r.toDouble());
    }
  }
  return bg;
}

Uint8List removeShadowsGray(Uint8List gray, int w, int h) {
  final Float32List bg = _background(gray, w, h);
  final Uint8List out = Uint8List(w * h);
  for (int i = 0; i < out.length; i++) {
    out[i] = (gray[i] * 255 / bg[i]).round().clamp(0, 255);
  }
  return out;
}

img.Image removeShadows(img.Image src) {
  final Float32List bg = _background(luminanceOf(src), src.width, src.height);
  final img.Image out = src.clone();
  int i = 0;
  for (final img.Pixel p in out) {
    final double k = 255 / bg[i++];
    p
      ..r = (p.r * k).clamp(0, 255)
      ..g = (p.g * k).clamp(0, 255)
      ..b = (p.b * k).clamp(0, 255);
  }
  return out;
}

/// Mean-of-window threshold over an integral image (window 31, offset 15).
Uint8List adaptiveThreshold(Uint8List gray, int w, int h, {int window = 31, int offset = 15}) {
  final Int64List sum = Int64List((w + 1) * (h + 1));
  for (int y = 0; y < h; y++) {
    int row = 0;
    for (int x = 0; x < w; x++) {
      row += gray[y * w + x];
      sum[(y + 1) * (w + 1) + x + 1] = sum[y * (w + 1) + x + 1] + row;
    }
  }
  final int r = window ~/ 2;
  final Uint8List out = Uint8List(w * h);
  for (int y = 0; y < h; y++) {
    final int y0 = math.max(0, y - r);
    final int y1 = math.min(h, y + r + 1);
    for (int x = 0; x < w; x++) {
      final int x0 = math.max(0, x - r);
      final int x1 = math.min(w, x + r + 1);
      final int s = sum[y1 * (w + 1) + x1] - sum[y0 * (w + 1) + x1] - sum[y1 * (w + 1) + x0] + sum[y0 * (w + 1) + x0];
      final int mean = s ~/ ((x1 - x0) * (y1 - y0));
      out[y * w + x] = gray[y * w + x] > mean - offset ? 255 : 0;
    }
  }
  return out;
}

img.Image _toImage(Uint8List gray, int w, int h) =>
    img.Image.fromBytes(width: w, height: h, bytes: gray.buffer, numChannels: 1);

img.Image _sharpen(img.Image src, double amount) =>
    img.convolution(src.clone(), filter: <num>[0, -1, 0, -1, 5, -1, 0, -1, 0], amount: amount);
