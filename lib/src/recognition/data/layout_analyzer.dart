import 'dart:math' as math;
import 'dart:ui' show Rect;

import '../../core/session/scan_session.dart';
import 'post_processor.dart';

/// Rebuilds a page's layout from recognized lines (research R6, revised
/// 2026-11-04): tables, paragraphs with their printed lines, alignment, headings,
/// indents and spacing, in reading order. Engine-independent: it only reads word
/// boxes, so Vision and Tesseract get the same treatment.
///
/// Steps: split lines at wide gaps into segments; cluster segments into rows;
/// find runs of rows whose segments fall in shared columns (tables); group the
/// remaining segments into paragraphs; measure each paragraph against the text
/// margins.
class LayoutAnalyzer {
  const LayoutAnalyzer({
    this.segmentGap = 1.8,
    this.paragraphGap = 0.75,
    this.headingSize = 1.3,
    this.tableRowGap = 2.6,
  });

  /// A horizontal gap wider than this many line heights splits a line.
  final double segmentGap;

  /// A vertical gap wider than this many median line heights ends a paragraph.
  final double paragraphGap;

  /// Lines this much taller than the median read as a heading.
  final double headingSize;

  /// Table rows may be this many median line heights apart.
  final double tableRowGap;

  List<Paragraph> analyze(List<List<Word>> lines, {required bool rtl}) {
    final List<_Seg> segs = <_Seg>[
      for (final List<Word> l in lines)
        if (l.isNotEmpty) ..._split(l, rtl),
    ];
    if (segs.isEmpty) return const <Paragraph>[];
    // The body's line height: a median weighted by words, so a page of short
    // table cells does not set the norm for its prose.
    final double medianH = _weightedMedian(<(double, int)>[for (final _Seg s in segs) (s.box.height, s.words.length)]);
    final List<_Row> rows = _rows(segs);
    final List<_Table> tables = _tables(rows, medianH);
    final Set<_Seg> inTables = <_Seg>{for (final _Table t in tables) ...t.segs};

    // Text margins from the segments outside tables (or all, for a table page).
    final List<_Seg> body = segs.where((_Seg s) => !inTables.contains(s)).toList();
    final List<_Seg> marginSource = body.length >= 2 ? body : segs;
    final double left = _percentile(marginSource.map((_Seg s) => s.box.left), 0.05);
    final double right = _percentile(marginSource.map((_Seg s) => s.box.right), 0.95);
    final double width = math.max(1, right - left);

    final List<_Block> blocks = <_Block>[
      for (final _Table t in tables)
        if (t.textColumns)
          // Start column first, then the next: how columns are read.
          _Block.columns(
            <List<_Seg>>[
              for (int c = 0; c < t.columns; c++)
                ..._paragraphs(<_Seg>[for (final List<List<_Seg>> row in t.cells) ...row[c]], medianH),
            ],
            t.top,
            t.bottom,
          )
        else
          _Block.table(t),
      for (final List<_Seg> p in _paragraphs(body, medianH)) _Block.text(p),
    ]..sort((_Block a, _Block b) => a.top.compareTo(b.top));

    final List<Paragraph> out = <Paragraph>[];
    double lastBottom = double.nan;
    int tableIndex = 0;
    for (final _Block b in blocks) {
      final double space = lastBottom.isNaN ? 0 : math.max(0, (b.top - lastBottom) / medianH);
      if (b.columnParagraphs != null) {
        bool first = true;
        for (final List<_Seg> p in b.columnParagraphs!) {
          final Rect box = p.map((_Seg s) => s.box).reduce((Rect a, Rect c) => a.expandToInclude(c));
          out.add(
            _paragraph(
              'p${out.length}',
              p,
              medianH: medianH,
              rtl: rtl,
              left: box.left,
              width: math.max(1, box.width),
              spaceBefore: first ? space : 0.5,
            ),
          );
          first = false;
        }
      } else if (b.table != null) {
        final _Table t = b.table!;
        final int id = tableIndex++;
        bool first = true;
        final int from = out.length;
        for (int r = 0; r < t.cells.length; r++) {
          for (int c = 0; c < t.columns; c++) {
            final List<_Seg> cell = t.cells[r][c];
            if (cell.isEmpty) continue;
            out.add(
              _paragraph(
                'p${out.length}',
                cell,
                medianH: medianH,
                rtl: rtl,
                left: t.colLeft(c),
                width: t.colWidth(c),
                spaceBefore: first ? space : 0,
              ).copyWith(table: id, row: r, col: c, indent: 0),
            );
            first = false;
          }
        }
        // One alignment per column: the cells' majority (headers and numbers
        // sharing a column read as one column).
        for (int c = 0; c < t.columns; c++) {
          final List<int> idx = <int>[
            for (int k = from; k < out.length; k++)
              if (out[k].col == c) k,
          ];
          final Map<BlockAlign, int> votes = <BlockAlign, int>{};
          for (final int k in idx) {
            votes[out[k].align] = (votes[out[k].align] ?? 0) + 1;
          }
          if (votes.isEmpty) continue;
          // Centered columns: every cell's middle near the column's middle.
          final double mid = t.colLeft(c) + t.colWidth(c) / 2;
          if (idx.length > 1 &&
              idx.every((int k) => ((out[k].box?.center.dx ?? mid) - mid).abs() < t.colWidth(c) * 0.12)) {
            for (final int k in idx) {
              out[k] = out[k].copyWith(align: BlockAlign.center);
            }
            continue;
          }
          final BlockAlign win = votes.entries
              .reduce((MapEntry<BlockAlign, int> a, MapEntry<BlockAlign, int> b) => b.value > a.value ? b : a)
              .key;
          for (final int k in idx) {
            out[k] = out[k].copyWith(align: win == BlockAlign.justify ? BlockAlign.start : win);
          }
        }
      } else {
        out.add(
          _paragraph(
            'p${out.length}',
            b.segs,
            medianH: medianH,
            rtl: rtl,
            left: left,
            width: width,
            spaceBefore: space,
          ),
        );
      }
      lastBottom = b.bottom;
    }
    return out;
  }

