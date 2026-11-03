// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scan_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Quad {
  Offset get topLeft => throw _privateConstructorUsedError;
  Offset get topRight => throw _privateConstructorUsedError;
  Offset get bottomRight => throw _privateConstructorUsedError;
  Offset get bottomLeft => throw _privateConstructorUsedError;

  /// Create a copy of Quad
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuadCopyWith<Quad> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuadCopyWith<$Res> {
  factory $QuadCopyWith(Quad value, $Res Function(Quad) then) =
      _$QuadCopyWithImpl<$Res, Quad>;
  @useResult
  $Res call({
    Offset topLeft,
    Offset topRight,
    Offset bottomRight,
    Offset bottomLeft,
  });
}

/// @nodoc
class _$QuadCopyWithImpl<$Res, $Val extends Quad>
    implements $QuadCopyWith<$Res> {
  _$QuadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Quad
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? topLeft = null,
    Object? topRight = null,
    Object? bottomRight = null,
    Object? bottomLeft = null,
  }) {
    return _then(
      _value.copyWith(
            topLeft: null == topLeft
                ? _value.topLeft
                : topLeft // ignore: cast_nullable_to_non_nullable
                      as Offset,
            topRight: null == topRight
                ? _value.topRight
                : topRight // ignore: cast_nullable_to_non_nullable
                      as Offset,
            bottomRight: null == bottomRight
                ? _value.bottomRight
                : bottomRight // ignore: cast_nullable_to_non_nullable
                      as Offset,
            bottomLeft: null == bottomLeft
                ? _value.bottomLeft
                : bottomLeft // ignore: cast_nullable_to_non_nullable
                      as Offset,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$QuadImplCopyWith<$Res> implements $QuadCopyWith<$Res> {
  factory _$$QuadImplCopyWith(
    _$QuadImpl value,
    $Res Function(_$QuadImpl) then,
  ) = __$$QuadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    Offset topLeft,
    Offset topRight,
    Offset bottomRight,
    Offset bottomLeft,
  });
}

/// @nodoc
class __$$QuadImplCopyWithImpl<$Res>
    extends _$QuadCopyWithImpl<$Res, _$QuadImpl>
    implements _$$QuadImplCopyWith<$Res> {
  __$$QuadImplCopyWithImpl(_$QuadImpl _value, $Res Function(_$QuadImpl) _then)
    : super(_value, _then);

  /// Create a copy of Quad
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? topLeft = null,
    Object? topRight = null,
    Object? bottomRight = null,
    Object? bottomLeft = null,
  }) {
    return _then(
      _$QuadImpl(
        topLeft: null == topLeft
            ? _value.topLeft
            : topLeft // ignore: cast_nullable_to_non_nullable
                  as Offset,
        topRight: null == topRight
            ? _value.topRight
            : topRight // ignore: cast_nullable_to_non_nullable
                  as Offset,
        bottomRight: null == bottomRight
            ? _value.bottomRight
            : bottomRight // ignore: cast_nullable_to_non_nullable
                  as Offset,
        bottomLeft: null == bottomLeft
            ? _value.bottomLeft
            : bottomLeft // ignore: cast_nullable_to_non_nullable
                  as Offset,
      ),
    );
  }
}

/// @nodoc

class _$QuadImpl implements _Quad {
  const _$QuadImpl({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  @override
  final Offset topLeft;
  @override
  final Offset topRight;
  @override
  final Offset bottomRight;
  @override
  final Offset bottomLeft;

  @override
  String toString() {
    return 'Quad(topLeft: $topLeft, topRight: $topRight, bottomRight: $bottomRight, bottomLeft: $bottomLeft)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuadImpl &&
            (identical(other.topLeft, topLeft) || other.topLeft == topLeft) &&
            (identical(other.topRight, topRight) ||
                other.topRight == topRight) &&
            (identical(other.bottomRight, bottomRight) ||
                other.bottomRight == bottomRight) &&
            (identical(other.bottomLeft, bottomLeft) ||
                other.bottomLeft == bottomLeft));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, topLeft, topRight, bottomRight, bottomLeft);

  /// Create a copy of Quad
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuadImplCopyWith<_$QuadImpl> get copyWith =>
      __$$QuadImplCopyWithImpl<_$QuadImpl>(this, _$identity);
}

abstract class _Quad implements Quad {
  const factory _Quad({
    required final Offset topLeft,
    required final Offset topRight,
    required final Offset bottomRight,
    required final Offset bottomLeft,
  }) = _$QuadImpl;

  @override
  Offset get topLeft;
  @override
  Offset get topRight;
  @override
  Offset get bottomRight;
  @override
  Offset get bottomLeft;

