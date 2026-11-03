import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/src/core/doc_scan_event.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session_repo.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/recognition_repo.dart';
import 'package:qanoniah_doc_scan/src/review/manager/review_cubit.dart';

import '../fakes/fake_text_recognizer.dart';
import '../helpers/test_host.dart';

void main() {
  late Directory tmp;
  late ScanSessionRepo sessions;
  late RecognitionRepo recognition;
  late FakePagePreparer preparer;
  late List<DocScanEvent> events;

  CapturedPage page(String id) {
    final File f = sessions.newFile('jpg')..writeAsBytesSync(<int>[1]);
    return CapturedPage(
      id: id,
      rawFile: f,
      corners: Quad.fullFrame,
      filters: const <PageFilter>{PageFilter.original},
      preparedFile: sessions.newFile('jpg')..writeAsBytesSync(<int>[1]),
      ocrInputFile: sessions.newFile('png')..writeAsBytesSync(<int>[1]),
      recognition: const RecognitionState.done(PageText(language: RecognitionLanguage.ar, paragraphs: <Paragraph>[])),
    );
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rev');
    sessions = ScanSessionRepo(tempRoot: () async => tmp);
    await sessions.start();
    for (final String id in <String>['a', 'b', 'c']) {
      sessions.addPage(page(id));
    }
    recognition = RecognitionRepo(recognizer: FakeTextRecognizer(), sessions: sessions);
    preparer = FakePagePreparer();
    events = <DocScanEvent>[];
  });

  tearDown(() async {
    recognition.dispose();
    await tmp.delete(recursive: true);
  });

  ReviewCubit cubit() =>
      ReviewCubit(sessions: sessions, preparer: preparer, recognition: recognition, onEvent: events.add);

  List<String> order() => sessions.session.pages.map((CapturedPage p) => p.id).toList();

  test('move, undo, and the order persists to the session', () async {
    final ReviewCubit c = cubit();
    c.move(2, 0);
    await pumpEventQueue();
    expect(order(), <String>['c', 'a', 'b']);
    expect(c.state.canUndo, isTrue);
    c.undoMove();
    await pumpEventQueue();
    expect(order(), <String>['a', 'b', 'c']);
    expect(events.map((DocScanEvent e) => e.name), containsAll(<String>['scan_review_opened', 'scan_page_moved', 'scan_page_move_undone']));
    await c.close();
  });

  test('delete removes files; deleting the last page reports empty', () async {
    final ReviewCubit c = cubit();
    final CapturedPage b = sessions.session.pages[1];
    expect(await c.deletePage(b.id), isFalse);
    expect(b.preparedFile.existsSync(), isFalse);
    expect(await c.deletePage('a'), isFalse);
    expect(await c.deletePage('c'), isTrue);
    await c.close();
  });

  test('a move followed by another change clears undo', () async {
    final ReviewCubit c = cubit();
    c.move(0, 1);
    await c.deletePage('c');
    await pumpEventQueue();
    expect(c.state.canUndo, isFalse);
    await c.close();
  });

  test('corners re-prepare from the raw file and re-queue recognition', () async {
    final ReviewCubit c = cubit();
    final CapturedPage before = sessions.session.pages.first;
    const Quad q = Quad(
      topLeft: Offset(0.2, 0.2),
      topRight: Offset(0.8, 0.2),
      bottomRight: Offset(0.8, 0.8),
      bottomLeft: Offset(0.2, 0.8),
    );
    await c.adjustCorners('a', q);
    final CapturedPage after = sessions.session.pages.first;
    expect(after.corners, q);
    expect(after.preparedFile.path, isNot(before.preparedFile.path));
    expect(before.preparedFile.existsSync(), isFalse);
    expect(preparer.corners.single, q);
    expect(events.map((DocScanEvent e) => e.name), contains('scan_corners_adjusted'));
    await c.close();
  });

  test('filters apply to all pages and drop «الأصل» when combined', () async {
    final ReviewCubit c = cubit();
    await c.setFilters(<PageFilter>{PageFilter.original, PageFilter.grayscale, PageFilter.highContrast});
    expect(preparer.calls, 3);
    expect(sessions.session.pages.every((CapturedPage p) => p.filters.length == 2), isTrue);
    await c.resetFilters(pageId: 'a');
    expect(sessions.session.pages.first.filters, <PageFilter>{PageFilter.original});
    await c.close();
  });
}
