import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/session/scan_session.dart';

/// Draws the tracked page corners over the preview (design `scanQuad`). Corners are
/// normalized, and the overlay is laid out on exactly the preview's box, so mapping
/// is a multiply.
///
/// Like a scanner app, the frame never jumps: each new detection eases in over
/// 300 ms, a detection missing for less than [hold] keeps the last frame, and the
/// frame pulses (opacity 1 to 0.55 over 1.4 s) while it tracks a page.
class EdgeFrameOverlay extends StatefulWidget {
  const EdgeFrameOverlay({
    super.key,
    required this.quad,
    required this.color,
    required this.strokeWidth,
    required this.fill,
    this.hold = const Duration(milliseconds: 500),
  });

  final Quad? quad;
  final Color color;
  final double strokeWidth;
  final Color fill;
  final Duration hold;

  @override
  State<EdgeFrameOverlay> createState() => _EdgeFrameOverlayState();
}

class _EdgeFrameOverlayState extends State<EdgeFrameOverlay> with TickerProviderStateMixin {
  late final AnimationController _move;
  late final AnimationController _pulse;
  late final AnimationController _show;
  Timer? _fade;
  Quad? _from;
  Quad? _to;
  DateTime _lastSeen = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _move = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _show = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _take(widget.quad);
  }

  @override
  void didUpdateWidget(EdgeFrameOverlay old) {
    super.didUpdateWidget(old);
    if (widget.quad != old.quad) _take(widget.quad);
  }

  void _take(Quad? q) {
    if (q == null) {
      // Brief misses keep the frame; a longer one fades it out.
      if (DateTime.now().difference(_lastSeen) > widget.hold) _show.reverse();
      _fade?.cancel();
      _fade = Timer(widget.hold, () {
        if (mounted && widget.quad == null) _show.reverse();
      });
      return;
    }
    _lastSeen = DateTime.now();
    _fade?.cancel();
    final Quad? current = _current;
    _from = current ?? q;
    _to = q;
    if (current == null || _show.value == 0) {
      _from = q;
    }
    _move.forward(from: 0);
    _show.forward();
  }

  Quad? get _current {
    final Quad? a = _from;
    final Quad? b = _to;
    if (a == null || b == null) return b;
    return lerpQuad(a, b, Curves.easeOut.transform(_move.value));
  }

  @override
  void dispose() {
    _fade?.cancel();
    _move.dispose();
    _pulse.dispose();
    _show.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_move, _pulse, _show]),
      builder: (BuildContext context, Widget? _) {
        final double opacity = _show.value * (1 - 0.45 * Curves.easeInOut.transform(_pulse.value));
        return CustomPaint(
          painter: _QuadPainter(
            _current,
            widget.color.withValues(alpha: widget.color.a * opacity),
            widget.strokeWidth,
            widget.fill.withValues(alpha: widget.fill.a * opacity),
          ),
          size: Size.infinite,
        );
      },
    ),
  );
}

/// The quad between [a] and [b], corner by corner.
Quad lerpQuad(Quad a, Quad b, double t) => Quad(
  topLeft: Offset.lerp(a.topLeft, b.topLeft, t)!,
  topRight: Offset.lerp(a.topRight, b.topRight, t)!,
  bottomRight: Offset.lerp(a.bottomRight, b.bottomRight, t)!,
  bottomLeft: Offset.lerp(a.bottomLeft, b.bottomLeft, t)!,
);

class _QuadPainter extends CustomPainter {
  _QuadPainter(this.quad, this.color, this.strokeWidth, this.fill);

  final Quad? quad;
  final Color color;
  final double strokeWidth;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final Quad? q = quad;
    if (q == null || color.a == 0) return;
    Offset p(Offset n) => Offset(n.dx * size.width, n.dy * size.height);
    final Path path = Path()
      ..moveTo(p(q.topLeft).dx, p(q.topLeft).dy)
      ..lineTo(p(q.topRight).dx, p(q.topRight).dy)
      ..lineTo(p(q.bottomRight).dx, p(q.bottomRight).dy)
      ..lineTo(p(q.bottomLeft).dx, p(q.bottomLeft).dy)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = fill)
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_QuadPainter old) =>
      old.quad != quad || old.color != color || old.strokeWidth != strokeWidth || old.fill != fill;
}