  /// Create a copy of Quad
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuadImplCopyWith<_$QuadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$Word {
  String get text => throw _privateConstructorUsedError;
  Rect get box => throw _privateConstructorUsedError;
  double get confidence => throw _privateConstructorUsedError;

  /// Create a copy of Word
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WordCopyWith<Word> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WordCopyWith<$Res> {
  factory $WordCopyWith(Word value, $Res Function(Word) then) =
      _$WordCopyWithImpl<$Res, Word>;
  @useResult
  $Res call({String text, Rect box, double confidence});
}

/// @nodoc
class _$WordCopyWithImpl<$Res, $Val extends Word>
    implements $WordCopyWith<$Res> {
  _$WordCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Word
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
    Object? box = null,
    Object? confidence = null,
  }) {
    return _then(
      _value.copyWith(
            text: null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                      as String,
            box: null == box
                ? _value.box
                : box // ignore: cast_nullable_to_non_nullable
                      as Rect,
            confidence: null == confidence
                ? _value.confidence
                : confidence // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WordImplCopyWith<$Res> implements $WordCopyWith<$Res> {
  factory _$$WordImplCopyWith(
    _$WordImpl value,
    $Res Function(_$WordImpl) then,
  ) = __$$WordImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String text, Rect box, double confidence});
}

/// @nodoc
class __$$WordImplCopyWithImpl<$Res>
    extends _$WordCopyWithImpl<$Res, _$WordImpl>
    implements _$$WordImplCopyWith<$Res> {
  __$$WordImplCopyWithImpl(_$WordImpl _value, $Res Function(_$WordImpl) _then)
    : super(_value, _then);

  /// Create a copy of Word
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
    Object? box = null,
    Object? confidence = null,
  }) {
    return _then(
      _$WordImpl(
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
        box: null == box
            ? _value.box
            : box // ignore: cast_nullable_to_non_nullable
                  as Rect,
        confidence: null == confidence
            ? _value.confidence
            : confidence // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc

class _$WordImpl implements _Word {
  const _$WordImpl({
    required this.text,
    required this.box,
    required this.confidence,
  });

  @override
  final String text;
  @override
  final Rect box;
  @override
  final double confidence;

  @override
  String toString() {
    return 'Word(text: $text, box: $box, confidence: $confidence)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WordImpl &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.box, box) || other.box == box) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence));
  }

  @override
  int get hashCode => Object.hash(runtimeType, text, box, confidence);

  /// Create a copy of Word
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WordImplCopyWith<_$WordImpl> get copyWith =>
      __$$WordImplCopyWithImpl<_$WordImpl>(this, _$identity);
}

abstract class _Word implements Word {
  const factory _Word({
    required final String text,
    required final Rect box,
    required final double confidence,
  }) = _$WordImpl;

  @override
  String get text;
  @override
  Rect get box;
  @override
  double get confidence;

  /// Create a copy of Word
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WordImplCopyWith<_$WordImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$Paragraph {
  String get id => throw _privateConstructorUsedError;
  List<Word> get words => throw _privateConstructorUsedError;

  /// Create a copy of Paragraph
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ParagraphCopyWith<Paragraph> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ParagraphCopyWith<$Res> {
  factory $ParagraphCopyWith(Paragraph value, $Res Function(Paragraph) then) =
      _$ParagraphCopyWithImpl<$Res, Paragraph>;
  @useResult
  $Res call({String id, List<Word> words});
}

/// @nodoc
class _$ParagraphCopyWithImpl<$Res, $Val extends Paragraph>
    implements $ParagraphCopyWith<$Res> {
  _$ParagraphCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Paragraph
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? words = null}) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            words: null == words
                ? _value.words
                : words // ignore: cast_nullable_to_non_nullable
                      as List<Word>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ParagraphImplCopyWith<$Res>
    implements $ParagraphCopyWith<$Res> {
  factory _$$ParagraphImplCopyWith(
    _$ParagraphImpl value,
    $Res Function(_$ParagraphImpl) then,
  ) = __$$ParagraphImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, List<Word> words});
}

/// @nodoc
class __$$ParagraphImplCopyWithImpl<$Res>
    extends _$ParagraphCopyWithImpl<$Res, _$ParagraphImpl>
    implements _$$ParagraphImplCopyWith<$Res> {
  __$$ParagraphImplCopyWithImpl(
    _$ParagraphImpl _value,
    $Res Function(_$ParagraphImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Paragraph
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? words = null}) {
    return _then(
      _$ParagraphImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        words: null == words
            ? _value._words
            : words // ignore: cast_nullable_to_non_nullable
                  as List<Word>,
      ),
    );
  }
}

/// @nodoc

class _$ParagraphImpl extends _Paragraph {
  const _$ParagraphImpl({required this.id, required final List<Word> words})
    : _words = words,
      super._();

  @override
  final String id;
  final List<Word> _words;
  @override
  List<Word> get words {
    if (_words is EqualUnmodifiableListView) return _words;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_words);
  }

  @override
  String toString() {
    return 'Paragraph(id: $id, words: $words)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ParagraphImpl &&
            (identical(other.id, id) || other.id == id) &&
            const DeepCollectionEquality().equals(other._words, _words));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, const DeepCollectionEquality().hash(_words));

  /// Create a copy of Paragraph
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ParagraphImplCopyWith<_$ParagraphImpl> get copyWith =>
      __$$ParagraphImplCopyWithImpl<_$ParagraphImpl>(this, _$identity);
}

abstract class _Paragraph extends Paragraph {
  const factory _Paragraph({
    required final String id,
    required final List<Word> words,
  }) = _$ParagraphImpl;
  const _Paragraph._() : super._();

  @override
  String get id;
  @override
  List<Word> get words;

