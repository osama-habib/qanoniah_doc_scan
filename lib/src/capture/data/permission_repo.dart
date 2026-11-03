import 'package:dartz/dartz.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/failures.dart';

/// Camera permission, through `permission_handler` because `camera` alone cannot
/// tell "denied" from "permanently denied" on both platforms (research R10).
class PermissionRepo {
  const PermissionRepo();

  /// Asks when needed. Right(unit) means the camera may be used.
  Future<Either<CameraFailure, Unit>> ensureCamera() async {
    PermissionStatus status = await Permission.camera.status;
    if (!status.isGranted && !status.isPermanentlyDenied) {
      status = await Permission.camera.request();
    }
    return _map(status);
  }

  /// Re-reads the status without asking, e.g. after returning from settings.
  Future<Either<CameraFailure, Unit>> check() async =>
      _map(await Permission.camera.status);

  Future<void> openSettings() => openAppSettings();

  static Either<CameraFailure, Unit> _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return const Right<CameraFailure, Unit>(unit);
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return const Left<CameraFailure, Unit>(CameraFailure.permanentlyDenied());
    }
    return const Left<CameraFailure, Unit>(CameraFailure.permissionDenied());
  }
}
