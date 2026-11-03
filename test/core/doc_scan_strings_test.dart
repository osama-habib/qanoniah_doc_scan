import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/src/core/doc_scan_strings.dart';

void main() {
  group('redactedWords (FR-016)', () {
    final DocScanStrings ar = DocScanStrings.ar();

    test('follows Arabic number agreement', () {
      expect(ar.redactedWords(1), 'كلمة محجوبة');
      expect(ar.redactedWords(2), 'كلمتان محجوبتان');
      expect(ar.redactedWords(3), '3 كلمات محجوبة');
      expect(ar.redactedWords(10), '10 كلمات محجوبة');
      expect(ar.redactedWords(11), '11 كلمة محجوبة');
      expect(ar.redactedWords(100), '100 كلمة محجوبة');
    });
  });

  group('copy rules (FR-074)', () {
    for (final MapEntry<String, DocScanStrings> locale in <String, DocScanStrings>{
      'ar': DocScanStrings.ar(),
      'en': DocScanStrings.en(),
    }.entries) {
      test('${locale.key} defaults have no em-dash, Arabic-Indic digit, or banned word',
          () {
        for (final String s in _allTexts(locale.value)) {
          expect(s.contains('—'), isFalse, reason: s);
          expect(RegExp('[٠-٩۰-۹]').hasMatch(s), isFalse,
              reason: s);
          expect(s.contains('استشار'), isFalse, reason: s);
        }
      });
    }
  });

  test('copyWith overrides one string and keeps the rest', () {
    final DocScanStrings s = DocScanStrings.ar().copyWith(attach: 'X');
    expect(s.attach, 'X');
    expect(s.scanTitle, 'مسح مستند');
  });
}

/// Every string a locale can show, with sample arguments for the parametric ones.
List<String> _allTexts(DocScanStrings s) => <String>[
      s.scanTitle, s.modeAuto, s.modeManual, s.cancel, s.close, s.back, s.capture,
      s.hintAuto, s.hintManual, s.hintNextPage, s.hintLowLight, s.hintHoldSteady,
      s.pageCaptured, s.announcePageDetected, s.announcePageSteady,
      s.announcePageCaptured(3), s.pageLimitReached(20), s.cameraPermissionTitle,
      s.cameraPermissionRetry, s.openSettings, s.reviewPages, s.reorderHint,
      s.addPage, s.retakeLast, s.undoMove, s.moveEarlier, s.moveLater,
      s.pageLabel(2), s.pageCount(12), s.deletePage, s.deletePageTitle(2),
      s.deletePageBody, s.deleteConfirm, s.cornersTitle, s.cornersHint, s.savePage,
      s.retake, s.filtersTitle, s.filtersHint, s.filterOriginal, s.filterAuto,
      s.filterText, s.filterShadow, s.filterContrast, s.filterGray, s.filterBw,
      s.applyToAllPages, s.resetFilters, s.buildDocument, s.stepAnalyze,
      s.stepExtract, s.stepPdf, s.buildFailed, s.storageFull, s.retry,
      s.previewTitle, s.previewTip, s.noTextOnPage, s.fileSize(1.25), s.edit,
      s.done, s.editHint, s.hideSelection, s.showText, s.hideParagraph,
      s.showParagraph, s.redactedText, s.redactedWords(7), s.textView, s.photoView,
      s.scanColor, s.colorColor, s.colorGray, s.colorBw, s.sendsAsText, s.rename,
      s.renameSave, s.attach, s.attachNote, s.sizeLimit(6.3, 5), s.defaultFileStem,
    ];
