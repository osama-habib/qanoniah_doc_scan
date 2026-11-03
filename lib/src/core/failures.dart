import 'package:freezed_annotation/freezed_annotation.dart';

part 'failures.freezed.dart';

// Failures never carry document text, words, or file names: hosts forward errors to
// crash reporting (FR-041).

@freezed
sealed class CameraFailure with _$CameraFailure {
  const factory CameraFailure.permissionDenied() = CameraPermissionDenied;
  const factory CameraFailure.permanentlyDenied() = CameraPermanentlyDenied;
  const factory CameraFailure.unavailable() = CameraUnavailable;
}

@freezed
sealed class RecognitionFailure with _$RecognitionFailure {
  const factory RecognitionFailure.engineUnavailable() = EngineUnavailable;
  const factory RecognitionFailure.failed() = RecognitionFailed;
}

@freezed
sealed class BuildFailure with _$BuildFailure {
  const factory BuildFailure.tooLarge({
    required int sizeBytes,
    required int limitBytes,
  }) = BuildTooLarge;
  const factory BuildFailure.storageFull() = BuildStorageFull;
  const factory BuildFailure.unknown() = BuildUnknown;
}

@freezed
sealed class StorageFailure with _$StorageFailure {
  const factory StorageFailure.full() = StorageFull;
  const factory StorageFailure.unknown() = StorageUnknown;
}
