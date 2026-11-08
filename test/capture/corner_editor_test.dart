import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qanoniah_doc_scan/qanoniah_doc_scan.dart';
import 'package:qanoniah_doc_scan/src/capture/presentation/corner_editor.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';

import '../helpers/test_host.dart';

void main() {
  late Directory tmp;
  late File photo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('corners');
    photo = File('${tmp.path}/p.jpg')..writeAsBytesSync(img.encodeJpg(img.Image(width: 300, height: 400)));
  });

  tearDown(() => tmp.delete(recursive: true));

  const Quad start = Quad(
    topLeft: Offset(0.2, 0.2),
    topRight: Offset(0.8, 0.2),
    bottomRight: Offset(0.8, 0.8),
    bottomLeft: Offset(0.2, 0.8),
  );

  Future<ValueNotifier<Quad>> pump(WidgetTester t) async {
    final ValueNotifier<Quad> quad = ValueNotifier<Quad>(start);
    await t.binding.setSurfaceSize(const Size(300, 400));
    await t.pumpWidget(
      testApp(
        Scaffold(
          body: ValueListenableBuilder<Quad>(
            valueListenable: quad,
            builder: (BuildContext context, Quad q, Widget? _) => CornerEditor(
              photo: photo,
              quad: q,
              strings: DocScanStrings.ar(),
              onChanged: (Quad next) => quad.value = next,
            ),
          ),
        ),
      ),
    );
    // The editor waits for the photo's size.
    for (int i = 0; i < 40 && find.byType(GestureDetector).evaluate().length < 8; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump();
    }
    return quad;
  }

  testWidgets('[UT] dragging the top edge moves both top corners, the bottom ones stay (pk4)', (WidgetTester t) async {
    final ValueNotifier<Quad> quad = await pump(t);
    // The top edge's handle sits between the top corners: (0.5, 0.2) of 300 x 400.
    await t.dragFrom(const Offset(150, 80), const Offset(0, 40));
    await t.pump();
    final Quad q = quad.value;
    // Down by the drag (less the gesture's start threshold), both corners alike.
    expect(q.topLeft.dy, greaterThan(0.24));
    expect(q.topRight.dy, closeTo(q.topLeft.dy, 1e-9));
    expect(q.topLeft.dx, closeTo(0.2, 0.01));
    expect(q.bottomLeft, start.bottomLeft);
    expect(q.bottomRight, start.bottomRight);
  });

  testWidgets('[UT] an edge stops at the photo instead of bending', (WidgetTester t) async {
    final ValueNotifier<Quad> quad = await pump(t);
    // The right edge, dragged far past the photo's right side.
    await t.dragFrom(const Offset(240, 200), const Offset(300, 0));
    await t.pump();
    expect(quad.value.topRight.dx, 1);
    expect(quad.value.bottomRight.dx, 1);
    expect(quad.value.topRight.dy, closeTo(0.2, 0.01));
  });

  testWidgets('[UT] a magnifier shows the spot under the finger while dragging, then goes', (WidgetTester t) async {
    await pump(t);
    final TestGesture g = await t.startGesture(const Offset(60, 80)); // top left corner
    await g.moveBy(const Offset(10, 10));
    await t.pump();
    expect(find.byType(RawMagnifier), findsOneWidget);
    await g.up();
    await t.pump();
    expect(find.byType(RawMagnifier), findsNothing);
  });
}
