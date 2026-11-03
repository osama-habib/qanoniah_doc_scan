// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'capture_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$CaptureState {
  CapturePhase get phase => throw _privateConstructorUsedError;
  CaptureMode get mode => throw _privateConstructorUsedError;

  /// Tracked page corners in the latest frame, normalized.
  Quad? get quad => throw _privateConstructorUsedError;
  CaptureHint get hint => throw _privateConstructorUsedError;
  int get pageCount => throw _privateConstructorUsedError;
  bool get capturing => throw _privateConstructorUsedError;

  /// Increments on every capture; drives the flash, the flying thumbnail and
  /// the «تم التقاط الصفحة» toast.
  int get shots => throw _privateConstructorUsedError;
  File? get lastThumbnail => throw _privateConstructorUsedError;
  bool get limitReached => throw _privateConstructorUsedError;
  bool get storageFull => throw _privateConstructorUsedError;

  /// Replace mode only: the replacement was taken, so the flow returns to review.
  bool get replaced => throw _privateConstructorUsedError;

  /// Manual capture: the photo waiting for «حفظ الصفحة» or «إعادة الالتقاط»,
  /// with the corners found on it (design `scanAdj`).
  File? get adjustFile => throw _privateConstructorUsedError;
  Quad? get adjustQuad => throw _privateConstructorUsedError;

  /// Create a copy of CaptureState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CaptureStateCopyWith<CaptureState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CaptureStateCopyWith<$Res> {
  factory $CaptureStateCopyWith(
    CaptureState value,
    $Res Function(CaptureState) then,
  ) = _$CaptureStateCopyWithImpl<$Res, CaptureState>;
  @useResult
  $Res call({
    CapturePhase phase,
    CaptureMode mode,
    Quad? quad,
    CaptureHint hint,
    int pageCount,
    bool capturing,
    int shots,
    File? lastThumbnail,
    bool limitReached,
    bool storageFull,
    bool replaced,
    File? adjustFile,
    Quad? adjustQuad,
  });

  $QuadCopyWith<$Res>? get quad;
  $QuadCopyWith<$Res>? get adjustQuad;
}

