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

/// One page of the text-form PDF drawn as printed (revised 2026-11-04), in PDF
/// points: the page's background (the scan without the words it erased) under
/// [items], each word at its printed place.
@immutable
class PdfPlacedPage {
  const PdfPlacedPage({required this.width, required this.height, required this.background, required this.items});

  final double width;
  final double height;

  /// JPEG or PNG bytes, drawn over the whole page.
  final Uint8List background;
  final List<PdfPlaced> items;
}

sealed class PdfPlaced {
  const PdfPlaced(this.box);

  final Rect box;
}

/// A word as text: [em] is its font size, [baseline] the y it sits on; it is
/// scaled across to the box's width.
class PdfPlacedWord extends PdfPlaced {
  const PdfPlacedWord(
    super.box, {
    required this.text,
    required this.em,
    required this.baseline,
    required this.bold,
    required this.rtl,
  });

  final String text;
  final double em;
  final double baseline;
  final bool bold;
  final bool rtl;
}

/// Hidden text: a filled bar, labeled «نص محجوب» when it hides a paragraph.
class PdfPlacedBar extends PdfPlaced {
  const PdfPlacedBar(super.box, {this.paragraph = false});

  final bool paragraph;
}

/// A rewritten paragraph: its new text flowing from the top of its old box.
class PdfPlacedFlow extends PdfPlaced {
  const PdfPlacedFlow(super.box, {required this.text, required this.em, required this.rtl});

  final String text;
  final double em;
  final bool rtl;
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

  /// The pages as printed, one PDF page each (revised 2026-11-04).
  Future<Uint8List> renderPlaced(List<PdfPlacedPage> pages, PdfLook look);
}

