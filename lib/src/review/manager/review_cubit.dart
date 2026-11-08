import 'dart:io';
import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/doc_scan_event.dart';
import '../../core/failures.dart';
import '../../core/session/scan_session.dart';
import '../../core/session/scan_session_repo.dart';
import '../../page_prep/data/page_preparer.dart';
import '../../recognition/data/recognition_repo.dart';

part 'review_cubit.freezed.dart';

@freezed
abstract class ReviewState with _$ReviewState {
  const ReviewState._();

  const factory ReviewState({
    required List<CapturedPage> pages,
    PageMove? lastMove,

    /// A page is being re-prepared (corners or filters).
    @Default(false) bool working,
    @Default(false) bool storageFull,
  }) = _ReviewState;

  bool get canBuild => pages.isNotEmpty;
  bool get canUndo => lastMove != null;
}

/// The review grid: reorder, undo, delete, corners, filters (stories 3, 11, 12, 13).
///
/// Adding and retaking are navigation: the flow opens the camera in append or
/// replace mode. Every change goes through [ScanSessionRepo], so the session's page
/// list is the PDF order (FR-011).
class ReviewCubit extends Cubit<ReviewState> {
  ReviewCubit({
    required ScanSessionRepo sessions,
    required PagePreparer preparer,
    required RecognitionRepo recognition,
    required void Function(DocScanEvent) onEvent,

    /// False on «توضيح الصفحات», which shares this cubit but is not review.
    bool announce = true,
  }) : _sessions = sessions,
       _preparer = preparer,
       _recognition = recognition,
       _onEvent = onEvent,
       super(ReviewState(pages: sessions.session.pages, lastMove: sessions.session.lastMove)) {
    _sub = _sessions.changes.listen((ScanSession s) => emit(state.copyWith(pages: s.pages, lastMove: s.lastMove)));
    if (announce) _onEvent(DocScanEvent.reviewOpened(pageCount: state.pages.length));
  }

  final ScanSessionRepo _sessions;
  final PagePreparer _preparer;
  final RecognitionRepo _recognition;
  final void Function(DocScanEvent) _onEvent;
  late final StreamSubscription<ScanSession> _sub;

  void move(int from, int to, {MoveVia via = MoveVia.drag}) {
    if (from == to || from < 0 || to < 0 || from >= state.pages.length || to >= state.pages.length) {
      return;
    }
    _sessions.movePage(from, to);
    _onEvent(DocScanEvent.pageMoved(via: via));
  }

  void undoMove() {
    if (!state.canUndo) return;
    _sessions.undoMove();
    _onEvent(DocScanEvent.pageMoveUndone());
  }

  /// Called by the flow when the camera added pages during an «إضافة صفحة» visit.
  void pagesAdded() => _onEvent(DocScanEvent.pageAdded(pageCount: state.pages.length));

  /// Deletes the page and its files. Returns true when no page is left, so the flow
  /// goes back to the camera.
  Future<bool> deletePage(String pageId) async {
    final Either<StorageFailure, ScanSession> r = await _sessions.removePage(pageId);
    return r.fold(
      (StorageFailure _) {
        emit(state.copyWith(storageFull: true));
        return false;
      },
      (ScanSession s) {
        _onEvent(DocScanEvent.pageDeleted(pageCount: s.pages.length));
        return s.pages.isEmpty;
      },
    );
  }

  /// Re-crops from the raw capture and re-queues recognition (story 12).
  Future<void> adjustCorners(String pageId, Quad corners, {int? turns}) async {
    final CapturedPage? page = _page(pageId);
    if (page == null) return;
    if (await _reprepare(page.copyWith(corners: corners, turns: (turns ?? page.turns) % 4))) {
      _onEvent(DocScanEvent.cornersAdjusted());
    }
  }

  /// «تدوير» on «توضيح الصفحات»: a quarter turn counter-clockwise of one page.
  Future<void> rotate(String pageId) async {
    final CapturedPage? page = _page(pageId);
    if (page == null) return;
    await _reprepare(page.copyWith(turns: (page.turns + 3) % 4));
  }

