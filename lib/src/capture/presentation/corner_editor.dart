import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/session/scan_session.dart';

/// A photo with four draggable page corners (design `scanAdj`): the area outside
/// the page is dimmed, the page is outlined, and the corner being dragged grows.
class CornerEditor extends StatefulWidget {
  const CornerEditor({
    super.key,
    required this.photo,
    required this.quad,
    required this.onChanged,
    required this.strings,
  });

  final File photo;
  final Quad quad;
  final ValueChanged<Quad> onChanged;
  final DocScanStrings strings;

  @override
  State<CornerEditor> createState() => _CornerEditorState();
}

class _CornerEditorState extends State<CornerEditor> {
  double? _aspect;
  int? _active;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener((ImageInfo info, bool _) {
    final ui.Image i = info.image;
    if (mounted) setState(() => _aspect = i.width / i.height);
  });

  @override
  void initState() {
    super.initState();
    _stream = FileImage(widget.photo).resolve(ImageConfiguration.empty)..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  Offset _corner(int i) => switch (i) {
    0 => widget.quad.topLeft,
    1 => widget.quad.topRight,
    2 => widget.quad.bottomRight,
    _ => widget.quad.bottomLeft,
  };

  void _move(int i, Offset n) {
    final Offset c = Offset(n.dx.clamp(0, 1), n.dy.clamp(0, 1));
    final Quad q = widget.quad;
    widget.onChanged(switch (i) {
      0 => q.copyWith(topLeft: c),
      1 => q.copyWith(topRight: c),
      2 => q.copyWith(bottomRight: c),
      _ => q.copyWith(bottomLeft: c),
    });
  }

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final double? aspect = _aspect;
    if (aspect == null) return const SizedBox.expand();
    // Handles are 22 with a 44 touch target (design).
    const double dot = 22;
    const double hit = 44;
    return Center(
      child: AspectRatio(
        aspectRatio: aspect,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) => Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(child: Image.file(widget.photo, fit: BoxFit.fill, gaplessPlayback: true)),
              Positioned.fill(
                child: CustomPaint(
                  painter: _MaskPainter(quad: widget.quad, accent: t.frameDetected, dim: t.cameraSurface.withValues(alpha: 0.5)),
                ),
              ),
              for (int i = 0; i < 4; i++)
                Positioned(
                  left: _corner(i).dx * c.maxWidth - hit / 2,
                  top: _corner(i).dy * c.maxHeight - hit / 2,
                  child: Semantics(
                    label: widget.strings.cornersTitle,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => setState(() => _active = i),
                      onPanEnd: (_) => setState(() => _active = null),
                      onPanCancel: () => setState(() => _active = null),
                      onPanUpdate: (DragUpdateDetails d) =>
                          _move(i, _corner(i) + Offset(d.delta.dx / c.maxWidth, d.delta.dy / c.maxHeight)),
                      child: SizedBox(
                        width: hit,
                        height: hit,
                        child: Center(
                          child: AnimatedScale(
                            scale: _active == i ? 1.25 : 1,
                            duration: const Duration(milliseconds: 150),
                            child: Container(
                              width: dot,
                              height: dot,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _active == i ? t.frameDetected : t.onCameraSurface,
                                border: Border.all(color: t.frameDetected, width: 3),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: t.scrim.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
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
          ),
        ),
      ),
    );
  }
}

class _MaskPainter extends CustomPainter {
  _MaskPainter({required this.quad, required this.accent, required this.dim});

  final Quad quad;
  final Color accent;

  /// Over the area outside the page (design: black at 50%).
  final Color dim;

  @override
  void paint(Canvas canvas, Size size) {
    Offset p(Offset o) => Offset(o.dx * size.width, o.dy * size.height);
    final Path page = Path()
      ..moveTo(p(quad.topLeft).dx, p(quad.topLeft).dy)
      ..lineTo(p(quad.topRight).dx, p(quad.topRight).dy)
      ..lineTo(p(quad.bottomRight).dx, p(quad.bottomRight).dy)
      ..lineTo(p(quad.bottomLeft).dx, p(quad.bottomLeft).dy)
      ..close();
    final Path outside = Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), page);
    canvas.drawPath(outside, Paint()..color = dim);
    canvas.drawPath(page, Paint()..color = accent.withValues(alpha: 0.12));
    canvas.drawPath(
      page,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_MaskPainter old) => old.quad != quad || old.accent != accent || old.dim != dim;
}
