import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/scan_metrics.dart';
import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/presentation/scan_confirm.dart';

/// «حذف الصفحة N؟» (story 11, design `scanDelOpen`): the confirmation card with
/// the page's thumbnail, «إلغاء» and a red «حذف». True when the user confirmed.
Future<bool> showDeletePageDialog(
  BuildContext context, {
  required DocScanStrings strings,
  required int pageNumber,
  required File page,
}) {
  final DocScanTheme t = DocScanTheme.of(context);
  return showScanConfirm(
    context,
    title: strings.deletePageTitle(pageNumber),
    body: strings.deletePageBody,
    confirm: strings.deleteConfirm,
    cancel: strings.cancel,
    leading: Container(
      width: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: ScanMetrics.radius(6),
        border: Border.all(color: t.border),
      ),
      child: Image.file(page, fit: BoxFit.fitWidth, cacheWidth: 160),
    ),
  );
}
