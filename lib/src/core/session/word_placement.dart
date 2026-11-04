import 'scan_session.dart';

/// Where a recognized word is drawn back on its page (revised 2026-11-04): at its
/// box, on its line's baseline, at its line's font size, stretched or narrowed to
/// the printed width. All in the recognized image's pixels.
extension WordPlacement on Word {
  /// Font size (em). Without the ink pass, a share of the engine's box.
  double get em => size > 0 ? size : box.height * 0.75;

  /// Baseline y. Without the ink pass, a little above the box's bottom.
  double get baselineY => baseline > 0 ? baseline : box.bottom - em * 0.22;

  /// Read well enough to be redrawn as text. Below this (marks inside a stamp,
  /// a signature) the scan shows the word as printed.
  bool get drawable => confidence >= minDrawConfidence;
}

const double minDrawConfidence = 0.6;

/// Horizontal scale that makes text of natural width [advance] span [width], within
/// what still reads as the same letters.
double fitScale(double width, double advance) => advance <= 0 ? 1 : (width / advance).clamp(0.6, 1.6).toDouble();
