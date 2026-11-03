import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'doc_scan_icons.dart';

/// Every color, text style, spacing, radius, and icon the flow uses.
///
/// The host builds it from Qanoniah design kit tokens and adds it to
/// `ThemeData.extensions` (FR-070). It has no defaults: the package holds no literal
/// design values.
@immutable
class DocScanTheme extends ThemeExtension<DocScanTheme> {
  const DocScanTheme({
    required this.cameraSurface,
    required this.onCameraSurface,
    required this.onCameraSurfaceMuted,
    required this.frameSearching,
    required this.frameDetected,
    required this.captureFlash,
    required this.surface,
    required this.surfaceSecondary,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.border,
    required this.primary,
    required this.onPrimary,
    required this.redactionFill,
    required this.onRedactionFill,
    required this.danger,
    required this.scrim,
    required this.canvas,
    required this.surfaceTertiary,
    required this.inverseSurface,
    required this.titleStyle,
    required this.bodyStyle,
    required this.bodyStrongStyle,
    required this.captionStyle,
    required this.buttonStyle,
    required this.spaceXs,
    required this.spaceSm,
    required this.spaceMd,
    required this.spaceLg,
    required this.spaceXl,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusSheet,
    required this.iconSize,
    required this.thumbnailSize,
    required this.frameStrokeWidth,
    required this.icons,
  });

  /// Dark camera sheet (no kit token yet; spec open design question 1).
  final Color cameraSurface;
  final Color onCameraSurface;
  final Color onCameraSurfaceMuted;

  /// Edge frame while searching and once a page is detected.
  final Color frameSearching;
  final Color frameDetected;
  final Color captureFlash;

  final Color surface;
  final Color surfaceSecondary;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color border;
  final Color primary;
  final Color onPrimary;

  /// The «نص محجوب» bar and redacted words.
  final Color redactionFill;
  final Color onRedactionFill;
  final Color danger;
  final Color scrim;

  /// Behind the preview's pages (design #e5e7eb).
  final Color canvas;

  /// Round icon buttons on light screens (design #f3f4f6).
  final Color surfaceTertiary;

  /// The floating selection bar (design #111827).
  final Color inverseSurface;

  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final TextStyle bodyStrongStyle;
  final TextStyle captionStyle;
  final TextStyle buttonStyle;

  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;

  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusSheet;

  final double iconSize;
  final double thumbnailSize;
  final double frameStrokeWidth;

  final DocScanIcons icons;

  /// The theme from the host's [ThemeData.extensions].
  ///
  /// Throws [StateError] when the host did not add it: the package has no fallback
  /// values to show instead (FR-070).
  static DocScanTheme of(BuildContext context) {
    final DocScanTheme? theme = Theme.of(context).extension<DocScanTheme>();
    if (theme == null) {
      throw StateError(
        'DocScanTheme is missing from ThemeData.extensions. The host app must '
        'provide it, filled from the Qanoniah design kit tokens.',
      );
    }
    return theme;
  }

