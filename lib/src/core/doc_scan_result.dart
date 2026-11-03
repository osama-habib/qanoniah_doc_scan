import 'dart:io';

import 'package:flutter/foundation.dart';

/// The two shapes of the returned PDF (FR-011).
enum DocScanPdfForm {
  /// Pages built from the final text; no photos. Used when the user edited or
  /// redacted anything.
  text,

  /// The captured photos plus an invisible text layer. Used for untouched documents.
  image,
}

/// What the host receives on attach (FR-031).
///
/// A plain value describing the scan. It is deliberately not the host's attachment
/// model; the host maps it into its own (FR-032).
@immutable
class DocScanResult {
  const DocScanResult({
    required this.pdf,
    required this.fileName,
    required this.form,
    required this.pageCount,
    required this.sizeBytes,
    required this.pageTexts,
  });

  /// Ownership passes to the host, which deletes it when done (FR-035).
  final File pdf;
  final String fileName;
  final DocScanPdfForm form;
  final int pageCount;
  final int sizeBytes;

  /// Final text of each page, in page order: edited and redaction-free.
  final List<String> pageTexts;
}
