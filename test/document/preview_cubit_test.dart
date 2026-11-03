import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/src/core/doc_scan_event.dart';
import 'package:qanoniah_doc_scan/src/core/doc_scan_result.dart';
import 'package:qanoniah_doc_scan/src/core/failures.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session_repo.dart';
import 'package:qanoniah_doc_scan/src/document/data/pdf_builder.dart';
import 'package:qanoniah_doc_scan/src/document/data/size_fitter.dart';
import 'package:qanoniah_doc_scan/src/document/manager/preview_cubit.dart';

import '../helpers/pdf_fixtures.dart';

void main() {
  late Directory tmp;
  late ScanSessionRepo sessions;
  late List<DocScanEvent> events;
  late BuildOutput built;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('prev');
    sessions = ScanSessionRepo(tempRoot: () async => tmp);
    await sessions.start();
    sessions.addPage(pdfPage(sessions.session.dir, 'a', <String>['يلتزم', 'SECRETWORD', 'بالسرية'], w: 300, h: 400));
    events = <DocScanEvent>[];
    final File f = sessions.newFile('pdf')..writeAsBytesSync(<int>[1, 2, 3]);
    built = BuildOutput(file: f, form: DocScanPdfForm.image, sizeBytes: 3, compressed: false);
  });

  tearDown(() async => tmp.delete(recursive: true));

  PreviewCubit cubit({int max = 5 << 20}) => PreviewCubit(
    sessions: sessions,
    built: built,
    fitter: const SizeFitter(),
    builder: const PdfBuilder(),
    look: testLook(),
    maxFileBytes: max,
    defaultStem: 'مستند-ممسوح-01',
    onEvent: events.add,
    estimateDelay: Duration.zero,
  );

  Paragraph para() => (sessions.session.pages.single.recognition as RecognitionDone).text.paragraphs.single;

  test('untouched document reuses the build-step image PDF', () async {
    final PreviewCubit c = cubit();
    final BuildOutput o = (await c.attach()).getOrElse(() => fail('attach failed'));
    expect(o.file.path, built.file.path);
    expect(o.form, DocScanPdfForm.image);
    expect(events.first.name, 'scan_preview_opened');
    await c.close();
  });

  test('an edit sends text form; the returned text is the edit', () async {
    final PreviewCubit c = cubit();
    c.setEditing(true);
    c.editParagraph('a', para(), 'نص معدّل');
    final BuildOutput o = (await c.attach()).getOrElse(() => fail('attach failed'));
    expect(o.form, DocScanPdfForm.text);
    expect(c.state.edits.finalText(sessions.session.pages.single), 'نص معدّل');
    expect(events.map((DocScanEvent e) => e.name), containsAll(<String>['scan_edit_mode_entered', 'scan_paragraph_edited']));
    await c.close();
  });

  test('redacted words never reach pageTexts, events, or the attach form', () async {
    final PreviewCubit c = cubit();
    c.select(const WordSelection(pageId: 'a', paragraphId: 'p0', start: 1, end: 1));
    expect(c.state.selectionRedacted, isFalse);
    c.redactSelection();
    expect(c.state.edits.redactedWordCount, 1);
    expect(c.state.colorModeAvailable, isFalse);
    final BuildOutput o = (await c.attach()).getOrElse(() => fail('attach failed'));
    expect(o.form, DocScanPdfForm.text);
    expect(c.state.edits.finalText(sessions.session.pages.single), isNot(contains('SECRETWORD')));
    for (final DocScanEvent e in events) {
      expect('${e.name} ${e.params}', isNot(contains('SECRETWORD')));
    }
    await c.close();
  });

  test('paragraph redaction toggles and reveal restores the edit', () async {
    final PreviewCubit c = cubit();
    c.editParagraph('a', para(), 'مُعدّل');
    c.toggleParagraphRedaction('a', 'p0');
    expect(c.state.edits.finalText(sessions.session.pages.single), isEmpty);
    c.toggleParagraphRedaction('a', 'p0');
    expect(c.state.edits.finalText(sessions.session.pages.single), 'مُعدّل');
    expect(events.map((DocScanEvent e) => e.name), containsAll(<String>['scan_paragraph_redacted', 'scan_redaction_removed']));
    await c.close();
  });

  test('rename trims, keeps .pdf, rejects bad names, and never puts the name in an event', () async {
    final PreviewCubit c = cubit();
    expect(c.rename('  عقد الإيجار.pdf '), isTrue);
    expect(c.state.fileStem, 'عقد الإيجار');
    expect(c.rename('   '), isFalse);
    expect(c.rename('a/b'), isFalse);
    expect(events.where((DocScanEvent e) => e.toString().contains('عقد')), isEmpty);
    await c.close();
  });

  test('a document over the limit fails with tooLarge', () async {
    final PreviewCubit c = cubit(max: 2);
    final Either<BuildFailure, BuildOutput> r = await c.attach();
    expect(r.fold((BuildFailure f) => f, (_) => null), isA<BuildTooLarge>());
    expect(events.map((DocScanEvent e) => e.name), contains('scan_size_limit_exceeded'));
    await c.close();
  });
}