  /// Create a copy of Paragraph
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ParagraphImplCopyWith<_$ParagraphImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PageText {
  RecognitionLanguage get language => throw _privateConstructorUsedError;
  List<Paragraph> get paragraphs => throw _privateConstructorUsedError;

  /// Create a copy of PageText
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PageTextCopyWith<PageText> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PageTextCopyWith<$Res> {
  factory $PageTextCopyWith(PageText value, $Res Function(PageText) then) =
      _$PageTextCopyWithImpl<$Res, PageText>;
  @useResult
  $Res call({RecognitionLanguage language, List<Paragraph> paragraphs});
}

/// @nodoc
class _$PageTextCopyWithImpl<$Res, $Val extends PageText>
    implements $PageTextCopyWith<$Res> {
  _$PageTextCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PageText
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? language = null, Object? paragraphs = null}) {
    return _then(
      _value.copyWith(
            language: null == language
                ? _value.language
                : language // ignore: cast_nullable_to_non_nullable
                      as RecognitionLanguage,
            paragraphs: null == paragraphs
                ? _value.paragraphs
                : paragraphs // ignore: cast_nullable_to_non_nullable
                      as List<Paragraph>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PageTextImplCopyWith<$Res>
    implements $PageTextCopyWith<$Res> {
  factory _$$PageTextImplCopyWith(
    _$PageTextImpl value,
    $Res Function(_$PageTextImpl) then,
  ) = __$$PageTextImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({RecognitionLanguage language, List<Paragraph> paragraphs});
}

/// @nodoc
class __$$PageTextImplCopyWithImpl<$Res>
    extends _$PageTextCopyWithImpl<$Res, _$PageTextImpl>
    implements _$$PageTextImplCopyWith<$Res> {
  __$$PageTextImplCopyWithImpl(
    _$PageTextImpl _value,
    $Res Function(_$PageTextImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PageText
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? language = null, Object? paragraphs = null}) {
    return _then(
      _$PageTextImpl(
        language: null == language
            ? _value.language
            : language // ignore: cast_nullable_to_non_nullable
                  as RecognitionLanguage,
        paragraphs: null == paragraphs
            ? _value._paragraphs
            : paragraphs // ignore: cast_nullable_to_non_nullable
                  as List<Paragraph>,
      ),
    );
  }
}

/// @nodoc

class _$PageTextImpl implements _PageText {
  const _$PageTextImpl({
    required this.language,
    required final List<Paragraph> paragraphs,
  }) : _paragraphs = paragraphs;

  @override
  final RecognitionLanguage language;
  final List<Paragraph> _paragraphs;
  @override
  List<Paragraph> get paragraphs {
    if (_paragraphs is EqualUnmodifiableListView) return _paragraphs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_paragraphs);
  }

  @override
  String toString() {
    return 'PageText(language: $language, paragraphs: $paragraphs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PageTextImpl &&
            (identical(other.language, language) ||
                other.language == language) &&
            const DeepCollectionEquality().equals(
              other._paragraphs,
              _paragraphs,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    language,
    const DeepCollectionEquality().hash(_paragraphs),
  );

  /// Create a copy of PageText
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PageTextImplCopyWith<_$PageTextImpl> get copyWith =>
      __$$PageTextImplCopyWithImpl<_$PageTextImpl>(this, _$identity);
}

abstract class _PageText implements PageText {
  const factory _PageText({
    required final RecognitionLanguage language,
    required final List<Paragraph> paragraphs,
  }) = _$PageTextImpl;

  @override
  RecognitionLanguage get language;
  @override
  List<Paragraph> get paragraphs;

  /// Create a copy of PageText
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PageTextImplCopyWith<_$PageTextImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$RecognitionState {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() pending,
    required TResult Function(PageText text) done,
    required TResult Function() noText,
    required TResult Function() failed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? pending,
    TResult? Function(PageText text)? done,
    TResult? Function()? noText,
    TResult? Function()? failed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? pending,
    TResult Function(PageText text)? done,
    TResult Function()? noText,
    TResult Function()? failed,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RecognitionPending value) pending,
    required TResult Function(RecognitionDone value) done,
    required TResult Function(RecognitionNoText value) noText,
    required TResult Function(RecognitionFailedState value) failed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RecognitionPending value)? pending,
    TResult? Function(RecognitionDone value)? done,
    TResult? Function(RecognitionNoText value)? noText,
    TResult? Function(RecognitionFailedState value)? failed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RecognitionPending value)? pending,
    TResult Function(RecognitionDone value)? done,
    TResult Function(RecognitionNoText value)? noText,
    TResult Function(RecognitionFailedState value)? failed,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecognitionStateCopyWith<$Res> {
  factory $RecognitionStateCopyWith(
    RecognitionState value,
    $Res Function(RecognitionState) then,
  ) = _$RecognitionStateCopyWithImpl<$Res, RecognitionState>;
}

/// @nodoc
class _$RecognitionStateCopyWithImpl<$Res, $Val extends RecognitionState>
    implements $RecognitionStateCopyWith<$Res> {
  _$RecognitionStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecognitionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$RecognitionPendingImplCopyWith<$Res> {
  factory _$$RecognitionPendingImplCopyWith(
    _$RecognitionPendingImpl value,
    $Res Function(_$RecognitionPendingImpl) then,
  ) = __$$RecognitionPendingImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$RecognitionPendingImplCopyWithImpl<$Res>
    extends _$RecognitionStateCopyWithImpl<$Res, _$RecognitionPendingImpl>
    implements _$$RecognitionPendingImplCopyWith<$Res> {
  __$$RecognitionPendingImplCopyWithImpl(
    _$RecognitionPendingImpl _value,
    $Res Function(_$RecognitionPendingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecognitionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$RecognitionPendingImpl implements RecognitionPending {
  const _$RecognitionPendingImpl();

  @override
  String toString() {
    return 'RecognitionState.pending()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$RecognitionPendingImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() pending,
    required TResult Function(PageText text) done,
    required TResult Function() noText,
    required TResult Function() failed,
  }) {
    return pending();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? pending,
    TResult? Function(PageText text)? done,
    TResult? Function()? noText,
    TResult? Function()? failed,
  }) {
    return pending?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? pending,
    TResult Function(PageText text)? done,
    TResult Function()? noText,
    TResult Function()? failed,
    required TResult orElse(),
  }) {
    if (pending != null) {
      return pending();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RecognitionPending value) pending,
    required TResult Function(RecognitionDone value) done,
    required TResult Function(RecognitionNoText value) noText,
    required TResult Function(RecognitionFailedState value) failed,
  }) {
    return pending(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RecognitionPending value)? pending,
    TResult? Function(RecognitionDone value)? done,
    TResult? Function(RecognitionNoText value)? noText,
    TResult? Function(RecognitionFailedState value)? failed,
  }) {
    return pending?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RecognitionPending value)? pending,
    TResult Function(RecognitionDone value)? done,
    TResult Function(RecognitionNoText value)? noText,
    TResult Function(RecognitionFailedState value)? failed,
    required TResult orElse(),
  }) {
    if (pending != null) {
      return pending(this);
    }
    return orElse();
  }
}

abstract class RecognitionPending implements RecognitionState {
  const factory RecognitionPending() = _$RecognitionPendingImpl;
}

/// @nodoc
abstract class _$$RecognitionDoneImplCopyWith<$Res> {
  factory _$$RecognitionDoneImplCopyWith(
    _$RecognitionDoneImpl value,
    $Res Function(_$RecognitionDoneImpl) then,
  ) = __$$RecognitionDoneImplCopyWithImpl<$Res>;
  @useResult
  $Res call({PageText text});

