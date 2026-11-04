import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/doc_scan_event.dart';
import '../../core/doc_scan_result.dart';
import '../../core/failures.dart';
import '../../core/session/document_edits.dart';
import '../../core/session/scan_session.dart';
import '../../core/session/scan_session_repo.dart';
import '../data/page_background.dart';
import '../data/pdf_builder.dart';
import '../data/size_fitter.dart';

part 'preview_cubit.freezed.dart';

enum PreviewView { text, photo }

/// A contiguous run of selected words in one paragraph (story 8).
@freezed
abstract class WordSelection with _$WordSelection {
  const WordSelection._();

  const factory WordSelection({
    required String pageId,
    required String paragraphId,
    required int start,
    required int end,
  }) = _WordSelection;

  ParagraphKey get key => (pageId, paragraphId);
  Iterable<int> get indexes sync* {
    for (int i = start; i <= end; i++) {
      yield i;
    }
  }
}

@freezed
abstract class PreviewState with _$PreviewState {
  const PreviewState._();

  const factory PreviewState({
    required List<CapturedPage> pages,
    required DocumentEdits edits,
    required PreviewView view,
    required int currentPage,
    required ScanColorMode colorMode,

    /// The file name without `.pdf`.
    required String fileStem,

    /// Size of the PDF that attach would send now (FR-011 form).
    required int sizeBytes,
    @Default(false) bool editing,
    WordSelection? selection,
    @Default(false) bool attaching,
    BuildFailure? failure,

    /// Each recognized page's background (the scan without its recognized words),
    /// by page id, once built.
    @Default(<String, File>{}) Map<String, File> backgrounds,
  }) = _PreviewState;

  DocScanPdfForm get form => edits.isDirty ? DocScanPdfForm.text : DocScanPdfForm.image;

  /// Scan color applies only to image form (story 14).
  bool get colorModeAvailable => !edits.isDirty;

  bool get selectionRedacted {
    final WordSelection? s = selection;
    return s != null && s.indexes.every((int i) => edits.isWordRedacted(s.key, i));
  }
}

/// Preview, edit, redaction, photo view, color mode and rename (stories 6 to 9, 14, 15).
class PreviewCubit extends Cubit<PreviewState> {
  PreviewCubit({
    required ScanSessionRepo sessions,
    required BuildOutput built,
    required SizeFitter fitter,
    required PdfBuilder builder,
    required PdfLook look,
    required int maxFileBytes,
    required String defaultStem,
    required void Function(DocScanEvent) onEvent,
    this.estimateDelay = const Duration(milliseconds: 500),
    PreviewView initialView = PreviewView.text,
  }) : _sessions = sessions,
       _built = built,
       _fitter = fitter,
       _builder = builder,
       _look = look,
       _maxFileBytes = maxFileBytes,
       _onEvent = onEvent,
       super(
         PreviewState(
           pages: sessions.session.pages,
           edits: const DocumentEdits(),
           view: initialView,
           currentPage: 0,
           colorMode: ScanColorMode.color,
           fileStem: defaultStem,
           sizeBytes: built.sizeBytes,
         ),
       ) {
    _onEvent(DocScanEvent.previewOpened());
    unawaited(_buildBackgrounds());
  }

  /// The text view draws each page as printed over its background.
  Future<void> _buildBackgrounds() async {
    for (final CapturedPage p in state.pages) {
      if (p.recognition is! RecognitionDone) continue;
      final PageBackgroundImage? bg = await PageBackground.forPage(p, out: _sessions.newFile('png'));
      if (isClosed) return;
      if (bg != null) emit(state.copyWith(backgrounds: <String, File>{...state.backgrounds, p.id: bg.file}));
    }
  }

  final ScanSessionRepo _sessions;
  final BuildOutput _built;
  final SizeFitter _fitter;
  final PdfBuilder _builder;
  final PdfLook _look;
  final int _maxFileBytes;
  final void Function(DocScanEvent) _onEvent;
  final Duration estimateDelay;
  Timer? _estimate;
  File? _estimateFile;

  void goToPage(int index) {
    if (index >= 0 && index < state.pages.length) emit(state.copyWith(currentPage: index));
  }

  void showView(PreviewView view) {
    if (view == state.view) return;
    if (view == PreviewView.photo) _onEvent(DocScanEvent.photoViewOpened());
    emit(state.copyWith(view: view, editing: false, selection: null));
  }

  void setColorMode(ScanColorMode mode) {
    if (!state.colorModeAvailable || mode == state.colorMode) return;
    _onEvent(DocScanEvent.colorModeChanged(mode: mode));
    emit(state.copyWith(colorMode: mode));
  }

  // Editing (story 7).

  void setEditing(bool on) {
    if (on == state.editing) return;
    if (on) _onEvent(DocScanEvent.editModeEntered());
    emit(state.copyWith(editing: on, selection: null, view: PreviewView.text));
  }

