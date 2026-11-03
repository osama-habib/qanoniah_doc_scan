import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/session/document_edits.dart';
import '../../core/session/scan_session.dart';
import 'pdf_builder.dart' show PdfLook;

/// One paragraph of a text-form page, as it will be sent: its direction and its
/// final segments (text, or redactions that carry no characters).
@immutable
class PdfTextBlock {
  const PdfTextBlock({
    required this.rtl,
    required this.segments,
    this.align = BlockAlign.start,
    this.size = 1,
    this.heading = false,
    this.spaceBefore = 0,
    this.indent = 0,
    this.table,
    this.row,
    this.col,
  });

  /// Builds a block from a recognized paragraph's layout.
  factory PdfTextBlock.of(Paragraph p, List<FinalSegment> segments, {required bool rtl}) => PdfTextBlock(
    rtl: p.mostlyLatin ? false : rtl,
    segments: segments,
    align: p.align,
    size: p.size,
    heading: p.heading,
    spaceBefore: p.spaceBefore,
    indent: p.indent,
    table: p.table,
    row: p.row,
    col: p.col,
  );

  final bool rtl;
  final List<FinalSegment> segments;
  final BlockAlign align;

  /// Print size relative to the body text.
  final double size;
  final bool heading;

  /// Blank space above, in body line heights.
  final double spaceBefore;

  /// From the start margin, as a share of the text width.
  final double indent;

  /// Table cell placement, when the block is one.
  final int? table;
  final int? row;
  final int? col;
}

/// Lays out the text-form PDF, one scanned page per run of PDF pages (FR-011).
///
/// A port because it is a platform seam (P5): the platform renderer gets Arabic
/// shaping, mixed Arabic and Latin order, and an extractable text layer right
/// (research R7, owner decision 2026-11-03); the `pdf`-package renderer is the
/// fallback and runs in tests.
abstract interface class TextPdfRenderer {
  /// Throws on failure; [PdfBuilder] maps it to a build failure.
  Future<Uint8List> render(List<List<PdfTextBlock>> pages, PdfLook look);
}

/// Text form through each platform's own text engine: TextKit / CoreText on iOS,
/// `PdfDocument` with `StaticLayout` on Android. Falls back to [fallback] when the
/// native side is missing.
class PlatformTextPdfRenderer implements TextPdfRenderer {
  PlatformTextPdfRenderer({required this.fallback, MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('qanoniah_doc_scan/pdf');

  final TextPdfRenderer fallback;
  final MethodChannel _channel;

  @override
  Future<Uint8List> render(List<List<PdfTextBlock>> pages, PdfLook look) async {
    try {
      final Uint8List? pdf = await _channel.invokeMethod<Uint8List>(
        'renderText',
        <String, Object?>{
          'font': look.font,
          'fontFallback': look.fontFallback,
          'fontBold': look.fontBold,
          'text': look.text,
          'fill': look.redactionFill,
          'onFill': look.onRedactionFill,
          'label': look.redactedLabel,
          'pages': <List<Map<String, Object>>>[
            for (final List<PdfTextBlock> page in pages)
              <Map<String, Object>>[
                for (final PdfTextBlock b in page)
                  <String, Object>{
                    'rtl': b.rtl,
                    'align': b.align.name,
                    'size': b.size,
                    'heading': b.heading,
                    'space': b.spaceBefore,
                    'indent': b.indent,
                    if (b.table != null) 'table': b.table!,
                    if (b.row != null) 'row': b.row!,
                    if (b.col != null) 'col': b.col!,
                    'segments': <Map<String, Object>>[
                      for (final FinalSegment s in b.segments)
                        switch (s) {
                          FinalText(:final String text) => <String, Object>{
                            'text': text,
                          },
                          FinalRedaction(:final bool wholeParagraph) =>
                            <String, Object>{
                              'redacted': wholeParagraph
                                  ? 'paragraph'
                                  : 'words',
                            },
                        },
                    ],
                  },
              ],
          ],
        },
      );
      if (pdf == null) throw StateError('No PDF.');
      return pdf;
    } on MissingPluginException {
      return fallback.render(pages, look);
    }
  }
}

/// Text form through the `pdf` package. Known defect (research R7): Latin runs
/// inside Arabic render reversed, and its text layer is emitted glyph by glyph.
class PdfPackageTextRenderer implements TextPdfRenderer {
  const PdfPackageTextRenderer();

  @override
  Future<Uint8List> render(List<List<PdfTextBlock>> pages, PdfLook look) {
    final pw.Font base = pw.Font.ttf(ByteData.sublistView(look.font));
    final pw.Font fallback = pw.Font.ttf(
      ByteData.sublistView(look.fontFallback),
    );
    final Uint8List? boldBytes = look.fontBold;
    final pw.ThemeData theme = pw.ThemeData.withFont(
      base: base,
      bold: boldBytes == null
          ? base
          : pw.Font.ttf(ByteData.sublistView(boldBytes)),
      fontFallback: <pw.Font>[fallback],
    );
    final PdfColor ink = PdfColor.fromInt(look.text);
    final PdfColor fill = PdfColor.fromInt(look.redactionFill);
    final PdfColor onFill = PdfColor.fromInt(look.onRedactionFill);
    final pw.Document doc = pw.Document(theme: theme);
    for (final List<PdfTextBlock> blocks in pages) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.applyMargin(
            left: 48,
            top: 56,
            right: 48,
            bottom: 56,
          ),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context _) => <pw.Widget>[
            for (final PdfTextBlock b in blocks)
              _paragraph(b, ink, fill, onFill, look.redactedLabel),
          ],
        ),
      );
    }
    if (pages.every((List<PdfTextBlock> b) => b.isEmpty)) {
      doc.addPage(pw.Page(build: (pw.Context _) => pw.SizedBox()));
    }
    return doc.save();
  }

  static pw.Widget _paragraph(
    PdfTextBlock b,
    PdfColor ink,
    PdfColor fill,
    PdfColor onFill,
    String label,
  ) {
    final pw.TextDirection dir = b.rtl
        ? pw.TextDirection.rtl
        : pw.TextDirection.ltr;
    final pw.Widget body;
    if (b.segments.length == 1 && b.segments.first is FinalRedaction) {
      body = pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: pw.BoxDecoration(
          color: fill,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          label,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(color: onFill, fontSize: 11),
        ),
      );
    } else {
      body = pw.RichText(
        textDirection: dir,
        textAlign: b.rtl ? pw.TextAlign.right : pw.TextAlign.left,
        text: pw.TextSpan(
          style: pw.TextStyle(color: ink, fontSize: 12, lineSpacing: 4),
          children: <pw.InlineSpan>[
            for (final FinalSegment s in b.segments)
              switch (s) {
                FinalText(:final String text) => pw.TextSpan(text: '$text '),
                FinalRedaction() => pw.WidgetSpan(
                  child: pw.Container(
                    width: 36,
                    height: 11,
                    margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                    decoration: pw.BoxDecoration(
                      color: fill,
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                  ),
                ),
              },
          ],
        ),
      );
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: body,
    );
  }
}
