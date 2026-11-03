import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/layout_analyzer.dart';

/// A line of [n] words between [left] and [right] at [top], word boxes even.
List<Word> line(String tag, double left, double right, double top, {int n = 4, double h = 30}) {
  final double w = (right - left) / n;
  return <Word>[
    // Right to left, like an Arabic engine line.
    for (int i = 0; i < n; i++)
      Word(text: '$tag$iب', box: Rect.fromLTWH(right - (i + 1) * w + 4, top, w - 8, h), confidence: 0.9),
  ];
}

void main() {
  const LayoutAnalyzer a = LayoutAnalyzer();

  test('[UT] heading, justified paragraph, table, signature row in reading order', () {
    final List<List<Word>> lines = <List<Word>>[
      line('h', 420, 820, 100, n: 2, h: 52), // centered heading
      line('a', 100, 1140, 250), // justified paragraph, 3 lines
      line('b', 100, 1140, 300),
      line('c', 500, 1140, 350), // last line short, start (right) aligned
      // Table 3x3: columns 760-1130, 420-760, 110-420.
      for (int r = 0; r < 3; r++) ...<List<Word>>[
        line('t${r}0', 800, 1100, 600 + r * 76.0, n: 2),
        line('t${r}1', 460, 720, 600 + r * 76.0, n: 2),
        line('t${r}2', 150, 380, 600 + r * 76.0, n: 2),
      ],
      line('sR', 860, 1140, 1500, n: 2), // signature on the right
      line('sL', 100, 380, 1500, n: 2), // and on the left
    ];
    final List<Paragraph> ps = a.analyze(lines, rtl: true);

    final Paragraph heading = ps.first;
    expect(heading.heading, isTrue, reason: 'size ${heading.size}');
    expect(heading.align, BlockAlign.center);

    final Paragraph body = ps[1];
    expect(body.words.first.text, 'a0ب');
    expect(body.lines, hasLength(3));
    expect(body.align, BlockAlign.justify);
    expect(body.spaceBefore, greaterThan(1));

    final List<Paragraph> cells = ps.where((Paragraph p) => p.table == 0).toList();
    expect(cells, hasLength(9));
    expect(cells.firstWhere((Paragraph p) => p.row == 0 && p.col == 0).words.first.text, startsWith('t00'));
    expect(cells.firstWhere((Paragraph p) => p.row == 2 && p.col == 2).words.first.text, startsWith('t22'));

    final List<Paragraph> sig = ps.where((Paragraph p) => p.table == 1).toList();
    expect(sig, hasLength(2));
    expect(sig.firstWhere((Paragraph p) => p.col == 0).words.first.text, startsWith('sR'));
    expect(ps.last.table, 1);
  });

  test('[UT] an indented start-aligned line keeps its indent', () {
    final List<Paragraph> ps = a.analyze(<List<Word>>[
      line('a', 100, 1140, 100),
      line('b', 100, 1140, 300),
      line('c', 400, 900, 500), // 240 from the right margin, short of the left
    ], rtl: true);
    final Paragraph c = ps.last;
    expect(c.align, BlockAlign.start);
    expect(c.indent, closeTo(240 / 1040, 0.02));
  });

  test('[UT] a wrapped table cell stays one cell; a paragraph under the table does not join it', () {
    final List<Paragraph> ps = a.analyze(<List<Word>>[
      line('h0', 800, 1100, 600, n: 2),
      line('h1', 460, 720, 600, n: 2),
      line('r0', 800, 1100, 676, n: 2),
      line('r1', 460, 720, 676, n: 2),
      line('w1', 480, 700, 708, n: 2), // second line of cell r1, tight under it
      line('s0', 800, 1100, 800, n: 2),
      line('s1', 460, 720, 800, n: 2),
      line('p', 100, 1140, 845), // a paragraph right under the table
    ], rtl: true);
    final List<Paragraph> cells = ps.where((Paragraph p) => p.table == 0).toList();
    expect(cells, hasLength(6));
    final Paragraph wrapped = cells.firstWhere((Paragraph p) => p.row == 1 && p.col == 1);
    expect(wrapped.lines, hasLength(2));
    expect(ps.last.table, isNull);
    expect(ps.last.words.first.text, startsWith('p'));
  });

  test('[UT] two wide text columns read column by column, not as a table', () {
    final List<List<Word>> lines = <List<Word>>[
      for (int r = 0; r < 6; r++) ...<List<Word>>[
        line('R$r', 640, 1140, 100 + r * 40.0, n: 6),
        line('L$r', 100, 600, 100 + r * 40.0, n: 6),
      ],
    ];
    final List<Paragraph> ps = a.analyze(lines, rtl: true);
    expect(ps.every((Paragraph p) => p.table == null), isTrue);
    expect(ps, hasLength(2));
    expect(ps.first.words.first.text, startsWith('R0'));
    expect(ps.first.lines, hasLength(6));
    expect(ps.last.words.first.text, startsWith('L0'));
  });
}