/// @nodoc
class _$CaptureStateCopyWithImpl<$Res, $Val extends CaptureState>
    implements $CaptureStateCopyWith<$Res> {
  _$CaptureStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CaptureState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? phase = null,
    Object? mode = null,
    Object? quad = freezed,
    Object? hint = null,
    Object? pageCount = null,
    Object? capturing = null,
    Object? shots = null,
    Object? lastThumbnail = freezed,
    Object? limitReached = null,
    Object? storageFull = null,
    Object? replaced = null,
    Object? adjustFile = freezed,
    Object? adjustQuad = freezed,
  }) {
    return _then(
      _value.copyWith(
            phase: null == phase
                ? _value.phase
                : phase // ignore: cast_nullable_to_non_nullable
                      as CapturePhase,
            mode: null == mode
                ? _value.mode
                : mode // ignore: cast_nullable_to_non_nullable
                      as CaptureMode,
            quad: freezed == quad
                ? _value.quad
                : quad // ignore: cast_nullable_to_non_nullable
                      as Quad?,
            hint: null == hint
                ? _value.hint
                : hint // ignore: cast_nullable_to_non_nullable
                      as CaptureHint,
            pageCount: null == pageCount
                ? _value.pageCount
                : pageCount // ignore: cast_nullable_to_non_nullable
                      as int,
            capturing: null == capturing
                ? _value.capturing
                : capturing // ignore: cast_nullable_to_non_nullable
                      as bool,
            shots: null == shots
                ? _value.shots
                : shots // ignore: cast_nullable_to_non_nullable
                      as int,
            lastThumbnail: freezed == lastThumbnail
                ? _value.lastThumbnail
                : lastThumbnail // ignore: cast_nullable_to_non_nullable
                      as File?,
            limitReached: null == limitReached
                ? _value.limitReached
                : limitReached // ignore: cast_nullable_to_non_nullable
                      as bool,
            storageFull: null == storageFull
                ? _value.storageFull
                : storageFull // ignore: cast_nullable_to_non_nullable
                      as bool,
            replaced: null == replaced
                ? _value.replaced
                : replaced // ignore: cast_nullable_to_non_nullable
                      as bool,
            adjustFile: freezed == adjustFile
                ? _value.adjustFile
                : adjustFile // ignore: cast_nullable_to_non_nullable
                      as File?,
            adjustQuad: freezed == adjustQuad
                ? _value.adjustQuad
                : adjustQuad // ignore: cast_nullable_to_non_nullable
                      as Quad?,
          )
          as $Val,
    );
  }

  /// Create a copy of CaptureState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $QuadCopyWith<$Res>? get quad {
    if (_value.quad == null) {
      return null;
    }

    return $QuadCopyWith<$Res>(_value.quad!, (value) {
      return _then(_value.copyWith(quad: value) as $Val);
    });
  }

  /// Create a copy of CaptureState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $QuadCopyWith<$Res>? get adjustQuad {
    if (_value.adjustQuad == null) {
      return null;
    }

    return $QuadCopyWith<$Res>(_value.adjustQuad!, (value) {
      return _then(_value.copyWith(adjustQuad: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CaptureStateImplCopyWith<$Res>
    implements $CaptureStateCopyWith<$Res> {
  factory _$$CaptureStateImplCopyWith(
    _$CaptureStateImpl value,
    $Res Function(_$CaptureStateImpl) then,
  ) = __$$CaptureStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    CapturePhase phase,
    CaptureMode mode,
    Quad? quad,
    CaptureHint hint,
    int pageCount,
    bool capturing,
    int shots,
    File? lastThumbnail,
    bool limitReached,
    bool storageFull,
    bool replaced,
    File? adjustFile,
    Quad? adjustQuad,
  });

  @override
  $QuadCopyWith<$Res>? get quad;
  @override
  $QuadCopyWith<$Res>? get adjustQuad;
}

/// @nodoc
class __$$CaptureStateImplCopyWithImpl<$Res>
    extends _$CaptureStateCopyWithImpl<$Res, _$CaptureStateImpl>
    implements _$$CaptureStateImplCopyWith<$Res> {
  __$$CaptureStateImplCopyWithImpl(
    _$CaptureStateImpl _value,
    $Res Function(_$CaptureStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CaptureState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? phase = null,
    Object? mode = null,
    Object? quad = freezed,
    Object? hint = null,
    Object? pageCount = null,
    Object? capturing = null,
    Object? shots = null,
    Object? lastThumbnail = freezed,
    Object? limitReached = null,
    Object? storageFull = null,
    Object? replaced = null,
    Object? adjustFile = freezed,
    Object? adjustQuad = freezed,
  }) {
    return _then(
      _$CaptureStateImpl(
        phase: null == phase
            ? _value.phase
            : phase // ignore: cast_nullable_to_non_nullable
                  as CapturePhase,
        mode: null == mode
            ? _value.mode
            : mode // ignore: cast_nullable_to_non_nullable
                  as CaptureMode,
        quad: freezed == quad
            ? _value.quad
            : quad // ignore: cast_nullable_to_non_nullable
                  as Quad?,
        hint: null == hint
            ? _value.hint
            : hint // ignore: cast_nullable_to_non_nullable
                  as CaptureHint,
        pageCount: null == pageCount
            ? _value.pageCount
            : pageCount // ignore: cast_nullable_to_non_nullable
                  as int,
        capturing: null == capturing
            ? _value.capturing
            : capturing // ignore: cast_nullable_to_non_nullable
                  as bool,
        shots: null == shots
            ? _value.shots
            : shots // ignore: cast_nullable_to_non_nullable
                  as int,
        lastThumbnail: freezed == lastThumbnail
            ? _value.lastThumbnail
            : lastThumbnail // ignore: cast_nullable_to_non_nullable
                  as File?,
        limitReached: null == limitReached
            ? _value.limitReached
            : limitReached // ignore: cast_nullable_to_non_nullable
                  as bool,
        storageFull: null == storageFull
            ? _value.storageFull
            : storageFull // ignore: cast_nullable_to_non_nullable
                  as bool,
        replaced: null == replaced
            ? _value.replaced
            : replaced // ignore: cast_nullable_to_non_nullable
                  as bool,
        adjustFile: freezed == adjustFile
            ? _value.adjustFile
            : adjustFile // ignore: cast_nullable_to_non_nullable
                  as File?,
        adjustQuad: freezed == adjustQuad
            ? _value.adjustQuad
            : adjustQuad // ignore: cast_nullable_to_non_nullable
                  as Quad?,
      ),
    );
  }
}

/// @nodoc

class _$CaptureStateImpl implements _CaptureState {
  const _$CaptureStateImpl({
    required this.phase,
    required this.mode,
    this.quad,
    required this.hint,
    required this.pageCount,
    this.capturing = false,
    this.shots = 0,
    this.lastThumbnail,
    this.limitReached = false,
    this.storageFull = false,
    this.replaced = false,
    this.adjustFile,
    this.adjustQuad,
  });

  @override
  final CapturePhase phase;
  @override
  final CaptureMode mode;

  /// Tracked page corners in the latest frame, normalized.
  @override
  final Quad? quad;
  @override
  final CaptureHint hint;
  @override
  final int pageCount;
  @override
  @JsonKey()
  final bool capturing;

  /// Increments on every capture; drives the flash, the flying thumbnail and
  /// the «تم التقاط الصفحة» toast.
  @override
  @JsonKey()
  final int shots;
  @override
  final File? lastThumbnail;
  @override
  @JsonKey()
  final bool limitReached;
  @override
  @JsonKey()
  final bool storageFull;

  /// Replace mode only: the replacement was taken, so the flow returns to review.
  @override
  @JsonKey()
  final bool replaced;

  /// Manual capture: the photo waiting for «حفظ الصفحة» or «إعادة الالتقاط»,
  /// with the corners found on it (design `scanAdj`).
  @override
  final File? adjustFile;
  @override
  final Quad? adjustQuad;

  @override
  String toString() {
    return 'CaptureState(phase: $phase, mode: $mode, quad: $quad, hint: $hint, pageCount: $pageCount, capturing: $capturing, shots: $shots, lastThumbnail: $lastThumbnail, limitReached: $limitReached, storageFull: $storageFull, replaced: $replaced, adjustFile: $adjustFile, adjustQuad: $adjustQuad)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CaptureStateImpl &&
            (identical(other.phase, phase) || other.phase == phase) &&
            (identical(other.mode, mode) || other.mode == mode) &&
            (identical(other.quad, quad) || other.quad == quad) &&
            (identical(other.hint, hint) || other.hint == hint) &&
            (identical(other.pageCount, pageCount) ||
                other.pageCount == pageCount) &&
            (identical(other.capturing, capturing) ||
                other.capturing == capturing) &&
            (identical(other.shots, shots) || other.shots == shots) &&
            (identical(other.lastThumbnail, lastThumbnail) ||
                other.lastThumbnail == lastThumbnail) &&
            (identical(other.limitReached, limitReached) ||
                other.limitReached == limitReached) &&
            (identical(other.storageFull, storageFull) ||
                other.storageFull == storageFull) &&
            (identical(other.replaced, replaced) ||
                other.replaced == replaced) &&
            (identical(other.adjustFile, adjustFile) ||
                other.adjustFile == adjustFile) &&
            (identical(other.adjustQuad, adjustQuad) ||
                other.adjustQuad == adjustQuad));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    phase,
    mode,
    quad,
    hint,
    pageCount,
    capturing,
    shots,
    lastThumbnail,
    limitReached,
    storageFull,
    replaced,
    adjustFile,
    adjustQuad,
  );

  /// Create a copy of CaptureState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CaptureStateImplCopyWith<_$CaptureStateImpl> get copyWith =>
      __$$CaptureStateImplCopyWithImpl<_$CaptureStateImpl>(this, _$identity);
}

abstract class _CaptureState implements CaptureState {
  const factory _CaptureState({
    required final CapturePhase phase,
    required final CaptureMode mode,
    final Quad? quad,
    required final CaptureHint hint,
    required final int pageCount,
    final bool capturing,
    final int shots,
    final File? lastThumbnail,
    final bool limitReached,
    final bool storageFull,
    final bool replaced,
    final File? adjustFile,
    final Quad? adjustQuad,
  }) = _$CaptureStateImpl;

  @override
  CapturePhase get phase;
  @override
  CaptureMode get mode;

  /// Tracked page corners in the latest frame, normalized.
  @override
  Quad? get quad;
  @override
  CaptureHint get hint;
  @override
  int get pageCount;
  @override
  bool get capturing;

  /// Increments on every capture; drives the flash, the flying thumbnail and
  /// the «تم التقاط الصفحة» toast.
  @override
  int get shots;
  @override
  File? get lastThumbnail;
  @override
  bool get limitReached;
  @override
  bool get storageFull;

  /// Replace mode only: the replacement was taken, so the flow returns to review.
  @override
  bool get replaced;

  /// Manual capture: the photo waiting for «حفظ الصفحة» or «إعادة الالتقاط»,
  /// with the corners found on it (design `scanAdj`).
  @override
  File? get adjustFile;
  @override
  Quad? get adjustQuad;

  /// Create a copy of CaptureState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CaptureStateImplCopyWith<_$CaptureStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
