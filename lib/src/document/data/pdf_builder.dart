import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/doc_scan_result.dart';
import '../../core/failures.dart';
import '../../core/session/document_edits.dart';
import '../../core/session/scan_session.dart';

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

/// Image encoding for one image-form attempt (research R7 size fitting).
@immutable
class ImageEncoding {
  const ImageEncoding({required this.quality, required this.longEdge});

  final int quality;
  final int longEdge;

  /// Tried in order until the PDF fits; the last one is the legibility floor.
  static const List<ImageEncoding> ladder = <ImageEncoding>[
    ImageEncoding(quality: 85, longEdge: 2200),
    ImageEncoding(quality: 75, longEdge: 2200),
    ImageEncoding(quality: 65, longEdge: 1900),
    ImageEncoding(quality: 55, longEdge: 1600),
  ];
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
/// - Text form: pages laid out from the final text only; no photos, so redacted
///   content cannot survive in pixels, and redacted characters never reach the PDF
///   (FR-041, FR-042).
class PdfBuilder {
  const PdfBuilder();

  static const double _pageWidth = 595; // A4 width in points.

  Future<Either<BuildFailure, BuildOutput>> buildImage({
    required List<CapturedPage> pages,
    required ScanColorMode colorMode,
    required ImageEncoding encoding,
    required PdfLook look,
    required File out,
  }) async {
    try {
      final List<_ImagePage> inputs = <_ImagePage>[
        for (final CapturedPage p in pages)
          _ImagePage(
            path: p.preparedFile.path,
            words: switch (p.recognition) {
              RecognitionDone(:final PageText text) =>
                text.paragraphs.expand((Paragraph para) => para.words).map((Word w) => (w.text, w.box)).toList(),
              _ => const <(String, Rect)>[],
            },
            rtl: switch (p.recognition) {
              RecognitionDone(:final PageText text) => text.language == RecognitionLanguage.ar,
              _ => true,
            },
          ),
      ];
      final Uint8List font = look.font;
      final Uint8List fallback = look.fontFallback;
      final Uint8List bytes = await Isolate.run(() => _imagePdf(inputs, colorMode, encoding, font, fallback));
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

  Future<Either<BuildFailure, BuildOutput>> buildText({
    required List<CapturedPage> pages,
    required DocumentEdits edits,
    required PdfLook look,
    required File out,
  }) async {
    try {
      final List<List<_TextBlock>> content = <List<_TextBlock>>[
        for (final CapturedPage p in pages)
          switch (p.recognition) {
            RecognitionDone(:final PageText text) => <_TextBlock>[
              for (final Paragraph para in text.paragraphs)
                _TextBlock(
                  rtl: text.language == RecognitionLanguage.ar,
                  segments: edits.finalSegments(p.id, para),
                ),
            ],
            _ => const <_TextBlock>[],
          },
      ];
      final Uint8List bytes = await _textPdf(content, look);
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

  static Future<Uint8List> _textPdf(List<List<_TextBlock>> pages, PdfLook look) {
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
    for (final List<_TextBlock> blocks in pages) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.applyMargin(left: 48, top: 56, right: 48, bottom: 56),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context _) => <pw.Widget>[
            for (final _TextBlock b in blocks) _paragraph(b, ink, fill, onFill, look.redactedLabel),
          ],
        ),
      );
    }
    if (pages.every((List<_TextBlock> b) => b.isEmpty)) {
      doc.addPage(pw.Page(build: (pw.Context _) => pw.SizedBox()));
    }
    return doc.save();
  }

  static pw.Widget _paragraph(_TextBlock b, PdfColor ink, PdfColor fill, PdfColor onFill, String label) {
    final pw.TextDirection dir = b.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final pw.Widget body;
    if (b.segments.length == 1 && b.segments.first is FinalRedaction) {
      body = pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: pw.BoxDecoration(color: fill, borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Text(label, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(color: onFill, fontSize: 11)),
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

class _ImagePage {
  const _ImagePage({required this.path, required this.words, required this.rtl});
  final String path;
  final List<(String, Rect)> words;
  final bool rtl;
}

class _TextBlock {
  const _TextBlock({required this.rtl, required this.segments});
  final bool rtl;
  final List<FinalSegment> segments;
}

/// Runs in an isolate: re-encodes each photo and lays out the image-form PDF.
Future<Uint8List> _imagePdf(
  List<_ImagePage> pages,
  ScanColorMode mode,
  ImageEncoding enc,
  Uint8List font,
  Uint8List fallback,
) async {
  final pw.Document doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: pw.Font.ttf(ByteData.sublistView(font)),
      fontFallback: <pw.Font>[pw.Font.ttf(ByteData.sublistView(fallback))],
    ),
  );
  for (final _ImagePage p in pages) {
    final img.Image? decoded = img.decodeImage(await File(p.path).readAsBytes());
    if (decoded == null) throw const FileSystemException('decode');
    img.Image photo = decoded;
    final int long = math.max(photo.width, photo.height);
    if (long > enc.longEdge) {
      photo = photo.width >= photo.height
          ? img.copyResize(photo, width: enc.longEdge, interpolation: img.Interpolation.average)
          : img.copyResize(photo, height: enc.longEdge, interpolation: img.Interpolation.average);
    }
    if (mode != ScanColorMode.color) photo = img.grayscale(photo);
    if (mode == ScanColorMode.bw) photo = img.luminanceThreshold(photo, threshold: 0.6);
    final Uint8List jpg = img.encodeJpg(photo, quality: enc.quality);

    // Word boxes are in the prepared image's pixels.
    final double scale = PdfBuilder._pageWidth / decoded.width;
    final PdfPageFormat format = PdfPageFormat(PdfBuilder._pageWidth, decoded.height * scale);
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
