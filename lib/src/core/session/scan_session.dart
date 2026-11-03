import 'dart:io';
import 'dart:ui' show Offset, Rect;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'scan_session.freezed.dart';

/// How pages are captured (FR-003).
enum CaptureMode { auto, manual }

/// Recognition language chosen per page (FR-062).
enum RecognitionLanguage { ar, en }

/// User-visible page filters (story 13, research R3). Combinable.
enum PageFilter {
  original,
  autoEnhance,
  sharpenText,
  removeShadows,
  highContrast,
  grayscale,
  blackWhite,
}

/// Color of image-form PDF pages (story 14).
enum ScanColorMode { color, gray, bw }

/// Four page corners, in coordinates normalized to the image (0 to 1), so they
/// survive any re-encoding of the page.
@freezed
abstract class Quad with _$Quad {
  const factory Quad({
    required Offset topLeft,
    required Offset topRight,
    required Offset bottomRight,
    required Offset bottomLeft,
  }) = _Quad;

  /// The whole image: used when no page edges were found (FR-005).
  static const Quad fullFrame = Quad(
    topLeft: Offset(0, 0),
    topRight: Offset(1, 0),
    bottomRight: Offset(1, 1),
    bottomLeft: Offset(0, 1),
  );
}

/// One recognized word with its box in image pixels.
@freezed
abstract class Word with _$Word {
  const factory Word({
    required String text,
    required Rect box,
    required double confidence,
  }) = _Word;
}

/// One paragraph of a page, its words in logical reading order.
@freezed
abstract class Paragraph with _$Paragraph {
  const Paragraph._();

  const factory Paragraph({required String id, required List<Word> words}) =
      _Paragraph;

  String get text => words.map((Word w) => w.text).join(' ');
}

/// Post-processed text of one page (research R6).
@freezed
abstract class PageText with _$PageText {
  const factory PageText({
    required RecognitionLanguage language,
    required List<Paragraph> paragraphs,
  }) = _PageText;
}

/// Where a page's text recognition stands.
@freezed
sealed class RecognitionState with _$RecognitionState {
  const factory RecognitionState.pending() = RecognitionPending;
  const factory RecognitionState.done(PageText text) = RecognitionDone;

  /// Recognition ran and found no words: the page stays as an image.
  const factory RecognitionState.noText() = RecognitionNoText;
  const factory RecognitionState.failed() = RecognitionFailedState;
}

/// One captured page and the files derived from it (data-model).
@freezed
abstract class CapturedPage with _$CapturedPage {
  const factory CapturedPage({
    required String id,

    /// The original capture, kept for corner re-adjust (story 12).
    required File rawFile,
    required Quad corners,
    required Set<PageFilter> filters,

    /// Warped and filtered image the user sees; the image-form PDF page.
    required File preparedFile,

    /// Hidden recognition input: [preparedFile] plus shadow removal and
    /// binarization. Never shown or put in the PDF.
    required File ocrInputFile,
    required RecognitionState recognition,
  }) = _CapturedPage;
}

/// The most recent page move, kept for «إرجاع الصفحة لمكانها» (FR-007).
@freezed
abstract class PageMove with _$PageMove {
  const factory PageMove({required int fromIndex, required int toIndex}) =
      _PageMove;
}

/// One run from start to attach or cancel (data-model).
@freezed
abstract class ScanSession with _$ScanSession {
  const factory ScanSession({
    required String id,
    required Directory dir,

    /// Review order; the list order is the PDF order (FR-011).
    required List<CapturedPage> pages,
    PageMove? lastMove,
    required CaptureMode captureMode,
    required DateTime startedAt,

    /// Null means no page limit (FR-009).
    int? maxPages,
  }) = _ScanSession;
}
