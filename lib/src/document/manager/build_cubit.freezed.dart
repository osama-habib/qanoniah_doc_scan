// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'build_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$BuildState {
  BuildStep get step => throw _privateConstructorUsedError;

  /// Progress inside [step], 0 to 1.
  double get progress => throw _privateConstructorUsedError;
  BuildOutput? get output => throw _privateConstructorUsedError;
  BuildFailure? get failure => throw _privateConstructorUsedError;

  /// Create a copy of BuildState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BuildStateCopyWith<BuildState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BuildStateCopyWith<$Res> {
  factory $BuildStateCopyWith(
    BuildState value,
    $Res Function(BuildState) then,
  ) = _$BuildStateCopyWithImpl<$Res, BuildState>;
  @useResult
  $Res call({
    BuildStep step,
    double progress,
    BuildOutput? output,
    BuildFailure? failure,
  });

  $BuildFailureCopyWith<$Res>? get failure;
}

/// @nodoc
class _$BuildStateCopyWithImpl<$Res, $Val extends BuildState>
    implements $BuildStateCopyWith<$Res> {
  _$BuildStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BuildState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? step = null,
    Object? progress = null,
    Object? output = freezed,
    Object? failure = freezed,
  }) {
    return _then(
      _value.copyWith(
            step: null == step
                ? _value.step
                : step // ignore: cast_nullable_to_non_nullable
                      as BuildStep,
            progress: null == progress
                ? _value.progress
                : progress // ignore: cast_nullable_to_non_nullable
                      as double,
            output: freezed == output
                ? _value.output
                : output // ignore: cast_nullable_to_non_nullable
                      as BuildOutput?,
            failure: freezed == failure
                ? _value.failure
                : failure // ignore: cast_nullable_to_non_nullable
                      as BuildFailure?,
          )
          as $Val,
    );
  }

  /// Create a copy of BuildState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BuildFailureCopyWith<$Res>? get failure {
    if (_value.failure == null) {
      return null;
    }

    return $BuildFailureCopyWith<$Res>(_value.failure!, (value) {
      return _then(_value.copyWith(failure: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$BuildStateImplCopyWith<$Res>
    implements $BuildStateCopyWith<$Res> {
  factory _$$BuildStateImplCopyWith(
    _$BuildStateImpl value,
    $Res Function(_$BuildStateImpl) then,
  ) = __$$BuildStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    BuildStep step,
    double progress,
    BuildOutput? output,
    BuildFailure? failure,
  });

  @override
  $BuildFailureCopyWith<$Res>? get failure;
}

/// @nodoc
class __$$BuildStateImplCopyWithImpl<$Res>
    extends _$BuildStateCopyWithImpl<$Res, _$BuildStateImpl>
    implements _$$BuildStateImplCopyWith<$Res> {
  __$$BuildStateImplCopyWithImpl(
    _$BuildStateImpl _value,
    $Res Function(_$BuildStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BuildState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? step = null,
    Object? progress = null,
    Object? output = freezed,
    Object? failure = freezed,
  }) {
    return _then(
      _$BuildStateImpl(
        step: null == step
            ? _value.step
            : step // ignore: cast_nullable_to_non_nullable
                  as BuildStep,
        progress: null == progress
            ? _value.progress
            : progress // ignore: cast_nullable_to_non_nullable
                  as double,
        output: freezed == output
            ? _value.output
            : output // ignore: cast_nullable_to_non_nullable
                  as BuildOutput?,
        failure: freezed == failure
            ? _value.failure
            : failure // ignore: cast_nullable_to_non_nullable
                  as BuildFailure?,
      ),
    );
  }
}

/// @nodoc

class _$BuildStateImpl implements _BuildState {
  const _$BuildStateImpl({
    required this.step,
    this.progress = 0,
    this.output,
    this.failure,
  });

  @override
  final BuildStep step;

  /// Progress inside [step], 0 to 1.
  @override
  @JsonKey()
  final double progress;
  @override
  final BuildOutput? output;
  @override
  final BuildFailure? failure;

  @override
  String toString() {
    return 'BuildState(step: $step, progress: $progress, output: $output, failure: $failure)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BuildStateImpl &&
            (identical(other.step, step) || other.step == step) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.output, output) || other.output == output) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, step, progress, output, failure);

  /// Create a copy of BuildState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BuildStateImplCopyWith<_$BuildStateImpl> get copyWith =>
      __$$BuildStateImplCopyWithImpl<_$BuildStateImpl>(this, _$identity);
}

abstract class _BuildState implements BuildState {
  const factory _BuildState({
    required final BuildStep step,
    final double progress,
    final BuildOutput? output,
    final BuildFailure? failure,
  }) = _$BuildStateImpl;

  @override
  BuildStep get step;

  /// Progress inside [step], 0 to 1.
  @override
  double get progress;
  @override
  BuildOutput? get output;
  @override
  BuildFailure? get failure;

  /// Create a copy of BuildState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BuildStateImplCopyWith<_$BuildStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
