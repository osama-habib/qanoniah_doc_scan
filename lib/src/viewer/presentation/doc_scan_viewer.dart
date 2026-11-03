import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:printing/printing.dart';

import '../../core/scan_metrics.dart';
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
    final DocScanStrings s =
        widget.strings ??
        (Localizations.localeOf(context).languageCode == 'ar' ? DocScanStrings.ar() : DocScanStrings.en());
    final TextStyle name = t.bodyStyle.sized(14, 20).copyWith(color: t.onSurface, fontWeight: FontWeight.w700);
    // Design `scanViewOnly`: the preview's header with ✕, no tip and no attach.
    return Scaffold(
      backgroundColor: t.surface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              padding: ScanMetrics.header,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.surfaceTertiary)),
              ),
              child: Row(
                children: <Widget>[
                  ScanIconButton(
                    icon: t.icons.close,
                    label: s.close,
                    size: 16,
                    color: t.onSurface,
                    background: t.surfaceTertiary,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          SvgPicture.asset(t.icons.pdf, width: 18, height: 22),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(widget.fileName, style: name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _done ? s.pageCount(_pages.length) : '',
                    style: t.captionStyle.sized(12, 16).copyWith(color: t.onSurfaceMuted),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: t.canvas,
                child: _pages.isEmpty && !_done
                    ? Center(child: CircularProgressIndicator(color: t.primary))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        itemCount: _pages.length,
                        separatorBuilder: (BuildContext context, int _) => const SizedBox(height: 14),
                        itemBuilder: (BuildContext context, int i) => Semantics(
                          image: true,
                          label: s.pageLabel(i + 1),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: t.surface,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: t.inverseSurface.withValues(alpha: 0.08),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                                BoxShadow(
                                  color: t.inverseSurface.withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Image.memory(_pages[i], fit: BoxFit.fitWidth),
                          ),
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