  /// Splits one engine line where words are far apart (table cells, two columns).
  List<_Seg> _split(List<Word> words, bool rtl) {
    final List<Word> byX = List<Word>.of(words)..sort((Word a, Word b) => a.box.left.compareTo(b.box.left));
    final double h = _median(byX.map((Word w) => w.box.height));
    final List<List<Word>> parts = <List<Word>>[
      <Word>[byX.first],
    ];
    for (int i = 1; i < byX.length; i++) {
      final double gap = byX[i].box.left - byX[i - 1].box.right;
      if (gap > h * segmentGap) {
        parts.add(<Word>[byX[i]]);
      } else {
        parts.last.add(byX[i]);
      }
    }
    // Keep the engine's word order inside each part.
    return <_Seg>[
      for (final List<Word> p in parts)
        _Seg(<Word>[
          for (final Word w in words)
            if (p.contains(w)) w,
        ]),
    ];
  }

  /// Segments whose vertical centers fall in each other's band share a row.
  List<_Row> _rows(List<_Seg> segs) {
    final List<_Seg> byY = List<_Seg>.of(segs)..sort((_Seg a, _Seg b) => a.box.center.dy.compareTo(b.box.center.dy));
    final List<_Row> rows = <_Row>[];
    for (final _Seg s in byY) {
      final _Row? r = rows.isEmpty ? null : rows.last;
      if (r != null && _overlapY(r.box, s.box) > 0.5 * math.min(r.box.height, s.box.height)) {
        r.add(s);
      } else {
        rows.add(_Row(s));
      }
    }
    for (final _Row r in rows) {
      r.segs.sort((_Seg a, _Seg b) => a.box.left.compareTo(b.box.left));
    }
    return rows;
  }

  /// Runs of two or more rows with two or more segments each, close together, whose
  /// segments line up into shared columns.
  List<_Table> _tables(List<_Row> rows, double medianH) {
    final List<_Table> out = <_Table>[];
    int i = 0;
    while (i < rows.length) {
      if (rows[i].segs.length < 2) {
        i++;
        continue;
      }
      int j = i + 1;
      while (j < rows.length) {
        final double gap = rows[j].box.top - rows[j - 1].box.bottom;
        // A wrapped cell's next line sits tight under its row; a new row needs
        // two or more cells.
        final bool continuation = gap < medianH * _Table.wrapGap && _fitsColumns(rows.sublist(i, j), rows[j], medianH);
        if (!continuation && (rows[j].segs.length < 2 || gap >= medianH * tableRowGap)) break;
        j++;
      }
      final List<_Row> run = rows.sublist(i, j);
      final _Table? t = _Table.fromRows(run, medianH: medianH);
      if (t != null && (run.length >= 2 || t.columns >= 2)) {
        // One row of side-by-side text (signature lines) is a borderless table too.
        out.add(t);
      }
      i = j;
    }
    return out;
  }

  /// Every segment of [row] lies inside one cell span of [run] (a wrapped line of
  /// a cell, not a paragraph running under the table).
  bool _fitsColumns(List<_Row> run, _Row row, double medianH) {
    final List<Rect> cells = <Rect>[for (final _Row r in run) ...r.segs.map((_Seg s) => s.box)];
    if (cells.isEmpty || run.every((_Row r) => r.segs.length < 2)) return false;
    return row.segs.every(
      (_Seg s) => cells.any(
        (Rect c) =>
            s.box.left >= c.left - medianH * 2 && s.box.right <= c.right + medianH * 2 && _overlapX(c, s.box) > 0,
      ),
    );
  }

