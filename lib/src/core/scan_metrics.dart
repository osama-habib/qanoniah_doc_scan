import 'package:flutter/painting.dart';

/// Geometry and type sizes taken from the scan design (Claude Design «Full App -
/// Document Scan», 2026-11). They are not design-kit tokens: the kit has no text
/// below 16, two radii (12, 20) and no 10, 14, 22 or 28 spacing.
///
/// PENDING DESIGN CONFIRMATION (Ahmed): replace with tokens once the kit has them.
/// Colors and font families still come from the host's [DocScanTheme].
abstract final class ScanMetrics {
  /// Design header: 22 above (the sheet's grabber sits in it), 16 at the sides,
  /// 12 below.
  static const EdgeInsets header = EdgeInsets.fromLTRB(16, 22, 16, 12);

  /// A header with actions (pk7): the row is [headerRow] high so the flash's
  /// 44 touch target fits (z8y71x6uuw), the design's 36 buttons centred in it,
  /// and the padding gives the extra 4 back above and below, so what shows is
  /// still 22 / 12 and every scan header is the same height.
  static const double headerRow = 44;
  static const EdgeInsets headerWithActions = EdgeInsets.fromLTRB(16, 18, 16, 8);

  /// Between the header's sides and its title (12), and between the buttons of
  /// one side (8).
  static const double headerGap = 12;
  static const double headerGroupGap = 8;

  /// The design's round header buttons (36) and the torch's glyph in them (20).
  static const double roundButton = 36;
  static const double torchGlyph = 20;

  /// «توضيح الصفحات»'s header: 10 below.
  static const EdgeInsets filtersHeader = EdgeInsets.fromLTRB(16, 22, 16, 10);
  static const EdgeInsets cameraBar = EdgeInsets.fromLTRB(24, 12, 24, 16);
  static const EdgeInsets reviewBar = EdgeInsets.fromLTRB(16, 12, 16, 16);
  static const EdgeInsets previewBar = EdgeInsets.fromLTRB(16, 10, 16, 16);
  static const EdgeInsets textPage = EdgeInsets.fromLTRB(22, 28, 22, 28);
  static const EdgeInsets sidebar = EdgeInsets.fromLTRB(16, 14, 16, 24);
  static const EdgeInsets thumbPaper = EdgeInsets.fromLTRB(4, 4, 4, 6);
  static const EdgeInsets deleteCardMargin = EdgeInsets.fromLTRB(12, 0, 12, 12);
  static const EdgeInsets deleteCard = EdgeInsets.fromLTRB(16, 20, 16, 16);
  static const EdgeInsets content = EdgeInsets.all(16);
  static const EdgeInsets ring = EdgeInsets.all(2);
  static const EdgeInsets movedRing = EdgeInsets.all(3);
  static const EdgeInsets pill = EdgeInsets.all(4);
  static const EdgeInsets tableCell = EdgeInsets.symmetric(horizontal: 6, vertical: 4);

  static BorderRadius radius(double r) => BorderRadius.all(Radius.elliptical(r, r));
}

extension ScanTextSize on TextStyle {
  /// The design's [size] with a [line] height in logical pixels.
  TextStyle sized(double size, double line) => copyWith(fontSize: size, height: line / size);
}
