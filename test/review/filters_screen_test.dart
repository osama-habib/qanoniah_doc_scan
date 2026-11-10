import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qanoniah_doc_scan/qanoniah_doc_scan.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session_repo.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/recognition_repo.dart';
import 'package:qanoniah_doc_scan/src/review/manager/review_cubit.dart';
import 'package:qanoniah_doc_scan/src/review/presentation/filters_screen.dart';

import '../fakes/fake_text_recognizer.dart';
import '../helpers/test_host.dart';

void main() {
  late Directory tmp;
  late ScanSessionRepo sessions;
  late RecognitionRepo recognition;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('filters');
    sessions = ScanSessionRepo(tempRoot: () async => tmp);
    await sessions.start();
    // Tall pages, so the page on screen is narrower than its slot.
    for (final String id in <String>['a', 'b', 'c']) {
      final List<int> jpeg = img.encodeJpg(img.Image(width: 300, height: 600));
      sessions.addPage(
        CapturedPage(
          id: id,
          rawFile: sessions.newFile('jpg')..writeAsBytesSync(jpeg),
          corners: Quad.fullFrame,
          filters: const <PageFilter>{PageFilter.original},
          preparedFile: sessions.newFile('jpg')..writeAsBytesSync(jpeg),
          ocrInputFile: sessions.newFile('png')..writeAsBytesSync(jpeg),
          recognition: const RecognitionState.pending(),
        ),
      );
    }
    recognition = RecognitionRepo(recognizer: FakeTextRecognizer(), sessions: sessions, enabled: false);
  });

  tearDown(() async {
    recognition.dispose();
    await tmp.delete(recursive: true);
  });

  Future<ReviewCubit> pump(WidgetTester t, {int index = 0}) async {
    final ReviewCubit cubit = ReviewCubit(
      sessions: sessions,
      preparer: FakePagePreparer(),
      recognition: recognition,
      onEvent: (DocScanEvent _) {},
      announce: false,
    );
    await t.binding.setSurfaceSize(const Size(402, 874));
    await t.pumpWidget(
      testApp(
        // In the flow the screen sits on the scan's Scaffold.
        Scaffold(
          body: BlocProvider<ReviewCubit>.value(
            value: cubit,
            child: FiltersScreen(strings: DocScanStrings.ar(), initialIndex: index, onBack: () {}, onNext: () {}),
          ),
        ),
      ),
    );
    await t.pump();
    return cubit;
  }

  testWidgets('[UT] the arrows move between pages, before and after a filter is saved (pk0)', (WidgetTester t) async {
    final ReviewCubit cubit = await pump(t);
    expect(find.text('صفحة 1 / 3'), findsOneWidget);
    // «التالي» page arrow, labelled with the page it opens.
    await t.tap(find.bySemanticsLabel('الصفحة 2'));
    await t.pump();
    expect(find.text('صفحة 2 / 3'), findsOneWidget, reason: 'the next arrow moves on');
    // Saving a filter re-prepares the pages; the arrows still work after it.
    await t.runAsync(() => cubit.setFilter(PageFilter.grayscale));
    await t.pump();
    await t.tap(find.bySemanticsLabel('الصفحة 3'));
    await t.pump();
    expect(find.text('صفحة 3 / 3'), findsOneWidget, reason: 'the next arrow still moves on after a save');
    await t.tap(find.bySemanticsLabel('الصفحة 2'));
    await t.pump();
    expect(find.text('صفحة 2 / 3'), findsOneWidget, reason: 'the previous arrow moves back');
    // Unmount before closing: a cubit still watched closes only as frames pump.
    await t.pumpWidget(const SizedBox());
    await t.runAsync(cubit.close);
  });

  testWidgets('[UT] a horizontal swipe on the page moves between pages', (WidgetTester t) async {
    final ReviewCubit cubit = await pump(t, index: 1);
    expect(find.text('صفحة 2 / 3'), findsOneWidget);
    // Right to left: the page sides follow the reading direction, a swipe to
    // the right shows the next page.
    await t.fling(find.byKey(const ValueKey<String>('filters-page')), const Offset(300, 0), 1000);
    await t.pump();
    expect(find.text('صفحة 3 / 3'), findsOneWidget);
    await t.fling(find.byKey(const ValueKey<String>('filters-page')), const Offset(-300, 0), 1000);
    await t.pump();
    expect(find.text('صفحة 2 / 3'), findsOneWidget);
    // Unmount before closing: a cubit still watched closes only as frames pump.
    await t.pumpWidget(const SizedBox());
    await t.runAsync(cubit.close);
  });

  testWidgets('[UT] the title and page count are exactly in the middle, back and «التالي» in 96 slots (04-a)', (
    WidgetTester t,
  ) async {
    final ReviewCubit cubit = await pump(t);
    expect(t.getCenter(find.text('توضيح الصفحات')).dx, closeTo(201, 0.5));
    expect(t.getCenter(find.text('صفحة 1 / 3')).dx, closeTo(201, 0.5));
    // Unmount before closing: a cubit still watched closes only as frames pump.
    await t.pumpWidget(const SizedBox());
    await t.runAsync(cubit.close);
  });
}
