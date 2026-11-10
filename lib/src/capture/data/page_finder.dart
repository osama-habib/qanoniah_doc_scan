import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../core/session/scan_session.dart';

/// Finds a document page in a luminance image the way a scanner app does: the
/// page's four sides as straight edges, not the brightest blob.
///
/// 1. Canny on a small copy ([work] px on the long side): Gaussian blur, Sobel,
///    thin edges, two thresholds from the image's own gradients.
/// 2. Hough lines, each edge pixel voting only near its gradient's direction.
/// 3. Every pair of near-horizontal lines with every pair of near-vertical ones
///    makes a candidate page. A candidate scores by how much of each side has a
///    real edge on it, darker outside than inside (a sheet on a table, or the
///    top sheet of a stack over its shadow), so a page with four whole sides
///    wins over the outline of a stack or a table's edge.
/// 4. Each winning side is refit to its own edge points, then to the strongest
///    gradient across it on the full image, and the corners are where the sides
///    meet: precise even where a corner is folded, cut, or under a finger.
///
/// Returns the corners normalized to the image (0 to 1), clockwise from the top
/// left, or null when no candidate covers [minAreaRatio] of the image.
Quad? findPage(
  Uint8List gray,
  int width,
  int height, {
  double minAreaRatio = 0.2,
  int work = 320,
  @visibleForTesting void Function(String)? trace,
}) {
  if (width < 16 || height < 16 || gray.length < width * height) return null;
  final double scale = math.max(width, height) / work;
  final _Image small = scale > 1 ? _shrink(gray, width, height, scale) : _Image(gray, width, height);
  final _Edges edges = _canny(small);
  trace?.call('edges ${edges.count} on ${small.width}x${small.height}');
  if (edges.count < 20) return null;
  final List<_Line> lines = _hough(edges);
  trace?.call(
    'lines ${lines.length}: ${lines.map((_Line l) => '${(l.theta * 180 / math.pi).round()}°/${l.rho.round()}/${l.votes.round()}').join(' ')}',
  );
  if (lines.length < 4) return null;
  final _Candidate? best = _bestQuad(edges, lines, minAreaRatio);
  trace?.call('best ${best?.score.toStringAsFixed(3)} ${best?.corners}');
  if (best == null) return null;

  // Refit each side on the small image, then on the full one.
  final List<_Line> sides = <_Line>[for (int s = 0; s < 4; s++) _refitOnEdges(edges, best, s) ?? best.sides[s]];
  final List<Offset> smallCorners = _corners(sides) ?? best.corners;
  final double up = width / small.width;
  final List<_Line> full = <_Line>[
    for (int s = 0; s < 4; s++)
      _refitOnGradient(gray, width, height, sides[s].scaled(up), _scaled(smallCorners, up), s, up) ??
          sides[s].scaled(up),
  ];
  final List<Offset> fromCandidate = _normalized(best.corners, small.width, small.height);
  final List<Offset>? refined = _corners(full);
  if (refined == null) return _quad(fromCandidate);
  final List<Offset> n = _normalized(refined, width, height);
  // A refit that moved a corner far from the candidate is not trusted.
  for (int i = 0; i < 4; i++) {
    if ((n[i] - fromCandidate[i]).distance > 0.04) return _quad(fromCandidate);
  }
  return _quad(n);
}

List<Offset> _scaled(List<Offset> pts, double f) => <Offset>[for (final Offset p in pts) p * f];

List<Offset> _normalized(List<Offset> pts, int w, int h) => <Offset>[
  for (final Offset c in pts) Offset((c.dx / (w - 1)).clamp(0.0, 1.0), (c.dy / (h - 1)).clamp(0.0, 1.0)),
];

Quad _quad(List<Offset> c) => Quad(topLeft: c[0], topRight: c[1], bottomRight: c[2], bottomLeft: c[3]);

class _Image {
  _Image(this.px, this.width, this.height);
  final Uint8List px;
  final int width;
  final int height;
}

