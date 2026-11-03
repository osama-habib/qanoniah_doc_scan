import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:qanoniah_doc_scan/src/core/failures.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/text_recognizer.dart';

/// Returns scripted results keyed by image path and language; records every call.
class FakeTextRecognizer implements TextRecognizer {
  final Map<(String, RecognitionLanguage), Either<RecognitionFailure, RawRecognition>>
      results =
      <(String, RecognitionLanguage), Either<RecognitionFailure, RawRecognition>>{};
  final List<(String, RecognitionLanguage)> calls = <(String, RecognitionLanguage)>[];

  void stub(File image, RecognitionLanguage lang, RawRecognition result) =>
      results[(image.path, lang)] = Right<RecognitionFailure, RawRecognition>(result);

  @override
  Future<Either<RecognitionFailure, RawRecognition>> recognize(
    File image,
    RecognitionLanguage language,
  ) async {
    calls.add((image.path, language));
    return results[(image.path, language)] ??
        const Right<RecognitionFailure, RawRecognition>(
          RawRecognition(blocks: <List<Word>>[], blocksAreParagraphs: false),
        );
  }
}
