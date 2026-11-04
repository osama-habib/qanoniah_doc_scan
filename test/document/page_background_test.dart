import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qanoniah_doc_scan/src/core/session/document_edits.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/document/data/page_background.dart';

/// A white page with a black block of "ink" at each word, a table rule running
/// through both words, and a gray stamp-like mark the engine read poorly.
CapturedPage _page(Directory dir) {
  final img.Image im = img.Image(width: 400, height: 200);
  img.fill(im, color: img.ColorRgb8(250, 250, 250));
  void block(Rect r, int v) => img.fillRect(
    im,
    x1: r.left.toInt(),
    y1: r.top.toInt(),
    x2: r.right.toInt() - 1,
    y2: r.bottom.toInt() - 1,
    color: img.ColorRgb8(v, v, v),
  );
  const Rect a = Rect.fromLTWH(300, 40, 60, 20);
  const Rect b = Rect.fromLTWH(200, 40, 60, 20);
  const Rect stamp = Rect.fromLTWH(60, 120, 50, 30);
  block(a, 20);
  block(b, 20);
  block(stamp, 60);
  // A one-pixel rule across the page, through both words.
  img.drawLine(im, x1: 0, y1: 50, x2: 399, y2: 50, color: img.ColorRgb8(0, 0, 0));
  final File f = File('${dir.path}/page.png')..writeAsBytesSync(img.encodePng(im));
  return CapturedPage(
    id: 'pg',
    rawFile: f,
    corners: Quad.fullFrame,
    filters: const <PageFilter>{PageFilter.original},
    preparedFile: f,
    ocrInputFile: f,
    recognition: RecognitionState.done(
      PageText(
        language: RecognitionLanguage.ar,
        width: 400,
        height: 200,
        paragraphs: <Paragraph>[
          Paragraph(
            id: 'p0',
            words: <Word>[
              Word(text: 'أول', box: a, confidence: 0.95),
              Word(text: 'سري', box: b, confidence: 0.95),
            ],
          ),
          Paragraph(
            id: 'p1',
            words: <Word>[Word(text: 'ختم', box: stamp, confidence: 0.3)],
          ),
        ],
      ),
    ),
  );
}

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('bg'));
  tearDown(() => tmp.delete(recursive: true));

  int darkIn(img.Image im, Rect r, {Rect? except}) {
    int n = 0;
    for (int y = r.top.toInt(); y < r.bottom.toInt(); y++) {
      for (int x = r.left.toInt(); x < r.right.toInt(); x++) {
        if (except != null && except.contains(Offset(x + 0.5, y + 0.5))) continue;
        if (im.getPixel(x, y).luminance < 128) n++;
      }
    }
    return n;
  }

  test('[UT] drawn words are erased, the rule through them and a poorly read mark stay', () async {
    final CapturedPage p = _page(tmp);
    final PageBackgroundImage bg = (await PageBackground.forPage(p, out: File('${tmp.path}/bg.png')))!;
    final img.Image im = img.decodeImage(bg.file.readAsBytesSync())!;
    expect((bg.width, bg.height), (400, 200));
    // Word ink is gone, except the rule's own row.
    expect(darkIn(im, const Rect.fromLTWH(300, 40, 60, 20), except: const Rect.fromLTWH(300, 50, 60, 1)), 0);
    expect(darkIn(im, const Rect.fromLTWH(200, 40, 60, 20), except: const Rect.fromLTWH(200, 50, 60, 1)), 0);
    expect(darkIn(im, const Rect.fromLTWH(0, 50, 400, 1)), greaterThan(380));
    expect(darkIn(im, const Rect.fromLTWH(60, 120, 50, 30)), greaterThan(1000));
    // Paper is white balanced to pure white.
    expect(im.getPixel(10, 10).r, 255);
  });

  test('[UT] for the text PDF, a redacted poorly read mark is erased too (FR-041)', () async {
    final CapturedPage p = _page(tmp);
    final DocumentEdits edits = const DocumentEdits().redactWords(('pg', 'p1'), <int>[0]);
    final PageBackgroundImage bg = (await PageBackground.forPage(p, edits: edits, out: File('${tmp.path}/bg.png')))!;
    final img.Image im = img.decodeImage(bg.file.readAsBytesSync())!;
    expect(darkIn(im, const Rect.fromLTWH(60, 120, 50, 30)), 0);
  });
}
