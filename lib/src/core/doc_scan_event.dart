import 'package:flutter/foundation.dart';

import 'doc_scan_result.dart';
import 'failures.dart';
import 'session/scan_session.dart';

/// How a page move was made.
enum MoveVia { drag, action }

/// Recognition languages found in a document.
enum DocumentLanguages { ar, en, mixed }

/// Flow step reported in `scan_cancelled`.
enum ScanStep { permission, capture, review, build, preview }

/// One analytics event for the host to record (FR-057, contracts/events.md).
///
/// Events carry only a name and non-document metadata. The constructor is private,
/// so no caller can attach document text, words, images, or file names (FR-041).
@immutable
class DocScanEvent {
  const DocScanEvent._(this.name, [this.params = const <String, Object>{}]);

  final String name;

  /// Values are only [int], [bool], [double], or one of the enum strings listed in
  /// contracts/events.md.
  final Map<String, Object> params;

  factory DocScanEvent.started() => const DocScanEvent._('scan_started');

  factory DocScanEvent.permissionDenied() =>
      const DocScanEvent._('scan_permission_denied');

  factory DocScanEvent.permissionPermanentlyDenied() =>
      const DocScanEvent._('scan_permission_permanently_denied');

  factory DocScanEvent.pageCaptured({
    required CaptureMode mode,
    required int pageCount,
  }) =>
      DocScanEvent._('scan_page_captured', <String, Object>{
        'mode': mode.name,
        'page_count': pageCount,
      });

  factory DocScanEvent.pageLimitReached({required int maxPages}) =>
      DocScanEvent._('scan_page_limit_reached', <String, Object>{
        'max_pages': maxPages,
      });

  factory DocScanEvent.reviewOpened({required int pageCount}) =>
      DocScanEvent._('scan_review_opened', <String, Object>{
        'page_count': pageCount,
      });

  factory DocScanEvent.pageMoved({required MoveVia via}) =>
      DocScanEvent._('scan_page_moved', <String, Object>{'via': via.name});

  factory DocScanEvent.pageMoveUndone() =>
      const DocScanEvent._('scan_page_move_undone');

  factory DocScanEvent.pageAdded({required int pageCount}) =>
      DocScanEvent._('scan_page_added', <String, Object>{
        'page_count': pageCount,
      });

  factory DocScanEvent.pageRetaken() =>
      const DocScanEvent._('scan_page_retaken');

  factory DocScanEvent.pageDeleted({required int pageCount}) =>
      DocScanEvent._('scan_page_deleted', <String, Object>{
        'page_count': pageCount,
      });

  factory DocScanEvent.cornersAdjusted() =>
      const DocScanEvent._('scan_corners_adjusted');

  factory DocScanEvent.filterApplied({
    required Set<PageFilter> filters,
    required bool allPages,
  }) {
    final List<String> names = (filters.toList()
          ..sort((PageFilter a, PageFilter b) => a.index.compareTo(b.index)))
        .map(_filterName)
        .toList();
    return DocScanEvent._('scan_filter_applied', <String, Object>{
      'filters': names.join(','),
      'all_pages': allPages,
    });
  }

  factory DocScanEvent.buildStarted({required int pageCount}) =>
      DocScanEvent._('scan_build_started', <String, Object>{
        'page_count': pageCount,
      });

  factory DocScanEvent.buildCompleted({
    required int pageCount,
    required int durationMs,
    required DocumentLanguages languages,
  }) =>
      DocScanEvent._('scan_build_completed', <String, Object>{
        'page_count': pageCount,
        'duration_ms': durationMs,
        'languages': languages.name,
      });

  factory DocScanEvent.buildFailed(BuildFailure failure) =>
      DocScanEvent._('scan_build_failed', <String, Object>{
        'error': failure is BuildStorageFull ? 'storage_full' : 'unknown',
      });

  factory DocScanEvent.pageNoText() => const DocScanEvent._('scan_page_no_text');

  factory DocScanEvent.previewOpened() =>
      const DocScanEvent._('scan_preview_opened');

  factory DocScanEvent.photoViewOpened() =>
      const DocScanEvent._('scan_photo_view_opened');

  factory DocScanEvent.colorModeChanged({required ScanColorMode mode}) =>
      DocScanEvent._('scan_color_mode_changed', <String, Object>{
        'mode': mode.name,
      });

  factory DocScanEvent.editModeEntered() =>
      const DocScanEvent._('scan_edit_mode_entered');

  factory DocScanEvent.paragraphEdited() =>
      const DocScanEvent._('scan_paragraph_edited');

  factory DocScanEvent.textRedacted({required int wordCount}) =>
      DocScanEvent._('scan_text_redacted', <String, Object>{
        'word_count': wordCount,
      });

  factory DocScanEvent.paragraphRedacted() =>
      const DocScanEvent._('scan_paragraph_redacted');

  factory DocScanEvent.redactionRemoved() =>
      const DocScanEvent._('scan_redaction_removed');

  /// Never carries the new name.
  factory DocScanEvent.documentRenamed() =>
      const DocScanEvent._('scan_document_renamed');

  factory DocScanEvent.sizeLimitExceeded({required int sizeBytes}) =>
      DocScanEvent._('scan_size_limit_exceeded', <String, Object>{
        'size_bucket': _overLimitBucket(sizeBytes),
      });

  factory DocScanEvent.attached({
    required int pageCount,
    required DocScanPdfForm form,
    required int redactionCount,
    required int editedParagraphCount,
    required int sizeBytes,
    required bool compressed,
    required int durationMs,
  }) =>
      DocScanEvent._('scan_attached', <String, Object>{
        'page_count': pageCount,
        'form': form.name,
        'redaction_count': redactionCount,
        'edited_paragraph_count': editedParagraphCount,
        'size_bucket': _attachedBucket(sizeBytes),
        'compressed': compressed,
        'duration_ms': durationMs,
      });

  factory DocScanEvent.cancelled({required ScanStep step}) =>
      DocScanEvent._('scan_cancelled', <String, Object>{'step': step.name});

  factory DocScanEvent.viewerOpened() =>
      const DocScanEvent._('scan_viewer_opened');

  static String _filterName(PageFilter f) => switch (f) {
    PageFilter.original => 'original',
    PageFilter.autoEnhance => 'auto',
    PageFilter.sharpenText => 'text',
    PageFilter.removeShadows => 'shadow',
    PageFilter.highContrast => 'contrast',
    PageFilter.grayscale => 'gray',
    PageFilter.blackWhite => 'bw',
  };

  static const int _mb = 1024 * 1024;

  static String _attachedBucket(int bytes) {
    if (bytes < _mb) return '<1';
    if (bytes < 2 * _mb) return '1-2';
    return '2-5';
  }

  static String _overLimitBucket(int bytes) {
    if (bytes < 10 * _mb) return '5-10';
    if (bytes < 20 * _mb) return '10-20';
    return '20+';
  }

  @override
  String toString() => 'DocScanEvent($name, $params)';
}
