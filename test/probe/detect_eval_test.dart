// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qanoniah_doc_scan/src/capture/data/edge_detector.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';

/// Host probe: page detection against photos with known corners.
///
/// PROBE_CASES is a folder of `name.jpg` with `name.txt` beside each: the four
/// corners in photo pixels, «x,y x,y x,y x,y» clockwise from the top left.
/// Prints each photo's worst corner error as a share of the photo's long side.
/// Skips without PROBE_CASES. The photos stay outside the repo.
void main() {
  final String? dir = Platform.environment['PROBE_CASES'];
  test('detection error per photo', () {
    final List<File> photos =
        Directory(dir!).listSync().whereType<File>().where((File f) => f.path.endsWith('.jpg')).toList()
          ..sort((File a, File b) => a.path.compareTo(b.path));
    double worst = 0;
    for (final File photo in photos) {
      final File truthFile = File(photo.path.replaceAll('.jpg', '.txt'));
      if (!truthFile.existsSync()) continue;
      final List<double> v = truthFile.readAsStringSync().trim().split(RegExp(r'[ ,]+')).map(double.parse).toList();
      final img.Image im = img.decodeImage(photo.readAsBytesSync())!;
      final int w = im.width, h = im.height;
      final List<Offset> truth = <Offset>[for (int i = 0; i < 8; i += 2) Offset(v[i] / w, v[i + 1] / h)];
      final Stopwatch sw = Stopwatch()..start();
      final Quad? q = detectInPhotoFile(photo.path, 0.2);
      sw.stop();
      final String name = photo.uri.pathSegments.last;
      // The live path: luminance at the camera's frame size.
      final img.Image live = img.copyResize(im, height: 640, interpolation: img.Interpolation.average);
      final Uint8List y = Uint8List(live.width * live.height);
      int k = 0;
      for (final img.Pixel p in live) {
        y[k++] = (0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b).round();
      }
      final Stopwatch lw = Stopwatch()..start();
      final Quad? lq = analyzeLuminance(y, live.width, live.height, 0.2).quad;
      lw.stop();
      if (lq != null) {
        double le = 0;
        final List<Offset> lg = <Offset>[lq.topLeft, lq.topRight, lq.bottomRight, lq.bottomLeft];
        for (int c = 0; c < 4; c++) {
          le = math.max(
            le,
            Offset((lg[c].dx - truth[c].dx) * w, (lg[c].dy - truth[c].dy) * h).distance / math.max(w, h),
          );
        }
        print('[LIVE] $name: off by ${(le * 100).toStringAsFixed(1)}% (${lw.elapsedMilliseconds} ms)');
      } else {
        print('[LIVE] $name: none');
      }
      if (q == null) {
        print('[EVAL] $name: none found (${sw.elapsedMilliseconds} ms)');
        worst = 1;
        continue;
      }
      final List<Offset> got = <Offset>[q.topLeft, q.topRight, q.bottomRight, q.bottomLeft];
      final double long = math.max(w, h).toDouble();
      double err = 0;
      for (int i = 0; i < 4; i++) {
        final Offset d = Offset((got[i].dx - truth[i].dx) * w, (got[i].dy - truth[i].dy) * h);
        err = math.max(err, d.distance / long);
      }
      worst = math.max(worst, err);
      print('[EVAL] $name: worst corner off by ${(err * 100).toStringAsFixed(1)}% (${sw.elapsedMilliseconds} ms)');
      print('[QUAD] $name ${got.map((Offset o) => '${(o.dx * w).round()},${(o.dy * h).round()}').join(' ')}');
    }
    print('[EVAL] worst of all: ${(worst * 100).toStringAsFixed(1)}%');
  }, skip: dir == null);
}
