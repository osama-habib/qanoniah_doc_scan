import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/presentation/scan_widgets.dart';
import '../../core/session/scan_session.dart';
import '../manager/preview_cubit.dart';

/// The page photo with «لون المسح» (story 14). No edit tools here.
class PhotoView extends StatelessWidget {
  const PhotoView({super.key, required this.page, required this.strings});

  final CapturedPage page;
  final DocScanStrings strings;

  // Luminance weights (Rec. 709); a preview of what the image-form builder writes.
  static const List<double> _gray = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];
  static const List<double> _bw = <double>[
    0.64, 2.15, 0.22, 0, -300, //
    0.64, 2.15, 0.22, 0, -300,
    0.64, 2.15, 0.22, 0, -300,
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final PreviewCubit cubit = context.watch<PreviewCubit>();
    final PreviewState st = cubit.state;
    final Widget photo = Image.file(page.preparedFile, fit: BoxFit.contain);
    return Column(
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(t.spaceLg),
            child: switch (st.colorMode) {
              ScanColorMode.color => photo,
              ScanColorMode.gray => ColorFiltered(colorFilter: const ColorFilter.matrix(_gray), child: photo),
              ScanColorMode.bw => ColorFiltered(colorFilter: const ColorFilter.matrix(_bw), child: photo),
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: t.spaceLg),
          child: Row(
            children: <Widget>[
              Text(strings.scanColor, style: t.captionStyle.copyWith(color: t.onSurfaceMuted)),
              SizedBox(width: t.spaceSm),
              Flexible(
                child: IgnorePointer(
                  ignoring: !st.colorModeAvailable,
                  child: Opacity(
                    opacity: st.colorModeAvailable ? 1 : 0.4,
                    child: ScanSegmented<ScanColorMode>(
                      options: <ScanColorMode, String>{
                        ScanColorMode.color: strings.colorColor,
                        ScanColorMode.gray: strings.colorGray,
                        ScanColorMode.bw: strings.colorBw,
                      },
                      selected: st.colorMode,
                      onChanged: cubit.setColorMode,
                      foreground: t.onSurfaceMuted,
                      selectedForeground: t.onPrimary,
                      selectedBackground: t.primary,
                      background: t.surfaceSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!st.colorModeAvailable)
          Padding(
            padding: EdgeInsets.all(t.spaceXs),
            child: Text(strings.sendsAsText, style: t.captionStyle.copyWith(color: t.onSurfaceMuted)),
          ),
      ],
    );
  }
}
