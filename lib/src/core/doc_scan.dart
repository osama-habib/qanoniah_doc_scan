import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../capture/data/camera_source.dart';
import '../capture/data/edge_detector.dart';
import '../capture/data/permission_repo.dart';
import '../capture/manager/capture_cubit.dart';
import '../capture/presentation/camera_sheet.dart';
import '../document/data/pdf_builder.dart';
import '../document/data/size_fitter.dart';
import '../document/data/text_pdf_renderer.dart';
import '../document/manager/build_cubit.dart';
import '../document/manager/preview_cubit.dart';
import '../document/presentation/build_screen.dart';
import '../document/presentation/preview_screen.dart';
import '../page_prep/data/page_preparer.dart';
import '../recognition/data/platform_text_recognizer.dart';
import '../recognition/data/recognition_repo.dart';
import '../recognition/data/text_recognizer.dart';
import '../review/manager/review_cubit.dart';
import '../review/presentation/filters_screen.dart';
import '../review/presentation/review_screen.dart';
import 'presentation/scan_confirm.dart';
import 'presentation/scan_sheet.dart';
import 'doc_scan_config.dart';
import 'doc_scan_event.dart';
import 'doc_scan_result.dart';
import 'doc_scan_strings.dart';
import 'doc_scan_theme.dart';
import 'failures.dart';
import 'session/scan_session.dart';
import 'session/scan_session_repo.dart';

/// Entry point (FR-030, contracts/public-api.md).
abstract final class DocScan {
  static bool _running = false;

  /// Test-only replacement for the platform ports.
  @visibleForTesting
  static ScanFlowDeps Function()? debugDeps;

  /// Runs the whole journey and returns one PDF, or null when the user cancels
  /// (FR-021, FR-031).
  ///
  /// Throws [StateError] when a scan is already running or when the host did not add
  /// [DocScanTheme] to its theme.
  static Future<DocScanResult?> start(BuildContext context, DocScanConfig config) async {
    if (_running) throw StateError('A document scan is already running.');
    DocScanTheme.of(context);
    final DocScanStrings strings =
        config.strings ??
        (Localizations.localeOf(context).languageCode == 'ar' ? DocScanStrings.ar() : DocScanStrings.en());
    _running = true;
    config.onEvent?.call(DocScanEvent.started());
    try {
      return await Navigator.of(context, rootNavigator: true).push<DocScanResult>(
        // Design `qn-scan-in`: the sheet slides up over 420 ms.
        // Not opaque: the screen the scan was opened from stays painted under
        // the sheet, so a pull down shows it (owner, 2026-11-10). The sheet
        // slides and the dim fades in ScanSheet, from this route's animation.
        PageRouteBuilder<DocScanResult>(
          opaque: false,
          fullscreenDialog: true,
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (BuildContext _, Animation<double> _, Animation<double> _) =>
              DocScanFlow(config: config, strings: strings, deps: (debugDeps ?? ScanFlowDeps.platform)()),
          transitionsBuilder: (BuildContext _, Animation<double> _, Animation<double> _, Widget child) => child,
        ),
      );
    } finally {
      _running = false;
    }
  }
}

/// The flow's composition root: one place that creates the ports and repos
/// (constitution P8, research R9).
class ScanFlowDeps {
  ScanFlowDeps({
    required this.sessions,
    required this.recognizer,
    required this.newCamera,
    required this.newEdgeDetector,
    required this.permissions,
    required this.preparer,
    this.builder = const PdfBuilder(),
  });

  factory ScanFlowDeps.platform() => ScanFlowDeps(
    sessions: ScanSessionRepo(),
    recognizer: PlatformTextRecognizer(),
    newCamera: CameraPluginSource.new,
    newEdgeDetector: () => Platform.isIOS ? VisionEdgeDetector() : DartEdgeDetector(),
    permissions: const PermissionRepo(),
    preparer: const PagePreparer(),
    builder: PdfBuilder(textRenderer: PlatformTextPdfRenderer(fallback: const PdfPackageTextRenderer())),
  );

  final ScanSessionRepo sessions;
  final TextRecognizer recognizer;