  void editParagraph(String pageId, Paragraph paragraph, String text) {
    final DocumentEdits next = state.edits.edit((pageId, paragraph.id), text, original: paragraph.text);
    if (next.replacements[(pageId, paragraph.id)] != state.edits.replacements[(pageId, paragraph.id)]) {
      _onEvent(DocScanEvent.paragraphEdited());
    }
    _setEdits(next);
  }

  // Selection and word redaction (story 8).

  void select(WordSelection? selection) => emit(state.copyWith(selection: selection));

  void redactSelection() {
    final WordSelection? s = state.selection;
    if (s == null) return;
    _onEvent(DocScanEvent.textRedacted(wordCount: s.end - s.start + 1));
    _setEdits(state.edits.redactWords(s.key, s.indexes), clearSelection: true);
  }

  void revealSelection() {
    final WordSelection? s = state.selection;
    if (s == null) return;
    _onEvent(DocScanEvent.redactionRemoved());
    _setEdits(state.edits.revealWords(s.key, s.indexes), clearSelection: true);
  }

  // Paragraph redaction (story 9).

  void toggleParagraphRedaction(String pageId, String paragraphId) {
    final ParagraphKey key = (pageId, paragraphId);
    _onEvent(state.edits.isParagraphRedacted(key) ? DocScanEvent.redactionRemoved() : DocScanEvent.paragraphRedacted());
    _setEdits(state.edits.toggleParagraph(key));
  }

  // Rename (story 15).

  /// Returns false and changes nothing for an empty name or one with a path
  /// separator. The name never goes into an event.
  bool rename(String input) {
    String name = input.trim();
    if (name.toLowerCase().endsWith('.pdf')) name = name.substring(0, name.length - 4).trim();
    if (name.isEmpty || name.contains('/') || name.contains(r'\') || name.contains(':')) return false;
    _onEvent(DocScanEvent.documentRenamed());
    emit(state.copyWith(fileStem: name));
    return true;
  }

  /// Builds what is sent: text form when anything was edited or redacted, otherwise
  /// the build-step image PDF, re-encoded only for a non-color scan color.
  Future<Either<BuildFailure, BuildOutput>> attach() async {
    if (state.attaching) return const Left<BuildFailure, BuildOutput>(BuildFailure.unknown());
    emit(state.copyWith(attaching: true, failure: null));
    _estimate?.cancel();
    final Either<BuildFailure, BuildOutput> r;
    if (state.edits.isDirty) {
      r = await _builder.buildText(pages: state.pages, edits: state.edits, look: _look, out: _sessions.newFile('pdf'));
    } else if (state.colorMode != ScanColorMode.color) {
      r = await _fitter.fitImage(
        pages: state.pages,
        colorMode: state.colorMode,
        look: _look,
        maxBytes: _maxFileBytes,
        newFile: () => _sessions.newFile('pdf'),
      );
    } else {
      r = Right<BuildFailure, BuildOutput>(_built);
    }
    final Either<BuildFailure, BuildOutput> checked = r.flatMap(
      (BuildOutput o) => o.sizeBytes <= _maxFileBytes
          ? Right<BuildFailure, BuildOutput>(o)
          : Left<BuildFailure, BuildOutput>(BuildFailure.tooLarge(sizeBytes: o.sizeBytes, limitBytes: _maxFileBytes)),
    );
    if (isClosed) return checked;
    checked.fold((BuildFailure f) {
      if (f is BuildTooLarge) _onEvent(DocScanEvent.sizeLimitExceeded(sizeBytes: f.sizeBytes));
      emit(state.copyWith(attaching: false, failure: f));
    }, (BuildOutput _) => emit(state.copyWith(attaching: false)));
    return checked;
  }

  void cancelled() => _onEvent(DocScanEvent.cancelled(step: ScanStep.preview));

  void _setEdits(DocumentEdits edits, {bool clearSelection = false}) {
    emit(state.copyWith(edits: edits, selection: clearSelection ? null : state.selection));
    _scheduleEstimate();
  }

  /// Re-estimates the size of the form that attach would send (FR-011).
  void _scheduleEstimate() {
    _estimate?.cancel();
    if (!state.edits.isDirty) {
      emit(state.copyWith(sizeBytes: _built.sizeBytes));
      return;
    }
    _estimate = Timer(estimateDelay, () async {
      final File out = _estimateFile ??= _sessions.newFile('pdf');
      final Either<BuildFailure, BuildOutput> r = await _builder.buildText(
        pages: state.pages,
        edits: state.edits,
        look: _look,
        out: out,
      );
      if (!isClosed) r.fold((BuildFailure _) {}, (BuildOutput o) => emit(state.copyWith(sizeBytes: o.sizeBytes)));
    });
  }

  @override
  Future<void> close() {
    _estimate?.cancel();
    return super.close();
  }
}
