import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/src/capture/data/page_finder.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';

/// [findPage]: a page's four sides, the way a scanner app finds them.
void main() {
  const int w = 600, h = 900;

  /// A tilted sheet: corners (pixels), the sheet's and the table's gray, a band
  /// across the sheet's top of [bandGray] [bandHeight] px deep, a printed rule
  /// [ruleAt] px below the top, and some noise.
  Uint8List scene({
    required List<Offset> corners,
    required int paper,
    required int table,
    int? bandGray,
    double bandHeight = 0,
    double? ruleAt,
    int seed = 1,
  }) {
    final math.Random r = math.Random(seed);
    final Uint8List px = Uint8List(w * h);
    // Inside test against the quad, and the distance down from its top side.
    bool inside(Offset p) {
      for (int i = 0; i < 4; i++) {
        final Offset a = corners[i], b = corners[(i + 1) % 4];
        if ((b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx) < 0) return false;
      }
      return true;
    }

    double belowTop(Offset p) {
      final Offset a = corners[0], b = corners[1];
      final Offset d = b - a;
      return ((p.dx - a.dx) * -d.dy + (p.dy - a.dy) * d.dx).abs() / d.distance;
    }

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final Offset p = Offset(x + 0.5, y + 0.5);
        int v = table;
        if (inside(p)) {
          final double down = belowTop(p);
          v = paper;
          if (bandGray != null && down < bandHeight) v = bandGray;
          // A printed rule, 3 px, inset from the sheet's sides.
          if (ruleAt != null && (down - ruleAt).abs() < 1.5 && x > 140 && x < 460) v = 60;
          // Lines of "text".
          if (down > 160 && (down.toInt() ~/ 14).isEven && down.toInt() % 14 < 4 && x > 150 && x < 450) v = 70;
        }
        px[y * w + x] = (v + r.nextInt(7) - 3).clamp(0, 255);
      }
    }
    return px;
  }

  double worst(Quad q, List<Offset> truth) {
    final List<Offset> got = <Offset>[q.topLeft, q.topRight, q.bottomRight, q.bottomLeft];
    double e = 0;
    for (int i = 0; i < 4; i++) {
      final Offset d = Offset((got[i].dx - truth[i].dx / (w - 1)) * w, (got[i].dy - truth[i].dy / (h - 1)) * h);
      e = math.max(e, d.distance / h);
    }
    return e;
  }

  const List<Offset> tilted = <Offset>[Offset(70, 110), Offset(520, 90), Offset(545, 800), Offset(55, 830)];

  test('[UT] a white sheet on a pale table, a few levels apart, is found to within 1%', () {
    final Quad? q = findPage(scene(corners: tilted, paper: 235, table: 222), w, h);
    expect(q, isNotNull);
    expect(worst(q!, tilted), lessThan(0.01));
  });

  test('[UT] a printed rule across the sheet is not taken for its top', () {
    final Quad? q = findPage(scene(corners: tilted, paper: 235, table: 205, ruleAt: 60), w, h);
    expect(q, isNotNull);
    expect(worst(q!, tilted), lessThan(0.01));
  });

  test('[UT] a tinted band darker than the table along the sheet\'s top still marks the top', () {
    final Quad? q = findPage(scene(corners: tilted, paper: 240, table: 225, bandGray: 212, bandHeight: 70), w, h);
    expect(q, isNotNull);
    expect(worst(q!, tilted), lessThan(0.01));
  });

  test('[UT] a flat or noisy frame has no page', () {
    final math.Random r = math.Random(3);
    final Uint8List flat = Uint8List(w * h)..fillRange(0, w * h, 180);
    final Uint8List noise = Uint8List.fromList(List<int>.generate(w * h, (_) => r.nextInt(256)));
    expect(findPage(flat, w, h), isNull);
    expect(findPage(noise, w, h), isNull);
  });

  test('[UT] a sheet too small for the frame is not a page', () {
    const List<Offset> small = <Offset>[Offset(250, 400), Offset(350, 400), Offset(350, 500), Offset(250, 500)];
    expect(findPage(scene(corners: small, paper: 240, table: 120), w, h), isNull);
  });
}
