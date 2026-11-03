import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/src/page_prep/data/page_preparer.dart';

/// Projects an A4 sheet seen by a pinhole camera (focal [f], principal point at the
/// image center), tilted by [pitch] and [yaw], to normalized corners tl, tr, br, bl.
List<double> photographed({required double f, required double pitch, required double yaw, double w = 1080, double h = 1920}) {
  const double pw = 210;
  const double ph = 297;
  final List<List<double>> corners = <List<double>>[
    <double>[-pw / 2, -ph / 2],
    <double>[pw / 2, -ph / 2],
    <double>[pw / 2, ph / 2],
    <double>[-pw / 2, ph / 2],
  ];
  final List<double> out = <double>[];
  for (final List<double> c in corners) {
    // Rotate about x (pitch) then y (yaw), push 400 mm away.
    final double y1 = c[1] * math.cos(pitch);
    final double z1 = c[1] * math.sin(pitch);
    final double x2 = c[0] * math.cos(yaw) + z1 * math.sin(yaw);
    final double z2 = -c[0] * math.sin(yaw) + z1 * math.cos(yaw) + 400;
    out
      ..add((f * x2 / z2 + w / 2) / w)
      ..add((f * y1 / z2 + h / 2) / h);
  }
  return out;
}

void main() {
  test('[UT] recovers A4 from a tilted photo', () {
    for (final (double pitch, double yaw) in <(double, double)>[(0.4, 0.3), (-0.35, 0.25), (0.6, -0.2)]) {
      final List<double> q = photographed(f: 1500, pitch: pitch, yaw: yaw);
      final double? r = pageAspect(q, 1080, 1920);
      // ignore: avoid_print
      print('[UT] pitch $pitch yaw $yaw -> ${r?.toStringAsFixed(4)} (A4 0.7071)');
      expect(r, isNotNull);
      expect(r!, closeTo(210 / 297, 0.01));
    }
  });

  test('[UT] a frontal view and an unknown lens still give the side ratio', () {
    expect(pageAspect(photographed(f: 1500, pitch: 0, yaw: 0), 1080, 1920), closeTo(210 / 297, 0.005));
    // Pure pitch with the lens the fallback assumes.
    expect(pageAspect(photographed(f: 1440, pitch: 0.5, yaw: 0), 1080, 1920), closeTo(210 / 297, 0.01));
  });
}
