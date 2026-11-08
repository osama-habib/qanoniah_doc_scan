import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/scan_metrics.dart';
import '../../core/doc_scan_icons.dart';
import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/presentation/scan_widgets.dart';
import '../../core/session/scan_session.dart';
import '../data/camera_source.dart';
import '../manager/capture_cubit.dart';
import 'camera_permission_view.dart';
import 'capture_feedback.dart';
import 'corner_editor.dart';
import 'straighten_animation.dart';
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

class _CameraSheetState extends State<CameraSheet> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool? _lastDetected;

  // The shot flying from the viewfinder into the page stack (design `qn-scan-shot`:
  // 500 ms, cubic 0.4 0 0.2 1, down to 18% and 20% opacity).
  late final AnimationController _fly;
  final GlobalKey _sheetKey = GlobalKey();
  final GlobalKey _viewKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  File? _flying;
  Rect? _flyFrom;
  Rect? _flyTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fly = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..addStatusListener((AnimationStatus s) {
        if (s == AnimationStatus.completed && mounted) setState(() => _flying = null);
      });
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
    _fly.dispose();
    super.dispose();
  }

  Rect? _rectOf(GlobalKey k) {
    final RenderObject? box = k.currentContext?.findRenderObject();
    final RenderObject? root = _sheetKey.currentContext?.findRenderObject();
    if (box is! RenderBox || root is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero, ancestor: root) & box.size;
  }

  void _onStored(BuildContext context, CaptureState s) {
    final File? f = s.lastThumbnail;
    final Rect? view = _rectOf(_viewKey);
    if (f == null || view == null) return;
    // Starts where the design's shot card sits: 64% wide, 16% from the top.
    final double w = view.width * 0.64;
    final Rect from = Rect.fromLTWH(view.center.dx - w / 2, view.top + view.height * 0.16, w, w * 1.414);
    final Rect to = _rectOf(_stackKey) ?? Rect.fromCenter(center: view.bottomLeft, width: 46, height: 60);
    setState(() {
      _flying = f;
      _flyFrom = from;
      _flyTo = to;
    });
    _fly.forward(from: 0);
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
      unawaited(
        // ignore: deprecated_member_use
        SemanticsService.announce(widget.strings.announcePageCaptured(s.pageCount), Directionality.of(context)),
      );
    }
  }

  /// The corners being dragged on the corner step; null until the user drags.
  Quad? _adjusted;

  /// The page straightening on screen, until its animation ends.
  (File, Quad, int, int)? _straightening;

  void _keep(CaptureCubit cubit) {
    final Quad? q = _adjusted ?? cubit.state.adjustQuad;
    setState(() => _adjusted = null);
    if (q != null) unawaited(cubit.keepAdjusted(q));
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
        BlocListener<CaptureCubit, CaptureState>(
          listenWhen: (CaptureState a, CaptureState b) => b.straightens != a.straightens && b.straightenFile != null,
          listener: (BuildContext _, CaptureState st) => setState(
            () => _straightening = (
              st.straightenFile!,
              st.straightenQuad ?? Quad.fullFrame,
              st.straightenTurns,
              st.straightens,
            ),
          ),
        ),
        BlocListener<CaptureCubit, CaptureState>(
          listenWhen: (CaptureState a, CaptureState b) => b.pageCount > a.pageCount || (b.replaced && !a.replaced),
          listener: _onStored,
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: t.cameraSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusSheet)),
        ),
        child: Stack(
          key: _sheetKey,
          children: <Widget>[
            SafeArea(
              child: BlocBuilder<CaptureCubit, CaptureState>(
                // Live corners repaint only the overlay, not the sheet.
                buildWhen: (CaptureState a, CaptureState b) => a.copyWith(quad: b.quad, hint: b.hint) != b,
                builder: (BuildContext context, CaptureState st) {
                  final CaptureCubit cubit = context.read<CaptureCubit>();
                  return Column(
                    children: <Widget>[
                      // Design `scanFind` header; the sheet's grabber and pull-down
                      // are the flow's (ScanSheet).
                      ScanHeader(
                        title: s.scanTitle,
                        color: t.onCameraSurface,
                        leading: _HeaderText(label: s.cancel, onTap: widget.onCancel),
                        trailing: st.phase == CapturePhase.ready
                            ? _FlashButton(flash: st.flash, strings: s, onTap: cubit.cycleFlash)
                            : null,
                      ),
                      Expanded(
                        child: st.phase == CapturePhase.ready
                            ? _Viewfinder(
                                key: _viewKey,
                                state: st,
                                preview: widget.preview,
                                strings: s,
                                adjusted: _adjusted,
                                onAdjust: (Quad q) => setState(() => _adjusted = q),
                                onWake: cubit.wake,
                                straightening: switch (_straightening) {
                                  (final File photo, final Quad quad, final int turns, final int id) =>
                                    StraightenAnimation(
                                      key: ValueKey<int>(id),
                                      photo: photo,
                                      quad: quad,
                                      turns: turns,
                                      background: t.cameraSurface,
                                      onDone: () => setState(() => _straightening = null),
                                    ),
                                  null => null,
                                },
                              )
                            : CameraPermissionView(
                                phase: st.phase,
                                strings: s,
                                onRetry: cubit.recheckPermission,
                                onOpenSettings: cubit.openSettings,
                              ),
                      ),
                      if (st.adjustFile != null)
                        _AdjustBar(
                          strings: s,
                          onRotate: cubit.rotateAdjusted,
                          onRetake: () {
                            setState(() => _adjusted = null);
                            unawaited(cubit.retakeAdjusted());
                          },
                          onKeep: () => _keep(cubit),
                        )
                      else
                        _BottomBar(state: st, strings: s, onReview: widget.onReview, stackKey: _stackKey),
                    ],
                  );
                },
              ),
            ),
            if (_flying != null) _FlyingShot(file: _flying!, from: _flyFrom!, to: _flyTo!, animation: _fly),
          ],
        ),
      ),
    );
  }
}

