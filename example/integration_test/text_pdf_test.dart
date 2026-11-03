import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qanoniah_doc_scan/src/core/session/document_edits.dart';
import 'package:qanoniah_doc_scan/src/document/data/pdf_builder.dart';
import 'package:qanoniah_doc_scan/src/document/data/text_pdf_renderer.dart';

/// Renders a text-form PDF with the platform engine and leaves it in the app's temp
/// directory for text extraction on the host (research R7 check).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('platform text-form PDF', (WidgetTester _) async {
    final ByteData ar = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
    final ByteData latin = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final PdfLook look = PdfLook(
      font: ar.buffer.asUint8List(),
      fontFallback: latin.buffer.asUint8List(),
      text: 0xff222222,
      redactionFill: 0xff222222,
      onRedactionFill: 0xffffffff,
      redactedLabel: 'نص محجوب',
    );
    final Uint8List pdf = await PlatformTextPdfRenderer(fallback: const PdfPackageTextRenderer()).render(
      <List<PdfTextBlock>>[
        <PdfTextBlock>[
          const PdfTextBlock(rtl: true, segments: <FinalSegment>[
            FinalText('وفق Article 5 من اللائحة (2) بنسبة 19.55% من رأس المال'),
            FinalRedaction(wholeParagraph: false),
            FinalText('والقضية رقم 10500 لعام 1440'),
          ]),
          const PdfTextBlock(rtl: true, segments: <FinalSegment>[FinalRedaction(wholeParagraph: true)]),
          const PdfTextBlock(rtl: false, segments: <FinalSegment>[FinalText('Contract of employment, clause 3.')]),
        ],
      ],
      look,
    );
    final File out = File(const String.fromEnvironment('PDF_OUT', defaultValue: '/tmp/qanoniah_text_pdf_check.pdf'))..writeAsBytesSync(pdf);
    // ignore: avoid_print
    print('PDF_OUT=${out.path} bytes=${pdf.length}');
    expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
  });
}
