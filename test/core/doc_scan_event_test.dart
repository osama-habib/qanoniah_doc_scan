import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/src/core/doc_scan_event.dart';
import 'package:qanoniah_doc_scan/src/core/doc_scan_result.dart';
import 'package:qanoniah_doc_scan/src/core/failures.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';

/// Allowed event names and, for each, the allowed param keys (contracts/events.md).
const Map<String, Set<String>> _contract = <String, Set<String>>{
  'scan_started': <String>{},
  'scan_permission_denied': <String>{},
  'scan_permission_permanently_denied': <String>{},
  'scan_page_captured': <String>{'mode', 'page_count'},
  'scan_page_limit_reached': <String>{'max_pages'},
  'scan_review_opened': <String>{'page_count'},
  'scan_page_moved': <String>{'via'},
  'scan_page_move_undone': <String>{},
  'scan_page_added': <String>{'page_count'},
  'scan_page_retaken': <String>{},
  'scan_page_deleted': <String>{'page_count'},
  'scan_corners_adjusted': <String>{},
  'scan_filter_applied': <String>{'filters', 'all_pages'},
  'scan_build_started': <String>{'page_count'},
  'scan_build_completed': <String>{'page_count', 'duration_ms', 'languages'},
  'scan_build_failed': <String>{'error'},
  'scan_page_no_text': <String>{},
  'scan_preview_opened': <String>{},
  'scan_photo_view_opened': <String>{},
  'scan_color_mode_changed': <String>{'mode'},
  'scan_edit_mode_entered': <String>{},
  'scan_paragraph_edited': <String>{},
  'scan_text_redacted': <String>{'word_count'},
  'scan_paragraph_redacted': <String>{},
  'scan_redaction_removed': <String>{},
  'scan_document_renamed': <String>{},
  'scan_size_limit_exceeded': <String>{'size_bucket'},
  'scan_attached': <String>{
    'page_count', 'form', 'redaction_count', 'edited_paragraph_count',
    'size_bucket', 'compressed', 'duration_ms',
  },
  'scan_cancelled': <String>{'step'},
  'scan_viewer_opened': <String>{},
};

/// The only string values a param may take.
final RegExp _allowedString = RegExp(
  r'^(auto|manual|drag|action|ar|en|mixed|storage_full|unknown|color|gray|bw|'
  r'text|image|permission|capture|review|build|preview|<1|1-2|2-5|5-10|10-20|20\+|'
  r'(original|auto|text|shadow|contrast|gray|bw)(,(original|auto|text|shadow|contrast|gray|bw))*)$',
);

void main() {
  final List<DocScanEvent> all = <DocScanEvent>[
    DocScanEvent.started(),
    DocScanEvent.permissionDenied(),
    DocScanEvent.permissionPermanentlyDenied(),
    DocScanEvent.pageCaptured(mode: CaptureMode.auto, pageCount: 2),
    DocScanEvent.pageLimitReached(maxPages: 20),
    DocScanEvent.reviewOpened(pageCount: 3),
    DocScanEvent.pageMoved(via: MoveVia.drag),
    DocScanEvent.pageMoveUndone(),
    DocScanEvent.pageAdded(pageCount: 4),
    DocScanEvent.pageRetaken(),
    DocScanEvent.pageDeleted(pageCount: 2),
    DocScanEvent.cornersAdjusted(),
    DocScanEvent.filterApplied(
      filters: <PageFilter>{PageFilter.grayscale, PageFilter.removeShadows},
      allPages: true,
    ),
    DocScanEvent.buildStarted(pageCount: 3),
    DocScanEvent.buildCompleted(
      pageCount: 3,
      durationMs: 4200,
      languages: DocumentLanguages.mixed,
    ),
    DocScanEvent.buildFailed(const BuildFailure.storageFull()),
    DocScanEvent.pageNoText(),
    DocScanEvent.previewOpened(),
    DocScanEvent.photoViewOpened(),
    DocScanEvent.colorModeChanged(mode: ScanColorMode.gray),
    DocScanEvent.editModeEntered(),
    DocScanEvent.paragraphEdited(),
    DocScanEvent.textRedacted(wordCount: 2),
    DocScanEvent.paragraphRedacted(),
    DocScanEvent.redactionRemoved(),
    DocScanEvent.documentRenamed(),
    DocScanEvent.sizeLimitExceeded(sizeBytes: 12 * 1024 * 1024),
    DocScanEvent.attached(
      pageCount: 3,
      form: DocScanPdfForm.text,
      redactionCount: 1,
      editedParagraphCount: 2,
      sizeBytes: 300 * 1024,
      compressed: false,
      durationMs: 41000,
    ),
    DocScanEvent.cancelled(step: ScanStep.review),
    DocScanEvent.viewerOpened(),
  ];

  test('every contract event has a factory', () {
    expect(all.map((DocScanEvent e) => e.name).toSet(), _contract.keys.toSet());
  });

  test('params use only contract keys and non-document values', () {
    for (final DocScanEvent e in all) {
      expect(e.params.keys.toSet(), _contract[e.name], reason: e.name);
      for (final Object v in e.params.values) {
        if (v is String) {
          expect(_allowedString.hasMatch(v), isTrue, reason: '${e.name}: $v');
        } else {
          expect(v is int || v is bool || v is double, isTrue, reason: e.name);
        }
      }
    }
  });

  test('size buckets', () {
    expect(
      DocScanEvent.sizeLimitExceeded(sizeBytes: 6 * 1024 * 1024).params['size_bucket'],
      '5-10',
    );
    expect(
      DocScanEvent.attached(
        pageCount: 1,
        form: DocScanPdfForm.image,
        redactionCount: 0,
        editedParagraphCount: 0,
        sizeBytes: 3 * 1024 * 1024,
        compressed: true,
        durationMs: 1,
      ).params['size_bucket'],
      '2-5',
    );
  });
}