  /// Small real previews of [filters] on [page] as it is cropped and turned, for
  /// the filter strip. Cached until the page's photo, corners or turns change.
  Future<Map<PageFilter, File>> filterPreviews(CapturedPage page, List<PageFilter> filters) async {
    final String key = '${page.rawFile.path}|${page.corners}|${page.turns}';
    final Map<PageFilter, File> cached = _previews[key] ??= <PageFilter, File>{};
    for (final PageFilter f in filters) {
      if (cached.containsKey(f)) continue;
      final File out = _sessions.newFile('jpg');
      final File ocr = _sessions.newFile('png');
      final Either<StorageFailure, Unit> r = await _preparer.prepare(
        raw: page.rawFile,
        corners: page.corners,
        filters: <PageFilter>{f},
        prepared: out,
        ocrInput: ocr,
        turns: page.turns,
        longEdge: previewEdge,
      );
      // A preview is read by no one: drop its recognition input at once, and the
      // preview itself when the screen closed meanwhile (the scan may be gone).
      await _deleteQuietly(ocr);
      if (isClosed) {
        await _deleteQuietly(out);
        break;
      }
      if (r.isRight()) cached[f] = out;
    }
    return Map<PageFilter, File>.of(cached);
  }

  static Future<void> _deleteQuietly(File f) async {
    try {
      if (f.existsSync()) await f.delete();
    } on FileSystemException {
      // Already gone with its session.
    }
  }

  /// Long edge of a filter preview, in pixels.
  static const int previewEdge = 360;
  final Map<String, Map<PageFilter, File>> _previews = <String, Map<PageFilter, File>>{};

  /// One filter, or none with [PageFilter.original], on one page or on all pages
  /// when [pageId] is null (revised 2026-11-04: filters no longer combine).
  Future<void> setFilter(PageFilter filter, {String? pageId}) => setFilters(<PageFilter>{filter}, pageId: pageId);

  /// Applies [filters] to one page, or to all pages when [pageId] is null (story 13).
  Future<void> setFilters(Set<PageFilter> filters, {String? pageId}) async {
    final Set<PageFilter> clean = filters.length > 1
        ? filters.difference(<PageFilter>{PageFilter.original})
        : (filters.isEmpty ? const <PageFilter>{PageFilter.original} : filters);
    final List<CapturedPage> targets = pageId == null
        ? List<CapturedPage>.of(state.pages)
        : <CapturedPage>[if (_page(pageId) case final CapturedPage p) p];
    bool any = false;
    for (final CapturedPage p in targets) {
      any = await _reprepare(p.copyWith(filters: clean)) || any;
    }
    if (any) _onEvent(DocScanEvent.filterApplied(filters: clean, allPages: pageId == null));
  }

  Future<void> resetFilters({String? pageId}) => setFilters(const <PageFilter>{PageFilter.original}, pageId: pageId);

  Future<bool> _reprepare(CapturedPage next) async {
    emit(state.copyWith(working: true));
    final CapturedPage page = next.copyWith(
      preparedFile: _sessions.newFile('jpg'),
      ocrInputFile: _sessions.newFile('png'),
      recognition: const RecognitionState.pending(),
    );
    final Either<StorageFailure, Unit> prepared = await _preparer.prepare(
      raw: page.rawFile,
      corners: page.corners,
      filters: page.filters,
      prepared: page.preparedFile,
      ocrInput: page.ocrInputFile,
      turns: page.turns,
    );
    if (isClosed) return false;
    if (prepared.isLeft()) {
      emit(state.copyWith(working: false, storageFull: true));
      return false;
    }
    final Either<StorageFailure, ScanSession> replaced = await _sessions.replacePage(page);
    if (isClosed) return false;
    emit(state.copyWith(working: false, storageFull: replaced.isLeft()));
    if (replaced.isLeft()) return false;
    _recognition.enqueue(page);
    return true;
  }

  /// From the session, not [state]: the state catches up with the session's
  /// changes asynchronously, so a second quick edit would start from a stale page.
  CapturedPage? _page(String id) {
    for (final CapturedPage p in _sessions.session.pages) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
