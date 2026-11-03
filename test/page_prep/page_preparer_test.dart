import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/page_prep/data/page_preparer.dart';

void main() {
  late Directory tmp;
  late File raw;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('prep');
    final img.Image photo = img.Image(width: 400, height: 500);
    img.fill(photo, color: img.ColorRgb8(40, 40, 40));
    img.fillRect(photo, x1: 50, y1: 50, x2: 350, y2: 450, color: img.ColorRgb8(230, 225, 215));
    for (int y = 80; y < 420; y += 20) {
      img.fillRect(photo, x1: 70, y1: y, x2: 320, y2: y + 4, color: img.ColorRgb8(30, 30, 30));
    }
    raw = File('${tmp.path}/raw.jpg')..writeAsBytesSync(img.encodeJpg(photo, quality: 95));
  });

  tearDown(() async => tmp.delete(recursive: true));

  const Quad page = Quad(
    topLeft: Offset(50 / 399, 50 / 499),
    topRight: Offset(350 / 399, 50 / 499),
    bottomRight: Offset(350 / 399, 450 / 499),
    bottomLeft: Offset(50 / 399, 450 / 499),
  );

  Future<img.Image> run(Set<PageFilter> filters, {Quad q = page, String name = 'p'}) async {
    final File prepared = File('${tmp.path}/$name.jpg');
    final File ocr = File('${tmp.path}/$name.png');
    final bool ok = preparePage(raw.path, <double>[
      q.topLeft.dx, q.topLeft.dy, q.topRight.dx, q.topRight.dy,
      q.bottomRight.dx, q.bottomRight.dy, q.bottomLeft.dx, q.bottomLeft.dy,
    ], filters.map((PageFilter f) => f.index).toList(), prepared.path, ocr.path, 2200, 90);
    expect(ok, isTrue);
    final img.Image bw = img.decodePng(ocr.readAsBytesSync())!;
    // Recognition input is strictly black and white.
    expect(bw.every((img.Pixel p) => p.r == 0 || p.r == 255), isTrue);
    return img.decodeJpg(prepared.readAsBytesSync())!;
  }

  test('warp crops to the corners: no dark background is left', () async {
    final img.Image out = await run(<PageFilter>{PageFilter.original});
    expect(out.width, closeTo(300, 3));
    expect(out.height, closeTo(400, 3));
    expect(out.getPixel(2, 2).r, greaterThan(150));
    expect(out.getPixel(out.width - 3, out.height - 3).r, greaterThan(150));
  });

  test('full frame keeps the whole photo', () async {
    final img.Image out = await run(<PageFilter>{PageFilter.original}, q: Quad.fullFrame, name: 'full');
    expect(out.width, 400);
    expect(out.getPixel(2, 2).r, lessThan(80));
  });

  test('each filter changes the page; gray and black-and-white drop color', () async {
    final img.Image base = await run(<PageFilter>{PageFilter.original}, name: 'base');
    for (final PageFilter f in PageFilter.values.where((PageFilter f) => f != PageFilter.original)) {
      final img.Image out = await run(<PageFilter>{f}, name: f.name);
      bool differs = false;
      for (int y = 0; y < out.height && !differs; y += 7) {
        for (int x = 0; x < out.width && !differs; x += 7) {
          if ((out.getPixel(x, y).r - base.getPixel(x, y).r).abs() > 6) differs = true;
        }
      }
      expect(differs, isTrue, reason: f.name);
    }
    final img.Image gray = await run(<PageFilter>{PageFilter.grayscale}, name: 'g2');
    final img.Pixel p = gray.getPixel(150, 200);
    expect((p.r - p.b).abs(), lessThan(4));
  });

  test('the same filters give the same output', () async {
    final img.Image a = await run(<PageFilter>{PageFilter.removeShadows, PageFilter.sharpenText}, name: 'a');
    final img.Image b = await run(<PageFilter>{PageFilter.sharpenText, PageFilter.removeShadows}, name: 'b');
    expect(a.getBytes(), b.getBytes());
  });
}
