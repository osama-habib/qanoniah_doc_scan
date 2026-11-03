import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qanoniah_doc_scan/src/capture/data/edge_detector.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';

/// A dark frame with a bright, slightly rotated page and some "text" lines.
Uint8List pageFrame(int w, int h, List<Offset> corners) {
  final Uint8List g = Uint8List(w * h);
  final Path page = Path()..addPolygon(corners, true);
  final math.Random r = math.Random(1);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final bool inside = page.contains(Offset(x + 0.5, y + 0.5));
      int v = inside ? 220 : 40;
      if (inside && y % 24 < 3 && x % 50 < 40) v = 70; // text
      g[y * w + x] = (v + r.nextInt(10)).clamp(0, 255);
    }
  }
  return g;
}

void main() {
  const int w = 480, h = 640;
  final List<Offset> corners = <Offset>[
    const Offset(70, 80), const Offset(420, 60), const Offset(440, 580), const Offset(50, 600),
  ];

  test('finds a bright page and orders its corners', () {
    final FrameAnalysis a = analyzeLuminance(pageFrame(w, h, corners), w, h, 0.2);
    final Quad q = a.quad!;
    void near(Offset got, Offset px) {
      expect((got.dx * (w - 1) - px.dx).abs(), lessThan(14));
      expect((got.dy * (h - 1) - px.dy).abs(), lessThan(14));
    }

    near(q.topLeft, corners[0]);
    near(q.topRight, corners[1]);
    near(q.bottomRight, corners[2]);
    near(q.bottomLeft, corners[3]);
    expect(a.luminance, greaterThan(100));
  });

  test('no page in a flat or noisy frame', () {
    final Uint8List flat = Uint8List(w * h)..fillRange(0, w * h, 120);
    expect(analyzeLuminance(flat, w, h, 0.2).quad, isNull);
    final math.Random r = math.Random(2);
    final Uint8List noise = Uint8List.fromList(List<int>.generate(w * h, (_) => r.nextInt(256)));
    expect(analyzeLuminance(noise, w, h, 0.2).quad, isNull);
  });

  test('a small bright patch is not a page', () {
    final List<Offset> small = <Offset>[
      const Offset(200, 250), const Offset(260, 250), const Offset(260, 320), const Offset(200, 320),
    ];
    expect(analyzeLuminance(pageFrame(w, h, small), w, h, 0.2).quad, isNull);
  });

  test('sharpness is higher for an edged frame than a flat one', () {
    final (double sharp, double _) = frameStats(pageFrame(w, h, corners), w, h);
    final (double flat, double _) = frameStats(Uint8List(w * h)..fillRange(0, w * h, 120), w, h);
    expect(sharp, greaterThan(flat));
  });

  test('finds the page in a captured photo', () async {
    final Directory tmp = await Directory.systemTemp.createTemp('photo');
    final Uint8List g = pageFrame(w, h, corners);
    final img.Image photo = img.Image(width: w, height: h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final int v = g[y * w + x];
        photo.setPixelRgb(x, y, v, v, v);
      }
    }
    final File f = File('${tmp.path}/p.jpg')..writeAsBytesSync(img.encodeJpg(photo, quality: 95));
    final Quad q = (await DartEdgeDetector().detectInPhoto(f))!;
    expect((q.topLeft.dx * (w - 1) - corners[0].dx).abs(), lessThan(16));
    expect((q.bottomRight.dy * (h - 1) - corners[2].dy).abs(), lessThan(16));
    await tmp.delete(recursive: true);
  });

  test('signatures tell a different page from the same one', () {
    final Uint8List a = pageFrame(w, h, corners);
    final List<int> sa = frameSignature(a, w, h);
    expect(signatureDistance(sa, frameSignature(a, w, h)), 0);
    final Uint8List b = Uint8List.fromList(a.map((int v) => 255 - v).toList());
    expect(signatureDistance(sa, frameSignature(b, w, h)), greaterThan(18));
  });
}
