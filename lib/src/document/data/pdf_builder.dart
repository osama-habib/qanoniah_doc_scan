import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show Rect;

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/doc_scan_result.dart';
import '../../core/failures.dart';
import '../../core/session/document_edits.dart';
import '../../core/session/scan_session.dart';
import '../../core/session/word_placement.dart';
import '../../recognition/data/post_processor.dart';
import 'page_background.dart';
import 'page_encoder.dart';
import 'text_pdf_renderer.dart';

export 'page_encoder.dart' show ImageEncoding;
export 'text_pdf_renderer.dart' show PdfTextBlock;

/// What [PdfBuilder] wrote (data-model BuildOutput).
@immutable
class BuildOutput {
  const BuildOutput({required this.file, required this.form, required this.sizeBytes, required this.compressed});

  final File file;
  final DocScanPdfForm form;
  final int sizeBytes;

  /// Image form only: the photos were re-encoded smaller to fit the limit.
  final bool compressed;
}

/// Look of the text-form PDF, from the host's theme and fonts.
@immutable
class PdfLook {
  const PdfLook({
    required this.font,
    required this.fontFallback,
    this.fontBold,
    required this.text,
    required this.redactionFill,
    required this.onRedactionFill,
    required this.redactedLabel,
  });

  final Uint8List font;
  final Uint8List fontFallback;
  final Uint8List? fontBold;
  final int text;
  final int redactionFill;
  final int onRedactionFill;

  /// «نص محجوب», drawn on whole-paragraph bars.
  final String redactedLabel;
}

/// Builds the one PDF, in session order (FR-011).
///
/// - Image form: each prepared photo full bleed, with the recognized text drawn
///   invisibly at the word boxes so the file is searchable.
/// - Text form: each page as printed (revised 2026-11-04): its background (the
///   scan with every redrawn, redacted or rewritten word erased from its pixels)
///   under the final text drawn in place. Redacted characters never reach the PDF,
///   and redacted words leave no pixels behind (FR-041, FR-042).
class PdfBuilder {
  const PdfBuilder({
    TextPdfRenderer textRenderer = const PdfPackageTextRenderer(),
    PageEncoder encoder = const PageEncoder(),
  }) : _textRenderer = textRenderer,
       _encoder = encoder;

  final TextPdfRenderer _textRenderer;
  final PageEncoder _encoder;

  static const double _pageWidth = 595; // A4 width in points.

  Future<Either<BuildFailure, BuildOutput>> buildImage({
    required List<CapturedPage> pages,
    required ScanColorMode colorMode,
    required ImageEncoding encoding,
    required PdfLook look,
    required File out,

    /// After each page is encoded: pages done, of all.
    void Function(int done, int total)? onPage,
  }) async {
    try {
      // One page at a time, never all at once (ClickUp z8y71x6uvk).
      final List<EncodedPage> encoded = <EncodedPage>[];
      final List<int> sourceWidths = <int>[];
      for (final CapturedPage p in pages) {
        final EncodedPage e = await _encoder.encode(p.preparedFile.path, encoding, colorMode);
        encoded.add(e);
        // Word boxes are in the prepared page's pixels.
        final (int, int)? prepared = jpegSize(await p.preparedFile.readAsBytes());
        sourceWidths.add(prepared?.$1 ?? e.width);
        onPage?.call(encoded.length, pages.length);
      }
      final List<_ImagePage> inputs = <_ImagePage>[
        for (int i = 0; i < pages.length; i++)
          _ImagePage(
            page: encoded[i],
            sourceWidth: sourceWidths[i],
            words: switch (pages[i].recognition) {
              RecognitionDone(:final PageText text) =>
                text.paragraphs.expand((Paragraph para) => para.words).map((Word w) => (w.text, w.box)).toList(),
              _ => const <(String, Rect)>[],
            },
            rtl: switch (pages[i].recognition) {
              RecognitionDone(:final PageText text) => text.language == RecognitionLanguage.ar,
              _ => true,
            },
          ),
      ];
      final Uint8List font = look.font;
      final Uint8List fallback = look.fontFallback;
      // Only laying out: the JPEGs go in as they are.
      final Uint8List bytes = await Isolate.run(() => _imagePdf(inputs, font, fallback));
      await out.writeAsBytes(bytes, flush: true);
      return Right<BuildFailure, BuildOutput>(
        BuildOutput(
          file: out,
          form: DocScanPdfForm.image,
          sizeBytes: bytes.length,
          compressed: encoding != ImageEncoding.ladder.first,
        ),
      );
    } on FileSystemException catch (e) {
      return Left<BuildFailure, BuildOutput>(_storage(e));
    } on Object {
      return const Left<BuildFailure, BuildOutput>(BuildFailure.unknown());
    }
  }

