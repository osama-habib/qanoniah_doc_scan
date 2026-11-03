import 'package:flutter/material.dart';

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
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: t.spaceMd, horizontal: t.spaceLg),
            child: Center(
              child: busy
                  ? SizedBox.square(
                      dimension: t.iconSize,
                      child: CircularProgressIndicator(strokeWidth: t.frameStrokeWidth, color: t.onPrimary),
                    )
                  : Text(label, style: t.buttonStyle.copyWith(color: t.onPrimary), textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet text action with an optional leading icon.
class ScanQuietButton extends StatelessWidget {
  const ScanQuietButton({super.key, required this.label, required this.onPressed, this.icon, this.color});

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final Color? color;

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
              if (icon != null) ...<Widget>[
                DocScanIcon(icon!, size: t.iconSize, color: c),
                SizedBox(width: t.spaceXs),
              ],
              Flexible(child: Text(label, style: t.buttonStyle.copyWith(color: c))),
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
    final double s = size ?? t.iconSize;
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
          child: Padding(
            padding: EdgeInsets.all(t.spaceSm),
            child: DocScanIcon(icon, size: s, color: color, mirrorInRtl: mirrorInRtl),
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
    final DocScanTheme t = DocScanTheme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.spaceSm),
      child: Container(
        width: t.thumbnailSize / 2,
        height: t.spaceXs,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(t.spaceXs)),
      ),
    );
  }
}

/// A light screen header: title in the middle, actions at the edges.
class ScanHeader extends StatelessWidget {
  const ScanHeader({super.key, required this.title, this.leading, this.trailing, this.color});

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.spaceSm, vertical: t.spaceXs),
      child: Row(
        children: <Widget>[
          SizedBox(width: t.thumbnailSize, child: Align(alignment: AlignmentDirectional.centerStart, child: leading)),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: t.titleStyle.copyWith(color: color ?? t.onSurface),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(width: t.thumbnailSize, child: Align(alignment: AlignmentDirectional.centerEnd, child: trailing)),
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
