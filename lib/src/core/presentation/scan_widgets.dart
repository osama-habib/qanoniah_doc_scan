import 'package:flutter/material.dart';

import '../scan_metrics.dart';
import '../doc_scan_icons.dart';
import '../doc_scan_theme.dart';

/// Small building blocks shared by the flow's screens. Every value comes from
/// [DocScanTheme] (FR-070).

/// The filled primary action, full width.
class ScanPrimaryButton extends StatelessWidget {
  const ScanPrimaryButton({super.key, required this.label, required this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final bool enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: enabled ? t.primary : t.border,
        borderRadius: BorderRadius.circular(t.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radiusMd),
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            height: 48,
            child: Center(
              child: busy
                  ? SizedBox.square(
                      dimension: t.iconSize,
                      child: CircularProgressIndicator(strokeWidth: t.frameStrokeWidth, color: t.onPrimary),
                    )
                  : Text(
                      label,
                      style: t.buttonStyle.sized(15, 22).copyWith(color: t.onPrimary, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The outlined secondary action, full width (design: «إرفاق كملف PDF» on review).
class ScanSecondaryButton extends StatelessWidget {
  const ScanSecondaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final bool enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusMd),
          side: BorderSide(color: t.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radiusMd),
          onTap: onPressed,
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(
                label,
                style: t.bodyStyle.sized(14, 20).copyWith(color: enabled ? t.onSurface : t.onSurfaceMuted),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet text action with an optional leading icon.
class ScanQuietButton extends StatelessWidget {
  const ScanQuietButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.textStyle,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final Color? color;

  /// Overrides the theme's button style; the color still comes from [color].
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final Color c = onPressed == null ? t.onSurfaceMuted : (color ?? t.primary);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(t.radiusSm),
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: t.spaceSm, horizontal: t.spaceSm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[DocScanIcon(icon!, size: t.iconSize, color: c), SizedBox(width: t.spaceXs)],
              Flexible(
                child: Text(
                  label,
                  style: (textStyle ?? t.buttonStyle).copyWith(color: c),
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round icon button with a required accessibility label (FR-064).
class ScanIconButton extends StatelessWidget {
  const ScanIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
    this.background,
    this.mirrorInRtl = false,
    this.size,
  });

  final String icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color? background;
  final bool mirrorInRtl;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    // Design: a 36 circle around an 18 glyph.
    final double s = size ?? 18;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: background ?? t.scrim.withValues(alpha: 0),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 36,
            child: Center(
              child: DocScanIcon(icon, size: s, color: color, mirrorInRtl: mirrorInRtl),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bottom-sheet drag handle.
class ScanSheetHandle extends StatelessWidget {
  const ScanSheetHandle({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    // Design grabber: 36 by 5, 7 from the top.
    return Padding(
      padding: const EdgeInsets.only(top: 7, bottom: 2),
      child: Container(
        width: 36,
        height: 5,
        decoration: BoxDecoration(color: color, borderRadius: ScanMetrics.radius(5)),
      ),
    );
  }
}

/// A light screen header: title in the middle, actions at the edges. The actions
/// keep their natural width on one line (never wrapped), and the title stays
/// centered on the screen whatever their widths.
class ScanHeader extends StatelessWidget {
  const ScanHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.color,
    this.divider = false,
    this.titleWidget,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final Color? color;

  /// The 1px line under light headers (design #f3f4f6).
  final bool divider;

  /// Replaces the plain [title] text, e.g. the preview's file name.
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    Widget side(Widget? w, AlignmentGeometry a) => Expanded(
      child: Align(
        alignment: a,
        child: w == null ? null : FittedBox(fit: BoxFit.scaleDown, alignment: a, child: w),
      ),
    );
    // Design header: 16 at the sides, 12 above and below, a 16 / 24 bold title.
    return Container(
      padding: ScanMetrics.header,
      decoration: divider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: t.surfaceTertiary)),
            )
          : null,
      child: Row(
        children: <Widget>[
          side(leading, AlignmentDirectional.centerStart),
          // Expanded, not Flexible: a short title must still take its share, or
          // the trailing side ends beside the title instead of at the edge.
          Expanded(
            flex: 2,
            child: Semantics(
              header: true,
              label: titleWidget == null ? null : title,
              child:
                  titleWidget ??
                  Text(
                    title,
                    style: t.bodyStyle.sized(16, 24).copyWith(color: color ?? t.onSurface, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            ),
          ),
          side(trailing, AlignmentDirectional.centerEnd),
        ],
      ),
    );
  }
}

/// A two-option segmented toggle, e.g. «تلقائي / يدوي».
class ScanSegmented<T> extends StatelessWidget {
  const ScanSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.foreground,
    required this.selectedForeground,
    required this.selectedBackground,
    required this.background,
  });

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final Color foreground;
  final Color selectedForeground;
  final Color selectedBackground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    return Container(
      padding: EdgeInsets.all(t.spaceXs),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(t.radiusLg)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final MapEntry<T, String> o in options.entries)
            Semantics(
              selected: o.key == selected,
              button: true,
              label: o.value,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => onChanged(o.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(horizontal: t.spaceMd, vertical: t.spaceXs),
                  decoration: BoxDecoration(
                    color: o.key == selected ? selectedBackground : background,
                    borderRadius: BorderRadius.circular(t.radiusLg),
                  ),
                  child: Text(
                    o.value,
                    style: t.captionStyle.copyWith(color: o.key == selected ? selectedForeground : foreground),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
