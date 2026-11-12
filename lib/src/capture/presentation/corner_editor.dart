import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
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

  /// Edge [e] (0 top, 1 right, 2 bottom, 3 left) runs from corner e to corner
  /// e + 1; dragging it moves both, so a whole side is set in one gesture (pk4).
  void _moveEdge(int e, Offset delta) {
    final int a = e;
    final int b = (e + 1) % 4;
    // Keep the side's direction: stop at the photo's edge instead of folding it.
    double dx = delta.dx;
    double dy = delta.dy;
    for (final Offset p in <Offset>[_corner(a), _corner(b)]) {
      dx = (p.dx + dx).clamp(0.0, 1.0) - p.dx;
      dy = (p.dy + dy).clamp(0.0, 1.0) - p.dy;
    }
    final Offset d = Offset(dx, dy);
    Quad q = widget.quad;
    Quad put(Quad q, int i, Offset v) => switch (i) {
      0 => q.copyWith(topLeft: v),
      1 => q.copyWith(topRight: v),
      2 => q.copyWith(bottomRight: v),
      _ => q.copyWith(bottomLeft: v),
    };
    q = put(q, a, _corner(a) + d);
    q = put(q, b, _corner(b) + d);
    widget.onChanged(q);
  }

  Offset _edgeMid(int e) => Offset.lerp(_corner(e), _corner((e + 1) % 4), 0.5)!;

  /// What a touch at [at] (in the photo's box) takes: a corner (0 to 3) or a
  /// whole side (4 + side), the nearest one (ClickUp z8y71x6uv0), or null.
  ///
  /// - A corner within [cornerReach] of the finger (a 56 target round a 22 dot).
  /// - A side's middle handle within [midReach].
  /// - Anywhere on a side, within [sideReach] across it (a 32 wide strip): the
  ///   corner at that end when within [reach] of it along the side (design
  ///   03-a), else the whole side.
  static const double cornerReach = 28;
  static const double midReach = 24;
  static const double sideReach = 16;
  static const double reach = 90;

  int? _targetAt(Offset at, Offset Function(Offset) px) {
    int? best;
    double bestDistance = double.infinity;
    void offer(int target, double distance) {
      if (distance < bestDistance) {
        best = target;
        bestDistance = distance;
      }
    }

    for (int i = 0; i < 4; i++) {
      final double d = (at - px(_corner(i))).distance;
      if (d <= cornerReach) offer(i, d);
    }
    for (int e = 0; e < 4; e++) {
      final double m = (at - px(_edgeMid(e))).distance;
      if (m <= midReach) offer(4 + e, m);
      final Offset a = px(_corner(e));
      final Offset b = px(_corner((e + 1) % 4));
      final Offset side = b - a;
      final double length = side.distance;
      if (length == 0) continue;
      final Offset dir = side / length;
      final Offset rel = at - a;
      final double along = rel.dx * dir.dx + rel.dy * dir.dy;
      final double across = (rel.dx * dir.dy - rel.dy * dir.dx).abs();
      if (along < 0 || along > length || across > sideReach) continue;
      if (along <= reach) {
        offer(e, across);
      } else if (length - along <= reach) {
        offer((e + 1) % 4, across);
      } else {
        offer(4 + e, across);
      }
    }
    return best;
  }

  /// The corner or side being dragged, from the first touch to the release.
  int? _grabbed;

  bool _grab(Offset at, Offset Function(Offset) px) {
    if (_grabbed != null) return false;
    final int? target = _targetAt(at, px);
    if (target == null) return false;
    setState(() => _active = _grabbed = target);
    return true;
  }

  /// The finger's movement, in the photo's box, moves what it holds by as much.
  void _drag(Offset delta, Size box) {
    final int? g = _grabbed;
    if (g == null) return;
    final Offset d = Offset(delta.dx / box.width, delta.dy / box.height);
    if (g < 4) {
      _move(g, _corner(g) + d);
    } else {
      _moveEdge(g - 4, d);
    }
  }

  void _release() {
    if (_grabbed == null) return;
    setState(() => _active = _grabbed = null);
  }

  /// The point the finger is moving: the dragged corner or the middle of the
  /// dragged edge (handles 4 to 7).
  Offset? get _focus {
    final int? a = _active;
    if (a == null) return null;
    return a < 4 ? _corner(a) : _edgeMid(a - 4);
  }

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final double? aspect = _aspect;
    if (aspect == null) return const SizedBox.expand();
    // Handles are 22 with a 44 touch target (design).
    const double dot = 22;
    const double hit = 44;
    // The magnifier: 96 across, twice the size, its centre 96 above the finger.
    const double lens = 96;
    const double lift = 96;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints outer) {
        // The photo's box, contained and centred, as AspectRatio would lay it.
        final double fw = outer.maxWidth, fh = outer.maxHeight;
        final Size box = fw / fh > aspect ? Size(fh * aspect, fh) : Size(fw, fw / aspect);
        final Offset origin = Offset((fw - box.width) / 2, (fh - box.height) / 2);
        Offset boxPx(Offset n) => Offset(n.dx * box.width, n.dy * box.height);
        // One recognizer for every handle, over the whole editor (handles at the
        // photo's border reach past it): it takes the touch the moment it lands
        // near one, so the sheet's pull-down and scrolling never get it, and the
        // handle moves from the first pixel (ClickUp z8y71x6uv0).
        return RawGestureDetector(
          behavior: HitTestBehavior.translucent,
          gestures: <Type, GestureRecognizerFactory>{
            _GrabRecognizer: GestureRecognizerFactoryWithHandlers<_GrabRecognizer>(
              _GrabRecognizer.new,
              (_GrabRecognizer r) => r
                ..grab = ((Offset at) => _grab(at - origin, boxPx))
                ..move = ((Offset delta) => _drag(delta, box))
                ..release = _release,
            ),
          },
          child: Center(
            child: SizedBox(
              width: box.width,
              height: box.height,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  Offset px(Offset n) => Offset(n.dx * c.maxWidth, n.dy * c.maxHeight);
                  final Offset? focus = _focus;
                  // The photo with the page outlined and the rest dimmed; the
                  // loupe shows this same layer, so the two never differ.
                  final Widget page = Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image.file(widget.photo, fit: BoxFit.fill, gaplessPlayback: true),
                      CustomPaint(
                        painter: _MaskPainter(
                          quad: widget.quad,
                          accent: t.frameDetected,
                          dim: t.cameraSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  );
                  return Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned.fill(child: page),
                      for (int e = 0; e < 4; e++)
                        Positioned(
                          left: px(_edgeMid(e)).dx - hit / 2,
                          top: px(_edgeMid(e)).dy - hit / 2,
                          child: Semantics(
                            label: widget.strings.cornersTitle,
                            child: IgnorePointer(
                              child: SizedBox(
                                width: hit,
                                height: hit,
                                child: Center(
                                  child: Transform.rotate(
                                    // Along the side.
                                    angle: (px(_corner((e + 1) % 4)) - px(_corner(e))).direction,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      width: _active == 4 + e ? dot * 1.4 : dot,
                                      height: dot / 3,
                                      decoration: BoxDecoration(
                                        color: _active == 4 + e ? t.frameDetected : t.onCameraSurface,
                                        borderRadius: BorderRadius.circular(t.radiusSm),
                                        border: Border.all(color: t.frameDetected, width: 2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      for (int i = 0; i < 4; i++)
                        Positioned(
                          left: px(_corner(i)).dx - hit / 2,
                          top: px(_corner(i)).dy - hit / 2,
                          child: Semantics(
                            label: widget.strings.cornersTitle,
                            child: IgnorePointer(
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
                      // The finger covers the spot it moves: show it, magnified, above
                      // the finger (below it near the top of the photo).
                      if (focus != null)
                        Builder(
                          builder: (BuildContext context) {
                            final Offset at = px(focus);
                            final double up = at.dy - lift - lens / 2 < -lift / 2 ? -lift : lift;
                            // Design 03-b, as drawn (pk4 reopened 2026-11-12): the
                            // photo itself 2.6x, the page's sides over it and a
                            // ring on the exact corner. It draws the photo, not
                            // the screen, so the held handle never fills it.
                            return Positioned(
                              left: at.dx - lens / 2,
                              top: at.dy - up - lens / 2,
                              child: IgnorePointer(
                                child: _Loupe(
                                  key: const ValueKey<String>('loupe'),
                                  page: page,
                                  box: Size(c.maxWidth, c.maxHeight),
                                  focus: at,
                                  size: lens,
                                  zoom: 2.6,
                                  line: t.frameDetected,
                                  rim: t.onCameraSurface,
                                  shadow: t.scrim.withValues(alpha: 0.35),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Takes a touch at once when [grab] says it landed on a handle: the arena is
/// won on the pointer's first contact, before the sheet's drag or any scroll can
/// claim it, and every movement after goes to [move], from the first pixel.
/// A touch [grab] declines is left to the others.
class _GrabRecognizer extends OneSequenceGestureRecognizer {
  bool Function(Offset local) grab = _never;
  void Function(Offset localDelta) move = _ignore;
  VoidCallback release = _nothing;

  static bool _never(Offset _) => false;
  static void _ignore(Offset _) {}
  static void _nothing() {}

  int? _pointer;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null || !grab(event.localPosition)) return;
    _pointer = event.pointer;
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      move(event.localDelta);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _end();
    }
  }

  void _end() {
    final int? p = _pointer;
    if (p == null) return;
    _pointer = null;
    stopTrackingPointer(p);
    release();
  }

  @override
  void rejectGesture(int pointer) {
    super.rejectGesture(pointer);
    _end();
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'corner grab';
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

/// The magnifier of design 03-b: the editor's own [page] layer (the photo with
/// the page outlined) [zoom] times around [focus] (in the photo's box of size
/// [box]), a small ring on the point, and a light rim. The handles are not in
/// it, so the one being held never fills it (pk4 reopened 2026-11-12).
class _Loupe extends StatelessWidget {
  const _Loupe({
    super.key,
    required this.page,
    required this.box,
    required this.focus,
    required this.size,
    required this.zoom,
    required this.line,
    required this.rim,
    required this.shadow,
  });

  final Widget page;
  final Size box;
  final Offset focus;
  final double size;
  final double zoom;
  final Color line;
  final Color rim;
  final Color shadow;

  @override
  Widget build(BuildContext context) {
    // Where the layer's origin lands so that [focus] is in the middle. Laid out
    // at the zoomed size (not transformed), its outline keeps its own width.
    final Offset origin = Offset(size / 2, size / 2) - focus * zoom;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[BoxShadow(color: shadow, blurRadius: 8)],
      ),
      // The rim is drawn over the content, so it takes no room from it and the
      // point stays in the exact middle.
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: rim, width: 3),
      ),
      child: ClipOval(
        child: Stack(
          children: <Widget>[
            Positioned(
              left: origin.dx,
              top: origin.dy,
              width: box.width * zoom,
              height: box.height * zoom,
              child: page,
            ),
            Center(
              child: Container(
                key: const ValueKey<String>('loupe-dot'),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: line, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
