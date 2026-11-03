import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/doc_scan_icons.dart';
import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/presentation/scan_widgets.dart';
import '../../core/session/scan_session.dart';
import '../manager/capture_cubit.dart';
import 'camera_permission_view.dart';
import 'capture_feedback.dart';
import 'edge_frame_overlay.dart';

/// The dark camera sheet (story 2). Reads [CaptureCubit]; holds no logic.
class CameraSheet extends StatefulWidget {
  const CameraSheet({
    super.key,
    required this.strings,
    required this.preview,
    required this.onCancel,
    required this.onReview,
  });

  final DocScanStrings strings;

  /// The camera's live preview, from the camera source.
  final Widget Function() preview;
  final VoidCallback onCancel;

  /// «مراجعة الصفحات»; also where the flow goes after a retake.
  final VoidCallback onReview;

  @override
  State<CameraSheet> createState() => _CameraSheetState();
}

class _CameraSheetState extends State<CameraSheet> with WidgetsBindingObserver {
  double _drag = 0;
  bool _toast = false;
  Timer? _toastTimer;
  bool? _lastDetected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CaptureCubit cubit = context.read<CaptureCubit>();
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      unawaited(cubit.pauseCamera());
    } else if (state == AppLifecycleState.resumed) {
      final CapturePhase phase = cubit.state.phase;
      unawaited(phase == CapturePhase.ready ? cubit.resumeCamera() : cubit.recheckPermission());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _toastTimer?.cancel();
    super.dispose();
  }

  void _onState(BuildContext context, CaptureState s) {
    if (s.replaced) return widget.onReview();
    final bool announce = MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
    final TextDirection dir = Directionality.of(context);
    final bool detected = s.quad != null;
    if (announce && detected != _lastDetected && detected) {
      // sendAnnouncement needs Flutter 3.36+; the host pins 3.35 (research R1).
      // ignore: deprecated_member_use
      unawaited(SemanticsService.announce(widget.strings.announcePageDetected, dir));
    }
    _lastDetected = detected;
  }

  void _onShot(BuildContext context, CaptureState s) {
    if (MediaQuery.maybeOf(context)?.accessibleNavigation ?? false) {
      // ignore: deprecated_member_use
      unawaited(SemanticsService.announce(widget.strings.announcePageCaptured(s.pageCount), Directionality.of(context)));
    }
    setState(() => _toast = true);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _toast = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final DocScanStrings s = widget.strings;
    return MultiBlocListener(
      listeners: <BlocListener<CaptureCubit, CaptureState>>[
        BlocListener<CaptureCubit, CaptureState>(
          listenWhen: (CaptureState a, CaptureState b) => a.quad != b.quad || a.replaced != b.replaced,
          listener: _onState,
        ),
        BlocListener<CaptureCubit, CaptureState>(
          listenWhen: (CaptureState a, CaptureState b) => a.shots != b.shots,
          listener: _onShot,
        ),
      ],
      child: Transform.translate(
        offset: Offset(0, _drag),
        child: Container(
          decoration: BoxDecoration(
            color: t.cameraSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusSheet)),
          ),
          child: SafeArea(
            child: BlocBuilder<CaptureCubit, CaptureState>(
              builder: (BuildContext context, CaptureState st) {
                final CaptureCubit cubit = context.read<CaptureCubit>();
                return Column(
                  children: <Widget>[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (DragUpdateDetails d) =>
                          setState(() => _drag = (_drag + d.delta.dy).clamp(0, double.infinity)),
                      onVerticalDragEnd: (DragEndDetails d) {
                        if (_drag > t.thumbnailSize * 2 || (d.primaryVelocity ?? 0) > 900) {
                          widget.onCancel();
                        } else {
                          setState(() => _drag = 0);
                        }
                      },
                      child: Column(
                        children: <Widget>[
                          ScanSheetHandle(color: t.onCameraSurfaceMuted),
                          ScanHeader(
                            title: s.scanTitle,
                            color: t.onCameraSurface,
                            leading: ScanQuietButton(label: s.cancel, onPressed: widget.onCancel, color: t.onCameraSurface),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: st.phase == CapturePhase.ready
                          ? _Viewfinder(state: st, preview: widget.preview, toast: _toast, strings: s)
                          : CameraPermissionView(
                              phase: st.phase,
                              strings: s,
                              onRetry: cubit.recheckPermission,
                              onOpenSettings: cubit.openSettings,
                            ),
                    ),
                    _BottomBar(state: st, strings: s, onReview: widget.onReview),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.state, required this.preview, required this.toast, required this.strings});

  final CaptureState state;
  final Widget Function() preview;
  final bool toast;
  final DocScanStrings strings;

  String _hint() => switch (state.hint) {
    CaptureHint.auto => strings.hintAuto,
    CaptureHint.manual => strings.hintManual,
    CaptureHint.nextPage => strings.hintNextPage,
    CaptureHint.lowLight => strings.hintLowLight,
    CaptureHint.holdSteady => strings.hintHoldSteady,
  };

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final String? message = state.limitReached
        ? strings.pageLimitReached(state.pageCount)
        : (state.storageFull ? strings.storageFull : null);
    return Column(
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: t.spaceMd),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(t.radiusLg),
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    preview(),
                    Positioned.fill(
                      child: EdgeFrameOverlay(
                        quad: state.quad,
                        color: state.quad == null ? t.frameSearching : t.frameDetected,
                        strokeWidth: t.frameStrokeWidth,
                        fill: t.frameDetected.withValues(alpha: 0.12),
                      ),
                    ),
                    Positioned.fill(child: CaptureFlash(shots: state.shots, color: t.captureFlash)),
                    PositionedDirectional(
                      top: t.spaceMd,
                      start: t.spaceMd,
                      end: t.spaceMd,
                      child: AnimatedOpacity(
                        opacity: toast ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: t.spaceMd, vertical: t.spaceXs),
                            decoration: BoxDecoration(color: t.scrim, borderRadius: BorderRadius.circular(t.radiusLg)),
                            child: Text(strings.pageCaptured, style: t.captionStyle.copyWith(color: t.onCameraSurface)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(t.spaceMd),
          child: Semantics(
            liveRegion: true,
            child: Text(
              message ?? _hint(),
              style: t.bodyStyle.copyWith(color: message == null ? t.onCameraSurface : t.danger),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state, required this.strings, required this.onReview});

  final CaptureState state;
  final DocScanStrings strings;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final CaptureCubit cubit = context.read<CaptureCubit>();
    final bool ready = state.phase == CapturePhase.ready;
    return Padding(
      padding: EdgeInsets.fromLTRB(t.spaceLg, t.spaceSm, t.spaceLg, t.spaceLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (ready)
            ScanSegmented<CaptureMode>(
              options: <CaptureMode, String>{CaptureMode.auto: strings.modeAuto, CaptureMode.manual: strings.modeManual},
              selected: state.mode,
              onChanged: cubit.setMode,
              foreground: t.onCameraSurfaceMuted,
              selectedForeground: t.cameraSurface,
              selectedBackground: t.onCameraSurface,
              background: t.scrim,
            ),
          SizedBox(height: t.spaceMd),
          Row(
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PageThumbnailBadge(
                    file: state.lastThumbnail,
                    count: state.pageCount,
                    shots: state.shots,
                    label: strings.reviewPages,
                    onTap: state.pageCount > 0 ? onReview : null,
                  ),
                ),
              ),
              _Shutter(
                label: strings.capture,
                enabled: ready && !state.capturing && !state.limitReached,
                onTap: cubit.capture,
              ),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: state.pageCount > 0
                      ? ScanQuietButton(label: strings.reviewPages, onPressed: onReview, color: t.onCameraSurface)
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final double size = t.thumbnailSize * 1.2;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(t.spaceXs),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: t.onCameraSurface, width: t.frameStrokeWidth),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? t.onCameraSurface : t.onCameraSurfaceMuted,
            ),
            child: Center(child: DocScanIcon(t.icons.capture, size: t.iconSize, color: t.cameraSurface)),
          ),
        ),
      ),
    );
  }
}
