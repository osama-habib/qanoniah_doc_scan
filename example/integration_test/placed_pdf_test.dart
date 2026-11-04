import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// ignore: depend_on_referenced_packages
import 'package:printing/printing.dart';
import 'package:qanoniah_doc_scan/src/core/doc_scan_result.dart';
import 'package:qanoniah_doc_scan/src/core/failures.dart';
import 'package:qanoniah_doc_scan/src/core/session/document_edits.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/document/data/pdf_builder.dart';
import 'package:qanoniah_doc_scan/src/document/data/text_pdf_renderer.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/ink_refiner.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/platform_text_recognizer.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/post_processor.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/text_recognizer.dart';

/// The page as printed, end to end on the platform: recognition of `PAGE` (the OCR
/// input), the ink pass, and the native text PDF over the background of `PREP`
/// (the visible page), with the second word of the first paragraph hidden.
/// Writes `placed.pdf` and `placed.png` to `OUT`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('placed text PDF', (WidgetTester t) async {
    await t.runAsync(() async {
      const String page = String.fromEnvironment('PAGE');
      const String prep = String.fromEnvironment('PREP');
      const String out = String.fromEnvironment('OUT');
      final Stopwatch sw = Stopwatch()..start();
      final Either<RecognitionFailure, RawRecognition> raw =
          await PlatformTextRecognizer().recognize(File(page), RecognitionLanguage.ar);
      final RawRecognition r = raw.fold((RecognitionFailure f) => throw StateError('$f'), (RawRecognition r) => r);
      final int tOcr = sw.elapsedMilliseconds;
      final RawRecognition refined = await InkRefiner.refineFile(r, page);
      final int tInk = sw.elapsedMilliseconds - tOcr;
      final PageText text = const PostProcessor().process(refined, RecognitionLanguage.ar);
      for (final List<Word> l in refined.blocks) {
        if (l.any((Word w) => <String>['من', 'في', 'مومت', 'يوم'].contains(w.text))) {
          // ignore: avoid_print
          print('[LINE] ${l.map((Word w) => '${w.text}[${w.box.top.round()}-${w.box.bottom.round()} b${w.baseline.round()}]').join(' ')}');
        }
      }
      final CapturedPage p = CapturedPage(
        id: 'pg',
        rawFile: File(prep),
        corners: Quad.fullFrame,
        filters: const <PageFilter>{PageFilter.original},
        preparedFile: File(prep),
        ocrInputFile: File(page),
        recognition: RecognitionState.done(text),
      );
      final Paragraph first = text.paragraphs.firstWhere((Paragraph q) => q.words.length > 1);
      final DocumentEdits edits = const DocumentEdits().redactWords(('pg', first.id), <int>[1]);
      final ByteData ar = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
      final ByteData arBold = await rootBundle.load('assets/fonts/NotoSansArabic-SemiBold.ttf');
      final ByteData latin = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      sw.reset();
      final Either<BuildFailure, BuildOutput> built = await PdfBuilder(
        textRenderer: PlatformTextPdfRenderer(fallback: const _Loud()),
      ).buildText(
        pages: <CapturedPage>[p],
        edits: edits,
        look: PdfLook(
          font: ar.buffer.asUint8List(),
          fontFallback: latin.buffer.asUint8List(),
          fontBold: arBold.buffer.asUint8List(),
          text: 0xff1a1a1a,
          redactionFill: 0xff222222,
          onRedactionFill: 0xffffffff,
          redactedLabel: 'نص محجوب',
        ),
        out: File('$out/placed.pdf'),
      );
      final BuildOutput o = built.fold((BuildFailure f) => throw StateError('$f'), (BuildOutput o) => o);
      // ignore: avoid_print
      print('[PLACED] ocr ${tOcr}ms ink ${tInk}ms pdf ${sw.elapsedMilliseconds}ms ${o.sizeBytes ~/ 1024}KB '
          'form ${o.form == DocScanPdfForm.text ? 'text' : 'image'} hidden "${first.words[1].text}"');
      await for (final PdfRaster ras in Printing.raster(File('$out/placed.pdf').readAsBytesSync(), dpi: 144)) {
        File('$out/placed.png').writeAsBytesSync(await ras.toPng());
        break;
      }
    });
  });
}

/// The package renderer, saying so when the platform one was missing.
class _Loud extends PdfPackageTextRenderer {
  const _Loud();

  @override
  Future<Uint8List> renderPlaced(List<PdfPlacedPage> pages, PdfLook look) {
    // ignore: avoid_print
    print('[PLACED] FALLBACK renderer used');
    return super.renderPlaced(pages, look);
  }
}
