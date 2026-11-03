import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/document/data/pdf_builder.dart';

/// Noto fonts from the example app (OFL), as a host would pass them.
PdfLook testLook() => PdfLook(
  font: File('example/assets/fonts/NotoSansArabic-Regular.ttf').readAsBytesSync(),
  fontFallback: File('example/assets/fonts/NotoSans-Regular.ttf').readAsBytesSync(),
  text: 0xff222222,
  redactionFill: 0xff222222,
  onRedactionFill: 0xffffffff,
  redactedLabel: 'نص محجوب',
);

/// A page with a noisy JPEG (so size depends on quality) and recognized words.
CapturedPage pdfPage(Directory dir, String id, List<String> words, {int w = 1200, int h = 1700}) {
  final img.Image photo = img.Image(width: w, height: h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final int v = ((x * 7919 + y * 104729) ^ (x * y)) & 0xff;
      photo.setPixelRgb(x, y, v, 255 - v, (v * 3) & 0xff);
    }
  }
  final File f = File('${dir.path}/$id.jpg')..writeAsBytesSync(img.encodeJpg(photo, quality: 95));
  return CapturedPage(
    id: id,
    rawFile: f,
    corners: Quad.fullFrame,
    filters: const <PageFilter>{PageFilter.original},
    preparedFile: f,
    ocrInputFile: f,
    recognition: RecognitionState.done(
      PageText(
        language: RecognitionLanguage.ar,
        paragraphs: <Paragraph>[
          Paragraph(
            id: 'p0',
            words: <Word>[
              for (int i = 0; i < words.length; i++)
                Word(text: words[i], box: Rect.fromLTWH(1000 - i * 120.0, 100, 100, 40), confidence: 0.9),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Every stream of [pdf], inflated when compressed, plus the raw file text.
String pdfText(Uint8List pdf) {
  final String raw = String.fromCharCodes(pdf);
  final StringBuffer out = StringBuffer(raw);
  final RegExp stream = RegExp(r'stream\r?\n');
  for (final RegExpMatch m in stream.allMatches(raw)) {
    final int end = raw.indexOf('endstream', m.end);
    if (end < 0) continue;
    try {
      out.write(String.fromCharCodes(zlib.decode(pdf.sublist(m.end, end))));
    } on FormatException {
      // Not deflated.
    }
  }
  return out.toString();
}
