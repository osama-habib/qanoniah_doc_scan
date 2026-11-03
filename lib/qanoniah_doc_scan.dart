/// Qanoniah document scan: capture, review, recognize, redact, and build one PDF.
///
/// This file exports only the public surface (constitution P2). Everything else lives
/// under `lib/src/`.
library;

export 'src/core/doc_scan.dart' show DocScan;
export 'src/core/doc_scan_config.dart' show DocScanConfig;
export 'src/core/doc_scan_event.dart' show DocScanEvent;
export 'src/core/doc_scan_icons.dart' show DocScanIcons;
export 'src/core/doc_scan_result.dart' show DocScanResult, DocScanPdfForm;
export 'src/core/doc_scan_strings.dart' show DocScanStrings;
export 'src/core/doc_scan_theme.dart' show DocScanTheme;
export 'src/viewer/presentation/doc_scan_viewer.dart' show DocScanViewer;
