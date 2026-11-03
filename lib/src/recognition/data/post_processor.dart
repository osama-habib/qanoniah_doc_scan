import 'dart:ui' show Rect;

import '../../core/session/scan_session.dart';
import 'text_recognizer.dart';

/// Layer 3 of the OCR service: turns either engine's raw output into [PageText]
/// (FR-051, research R6). Engine-independent, so the evaluation set measures
/// engines and not formatting differences.
class PostProcessor {
  const PostProcessor({this.paragraphGapFactor = 1.2});

  /// A vertical gap larger than this many median line heights starts a paragraph.
  final double paragraphGapFactor;

  PageText process(RawRecognition raw, RecognitionLanguage language) {
    final List<List<Word>> lines = raw.blocks
        .map((List<Word> words) => words.map(_normalizeWord).where((Word w) => w.text.isNotEmpty).toList())
        .where((List<Word> words) => words.isNotEmpty)
        .map(orderLine)
        .toList();
    final List<List<Word>> paragraphs = raw.blocksAreParagraphs ? lines : _group(lines);
    return PageText(
      language: language,
      paragraphs: <Paragraph>[
        for (int i = 0; i < paragraphs.length; i++) Paragraph(id: 'p$i', words: paragraphs[i]),
      ],
    );
  }

  /// Logical order: right to left for Arabic lines with Latin runs kept left to
  /// right inside them; left to right for Latin lines.
  static List<Word> orderLine(List<Word> words) {
    final int arabic = words.where((Word w) => hasArabic(w.text)).length;
    final bool rtl = arabic * 2 >= words.length;
    final List<Word> sorted = List<Word>.of(words)
      ..sort((Word a, Word b) => rtl ? b.box.right.compareTo(a.box.right) : a.box.left.compareTo(b.box.left));
    if (!rtl) return sorted;
    final List<Word> out = <Word>[];
    final List<Word> run = <Word>[];
    void flush() {
      out.addAll(run.reversed);
      run.clear();
    }

    for (final Word w in sorted) {
      if (hasArabic(w.text)) {
        flush();
        out.add(w);
      } else {
        run.add(w);
      }
    }
    flush();
    return out;
  }

  List<List<Word>> _group(List<List<Word>> lines) {
    if (lines.isEmpty) return lines;
    final List<List<Word>> byTop = List<List<Word>>.of(lines)
      ..sort((List<Word> a, List<Word> b) => _bounds(a).top.compareTo(_bounds(b).top));
    final List<double> heights = byTop.map((List<Word> l) => _bounds(l).height).toList()..sort();
    final double median = heights[heights.length ~/ 2];
    final List<List<Word>> out = <List<Word>>[List<Word>.of(byTop.first)];
    for (int i = 1; i < byTop.length; i++) {
      final double gap = _bounds(byTop[i]).top - _bounds(byTop[i - 1]).bottom;
      if (gap > median * paragraphGapFactor) {
        out.add(List<Word>.of(byTop[i]));
      } else {
        out.last.addAll(byTop[i]);
      }
    }
    return out;
  }

  static Rect _bounds(List<Word> line) =>
      line.map((Word w) => w.box).reduce((Rect a, Rect b) => a.expandToInclude(b));

  static Word _normalizeWord(Word w) => w.copyWith(text: normalizeText(w.text.trim()));

  static final RegExp _arabicLetter = RegExp(r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]');

  static bool hasArabic(String s) => _arabicLetter.hasMatch(s.replaceAll(RegExp(r'[٠-٩۰-۹]'), ''));

  /// Share of letters that are Arabic, for the per-page language rule (R5).
  static double arabicRatio(Iterable<String> texts) {
    int ar = 0;
    int letters = 0;
    for (final String t in texts) {
      for (final int r in t.runes) {
        final String c = String.fromCharCode(r);
        if (_arabicLetter.hasMatch(c)) {
          ar++;
          letters++;
        } else if (RegExp(r'[A-Za-z]').hasMatch(c)) {
          letters++;
        }
      }
    }
    return letters == 0 ? 0 : ar / letters;
  }

  /// Arabic-Indic and Persian digits to Latin, Arabic separators to Latin, and a
  /// leading `%` moved after its number.
  static String normalizeText(String s) {
    final StringBuffer b = StringBuffer();
    for (final int r in s.runes) {
      if (r >= 0x0660 && r <= 0x0669) {
        b.writeCharCode(0x30 + r - 0x0660);
      } else if (r >= 0x06F0 && r <= 0x06F9) {
        b.writeCharCode(0x30 + r - 0x06F0);
      } else if (r == 0x066B) {
        b.write('.');
      } else if (r == 0x066C) {
        b.write(',');
      } else if (r == 0x066A) {
        b.write('%');
      } else {
        b.writeCharCode(r);
      }
    }
    return b.toString().replaceAllMapped(
      RegExp(r'%\s*(\d+(?:[.,]\d+)?)'),
      (Match m) => '${m[1]}%',
    );
  }

  /// Mean word confidence, 0 when there are no words.
  static double meanConfidence(RawRecognition raw) {
    final List<double> c = raw.blocks.expand((List<Word> l) => l).map((Word w) => w.confidence).toList();
    return c.isEmpty ? 0 : c.reduce((double a, double b) => a + b) / c.length;
  }

  static int wordCount(RawRecognition raw) => raw.blocks.fold(0, (int n, List<Word> l) => n + l.length);
}