/// Box-averaged copy, [scale] times smaller.
_Image _shrink(Uint8List gray, int width, int height, double scale) {
  final int w = math.max(1, (width / scale).round());
  final int h = math.max(1, (height / scale).round());
  final Uint8List out = Uint8List(w * h);
  for (int y = 0; y < h; y++) {
    final int y0 = (y * height) ~/ h;
    final int y1 = math.max(y0 + 1, ((y + 1) * height) ~/ h);
    for (int x = 0; x < w; x++) {
      final int x0 = (x * width) ~/ w;
      final int x1 = math.max(x0 + 1, ((x + 1) * width) ~/ w);
      int sum = 0;
      for (int yy = y0; yy < y1; yy++) {
        final int row = yy * width;
        for (int xx = x0; xx < x1; xx++) {
          sum += gray[row + xx];
        }
      }
      out[y * w + x] = sum ~/ ((y1 - y0) * (x1 - x0));
    }
  }
  return _Image(out, w, h);
}

class _Edges {
  _Edges(this.width, this.height, this.on, this.gx, this.gy, this.lum, this.count);
  final int width;
  final int height;

  /// 1 on a thin edge pixel.
  final Uint8List on;
  final Float32List gx;
  final Float32List gy;

  /// The blurred image.
  final Float32List lum;
  final int count;

  bool edgeAt(int x, int y) => x >= 0 && y >= 0 && x < width && y < height && on[y * width + x] == 1;
}

/// Canny: blur, Sobel, non-maximum suppression, hysteresis.
_Edges _canny(_Image im) {
  final int w = im.width, h = im.height, n = w * h;
  // 5 x 5 binomial blur (about a 1.1 px Gaussian), separable.
  const List<double> k = <double>[1 / 16, 4 / 16, 6 / 16, 4 / 16, 1 / 16];
  final Float32List tmp = Float32List(n);
  final Float32List lum = Float32List(n);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      double s = 0;
      for (int i = -2; i <= 2; i++) {
        s += k[i + 2] * im.px[y * w + (x + i).clamp(0, w - 1)];
      }
      tmp[y * w + x] = s;
    }
  }
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      double s = 0;
      for (int i = -2; i <= 2; i++) {
        s += k[i + 2] * tmp[(y + i).clamp(0, h - 1) * w + x];
      }
      lum[y * w + x] = s;
    }
  }
  final Float32List gx = Float32List(n);
  final Float32List gy = Float32List(n);
  final Float32List mag = Float32List(n);
  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      final int i = y * w + x;
      final double a = lum[i - w - 1], b = lum[i - w], c = lum[i - w + 1];
      final double d = lum[i - 1], f = lum[i + 1];
      final double g = lum[i + w - 1], hh = lum[i + w], j = lum[i + w + 1];
      final double sx = (c + 2 * f + j) - (a + 2 * d + g);
      final double sy = (g + 2 * hh + j) - (a + 2 * b + c);
      gx[i] = sx;
      gy[i] = sy;
      mag[i] = math.sqrt(sx * sx + sy * sy);
    }
  }
  // Thresholds from the image: the strong ones are the top 8% of gradients,
  // never below what a faint paper edge on a pale table gives.
  // Fixed and low: a sheet's edge on a pale table is a step of a few levels
  // (Sobel gives 4x the step), far fainter than print; lines, not thresholds,
  // tell the page from the noise.
  const double high = 16;
  const double low = 8;
  // Thin edges: keep a pixel only where it is the peak across its gradient.
  final Uint8List thin = Uint8List(n);
  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      final int i = y * w + x;
      final double m = mag[i];
      if (m < low) continue;
      final double ax = gx[i].abs(), ay = gy[i].abs();
      double m1, m2;
      if (ay <= ax * 0.4142) {
        m1 = mag[i - 1];
        m2 = mag[i + 1];
      } else if (ax <= ay * 0.4142) {
        m1 = mag[i - w];
        m2 = mag[i + w];
      } else if ((gx[i] > 0) == (gy[i] > 0)) {
        m1 = mag[i - w - 1];
        m2 = mag[i + w + 1];
      } else {
        m1 = mag[i - w + 1];
        m2 = mag[i + w - 1];
      }
      if (m >= m1 && m > m2) thin[i] = m >= high ? 2 : 1;
    }
  }
  // Hysteresis: weak edges count when they touch a strong one.
  final Uint8List on = Uint8List(n);
  final List<int> stack = <int>[];
  int count = 0;
  for (int i = 0; i < n; i++) {
    if (thin[i] != 2 || on[i] == 1) continue;
    on[i] = 1;
    count++;
    stack.add(i);
    while (stack.isNotEmpty) {
      final int p = stack.removeLast();
      final int px = p % w, py = p ~/ w;
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          final int qx = px + dx, qy = py + dy;
          if (qx < 0 || qy < 0 || qx >= w || qy >= h) continue;
          final int q = qy * w + qx;
          if (thin[q] != 0 && on[q] == 0) {
            on[q] = 1;
            count++;
            stack.add(q);
          }
        }
      }
    }
  }
  return _Edges(w, h, on, gx, gy, lum, count);
}

