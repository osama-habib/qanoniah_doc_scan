import 'package:flutter/material.dart';

import '../../core/scan_metrics.dart';
import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/failures.dart';
import '../../core/presentation/scan_widgets.dart';

/// The preview's bottom (story 5, FR-061, design `scanPdf`): the hidden-word
/// count when there is one, the size-limit message, and «إرفاق كملف PDF».
class AttachBar extends StatelessWidget {
  const AttachBar({
    super.key,
    required this.strings,
    required this.hiddenWords,
    required this.busy,
    required this.failure,
    required this.onAttach,
  });

  final DocScanStrings strings;
  final int hiddenWords;
  final bool busy;
  final BuildFailure? failure;
  final VoidCallback onAttach;

  static const double _mb = 1024 * 1024;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final BuildFailure? f = failure;
    final String? error = switch (f) {
      BuildTooLarge(:final int sizeBytes, :final int limitBytes) => strings.sizeLimit(
        sizeBytes / _mb,
        limitBytes / _mb,
      ),
      BuildStorageFull() => strings.storageFull,
      BuildUnknown() => strings.buildFailed,
      null => null,
    };
    final TextStyle small = t.captionStyle.sized(12, 18).copyWith(color: t.onSurfaceMuted);
    return Container(
      padding: ScanMetrics.previewBar,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.surfaceTertiary)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (hiddenWords > 0) ...<Widget>[
            Text(strings.redactedWords(hiddenWords), style: small, textAlign: TextAlign.center),
            const SizedBox(height: 10),
          ],
          if (error != null) ...<Widget>[
            Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: small.copyWith(color: t.danger),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
          ],
          ScanPrimaryButton(label: strings.attach, busy: busy, onPressed: onAttach),
        ],
      ),
    );
  }
}
