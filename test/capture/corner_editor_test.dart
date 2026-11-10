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

  Future<ValueNotifier<Quad>> pump(WidgetTester t, {Quad from = start}) async {
    final ValueNotifier<Quad> quad = ValueNotifier<Quad>(from);
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
    for (int i = 0; i < 40 && find.byType(AnimatedScale).evaluate().length < 4; i++) {
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

  testWidgets('[UT] a corner moves from its side within 90 px, by the finger\'s movement, without a jump (03-a)', (
    WidgetTester t,
  ) async {
    final ValueNotifier<Quad> quad = await pump(t);
    // On the top side, 50 px from the top-left corner (60, 80), off its handle.
    await t.dragFrom(const Offset(110, 82), const Offset(0, 60));
    await t.pump();
    final Quad q = quad.value;
    expect(q.topLeft.dy, greaterThan(0.25), reason: 'the corner came down with the finger');
    expect(q.topLeft.dx, closeTo(0.2, 0.01), reason: 'no jump to where the finger is');
    expect(q.topRight, start.topRight, reason: 'the other corner of the side stays');
    expect(q.bottomLeft, start.bottomLeft);
  });

  testWidgets('[UT] a touch far from the sides moves nothing', (WidgetTester t) async {
    final ValueNotifier<Quad> quad = await pump(t);
    await t.dragFrom(const Offset(150, 200), const Offset(30, 30));
    await t.pump();
    expect(quad.value, start);
  });

  testWidgets('[UT] a corner is taken by a touch near it, not only on it (uv0)', (WidgetTester t) async {
    final ValueNotifier<Quad> quad = await pump(t);
    // 20 px left of and below the top-left corner (60, 80), off its dot.
    final TestGesture g = await t.startGesture(const Offset(45, 95));
    await g.moveBy(const Offset(0, 30));
    await t.pump();
    expect(quad.value.topLeft.dy, closeTo(0.2 + 30 / 400, 1e-6));
    await g.up();
  });

  testWidgets('[UT] the handle moves from the first pixel, by exactly the finger\'s movement (uv0)', (
    WidgetTester t,
  ) async {
    final ValueNotifier<Quad> quad = await pump(t);
    final TestGesture g = await t.startGesture(const Offset(60, 80));
    await g.moveBy(const Offset(3, 2));
    await t.pump();
    expect(quad.value.topLeft.dx, closeTo(0.2 + 3 / 300, 1e-6), reason: 'no dead zone before it moves');
    expect(quad.value.topLeft.dy, closeTo(0.2 + 2 / 400, 1e-6), reason: 'no jump under the finger');
    await g.up();
  });

  testWidgets('[UT] between two handles the nearest one wins (uv0)', (WidgetTester t) async {
    // The top corners 30 px apart: (120, 80) and (150, 80).
    const Quad narrow = Quad(
      topLeft: Offset(0.4, 0.2),
      topRight: Offset(0.5, 0.2),
      bottomRight: Offset(0.8, 0.8),
      bottomLeft: Offset(0.2, 0.8),
    );
    final ValueNotifier<Quad> quad = await pump(t, from: narrow);
    // 20 px from the right one, 10 px from the left one.
    final TestGesture g = await t.startGesture(const Offset(130, 80));
    await g.moveBy(const Offset(0, 40));
    await t.pump();
    expect(quad.value.topLeft.dy, closeTo(0.3, 1e-6), reason: 'the nearer corner moved');
    expect(quad.value.topRight, narrow.topRight, reason: 'the farther one stayed');
    await g.up();
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
    // Design 03-b: 2.6x, a dot on the exact corner.
    expect(t.widget<RawMagnifier>(find.byType(RawMagnifier)).magnificationScale, 2.6);
    expect(find.byKey(const ValueKey<String>('loupe-dot')), findsOneWidget);
    await g.up();
    await t.pump();
    expect(find.byType(RawMagnifier), findsNothing);
  });
}
