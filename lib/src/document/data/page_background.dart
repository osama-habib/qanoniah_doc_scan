import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;

import '../../core/ink_map.dart';
import '../../core/session/document_edits.dart';
import '../../core/session/scan_session.dart';
import '../../core/session/word_placement.dart';

/// A written background and its size in pixels (the recognized image's).
class PageBackgroundImage {
  const PageBackgroundImage(this.file, this.width, this.height);

  final File file;
  final int width;
  final int height;
}

/// The page under its recognized text (revised 2026-11-04): the scan itself, on
/// pure white paper, with the recognized words erased so they can be drawn back as
/// real text in place. Everything else stays as printed: table rules, boxes,
/// logos, stamps, signatures, codes, and any text the engine did not read.
///
/// An erased word leaves no pixels behind, so a redacted word cannot be recovered
/// from the background (FR-041).
class PageBackground {
  const PageBackground();

  /// The background of one page, or null when its images cannot be read.
  ///
  /// Erases every word drawn back as text. With [edits] (the text PDF) it also
  /// erases what the edits remove: redacted words, and the words of hidden or
  /// rewritten paragraphs, so none of them stays in the page's pixels. A page
  /// without recognized text keeps all of its print.
  static Future<PageBackgroundImage?> forPage(
    CapturedPage page, {
    DocumentEdits? edits,
    required File out,
    bool jpeg = false,
  }) async {
    final List<Rect> erase = <Rect>[];
    double lineHeight = 0;
    final RecognitionState r = page.recognition;
    if (r is RecognitionDone) {
      final List<double> ems = <double>[];
      for (final Paragraph p in r.text.paragraphs) {
        final ParagraphKey key = (page.id, p.id);
        final bool whole = edits != null && (edits.isParagraphRedacted(key) || edits.replacements.containsKey(key));
        for (int i = 0; i < p.words.length; i++) {
          final Word w = p.words[i];
          ems.add(w.em);
          if (w.drawable || whole || (edits?.isWordRedacted(key, i) ?? false)) erase.add(w.box);
        }
      }
      ems.sort();
      if (ems.isNotEmpty) lineHeight = ems[ems.length ~/ 2] * 1.3;
    }
    try {
      return await write(
        prepared: page.preparedFile,
        ocr: page.ocrInputFile,
        erase: erase,
        lineHeight: lineHeight > 0 ? lineHeight : 24,
        out: out,
        jpeg: jpeg,
      );
    } on Object {
      return null;
    }
  }

  /// Builds the background of [prepared] (the page as the user filtered it) from
  /// [ocr], the image the text was recognized on, whose pixels [erase] is in.
  /// Writes a PNG, or a JPEG, to [out].
  static Future<PageBackgroundImage> write({
    required File prepared,
    required File ocr,
    required List<Rect> erase,
    required double lineHeight,
    required File out,
    bool jpeg = false,
  }) async {
    final String p = prepared.path;
    final String o = ocr.path;
    final (Uint8List bytes, int w, int h) = await Isolate.run(() {
      final img.Image page = img.decodeImage(File(p).readAsBytesSync())!;
      final img.Image text = img.decodeImage(File(o).readAsBytesSync())!;
      final img.Image bg = const PageBackground().compose(page, text, erase, lineHeight);
      return (jpeg ? img.encodeJpg(bg, quality: 85) : img.encodePng(bg, level: 6), bg.width, bg.height);
    });
    return PageBackgroundImage(await out.writeAsBytes(bytes, flush: true), w, h);
  }

  /// The paper's color in a thin ring around a box: a light percentile of the
  /// ring's non-ink pixels, so borders, neighbouring ink and their soft edges do
  /// not darken it. White when the ring is all ink.
  static int _paperAround(img.Image color, Uint8List gray, int w, int h, int x0, int y0, int x1, int y1) {
    final List<(int, int)> ring = <(int, int)>[]; // luminance, rgb
    void take(int x, int y) {
      if (x < 0 || y < 0 || x >= w || y >= h) return;
      // Ink (a box's border, a neighbour's letters) is not paper.
      if (gray[y * w + x] < 150) return;
      final img.Pixel p = color.getPixel(x, y);
      ring.add((p.luminance.toInt(), p.r.toInt() << 16 | p.g.toInt() << 8 | p.b.toInt()));
    }

    for (int x = x0 - 2; x < x1 + 2; x++) {
      take(x, y0 - 2);
      take(x, y1 + 1);
    }
    for (int y = y0; y < y1; y++) {
      take(x0 - 2, y);
      take(x1 + 1, y);
    }
    if (ring.isEmpty) return 0xffffff;
    ring.sort(((int, int) a, (int, int) b) => a.$1.compareTo(b.$1));
    return ring[(ring.length * 0.75).floor()].$2;
  }

  img.Image compose(img.Image page, img.Image text, List<Rect> erase, double lineHeight) {
    final int w = text.width;
    final int h = text.height;
    final img.Image color = page.width == w && page.height == h
        ? page
        : img.copyResize(page, width: w, height: h, interpolation: img.Interpolation.average);
    final Uint8List gray = Uint8List(w * h);
    final bool single = text.numChannels == 1;
    int i = 0;
    for (final img.Pixel p in text) {
      gray[i++] = (single ? p.r : p.luminance).toInt();
    }
    final InkMap ink = InkMap.forText(gray, w, h, lineHeight: lineHeight);
    // White balance against the paper: its usual brightness becomes pure white,
    // shading (a table header) stays as a smooth tint.
    final List<int> lums = <int>[];
    for (int y = 0; y < h; y += 7) {
      for (int x = 0; x < w; x += 7) {
        lums.add(color.getPixel(x, y).luminance.toInt());
      }
    }
    lums.sort();
    final double gain = 255 / lums[(lums.length * 0.9).floor()].clamp(96, 255);
    final img.Image out = img.Image(width: w, height: h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final img.Pixel p = color.getPixel(x, y);
        int r = (p.r * gain).round().clamp(0, 255);
        int g = (p.g * gain).round().clamp(0, 255);
        int b = (p.b * gain).round().clamp(0, 255);
        if (r > 244 && g > 244 && b > 244) r = g = b = 255;
        out.setPixelRgb(x, y, r, g, b);
      }
    }
    // Erase each recognized word (not the rules through it) with the paper
    // around it.
    for (final Rect r in erase) {
      // A margin for anti-aliased edges and marks the box missed.
      final double mx = 1 + r.height * 0.08;
      final double my = 1 + r.height * 0.15;
      final int x0 = (r.left - mx).floor().clamp(0, w);
      final int x1 = (r.right + mx).ceil().clamp(0, w);
      final int y0 = (r.top - my).floor().clamp(0, h);
      final int y1 = (r.bottom + my).ceil().clamp(0, h);
      final int rgb = _paperAround(out, gray, w, h, x0, y0, x1, y1);
      for (int y = y0; y < y1; y++) {
        for (int x = x0; x < x1; x++) {
          if (ink.rule[y * w + x] == 1) continue;
          out.setPixelRgb(x, y, rgb >> 16 & 0xff, rgb >> 8 & 0xff, rgb & 0xff);
        }
      }
    }
    return out;
  }
}