/// A line x cos(theta) + y sin(theta) = rho.
class _Line {
  const _Line(this.theta, this.rho, [this.votes = 0]);
  final double theta;
  final double rho;
  final double votes;

  _Line scaled(double f) => _Line(theta, rho * f, votes);

  Offset? meet(_Line o) {
    final double d = math.cos(theta) * math.sin(o.theta) - math.sin(theta) * math.cos(o.theta);
    if (d.abs() < 1e-6) return null;
    return Offset(
      (rho * math.sin(o.theta) - o.rho * math.sin(theta)) / d,
      (o.rho * math.cos(theta) - rho * math.cos(o.theta)) / d,
    );
  }

  /// Signed distance of [p] from the line.
  double distance(Offset p) => p.dx * math.cos(theta) + p.dy * math.sin(theta) - rho;
}

/// Hough transform in 1° steps over [0°, 180°), each edge pixel voting within
/// 3° of its gradient's direction; the strongest distinct lines.
List<_Line> _hough(_Edges e) {
  const int thetas = 180;
  final int w = e.width, h = e.height;
  final int diag = (math.sqrt(w * w + h * h)).ceil();
  final int rhos = 2 * diag + 1;
  final Float32List acc = Float32List(thetas * rhos);
  final Float64List cs = Float64List(thetas), sn = Float64List(thetas);
  for (int t = 0; t < thetas; t++) {
    cs[t] = math.cos(t * math.pi / thetas);
    sn[t] = math.sin(t * math.pi / thetas);
  }
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final int i = y * w + x;
      if (e.on[i] == 0) continue;
      double a = math.atan2(e.gy[i], e.gx[i]);
      if (a < 0) a += math.pi;
      final int t0 = (a / math.pi * thetas).round();
      for (int dt = -3; dt <= 3; dt++) {
        final int t = (t0 + dt) % thetas;
        final int tt = t < 0 ? t + thetas : t;
        final double r = x * cs[tt] + y * sn[tt];
        acc[tt * rhos + r.round() + diag] += 1;
      }
    }
  }
  final double minVotes = math.min(w, h) * 0.12;
  final List<_Line> peaks = <_Line>[];
  for (int t = 0; t < thetas; t++) {
    for (int r = 1; r < rhos - 1; r++) {
      final double v = acc[t * rhos + r];
      if (v < minVotes) continue;
      bool peak = true;
      for (int dt = -2; dt <= 2 && peak; dt++) {
        final int tt = (t + dt) % thetas;
        final int t2 = tt < 0 ? tt + thetas : tt;
        for (int dr = -3; dr <= 3; dr++) {
          if (dt == 0 && dr == 0) continue;
          final int rr = r + dr;
          if (rr < 0 || rr >= rhos) continue;
          final double o = acc[t2 * rhos + rr];
          if (o > v || (o == v && (dt < 0 || (dt == 0 && dr < 0)))) {
            peak = false;
            break;
          }
        }
      }
      if (peak) peaks.add(_Line(t * math.pi / thetas, (r - diag).toDouble(), v));
    }
  }
  peaks.sort((_Line a, _Line b) => b.votes.compareTo(a.votes));
  final List<_Line> out = <_Line>[];
  for (final _Line l in peaks) {
    final bool near = out.any((_Line o) {
      double dt = (l.theta - o.theta).abs();
      dt = math.min(dt, math.pi - dt);
      return dt < 3 * math.pi / 180 && (l.rho - o.rho).abs() < 6 ||
          // The same line seen from the other side of 0° / 180°.
          (math.pi - (l.theta - o.theta).abs()) < 3 * math.pi / 180 && (l.rho + o.rho).abs() < 6;
    });
    if (!near) out.add(l);
    if (out.length >= 60) break;
  }
  return out;
}

