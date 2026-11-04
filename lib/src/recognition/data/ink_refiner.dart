import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;

import '../../core/ink_map.dart';
import '../../core/session/scan_session.dart';
import 'text_recognizer.dart';

/// The ink pass after recognition (revised 2026-11-04), so the text can be drawn
/// back exactly where and as large as it was printed:
///
/// * each word's box is tightened to its own ink, without the rules around it
///   (engines return the whole line's height for every word);
/// * a line the engine merged with the one below is split back into two;
/// * every word gets its line's font size and baseline, from where the ink of
///   its letters sits (calibrated on the PDF font, Noto Sans Arabic);
/// * words with heavy strokes are marked bold.
class InkRefiner {
  const InkRefiner();

  /// Reads the recognized image at [path] off the UI isolate.
  static Future<RawRecognition> refineFile(RawRecognition raw, String path) => Isolate.run(() {
    final img.Image? im = img.decodeImage(File(path).readAsBytesSync());
    if (im == null) return raw;
    return const InkRefiner().refine(raw, grayOf(im), im.width, im.height);
  });

  /// One luminance byte per pixel. A one-channel image is its own luminance
  /// (`Pixel.luminance` reads its missing green and blue as 0).
  static Uint8List grayOf(img.Image im) {
    final Uint8List gray = Uint8List(im.width * im.height);
    int i = 0;
    final bool single = im.numChannels == 1;
    for (final img.Pixel p in im) {
      gray[i++] = (single ? p.r : p.luminance).toInt();
    }
    return gray;
  }

  RawRecognition refine(RawRecognition raw, Uint8List gray, int width, int height) {
    final List<Word> all = raw.blocks.expand((List<Word> b) => b).toList();
    if (all.isEmpty) return raw;
    // Boxes may be in another scale than the image (an engine that downsampled).
    final double sx = raw.width > 0 ? width / raw.width : 1;
    final double sy = raw.height > 0 ? height / raw.height : 1;
    final double medianH = _median(all.map((Word w) => w.box.height * sy).toList());
    final InkMap ink = InkMap.forText(gray, width, height, lineHeight: medianH);

    Rect toImage(Rect r) => Rect.fromLTRB(r.left * sx, r.top * sy, r.right * sx, r.bottom * sy);
    Rect fromImage(Rect r) => Rect.fromLTRB(r.left / sx, r.top / sy, r.right / sx, r.bottom / sy);

    final List<List<Word>> out = <List<Word>>[];
    final List<double> strokes = <double>[];
    final Map<Word, double> strokeOf = <Word, double>{};
    for (final List<Word> block in raw.blocks) {
      final List<(Word, Rect)> tight = <(Word, Rect)>[for (final Word w in block) (w, _tighten(ink, toImage(w.box)))];
      for (final List<(Word, Rect)> line in _splitLines(tight)) {
        final (double size, double baseline) = _place(line);
        final List<Word> words = <Word>[];
        for (final (Word w, Rect r) in line) {
          final Word placed = w.copyWith(box: fromImage(r), size: size / sy, baseline: baseline / sy);
          final double? stroke = _stroke(ink, r);
          if (stroke != null && size > 0) {
            strokes.add(stroke / size);
            strokeOf[placed] = stroke / size;
          }
          words.add(placed);
        }
        out.add(words);
      }
    }
    // Bold: strokes clearly heavier than the page's usual weight, or heavy in
    // absolute terms (a page printed all in bold).
    final double usual = strokes.isEmpty ? 0 : _median(strokes);
    for (final List<Word> line in out) {
      for (int i = 0; i < line.length; i++) {
        final double? s = strokeOf[line[i]];
        if (s != null && (s > usual * 1.3 || s > boldStroke)) line[i] = line[i].copyWith(bold: true);
      }
    }
    return RawRecognition(
      blocks: out,
      blocksAreParagraphs: raw.blocksAreParagraphs,
      width: raw.width,
      height: raw.height,
    );
  }

  /// Stroke width per em above which a word reads as bold.
  static const double boldStroke = 0.14;

