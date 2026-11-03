import 'package:flutter/material.dart';

import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/presentation/scan_widgets.dart';

/// «حذف الصفحة N؟» confirmation (story 11). True when the user confirmed.
Future<bool> showDeletePageDialog(
  BuildContext context, {
  required DocScanStrings strings,
  required int pageNumber,
}) async {
  final DocScanTheme t = DocScanTheme.of(context);
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialog) => Dialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusLg)),
      child: Padding(
        padding: EdgeInsets.all(t.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(strings.deletePageTitle(pageNumber), style: t.titleStyle.copyWith(color: t.onSurface)),
            SizedBox(height: t.spaceSm),
            Text(strings.deletePageBody, style: t.bodyStyle.copyWith(color: t.onSurfaceMuted)),
            SizedBox(height: t.spaceLg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                ScanQuietButton(label: strings.cancel, color: t.onSurface, onPressed: () => Navigator.of(dialog).pop(false)),
                SizedBox(width: t.spaceSm),
                ScanQuietButton(label: strings.deleteConfirm, color: t.danger, onPressed: () => Navigator.of(dialog).pop(true)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}
