// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'preview_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$WordSelection {
  String get pageId => throw _privateConstructorUsedError;
  String get paragraphId => throw _privateConstructorUsedError;
  int get start => throw _privateConstructorUsedError;
  int get end => throw _privateConstructorUsedError;

  /// Create a copy of WordSelection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WordSelectionCopyWith<WordSelection> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WordSelectionCopyWith<$Res> {
  factory $WordSelectionCopyWith(
    WordSelection value,
    $Res Function(WordSelection) then,
  ) = _$WordSelectionCopyWithImpl<$Res, WordSelection>;
  @useResult
  $Res call({String pageId, String paragraphId, int start, int end});
}

/// @nodoc
class _$WordSelectionCopyWithImpl<$Res, $Val extends WordSelection>
    implements $WordSelectionCopyWith<$Res> {
  _$WordSelectionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WordSelection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pageId = null,
    Object? paragraphId = null,
    Object? start = null,
    Object? end = null,
  }) {
    return _then(
      _value.copyWith(
            pageId: null == pageId
                ? _value.pageId
                : pageId // ignore: cast_nullable_to_non_nullable
                      as String,
            paragraphId: null == paragraphId
                ? _value.paragraphId
                : paragraphId // ignore: cast_nullable_to_non_nullable
                      as String,
            start: null == start
                ? _value.start
                : start // ignore: cast_nullable_to_non_nullable
                      as int,
            end: null == end
                ? _value.end
                : end // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WordSelectionImplCopyWith<$Res>
    implements $WordSelectionCopyWith<$Res> {
  factory _$$WordSelectionImplCopyWith(
    _$WordSelectionImpl value,
    $Res Function(_$WordSelectionImpl) then,
  ) = __$$WordSelectionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String pageId, String paragraphId, int start, int end});
}

/// @nodoc
class __$$WordSelectionImplCopyWithImpl<$Res>
    extends _$WordSelectionCopyWithImpl<$Res, _$WordSelectionImpl>
    implements _$$WordSelectionImplCopyWith<$Res> {
  __$$WordSelectionImplCopyWithImpl(
    _$WordSelectionImpl _value,
    $Res Function(_$WordSelectionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WordSelection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pageId = null,
    Object? paragraphId = null,
    Object? start = null,
    Object? end = null,
  }) {
    return _then(
      _$WordSelectionImpl(
        pageId: null == pageId
            ? _value.pageId
            : pageId // ignore: cast_nullable_to_non_nullable
                  as String,
        paragraphId: null == paragraphId
            ? _value.paragraphId
            : paragraphId // ignore: cast_nullable_to_non_nullable
                  as String,
        start: null == start
            ? _value.start
            : start // ignore: cast_nullable_to_non_nullable
                  as int,
        end: null == end
            ? _value.end
            : end // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$WordSelectionImpl extends _WordSelection {
  const _$WordSelectionImpl({
    required this.pageId,
    required this.paragraphId,
    required this.start,
    required this.end,
  }) : super._();

  @override
  final String pageId;
  @override
  final String paragraphId;
  @override
  final int start;
  @override
  final int end;

  @override
  String toString() {
    return 'WordSelection(pageId: $pageId, paragraphId: $paragraphId, start: $start, end: $end)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WordSelectionImpl &&
            (identical(other.pageId, pageId) || other.pageId == pageId) &&
            (identical(other.paragraphId, paragraphId) ||
                other.paragraphId == paragraphId) &&
            (identical(other.start, start) || other.start == start) &&
            (identical(other.end, end) || other.end == end));
  }

  @override
  int get hashCode => Object.hash(runtimeType, pageId, paragraphId, start, end);

  /// Create a copy of WordSelection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WordSelectionImplCopyWith<_$WordSelectionImpl> get copyWith =>
      __$$WordSelectionImplCopyWithImpl<_$WordSelectionImpl>(this, _$identity);
}

abstract class _WordSelection extends WordSelection {
  const factory _WordSelection({
    required final String pageId,
    required final String paragraphId,
    required final int start,
    required final int end,
  }) = _$WordSelectionImpl;
  const _WordSelection._() : super._();

  @override
  String get pageId;
  @override
  String get paragraphId;
  @override
  int get start;
  @override
  int get end;

  /// Create a copy of WordSelection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WordSelectionImplCopyWith<_$WordSelectionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PreviewState {
  List<CapturedPage> get pages => throw _privateConstructorUsedError;
  DocumentEdits get edits => throw _privateConstructorUsedError;
  PreviewView get view => throw _privateConstructorUsedError;
  int get currentPage => throw _privateConstructorUsedError;
  ScanColorMode get colorMode => throw _privateConstructorUsedError;

  /// The file name without `.pdf`.
  String get fileStem => throw _privateConstructorUsedError;

  /// Size of the PDF that attach would send now (FR-011 form).
  int get sizeBytes => throw _privateConstructorUsedError;
  bool get editing => throw _privateConstructorUsedError;
  WordSelection? get selection => throw _privateConstructorUsedError;
  bool get attaching => throw _privateConstructorUsedError;
  BuildFailure? get failure => throw _privateConstructorUsedError;

  /// Each recognized page's background (the scan without its recognized words),
  /// by page id, once built.
  Map<String, File> get backgrounds => throw _privateConstructorUsedError;

  /// Create a copy of PreviewState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PreviewStateCopyWith<PreviewState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PreviewStateCopyWith<$Res> {
  factory $PreviewStateCopyWith(
    PreviewState value,
    $Res Function(PreviewState) then,
  ) = _$PreviewStateCopyWithImpl<$Res, PreviewState>;
  @useResult
  $Res call({
    List<CapturedPage> pages,
    DocumentEdits edits,
    PreviewView view,
    int currentPage,
    ScanColorMode colorMode,
    String fileStem,
    int sizeBytes,
    bool editing,
    WordSelection? selection,
    bool attaching,
    BuildFailure? failure,
    Map<String, File> backgrounds,
  });

  $WordSelectionCopyWith<$Res>? get selection;
  $BuildFailureCopyWith<$Res>? get failure;
}

/// @nodoc
class _$PreviewStateCopyWithImpl<$Res, $Val extends PreviewState>
    implements $PreviewStateCopyWith<$Res> {
  _$PreviewStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PreviewState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pages = null,
    Object? edits = null,
    Object? view = null,
    Object? currentPage = null,
    Object? colorMode = null,
    Object? fileStem = null,
    Object? sizeBytes = null,
    Object? editing = null,
    Object? selection = freezed,
    Object? attaching = null,
    Object? failure = freezed,
    Object? backgrounds = null,
  }) {
    return _then(
      _value.copyWith(
            pages: null == pages
                ? _value.pages
                : pages // ignore: cast_nullable_to_non_nullable
                      as List<CapturedPage>,
            edits: null == edits
                ? _value.edits
                : edits // ignore: cast_nullable_to_non_nullable
                      as DocumentEdits,
            view: null == view
                ? _value.view
                : view // ignore: cast_nullable_to_non_nullable
                      as PreviewView,
            currentPage: null == currentPage
                ? _value.currentPage
                : currentPage // ignore: cast_nullable_to_non_nullable
                      as int,
            colorMode: null == colorMode
                ? _value.colorMode
                : colorMode // ignore: cast_nullable_to_non_nullable
                      as ScanColorMode,
            fileStem: null == fileStem
                ? _value.fileStem
                : fileStem // ignore: cast_nullable_to_non_nullable
                      as String,
            sizeBytes: null == sizeBytes
                ? _value.sizeBytes
                : sizeBytes // ignore: cast_nullable_to_non_nullable
                      as int,
            editing: null == editing
                ? _value.editing
                : editing // ignore: cast_nullable_to_non_nullable
                      as bool,
            selection: freezed == selection
                ? _value.selection
                : selection // ignore: cast_nullable_to_non_nullable
                      as WordSelection?,
            attaching: null == attaching
                ? _value.attaching
                : attaching // ignore: cast_nullable_to_non_nullable
                      as bool,
            failure: freezed == failure
                ? _value.failure
                : failure // ignore: cast_nullable_to_non_nullable
                      as BuildFailure?,
            backgrounds: null == backgrounds
                ? _value.backgrounds
                : backgrounds // ignore: cast_nullable_to_non_nullable
                      as Map<String, File>,
          )
          as $Val,
    );
  }

  /// Create a copy of PreviewState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WordSelectionCopyWith<$Res>? get selection {
    if (_value.selection == null) {
      return null;
    }

    return $WordSelectionCopyWith<$Res>(_value.selection!, (value) {
      return _then(_value.copyWith(selection: value) as $Val);
    });
  }

  /// Create a copy of PreviewState
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
abstract class _$$PreviewStateImplCopyWith<$Res>
    implements $PreviewStateCopyWith<$Res> {
  factory _$$PreviewStateImplCopyWith(
    _$PreviewStateImpl value,
    $Res Function(_$PreviewStateImpl) then,
  ) = __$$PreviewStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<CapturedPage> pages,
    DocumentEdits edits,
    PreviewView view,
    int currentPage,
    ScanColorMode colorMode,
    String fileStem,
    int sizeBytes,
    bool editing,
    WordSelection? selection,
    bool attaching,
    BuildFailure? failure,
    Map<String, File> backgrounds,
  });

  @override
  $WordSelectionCopyWith<$Res>? get selection;
  @override
  $BuildFailureCopyWith<$Res>? get failure;
}

