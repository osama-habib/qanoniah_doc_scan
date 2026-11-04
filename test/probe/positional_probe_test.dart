// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/src/document/data/page_background.dart';
import 'package:qanoniah_doc_scan/src/document/presentation/positional_sheet.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/post_processor.dart';
import 'package:qanoniah_doc_scan/src/core/session/word_placement.dart';
import 'package:image/image.dart' as img;
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/ink_refiner.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/text_recognizer.dart';

/// Host probe for the positional page: PROBE_JSON (an ocr_dump_test dump), PROBE_OCR
/// (the image it read), PROBE_OUT (a folder). Skips without them.
final Map<String, String> env = Platform.environment;

RawRecognition loadRaw(String path) {
  final Map<String, dynamic> d = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return RawRecognition(
    blocksAreParagraphs: false,
    width: (d['width'] as num).toDouble(),
    height: (d['height'] as num).toDouble(),
    blocks: <List<Word>>[
      for (final dynamic l in d['blocks'] as List<dynamic>)
        <Word>[
          for (final dynamic w in l as List<dynamic>)
            Word(
              text: w['t'] as String,
              box: Rect.fromLTRB(
                (w['l'] as num).toDouble(),
                (w['tp'] as num).toDouble(),
                (w['r'] as num).toDouble(),
                (w['b'] as num).toDouble(),
              ),
              confidence: (w['c'] as num).toDouble(),
            ),
        ],
    ],
  );
}

void main() {
  final bool skip = env['PROBE_JSON'] == null;
  test('refine', () {
    final RawRecognition raw = loadRaw(env['PROBE_JSON']!);
    final img.Image im = img.decodeImage(File(env['PROBE_OCR']!).readAsBytesSync())!;
    final Uint8List gray = InkRefiner.grayOf(im);
    final Stopwatch sw = Stopwatch()..start();
    final RawRecognition r = const InkRefiner().refine(raw, gray, im.width, im.height);
    print('[PR] refine ${sw.elapsedMilliseconds} ms, ${raw.blocks.length} -> ${r.blocks.length} lines');
    for (final List<Word> l in r.blocks) {
      print(
        '[PR] size ${l.first.size.toStringAsFixed(1)} base ${l.first.baseline.toStringAsFixed(0)} | '
        '${l.map((Word w) => '${w.text}${w.bold ? '*' : ''}[${w.box.top.round()}-${w.box.bottom.round()}]').join(' ')}',
      );
    }
  }, skip: skip);

  testWidgets('render', (WidgetTester t) async {
    final String out = env['PROBE_OUT']!;
    Directory(out).createSync(recursive: true);
    late PageText text;
    late File bg;
    await t.runAsync(() async {
      for (final (String fam, List<String> files) in <(String, List<String>)>[
        ('NotoSansArabic', <String>['NotoSansArabic-Regular.ttf', 'NotoSansArabic-SemiBold.ttf']),
        ('NotoSans', <String>['NotoSans-Regular.ttf']),
      ]) {
        final FontLoader l = FontLoader(fam);
        for (final String f in files) {
          l.addFont(Future<ByteData>.value(ByteData.sublistView(File('example/assets/fonts/$f').readAsBytesSync())));
        }
        await l.load();
      }
      final RawRecognition raw = loadRaw(env['PROBE_JSON']!);
      final img.Image im = img.decodeImage(File(env['PROBE_OCR']!).readAsBytesSync())!;
      final RawRecognition r = const InkRefiner().refine(raw, InkRefiner.grayOf(im), im.width, im.height);
      text = const PostProcessor().process(r, RecognitionLanguage.ar);
      final List<Word> all = text.paragraphs.expand((Paragraph p) => p.words).toList();
      final Stopwatch sw = Stopwatch()..start();
      bg = (await PageBackground.write(
        prepared: File(env['PROBE_PREP'] ?? env['PROBE_OCR']!),
        ocr: File(env['PROBE_OCR']!),
        erase: <Rect>[
          for (final Word w in all)
            if (w.drawable) w.box,
        ],
        lineHeight: (all.map((Word w) => w.em).toList()..sort())[all.length ~/ 2] * 1.3,
        out: File('$out/background.png'),
      )).file;
      print('[PR] background ${sw.elapsedMilliseconds} ms ${bg.lengthSync() ~/ 1024} KB');
    });
    final GlobalKey key = GlobalKey();
    final ImageProvider bgImage = MemoryImage(bg.readAsBytesSync());
    await t.binding.setSurfaceSize(Size(text.width, text.height));
    t.view.physicalSize = Size(text.width, text.height);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          child: RepaintBoundary(
            key: key,
            child: PositionalSheet(
              text: text,
              background: env['PROBE_NOBG'] == null ? bgImage : null,
              style: const TextStyle(
                fontFamily: 'NotoSansArabic',
                fontFamilyFallback: <String>['NotoSans'],
                color: Color(0xff111111),
              ),
              paper: const Color(0xffffffff),
              selection: const Color(0x55448aff),
              redaction: const Color(0xff222222),
            ),
          ),
        ),
      ),
    );
    await t.runAsync(() => precacheImage(bgImage, key.currentContext!));
    await t.pump();
    final RenderRepaintBoundary b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image shot = await b.toImage();
    final ByteData? png = await t.runAsync<ByteData?>(() => shot.toByteData(format: ui.ImageByteFormat.png));
    File('$out/positional.png').writeAsBytesSync(png!.buffer.asUint8List());
    print('[PR] rendered ${shot.width}x${shot.height}');
  }, skip: skip);
}
