# Contract: Public API of `qanoniah_doc_scan`

This is everything `lib/qanoniah_doc_scan.dart` exports (P2, FR-037). Any change to it is a
breaking change, which needs a major version bump and a CHANGELOG entry. The signatures are the
contract; the bodies are implementation.

```dart
/// Entry point. Returns null on cancel (FR-021, FR-031).
abstract final class DocScan {
  static Future<DocScanResult?> start(BuildContext context, DocScanConfig config);
}

class DocScanConfig {
  const DocScanConfig({
    required this.pdfFont,          // Noto Sans Arabic regular, from the host's assets (R7)
    required this.pdfFontFallback,  // Noto Sans regular: Latin, `( ) %` inside Arabic (R7, T010)
    this.pdfFontBold,               // optional, for headings in text form
    this.strings,                   // null: built-in ar/en by Localizations locale
    this.onEvent,                   // analytics callback (contracts/events.md)
    this.fileNumber = 1,            // NN in «مستند-ممسوح-NN.pdf» (FR-022)
    this.maxFileBytes = 5 * 1024 * 1024, // host upload limit (FR-061)
    this.maxPages,                  // null: no limit (FR-009)
  });
  final Uint8List pdfFont;
  final Uint8List pdfFontFallback;
  final Uint8List? pdfFontBold;
  final DocScanStrings? strings;
  final void Function(DocScanEvent event)? onEvent;
  final int fileNumber;
  final int maxFileBytes;
  final int? maxPages;
}

enum DocScanPdfForm { text, image }

class DocScanResult {
  final File pdf;            // ownership passes to the host (FR-035)
  final String fileName;
  final DocScanPdfForm form;
  final int pageCount;
  final int sizeBytes;
  final List<String> pageTexts; // final, edited, redaction-free, in page order
}

/// Every user-facing string; ar() and en() defaults, copyWith for overrides (FR-036).
class DocScanStrings {
  const DocScanStrings({/* one named field per string */});
  factory DocScanStrings.ar();
  factory DocScanStrings.en();
  DocScanStrings copyWith({/* same fields, optional */});
}

/// Host fills it from Qanoniah kit tokens and adds it to ThemeData.extensions (FR-070).
class DocScanTheme extends ThemeExtension<DocScanTheme> {
  // Color, TextStyle, spacing and radius fields, plus `final DocScanIcons icons;`.
  // No defaults; the example app holds the only literal values (fallback theme).
}

/// SVG asset paths the host supplies from its own iconsax assets (FR-072).
/// The package bundles no icon files.
class DocScanIcons {
  const DocScanIcons({
    required this.close, required this.capture, required this.autoMode, required this.manualMode,
    required this.addPage, required this.retake, required this.delete, required this.crop,
    required this.filters, required this.redact, required this.reveal, required this.edit,
    required this.document, required this.back, required this.done, required this.photoView,
  });
  final String close, capture, autoMode, manualMode, addPage, retake, delete, crop,
      filters, redact, reveal, edit, document, back, done, photoView;
}

class DocScanEvent {
  final String name;
  final Map<String, Object> params;
  // Private constructor; created by the package only.
}

/// Read-only view of a returned PDF (story 10, FR-023). No edit or reveal tools.
class DocScanViewer extends StatelessWidget {
  const DocScanViewer({super.key, required this.pdf, required this.fileName});
  final File pdf;
  final String fileName;
}
```

## Behavior guarantees

| Guarantee | Requirement |
|-----------|-------------|
| `start` returns at most one result per call; a second concurrent call throws `StateError` | FR-031 |
| `start` throws `StateError` if `DocScanTheme` is missing from the theme (no silent literal fallback) | FR-070 |
| No network I/O, no auth, no host imports, no service locator | FR-033, FR-040 |
| `pageTexts.length == pageCount`; no redacted word appears in any field | FR-031, FR-041 |
| `form == text` iff the user left any edit or redaction | FR-011 |
| `sizeBytes <= maxFileBytes` always; otherwise attach was blocked in the UI and no result returned | FR-061 |
| All session temp files are gone when `start` completes; only `pdf` remains | FR-044 |
| At each `start`, returned PDFs older than 24 hours that the host did not delete are removed | FR-044 |
| Gating (signed out, entitlement, credit) is checked by the host before `start` | FR-034 |

## Host integration (qanoniah-mobile, not built here)

1. The attach menu becomes three equal cards «الصور · الملفات · مسح مستند». Camera is removed.
2. Before `start`: the existing gating (signed in, `user.features.agentFileUpload == 'full'`, credit).
3. Add `DocScanTheme` built from kit tokens to `ThemeData.extensions`, with `DocScanIcons` pointing at the host's `assets/icons/ds/iconsax/` files. Pass the Noto Sans Arabic bytes.
4. Map `DocScanResult` into the host's own composer attachment. Upload via the existing multipart `/agent-attachment-upload`. Delete `pdf` when done.
5. Forward `DocScanEvent`s to the host's analytics.
6. Tapping the chip in the same session opens `DocScanViewer` on the local `pdf`. After a reload it shows a plain chip (the uploaded blob cannot be read back).
7. A full release, not a Shorebird patch (native code; constitution V).
