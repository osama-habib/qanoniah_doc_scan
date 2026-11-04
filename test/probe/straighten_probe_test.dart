// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/src/capture/presentation/straighten_animation.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';

/// Host probe: frames of the straightening on PROBE_PHOTO, to PROBE_OUT. Skips
/// without them.
void main() {
  final Map<String, String> env = Platform.environment;
  testWidgets('straighten frames', (WidgetTester t) async {
    final File photo = File(env['PROBE_PHOTO']!);
    // The invoice photo's page, measured by eye.
    const Quad quad = Quad(
      topLeft: Offset(0.093, 0.227),
      topRight: Offset(0.935, 0.232),
      bottomRight: Offset(0.995, 0.943),
      bottomLeft: Offset(0.065, 0.922),
    );
    print('[ST] quad $quad');
    await t.binding.setSurfaceSize(const Size(400, 700));
    final GlobalKey key = GlobalKey();
    await t.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: StraightenAnimation(
            photo: photo,
            quad: quad,
            turns: int.parse(env['PROBE_TURNS'] ?? '0'),
            background: const Color(0xff0b0f1a),
            onDone: () {},
          ),
        ),
      ),
    );
    // The photo decodes on real time; frames stay on the test clock.
    for (int i = 0; i < 40; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump(Duration.zero);
    }
    for (final int ms in <int>[0, 140, 280, 420, 560]) {
      if (ms > 0) await t.pump(const Duration(milliseconds: 140));
      final ui.Image im = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
      final ByteData? png = await t.runAsync<ByteData?>(() => im.toByteData(format: ui.ImageByteFormat.png));
      File('${env['PROBE_OUT']}/st_$ms.png').writeAsBytesSync(png!.buffer.asUint8List());
    }
  }, skip: env['PROBE_PHOTO'] == null);
}