  /// The word's ink: the band of inked rows that overlaps the engine's box, its
  /// small detached marks (dots, hamza) included, and its inked columns.
  Rect _tighten(InkMap ink, Rect b) {
    final double h = math.max(2, b.height);
    final int x0 = math.max(0, b.left.floor() - 1);
    final int x1 = math.min(ink.width, b.right.ceil() + 1);
    final int y0 = math.max(0, (b.top - 0.3 * h).floor());
    final int y1 = math.min(ink.height, (b.bottom + 0.3 * h).ceil());
    if (x1 - x0 < 1 || y1 - y0 < 1) return b;
    // Borders the rule map missed (broken or thick in the scan): a column inked
    // down most of the window is taller than any letter, and a row inked across
    // the word that carries on past both its ends is a line, not a stroke.
    final List<bool> border = List<bool>.filled(x1 - x0, false);
    for (int x = x0; x < x1; x++) {
      int n = 0;
      for (int y = y0; y < y1; y++) {
        if (ink.glyph(x, y)) n++;
      }
      border[x - x0] = n > 0.75 * (y1 - y0);
    }
    bool line(int y) {
      final int out = math.max(2, (0.15 * h).round());
      if (x0 - out < 0 || x1 + out > ink.width) return false;
      for (final int x in <int>[x0 - out, x0 - 1, x1, x1 + out - 1]) {
        if (ink.dark[y * ink.width + x] == 0) return false;
      }
      return true;
    }

    bool glyph(int x, int y) => ink.glyph(x, y) && !border[x - x0];
    final List<int> rows = List<int>.filled(y1 - y0, 0);
    for (int y = y0; y < y1; y++) {
      int n = 0;
      for (int x = x0; x < x1; x++) {
        if (glyph(x, y)) n++;
      }
      rows[y - y0] = n > 0.9 * (x1 - x0) && line(y) ? 0 : n;
    }
    final int minRow = math.max(1, ((x1 - x0) * 0.01).round());
    final int gap = math.max(1, (0.12 * h).round());
    final List<(int, int, int)> bands = <(int, int, int)>[]; // from, to (exclusive), mass
    int? from;
    int last = -1;
    int mass = 0;
    for (int i = 0; i < rows.length; i++) {
      if (rows[i] < minRow) continue;
      if (from != null && i - last > gap) {
        bands.add((from, last + 1, mass));
        from = null;
      }
      from ??= i;
      if (last < from) mass = 0;
      mass += rows[i];
      last = i;
    }
    if (from != null) bands.add((from, last + 1, mass));
    (int, int, int)? main;
    for (final (int, int, int) band in bands) {
      final bool overlaps = y0 + band.$2 > b.top && y0 + band.$1 < b.bottom;
      if (overlaps && (main == null || band.$3 > main.$3)) main = band;
    }
    if (main == null) return b;
    int top = main.$1;
    int bottom = main.$2;
    for (final (int, int, int) band in bands) {
      if (band == main || band.$3 > main.$3 * 0.25) continue;
      final int between = band.$1 >= bottom ? band.$1 - bottom : top - band.$2;
      final bool inside = y0 + band.$1 >= b.top - 0.1 * h && y0 + band.$2 <= b.bottom + 0.1 * h;
      if (between <= 0.25 * h && inside) {
        top = math.min(top, band.$1);
        bottom = math.max(bottom, band.$2);
      }
    }
    int left = x1;
    int right = x0 - 1;
    for (int y = y0 + top; y < y0 + bottom; y++) {
      if (rows[y - y0] == 0) continue;
      for (int x = x0; x < x1; x++) {
        if (glyph(x, y)) {
          if (x < left) left = x;
          if (x > right) right = x;
        }
      }
    }
    if (right < left) return b;
    return Rect.fromLTRB(left.toDouble(), (y0 + top).toDouble(), right + 1.0, (y0 + bottom).toDouble());
  }

