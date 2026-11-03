import 'package:flutter/foundation.dart';

import 'doc_scan_event.dart';
import 'doc_scan_strings.dart';

/// What the host passes to `DocScan.start` (FR-030).
///
/// The theme and icons are not here: they are read from the host's
/// `ThemeData.extensions` (`DocScanTheme`).
@immutable
class DocScanConfig {
  const DocScanConfig({
    required this.pdfFont,
    required this.pdfFontFallback,
    this.pdfFontBold,
    this.strings,
    this.onEvent,
    this.fileNumber = 1,
    this.maxFileBytes = 5 * 1024 * 1024,
    this.maxPages,
  }) : assert(fileNumber > 0),
       assert(maxFileBytes > 0),
       assert(maxPages == null || maxPages > 0);

  /// Noto Sans Arabic regular, from the host's assets. Embedded in text-form PDFs.
  final Uint8List pdfFont;

  /// Noto Sans regular, from the host's assets. Without it the `pdf` package drops
  /// Latin letters, digits' punctuation, `(`, `)` and `%` inside Arabic text
  /// (research R7, spike T010).
  final Uint8List pdfFontFallback;

  /// Optional bold weight for headings in text-form PDFs.
  final Uint8List? pdfFontBold;

  /// Null: the built-in Arabic or English strings, by the app's locale.
  final DocScanStrings? strings;

  /// Receives analytics events (contracts/events.md).
  final void Function(DocScanEvent event)? onEvent;

  /// NN in «مستند-ممسوح-NN.pdf» (FR-022).
  final int fileNumber;

  /// The host's per-file upload limit (FR-061).
  final int maxFileBytes;

  /// Null means no page limit (FR-009).
  final int? maxPages;
}
