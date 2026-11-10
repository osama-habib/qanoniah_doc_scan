import 'package:flutter/material.dart';

import '../doc_scan_theme.dart';
import 'scan_widgets.dart';

/// The scan's one bottom sheet around every step (design: the grabber and
/// pull-down on `scanOn`, pk2), over the screen the scan was opened from.
///
/// The sheet starts just below the status bar with rounded top corners; the app
/// shows dimmed above it. It slides up with the route, and a pull down from its
/// top (the handle and the header under it) moves it with the finger, the app
/// behind growing clearer as it goes (owner, 2026-11-10: one sheet, not a sheet
/// on a sheet). Past [dismissDistance] it asks to close through [onDismiss]; a
/// short pull, or a refused close, springs back.
///
/// Lists inside the step keep their own vertical scrolling: the pull only starts
/// in the top [pullZone].
class ScanSheet extends StatefulWidget {
  const ScanSheet({
    super.key,
    required this.child,
    required this.color,
    required this.handleColor,
    required this.onDismiss,
    this.pullZone = 84,
    this.dismissDistance = 120,
  });

  final Widget child;

  /// The sheet's own surface: dark on the camera steps, light on the others.
  final Color color;
  final Color handleColor;

  /// Asks to close the scan; the sheet springs back when the request is refused.
  final Future<void> Function() onDismiss;

  /// Height from the top of the sheet where a pull can start: the handle and
  /// the header.
  final double pullZone;
  final double dismissDistance;

  @override
  State<ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<ScanSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  double _drag = 0;
  bool _pulling = false;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _back.addListener(() => setState(() => _drag = _from * (1 - Curves.easeOutCubic.transform(_back.value))));
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _springBack() {
    _from = _drag;
    _back.forward(from: 0);
  }

  Future<void> _end(DragEndDetails d) async {
    if (!_pulling) return;
    _pulling = false;
    if (_drag > widget.dismissDistance || (d.primaryVelocity ?? 0) > 900) {
      await widget.onDismiss();
      // Still here: the close was refused (or asked first and kept).
      if (mounted && !_closing) _springBack();
    } else {
      _springBack();
    }
  }

  /// The route is leaving: the sheet carries on down from where the finger
  /// left it instead of springing back first.
  bool get _closing {
    final Animation<double>? route = ModalRoute.of(context)?.animation;
    return route != null && route.status == AnimationStatus.reverse;
  }

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final double top = MediaQuery.paddingOf(context).top + t.spaceSm;
    final Animation<double> route = ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    final Animation<Offset> slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      // Design `qn-scan-in`: the sheet slides up over 420 ms.
      CurvedAnimation(parent: route, curve: const Cubic(0.32, 0.72, 0, 1), reverseCurve: Curves.easeIn),
    );
    final BorderRadius corners = BorderRadius.vertical(top: Radius.circular(t.radiusSheet));
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double height = c.maxHeight - top;
        // The app behind clears as the sheet goes down.
        final double dim = height <= 0 ? 1 : (1 - _drag / height).clamp(0, 1);
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: FadeTransition(
                  opacity: route,
                  child: ColoredBox(color: t.scrim.withValues(alpha: t.scrim.a * dim)),
                ),
              ),
            ),
            Positioned.fill(
              top: top,
              child: SlideTransition(
                position: slide,
                child: Transform.translate(
                  offset: Offset(0, _drag),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    // The pull is a touch shortcut; screen readers close with
                    // «إلغاء» or back, and the step's own labels stay as they are.
                    excludeFromSemantics: true,
                    onVerticalDragStart: (DragStartDetails d) {
                      _pulling = d.localPosition.dy < widget.pullZone;
                      if (_pulling) _back.stop();
                    },
                    onVerticalDragUpdate: (DragUpdateDetails d) {
                      if (_pulling) setState(() => _drag = (_drag + d.delta.dy).clamp(0, double.infinity));
                    },
                    onVerticalDragEnd: _end,
                    onVerticalDragCancel: () {
                      if (_pulling) _springBack();
                      _pulling = false;
                    },
                    child: ClipRRect(
                      borderRadius: corners,
                      child: ColoredBox(
                        color: widget.color,
                        // Below the status bar now: the steps add no top inset.
                        child: MediaQuery.removePadding(
                          context: context,
                          removeTop: true,
                          child: Stack(
                            children: <Widget>[
                              Positioned.fill(child: widget.child),
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: IgnorePointer(
                                  child: Center(child: ScanSheetHandle(color: widget.handleColor)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