  /// A fresh camera per camera visit; the capture cubit disposes it.
  final CameraSource Function() newCamera;
  final EdgeDetector Function() newEdgeDetector;
  final PermissionRepo permissions;
  final PagePreparer preparer;
  final PdfBuilder builder;
}

enum _Step { starting, camera, filters, review, build, preview, failed }

/// Hosts the steps capture → review → build → preview and owns the session.
class DocScanFlow extends StatefulWidget {
  const DocScanFlow({super.key, required this.config, required this.strings, required this.deps});

  final DocScanConfig config;
  final DocScanStrings strings;
  final ScanFlowDeps deps;

  @override
  State<DocScanFlow> createState() => _DocScanFlowState();
}

class _DocScanFlowState extends State<DocScanFlow> {
  _Step _step = _Step.starting;
  late final RecognitionRepo _recognition;
  late final SizeFitter _fitter = SizeFitter(builder: widget.deps.builder);

  /// Bumped per camera visit so each visit gets a new cubit and camera.
  int _visit = 0;

  /// Set while the camera replaces a page (retake).
  String? _replacing;

  /// True while the camera was opened from review («إضافة صفحة»), so returning to
  /// review can report the added pages.
  bool _fromReview = false;
  int _pagesBeforeVisit = 0;

  /// The page «توضيح الصفحات» opens on.
  int _filterIndex = 0;

  /// «إرفاق كملف PDF» from review: build from the photos without waiting for
  /// text, and open the preview on the photos.
  bool _imagesOnly = false;

  /// The camera of the current visit; its capture cubit disposes it.
  CameraSource? _camera;

  /// The flash the user chose, kept between camera visits.
  ScanFlash _flash = ScanFlash.off;
  BuildOutput? _built;
  PreviewCubit? _preview;
  bool _closing = false;

  ScanSessionRepo get _sessions => widget.deps.sessions;