/// @nodoc
class __$$PreviewStateImplCopyWithImpl<$Res>
    extends _$PreviewStateCopyWithImpl<$Res, _$PreviewStateImpl>
    implements _$$PreviewStateImplCopyWith<$Res> {
  __$$PreviewStateImplCopyWithImpl(
    _$PreviewStateImpl _value,
    $Res Function(_$PreviewStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PreviewState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pages = null,
    Object? edits = null,
    Object? view = null,
    Object? currentPage = null,
    Object? colorMode = null,
    Object? fileStem = null,
    Object? sizeBytes = null,
    Object? editing = null,
    Object? selection = freezed,
    Object? attaching = null,
    Object? failure = freezed,
    Object? backgrounds = null,
  }) {
    return _then(
      _$PreviewStateImpl(
        pages: null == pages
            ? _value._pages
            : pages // ignore: cast_nullable_to_non_nullable
                  as List<CapturedPage>,
        edits: null == edits
            ? _value.edits
            : edits // ignore: cast_nullable_to_non_nullable
                  as DocumentEdits,
        view: null == view
            ? _value.view
            : view // ignore: cast_nullable_to_non_nullable
                  as PreviewView,
        currentPage: null == currentPage
            ? _value.currentPage
            : currentPage // ignore: cast_nullable_to_non_nullable
                  as int,
        colorMode: null == colorMode
            ? _value.colorMode
            : colorMode // ignore: cast_nullable_to_non_nullable
                  as ScanColorMode,
        fileStem: null == fileStem
            ? _value.fileStem
            : fileStem // ignore: cast_nullable_to_non_nullable
                  as String,
        sizeBytes: null == sizeBytes
            ? _value.sizeBytes
            : sizeBytes // ignore: cast_nullable_to_non_nullable
                  as int,
        editing: null == editing
            ? _value.editing
            : editing // ignore: cast_nullable_to_non_nullable
                  as bool,
        selection: freezed == selection
            ? _value.selection
            : selection // ignore: cast_nullable_to_non_nullable
                  as WordSelection?,
        attaching: null == attaching
            ? _value.attaching
            : attaching // ignore: cast_nullable_to_non_nullable
                  as bool,
        failure: freezed == failure
            ? _value.failure
            : failure // ignore: cast_nullable_to_non_nullable
                  as BuildFailure?,
        backgrounds: null == backgrounds
            ? _value._backgrounds
            : backgrounds // ignore: cast_nullable_to_non_nullable
                  as Map<String, File>,
      ),
    );
  }
}

