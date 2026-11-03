import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/doc_scan_event.dart';
import '../../core/failures.dart';
import '../../core/session/scan_session.dart';
import '../../core/session/scan_session_repo.dart';
import '../../recognition/data/recognition_repo.dart';
import '../data/pdf_builder.dart';
import '../data/size_fitter.dart';

part 'build_cubit.freezed.dart';

/// «تحليل الصور · استخراج النص · إنشاء ملف PDF» (FR-012).
enum BuildStep { analyze, extract, pdf, done }

@freezed
abstract class BuildState with _$BuildState {
  const factory BuildState({
    required BuildStep step,

    /// Progress inside [step], 0 to 1.
    @Default(0) double progress,
    BuildOutput? output,
    BuildFailure? failure,
  }) = _BuildState;
}

/// The three build steps with real progress. Pages were prepared at capture and are
/// recognized in the background, so a step that is already done completes at once.
class BuildCubit extends Cubit<BuildState> {
  BuildCubit({
    required ScanSessionRepo sessions,
    required RecognitionRepo recognition,
    required SizeFitter fitter,
    required PdfLook look,
    required int maxFileBytes,
    required void Function(DocScanEvent) onEvent,
    DateTime Function()? now,
  }) : _sessions = sessions,
       _recognition = recognition,
       _fitter = fitter,
       _look = look,
       _maxFileBytes = maxFileBytes,
       _onEvent = onEvent,
       _now = now ?? DateTime.now,
       super(const BuildState(step: BuildStep.analyze));

  final ScanSessionRepo _sessions;
  final RecognitionRepo _recognition;
  final SizeFitter _fitter;
  final PdfLook _look;
  final int _maxFileBytes;
  final void Function(DocScanEvent) _onEvent;
  final DateTime Function() _now;
  StreamSubscription<RecognitionProgress>? _progress;

  Future<void> start() async {
    final DateTime t0 = _now();
    final List<CapturedPage> pages = _sessions.session.pages;
    _onEvent(DocScanEvent.buildStarted(pageCount: pages.length));
    emit(const BuildState(step: BuildStep.analyze, progress: 1));

    emit(state.copyWith(step: BuildStep.extract, progress: _fraction(_recognition.current)));
    _progress = _recognition.progress.listen((RecognitionProgress p) {
      if (!isClosed && state.step == BuildStep.extract) emit(state.copyWith(progress: _fraction(p)));
    });
    await _recognition.whenComplete();
    await _progress?.cancel();
    if (isClosed) return;

    final List<CapturedPage> settled = _sessions.session.pages;
    for (final CapturedPage p in settled) {
      if (p.recognition is RecognitionNoText) _onEvent(DocScanEvent.pageNoText());
    }
    emit(state.copyWith(step: BuildStep.pdf, progress: 0));
    final Either<BuildFailure, BuildOutput> r = await _fitter.fitImage(
      pages: settled,
      colorMode: ScanColorMode.color,
      look: _look,
      maxBytes: _maxFileBytes,
      newFile: () => _sessions.newFile('pdf'),
    );
    if (isClosed) return;
    r.fold(
      (BuildFailure f) {
        _onEvent(DocScanEvent.buildFailed(f));
        if (f is BuildTooLarge) _onEvent(DocScanEvent.sizeLimitExceeded(sizeBytes: f.sizeBytes));
        emit(state.copyWith(failure: f));
      },
      (BuildOutput o) {
        _onEvent(
          DocScanEvent.buildCompleted(
            pageCount: settled.length,
            durationMs: _now().difference(t0).inMilliseconds,
            languages: _languages(settled),
          ),
        );
        emit(BuildState(step: BuildStep.done, progress: 1, output: o));
      },
    );
  }

  /// Retries after a failure, e.g. once the user freed space.
  Future<void> retry() {
    emit(const BuildState(step: BuildStep.analyze));
    return start();
  }

  void cancelled() => _onEvent(DocScanEvent.cancelled(step: ScanStep.build));

  static double _fraction(RecognitionProgress p) => p.total == 0 ? 1 : p.settled / p.total;

  static DocumentLanguages _languages(List<CapturedPage> pages) {
    final Set<RecognitionLanguage> langs = <RecognitionLanguage>{
      for (final CapturedPage p in pages)
        if (p.recognition case RecognitionDone(:final PageText text)) text.language,
    };
    if (langs.length > 1) return DocumentLanguages.mixed;
    return langs.contains(RecognitionLanguage.en) ? DocumentLanguages.en : DocumentLanguages.ar;
  }

  @override
  Future<void> close() async {
    await _progress?.cancel();
    return super.close();
  }
}