class _Candidate {
  _Candidate(this.sides, this.corners, this.score);

  /// Top, right, bottom, left.
  final List<_Line> sides;

  /// Top left, top right, bottom right, bottom left.
  final List<Offset> corners;
  final double score;
}

/// Every pair of near-horizontal lines with every pair of near-vertical ones,
/// scored; the best one, or null.
_Candidate? _bestQuad(_Edges e, List<_Line> lines, double minAreaRatio) {
  final int w = e.width, h = e.height;
  // Normal near vertical: a horizontal side. Within 40° either way.
  bool horizontal(_Line l) => (l.theta - math.pi / 2).abs() < 40 * math.pi / 180;
  bool vertical(_Line l) => l.theta < 40 * math.pi / 180 || l.theta > 140 * math.pi / 180;
  final List<_Line> hs = lines.where(horizontal).take(24).toList();
  final List<_Line> vs = lines.where(vertical).take(24).toList();
  _Candidate? best;
  final double margin = 0.06 * math.max(w, h);
  bool inside(Offset p) => p.dx > -margin && p.dy > -margin && p.dx < w - 1 + margin && p.dy < h - 1 + margin;
  for (int a = 0; a < hs.length; a++) {
    for (int b = a + 1; b < hs.length; b++) {
      // Top is the one whose middle is higher.
      final double ya = _yAt(hs[a], w / 2), yb = _yAt(hs[b], w / 2);
      if ((ya - yb).abs() < h * 0.25) continue;
      final _Line top = ya < yb ? hs[a] : hs[b];
      final _Line bottom = ya < yb ? hs[b] : hs[a];
      for (int c = 0; c < vs.length; c++) {
        for (int d = c + 1; d < vs.length; d++) {
          final double xc = _xAt(vs[c], h / 2), xd = _xAt(vs[d], h / 2);
          if ((xc - xd).abs() < w * 0.25) continue;
          final _Line left = xc < xd ? vs[c] : vs[d];
          final _Line right = xc < xd ? vs[d] : vs[c];
          final List<_Line> sides = <_Line>[top, right, bottom, left];
          final List<Offset>? cs = _corners(sides);
          if (cs == null || !cs.every(inside) || !_convex(cs)) continue;
          final double area = _area(cs);
          if (area < minAreaRatio * w * h) continue;
          final double score = _score(e, cs, area / (w * h));
          if (score <= 0) continue;
          if (best == null || score > best.score) best = _Candidate(sides, cs, score);
        }
      }
    }
  }
  return best;
}

double _yAt(_Line l, double x) {
  final double s = math.sin(l.theta);
  return s.abs() < 1e-6 ? double.infinity : (l.rho - x * math.cos(l.theta)) / s;
}

double _xAt(_Line l, double y) {
  final double c = math.cos(l.theta);
  return c.abs() < 1e-6 ? double.infinity : (l.rho - y * math.sin(l.theta)) / c;
}

bool _convex(List<Offset> p) {
  double sign = 0;
  for (int i = 0; i < 4; i++) {
    final Offset a = p[i], b = p[(i + 1) % 4], c = p[(i + 2) % 4];
    final double z = (b.dx - a.dx) * (c.dy - b.dy) - (b.dy - a.dy) * (c.dx - b.dx);
    if (z == 0) return false;
    if (sign == 0) {
      sign = z.sign;
    } else if (z.sign != sign) {
      return false;
    }
  }
  return true;
}

double _area(List<Offset> p) {
  double s = 0;
  for (int i = 0; i < 4; i++) {
    s += p[i].dx * p[(i + 1) % 4].dy - p[(i + 1) % 4].dx * p[i].dy;
  }
  return s.abs() / 2;
}