/// The camera paused itself (pk5): a quiet screen in place of the picture and a
/// button that brings it back.
class _Paused extends StatelessWidget {
  const _Paused({required this.strings, required this.onWake});

  final DocScanStrings strings;
  final VoidCallback onWake;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    return ColoredBox(
      color: t.cameraSurface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              strings.cameraPaused,
              style: t.bodyStyle.sized(14, 20).copyWith(color: t.onCameraSurfaceMuted),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: t.spaceMd),
            Semantics(
              button: true,
              label: strings.resumeCamera,
              excludeSemantics: true,
              child: Material(
                color: t.onCameraSurface,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: onWake,
                  child: Container(
                    height: 44,
                    padding: EdgeInsets.symmetric(horizontal: t.spaceLg),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        DocScanIcon(t.icons.capture, size: t.iconSize * 0.75, color: t.primary),
                        SizedBox(width: t.spaceSm),
                        Text(
                          strings.resumeCamera,
                          style: t.buttonStyle.sized(14, 20).copyWith(color: t.primary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «إلغاء» as the design draws it: plain text against the edge, 64 wide at
/// least and 36 high.
class _HeaderText extends StatelessWidget {
  const _HeaderText({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 36),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: Text(label, style: t.bodyStyle.sized(15, 22).copyWith(color: t.onCameraSurface)),
          ),
        ),
      ),
    );
  }
}

/// The flash (pk3): its icon with the state written beside it. Tapping goes
/// off, automatic, on, and back to off.
class _FlashButton extends StatelessWidget {
  const _FlashButton({required this.flash, required this.strings, required this.onTap});

  final ScanFlash flash;
  final DocScanStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final String state = switch (flash) {
      ScanFlash.auto => strings.flashAuto,
      ScanFlash.on => strings.flashOn,
      ScanFlash.off => strings.flashOff,
    };
    final String? icon = flash == ScanFlash.on ? t.icons.flashOn ?? t.icons.flash : t.icons.flash;
    // Off reads quieter than auto and on.
    final Color color = flash == ScanFlash.off ? t.onCameraSurfaceMuted : t.onCameraSurface;
    return Semantics(
      button: true,
      label: '${strings.flash}: $state',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 36),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                DocScanIcon(icon, size: t.iconSize * 0.75, color: color),
                SizedBox(width: t.spaceXs),
              ] else ...<Widget>[
                Text(strings.flash, style: t.captionStyle.sized(13, 20).copyWith(color: color)),
                SizedBox(width: t.spaceXs),
              ],
              Text(state, style: t.captionStyle.sized(13, 20).copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({
    super.key,
    required this.state,
    required this.preview,
    required this.strings,
    required this.adjusted,
    required this.onAdjust,
    required this.onWake,
    this.straightening,
  });

  final CaptureState state;

  /// «استئناف الكاميرا» after the camera paused itself (pk5).
  final VoidCallback onWake;

  /// The page straightening itself after capture, over everything else.
  final Widget? straightening;
  final Widget Function() preview;
  final DocScanStrings strings;

  /// The corner step's corners once the user dragged one.
  final Quad? adjusted;
  final ValueChanged<Quad> onAdjust;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final String? message = state.limitReached
        ? strings.pageLimitReached(state.pageCount)
        : (state.storageFull ? strings.storageFull : null);
    final File? adjust = state.adjustFile;
    // Design: the live picture fills the width on black, 8 above the bottom bar.
    return Padding(
      padding: EdgeInsets.only(bottom: t.spaceSm),
      child: ColoredBox(
        color: t.cameraSurface,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  preview(),
                  Positioned.fill(
                    child: BlocSelector<CaptureCubit, CaptureState, Quad?>(
                      selector: (CaptureState s) => s.quad,
                      builder: (BuildContext context, Quad? quad) => EdgeFrameOverlay(
                        quad: adjust == null ? quad : null,
                        color: t.frameDetected,
                        strokeWidth: 2.5,
                        fill: t.frameDetected.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (adjust != null)
              TweenAnimationBuilder<double>(
                // Design `qn-fade`: the corner step fades in over 200 ms.
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 200),
                builder: (BuildContext context, double o, Widget? child) => Opacity(opacity: o, child: child),
                child: ColoredBox(
                  color: t.cameraSurface,
                  // The photo shows upright; the editor's corners stay in the
                  // photo's own coordinates (RotatedBox maps the drags).
                  child: RotatedBox(
                    quarterTurns: state.adjustTurns,
                    child: CornerEditor(
                      key: ValueKey<String>(adjust.path),
                      photo: adjust,
                      quad: adjusted ?? state.adjustQuad ?? Quad.fullFrame,
                      strings: strings,
                      onChanged: onAdjust,
                    ),
                  ),
                ),
              ),
            if (straightening != null) Positioned.fill(child: straightening!),
            if (state.idle && adjust == null)
              Positioned.fill(
                child: _Paused(strings: strings, onWake: onWake),
              ),
            Positioned.fill(
              child: CaptureFlash(shots: state.shots, color: t.captureFlash),
            ),
            if (message != null)
              PositionedDirectional(
                bottom: t.spaceMd,
                start: t.spaceMd,
                end: t.spaceMd,
                child: Semantics(
                  liveRegion: true,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: t.spaceMd, vertical: t.spaceXs),
                      decoration: BoxDecoration(color: t.scrim, borderRadius: BorderRadius.circular(t.radiusLg)),
                      child: Text(
                        message,
                        style: t.captionStyle.copyWith(color: t.onCameraSurface),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Design camera bottom bar: 12 / 24 / 40 padding, the page stack at the start,
/// the shutter in the middle, «حفظ (N)» at the end.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state, required this.strings, required this.onReview, required this.stackKey});

  final CaptureState state;
  final DocScanStrings strings;
  final VoidCallback onReview;

  /// Where the flying shot lands.
  final GlobalKey stackKey;

  @override
  Widget build(BuildContext context) {
    final CaptureCubit cubit = context.read<CaptureCubit>();
    final bool ready = state.phase == CapturePhase.ready;
    final bool hasPages = state.pageCount > 0;
    return Padding(
      padding: ScanMetrics.cameraBar,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: PageThumbnailBadge(
                key: stackKey,
                file: state.lastThumbnail,
                count: state.pageCount,
                shots: state.pageCount,
                label: strings.reviewPages,
                onTap: hasPages ? onReview : null,
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
              child: hasPages
                  ? _Pill(label: strings.saveCount(state.pageCount), height: 40, padding: 16, onTap: onReview)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

/// The corner step's bar: «إعادة الالتقاط», «تدوير» and «حفظ الصفحة» (design
/// `scanAdjOn`, rotation added 2026-11-04).
class _AdjustBar extends StatelessWidget {
  const _AdjustBar({required this.strings, required this.onRotate, required this.onRetake, required this.onKeep});

  final DocScanStrings strings;
  final VoidCallback onRotate;
  final VoidCallback onRetake;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    return Padding(
      padding: ScanMetrics.cameraBar,
      child: SizedBox(
        height: 72,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _Pill(label: strings.retake, height: 44, padding: 18, quiet: true, onTap: onRetake),
            ScanIconButton(
              icon: t.icons.rotate,
              label: strings.rotate,
              onPressed: onRotate,
              color: t.onCameraSurface,
              background: t.onCameraSurface.withValues(alpha: 0.14),
              size: t.iconSize,
            ),
            _Pill(label: strings.savePage, height: 44, padding: 20, onTap: onKeep),
          ],
        ),
      ),
    );
  }
}

/// A white pill with navy text, or a translucent one with white text.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.height,
    required this.padding,
    required this.onTap,
    this.quiet = false,
  });

  final String label;
  final double height;
  final double padding;
  final bool quiet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    return Semantics(
      button: true,
      child: Material(
        color: quiet ? t.onCameraSurface.withValues(alpha: 0.14) : t.onCameraSurface,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: padding),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: t.buttonStyle
                  .sized(14, 20)
                  .copyWith(
                    fontWeight: quiet ? FontWeight.w500 : FontWeight.w700,
                    color: quiet ? t.onCameraSurface : t.primary,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Design shutter: a 72 ring with a 4 white border around a 58 white disc.
class _Shutter extends StatelessWidget {
  const _Shutter({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: t.onCameraSurface, width: 4),
          ),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? t.onCameraSurface : t.onCameraSurfaceMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// The stored page shrinking from the viewfinder into the page stack.
class _FlyingShot extends StatelessWidget {
  const _FlyingShot({required this.file, required this.from, required this.to, required this.animation});

  final File file;
  final Rect from;
  final Rect to;
  final Animation<double> animation;

  static const Cubic _curve = Cubic(0.4, 0, 0.2, 1);

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          final double t = _curve.transform(animation.value);
          return Stack(
            children: <Widget>[
              Positioned.fromRect(
                rect: Rect.lerp(from, to, t)!,
                child: Opacity(opacity: 1 - 0.8 * t, child: child),
              ),
            ],
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: DocScanTheme.of(context).scrim.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Image.file(file, fit: BoxFit.cover, gaplessPlayback: true),
        ),
      ),
    ),
  );
}