  /// Events raised while a screen builds (a cubit created by its provider) reach
  /// the host after the frame: a host that calls setState in onEvent would
  /// otherwise mark itself dirty mid-build.
  void _emit(DocScanEvent e) {
    final void Function(DocScanEvent)? onEvent = widget.config.onEvent;
    if (onEvent == null) return;
    final SchedulerBinding binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((Duration _) => onEvent(e));
    } else {
      onEvent(e);
    }
  }

  @override
  void initState() {
    super.initState();
    _recognition = RecognitionRepo(
      recognizer: widget.deps.recognizer,
      sessions: _sessions,
      enabled: widget.config.recognizeText,
    );
    unawaited(_begin());
  }

  Future<void> _begin() async {
    final Either<StorageFailure, ScanSession> r = await _sessions.start(maxPages: widget.config.maxPages);
    if (!mounted) return;
    setState(() {
      _camera = widget.deps.newCamera();
      _step = r.isRight() ? _Step.camera : _Step.failed;
    });
  }

  PdfLook _look(DocScanTheme t) => PdfLook(
    font: widget.config.pdfFont,
    fontFallback: widget.config.pdfFontFallback,
    fontBold: widget.config.pdfFontBold,
    text: t.onSurface.toARGB32(),
    redactionFill: t.redactionFill.toARGB32(),
    onRedactionFill: t.onRedactionFill.toARGB32(),
    redactedLabel: widget.strings.redactedText,
  );

  String get _defaultStem => '${widget.strings.defaultFileStem}-${widget.config.fileNumber.toString().padLeft(2, '0')}';

  void _openCamera({String? replacing}) => setState(() {
    _fromReview = _step == _Step.review || _step == _Step.filters;
    _pagesBeforeVisit = _sessions.session.pages.length;
    _replacing = replacing;
    _camera = widget.deps.newCamera();
    _visit++;
    _step = _Step.camera;
  });

  void _openReview() => setState(() {
    _replacing = null;
    _step = _Step.review;
  });

  /// «توضيح الصفحات» on [index], or on the last page.
  void _openFilters([int? index]) => setState(() {
    final int n = _sessions.session.pages.length;
    _filterIndex = (index ?? n - 1).clamp(0, n == 0 ? 0 : n - 1);
    _replacing = null;
    _step = _Step.filters;
  });

  void _openBuild({required bool imagesOnly}) => setState(() {
    // Without text recognition there is only the photo PDF.
    _imagesOnly = imagesOnly || !widget.config.recognizeText;
    _step = _Step.build;
  });

  // TODO(unused): «إلغاء» and the pull-down close the scan from every step now
  // (pk2, `_requestClose`); kept for a back that returns to review instead.
  // ignore: unused_element
  void _cameraCancelled() {
    if (_sessions.session.pages.isNotEmpty) return _openReview();
    _cancel(ScanStep.capture);
  }

  /// «إلغاء» or the pull-down, on any step (pk2): closes the scan without
  /// attaching anything. Captured pages are never dropped by accident: with
  /// pages, «تجاهل المسح؟» asks first (owner rule of 2026-11-03).
  Future<void> _requestClose() async {
    if (_closing) return;
    if (_sessions.session.pages.isEmpty) return _cancel(_scanStep);
    final DocScanStrings s = widget.strings;
    final bool discard = await showScanConfirm(
      context,
      title: s.discardTitle,
      body: s.discardBody,
      confirm: s.discardConfirm,
      cancel: s.discardKeep,
    );
    if (discard && mounted) await _cancel(_scanStep);
  }

  /// The preview's back (design `scanPdfBack`): review again; a later build
  /// makes a new preview.
  void _previewBack() {
    unawaited(_preview?.close());
    _preview = null;
    _openReview();
  }

  Future<void> _cancel(ScanStep step) async {
    if (_closing) return;
    _closing = true;
    _emit(DocScanEvent.cancelled(step: step));
    _recognition.dispose();
    await _sessions.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _attach() async {
    final PreviewCubit? cubit = _preview;
    if (cubit == null || _closing) return;
    final Either<BuildFailure, BuildOutput> r = await cubit.attach();
    final BuildOutput? out = r.fold((BuildFailure _) => null, (BuildOutput o) => o);
    if (out == null || !mounted) return;
    _closing = true;
    final PreviewState st = cubit.state;
    final List<CapturedPage> pages = _sessions.session.pages;
    final List<String> texts = pages.map(st.edits.finalText).toList();
    final DateTime startedAt = _sessions.session.startedAt;
    final Either<StorageFailure, File> moved = await _sessions.finish(out.file);
    _recognition.dispose();
    if (!mounted) return;
    moved.fold((StorageFailure _) => Navigator.of(context).pop(), (File file) {
      _emit(
        DocScanEvent.attached(
          pageCount: pages.length,
          form: out.form,
          redactionCount: st.edits.redactionCount,
          editedParagraphCount: st.edits.editedParagraphCount,
          sizeBytes: out.sizeBytes,
          compressed: out.compressed,
          durationMs: DateTime.now().difference(startedAt).inMilliseconds,
        ),
      );
      Navigator.of(context).pop(
        DocScanResult(
          pdf: file,
          fileName: '${st.fileStem}.pdf',
          form: out.form,
          pageCount: pages.length,
          sizeBytes: out.sizeBytes,
          pageTexts: texts,
        ),
      );
    });
  }

  ScanStep get _scanStep => switch (_step) {
    _Step.starting || _Step.camera || _Step.failed => ScanStep.capture,
    _Step.filters || _Step.review => ScanStep.review,
    _Step.build => ScanStep.build,
    _Step.preview => ScanStep.preview,
  };

  @override
  void dispose() {
    unawaited(_preview?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final DocScanStrings s = widget.strings;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) return;
        unawaited(_requestClose());
      },
      child: Scaffold(
        backgroundColor: t.scrim.withValues(alpha: 0),
        body: ScanSheet(
          color: _step == _Step.camera || _step == _Step.filters ? t.cameraSurface : t.surface,
          handleColor: _step == _Step.camera || _step == _Step.filters
              ? t.onCameraSurface.withValues(alpha: 0.45)
              : t.border,
          onDismiss: _requestClose,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(key: ValueKey<Object>('$_step/$_visit'), child: _body(t, s)),
          ),
        ),
      ),
    );
  }

  Widget _body(DocScanTheme t, DocScanStrings s) {
    switch (_step) {
      case _Step.starting:
        return Center(child: CircularProgressIndicator(color: t.primary));
      case _Step.failed:
        return Center(
          child: Padding(
            padding: EdgeInsets.all(t.spaceXl),
            child: Text(
              s.storageFull,
              style: t.bodyStyle.copyWith(color: t.danger),
              textAlign: TextAlign.center,
            ),
          ),
        );
      case _Step.camera:
        final CameraSource camera = _camera!;
        return BlocProvider<CaptureCubit>(
          create: (BuildContext _) => CaptureCubit(
            camera: camera,
            edges: widget.deps.newEdgeDetector(),
            permissions: widget.deps.permissions,
            preparer: widget.deps.preparer,
            sessions: _sessions,
            recognition: _recognition,
            onEvent: _emit,
            replacePageId: _replacing,
            initialFlash: _flash,
            onFlashChanged: (ScanFlash f) => _flash = f,
          )..start(),
          child: CameraSheet(
            strings: s,
            preview: camera.preview,
            onCancel: _requestClose,
            // The camera always hands over to «توضيح الصفحات» (design).
            onReview: () {
              final bool added = _fromReview && _sessions.session.pages.length > _pagesBeforeVisit;
              final String? replaced = _replacing;
              final int index = replaced == null
                  ? _sessions.session.pages.length - 1
                  : _sessions.session.pages.indexWhere((CapturedPage p) => p.id == replaced);
              _openFilters(index);
              if (added) _emit(DocScanEvent.pageAdded(pageCount: _sessions.session.pages.length));
            },
          ),
        );
      case _Step.filters:
        return BlocProvider<ReviewCubit>(
          create: (BuildContext _) => ReviewCubit(
            sessions: _sessions,
            preparer: widget.deps.preparer,
            recognition: _recognition,
            onEvent: _emit,
            announce: false,
          ),
          child: FiltersScreen(strings: s, initialIndex: _filterIndex, onBack: _openCamera, onNext: _openReview),
        );
      case _Step.review:
        return BlocProvider<ReviewCubit>(
          create: (BuildContext _) => ReviewCubit(
            sessions: _sessions,
            preparer: widget.deps.preparer,
            recognition: _recognition,
            onEvent: _emit,
          ),
          child: ReviewScreen(
            strings: s,
            onBack: _openFilters,
            onCancel: _requestClose,
            onAddPage: _openCamera,
            onRetakeLast: (String id) => _openCamera(replacing: id),
            onOpenFilters: _openFilters,
            onBuild: widget.config.recognizeText ? () => _openBuild(imagesOnly: false) : null,
            onAttachImages: () => _openBuild(imagesOnly: true),
            onEmpty: _openCamera,
          ),
        );
      case _Step.build:
        return BlocProvider<BuildCubit>(
          create: (BuildContext _) => BuildCubit(
            sessions: _sessions,
            recognition: _recognition,
            fitter: _fitter,
            look: _look(t),
            maxFileBytes: widget.config.maxFileBytes,
            onEvent: _emit,
            waitForText: !_imagesOnly,
          )..start(),
          child: BlocListener<BuildCubit, BuildState>(
            listenWhen: (BuildState a, BuildState b) => b.output != null && a.output == null,
            listener: (BuildContext _, BuildState st) => setState(() {
              _built = st.output;
              _step = _Step.preview;
            }),
            child: BuildScreen(strings: s, onCancel: _requestClose),
          ),
        );
      case _Step.preview:
        final PreviewCubit cubit = _preview ??= PreviewCubit(
          sessions: _sessions,
          built: _built!,
          fitter: _fitter,
          builder: widget.deps.builder,
          look: _look(t),
          maxFileBytes: widget.config.maxFileBytes,
          defaultStem: _defaultStem,
          onEvent: _emit,
          initialView: _imagesOnly ? PreviewView.photo : PreviewView.text,
        );
        return BlocProvider<PreviewCubit>.value(
          value: cubit,
          child: PreviewScreen(strings: s, onBack: _previewBack, onAttach: _attach),
        );
    }
  }
}
