import 'dart:convert';
import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:dartz/dartz.dart' show Either;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qanoniah_doc_scan/src/core/failures.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/platform_text_recognizer.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/text_recognizer.dart';

/// Recognizes the page image in `--dart-define=PAGE=path` with the platform engine and
/// writes the raw words to `--dart-define=OUT=path` as JSON: a fixture for tuning the
/// layout on the host, without a device in the loop.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dump raw recognition', (WidgetTester t) async {
    await t.runAsync(() async {
      const String page = String.fromEnvironment('PAGE');
      const String out = String.fromEnvironment('OUT');
      final Stopwatch sw = Stopwatch()..start();
      final Either<RecognitionFailure, RawRecognition> raw =
          await PlatformTextRecognizer().recognize(File(page), RecognitionLanguage.ar);
      final RawRecognition r = raw.fold((RecognitionFailure f) => throw StateError('$f'), (RawRecognition r) => r);
      File(out).writeAsStringSync(
        const JsonEncoder.withIndent(' ').convert(<String, Object?>{
          'width': r.width,
          'height': r.height,
          'ms': sw.elapsedMilliseconds,
          'blocks': <Object>[
            for (final List<Word> l in r.blocks)
              <Object>[
                for (final Word w in l)
                  <String, Object>{
                    't': w.text,
                    'l': w.box.left,
                    'tp': w.box.top,
                    'r': w.box.right,
                    'b': w.box.bottom,
                    'c': w.confidence,
                  },
              ],
          ],
        }),
      );
      // ignore: avoid_print
      print('[DUMP] ${r.blocks.length} lines in ${sw.elapsedMilliseconds} ms');
    });
  });
}
