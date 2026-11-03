import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/scan_metrics.dart';
import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';

/// «حذف الصفحة N؟» (story 11, design `scanDelOpen`): a card at the bottom with
/// the page's thumbnail, «إلغاء» and a red «حذف». True when the user confirmed.
Future<bool> showDeletePageDialog(
  BuildContext context, {
  required DocScanStrings strings,
  required int pageNumber,
  required File page,
}) async {
  final DocScanTheme t = DocScanTheme.of(context);
  final bool? ok = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: t.surface.withValues(alpha: 0),
    barrierColor: t.inverseSurface.withValues(alpha: 0.45),
    elevation: 0,
    builder: (BuildContext sheet) => SafeArea(
      child: Container(
        margin: ScanMetrics.deleteCardMargin,
        padding: ScanMetrics.deleteCard,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: ScanMetrics.radius(20),
          boxShadow: <BoxShadow>[
            BoxShadow(color: t.primary.withValues(alpha: 0.18), blurRadius: 32, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 56,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: ScanMetrics.radius(6),
                    border: Border.all(color: t.border),
                  ),
                  child: Image.file(page, fit: BoxFit.fitWidth, cacheWidth: 160),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        strings.deletePageTitle(pageNumber),
                        style: t.bodyStyle.sized(16, 24).copyWith(color: t.onSurface, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(strings.deletePageBody, style: t.bodyStyle.sized(13, 20).copyWith(color: t.onSurfaceMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Button(
                    label: strings.cancel,
                    color: t.surface,
                    textColor: t.onSurface,
                    border: t.border,
                    onTap: () => Navigator.of(sheet).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Button(
                    label: strings.deleteConfirm,
                    color: t.danger,
                    textColor: t.surface,
                    bold: true,
                    onTap: () => Navigator.of(sheet).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
    this.border,
    this.bold = false,
  });

  final String label;
  final Color color;
  final Color textColor;
  final Color? border;
  final bool bold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final BorderRadius r = ScanMetrics.radius(12);
    return Semantics(
      button: true,
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: r,
          side: border == null ? BorderSide.none : BorderSide(color: border!),
        ),
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: SizedBox(
            height: 46,
            child: Center(
              child: Text(
                label,
                style: t.bodyStyle
                    .sized(14, 20)
                    .copyWith(color: textColor, fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