  /// A page as printed: A4 wide in points, its own height; its background
  /// without the words that are drawn or edited away.
  static Future<PdfPlacedPage?> _placed(CapturedPage page, DocumentEdits edits, File bgFile) async {
    final PageBackgroundImage? bg = await PageBackground.forPage(page, edits: edits, out: bgFile, jpeg: true);
    if (bg == null) return null;
    final double k = 595 / bg.width;
    Rect pt(Rect r) => Rect.fromLTRB(r.left * k, r.top * k, r.right * k, r.bottom * k);
    final List<PdfPlaced> items = <PdfPlaced>[];
    final RecognitionState r = page.recognition;
    if (r is RecognitionDone) {
      // Text coordinates are the recognized image's, the background's size.
      final double tk = r.text.width > 0 ? bg.width / r.text.width : 1;
      Rect at(Rect b) => pt(Rect.fromLTRB(b.left * tk, b.top * tk, b.right * tk, b.bottom * tk));
      for (final Paragraph p in r.text.paragraphs) {
        if (p.words.isEmpty) continue;
        final ParagraphKey key = (page.id, p.id);
        final Rect box = at(p.words.map((Word w) => w.box).reduce((Rect a, Rect b) => a.expandToInclude(b)));
        if (edits.isParagraphRedacted(key)) {
          items.add(PdfPlacedBar(box, paragraph: true));
          continue;
        }
        final String? replaced = edits.replacements[key];
        if (replaced != null) {
          final List<double> ems = p.words.map((Word w) => w.em).toList()..sort();
          items.add(PdfPlacedFlow(box, text: replaced, em: ems[ems.length ~/ 2] * tk * k, rtl: !p.mostlyLatin));
          continue;
        }
        for (int i = 0; i < p.words.length; i++) {
          final Word w = p.words[i];
          if (edits.isWordRedacted(key, i)) {
            items.add(PdfPlacedBar(at(w.box)));
          } else if (w.drawable) {
            items.add(
              PdfPlacedWord(
                at(w.box),
                text: w.text,
                em: w.em * tk * k,
                baseline: w.baselineY * tk * k,
                bold: w.bold,
                rtl: PostProcessor.hasArabic(w.text),
              ),
            );
          }
        }
      }
    }
    return PdfPlacedPage(width: 595, height: bg.height * k, background: await bg.file.readAsBytes(), items: items);
  }

  Future<Either<BuildFailure, BuildOutput>> buildText({
    required List<CapturedPage> pages,
    required DocumentEdits edits,
    required PdfLook look,
    required File out,
  }) async {
    try {
      final List<PdfPlacedPage> placed = <PdfPlacedPage>[];
      for (int i = 0; i < pages.length; i++) {
        final PdfPlacedPage? page = await _placed(pages[i], edits, File('${out.path}.bg$i.jpg'));
        if (page == null) throw StateError('Page ${i + 1} could not be read.');
        placed.add(page);
      }
      final Uint8List bytes = await _textRenderer.renderPlaced(placed, look);
      for (int i = 0; i < pages.length; i++) {
        final File bg = File('${out.path}.bg$i.jpg');
        if (bg.existsSync()) bg.deleteSync();
      }
      await out.writeAsBytes(bytes, flush: true);
      return Right<BuildFailure, BuildOutput>(
        BuildOutput(file: out, form: DocScanPdfForm.text, sizeBytes: bytes.length, compressed: false),
      );
    } on FileSystemException catch (e) {
      return Left<BuildFailure, BuildOutput>(_storage(e));
    } on Object {
      return const Left<BuildFailure, BuildOutput>(BuildFailure.unknown());
    }
  }

  static BuildFailure _storage(FileSystemException e) =>
      e.osError?.errorCode == 28 ? const BuildFailure.storageFull() : const BuildFailure.unknown();
}

class _ImagePage {
  const _ImagePage({required this.page, required this.sourceWidth, required this.words, required this.rtl});
  final EncodedPage page;

  /// The prepared page's width, which the word boxes are measured in.
  final int sourceWidth;
  final List<(String, Rect)> words;
  final bool rtl;
}

/// Runs in an isolate: lays out the image-form PDF around the encoded pages.
Future<Uint8List> _imagePdf(List<_ImagePage> pages, Uint8List font, Uint8List fallback) async {
  final pw.Document doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: pw.Font.ttf(ByteData.sublistView(font)),
      fontFallback: <pw.Font>[pw.Font.ttf(ByteData.sublistView(fallback))],
    ),
  );
  for (final _ImagePage p in pages) {
    final Uint8List jpg = p.page.bytes;
    // Word boxes are in the prepared page's pixels; the page keeps its shape.
    final double scale = PdfBuilder._pageWidth / p.sourceWidth;
    final PdfPageFormat format = PdfPageFormat(
      PdfBuilder._pageWidth,
      p.page.height * PdfBuilder._pageWidth / p.page.width,
    );
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context _) => pw.Stack(
          children: <pw.Widget>[
            pw.Positioned.fill(child: pw.Image(pw.MemoryImage(jpg), fit: pw.BoxFit.fill)),
            for (final (String text, Rect box) in p.words)
              if (box.width > 0 && box.height > 0)
                pw.Positioned(
                  left: box.left * scale,
                  top: box.top * scale,
                  child: pw.SizedBox(
                    width: box.width * scale,
                    height: box.height * scale,
                    child: pw.FittedBox(
                      fit: pw.BoxFit.fill,
                      child: pw.Text(
                        text,
                        textDirection: p.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                        style: const pw.TextStyle(renderingMode: PdfTextRenderingMode.invisible),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
  return doc.save();
}
