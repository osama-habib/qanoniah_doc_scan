import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../failures.dart';
import 'scan_session.dart';

/// Owns the one active [ScanSession] and its temp directory (research R11).
///
/// Every cubit reads and changes pages through this repo, so the page list, its files
/// and the cleanup rules live in one place (FR-021, FR-044).
class ScanSessionRepo {
  ScanSessionRepo({
    Future<Directory> Function()? tempRoot,
    DateTime Function()? now,
  }) : _tempRoot = tempRoot ?? getTemporaryDirectory,
       _now = now ?? DateTime.now;

  final Future<Directory> Function() _tempRoot;
  final DateTime Function() _now;
  final StreamController<ScanSession> _changes =
      StreamController<ScanSession>.broadcast();

  static const String _rootName = 'qanoniah_doc_scan';
  static const String _outName = 'out';

  /// Returned PDFs the host did not delete are removed after this long (FR-044).
  static const Duration outputMaxAge = Duration(hours: 24);

  ScanSession? _session;

  /// The active session. Only valid between [start] and [cancel] / [finish].
  ScanSession get session {
    final ScanSession? s = _session;
    if (s == null) throw StateError('No active scan session.');
    return s;
  }

  Stream<ScanSession> get changes => _changes.stream;

  /// Cleans leftovers from earlier sessions, then creates a new session directory.
  Future<Either<StorageFailure, ScanSession>> start({int? maxPages}) {
    return _guard(() async {
      final Directory root = await _root();
      await root.create(recursive: true);
      await for (final FileSystemEntity e in root.list()) {
        if (e is Directory && _name(e) != _outName) {
          await e.delete(recursive: true);
        }
      }
      await _deleteOldOutputs(Directory('${root.path}/$_outName'));
      final String id = const Uuid().v4();
      final Directory dir = await Directory('${root.path}/$id').create();
      return _emit(
        ScanSession(
          id: id,
          dir: dir,
          pages: const <CapturedPage>[],
          captureMode: CaptureMode.auto,
          startedAt: _now(),
          maxPages: maxPages,
        ),
      );
    });
  }

  /// A new, unused file path inside the session directory.
  File newFile(String extension) =>
      File('${session.dir.path}/${const Uuid().v4()}.$extension');

  /// A new page id, stable across reorder.
  String newPageId() => const Uuid().v4();

  ScanSession setCaptureMode(CaptureMode mode) =>
      _emit(session.copyWith(captureMode: mode));

  /// Appends [page] at the end (FR-008).
  ScanSession addPage(CapturedPage page) => _emit(
    session.copyWith(
      pages: <CapturedPage>[...session.pages, page],
      lastMove: null,
    ),
  );

  /// Replaces the page with [page.id], deleting files the new page no longer uses.
  Future<Either<StorageFailure, ScanSession>> replacePage(CapturedPage page) {
    return _guard(() async {
      final int i = _indexOf(page.id);
      final CapturedPage old = session.pages[i];
      await _deleteFiles(_filesOf(old).difference(_filesOf(page)));
      final List<CapturedPage> pages = List<CapturedPage>.of(session.pages)
        ..[i] = page;
      return _emit(session.copyWith(pages: pages, lastMove: null));
    });
  }

  /// Updates a page's recognition state without touching files or the undo slot.
  ScanSession updateRecognition(String pageId, RecognitionState state) {
    final int i = _indexOf(pageId);
    final List<CapturedPage> pages = List<CapturedPage>.of(session.pages)
      ..[i] = session.pages[i].copyWith(recognition: state);
    return _emit(session.copyWith(pages: pages));
  }

  /// Moves a page and remembers the move for [undoMove] (FR-007).
  ScanSession movePage(int fromIndex, int toIndex) {
    final List<CapturedPage> pages = List<CapturedPage>.of(session.pages);
    pages.insert(toIndex, pages.removeAt(fromIndex));
    return _emit(
      session.copyWith(
        pages: pages,
        lastMove: PageMove(fromIndex: fromIndex, toIndex: toIndex),
      ),
    );
  }

  /// Reverts the last move. No-op when there is none.
  ScanSession undoMove() {
    final PageMove? move = session.lastMove;
    if (move == null) return session;
    final List<CapturedPage> pages = List<CapturedPage>.of(session.pages);
    pages.insert(move.fromIndex, pages.removeAt(move.toIndex));
    return _emit(session.copyWith(pages: pages, lastMove: null));
  }

  /// Removes a page and deletes its files (story 11, story 3 retake).
  Future<Either<StorageFailure, ScanSession>> removePage(String pageId) {
    return _guard(() async {
      final CapturedPage page = session.pages[_indexOf(pageId)];
      await _deleteFiles(_filesOf(page));
      return _emit(
        session.copyWith(
          pages: session.pages.where((CapturedPage p) => p.id != pageId).toList(),
          lastMove: null,
        ),
      );
    });
  }

  /// Deletes the session directory and ends the session (FR-021).
  Future<Either<StorageFailure, Unit>> cancel() {
    return _guard(() async {
      await _end();
      return unit;
    });
  }

  /// Moves [pdf] to the output directory, deletes the session directory, and returns
  /// the moved file. Its ownership passes to the host (FR-035).
  Future<Either<StorageFailure, File>> finish(File pdf) {
    return _guard(() async {
      final Directory out = await Directory(
        '${(await _root()).path}/$_outName',
      ).create(recursive: true);
      final File moved = await pdf.copy('${out.path}/${session.id}.pdf');
      await _end();
      return moved;
    });
  }

  Future<void> dispose() => _changes.close();

  Future<void> _end() async {
    final ScanSession? s = _session;
    _session = null;
    if (s != null && await s.dir.exists()) await s.dir.delete(recursive: true);
  }

  Future<void> _deleteOldOutputs(Directory out) async {
    if (!await out.exists()) return;
    final DateTime cutoff = _now().subtract(outputMaxAge);
    await for (final FileSystemEntity e in out.list()) {
      if (e is File && (await e.lastModified()).isBefore(cutoff)) {
        await e.delete();
      }
    }
  }

  Future<Directory> _root() async =>
      Directory('${(await _tempRoot()).path}/$_rootName');

  int _indexOf(String pageId) {
    final int i = session.pages.indexWhere((CapturedPage p) => p.id == pageId);
    if (i < 0) throw StateError('Unknown page.');
    return i;
  }

  static Set<String> _filesOf(CapturedPage p) => <String>{
    p.rawFile.path,
    p.preparedFile.path,
    p.ocrInputFile.path,
  };

  static Future<void> _deleteFiles(Set<String> paths) async {
    for (final String path in paths) {
      final File f = File(path);
      if (await f.exists()) await f.delete();
    }
  }

  static String _name(FileSystemEntity e) => e.uri.pathSegments
      .where((String s) => s.isNotEmpty)
      .last;

  ScanSession _emit(ScanSession s) {
    _session = s;
    _changes.add(s);
    return s;
  }

  /// Maps file-system errors to [StorageFailure]. Error details are dropped on
  /// purpose: paths can contain the user's file name (FR-041).
  static Future<Either<StorageFailure, T>> _guard<T>(
    Future<T> Function() body,
  ) async {
    try {
      return Right<StorageFailure, T>(await body());
    } on FileSystemException catch (e) {
      // ENOSPC is 28 on both Linux/Android and Darwin.
      return Left<StorageFailure, T>(
        e.osError?.errorCode == 28
            ? const StorageFailure.full()
            : const StorageFailure.unknown(),
      );
    }
  }
}