  $PageTextCopyWith<$Res> get text;
}

/// @nodoc
class __$$RecognitionDoneImplCopyWithImpl<$Res>
    extends _$RecognitionStateCopyWithImpl<$Res, _$RecognitionDoneImpl>
    implements _$$RecognitionDoneImplCopyWith<$Res> {
  __$$RecognitionDoneImplCopyWithImpl(
    _$RecognitionDoneImpl _value,
    $Res Function(_$RecognitionDoneImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecognitionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? text = null}) {
    return _then(
      _$RecognitionDoneImpl(
        null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as PageText,
      ),
    );
  }

  /// Create a copy of RecognitionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PageTextCopyWith<$Res> get text {
    return $PageTextCopyWith<$Res>(_value.text, (value) {
      return _then(_value.copyWith(text: value));
    });
  }
}

/// @nodoc

class _$RecognitionDoneImpl implements RecognitionDone {
  const _$RecognitionDoneImpl(this.text);

  @override
  final PageText text;

  @override
  String toString() {
    return 'RecognitionState.done(text: $text)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecognitionDoneImpl &&
            (identical(other.text, text) || other.text == text));
  }

  @override
  int get hashCode => Object.hash(runtimeType, text);

  /// Create a copy of RecognitionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecognitionDoneImplCopyWith<_$RecognitionDoneImpl> get copyWith =>
      __$$RecognitionDoneImplCopyWithImpl<_$RecognitionDoneImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() pending,
    required TResult Function(PageText text) done,
    required TResult Function() noText,
    required TResult Function() failed,
  }) {
    return done(text);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? pending,
    TResult? Function(PageText text)? done,
    TResult? Function()? noText,
    TResult? Function()? failed,
  }) {
    return done?.call(text);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? pending,
    TResult Function(PageText text)? done,
    TResult Function()? noText,
    TResult Function()? failed,
    required TResult orElse(),
  }) {
    if (done != null) {
      return done(text);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RecognitionPending value) pending,
    required TResult Function(RecognitionDone value) done,
    required TResult Function(RecognitionNoText value) noText,
    required TResult Function(RecognitionFailedState value) failed,
  }) {
    return done(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RecognitionPending value)? pending,
    TResult? Function(RecognitionDone value)? done,
    TResult? Function(RecognitionNoText value)? noText,
    TResult? Function(RecognitionFailedState value)? failed,
  }) {
    return done?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RecognitionPending value)? pending,
    TResult Function(RecognitionDone value)? done,
    TResult Function(RecognitionNoText value)? noText,
    TResult Function(RecognitionFailedState value)? failed,
    required TResult orElse(),
  }) {
    if (done != null) {
      return done(this);
    }
    return orElse();
  }
}

abstract class RecognitionDone implements RecognitionState {
  const factory RecognitionDone(final PageText text) = _$RecognitionDoneImpl;

  PageText get text;

