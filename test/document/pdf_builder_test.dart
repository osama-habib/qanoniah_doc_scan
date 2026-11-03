import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/src/core/doc_scan_result.dart';
import 'package:qanoniah_doc_scan/src/core/failures.dart';
import 'package:qanoniah_doc_scan/src/core/session/document_edits.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/document/data/pdf_builder.dart';
import 'package:qanoniah_doc_scan/src/document/data/size_fitter.dart';

import '../helpers/pdf_fixtures.dart';

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('pdf'));
  tearDown(() async => tmp.delete(recursive: true));

  int n = 0;
  File out() => File('${tmp.path}/out${n++}.pdf');

  test('image form: one page per captured page, in session order', () async {
    final List<CapturedPage> pages = <CapturedPage>[
      pdfPage(tmp, 'a', <String>['أول'], w: 300, h: 400),
      pdfPage(tmp, 'b', <String>['ثاني'], w: 300, h: 400),
      pdfPage(tmp, 'c', <String>['ثالث'], w: 300, h: 400),
    ];
    final Either<BuildFailure, BuildOutput> r = await const PdfBuilder().buildImage(
      pages: pages,
      colorMode: ScanColorMode.color,
      encoding: ImageEncoding.ladder.first,
      look: testLook(),
      out: out(),
    );
    final BuildOutput o = r.getOrElse(() => fail('build failed'));
    expect(o.form, DocScanPdfForm.image);
    final String text = pdfText(o.file.readAsBytesSync());
    expect(RegExp(r'/Type\s*/Page\b').allMatches(text).length, 3);
    expect(text, contains(RegExp(r'/Subtype\s*/Image')));
  });

  test('text form holds no images and is built from final segments only', () async {
    final CapturedPage p = pdfPage(tmp, 'a', <String>['يلتزم', 'SECRETWORD', 'بالسرية'], w: 300, h: 400);
    final DocumentEdits edits = const DocumentEdits().redactWords(('a', 'p0'), <int>[1]);
    final Either<BuildFailure, BuildOutput> r = await const PdfBuilder().buildText(
      pages: <CapturedPage>[p],
      edits: edits,
      look: testLook(),
      out: out(),
    );
    final BuildOutput o = r.getOrElse(() => fail('build failed'));
    expect(o.form, DocScanPdfForm.text);
    final String text = pdfText(o.file.readAsBytesSync());
    expect(text, isNot(contains(RegExp(r'/Subtype\s*/Image'))));
    expect(text, isNot(contains('SECRETWORD')));
    expect(edits.finalText(p), isNot(contains('SECRETWORD')));
  });

  test('size fitter compresses under the limit, or reports tooLarge at the floor', () async {
    final List<CapturedPage> pages = <CapturedPage>[pdfPage(tmp, 'a', <String>['نص'])];
    const SizeFitter fitter = SizeFitter();
    final BuildOutput best = (await fitter.fitImage(
      pages: pages,
      colorMode: ScanColorMode.color,
      look: testLook(),
      maxBytes: 1 << 30,
      newFile: out,
    )).getOrElse(() => fail('fit failed'));
    expect(best.compressed, isFalse);

    final Either<BuildFailure, BuildOutput> squeezed = await fitter.fitImage(
      pages: pages,
      colorMode: ScanColorMode.color,
      look: testLook(),
      maxBytes: best.sizeBytes - 1,
      newFile: out,
    );
    final BuildOutput s = squeezed.getOrElse(() => fail('should fit when compressed'));
    expect(s.compressed, isTrue);
    expect(s.sizeBytes, lessThan(best.sizeBytes));

    final Either<BuildFailure, BuildOutput> impossible = await fitter.fitImage(
      pages: pages,
      colorMode: ScanColorMode.color,
      look: testLook(),
      maxBytes: 1000,
      newFile: out,
    );
    expect(impossible.fold((BuildFailure f) => f, (_) => null), isA<BuildTooLarge>());
  });
}
