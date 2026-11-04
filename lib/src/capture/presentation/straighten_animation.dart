import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/session/scan_session.dart';

/// The page straightening itself, like a scanner app (revised 2026-11-04): the
/// photo freezes, the page inside [quad] lifts out of it and its corners glide
/// from where they were photographed to an upright rectangle of the page's
/// proportions, the rest of the photo fading away. [turns] shows the photo as
/// the corner step did. Calls [onDone] when finished, at once under reduced
/// motion.
class StraightenAnimation extends StatefulWidget {
  const StraightenAnimation({
    super.key,
    required this.photo,
    required this.quad,
    required this.turns,
    required this.background,
    required this.onDone,
    this.duration = const Duration(milliseconds: 560),
  });

  final File photo;
  final Quad quad;
  final int turns;
  final Color background;
  final VoidCallback onDone;
  final Duration duration;

  @override
  State<StraightenAnimation> createState() => _StraightenAnimationState();
}

class _StraightenAnimationState extends State<StraightenAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  ImageStream? _stream;
  bool _started = false;
  double? _aspect;
  late final ImageStreamListener _listener = ImageStreamListener((ImageInfo info, bool _) {
    final ui.Image i = info.image;
    if (!mounted) return;
    setState(() => _aspect = i.width / i.height);
    // From the first frame that shows the photo.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;
      _c.forward().whenComplete(() {
        if (mounted) widget.onDone();
      });
    });
  });

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Reduced motion: the page goes straight to the stack.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted) widget.onDone();
      });
      return;
    }
    _stream = FileImage(widget.photo).resolve(ImageConfiguration.empty)..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double? aspect = _aspect;
    return ColoredBox(
      color: widget.background,
      child: aspect == null
          ? const SizedBox.expand()
          : RotatedBox(
              quarterTurns: widget.turns,
              child: Center(
                child: AspectRatio(
                  aspectRatio: aspect,
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) => AnimatedBuilder(
                      animation: _c,
                      builder: (BuildContext context, Widget? image) {
                        final Size size = Size(c.maxWidth, c.maxHeight);
                        final List<Offset> from = _corners(widget.quad, size);
                        final List<Offset> to = _upright(from, size);
                        // Ease in and out, the motion a little ahead of the fade.
                        final double t = Curves.easeInOutCubic.transform(_c.value);
                        final List<Offset> now = <Offset>[for (int i = 0; i < 4; i++) Offset.lerp(from[i], to[i], t)!];
                        final double rest = 1 - Curves.easeOut.transform((_c.value * 2).clamp(0, 1));
                        return Stack(
                          children: <Widget>[
                            // The photo around the page, fading out.
                            Positioned.fill(
                              child: Opacity(opacity: rest * 0.6, child: image),
                            ),
                            Positioned.fill(
                              child: Transform(
                                transform: homography(from, now),
                                child: ClipPath(clipper: _QuadClip(from), child: image),
                              ),
                            ),
                          ],
                        );
                      },
                      child: Image.file(widget.photo, fit: BoxFit.fill, gaplessPlayback: true),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  static List<Offset> _corners(Quad q, Size s) => <Offset>[
    for (final Offset o in <Offset>[q.topLeft, q.topRight, q.bottomRight, q.bottomLeft])
      Offset(o.dx * s.width, o.dy * s.height),
  ];

  /// An upright rectangle of the page's proportions (its opposite sides
  /// averaged), centred, with a margin.
  static List<Offset> _upright(List<Offset> q, Size s) {
    final double w = ((q[1] - q[0]).distance + (q[2] - q[3]).distance) / 2;
    final double h = ((q[3] - q[0]).distance + (q[2] - q[1]).distance) / 2;
    final double a = h > 0 ? w / h : 1;
    double rw = s.width * 0.86;
    double rh = rw / a;
    if (rh > s.height * 0.86) {
      rh = s.height * 0.86;
      rw = rh * a;
    }
    final Offset o = Offset((s.width - rw) / 2, (s.height - rh) / 2);
    return <Offset>[o, o + Offset(rw, 0), o + Offset(rw, rh), o + Offset(0, rh)];
  }
}

/// The projective transform taking the four points [from] to [to] (tl, tr, br,
/// bl), as a Matrix4 for a [Transform].
Matrix4 homography(List<Offset> from, List<Offset> to) {
  // Solve for h0..h7 in x' = (h0 x + h1 y + h2) / (h6 x + h7 y + 1), likewise y'.
  final List<List<double>> m = <List<double>>[];
  for (int i = 0; i < 4; i++) {
    final double x = from[i].dx, y = from[i].dy, u = to[i].dx, v = to[i].dy;
    m.add(<double>[x, y, 1, 0, 0, 0, -u * x, -u * y, u]);
    m.add(<double>[0, 0, 0, x, y, 1, -v * x, -v * y, v]);
  }
  for (int col = 0; col < 8; col++) {
    int pivot = col;
    for (int r = col + 1; r < 8; r++) {
      if (m[r][col].abs() > m[pivot][col].abs()) pivot = r;
    }
    if (m[pivot][col].abs() < 1e-12) return Matrix4.identity();
    final List<double> tmp = m[col];
    m[col] = m[pivot];
    m[pivot] = tmp;
    for (int r = 0; r < 8; r++) {
      if (r == col) continue;
      final double f = m[r][col] / m[col][col];
      for (int k = col; k < 9; k++) {
        m[r][k] -= f * m[col][k];
      }
    }
  }
  final List<double> h = <double>[for (int i = 0; i < 8; i++) m[i][8] / m[i][i]];
  // Rows (h0 h1 0 h2), (h3 h4 0 h5), (0 0 1 0), (h6 h7 0 1), given column by column.
  return Matrix4(h[0], h[3], 0, h[6], h[1], h[4], 0, h[7], 0, 0, 1, 0, h[2], h[5], 0, 1);
}

class _QuadClip extends CustomClipper<Path> {
  _QuadClip(this.q);

  final List<Offset> q;

  @override
  Path getClip(Size size) => Path()..addPolygon(q, true);

  @override
  bool shouldReclip(_QuadClip old) => old.q != q;
}
