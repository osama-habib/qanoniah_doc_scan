import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/src/core/session/document_edits.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';

void main() {
  Paragraph para(String id, List<String> words) => Paragraph(
    id: id,
    words: <Word>[for (final String t in words) Word(text: t, box: Rect.zero, confidence: 1)],
  );

  final Paragraph p0 = para('p0', <String>['يلتزم', 'الطرف', 'الثاني', 'بالسرية']);
  final Paragraph p1 = para('p1', <String>['المادة', 'الثانية']);
  final CapturedPage page = CapturedPage(
    id: 'pg',
    rawFile: File('x'),
    corners: Quad.fullFrame,
    filters: const <PageFilter>{PageFilter.original},
    preparedFile: File('x'),
    ocrInputFile: File('x'),
    recognition: RecognitionState.done(
      PageText(language: RecognitionLanguage.ar, paragraphs: <Paragraph>[p0, p1]),
    ),
  );

  test('an edit then a revert is not dirty', () {
    final DocumentEdits e = const DocumentEdits()
        .edit(('pg', 'p0'), 'نص جديد', original: p0.text)
        .edit(('pg', 'p0'), p0.text, original: p0.text);
    expect(e.isDirty, isFalse);
  });

  test('finalText uses the replacement', () {
    final DocumentEdits e = const DocumentEdits().edit(('pg', 'p1'), 'المادة الثالثة', original: p1.text);
    expect(e.finalText(page), contains('المادة الثالثة'));
    expect(e.finalText(page), isNot(contains('الثانية')));
  });

  test('redacted words and paragraphs are absent from finalText', () {
    final DocumentEdits e = const DocumentEdits().redactWords(('pg', 'p0'), <int>[1, 2]).toggleParagraph(('pg', 'p1'));
    final String text = e.finalText(page);
    expect(text, 'يلتزم بالسرية');
    expect(e.redactedWordCount, 2);
    expect(e.isDirty, isTrue);
    expect(e.finalSegments('pg', p1).single, isA<FinalRedaction>());
  });

  test('editing a paragraph clears its word redactions', () {
    final DocumentEdits e = const DocumentEdits()
        .redactWords(('pg', 'p0'), <int>[0])
        .edit(('pg', 'p0'), 'نص', original: p0.text);
    expect(e.redactedWordCount, 0);
  });

  test('revealing a paragraph keeps its earlier edit', () {
    final DocumentEdits e = const DocumentEdits()
        .edit(('pg', 'p1'), 'معدّل', original: p1.text)
        .toggleParagraph(('pg', 'p1'))
        .toggleParagraph(('pg', 'p1'));
    expect(e.finalText(page), contains('معدّل'));
  });
}