  /// Create a copy of RecognitionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecognitionDoneImplCopyWith<_$RecognitionDoneImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RecognitionNoTextImplCopyWith<$Res> {
  factory _$$RecognitionNoTextImplCopyWith(
    _$RecognitionNoTextImpl value,
    $Res Function(_$RecognitionNoTextImpl) then,
  ) = __$$RecognitionNoTextImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$RecognitionNoTextImplCopyWithImpl<$Res>
    extends _$RecognitionStateCopyWithImpl<$Res, _$RecognitionNoTextImpl>
    implements _$$RecognitionNoTextImplCopyWith<$Res> {
  __$$RecognitionNoTextImplCopyWithImpl(
    _$RecognitionNoTextImpl _value,
    $Res Function(_$RecognitionNoTextImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecognitionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$RecognitionNoTextImpl implements RecognitionNoText {
  const _$RecognitionNoTextImpl();

  @override
  String toString() {
    return 'RecognitionState.noText()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$RecognitionNoTextImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() pending,
    required TResult Function(PageText text) done,
    required TResult Function() noText,
    required TResult Function() failed,
  }) {
    return noText();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? pending,
    TResult? Function(PageText text)? done,
    TResult? Function()? noText,
    TResult? Function()? failed,
  }) {
    return noText?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? pending,
    TResult Function(PageText text)? done,
    TResult Function()? noText,
    TResult Function()? failed,
    required TResult orElse(),
  }) {
    if (noText != null) {
      return noText();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RecognitionPending value) pending,
    required TResult Function(RecognitionDone value) done,
    required TResult Function(RecognitionNoText value) noText,
    required TResult Function(RecognitionFailedState value) failed,
  }) {
    return noText(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RecognitionPending value)? pending,
    TResult? Function(RecognitionDone value)? done,
    TResult? Function(RecognitionNoText value)? noText,
    TResult? Function(RecognitionFailedState value)? failed,
  }) {
    return noText?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RecognitionPending value)? pending,
    TResult Function(RecognitionDone value)? done,
    TResult Function(RecognitionNoText value)? noText,
    TResult Function(RecognitionFailedState value)? failed,
    required TResult orElse(),
  }) {
    if (noText != null) {
      return noText(this);
    }
    return orElse();
  }
}

abstract class RecognitionNoText implements RecognitionState {
  const factory RecognitionNoText() = _$RecognitionNoTextImpl;
}

/// @nodoc
abstract class _$$RecognitionFailedStateImplCopyWith<$Res> {
  factory _$$RecognitionFailedStateImplCopyWith(
    _$RecognitionFailedStateImpl value,
    $Res Function(_$RecognitionFailedStateImpl) then,
  ) = __$$RecognitionFailedStateImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$RecognitionFailedStateImplCopyWithImpl<$Res>
    extends _$RecognitionStateCopyWithImpl<$Res, _$RecognitionFailedStateImpl>
    implements _$$RecognitionFailedStateImplCopyWith<$Res> {
  __$$RecognitionFailedStateImplCopyWithImpl(
    _$RecognitionFailedStateImpl _value,
    $Res Function(_$RecognitionFailedStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecognitionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$RecognitionFailedStateImpl implements RecognitionFailedState {
  const _$RecognitionFailedStateImpl();

  @override
  String toString() {
    return 'RecognitionState.failed()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecognitionFailedStateImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() pending,
    required TResult Function(PageText text) done,
    required TResult Function() noText,
    required TResult Function() failed,
  }) {
    return failed();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? pending,
    TResult? Function(PageText text)? done,
    TResult? Function()? noText,
    TResult? Function()? failed,
  }) {
    return failed?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? pending,
    TResult Function(PageText text)? done,
    TResult Function()? noText,
    TResult Function()? failed,
    required TResult orElse(),
  }) {
    if (failed != null) {
      return failed();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RecognitionPending value) pending,
    required TResult Function(RecognitionDone value) done,
    required TResult Function(RecognitionNoText value) noText,
    required TResult Function(RecognitionFailedState value) failed,
  }) {
    return failed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RecognitionPending value)? pending,
    TResult? Function(RecognitionDone value)? done,
    TResult? Function(RecognitionNoText value)? noText,
    TResult? Function(RecognitionFailedState value)? failed,
  }) {
    return failed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RecognitionPending value)? pending,
    TResult Function(RecognitionDone value)? done,
    TResult Function(RecognitionNoText value)? noText,
    TResult Function(RecognitionFailedState value)? failed,
    required TResult orElse(),
  }) {
    if (failed != null) {
      return failed(this);
    }
    return orElse();
  }
}

abstract class RecognitionFailedState implements RecognitionState {
  const factory RecognitionFailedState() = _$RecognitionFailedStateImpl;
}

/// @nodoc
mixin _$CapturedPage {
  String get id => throw _privateConstructorUsedError;

  /// The original capture, kept for corner re-adjust (story 12).
  File get rawFile => throw _privateConstructorUsedError;
  Quad get corners => throw _privateConstructorUsedError;
  Set<PageFilter> get filters => throw _privateConstructorUsedError;

  /// Warped and filtered image the user sees; the image-form PDF page.
  File get preparedFile => throw _privateConstructorUsedError;

  /// Hidden recognition input: [preparedFile] plus shadow removal and
  /// binarization. Never shown or put in the PDF.
  File get ocrInputFile => throw _privateConstructorUsedError;
  RecognitionState get recognition => throw _privateConstructorUsedError;

  /// Create a copy of CapturedPage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CapturedPageCopyWith<CapturedPage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CapturedPageCopyWith<$Res> {
  factory $CapturedPageCopyWith(
    CapturedPage value,
    $Res Function(CapturedPage) then,
  ) = _$CapturedPageCopyWithImpl<$Res, CapturedPage>;
  @useResult
  $Res call({
    String id,
    File rawFile,
    Quad corners,
    Set<PageFilter> filters,
    File preparedFile,
    File ocrInputFile,
    RecognitionState recognition,
  });

  $QuadCopyWith<$Res> get corners;
  $RecognitionStateCopyWith<$Res> get recognition;
}

