import 'dart:typed_data';

/// The dark pixels of a page image, and which of them are rules: the long thin
/// straight strokes of table borders, boxes and underlines (research R6, revised
/// 2026-11-04).
///
/// Shared by the ink pass, which measures words without the rules around them, and
/// the page background, which erases words but keeps the rules.
class InkMap {
  InkMap._(this.width, this.height, this.gray, this.dark, this.rule);

  /// [gray] is one luminance byte per pixel, row by row; [lineHeight] is the
  /// page's usual height of a line of text, in pixels.
  ///
  /// A pixel is ink below [threshold]. A rule is a run of ink longer than text
  /// makes it (horizontal: 3 line heights; vertical: 0.9, taller than any letter
  /// of the line) and thin (a fifth of a line height at most), so the thick stems
  /// of a large title are not rules.
  factory InkMap.forText(Uint8List gray, int width, int height, {required double lineHeight, int threshold = 150}) {
    final Uint8List dark = Uint8List(width * height);
    for (int i = 0; i < dark.length; i++) {
      if (gray[i] < threshold) dark[i] = 1;
    }
    final int across = _atLeast(4, lineHeight * 3);
    final int down = _atLeast(4, lineHeight * 0.9);
    final int thin = _atLeast(3, lineHeight * 0.2);

    // Thickness of the ink through (x, y), across a run that goes the other way.
    int thickV(int x, int y) {
      int a = y;
      int b = y;
      while (a > 0 && dark[(a - 1) * width + x] == 1) {
        a--;
      }
      while (b < height - 1 && dark[(b + 1) * width + x] == 1) {
        b++;
      }
      return b - a + 1;
    }

    int thickH(int x, int y) {
      int a = x;
      int b = x;
      while (a > 0 && dark[y * width + a - 1] == 1) {
        a--;
      }
      while (b < width - 1 && dark[y * width + b + 1] == 1) {
        b++;
      }
      return b - a + 1;
    }

    final Uint8List rule = Uint8List(width * height);
    for (int y = 0; y < height; y++) {
      int x = 0;
      while (x < width) {
        if (dark[y * width + x] == 0) {
          x++;
          continue;
        }
        final int from = x;
        while (x < width && dark[y * width + x] == 1) {
          x++;
        }
        if (x - from >= across && _mostly(from, x, (int at) => thickV(at, y) <= thin)) {
          rule.fillRange(y * width + from, y * width + x, 1);
        }
      }
    }
    for (int x = 0; x < width; x++) {
      int y = 0;
      while (y < height) {
        if (dark[y * width + x] == 0) {
          y++;
          continue;
        }
        final int from = y;
        while (y < height && dark[y * width + x] == 1) {
          y++;
        }
        if (y - from >= down && _mostly(from, y, (int at) => thickH(x, at) <= thin)) {
          for (int k = from; k < y; k++) {
            rule[k * width + x] = 1;
          }
        }
      }
    }
    // A rule's ragged edges (scan noise, a thick line's wobble) have short runs
    // of their own: grow the rules into the ink touching them, where that ink is
    // still thin across the rule (not a letter sitting on it).
    for (int pass = 0; pass < 2; pass++) {
      final Uint8List grown = Uint8List.fromList(rule);
      for (int y = 1; y < height - 1; y++) {
        for (int x = 1; x < width - 1; x++) {
          final int i = y * width + x;
          if (rule[i] == 1 || dark[i] == 0) continue;
          final bool byRow = (rule[i - width] == 1 || rule[i + width] == 1) && thickV(x, y) <= thin;
          final bool byColumn = (rule[i - 1] == 1 || rule[i + 1] == 1) && thickH(x, y) <= thin;
          if (byRow || byColumn) grown[i] = 1;
        }
      }
      rule.setAll(0, grown);
    }
    return InkMap._(width, height, gray, dark, rule);
  }

  /// Thin at 40% or more of fifteen points along a run [from, to): a rule stays a
  /// rule where it crosses words or other rules.
  static bool _mostly(int from, int to, bool Function(int at) thin) {
    int yes = 0;
    for (int k = 1; k <= 15; k++) {
      if (thin(from + (to - from) * k ~/ 16)) yes++;
    }
    return yes >= 6;
  }

  static int _atLeast(int min, double v) => v.round() < min ? min : v.round();

  final int width;
  final int height;
  final Uint8List gray;

  /// 1 for ink.
  final Uint8List dark;

  /// 1 for ink that belongs to a rule.
  final Uint8List rule;

  /// Ink that is not part of a rule: a glyph.
  bool glyph(int x, int y) {
    final int i = y * width + x;
    return dark[i] == 1 && rule[i] == 0;
  }
}
