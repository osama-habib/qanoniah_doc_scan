import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/post_processor.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/text_recognizer.dart';

Word w(String t, double l, double top, {double width = 40, double h = 20}) =>
    Word(text: t, box: Rect.fromLTWH(l, top, width, h), confidence: 0.9);

void main() {
  const PostProcessor pp = PostProcessor();

  test('Arabic line reads right to left and keeps a Latin run left to right', () {
    // Visual order, left to right: "Article" "5" "المادة" "نص"
    final List<Word> ordered = PostProcessor.orderLine(<Word>[
      w('Article', 10, 0), w('نص', 300, 0), w('5', 60, 0), w('المادة', 200, 0),
    ]);
    expect(ordered.map((Word x) => x.text).toList(), <String>['نص', 'المادة', 'Article', '5']);
  });

  test('Latin line reads left to right', () {
    final List<Word> ordered = PostProcessor.orderLine(<Word>[w('world', 100, 0), w('hello', 0, 0)]);
    expect(ordered.map((Word x) => x.text).toList(), <String>['hello', 'world']);
  });

  test('digits and separators normalize to Latin', () {
    expect(PostProcessor.normalizeText('٢٠٢٤'), '2024');
    expect(PostProcessor.normalizeText('۱۹٫۵۵'), '19.55');
    expect(PostProcessor.normalizeText('% 15'), '15%');
    expect(PostProcessor.normalizeText('٪١٠'), '10%');
  });

  test('a large vertical gap starts a new paragraph; boxes are kept', () {
    final PageText page = pp.process(
      RawRecognition(
        blocksAreParagraphs: false,
        blocks: <List<Word>>[
          <Word>[w('سطر', 0, 0)],
          <Word>[w('تابع', 0, 24)],
          <Word>[w('فقرة', 0, 200)],
        ],
      ),
      RecognitionLanguage.ar,
    );
    expect(page.paragraphs.length, 2);
    expect(page.paragraphs.first.words.length, 2);
    expect(page.paragraphs.last.words.single.box, const Rect.fromLTWH(0, 200, 40, 20));
  });

  test('engine paragraphs are not regrouped', () {
    final PageText page = pp.process(
      RawRecognition(blocksAreParagraphs: true, blocks: <List<Word>>[
        <Word>[w('a', 0, 0)],
        <Word>[w('b', 0, 22)],
      ]),
      RecognitionLanguage.en,
    );
    expect(page.paragraphs.length, 2);
  });

  test('arabic ratio counts letters only', () {
    expect(PostProcessor.arabicRatio(<String>['نص', 'ab']), 0.5);
    expect(PostProcessor.arabicRatio(<String>['123']), 0);
  });
}