/// @nodoc
class _$CapturedPageCopyWithImpl<$Res, $Val extends CapturedPage>
    implements $CapturedPageCopyWith<$Res> {
  _$CapturedPageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CapturedPage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? rawFile = null,
    Object? corners = null,
    Object? filters = null,
    Object? preparedFile = null,
    Object? ocrInputFile = null,
    Object? recognition = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            rawFile: null == rawFile
                ? _value.rawFile
                : rawFile // ignore: cast_nullable_to_non_nullable
                      as File,
            corners: null == corners
                ? _value.corners
                : corners // ignore: cast_nullable_to_non_nullable
                      as Quad,
            filters: null == filters
                ? _value.filters
                : filters // ignore: cast_nullable_to_non_nullable
                      as Set<PageFilter>,
            preparedFile: null == preparedFile
                ? _value.preparedFile
                : preparedFile // ignore: cast_nullable_to_non_nullable
                      as File,
            ocrInputFile: null == ocrInputFile
                ? _value.ocrInputFile
                : ocrInputFile // ignore: cast_nullable_to_non_nullable
                      as File,
            recognition: null == recognition
                ? _value.recognition
                : recognition // ignore: cast_nullable_to_non_nullable
                      as RecognitionState,
          )
          as $Val,
    );
  }

  /// Create a copy of CapturedPage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $QuadCopyWith<$Res> get corners {
    return $QuadCopyWith<$Res>(_value.corners, (value) {
      return _then(_value.copyWith(corners: value) as $Val);
    });
  }

  /// Create a copy of CapturedPage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RecognitionStateCopyWith<$Res> get recognition {
    return $RecognitionStateCopyWith<$Res>(_value.recognition, (value) {
      return _then(_value.copyWith(recognition: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CapturedPageImplCopyWith<$Res>
    implements $CapturedPageCopyWith<$Res> {
  factory _$$CapturedPageImplCopyWith(
    _$CapturedPageImpl value,
    $Res Function(_$CapturedPageImpl) then,
  ) = __$$CapturedPageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    File rawFile,
    Quad corners,
    Set<PageFilter> filters,
    File preparedFile,
    File ocrInputFile,
    RecognitionState recognition,
  });

  @override
  $QuadCopyWith<$Res> get corners;
  @override
  $RecognitionStateCopyWith<$Res> get recognition;
}

/// @nodoc
class __$$CapturedPageImplCopyWithImpl<$Res>
    extends _$CapturedPageCopyWithImpl<$Res, _$CapturedPageImpl>
    implements _$$CapturedPageImplCopyWith<$Res> {
  __$$CapturedPageImplCopyWithImpl(
    _$CapturedPageImpl _value,
    $Res Function(_$CapturedPageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CapturedPage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? rawFile = null,
    Object? corners = null,
    Object? filters = null,
    Object? preparedFile = null,
    Object? ocrInputFile = null,
    Object? recognition = null,
  }) {
    return _then(
      _$CapturedPageImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        rawFile: null == rawFile
            ? _value.rawFile
            : rawFile // ignore: cast_nullable_to_non_nullable
                  as File,
        corners: null == corners
            ? _value.corners
            : corners // ignore: cast_nullable_to_non_nullable
                  as Quad,
        filters: null == filters
            ? _value._filters
            : filters // ignore: cast_nullable_to_non_nullable
                  as Set<PageFilter>,
        preparedFile: null == preparedFile
            ? _value.preparedFile
            : preparedFile // ignore: cast_nullable_to_non_nullable
                  as File,
        ocrInputFile: null == ocrInputFile
            ? _value.ocrInputFile
            : ocrInputFile // ignore: cast_nullable_to_non_nullable
                  as File,
        recognition: null == recognition
            ? _value.recognition
            : recognition // ignore: cast_nullable_to_non_nullable
                  as RecognitionState,
      ),
    );
  }
}

/// @nodoc

class _$CapturedPageImpl implements _CapturedPage {
  const _$CapturedPageImpl({
    required this.id,
    required this.rawFile,
    required this.corners,
    required final Set<PageFilter> filters,
    required this.preparedFile,
    required this.ocrInputFile,
    required this.recognition,
  }) : _filters = filters;

  @override
  final String id;

  /// The original capture, kept for corner re-adjust (story 12).
  @override
  final File rawFile;
  @override
  final Quad corners;
  final Set<PageFilter> _filters;
  @override
  Set<PageFilter> get filters {
    if (_filters is EqualUnmodifiableSetView) return _filters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_filters);
  }

  /// Warped and filtered image the user sees; the image-form PDF page.
  @override
  final File preparedFile;

  /// Hidden recognition input: [preparedFile] plus shadow removal and
  /// binarization. Never shown or put in the PDF.
  @override
  final File ocrInputFile;
  @override
  final RecognitionState recognition;

  @override
  String toString() {
    return 'CapturedPage(id: $id, rawFile: $rawFile, corners: $corners, filters: $filters, preparedFile: $preparedFile, ocrInputFile: $ocrInputFile, recognition: $recognition)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CapturedPageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.rawFile, rawFile) || other.rawFile == rawFile) &&
            (identical(other.corners, corners) || other.corners == corners) &&
            const DeepCollectionEquality().equals(other._filters, _filters) &&
            (identical(other.preparedFile, preparedFile) ||
                other.preparedFile == preparedFile) &&
            (identical(other.ocrInputFile, ocrInputFile) ||
                other.ocrInputFile == ocrInputFile) &&
            (identical(other.recognition, recognition) ||
                other.recognition == recognition));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    rawFile,
    corners,
    const DeepCollectionEquality().hash(_filters),
    preparedFile,
    ocrInputFile,
    recognition,
  );

  /// Create a copy of CapturedPage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CapturedPageImplCopyWith<_$CapturedPageImpl> get copyWith =>
      __$$CapturedPageImplCopyWithImpl<_$CapturedPageImpl>(this, _$identity);
}

