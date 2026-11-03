import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/src/core/failures.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session_repo.dart';

void main() {
  late Directory tmp;
  late DateTime now;
  late ScanSessionRepo repo;

  Directory root() => Directory('${tmp.path}/qanoniah_doc_scan');

  Future<ScanSession> start() async =>
      (await repo.start()).getOrElse(() => throw StateError('start failed'));

  CapturedPage page(String id) {
    File f(String ext) => repo.newFile(ext)..writeAsStringSync(id);
    return CapturedPage(
      id: id,
      rawFile: f('jpg'),
      corners: Quad.fullFrame,
      filters: <PageFilter>{PageFilter.original},
      preparedFile: f('jpg'),
      ocrInputFile: f('png'),
      recognition: const RecognitionState.pending(),
    );
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('doc_scan_repo_test');
    now = DateTime(2026, 11, 2, 12);
    repo = ScanSessionRepo(tempRoot: () async => tmp, now: () => now);
  });

  tearDown(() async {
    await repo.dispose();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('start removes orphaned session directories', () async {
    final Directory orphan =
        await Directory('${root().path}/old-session').create(recursive: true);
    File('${orphan.path}/page.jpg').writeAsStringSync('x');

    final ScanSession s = await start();

    expect(await orphan.exists(), isFalse);
    expect(await s.dir.exists(), isTrue);
  });

  test('start removes outputs older than 24 hours and keeps newer ones', () async {
    final Directory out =
        await Directory('${root().path}/out').create(recursive: true);
    final File old = File('${out.path}/old.pdf')..writeAsStringSync('x');
    final File recent = File('${out.path}/recent.pdf')..writeAsStringSync('x');
    await old.setLastModified(now.subtract(const Duration(hours: 25)));
    await recent.setLastModified(now.subtract(const Duration(hours: 1)));

    await start();

    expect(await old.exists(), isFalse);
    expect(await recent.exists(), isTrue);
  });

  test('cancel leaves no session files (SC-007)', () async {
    final ScanSession s = await start();
    repo.addPage(page('a'));
    repo.addPage(page('b'));

    expect((await repo.cancel()).isRight(), isTrue);

    expect(await s.dir.exists(), isFalse);
    expect(() => repo.session, throwsStateError);
  });

  test('finish leaves only the output PDF (SC-007)', () async {
    final ScanSession s = await start();
    repo.addPage(page('a'));
    final File pdf = repo.newFile('pdf')..writeAsStringSync('%PDF');

    final File moved = (await repo.finish(pdf)).getOrElse(
      () => throw StateError('finish failed'),
    );

    expect(await s.dir.exists(), isFalse);
    expect(await moved.exists(), isTrue);
    final List<FileSystemEntity> left = root().listSync(recursive: true);
    expect(left.whereType<File>().map((File f) => f.path), <String>[moved.path]);
  });

  test('removePage deletes the page files', () async {
    await start();
    final CapturedPage a = page('a');
    repo.addPage(a);

    await repo.removePage('a');

    expect(repo.session.pages, isEmpty);
    expect(await a.rawFile.exists(), isFalse);
    expect(await a.preparedFile.exists(), isFalse);
    expect(await a.ocrInputFile.exists(), isFalse);
  });

  test('replacePage deletes only files the new page no longer uses', () async {
    await start();
    final CapturedPage a = page('a');
    repo.addPage(a);
    final File newPrepared = repo.newFile('jpg')..writeAsStringSync('n');
    final File newOcr = repo.newFile('png')..writeAsStringSync('n');

    await repo.replacePage(
      a.copyWith(preparedFile: newPrepared, ocrInputFile: newOcr),
    );

    expect(await a.rawFile.exists(), isTrue);
    expect(await a.preparedFile.exists(), isFalse);
    expect(await newPrepared.exists(), isTrue);
  });

  test('move and undo restore the order; other changes clear undo', () async {
    await start();
    for (final String id in <String>['a', 'b', 'c']) {
      repo.addPage(page(id));
    }
    List<String> order() =>
        repo.session.pages.map((CapturedPage p) => p.id).toList();

    repo.movePage(2, 0);
    expect(order(), <String>['c', 'a', 'b']);
    expect(repo.session.lastMove, isNotNull);

    repo.undoMove();
    expect(order(), <String>['a', 'b', 'c']);
    expect(repo.session.lastMove, isNull);

    repo.movePage(2, 0);
    repo.addPage(page('d'));
    expect(repo.session.lastMove, isNull);
  });

  test('storage errors map to StorageFailure without details', () async {
    final ScanSessionRepo broken = ScanSessionRepo(
      tempRoot: () async => Directory('/dev/null/not-a-dir'),
    );
    final Either<StorageFailure, ScanSession> r = await broken.start();
    expect(r.isLeft(), isTrue);
    await broken.dispose();
  });
}
