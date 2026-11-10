import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// SVG asset paths for every icon the flow shows.
///
/// The host fills these from its own iconsax assets (FR-072). The package bundles no
/// icon files and copies nothing from the design kit.
@immutable
class DocScanIcons {
  const DocScanIcons({
    required this.close,
    required this.capture,
    required this.autoMode,
    required this.manualMode,
    required this.addPage,
    required this.retake,
    required this.delete,
    required this.crop,
    required this.filters,
    required this.redact,
    required this.reveal,
    required this.edit,
    required this.document,
    required this.back,
    required this.done,
    required this.photoView,
    required this.undo,
    required this.dragHandle,
    required this.pages,
    required this.search,
    required this.chevronUp,
    required this.chevronDown,
    required this.pdf,
    String? rotate,
    this.flash,
    this.flashOn,
    this.flashOff,
  }) : _rotate = rotate;

  final String close;
  final String capture;
  final String autoMode;
  final String manualMode;
  final String addPage;
  final String retake;

  /// «تدوير» on the corner step (iconsax `rotate-left`). Null: the retake icon,
  /// which is the same glyph in the Qanoniah set.
  String get rotate => _rotate ?? retake;
  final String? _rotate;

  /// The camera's flash button, one glyph per state (z8y71x6uuw): [flash]
  /// automatic, [flashOn] on, [flashOff] off. A missing [flashOn] or [flashOff]
  /// falls back to [flash]; a missing [flash] shows the state as text.
  final String? flash;
  final String? flashOn;
  final String? flashOff;
  final String delete;
  final String crop;
  final String filters;
  final String redact;
  final String reveal;
  final String edit;
  final String document;

  /// Mirrored under RTL by [DocScanIcon] (FR-073).
  final String back;
  final String done;
  final String photoView;

  /// «إرجاع الصفحة لمكانها» on a moved page.
  final String undo;

  /// The grip on each review tile.
  final String dragHandle;

  /// «كل الصفحات»: the preview's page sidebar.
  final String pages;
  final String search;
  final String chevronUp;
  final String chevronDown;

  /// Shown in full color next to the file name, not tinted.
  final String pdf;
}

/// Renders one [DocScanIcons] path, tinted with [color].
class DocScanIcon extends StatelessWidget {
  const DocScanIcon(
    this.assetPath, {
    super.key,
    required this.size,
    required this.color,
    this.mirrorInRtl = false,
    this.semanticLabel,
  });

  final String assetPath;
  final double size;
  final Color color;

  /// True for direction-bearing icons such as back arrows and chevrons.
  final bool mirrorInRtl;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget icon = SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
    );
    final bool mirror = mirrorInRtl && Directionality.of(context) == TextDirection.rtl;
    return mirror ? Transform.flip(flipX: true, child: icon) : icon;
  }
}