abstract class _CapturedPage implements CapturedPage {
  const factory _CapturedPage({
    required final String id,
    required final File rawFile,
    required final Quad corners,
    required final Set<PageFilter> filters,
    required final File preparedFile,
    required final File ocrInputFile,
    required final RecognitionState recognition,
  }) = _$CapturedPageImpl;

  @override
  String get id;

  /// The original capture, kept for corner re-adjust (story 12).
  @override
  File get rawFile;
  @override
  Quad get corners;
  @override
  Set<PageFilter> get filters;

  /// Warped and filtered image the user sees; the image-form PDF page.
  @override
  File get preparedFile;

  /// Hidden recognition input: [preparedFile] plus shadow removal and
  /// binarization. Never shown or put in the PDF.
  @override
  File get ocrInputFile;
  @override
  RecognitionState get recognition;

  /// Create a copy of CapturedPage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CapturedPageImplCopyWith<_$CapturedPageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PageMove {
  int get fromIndex => throw _privateConstructorUsedError;
  int get toIndex => throw _privateConstructorUsedError;

  /// Create a copy of PageMove
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PageMoveCopyWith<PageMove> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PageMoveCopyWith<$Res> {
  factory $PageMoveCopyWith(PageMove value, $Res Function(PageMove) then) =
      _$PageMoveCopyWithImpl<$Res, PageMove>;
  @useResult
  $Res call({int fromIndex, int toIndex});
}

/// @nodoc
class _$PageMoveCopyWithImpl<$Res, $Val extends PageMove>
    implements $PageMoveCopyWith<$Res> {
  _$PageMoveCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PageMove
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? fromIndex = null, Object? toIndex = null}) {
    return _then(
      _value.copyWith(
            fromIndex: null == fromIndex
                ? _value.fromIndex
                : fromIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            toIndex: null == toIndex
                ? _value.toIndex
                : toIndex // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PageMoveImplCopyWith<$Res>
    implements $PageMoveCopyWith<$Res> {
  factory _$$PageMoveImplCopyWith(
    _$PageMoveImpl value,
    $Res Function(_$PageMoveImpl) then,
  ) = __$$PageMoveImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int fromIndex, int toIndex});
}

/// @nodoc
class __$$PageMoveImplCopyWithImpl<$Res>
    extends _$PageMoveCopyWithImpl<$Res, _$PageMoveImpl>
    implements _$$PageMoveImplCopyWith<$Res> {
  __$$PageMoveImplCopyWithImpl(
    _$PageMoveImpl _value,
    $Res Function(_$PageMoveImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PageMove
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? fromIndex = null, Object? toIndex = null}) {
    return _then(
      _$PageMoveImpl(
        fromIndex: null == fromIndex
            ? _value.fromIndex
            : fromIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        toIndex: null == toIndex
            ? _value.toIndex
            : toIndex // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$PageMoveImpl implements _PageMove {
  const _$PageMoveImpl({required this.fromIndex, required this.toIndex});

  @override
  final int fromIndex;
  @override
  final int toIndex;

  @override
  String toString() {
    return 'PageMove(fromIndex: $fromIndex, toIndex: $toIndex)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PageMoveImpl &&
            (identical(other.fromIndex, fromIndex) ||
                other.fromIndex == fromIndex) &&
            (identical(other.toIndex, toIndex) || other.toIndex == toIndex));
  }

  @override
  int get hashCode => Object.hash(runtimeType, fromIndex, toIndex);

  /// Create a copy of PageMove
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PageMoveImplCopyWith<_$PageMoveImpl> get copyWith =>
      __$$PageMoveImplCopyWithImpl<_$PageMoveImpl>(this, _$identity);
}

abstract class _PageMove implements PageMove {
  const factory _PageMove({
    required final int fromIndex,
    required final int toIndex,
  }) = _$PageMoveImpl;

  @override
  int get fromIndex;
  @override
  int get toIndex;

  /// Create a copy of PageMove
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PageMoveImplCopyWith<_$PageMoveImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ScanSession {
  String get id => throw _privateConstructorUsedError;
  Directory get dir => throw _privateConstructorUsedError;

  /// Review order; the list order is the PDF order (FR-011).
  List<CapturedPage> get pages => throw _privateConstructorUsedError;
  PageMove? get lastMove => throw _privateConstructorUsedError;
  CaptureMode get captureMode => throw _privateConstructorUsedError;
  DateTime get startedAt => throw _privateConstructorUsedError;

  /// Null means no page limit (FR-009).
  int? get maxPages => throw _privateConstructorUsedError;

  /// Create a copy of ScanSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ScanSessionCopyWith<ScanSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ScanSessionCopyWith<$Res> {
  factory $ScanSessionCopyWith(
    ScanSession value,
    $Res Function(ScanSession) then,
  ) = _$ScanSessionCopyWithImpl<$Res, ScanSession>;
  @useResult
  $Res call({
    String id,
    Directory dir,
    List<CapturedPage> pages,
    PageMove? lastMove,
    CaptureMode captureMode,
    DateTime startedAt,
    int? maxPages,
  });

  $PageMoveCopyWith<$Res>? get lastMove;
}

/// @nodoc
class _$ScanSessionCopyWithImpl<$Res, $Val extends ScanSession>
    implements $ScanSessionCopyWith<$Res> {
  _$ScanSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ScanSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? dir = null,
    Object? pages = null,
    Object? lastMove = freezed,
    Object? captureMode = null,
    Object? startedAt = null,
    Object? maxPages = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            dir: null == dir
                ? _value.dir
                : dir // ignore: cast_nullable_to_non_nullable
                      as Directory,
            pages: null == pages
                ? _value.pages
                : pages // ignore: cast_nullable_to_non_nullable
                      as List<CapturedPage>,
            lastMove: freezed == lastMove
                ? _value.lastMove
                : lastMove // ignore: cast_nullable_to_non_nullable
                      as PageMove?,
            captureMode: null == captureMode
                ? _value.captureMode
                : captureMode // ignore: cast_nullable_to_non_nullable
                      as CaptureMode,
            startedAt: null == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            maxPages: freezed == maxPages
                ? _value.maxPages
                : maxPages // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }

  /// Create a copy of ScanSession
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
abstract class _$$ScanSessionImplCopyWith<$Res>
    implements $ScanSessionCopyWith<$Res> {
  factory _$$ScanSessionImplCopyWith(
    _$ScanSessionImpl value,
    $Res Function(_$ScanSessionImpl) then,
  ) = __$$ScanSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    Directory dir,
    List<CapturedPage> pages,
    PageMove? lastMove,
    CaptureMode captureMode,
    DateTime startedAt,
    int? maxPages,
  });

  @override
  $PageMoveCopyWith<$Res>? get lastMove;
}

/// @nodoc
class __$$ScanSessionImplCopyWithImpl<$Res>
    extends _$ScanSessionCopyWithImpl<$Res, _$ScanSessionImpl>
    implements _$$ScanSessionImplCopyWith<$Res> {
  __$$ScanSessionImplCopyWithImpl(
    _$ScanSessionImpl _value,
    $Res Function(_$ScanSessionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScanSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? dir = null,
    Object? pages = null,
    Object? lastMove = freezed,
    Object? captureMode = null,
    Object? startedAt = null,
    Object? maxPages = freezed,
  }) {
    return _then(
      _$ScanSessionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        dir: null == dir
            ? _value.dir
            : dir // ignore: cast_nullable_to_non_nullable
                  as Directory,
        pages: null == pages
            ? _value._pages
            : pages // ignore: cast_nullable_to_non_nullable
                  as List<CapturedPage>,
        lastMove: freezed == lastMove
            ? _value.lastMove
            : lastMove // ignore: cast_nullable_to_non_nullable
                  as PageMove?,
        captureMode: null == captureMode
            ? _value.captureMode
            : captureMode // ignore: cast_nullable_to_non_nullable
                  as CaptureMode,
        startedAt: null == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        maxPages: freezed == maxPages
            ? _value.maxPages
            : maxPages // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc

class _$ScanSessionImpl implements _ScanSession {
  const _$ScanSessionImpl({
    required this.id,
    required this.dir,
    required final List<CapturedPage> pages,
    this.lastMove,
    required this.captureMode,
    required this.startedAt,
    this.maxPages,
  }) : _pages = pages;

  @override
  final String id;
  @override
  final Directory dir;

  /// Review order; the list order is the PDF order (FR-011).
  final List<CapturedPage> _pages;

  /// Review order; the list order is the PDF order (FR-011).
  @override
  List<CapturedPage> get pages {
    if (_pages is EqualUnmodifiableListView) return _pages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pages);
  }

  @override
  final PageMove? lastMove;
  @override
  final CaptureMode captureMode;
  @override
  final DateTime startedAt;

  /// Null means no page limit (FR-009).
  @override
  final int? maxPages;

  @override
  String toString() {
    return 'ScanSession(id: $id, dir: $dir, pages: $pages, lastMove: $lastMove, captureMode: $captureMode, startedAt: $startedAt, maxPages: $maxPages)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ScanSessionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.dir, dir) || other.dir == dir) &&
            const DeepCollectionEquality().equals(other._pages, _pages) &&
            (identical(other.lastMove, lastMove) ||
                other.lastMove == lastMove) &&
            (identical(other.captureMode, captureMode) ||
                other.captureMode == captureMode) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.maxPages, maxPages) ||
                other.maxPages == maxPages));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    dir,
    const DeepCollectionEquality().hash(_pages),
    lastMove,
    captureMode,
    startedAt,
    maxPages,
  );

  /// Create a copy of ScanSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ScanSessionImplCopyWith<_$ScanSessionImpl> get copyWith =>
      __$$ScanSessionImplCopyWithImpl<_$ScanSessionImpl>(this, _$identity);
}

abstract class _ScanSession implements ScanSession {
  const factory _ScanSession({
    required final String id,
    required final Directory dir,
    required final List<CapturedPage> pages,
    final PageMove? lastMove,
    required final CaptureMode captureMode,
    required final DateTime startedAt,
    final int? maxPages,
  }) = _$ScanSessionImpl;

  @override
  String get id;
  @override
  Directory get dir;

  /// Review order; the list order is the PDF order (FR-011).
  @override
  List<CapturedPage> get pages;
  @override
  PageMove? get lastMove;
  @override
  CaptureMode get captureMode;
  @override
  DateTime get startedAt;

  /// Null means no page limit (FR-009).
  @override
  int? get maxPages;

  /// Create a copy of ScanSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ScanSessionImplCopyWith<_$ScanSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
