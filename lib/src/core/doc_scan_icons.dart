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
  });

  final String close;
  final String capture;
  final String autoMode;
  final String manualMode;
  final String addPage;
  final String retake;
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
    final bool mirror =
        mirrorInRtl && Directionality.of(context) == TextDirection.rtl;
    return mirror ? Transform.flip(flipX: true, child: icon) : icon;
  }
}
