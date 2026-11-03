import 'package:flutter/material.dart';

import '../../core/session/scan_session.dart';

/// Draws the tracked page corners over the preview. Corners are normalized, and the
/// overlay is laid out on exactly the preview's box, so mapping is a multiply.
class EdgeFrameOverlay extends StatelessWidget {
  const EdgeFrameOverlay({
    super.key,
    required this.quad,
    required this.color,
    required this.strokeWidth,
    required this.fill,
  });

  final Quad? quad;
  final Color color;
  final double strokeWidth;
  final Color fill;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(painter: _QuadPainter(quad, color, strokeWidth, fill), size: Size.infinite),
  );
}

class _QuadPainter extends CustomPainter {
  _QuadPainter(this.quad, this.color, this.strokeWidth, this.fill);

  final Quad? quad;
  final Color color;
  final double strokeWidth;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final Quad? q = quad;
    if (q == null) return;
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
