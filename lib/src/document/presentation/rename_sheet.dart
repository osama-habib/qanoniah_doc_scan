import 'package:flutter/material.dart';

import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/presentation/scan_widgets.dart';

// TODO(unused): the design renames in place in the preview header.
/// «إعادة تسمية المستند» (story 15). [onSave] returns false for an invalid name,
/// which keeps the sheet open.
Future<void> showRenameSheet(
  BuildContext context, {
  required DocScanStrings strings,
  required String current,
  required bool Function(String) onSave,
}) {
  final DocScanTheme t = DocScanTheme.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusSheet))),
    builder: (BuildContext sheet) => _RenameBody(strings: strings, current: current, onSave: onSave),
  );
}

class _RenameBody extends StatefulWidget {
  const _RenameBody({required this.strings, required this.current, required this.onSave});

  final DocScanStrings strings;
  final String current;
  final bool Function(String) onSave;

  @override
  State<_RenameBody> createState() => _RenameBodyState();
}

class _RenameBodyState extends State<_RenameBody> {
  late final TextEditingController _c = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    if (widget.onSave(_c.text)) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(t.spaceLg, 0, t.spaceLg, t.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(child: ScanSheetHandle(color: t.border)),
              ScanHeader(title: widget.strings.rename),
              TextField(
                controller: _c,
                autofocus: true,
                style: t.bodyStyle.copyWith(color: t.onSurface),
                cursorColor: t.primary,
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  suffixText: '.pdf',
                  filled: true,
                  fillColor: t.surfaceSecondary,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(t.radiusSm), borderSide: BorderSide(color: t.border)),
                ),
              ),
              SizedBox(height: t.spaceMd),
              ScanPrimaryButton(label: widget.strings.renameSave, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
