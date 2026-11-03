import 'package:flutter/foundation.dart';

import 'scan_session.dart';

/// Identifies one paragraph of one page.
typedef ParagraphKey = (String pageId, String paragraphId);

/// One run of a final paragraph: text that is sent, or a redaction that is not.
@immutable
sealed class FinalSegment {
  const FinalSegment();
}

class FinalText extends FinalSegment {
  const FinalText(this.text);
  final String text;
}

/// A redacted run. It carries no characters, so nothing downstream can leak them.
class FinalRedaction extends FinalSegment {
  const FinalRedaction({required this.wholeParagraph});
  final bool wholeParagraph;
}

/// The user's edits and redactions, kept apart from the recognized text so that a
/// revert restores the original (data-model DocumentEdits).
@immutable
class DocumentEdits {
  const DocumentEdits({
    this.replacements = const <ParagraphKey, String>{},
    this.redactedWords = const <ParagraphKey, Set<int>>{},
    this.redactedParagraphs = const <ParagraphKey>{},
  });

  /// Edited paragraph text (FR-015).
  final Map<ParagraphKey, String> replacements;

  /// Word indexes per paragraph (story 8).
  final Map<ParagraphKey, Set<int>> redactedWords;

  /// Whole paragraphs (story 9).
  final Set<ParagraphKey> redactedParagraphs;

  /// Sets the paragraph's text. Editing clears that paragraph's word redactions: the
  /// edited text is what gets sent. Setting the original text back reverts.
  DocumentEdits edit(ParagraphKey key, String text, {required String original}) {
    final Map<ParagraphKey, String> r = Map<ParagraphKey, String>.of(replacements);
    if (text == original) {
      r.remove(key);
    } else {
      r[key] = text;
    }
    final Map<ParagraphKey, Set<int>> w = Map<ParagraphKey, Set<int>>.of(redactedWords)..remove(key);
    return DocumentEdits(replacements: r, redactedWords: w, redactedParagraphs: redactedParagraphs);
  }

  DocumentEdits redactWords(ParagraphKey key, Iterable<int> indexes) {
    final Map<ParagraphKey, Set<int>> w = Map<ParagraphKey, Set<int>>.of(redactedWords);
    w[key] = <int>{...?w[key], ...indexes};
    return DocumentEdits(replacements: replacements, redactedWords: w, redactedParagraphs: redactedParagraphs);
  }

  DocumentEdits revealWords(ParagraphKey key, Iterable<int> indexes) {
    final Map<ParagraphKey, Set<int>> w = Map<ParagraphKey, Set<int>>.of(redactedWords);
    final Set<int> left = <int>{...?w[key]}..removeAll(indexes);
    if (left.isEmpty) {
      w.remove(key);
    } else {
      w[key] = left;
    }
    return DocumentEdits(replacements: replacements, redactedWords: w, redactedParagraphs: redactedParagraphs);
  }

  /// Toggles a whole-paragraph redaction. Revealing keeps any earlier edit.
  DocumentEdits toggleParagraph(ParagraphKey key) {
    final Set<ParagraphKey> p = Set<ParagraphKey>.of(redactedParagraphs);
    if (!p.remove(key)) p.add(key);
    return DocumentEdits(replacements: replacements, redactedWords: redactedWords, redactedParagraphs: p);
  }

  bool isParagraphRedacted(ParagraphKey key) => redactedParagraphs.contains(key);

  bool isWordRedacted(ParagraphKey key, int index) => redactedWords[key]?.contains(index) ?? false;

  /// True when anything the user changed is still in effect (FR-011).
  bool get isDirty =>
      replacements.isNotEmpty || redactedParagraphs.isNotEmpty || redactedWords.values.any((Set<int> s) => s.isNotEmpty);

  int get redactedWordCount => redactedWords.values.fold(0, (int n, Set<int> s) => n + s.length);

  /// Redaction actions in effect: one per paragraph plus one per redacted word.
  int get redactionCount => redactedParagraphs.length + redactedWordCount;

  int get editedParagraphCount => replacements.length;

  /// The text the user sees for [paragraph] when not redacted.
  String textOf(String pageId, Paragraph paragraph) =>
      replacements[(pageId, paragraph.id)] ?? paragraph.text;

  /// The paragraph as it will be sent: the replacement or the original, with
  /// redactions as [FinalRedaction] runs (FR-041, FR-042).
  List<FinalSegment> finalSegments(String pageId, Paragraph paragraph) {
    final ParagraphKey key = (pageId, paragraph.id);
    if (redactedParagraphs.contains(key)) {
      return const <FinalSegment>[FinalRedaction(wholeParagraph: true)];
    }
    final String? replaced = replacements[key];
    if (replaced != null) return <FinalSegment>[FinalText(replaced)];
    final Set<int> hidden = redactedWords[key] ?? const <int>{};
    final List<FinalSegment> out = <FinalSegment>[];
    final StringBuffer run = StringBuffer();
    void flush() {
      if (run.isNotEmpty) out.add(FinalText(run.toString()));
      run.clear();
    }

    for (int i = 0; i < paragraph.words.length; i++) {
      if (hidden.contains(i)) {
        flush();
        if (out.isEmpty || out.last is! FinalRedaction) out.add(const FinalRedaction(wholeParagraph: false));
      } else {
        if (run.isNotEmpty) run.write(' ');
        run.write(paragraph.words[i].text);
      }
    }
    flush();
    return out;
  }

  /// The final text of one page: redacted paragraphs produce nothing, redacted
  /// words are dropped (data-model `finalText`).
  String finalText(CapturedPage page) {
    final RecognitionState r = page.recognition;
    if (r is! RecognitionDone) return '';
    return r.text.paragraphs
        .map(
          (Paragraph p) => finalSegments(page.id, p)
              .whereType<FinalText>()
              .map((FinalText t) => t.text)
              .join(' ')
              .trim(),
        )
        .where((String t) => t.isNotEmpty)
        .join('\n\n');
  }
}
