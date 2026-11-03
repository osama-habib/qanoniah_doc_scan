import 'package:flutter/material.dart';
import 'package:qanoniah_doc_scan/qanoniah_doc_scan.dart';

/// The example's [DocScanTheme]: the only place in this repo with literal design
/// values (P3). Values are Qanoniah kit tokens as the host app already maps them
/// (`lib/core/style/app_colors.dart`, `app_sizes.dart`, `app_typography.dart`).
///
/// Lines marked `TODO(ahmed)` have no kit token; they use the nearest token until
/// Ahmed answers the spec's open design questions (T029).
const String _font = 'NotoSansArabic';
const List<String> _fallback = <String>['NotoSans'];

const Color _brand500 = Color(0xff0a1c6d);
const Color _logoBlue500 = Color(0xff1f50ab);
const Color _white = Color(0xffffffff);
const Color _gray50 = Color(0xfff9fafb);
const Color _gray200 = Color(0xffe5e7eb);
const Color _gray300 = Color(0xffd1d5db);
const Color _gray500 = Color(0xff6b7280);
const Color _gray800 = Color(0xff1f2937);
const Color _gray900 = Color(0xff111827);
const Color _red600 = Color(0xffdc2626);

TextStyle _text(double size, FontWeight weight, double height) => TextStyle(
  fontFamily: _font,
  fontFamilyFallback: _fallback,
  fontSize: size,
  fontWeight: weight,
  height: height / size,
);

final DocScanTheme fallbackTheme = DocScanTheme(
  cameraSurface: _gray900, // TODO(ahmed): design uses #0b0f19, no dark token.
  onCameraSurface: _white,
  onCameraSurfaceMuted: _gray300,
  frameSearching: _gray300,
  frameDetected: _logoBlue500, // TODO(ahmed): design uses #5b8cff, no token.
  captureFlash: _white,
  surface: _white,
  surfaceSecondary: _gray50,
  onSurface: _gray800,
  onSurfaceMuted: _gray500,
  border: _gray200,
  primary: _brand500,
  onPrimary: _white,
  redactionFill: _gray800,
  onRedactionFill: _white,
  danger: _red600,
  scrim: _gray900.withValues(alpha: 0.6),
  titleStyle: _text(18, FontWeight.w600, 28),
  bodyStyle: _text(16, FontWeight.w400, 24),
  bodyStrongStyle: _text(16, FontWeight.w500, 24),
  captionStyle: _text(14, FontWeight.w400, 20), // TODO(ahmed): no 14px text token.
  buttonStyle: _text(16, FontWeight.w500, 24),
  spaceXs: 4,
  spaceSm: 8,
  spaceMd: 12,
  spaceLg: 16,
  spaceXl: 32,
  radiusSm: 12, // TODO(ahmed): kit has only 12 and 20.
  radiusMd: 12,
  radiusLg: 20,
  radiusSheet: 20,
  iconSize: 24,
  thumbnailSize: 48,
  frameStrokeWidth: 2,
  icons: const DocScanIcons(
    close: 'assets/icons/x-close.svg',
    capture: 'assets/icons/camera-01.svg',
    autoMode: 'assets/icons/magic-star.svg',
    manualMode: 'assets/icons/edit.svg', // TODO(ahmed): no manual-capture icon chosen.
    addPage: 'assets/icons/add-circle.svg',
    retake: 'assets/icons/rotate-left.svg',
    delete: 'assets/icons/trash.svg',
    crop: 'assets/icons/more.svg', // TODO(ahmed): no crop icon in the host set.
    filters: 'assets/icons/setting-4.svg',
    redact: 'assets/icons/eye-slash.svg',
    reveal: 'assets/icons/eye.svg',
    edit: 'assets/icons/edit-2.svg',
    document: 'assets/icons/document-text.svg',
    back: 'assets/icons/left_arrow.svg',
    done: 'assets/icons/tick-circle.svg',
    photoView: 'assets/icons/document-text.svg', // TODO(ahmed): no photo icon in the host set.
  ),
);
