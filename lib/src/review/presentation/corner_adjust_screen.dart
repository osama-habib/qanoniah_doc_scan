import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/presentation/scan_widgets.dart';
import '../../core/session/scan_session.dart';
import '../../capture/presentation/edge_frame_overlay.dart';

/// «زاوية الصفحة»: four draggable corners over the raw capture (story 12).
/// Pops the new [Quad], or null for «إعادة الالتقاط» / back.
class CornerAdjustScreen extends StatefulWidget {
  const CornerAdjustScreen({super.key, required this.page, required this.strings});

  final CapturedPage page;
  final DocScanStrings strings;

  @override
  State<CornerAdjustScreen> createState() => _CornerAdjustScreenState();
}

class _CornerAdjustScreenState extends State<CornerAdjustScreen> {
  late Quad _quad = widget.page.corners;
  double? _aspect;

  @override
  void initState() {
    super.initState();
    final ImageStream stream = FileImage(widget.page.rawFile).resolve(ImageConfiguration.empty);
    stream.addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        final ui.Image i = info.image;
        if (mounted) setState(() => _aspect = i.width / i.height);
      }),
    );
  }

  Offset _corner(int i) => switch (i) {
    0 => _quad.topLeft,
    1 => _quad.topRight,
    2 => _quad.bottomRight,
    _ => _quad.bottomLeft,
  };

  void _move(int i, Offset n) {
    final Offset c = Offset(n.dx.clamp(0, 1), n.dy.clamp(0, 1));
    setState(() {
      _quad = switch (i) {
        0 => _quad.copyWith(topLeft: c),
        1 => _quad.copyWith(topRight: c),
        2 => _quad.copyWith(bottomRight: c),
        _ => _quad.copyWith(bottomLeft: c),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final DocScanStrings s = widget.strings;
    final double? aspect = _aspect;
    return Scaffold(
      backgroundColor: t.cameraSurface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            ScanHeader(
              title: s.cornersTitle,
              color: t.onCameraSurface,
              leading: ScanIconButton(
                icon: t.icons.back,
                label: s.back,
                mirrorInRtl: true,
                color: t.onCameraSurface,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Text(s.cornersHint, style: t.captionStyle.copyWith(color: t.onCameraSurfaceMuted)),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(t.spaceLg),
                child: Center(
                  child: aspect == null
                      ? CircularProgressIndicator(color: t.onCameraSurface)
                      : AspectRatio(
                          aspectRatio: aspect,
                          child: LayoutBuilder(
                            builder: (BuildContext context, BoxConstraints c) => Stack(
                              clipBehavior: Clip.none,
                              children: <Widget>[
                                Positioned.fill(child: Image.file(widget.page.rawFile, fit: BoxFit.fill)),
                                Positioned.fill(
                                  child: EdgeFrameOverlay(
                                    quad: _quad,
                                    color: t.frameDetected,
                                    strokeWidth: t.frameStrokeWidth,
                                    fill: t.frameDetected.withValues(alpha: 0.12),
                                  ),
                                ),
                                for (int i = 0; i < 4; i++)
                                  Positioned(
                                    left: _corner(i).dx * c.maxWidth - t.iconSize,
                                    top: _corner(i).dy * c.maxHeight - t.iconSize,
                                    child: GestureDetector(
                                      onPanUpdate: (DragUpdateDetails d) => _move(
                                        i,
                                        _corner(i) + Offset(d.delta.dx / c.maxWidth, d.delta.dy / c.maxHeight),
                                      ),
                                      child: Container(
                                        width: t.iconSize * 2,
                                        height: t.iconSize * 2,
                                        alignment: Alignment.center,
                                        child: Container(
                                          width: t.iconSize,
                                          height: t.iconSize,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: t.onCameraSurface,
                                            border: Border.all(color: t.frameDetected, width: t.frameStrokeWidth),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(t.spaceLg),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: ScanQuietButton(
                      label: s.retake,
                      color: t.onCameraSurface,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  SizedBox(width: t.spaceMd),
                  Expanded(
                    flex: 2,
                    child: ScanPrimaryButton(label: s.savePage, onPressed: () => Navigator.of(context).pop(_quad)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
