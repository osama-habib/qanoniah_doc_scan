import 'package:flutter/material.dart';

import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/failures.dart';
import '../../core/presentation/scan_widgets.dart';

/// «إرفاق كملف PDF» with the page count, size, merge note, and size-limit message
/// (story 5, FR-061).
class AttachBar extends StatelessWidget {
  const AttachBar({
    super.key,
    required this.strings,
    required this.pageCount,
    required this.sizeBytes,
    required this.busy,
    required this.failure,
    required this.onAttach,
  });

  final DocScanStrings strings;
  final int pageCount;
  final int sizeBytes;
  final bool busy;
  final BuildFailure? failure;
  final VoidCallback onAttach;

  static const double _mb = 1024 * 1024;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final BuildFailure? f = failure;
    final String? error = switch (f) {
      BuildTooLarge(:final int sizeBytes, :final int limitBytes) => strings.sizeLimit(sizeBytes / _mb, limitBytes / _mb),
      BuildStorageFull() => strings.storageFull,
      BuildUnknown() => strings.buildFailed,
      null => null,
    };
    return Container(
      padding: EdgeInsets.all(t.spaceLg),
      decoration: BoxDecoration(color: t.surface, border: Border(top: BorderSide(color: t.border))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '${strings.pageCount(pageCount)} · ${strings.fileSize(sizeBytes / _mb)}',
            style: t.captionStyle.copyWith(color: t.onSurfaceMuted),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: t.spaceXs),
          Text(strings.attachNote, style: t.captionStyle.copyWith(color: t.onSurfaceMuted), textAlign: TextAlign.center),
          if (error != null) ...<Widget>[
            SizedBox(height: t.spaceSm),
            Semantics(
              liveRegion: true,
              child: Text(error, style: t.captionStyle.copyWith(color: t.danger), textAlign: TextAlign.center),
            ),
          ],
          SizedBox(height: t.spaceSm),
          ScanPrimaryButton(label: strings.attach, busy: busy, onPressed: onAttach),
        ],
      ),
    );
  }
}
