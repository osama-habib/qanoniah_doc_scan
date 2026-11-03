import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/doc_scan_theme.dart';

/// A short white flash each time [shots] changes (story 2).
class CaptureFlash extends StatefulWidget {
  const CaptureFlash({super.key, required this.shots, required this.color});

  final int shots;
  final Color color;

  @override
  State<CaptureFlash> createState() => _CaptureFlashState();
}

class _CaptureFlashState extends State<CaptureFlash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

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
          ColoredBox(color: widget.color.withValues(alpha: _c.isAnimating ? (1 - _c.value) * 0.85 : 0)),
    ),
  );
}

/// The last page's thumbnail with the page count; each new shot pops in, like it
/// flew down from the viewfinder.
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

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final File? f = file;
    if (f == null || count == 0) return SizedBox.square(dimension: t.thumbnailSize);
    return Semantics(
      button: true,
      label: label,
      value: '$count',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox.square(
          dimension: t.thumbnailSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (Widget child, Animation<double> a) => SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, -2.5), end: Offset.zero)
                        .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                    child: ScaleTransition(scale: Tween<double>(begin: 1.8, end: 1).animate(a), child: child),
                  ),
                  child: ClipRRect(
                    key: ValueKey<int>(shots),
                    borderRadius: BorderRadius.circular(t.radiusSm),
                    child: Image.file(f, fit: BoxFit.cover, cacheWidth: 160),
                  ),
                ),
              ),
              PositionedDirectional(
                top: -t.spaceXs,
                end: -t.spaceXs,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: t.spaceXs + t.spaceXs / 2),
                  decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(t.radiusLg)),
                  child: Text('$count', style: t.captionStyle.copyWith(color: t.onPrimary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
