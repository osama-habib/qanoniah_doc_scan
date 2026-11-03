import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:dartz/dartz.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../../core/failures.dart';
import '../../core/session/scan_session.dart';

/// Layer 1 of the OCR service: one image pipeline that serves the page the user sees
/// and the hidden recognition input (FR-051, research R3).
///
/// Concrete on purpose (P5): tests that must not load OpenCV implement this class.
class PagePreparer {
  const PagePreparer({this.maxLongEdge = 2200, this.jpegQuality = 90});

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
    final bool ok = await Isolate.run(
      () => preparePage(rawPath, quad, filterIndexes, preparedPath, ocrPath, longEdge, quality),
    );
    return ok
        ? const Right<StorageFailure, Unit>(unit)
        : const Left<StorageFailure, Unit>(StorageFailure.unknown());
  }

  static List<double> _flatten(Quad q) => <double>[
    q.topLeft.dx, q.topLeft.dy, q.topRight.dx, q.topRight.dy, //
    q.bottomRight.dx, q.bottomRight.dy, q.bottomLeft.dx, q.bottomLeft.dy,
  ];
}

/// The pipeline itself; synchronous so the isolate and on-device tests share it.
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
  final cv.Mat src = cv.imread(rawPath);
  if (src.isEmpty) return false;
  final Set<PageFilter> filters = filterIndexes.map((int i) => PageFilter.values[i]).toSet();

  cv.Mat page = _warp(src, quad, maxLongEdge);
  if (filters.contains(PageFilter.removeShadows)) page = _removeShadows(page);
  if (filters.contains(PageFilter.autoEnhance)) page = _autoEnhance(page);
  if (filters.contains(PageFilter.highContrast)) page = _clahe(page);
  if (filters.contains(PageFilter.sharpenText)) page = _unsharp(page, 1.5);
  if (filters.contains(PageFilter.grayscale)) page = _gray(page);
  if (filters.contains(PageFilter.blackWhite)) page = _binarize(_gray(page));

  final cv.VecI32 params = cv.VecI32.fromList(<int>[cv.IMWRITE_JPEG_QUALITY, jpegQuality]);
  if (!cv.imwrite(preparedPath, page, params: params)) return false;

  // Recognition input: shadows removed and binarized on top of the user's filters.
  cv.Mat ocr = _gray(page);
  if (!filters.contains(PageFilter.removeShadows)) ocr = _removeShadows(ocr);
  ocr = _binarize(ocr);
  return cv.imwrite(ocrPath, ocr);
}

cv.Mat _warp(cv.Mat src, List<double> q, int maxLongEdge) {
  final double w = src.cols.toDouble();
  final double h = src.rows.toDouble();
  final List<cv.Point2f> pts = <cv.Point2f>[
    for (int i = 0; i < 8; i += 2) cv.Point2f(q[i] * w, q[i + 1] * h),
  ];
  double dist(cv.Point2f a, cv.Point2f b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
  double outW = math.max(dist(pts[0], pts[1]), dist(pts[3], pts[2]));
  double outH = math.max(dist(pts[0], pts[3]), dist(pts[1], pts[2]));
  final double scale = math.min(1, maxLongEdge / math.max(outW, outH));
  outW = (outW * scale).roundToDouble();
  outH = (outH * scale).roundToDouble();
  final cv.VecPoint2f from = cv.VecPoint2f.fromList(pts);
  final cv.VecPoint2f to = cv.VecPoint2f.fromList(<cv.Point2f>[
    cv.Point2f(0, 0),
    cv.Point2f(outW - 1, 0),
    cv.Point2f(outW - 1, outH - 1),
    cv.Point2f(0, outH - 1),
  ]);
  final cv.Mat m = cv.getPerspectiveTransform2f(from, to);
  return cv.warpPerspective(src, m, (outW.toInt(), outH.toInt()));
}

cv.Mat _gray(cv.Mat m) => m.channels == 1 ? m : cv.cvtColor(m, cv.COLOR_BGR2GRAY);

/// Divides each channel by a closing-based background estimate.
cv.Mat _removeShadows(cv.Mat m) {
  final cv.Mat kernel = cv.getStructuringElement(cv.MORPH_RECT, (25, 25));
  cv.Mat one(cv.Mat ch) {
    final cv.Mat bg = cv.medianBlur(cv.morphologyEx(ch, cv.MORPH_DILATE, kernel), 21);
    return cv.divide(ch, bg, scale: 255);
  }

  if (m.channels == 1) return one(m);
  final cv.VecMat chans = cv.split(m);
  return cv.merge(cv.VecMat.fromList(chans.map(one).toList()));
}

cv.Mat _autoEnhance(cv.Mat m) {
  final cv.Mat stretched = cv.normalize(m, cv.Mat.empty(), alpha: 0, beta: 255, normType: cv.NORM_MINMAX);
  return _unsharp(stretched, 0.5);
}

cv.Mat _clahe(cv.Mat m) {
  final cv.CLAHE clahe = cv.CLAHE(2.0, (8, 8));
  if (m.channels == 1) return clahe.apply(m);
  final cv.VecMat lab = cv.split(cv.cvtColor(m, cv.COLOR_BGR2Lab));
  final List<cv.Mat> parts = lab.toList();
  parts[0] = clahe.apply(parts[0]);
  return cv.cvtColor(cv.merge(cv.VecMat.fromList(parts)), cv.COLOR_Lab2BGR);
}

cv.Mat _unsharp(cv.Mat m, double amount) {
  final cv.Mat blur = cv.gaussianBlur(m, (0, 0), 3);
  return cv.addWeighted(m, 1 + amount, blur, -amount, 0);
}

cv.Mat _binarize(cv.Mat gray) =>
    cv.adaptiveThreshold(gray, 255, cv.ADAPTIVE_THRESH_GAUSSIAN_C, cv.THRESH_BINARY, 31, 15);
