import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../core/failures.dart';
import '../../core/session/scan_session.dart';
import '../../core/session/scan_session_repo.dart';
import 'post_processor.dart';
import 'text_recognizer.dart';

/// How many pages have settled (done, no text, or failed) out of all pages.
@immutable
class RecognitionProgress {
  const RecognitionProgress({required this.settled, required this.total});

  final int settled;
  final int total;

  bool get isComplete => settled >= total;
}

/// Runs recognition for each page in the background, right after capture (FR-010),
/// one page at a time, and writes the result into the session.
///
/// A page that changes (retake, corners, filters) is re-queued; a result for an
/// outdated version of a page is dropped.
class RecognitionRepo {
  RecognitionRepo({
    required TextRecognizer recognizer,
    required ScanSessionRepo sessions,
    PostProcessor postProcessor = const PostProcessor(),
    this.minArabicConfidence = 0.6,
    this.minArabicRatio = 0.4,
  }) : _recognizer = recognizer,
       _sessions = sessions,
       _post = postProcessor;

  final TextRecognizer _recognizer;
  final ScanSessionRepo _sessions;
  final PostProcessor _post;

  /// Below this mean confidence the English pass also runs (research R5).
  final double minArabicConfidence;

  /// Below this share of Arabic letters the English pass also runs (research R5).
  final double minArabicRatio;

  final List<CapturedPage> _queue = <CapturedPage>[];
  final StreamController<RecognitionProgress> _progress =
      StreamController<RecognitionProgress>.broadcast();
  bool _running = false;
  bool _disposed = false;

  Stream<RecognitionProgress> get progress => _progress.stream;

  RecognitionProgress get current {
    final List<CapturedPage> pages = _sessions.session.pages;
    return RecognitionProgress(
      settled: pages.where((CapturedPage p) => p.recognition is! RecognitionPending).length,
      total: pages.length,
    );
  }

  /// Queues [page] (its current files). Replaces any queued older version.
  void enqueue(CapturedPage page) {
    _queue
      ..removeWhere((CapturedPage p) => p.id == page.id)
      ..add(page);
    _emit();
    unawaited(_drain());
  }

  /// Completes when every page in the session has settled.
  Future<RecognitionProgress> whenComplete() async {
    if (current.isComplete) return current;
    return progress.firstWhere((RecognitionProgress p) => p.isComplete);
  }

  void dispose() {
    _disposed = true;
    _queue.clear();
    unawaited(_progress.close());
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    try {
      while (_queue.isNotEmpty && !_disposed) {
        final CapturedPage page = _queue.removeAt(0);
        final RecognitionState state = await _recognize(page);
        if (_disposed) return;
        if (_isCurrent(page)) {
          _sessions.updateRecognition(page.id, state);
          _emit();
        }
      }
    } finally {
      _running = false;
    }
  }

  /// Arabic first; English too when Arabic looks wrong; never both at once (R5).
  Future<RecognitionState> _recognize(CapturedPage page) async {
    final Either<RecognitionFailure, RawRecognition> ar =
        await _recognizer.recognize(page.ocrInputFile, RecognitionLanguage.ar);
    final RawRecognition? arRaw = ar.fold((RecognitionFailure _) => null, (RawRecognition r) => r);

    final bool needEnglish = arRaw == null ||
        PostProcessor.meanConfidence(arRaw) < minArabicConfidence ||
        PostProcessor.arabicRatio(arRaw.blocks.expand((List<Word> l) => l).map((Word w) => w.text)) < minArabicRatio;

    RawRecognition? best = arRaw;
    RecognitionLanguage lang = RecognitionLanguage.ar;
    if (needEnglish) {
      final Either<RecognitionFailure, RawRecognition> en =
          await _recognizer.recognize(page.ocrInputFile, RecognitionLanguage.en);
      final RawRecognition? enRaw = en.fold((RecognitionFailure _) => null, (RawRecognition r) => r);
      if (enRaw != null &&
          (best == null || PostProcessor.meanConfidence(enRaw) > PostProcessor.meanConfidence(best))) {
        best = enRaw;
        lang = RecognitionLanguage.en;
      }
    }
    if (best == null) return const RecognitionState.failed();
    if (PostProcessor.wordCount(best) == 0) return const RecognitionState.noText();
    return RecognitionState.done(_post.process(best, lang));
  }

  bool _isCurrent(CapturedPage page) {
    for (final CapturedPage p in _sessions.session.pages) {
      if (p.id == page.id) return p.ocrInputFile.path == page.ocrInputFile.path;
    }
    return false;
  }

  void _emit() {
    if (!_disposed) _progress.add(current);
  }
}