Map<String, Object> _rect(Rect r) => <String, Object>{'l': r.left, 't': r.top, 'r': r.right, 'b': r.bottom};

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
      final Uint8List? pdf = await _channel.invokeMethod<Uint8List>('renderText', <String, Object?>{
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
                        FinalText(:final String text) => <String, Object>{'text': text},
                        FinalRedaction(:final bool wholeParagraph) => <String, Object>{
                          'redacted': wholeParagraph ? 'paragraph' : 'words',
                        },
                      },
                  ],
                },
            ],
        ],
      });
      if (pdf == null) throw StateError('No PDF.');
      return pdf;
    } on MissingPluginException {
      return fallback.render(pages, look);
    }
  }

  @override
  Future<Uint8List> renderPlaced(List<PdfPlacedPage> pages, PdfLook look) async {
    try {
      final Uint8List? pdf = await _channel.invokeMethod<Uint8List>('renderPlaced', <String, Object?>{
        'font': look.font,
        'fontFallback': look.fontFallback,
        'fontBold': look.fontBold,
        'text': look.text,
        'fill': look.redactionFill,
        'onFill': look.onRedactionFill,
        'label': look.redactedLabel,
        'pages': <Map<String, Object>>[
          for (final PdfPlacedPage p in pages)
            <String, Object>{
              'w': p.width,
              'h': p.height,
              'bg': p.background,
              'items': <Map<String, Object>>[
                for (final PdfPlaced it in p.items)
                  switch (it) {
                    PdfPlacedWord() => <String, Object>{
                      'k': 'word',
                      ..._rect(it.box),
                      'text': it.text,
                      'em': it.em,
                      'base': it.baseline,
                      'bold': it.bold,
                      'rtl': it.rtl,
                    },
                    PdfPlacedBar() => <String, Object>{'k': 'bar', ..._rect(it.box), 'paragraph': it.paragraph},
                    PdfPlacedFlow() => <String, Object>{
                      'k': 'flow',
                      ..._rect(it.box),
                      'text': it.text,
                      'em': it.em,
                      'rtl': it.rtl,
                    },
                  },
              ],
            },
        ],
      });
      if (pdf == null) throw StateError('No PDF.');
      return pdf;
    } on MissingPluginException {
      return fallback.renderPlaced(pages, look);
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
    final pw.Font fallback = pw.Font.ttf(ByteData.sublistView(look.fontFallback));
    final Uint8List? boldBytes = look.fontBold;
    final pw.ThemeData theme = pw.ThemeData.withFont(
      base: base,
      bold: boldBytes == null ? base : pw.Font.ttf(ByteData.sublistView(boldBytes)),
      fontFallback: <pw.Font>[fallback],
    );
    final PdfColor ink = PdfColor.fromInt(look.text);
    final PdfColor fill = PdfColor.fromInt(look.redactionFill);
    final PdfColor onFill = PdfColor.fromInt(look.onRedactionFill);
    final pw.Document doc = pw.Document(theme: theme);
    for (final List<PdfTextBlock> blocks in pages) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.applyMargin(left: 48, top: 56, right: 48, bottom: 56),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context _) => <pw.Widget>[
            for (final PdfTextBlock b in blocks) _paragraph(b, ink, fill, onFill, look.redactedLabel),
          ],
        ),
      );
    }
    if (pages.every((List<PdfTextBlock> b) => b.isEmpty)) {
      doc.addPage(pw.Page(build: (pw.Context _) => pw.SizedBox()));
    }
    return doc.save();
  }

  @override
  Future<Uint8List> renderPlaced(List<PdfPlacedPage> pages, PdfLook look) {
    final pw.Font base = pw.Font.ttf(ByteData.sublistView(look.font));
    final pw.Font latin = pw.Font.ttf(ByteData.sublistView(look.fontFallback));
    final Uint8List? boldBytes = look.fontBold;
    final pw.Font bold = boldBytes == null ? base : pw.Font.ttf(ByteData.sublistView(boldBytes));
    final PdfColor ink = PdfColor.fromInt(look.text);
    final PdfColor fill = PdfColor.fromInt(look.redactionFill);
    final pw.Document doc = pw.Document();
    for (final PdfPlacedPage page in pages) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(page.width, page.height),
          margin: pw.EdgeInsets.zero,
          build: (pw.Context ctx) => pw.Stack(
            children: <pw.Widget>[
              pw.Positioned.fill(child: pw.Image(pw.MemoryImage(page.background), fit: pw.BoxFit.fill)),
              for (final PdfPlaced it in page.items)
                switch (it) {
                  PdfPlacedWord() => pw.Positioned(
                    left: it.box.left,
                    // The pdf package places text by its top; its ascent puts
                    // the baseline back where it was printed.
                    top: it.baseline - (it.bold ? bold : base).getFont(ctx).ascent * it.em,
                    child: pw.SizedBox(
                      width: it.box.width,
                      child: pw.FittedBox(
                        fit: pw.BoxFit.fitWidth,
                        child: pw.Text(
                          it.text,
                          textDirection: it.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                          style: pw.TextStyle(
                            font: it.bold ? bold : base,
                            fontFallback: <pw.Font>[latin],
                            fontSize: it.em,
                            color: ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                  PdfPlacedBar() => pw.Positioned(
                    left: it.box.left,
                    top: it.box.top,
                    child: pw.Container(width: it.box.width, height: it.box.height, color: fill),
                  ),
                  PdfPlacedFlow() => pw.Positioned(
                    left: it.box.left,
                    top: it.box.top,
                    child: pw.SizedBox(
                      width: it.box.width,
                      child: pw.Text(
                        it.text,
                        textDirection: it.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                        style: pw.TextStyle(font: base, fontFallback: <pw.Font>[latin], fontSize: it.em, color: ink),
                      ),
                    ),
                  ),
                },
            ],
          ),
        ),
      );
    }
    if (pages.isEmpty) doc.addPage(pw.Page(build: (pw.Context _) => pw.SizedBox()));
    return doc.save();
  }

  static pw.Widget _paragraph(PdfTextBlock b, PdfColor ink, PdfColor fill, PdfColor onFill, String label) {
    final pw.TextDirection dir = b.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final pw.Widget body;
    if (b.segments.length == 1 && b.segments.first is FinalRedaction) {
      body = pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: pw.BoxDecoration(color: fill, borderRadius: pw.BorderRadius.circular(4)),
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
                    decoration: pw.BoxDecoration(color: fill, borderRadius: pw.BorderRadius.circular(2)),
                  ),
                ),
              },
          ],
        ),
      );
    }
    return pw.Padding(padding: const pw.EdgeInsets.only(bottom: 10), child: body);
  }
}
