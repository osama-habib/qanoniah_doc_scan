// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ReviewState {
  List<CapturedPage> get pages => throw _privateConstructorUsedError;
  PageMove? get lastMove => throw _privateConstructorUsedError;

  /// A page is being re-prepared (corners or filters).
  bool get working => throw _privateConstructorUsedError;
  bool get storageFull => throw _privateConstructorUsedError;

  /// Create a copy of ReviewState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReviewStateCopyWith<ReviewState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReviewStateCopyWith<$Res> {
  factory $ReviewStateCopyWith(
    ReviewState value,
    $Res Function(ReviewState) then,
  ) = _$ReviewStateCopyWithImpl<$Res, ReviewState>;
  @useResult
  $Res call({
    List<CapturedPage> pages,
    PageMove? lastMove,
    bool working,
    bool storageFull,
  });

  $PageMoveCopyWith<$Res>? get lastMove;
}

/// @nodoc
class _$ReviewStateCopyWithImpl<$Res, $Val extends ReviewState>
    implements $ReviewStateCopyWith<$Res> {
  _$ReviewStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReviewState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pages = null,
    Object? lastMove = freezed,
    Object? working = null,
    Object? storageFull = null,
  }) {
    return _then(
      _value.copyWith(
            pages: null == pages
                ? _value.pages
                : pages // ignore: cast_nullable_to_non_nullable
                      as List<CapturedPage>,
            lastMove: freezed == lastMove
                ? _value.lastMove
                : lastMove // ignore: cast_nullable_to_non_nullable
                      as PageMove?,
            working: null == working
                ? _value.working
                : working // ignore: cast_nullable_to_non_nullable
                      as bool,
            storageFull: null == storageFull
                ? _value.storageFull
                : storageFull // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }

  /// Create a copy of ReviewState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PageMoveCopyWith<$Res>? get lastMove {
    if (_value.lastMove == null) {
      return null;
    }

    return $PageMoveCopyWith<$Res>(_value.lastMove!, (value) {
      return _then(_value.copyWith(lastMove: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ReviewStateImplCopyWith<$Res>
    implements $ReviewStateCopyWith<$Res> {
  factory _$$ReviewStateImplCopyWith(
    _$ReviewStateImpl value,
    $Res Function(_$ReviewStateImpl) then,
  ) = __$$ReviewStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<CapturedPage> pages,
    PageMove? lastMove,
    bool working,
    bool storageFull,
  });

  @override
  $PageMoveCopyWith<$Res>? get lastMove;
}

/// @nodoc
class __$$ReviewStateImplCopyWithImpl<$Res>
    extends _$ReviewStateCopyWithImpl<$Res, _$ReviewStateImpl>
    implements _$$ReviewStateImplCopyWith<$Res> {
  __$$ReviewStateImplCopyWithImpl(
    _$ReviewStateImpl _value,
    $Res Function(_$ReviewStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ReviewState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pages = null,
    Object? lastMove = freezed,
    Object? working = null,
    Object? storageFull = null,
  }) {
    return _then(
      _$ReviewStateImpl(
        pages: null == pages
            ? _value._pages
            : pages // ignore: cast_nullable_to_non_nullable
                  as List<CapturedPage>,
        lastMove: freezed == lastMove
            ? _value.lastMove
            : lastMove // ignore: cast_nullable_to_non_nullable
                  as PageMove?,
        working: null == working
            ? _value.working
            : working // ignore: cast_nullable_to_non_nullable
                  as bool,
        storageFull: null == storageFull
            ? _value.storageFull
            : storageFull // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$ReviewStateImpl extends _ReviewState {
  const _$ReviewStateImpl({
    required final List<CapturedPage> pages,
    this.lastMove,
    this.working = false,
    this.storageFull = false,
  }) : _pages = pages,
       super._();

  final List<CapturedPage> _pages;
  @override
  List<CapturedPage> get pages {
    if (_pages is EqualUnmodifiableListView) return _pages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pages);
  }

  @override
  final PageMove? lastMove;

  /// A page is being re-prepared (corners or filters).
  @override
  @JsonKey()
  final bool working;
  @override
  @JsonKey()
  final bool storageFull;

  @override
  String toString() {
    return 'ReviewState(pages: $pages, lastMove: $lastMove, working: $working, storageFull: $storageFull)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReviewStateImpl &&
            const DeepCollectionEquality().equals(other._pages, _pages) &&
            (identical(other.lastMove, lastMove) ||
                other.lastMove == lastMove) &&
            (identical(other.working, working) || other.working == working) &&
            (identical(other.storageFull, storageFull) ||
                other.storageFull == storageFull));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_pages),
    lastMove,
    working,
    storageFull,
  );

  /// Create a copy of ReviewState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReviewStateImplCopyWith<_$ReviewStateImpl> get copyWith =>
      __$$ReviewStateImplCopyWithImpl<_$ReviewStateImpl>(this, _$identity);
}

abstract class _ReviewState extends ReviewState {
  const factory _ReviewState({
    required final List<CapturedPage> pages,
    final PageMove? lastMove,
    final bool working,
    final bool storageFull,
  }) = _$ReviewStateImpl;
  const _ReviewState._() : super._();

  @override
  List<CapturedPage> get pages;
  @override
  PageMove? get lastMove;

  /// A page is being re-prepared (corners or filters).
  @override
  bool get working;
  @override
  bool get storageFull;

  /// Create a copy of ReviewState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReviewStateImplCopyWith<_$ReviewStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