  /// Words of one engine line stacked in more than one band of print: each band
  /// is its own line, in the engine's reading order.
  List<List<(Word, Rect)>> _splitLines(List<(Word, Rect)> words) {
    if (words.length < 2) return <List<(Word, Rect)>>[words];
    final double mh = _median(words.map(((Word, Rect) w) => w.$2.height).toList());
    final List<int> order = List<int>.generate(words.length, (int i) => i)
      ..sort((int a, int b) => words[a].$2.center.dy.compareTo(words[b].$2.center.dy));
    final List<List<int>> bands = <List<int>>[];
    double mean = 0;
    for (final int i in order) {
      final double c = words[i].$2.center.dy;
      if (bands.isEmpty || c - mean > 0.6 * mh) {
        bands.add(<int>[i]);
        mean = c;
      } else {
        bands.last.add(i);
        mean += (c - mean) / bands.last.length;
      }
    }
    if (bands.length == 1) return <List<(Word, Rect)>>[words];
    return <List<(Word, Rect)>>[
      for (final List<int> band in bands) <(Word, Rect)>[for (final int i in band..sort()) words[i]],
    ];
  }

  /// The line's font size and baseline: each word says how tall its letters stand
  /// above and below the baseline, in em; the median over the line is robust to a
  /// word whose letters were guessed wrong.
  (double, double) _place(List<(Word, Rect)> line) {
    final List<double> sizes = <double>[];
    final List<double> baselines = <double>[];
    for (final (Word w, Rect r) in line) {
      final (double up, double down) = letterExtent(w.text);
      if (up + down <= 0 || r.height < 1) continue;
      final double s = r.height / (up + down);
      sizes.add(s);
      baselines.add(r.bottom - down * s);
    }
    if (sizes.isEmpty) return (0, 0);
    return (_median(sizes), _median(baselines));
  }

  /// How far [text]'s ink rises above and drops below the baseline, in em of Noto
  /// Sans Arabic / Noto Sans (measured 2026-11-04).
  static (double, double) letterExtent(String text) {
    double up = 0;
    double down = 0;
    for (final int c in text.runes) {
      final String ch = String.fromCharCode(c);
      if (c >= 0x0600 && c <= 0x06FF || c >= 0x0750 && c <= 0x077F || c >= 0xFB50 && c <= 0xFEFF) {
        if ('أآ'.contains(ch)) {
          up = math.max(up, 0.95);
        } else if ('الكطظإ'.contains(ch)) {
          up = math.max(up, 0.72);
        } else if (c >= 0x0660 && c <= 0x0669) {
          up = math.max(up, 0.73);
        } else {
          up = math.max(up, 0.45);
        }
        if ('يىمحجخعغإ'.contains(ch)) {
          down = math.max(down, 0.30);
        } else if ('رزونسشصضقل'.contains(ch)) {
          down = math.max(down, 0.22);
        }
      } else if (c >= 0x30 && c <= 0x39) {
        up = math.max(up, 0.73);
      } else if (c >= 0x41 && c <= 0x5A || 'bdfhiklt'.contains(ch)) {
        up = math.max(up, 0.75);
      } else if (c >= 0x61 && c <= 0x7A) {
        up = math.max(up, 0.54);
      } else if ('()[]{}|/'.contains(ch)) {
        up = math.max(up, 0.75);
        down = math.max(down, 0.2);
      } else if ('%#&@\$'.contains(ch)) {
        up = math.max(up, 0.73);
      }
      if ('gjpqy'.contains(ch)) {
        down = math.max(down, 0.22);
      } else if (',;'.contains(ch)) {
        down = math.max(down, 0.12);
      }
    }
    return (up, down);
  }

  /// Mean length of the word's horizontal ink runs: its stroke width in pixels.
  /// Null for too little ink to judge.
  double? _stroke(InkMap ink, Rect r) {
    int total = 0;
    int runs = 0;
    for (int y = r.top.floor(); y < r.bottom.ceil() && y < ink.height; y++) {
      int x = r.left.floor();
      while (x < r.right.ceil() && x < ink.width) {
        if (!ink.glyph(x, y)) {
          x++;
          continue;
        }
        final int from = x;
        while (x < r.right.ceil() && x < ink.width && ink.glyph(x, y)) {
          x++;
        }
        total += x - from;
        runs++;
      }
    }
    return runs < 6 ? null : total / runs;
  }

  static double _median(List<double> v) {
    if (v.isEmpty) return 0;
    final List<double> s = List<double>.of(v)..sort();
    return s[s.length ~/ 2];
  }
}
