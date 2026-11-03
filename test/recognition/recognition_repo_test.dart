import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session_repo.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/recognition_repo.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/text_recognizer.dart';

import '../fakes/fake_text_recognizer.dart';

RawRecognition raw(List<String> words, double conf) => RawRecognition(
  blocksAreParagraphs: false,
  blocks: <List<Word>>[
    <Word>[
      for (int i = 0; i < words.length; i++)
        Word(text: words[i], box: Rect.fromLTWH(i * 50.0, 0, 40, 20), confidence: conf),
    ],
  ],
);

void main() {
  late Directory tmp;
  late ScanSessionRepo sessions;
  late FakeTextRecognizer engine;
  late RecognitionRepo repo;

  CapturedPage page(String id, {String suffix = ''}) {
    final File f = File('${tmp.path}/$id$suffix.png')..writeAsBytesSync(<int>[1]);
    return CapturedPage(
      id: id,
      rawFile: f,
      corners: Quad.fullFrame,
      filters: const <PageFilter>{PageFilter.original},
      preparedFile: f,
      ocrInputFile: f,
      recognition: const RecognitionState.pending(),
    );
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rec');
    sessions = ScanSessionRepo(tempRoot: () async => tmp);
    await sessions.start();
    engine = FakeTextRecognizer();
    repo = RecognitionRepo(recognizer: engine, sessions: sessions);
  });

  tearDown(() async {
    repo.dispose();
    await tmp.delete(recursive: true);
  });

  Future<RecognitionState> run(CapturedPage p) async {
    sessions.addPage(p);
    repo.enqueue(p);
    await repo.whenComplete();
    return sessions.session.pages.firstWhere((CapturedPage x) => x.id == p.id).recognition;
  }

  test('confident Arabic is accepted with no English pass', () async {
    final CapturedPage p = page('a');
    engine.stub(p.ocrInputFile, RecognitionLanguage.ar, raw(<String>['حكم', 'المحكمة'], 0.9));
    final RecognitionState s = await run(p);
    expect(s, isA<RecognitionDone>());
    expect(engine.calls.map(((String, RecognitionLanguage) c) => c.$2), <RecognitionLanguage>[RecognitionLanguage.ar]);
  });

  test('low-confidence Arabic runs English and the better pass wins; never combined', () async {
    final CapturedPage p = page('b');
    engine
      ..stub(p.ocrInputFile, RecognitionLanguage.ar, raw(<String>['ءءء'], 0.2))
      ..stub(p.ocrInputFile, RecognitionLanguage.en, raw(<String>['Contract', 'Article'], 0.9));
    final RecognitionState s = await run(p);
    expect((s as RecognitionDone).text.language, RecognitionLanguage.en);
    expect(engine.calls.length, 2);
  });

  test('no words gives noText', () async {
    expect(await run(page('c')), isA<RecognitionNoText>());
  });

  test('a result for an outdated version of a page is dropped', () async {
    final CapturedPage old = page('d');
    sessions.addPage(old);
    final CapturedPage changed = page('d', suffix: '-v2');
    engine
      ..stub(old.ocrInputFile, RecognitionLanguage.ar, raw(<String>['قديم'], 0.9))
      ..stub(changed.ocrInputFile, RecognitionLanguage.ar, raw(<String>['جديد'], 0.9));
    await sessions.replacePage(changed);
    repo
      ..enqueue(old)
      ..enqueue(changed);
    await repo.whenComplete();
    final RecognitionState s = sessions.session.pages.single.recognition;
    expect((s as RecognitionDone).text.paragraphs.single.text, 'جديد');
  });
}
