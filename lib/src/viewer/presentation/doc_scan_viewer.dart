import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/presentation/scan_widgets.dart';

/// Read-only view of the attached PDF (story 10, research R8).
///
/// It renders exactly the file that was sent, through the platform's PDF renderer,
/// with no edit or reveal tools, so redactions stay redacted. It emits no events;
/// the host records `DocScanEvent.viewerOpened()` when it opens the viewer.
class DocScanViewer extends StatefulWidget {
  const DocScanViewer({super.key, required this.pdf, required this.fileName, this.strings});

  final File pdf;
  final String fileName;

  /// Null: the built-in Arabic or English strings, by the app's locale.
  final DocScanStrings? strings;

  @override
  State<DocScanViewer> createState() => _DocScanViewerState();
}

class _DocScanViewerState extends State<DocScanViewer> {
  final List<Uint8List> _pages = <Uint8List>[];
  StreamSubscription<PdfRaster>? _sub;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final Uint8List bytes = await widget.pdf.readAsBytes();
    _sub = Printing.raster(bytes, dpi: 144).listen(
      (PdfRaster r) async {
        final Uint8List png = await r.toPng();
        if (mounted) setState(() => _pages.add(png));
      },
      onDone: () {
        if (mounted) setState(() => _done = true);
      },
      onError: (Object _) {
        if (mounted) setState(() => _done = true);
      },
    );
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final DocScanStrings s = widget.strings ??
        (Localizations.localeOf(context).languageCode == 'ar' ? DocScanStrings.ar() : DocScanStrings.en());
    return Scaffold(
      backgroundColor: t.surfaceSecondary,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            ScanHeader(
              title: widget.fileName,
              leading: ScanIconButton(
                icon: t.icons.close,
                label: s.close,
                color: t.onSurface,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: _pages.isEmpty && !_done
                  ? Center(child: CircularProgressIndicator(color: t.primary))
                  : ListView.separated(
                      padding: EdgeInsets.all(t.spaceMd),
                      itemCount: _pages.length,
                      separatorBuilder: (BuildContext context, int _) => SizedBox(height: t.spaceMd),
                      itemBuilder: (BuildContext context, int i) => Semantics(
                        image: true,
                        label: s.pageLabel(i + 1),
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border)),
                          child: Image.memory(_pages[i], fit: BoxFit.fitWidth),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
