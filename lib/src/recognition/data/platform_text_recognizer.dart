import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/failures.dart';
import '../../core/session/scan_session.dart';
import 'text_recognizer.dart';

/// [TextRecognizer] over the plugin's native channel (research R4).
///
/// iOS answers with Apple Vision when it supports the language and with Tesseract 5
/// otherwise; Android answers with Tesseract (tesseract4android). Both Tesseracts
/// read the bundled tessdata_fast models. The model
/// files are package assets, copied once to app-support storage because Tesseract
/// reads from a path, so a model update is an asset swap (FR-053).
class PlatformTextRecognizer implements TextRecognizer {
  PlatformTextRecognizer({MethodChannel? channel, AssetBundle? bundle})
    : _channel = channel ?? const MethodChannel('qanoniah_doc_scan/recognition'),
      _bundle = bundle ?? rootBundle;

  final MethodChannel _channel;
  final AssetBundle _bundle;
  String? _tessdataDir;

  static const String _assetDir = 'packages/qanoniah_doc_scan/assets/tessdata';

  @override
  Future<Either<RecognitionFailure, RawRecognition>> recognize(
    File image,
    RecognitionLanguage language,
  ) async {
    try {
      final Map<Object?, Object?>? res = await _channel.invokeMapMethod<Object?, Object?>(
        'recognize',
        <String, Object?>{
          'path': image.path,
          'lang': language.name,
          // Android always reads with Tesseract; iOS falls back to it when Vision
          // cannot read the language (iOS 15 to 17 for Arabic).
          'tessdata': await _ensureTessdata(),
        },
      );
      if (res == null) return const Left<RecognitionFailure, RawRecognition>(RecognitionFailure.failed());
      if (res['unsupported'] == true) {
        return const Left<RecognitionFailure, RawRecognition>(RecognitionFailure.engineUnavailable());
      }
      return Right<RecognitionFailure, RawRecognition>(_parse(res));
    } on PlatformException {
      return const Left<RecognitionFailure, RawRecognition>(RecognitionFailure.failed());
    } on MissingPluginException {
      return const Left<RecognitionFailure, RawRecognition>(RecognitionFailure.engineUnavailable());
    }
  }

  Future<String> _ensureTessdata() async {
    final String? known = _tessdataDir;
    if (known != null) return known;
    final Directory dir = Directory('${(await getApplicationSupportDirectory()).path}/qanoniah_doc_scan/tessdata');
    await dir.create(recursive: true);
    for (final String lang in <String>['ara', 'eng']) {
      final File f = File('${dir.path}/$lang.traineddata');
      final ByteData data = await _bundle.load('$_assetDir/$lang.traineddata');
      if (!await f.exists() || await f.length() != data.lengthInBytes) {
        await f.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      }
    }
    // Tesseract wants the parent of `tessdata/`.
    return _tessdataDir = dir.parent.path;
  }

  static RawRecognition _parse(Map<Object?, Object?> res) {
    final List<Object?> blocks = (res['blocks'] as List<Object?>?) ?? const <Object?>[];
    return RawRecognition(
      blocksAreParagraphs: res['paragraphs'] == true,
      blocks: <List<Word>>[
        for (final Object? b in blocks)
          <Word>[
            for (final Object? w in (b as List<Object?>? ?? const <Object?>[]))
              if (w is Map<Object?, Object?>)
                Word(
                  text: (w['text'] as String?) ?? '',
                  box: Rect.fromLTRB(_d(w['l']), _d(w['t']), _d(w['r']), _d(w['b'])),
                  confidence: _d(w['c']),
                ),
          ],
      ],
    );
  }

  static double _d(Object? v) => v is num ? v.toDouble() : 0;
}
