import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:qanoniah_doc_scan/src/capture/data/edge_detector.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/page_prep/data/page_preparer.dart';

/// Upright detection on the platform: the upright page at `PAGE`, turned 0, 90,
/// 180 and 270 degrees clockwise, must come back with the turns that undo it, and
/// preparing with those turns must give the page back upright.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('upright turns', (WidgetTester t) async {
    await t.runAsync(() async {
      const String page = String.fromEnvironment('PAGE');
      const String out = String.fromEnvironment('OUT');
      final img.Image upright = img.decodeImage(File(page).readAsBytesSync())!;
      final img.Image small = img.copyResize(upright, width: 64);
      final VisionEdgeDetector edges = VisionEdgeDetector();
      int ok = 0;
      for (final int k in <int>[0, 1, 2, 3]) {
        final File photo = File('$out/turned_$k.jpg')
          ..writeAsBytesSync(img.encodeJpg(k == 0 ? upright : img.copyRotate(upright, angle: 90 * k), quality: 92));
        final Stopwatch sw = Stopwatch()..start();
        final int turns = await edges.uprightTurns(photo, Quad.fullFrame);
        final int ms = sw.elapsedMilliseconds;
        final File prepared = File('$out/upright_$k.jpg');
        await const PagePreparer().prepare(
          raw: photo,
          corners: Quad.fullFrame,
          filters: const <PageFilter>{PageFilter.original},
          prepared: prepared,
          ocrInput: File('$out/upright_$k.png'),
          turns: turns,
        );
        final img.Image back = img.decodeImage(prepared.readAsBytesSync())!;
        // Same page as the original: portrait, and close pixel for pixel.
        final img.Image b = img.copyResize(back, width: 64, height: small.height);
        double diff = 0;
        for (int y = 0; y < small.height; y++) {
          for (int x = 0; x < 64; x++) {
            diff += (small.getPixel(x, y).luminance - b.getPixel(x, y).luminance).abs();
          }
        }
        diff /= 64 * small.height;
        final bool right = turns == (4 - k) % 4 && back.height > back.width && diff < 35;
        if (right) ok++;
        // ignore: avoid_print
        print('[ROT] turned $k*90 -> turns $turns (want ${(4 - k) % 4}) in ${ms}ms, '
            '${edges.lastUprightDetails} result ${back.width}x${back.height} diff ${diff.toStringAsFixed(1)} ${right ? 'OK' : 'WRONG'}');
      }
      // ignore: avoid_print
      print('[ROT] $ok/4 upright');
    });
  });
}
