import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/scan_metrics.dart';
import '../../core/doc_scan_theme.dart';

/// A short white flash each time [shots] changes (story 2, design `qn-scan-flash`:
/// 0.9 to 0 over 350 ms, ease out).
class CaptureFlash extends StatefulWidget {
  const CaptureFlash({super.key, required this.shots, required this.color});

  final int shots;
  final Color color;

  @override
  State<CaptureFlash> createState() => _CaptureFlashState();
}

class _CaptureFlashState extends State<CaptureFlash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));

  @override
  void didUpdateWidget(CaptureFlash old) {
    super.didUpdateWidget(old);
    if (old.shots != widget.shots) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? _) =>
          ColoredBox(
            color: widget.color.withValues(
              alpha: _c.isAnimating ? (1 - Curves.easeOut.transform(_c.value)) * 0.9 : 0,
            ),
          ),
    ),
  );
}

/// Two stacked sheets with the page count (design camera bottom bar): the top
/// sheet shows the last page, and each new shot pops in, like it flew down from
/// the viewfinder.
class PageThumbnailBadge extends StatelessWidget {
  const PageThumbnailBadge({
    super.key,
    required this.file,
    required this.count,
    required this.shots,
    required this.label,
    required this.onTap,
  });

  final File? file;
  final int count;
  final int shots;
  final String label;
  final VoidCallback? onTap;

  // Design: 46 by 60 sheets, the back one turned -6°, a 22 high count badge.
  static const double _width = 46;
  static const double _height = 60;
  static const double _badge = 22;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final File? f = file;
    if (f == null || count == 0) return const SizedBox(width: _width, height: _height);
    final BorderRadius r = ScanMetrics.radius(4);
    return Semantics(
      button: true,
      label: label,
      value: '$count',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: _width,
          height: _height,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: Transform.rotate(
                  angle: -6 * 3.14159265 / 180,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: t.surfaceSecondary, borderRadius: r),
                  ),
                ),
              ),
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  // The flying shot lands here; the new sheet just settles in.
                  transitionBuilder: (Widget child, Animation<double> a) => ScaleTransition(
                    scale: Tween<double>(begin: 1.15, end: 1).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
                    child: child,
                  ),
                  child: Container(
                    key: ValueKey<int>(shots),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: r,
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: t.scrim.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: r,
                      child: Image.file(f, fit: BoxFit.cover, cacheWidth: 160),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: -8,
                end: -8,
                child: Container(
                  constraints: const BoxConstraints(minWidth: _badge),
                  height: _badge,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.frameDetected,
                    borderRadius: BorderRadius.circular(_badge),
                    border: Border.all(color: t.cameraSurface, width: 2),
                  ),
                  child: Text(
                    '$count',
                    style: t.captionStyle
                        .sized(11, 11)
                        .copyWith(
                          color: t.onCameraSurface,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
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