/// How much of each side has an edge on it that is darker outside than in;
/// a page needs all four (its weakest side counts most), and a larger page wins
/// a tie. Sides that run on past the corners lose: a printed rule across the
/// page has the page's own sides carrying on beyond it, a real edge does not.
/// 0 when a side has almost no edge.
double _score(_Edges e, List<Offset> cs, double areaRatio) {
  final Offset centre = (cs[0] + cs[1] + cs[2] + cs[3]) / 4;
  double sum = 0, minCover = 1, runOn = 0;
  for (int s = 0; s < 4; s++) {
    final Offset a = cs[s], b = cs[(s + 1) % 4];
    final double cover = _cover(e, a, b, centre);
    sum += cover;
    if (cover < minCover) minCover = cover;
    // Past each end, along the side, for a fifth of its length.
    final Offset d = b - a;
    final Offset ext = d * 0.2;
    runOn += _cover(e, b, b + ext, centre, from: 0, to: 1) + _cover(e, a, a - ext, centre, from: 0, to: 1);
  }
  if (minCover < 0.2) return 0;
  final double mean = sum / 4;
  return mean * (0.4 + 0.6 * minCover) + 0.5 * areaRatio - 2.0 * runOn / 8;
}

/// Share of the side from [a] to [b] (its middle 90% unless [from], [to] say
/// otherwise) with an edge pixel within 1 px lying across it, all brightening
/// the same way: into the page (a sheet on a table), or out of it (a tinted band
/// printed on the sheet's edge, darker than a pale table). The better of the two.
double _cover(_Edges e, Offset a, Offset b, Offset centre, {double from = 0.05, double to = 0.95}) {
  final Offset d = b - a;
  final double len = d.distance;
  if (len < 4) return 0;
  final Offset u = d / len;
  // The side's normal, pointing into the page.
  Offset nrm = Offset(-u.dy, u.dx);
  if ((centre - a).dx * nrm.dx + (centre - a).dy * nrm.dy < 0) nrm = -nrm;
  int inward = 0, outward = 0, total = 0;
  for (double t = len * from; t <= len * to; t += 1) {
    total++;
    final Offset p = a + u * t;
    bool fin = false, fout = false;
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        final int x = p.dx.round() + dx, y = p.dy.round() + dy;
        if (!e.edgeAt(x, y)) continue;
        final int i = y * e.width + x;
        final double gx = e.gx[i], gy = e.gy[i];
        final double gl = math.sqrt(gx * gx + gy * gy);
        if (gl == 0) continue;
        final double c = (gx * nrm.dx + gy * nrm.dy) / gl;
        if (c > 0.8) fin = true;
        if (c < -0.8) fout = true;
      }
    }
    if (fin) inward++;
    if (fout) outward++;
  }
  return total == 0 ? 0 : math.max(inward, outward) / total;
}

/// The side's own edge points (middle 80%, within 2 px, right polarity), fitted
/// by total least squares.
_Line? _refitOnEdges(_Edges e, _Candidate c, int side) {
  final Offset a = c.corners[side], b = c.corners[(side + 1) % 4];
  final Offset centre = (c.corners[0] + c.corners[1] + c.corners[2] + c.corners[3]) / 4;
  final Offset d = b - a;
  final double len = d.distance;
  if (len < 8) return null;
  final Offset u = d / len;
  Offset nrm = Offset(-u.dy, u.dx);
  if ((centre - a).dx * nrm.dx + (centre - a).dy * nrm.dy < 0) nrm = -nrm;
  final List<Offset> pts = <Offset>[];
  for (double t = len * 0.1; t <= len * 0.9; t += 1) {
    final Offset p = a + u * t;
    for (int k = -2; k <= 2; k++) {
      final Offset q = p + nrm * k.toDouble();
      final int x = q.dx.round(), y = q.dy.round();
      if (!e.edgeAt(x, y)) continue;
      final int i = y * e.width + x;
      final double gx = e.gx[i], gy = e.gy[i];
      final double gl = math.sqrt(gx * gx + gy * gy);
      if (gl > 0 && (gx * nrm.dx + gy * nrm.dy) / gl > 0.8) pts.add(Offset(x.toDouble(), y.toDouble()));
    }
  }
  return _fit(pts);
}