/// @nodoc

class _$PreviewStateImpl extends _PreviewState {
  const _$PreviewStateImpl({
    required final List<CapturedPage> pages,
    required this.edits,
    required this.view,
    required this.currentPage,
    required this.colorMode,
    required this.fileStem,
    required this.sizeBytes,
    this.editing = false,
    this.selection,
    this.attaching = false,
    this.failure,
    final Map<String, File> backgrounds = const <String, File>{},
  }) : _pages = pages,
       _backgrounds = backgrounds,
       super._();

  final List<CapturedPage> _pages;
  @override
  List<CapturedPage> get pages {
    if (_pages is EqualUnmodifiableListView) return _pages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pages);
  }

  @override
  final DocumentEdits edits;
  @override
  final PreviewView view;
  @override
  final int currentPage;
  @override
  final ScanColorMode colorMode;

  /// The file name without `.pdf`.
  @override
  final String fileStem;

  /// Size of the PDF that attach would send now (FR-011 form).
  @override
  final int sizeBytes;
  @override
  @JsonKey()
  final bool editing;
  @override
  final WordSelection? selection;
  @override
  @JsonKey()
  final bool attaching;
  @override
  final BuildFailure? failure;

  /// Each recognized page's background (the scan without its recognized words),
  /// by page id, once built.
  final Map<String, File> _backgrounds;

  /// Each recognized page's background (the scan without its recognized words),
  /// by page id, once built.
  @override
  @JsonKey()
  Map<String, File> get backgrounds {
    if (_backgrounds is EqualUnmodifiableMapView) return _backgrounds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_backgrounds);
  }

  @override
  String toString() {
    return 'PreviewState(pages: $pages, edits: $edits, view: $view, currentPage: $currentPage, colorMode: $colorMode, fileStem: $fileStem, sizeBytes: $sizeBytes, editing: $editing, selection: $selection, attaching: $attaching, failure: $failure, backgrounds: $backgrounds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PreviewStateImpl &&
            const DeepCollectionEquality().equals(other._pages, _pages) &&
            (identical(other.edits, edits) || other.edits == edits) &&
            (identical(other.view, view) || other.view == view) &&
            (identical(other.currentPage, currentPage) ||
                other.currentPage == currentPage) &&
            (identical(other.colorMode, colorMode) ||
                other.colorMode == colorMode) &&
            (identical(other.fileStem, fileStem) ||
                other.fileStem == fileStem) &&
            (identical(other.sizeBytes, sizeBytes) ||
                other.sizeBytes == sizeBytes) &&
            (identical(other.editing, editing) || other.editing == editing) &&
            (identical(other.selection, selection) ||
                other.selection == selection) &&
            (identical(other.attaching, attaching) ||
                other.attaching == attaching) &&
            (identical(other.failure, failure) || other.failure == failure) &&
            const DeepCollectionEquality().equals(
              other._backgrounds,
              _backgrounds,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_pages),
    edits,
    view,
    currentPage,
    colorMode,
    fileStem,
    sizeBytes,
    editing,
    selection,
    attaching,
    failure,
    const DeepCollectionEquality().hash(_backgrounds),
  );

  /// Create a copy of PreviewState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PreviewStateImplCopyWith<_$PreviewStateImpl> get copyWith =>
      __$$PreviewStateImplCopyWithImpl<_$PreviewStateImpl>(this, _$identity);
}

abstract class _PreviewState extends PreviewState {
  const factory _PreviewState({
    required final List<CapturedPage> pages,
    required final DocumentEdits edits,
    required final PreviewView view,
    required final int currentPage,
    required final ScanColorMode colorMode,
    required final String fileStem,
    required final int sizeBytes,
    final bool editing,
    final WordSelection? selection,
    final bool attaching,
    final BuildFailure? failure,
    final Map<String, File> backgrounds,
  }) = _$PreviewStateImpl;
  const _PreviewState._() : super._();

  @override
  List<CapturedPage> get pages;
  @override
  DocumentEdits get edits;
  @override
  PreviewView get view;
  @override
  int get currentPage;
  @override
  ScanColorMode get colorMode;

  /// The file name without `.pdf`.
  @override
  String get fileStem;

  /// Size of the PDF that attach would send now (FR-011 form).
  @override
  int get sizeBytes;
  @override
  bool get editing;
  @override
  WordSelection? get selection;
  @override
  bool get attaching;
  @override
  BuildFailure? get failure;

  /// Each recognized page's background (the scan without its recognized words),
  /// by page id, once built.
  @override
  Map<String, File> get backgrounds;

  /// Create a copy of PreviewState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PreviewStateImplCopyWith<_$PreviewStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
