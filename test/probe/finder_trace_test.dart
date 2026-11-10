// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qanoniah_doc_scan/src/capture/data/page_finder.dart';

/// Host probe: [findPage]'s stages on PROBE_PHOTO, and its edge map to
/// PROBE_PHOTO.edges.png. Skips without it.
void main() {
  final String? path = Platform.environment['PROBE_PHOTO'];
  test('trace', () {
    final img.Image im = img.decodeImage(File(path!).readAsBytesSync())!;
    final Uint8List g = Uint8List(im.width * im.height);
    int i = 0;
    for (final img.Pixel p in im) {
      g[i++] = switch (Platform.environment['PROBE_CHANNEL']) {
        'min' => [p.r, p.g, p.b].reduce((num a, num b) => a < b ? a : b).round(),
        'blue' => p.b.round(),
        _ => (0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b).round(),
      };
    }
    print('[TRACE] ${findPage(g, im.width, im.height, work: 360, trace: (String s) => print('[TRACE] $s'))}');
    final (Uint8List e, int w, int h) = debugEdges(g, im.width, im.height, work: 360);
    final img.Image out = img.Image(width: w, height: h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final int v = e[y * w + x];
        out.setPixelRgb(x, y, v, v, v);
      }
    }
    File('$path.edges.png').writeAsBytesSync(img.encodePng(out));
  }, skip: path == null);
}
