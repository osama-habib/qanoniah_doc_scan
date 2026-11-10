import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/src/core/presentation/scan_widgets.dart';

import '../helpers/test_host.dart';

/// The shared scan header (ClickUp z8y71x6pk7).
void main() {
  testWidgets('[UT] at a phone\'s width a long title stays exactly in the middle, cut short, never pushed aside', (
    WidgetTester t,
  ) async {
    await t.binding.setSurfaceSize(const Size(402, 200));
    addTearDown(() => t.binding.setSurfaceSize(null));
    const Key title = Key('title');
    await t.pumpWidget(
      testApp(
        const Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: ScanHeader(
              title: 'title',
              // The preview's sides: a narrow back button, a wide page count.
              leading: SizedBox(width: 36, height: 36),
              trailing: SizedBox(width: 110, height: 36),
              titleWidget: Text(
                'مستند-ممسوح-01-طويل-جدا-جدا.pdf',
                key: title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
    final Rect r = t.getRect(find.byKey(title));
    expect(r.center.dx, closeTo(201, 0.5), reason: 'exactly in the middle of the screen');
    // 402 - 16 - 16 at the sides, then the wider side (110) and the 12 gap on
    // both sides.
    expect(r.width, lessThanOrEqualTo(402 - 32 - 2 * (110 + 12)), reason: 'cut, not pushed into a side');
    expect(t.takeException(), isNull);
  });

  testWidgets('[UT] the leading side is at the start: the right in Arabic', (WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(402, 200));
    addTearDown(() => t.binding.setSurfaceSize(null));
    const Key lead = Key('lead');
    const Key trail = Key('trail');
    await t.pumpWidget(
      testApp(
        const Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: ScanHeader(
              title: 'عنوان',
              leading: SizedBox(key: lead, width: 36, height: 36),
              trailing: SizedBox(key: trail, width: 36, height: 36),
            ),
          ),
        ),
      ),
    );
    expect(t.getRect(find.byKey(lead)).right, 402 - 16);
    expect(t.getRect(find.byKey(trail)).left, 16);
  });
}
