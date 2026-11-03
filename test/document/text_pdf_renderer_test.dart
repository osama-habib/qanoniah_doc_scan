import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/src/core/session/document_edits.dart';
import 'package:qanoniah_doc_scan/src/document/data/pdf_builder.dart';
import 'package:qanoniah_doc_scan/src/document/data/text_pdf_renderer.dart';

import '../helpers/pdf_fixtures.dart';

class _Fallback implements TextPdfRenderer {
  int calls = 0;
  @override
  Future<Uint8List> render(List<List<PdfTextBlock>> pages, PdfLook look) async {
    calls++;
    return Uint8List.fromList('%PDF-fallback'.codeUnits);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('qanoniah_doc_scan/pdf');
  final List<List<PdfTextBlock>> pages = <List<PdfTextBlock>>[
    <PdfTextBlock>[
      const PdfTextBlock(rtl: true, segments: <FinalSegment>[
        FinalText('يلتزم'),
        FinalRedaction(wholeParagraph: false),
        FinalText('بالسرية'),
      ]),
      const PdfTextBlock(rtl: true, segments: <FinalSegment>[FinalRedaction(wholeParagraph: true)]),
    ],
  ];

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  test('the platform gets markers for redactions, never their text', () async {
    Map<Object?, Object?>? sent;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall c) async {
      sent = c.arguments as Map<Object?, Object?>;
      return Uint8List.fromList('%PDF-native'.codeUnits);
    });
    final _Fallback fallback = _Fallback();
    final Uint8List pdf = await PlatformTextPdfRenderer(fallback: fallback).render(pages, testLook());
    expect(String.fromCharCodes(pdf), '%PDF-native');
    expect(fallback.calls, 0);
    final List<Object?> blocks = (sent!['pages']! as List<Object?>).single! as List<Object?>;
    final List<Object?> first = (blocks.first! as Map<Object?, Object?>)['segments']! as List<Object?>;
    expect(first, <Object>[
      <String, Object>{'text': 'يلتزم'},
      <String, Object>{'redacted': 'words'},
      <String, Object>{'text': 'بالسرية'},
    ]);
    expect(((blocks.last! as Map<Object?, Object?>)['segments']! as List<Object?>).single, <String, Object>{'redacted': 'paragraph'});
  });

  test('a missing platform side falls back to the pdf-package renderer', () async {
    final _Fallback fallback = _Fallback();
    final Uint8List pdf = await PlatformTextPdfRenderer(fallback: fallback).render(pages, testLook());
    expect(String.fromCharCodes(pdf), '%PDF-fallback');
    expect(fallback.calls, 1);
  });
}