  /// Consecutive segments that sit close below each other, are about the same
  /// height and overlap horizontally.
  List<List<_Seg>> _paragraphs(List<_Seg> segs, double medianH) {
    final List<_Seg> byTop = List<_Seg>.of(segs)..sort((_Seg a, _Seg b) => a.box.top.compareTo(b.box.top));
    final List<List<_Seg>> out = <List<_Seg>>[];
    for (final _Seg s in byTop) {
      List<_Seg>? target;
      for (final List<_Seg> p in out.reversed) {
        final _Seg last = p.last;
        final double gap = s.box.top - last.box.bottom;
        final double ratio = s.box.height / last.box.height;
        final double overlap = _overlapX(last.box, s.box) / math.min(last.box.width, s.box.width);
        if (gap < medianH * paragraphGap && gap > -medianH * 0.5 && ratio < 1.35 && ratio > 1 / 1.35 && overlap > 0.3) {
          target = p;
          break;
        }
        if (s.box.top - last.box.bottom > medianH * 3) break;
      }
      if (target != null) {
        target.add(s);
      } else {
        out.add(<_Seg>[s]);
      }
    }
    return out;
  }

  Paragraph _paragraph(
    String id,
    List<_Seg> lines, {
    required double medianH,
    required bool rtl,
    required double left,
    required double width,
    required double spaceBefore,
  }) {
    // Alignment is measured in the paragraph's own direction: an English line on
    // an Arabic page starts at the left.
    final int latin = lines.expand((_Seg l) => l.words).where((Word w) => !PostProcessor.hasArabic(w.text)).length;
    final int total = lines.fold(0, (int n, _Seg l) => n + l.words.length);
    if (latin * 2 > total) rtl = false;
    final List<Word> words = <Word>[];
    final List<int> starts = <int>[];
    for (final _Seg l in lines) {
      if (words.isNotEmpty) starts.add(words.length);
      words.addAll(l.words);
    }
    final Rect box = lines.map((_Seg s) => s.box).reduce((Rect a, Rect b) => a.expandToInclude(b));
    final double measured = _median(lines.map((_Seg s) => s.box.height)) / medianH;
    // Glyph boxes vary a little with the letters; only clearly bigger print counts.
    final double size = measured >= headingSize ? measured : 1;
    final double tol = math.max(width * 0.035, medianH * 0.8);
    double startGap(Rect r) => rtl ? left + width - r.right : r.left - left;
    double endGap(Rect r) => rtl ? r.left - left : left + width - r.right;

    BlockAlign align;
    final List<_Seg> full = lines.length > 1 ? lines.sublist(0, lines.length - 1) : lines;
    final bool bothFlush = full.every((_Seg l) => startGap(l.box) < tol && endGap(l.box) < tol);
    final bool centered = lines.every((_Seg l) {
      final double a = startGap(l.box);
      final double b = endGap(l.box);
      return (a - b).abs() < tol * 1.5 && a > tol && b > tol;
    });
    if (lines.length > 1 && bothFlush) {
      align = BlockAlign.justify;
    } else if (centered) {
      align = BlockAlign.center;
    } else if (lines.every((_Seg l) => endGap(l.box) < tol) && lines.any((_Seg l) => startGap(l.box) > tol)) {
      align = BlockAlign.end;
    } else {
      align = BlockAlign.start;
    }
    final double indent = align == BlockAlign.start
        ? math.max(0, _median(lines.map((_Seg l) => startGap(l.box)))) / width
        : 0;
    return Paragraph(
      id: id,
      words: words,
      lineStarts: starts,
      box: box,
      align: align,
      size: size,
      heading: size >= headingSize && lines.length <= 2 && words.length <= 16,
      spaceBefore: spaceBefore,
      indent: indent < 0.02 ? 0 : indent,
    );
  }

  static double _overlapY(Rect a, Rect b) => math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
  static double _overlapX(Rect a, Rect b) => math.max(0, math.min(a.right, b.right) - math.max(a.left, b.left));

  static double _median(Iterable<double> v) {
    final List<double> l = v.toList()..sort();
    return l.isEmpty ? 1 : math.max(1, l[l.length ~/ 2]);
  }

  static double _weightedMedian(List<(double, int)> v) {
    if (v.isEmpty) return 1;
    final List<(double, int)> l = List<(double, int)>.of(v)
      ..sort(((double, int) a, (double, int) b) => a.$1.compareTo(b.$1));
    final int total = l.fold(0, (int n, (double, int) e) => n + e.$2);
    int acc = 0;
    for (final (double h, int w) in l) {
      acc += w;
      if (acc * 2 >= total) return math.max(1, h);
    }
    return math.max(1, l.last.$1);
  }