/// On the full image: across the side, every few px along it, the point of the
/// strongest brightening into the page (to a fraction of a pixel); the line
/// through them. Null when too few are found.
_Line? _refitOnGradient(Uint8List g, int w, int h, _Line guess, List<Offset> corners, int side, double up) {
  final Offset a = corners[side], b = corners[(side + 1) % 4];
  final Offset centre = (corners[0] + corners[1] + corners[2] + corners[3]) / 4;
  final Offset d = b - a;
  final double len = d.distance;
  if (len < 16) return null;
  final Offset u = d / len;
  Offset nrm = Offset(-u.dy, u.dx);
  if ((centre - a).dx * nrm.dx + (centre - a).dy * nrm.dy < 0) nrm = -nrm;
  double at(Offset p) {
    final int x = p.dx.round().clamp(0, w - 1), y = p.dy.round().clamp(0, h - 1);
    return g[y * w + x].toDouble();
  }

  // Search within two small-image pixels of the guess.
  final int reach = math.max(3, (up * 2).ceil());
  final List<Offset> pts = <Offset>[];
  final double step = math.max(2, len / 120);
  for (double t = len * 0.1; t <= len * 0.9; t += step) {
    final Offset base = a + u * t;
    // Start from the guessed line, not the corner chord.
    final Offset on = base - Offset(math.cos(guess.theta), math.sin(guess.theta)) * guess.distance(base);
    double bestG = 0;
    double bestK = 0;
    for (int k = -reach; k <= reach; k++) {
      // Brightening into the page over 2 px, averaged over 3 px along the side.
      double gsum = 0;
      for (int j = -1; j <= 1; j++) {
        final Offset p = on + nrm * k.toDouble() + u * j.toDouble();
        gsum += at(p + nrm) - at(p - nrm);
      }
      if (gsum > bestG) {
        bestG = gsum;
        bestK = k.toDouble();
      }
    }
    if (bestG > 12) pts.add(on + nrm * bestK);
  }
  if (pts.length < 8) return null;
  return _fit(pts);
}

/// Total least squares line through [pts], or null for too few.
_Line? _fit(List<Offset> pts) {
  if (pts.length < 6) return null;
  double mx = 0, my = 0;
  for (final Offset p in pts) {
    mx += p.dx;
    my += p.dy;
  }
  mx /= pts.length;
  my /= pts.length;
  double sxx = 0, syy = 0, sxy = 0;
  for (final Offset p in pts) {
    final double dx = p.dx - mx, dy = p.dy - my;
    sxx += dx * dx;
    syy += dy * dy;
    sxy += dx * dy;
  }
  // The normal is the eigenvector of the smaller eigenvalue.
  final double angle = 0.5 * math.atan2(2 * sxy, sxx - syy);
  double theta = angle + math.pi / 2;
  double rho = mx * math.cos(theta) + my * math.sin(theta);
  if (rho < 0) {
    theta += math.pi;
    rho = -rho;
  }
  theta %= 2 * math.pi;
  return _Line(theta, rho);
}

/// Corners of top, right, bottom, left sides: top left, top right, bottom right,
/// bottom left.
List<Offset>? _corners(List<_Line> s) {
  final Offset? tl = s[0].meet(s[3]);
  final Offset? tr = s[0].meet(s[1]);
  final Offset? br = s[2].meet(s[1]);
  final Offset? bl = s[2].meet(s[3]);
  if (tl == null || tr == null || br == null || bl == null) return null;
  return <Offset>[tl, tr, br, bl];
}

/// The thin edges [findPage] sees on [gray] shrunk to [work] px: 255 on an edge.
@visibleForTesting
(Uint8List, int, int) debugEdges(Uint8List gray, int width, int height, {int work = 320}) {
  final double scale = math.max(width, height) / work;
  final _Image small = scale > 1 ? _shrink(gray, width, height, scale) : _Image(gray, width, height);
  final _Edges e = _canny(small);
  return (Uint8List.fromList(<int>[for (final int v in e.on) v * 255]), e.width, e.height);
}
