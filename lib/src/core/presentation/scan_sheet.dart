import 'package:flutter/material.dart';

import 'scan_widgets.dart';

/// The scan's bottom sheet around every step (design: the grabber and pull-down
/// on `scanOn`, pk2): a drag handle at the top, and a pull down from the top of
/// the sheet (the handle and the header under it) that closes the scan through
/// [onDismiss]. A short pull springs back.
///
/// Lists inside the step keep their own vertical scrolling: the pull only starts
/// in the top [pullZone].
class ScanSheet extends StatefulWidget {
  const ScanSheet({
    super.key,
    required this.child,
    required this.handleColor,
    required this.onDismiss,
    this.pullZone = 84,
    this.dismissDistance = 120,
  });

  final Widget child;
  final Color handleColor;

  /// Asks to close the scan; the sheet springs back when the request is refused.
  final Future<void> Function() onDismiss;

  /// Height from the top of the safe area where a pull can start: the handle and
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
      if (mounted) _springBack();
    } else {
      _springBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // The pull is a touch shortcut; screen readers close with «إلغاء» or back,
      // and the step's own labels must stay as they are.
      excludeFromSemantics: true,
      onVerticalDragStart: (DragStartDetails d) {
        _pulling = d.localPosition.dy - top < widget.pullZone;
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
      child: Transform.translate(
        offset: Offset(0, _drag),
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: widget.child),
            Positioned(
              top: top,
              left: 0,
              right: 0,
              child: IgnorePointer(child: Center(child: ScanSheetHandle(color: widget.handleColor))),
            ),
          ],
        ),
      ),
    );
  }
}