  static double _percentile(Iterable<double> v, double p) {
    final List<double> l = v.toList()..sort();
    if (l.isEmpty) return 0;
    return l[((l.length - 1) * p).round()];
  }
}

class _Seg {
  _Seg(this.words) : box = words.map((Word w) => w.box).reduce((Rect a, Rect b) => a.expandToInclude(b));

  final List<Word> words;
  final Rect box;
}

class _Row {
  _Row(_Seg s) : segs = <_Seg>[s], box = s.box;

  final List<_Seg> segs;
  Rect box;

  void add(_Seg s) {
    segs.add(s);
    box = box.expandToInclude(s.box);
  }
}

class _Table {
  _Table(this.columnsLtr, this.cells, this.segs, this.top, this.bottom);

  /// Column intervals left to right.
  final List<(double, double)> columnsLtr;

  /// cells[row][col], col counted from the start side (the right for RTL).
  final List<List<List<_Seg>>> cells;
  final List<_Seg> segs;
  final double top;
  final double bottom;

  int get columns => columnsLtr.length;

  (double, double) _col(int c) => columnsLtr[columnsLtr.length - 1 - c];
  double colLeft(int c) => _col(c).$1;
  double colWidth(int c) => math.max(1, _col(c).$2 - _col(c).$1);

  /// Merges the rows' segment spans into columns; null when a row puts two
  /// segments in one column more than rarely, so it is not a table.
  /// Lines closer than this many median line heights belong to one table row.
  static const double wrapGap = 0.6;

  /// Two wide columns over several rows are text columns, not a table.
  bool get textColumns {
    if (columns != 2) return false;
    // Lines per column, wrapped or not: prose runs long, cells run short.
    final int lines = cells.fold(0, (int n, List<List<_Seg>> row) => n + row[0].length + row[1].length);
    if (lines < 8) return false;
    double fill = 0;
    int n = 0;
    for (final List<List<_Seg>> row in cells) {
      for (int c = 0; c < columns; c++) {
        for (final _Seg s in row[c]) {
          fill += s.box.width / colWidth(c);
          n++;
        }
      }
    }
    return n > 0 && fill / n > 0.75;
  }

  static _Table? fromRows(List<_Row> rows, {required double medianH}) {
    final List<(double, double)> spans = <(double, double)>[
      for (final _Row r in rows)
        for (final _Seg s in r.segs) (s.box.left, s.box.right),
    ]..sort(((double, double) a, (double, double) b) => a.$1.compareTo(b.$1));
    final List<(double, double)> cols = <(double, double)>[];
    for (final (double l, double r) in spans) {
      if (cols.isNotEmpty && l < cols.last.$2) {
        cols[cols.length - 1] = (cols.last.$1, math.max(cols.last.$2, r));
      } else {
        cols.add((l, r));
      }
    }
    if (cols.length < 2) return null;
    int clashes = 0;
    final List<List<List<_Seg>>> cells = <List<List<_Seg>>>[];
    _Row? previous;
    for (final _Row r in rows) {
      // A tight row continues the cells above it (wrapped text).
      final bool wrapped = previous != null && r.box.top - previous.box.bottom < medianH * wrapGap;
      final List<List<_Seg>> row = wrapped ? cells.last : List<List<_Seg>>.generate(cols.length, (_) => <_Seg>[]);
      for (final _Seg s in r.segs) {
        final int ltr = cols.indexWhere(((double, double) c) => s.box.center.dx >= c.$1 && s.box.center.dx <= c.$2);
        final int k = ltr < 0 ? 0 : ltr;
        if (!wrapped && row[cols.length - 1 - k].isNotEmpty) clashes++;
        row[cols.length - 1 - k].add(s);
      }
      if (!wrapped) cells.add(row);
      previous = r;
    }
    if (clashes > cells.length ~/ 3) return null;
    return _Table(
      cols,
      cells,
      <_Seg>[for (final _Row r in rows) ...r.segs],
      rows.first.box.top,
      rows.map((_Row r) => r.box.bottom).reduce(math.max),
    );
  }
}

class _Block {
  _Block.table(_Table t) : table = t, segs = t.segs, top = t.top, bottom = t.bottom, columnParagraphs = null;

  _Block.columns(List<List<_Seg>> this.columnParagraphs, this.top, this.bottom)
    : table = null,
      segs = <_Seg>[for (final List<_Seg> p in columnParagraphs) ...p];

  _Block.text(this.segs)
    : table = null,
      columnParagraphs = null,
      top = segs.map((_Seg s) => s.box.top).reduce(math.min),
      bottom = segs.map((_Seg s) => s.box.bottom).reduce(math.max);

  final _Table? table;

  /// Text columns, already split into paragraphs in reading order.
  final List<List<_Seg>>? columnParagraphs;
  final List<_Seg> segs;
  final double top;
  final double bottom;
}