  @override
  DocScanTheme copyWith({
    Color? cameraSurface,
    Color? onCameraSurface,
    Color? onCameraSurfaceMuted,
    Color? frameSearching,
    Color? frameDetected,
    Color? captureFlash,
    Color? surface,
    Color? surfaceSecondary,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? border,
    Color? primary,
    Color? onPrimary,
    Color? redactionFill,
    Color? onRedactionFill,
    Color? danger,
    Color? scrim,
    Color? canvas,
    Color? surfaceTertiary,
    Color? inverseSurface,
    TextStyle? titleStyle,
    TextStyle? bodyStyle,
    TextStyle? bodyStrongStyle,
    TextStyle? captionStyle,
    TextStyle? buttonStyle,
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusSheet,
    double? iconSize,
    double? thumbnailSize,
    double? frameStrokeWidth,
    DocScanIcons? icons,
  }) {
    return DocScanTheme(
      cameraSurface: cameraSurface ?? this.cameraSurface,
      onCameraSurface: onCameraSurface ?? this.onCameraSurface,
      onCameraSurfaceMuted: onCameraSurfaceMuted ?? this.onCameraSurfaceMuted,
      frameSearching: frameSearching ?? this.frameSearching,
      frameDetected: frameDetected ?? this.frameDetected,
      captureFlash: captureFlash ?? this.captureFlash,
      surface: surface ?? this.surface,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      redactionFill: redactionFill ?? this.redactionFill,
      onRedactionFill: onRedactionFill ?? this.onRedactionFill,
      danger: danger ?? this.danger,
      scrim: scrim ?? this.scrim,
      canvas: canvas ?? this.canvas,
      surfaceTertiary: surfaceTertiary ?? this.surfaceTertiary,
      inverseSurface: inverseSurface ?? this.inverseSurface,
      titleStyle: titleStyle ?? this.titleStyle,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      bodyStrongStyle: bodyStrongStyle ?? this.bodyStrongStyle,
      captionStyle: captionStyle ?? this.captionStyle,
      buttonStyle: buttonStyle ?? this.buttonStyle,
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusSheet: radiusSheet ?? this.radiusSheet,
      iconSize: iconSize ?? this.iconSize,
      thumbnailSize: thumbnailSize ?? this.thumbnailSize,
      frameStrokeWidth: frameStrokeWidth ?? this.frameStrokeWidth,
      icons: icons ?? this.icons,
    );
  }

  @override
  DocScanTheme lerp(covariant DocScanTheme? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    TextStyle s(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    double d(double a, double b) => lerpDouble(a, b, t)!;
    return DocScanTheme(
      cameraSurface: c(cameraSurface, other.cameraSurface),
      onCameraSurface: c(onCameraSurface, other.onCameraSurface),
      onCameraSurfaceMuted: c(onCameraSurfaceMuted, other.onCameraSurfaceMuted),
      frameSearching: c(frameSearching, other.frameSearching),
      frameDetected: c(frameDetected, other.frameDetected),
      captureFlash: c(captureFlash, other.captureFlash),
      surface: c(surface, other.surface),
      surfaceSecondary: c(surfaceSecondary, other.surfaceSecondary),
      onSurface: c(onSurface, other.onSurface),
      onSurfaceMuted: c(onSurfaceMuted, other.onSurfaceMuted),
      border: c(border, other.border),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      redactionFill: c(redactionFill, other.redactionFill),
      onRedactionFill: c(onRedactionFill, other.onRedactionFill),
      danger: c(danger, other.danger),
      scrim: c(scrim, other.scrim),
      canvas: c(canvas, other.canvas),
      surfaceTertiary: c(surfaceTertiary, other.surfaceTertiary),
      inverseSurface: c(inverseSurface, other.inverseSurface),
      titleStyle: s(titleStyle, other.titleStyle),
      bodyStyle: s(bodyStyle, other.bodyStyle),
      bodyStrongStyle: s(bodyStrongStyle, other.bodyStrongStyle),
      captionStyle: s(captionStyle, other.captionStyle),
      buttonStyle: s(buttonStyle, other.buttonStyle),
      spaceXs: d(spaceXs, other.spaceXs),
      spaceSm: d(spaceSm, other.spaceSm),
      spaceMd: d(spaceMd, other.spaceMd),
      spaceLg: d(spaceLg, other.spaceLg),
      spaceXl: d(spaceXl, other.spaceXl),
      radiusSm: d(radiusSm, other.radiusSm),
      radiusMd: d(radiusMd, other.radiusMd),
      radiusLg: d(radiusLg, other.radiusLg),
      radiusSheet: d(radiusSheet, other.radiusSheet),
      iconSize: d(iconSize, other.iconSize),
      thumbnailSize: d(thumbnailSize, other.thumbnailSize),
      frameStrokeWidth: d(frameStrokeWidth, other.frameStrokeWidth),
      icons: t < 0.5 ? icons : other.icons,
    );
  }
}
