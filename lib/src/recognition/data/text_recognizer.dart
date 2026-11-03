import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../core/failures.dart';
import '../../core/session/scan_session.dart';

/// What an engine returns, before post-processing (research R6).
@immutable
class RawRecognition {
  const RawRecognition({required this.blocks, required this.blocksAreParagraphs});

  /// Lines, or paragraphs when the engine groups them itself. Words are in the
  /// engine's own order, with boxes in image pixels.
  final List<List<Word>> blocks;

  /// True when [blocks] are already paragraphs, so grouping is skipped.
  final bool blocksAreParagraphs;
}

/// The recognition engine, behind the one port the brief allows (FR-051, P5).
/// Implementations: Apple Vision and Tesseract (research R4).
abstract interface class TextRecognizer {
  /// Recognizes [image] in exactly one [language] (FR-062: never combined).
  Future<Either<RecognitionFailure, RawRecognition>> recognize(
    File image,
    RecognitionLanguage language,
  );
}
