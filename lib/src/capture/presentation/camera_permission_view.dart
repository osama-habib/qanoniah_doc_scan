import 'package:flutter/material.dart';

import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/presentation/scan_widgets.dart';
import '../manager/capture_cubit.dart';

/// Shown instead of the preview when the camera may not or cannot be used (FR-004).
class CameraPermissionView extends StatelessWidget {
  const CameraPermissionView({
    super.key,
    required this.phase,
    required this.strings,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final CapturePhase phase;
  final DocScanStrings strings;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    if (phase == CapturePhase.checking) {
      return Center(child: CircularProgressIndicator(color: t.onCameraSurface, strokeWidth: t.frameStrokeWidth));
    }
    final bool settings = phase == CapturePhase.permanentlyDenied;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(t.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              strings.cameraPermissionTitle,
              style: t.bodyStrongStyle.copyWith(color: t.onCameraSurface),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: t.spaceLg),
            if (phase != CapturePhase.unavailable)
              ScanPrimaryButton(
                label: settings ? strings.openSettings : strings.cameraPermissionRetry,
                onPressed: settings ? onOpenSettings : onRetry,
              ),
          ],
        ),
      ),
    );
  }
}
