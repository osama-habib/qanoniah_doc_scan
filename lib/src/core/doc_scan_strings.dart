import 'package:flutter/foundation.dart';

/// Every user-facing string in the flow (FR-036).
///
/// [DocScanStrings.ar] and [DocScanStrings.en] are the defaults; the host overrides any
/// string with [copyWith]. Arabic copy follows the kit rules: فصحى مبسطة, Latin
/// numerals, no em-dash.
///
/// Strings marked `TODO(ahmed)` in [DocScanStrings.ar] have no design source and are
/// proposals pending UX approval (spec, open design question 7).
@immutable
class DocScanStrings {
  const DocScanStrings({
    required this.scanTitle,
    required this.modeAuto,
    required this.modeManual,
    required this.cancel,
    required this.close,
    required this.back,
    required this.capture,
    required this.hintAuto,
    required this.hintManual,
    required this.hintNextPage,
    required this.hintLowLight,
    required this.hintHoldSteady,
    required this.pageCaptured,
    required this.announcePageDetected,
    required this.announcePageSteady,
    required this.announcePageCaptured,
    required this.pageLimitReached,
    required this.cameraPermissionTitle,
    required this.cameraPermissionRetry,
    required this.openSettings,
    required this.reviewPages,
    required this.reorderHint,
    required this.addPage,
    required this.retakeLast,
    required this.undoMove,
    required this.moveEarlier,
    required this.moveLater,
    required this.pageLabel,
    required this.pageCount,
    required this.deletePage,
    required this.deletePageTitle,
    required this.deletePageBody,
    required this.deleteConfirm,
    required this.cornersTitle,
    required this.cornersHint,
    required this.savePage,
    required this.retake,
    required this.filtersTitle,
    required this.filtersPanelTitle,
    required this.next,
    required this.pageOf,
    required this.saveCount,
    required this.pageShort,
    required this.allPages,
    required this.filtersHint,
    required this.filterOriginal,
    required this.filterAuto,
    required this.filterText,
    required this.filterShadow,
    required this.filterContrast,
    required this.filterGray,
    required this.filterBw,
    required this.applyToAllPages,
    required this.resetFilters,
    required this.buildDocument,
    required this.stepAnalyze,
    required this.stepExtract,
    required this.stepPdf,
    required this.buildFailed,
    required this.storageFull,
    required this.retry,
    required this.previewTitle,
    required this.previewTip,
    required this.noTextOnPage,
    required this.fileSize,
    required this.edit,
    required this.done,
    required this.editHint,
    required this.hideSelection,
    required this.showText,
    required this.hideParagraph,
    required this.showParagraph,
    required this.redactedText,
    required this.redactedWords,
    required this.textView,
    required this.photoView,
    required this.scanColor,
    required this.colorColor,
    required this.colorGray,
    required this.colorBw,
    required this.sendsAsText,
    required this.rename,
    required this.renameSave,
    required this.attach,
    required this.attachNote,
    required this.sizeLimit,
    required this.defaultFileStem,
  });

  // Camera
  final String scanTitle;
  final String modeAuto;
  final String modeManual;
  final String cancel;
  final String close;
  final String back;
  final String capture;
  final String hintAuto;
  final String hintManual;
  final String hintNextPage;
  final String hintLowLight;
  final String hintHoldSteady;
  final String pageCaptured;
  final String announcePageDetected;
  final String announcePageSteady;
  final String Function(int count) announcePageCaptured;
  final String Function(int max) pageLimitReached;
  final String cameraPermissionTitle;
  final String cameraPermissionRetry;
  final String openSettings;

  // Review
  final String reviewPages;
  final String reorderHint;
  final String addPage;
  final String retakeLast;
  final String undoMove;
  final String moveEarlier;
  final String moveLater;
  final String Function(int number) pageLabel;
  final String Function(int count) pageCount;
  final String deletePage;
  final String Function(int number) deletePageTitle;
  final String deletePageBody;
  final String deleteConfirm;
  final String cornersTitle;
  final String cornersHint;
  final String savePage;
  final String retake;
  final String filtersTitle;

  /// «الفلاتر», the filter strip's heading on «توضيح الصفحات».
  final String filtersPanelTitle;

  /// «التالي»: from «توضيح الصفحات» to review.
  final String next;

  /// «صفحة 2 / 5».
  final String Function(int number, int total) pageOf;

  /// «حفظ (N)» on the camera.
  final String Function(int count) saveCount;

  /// «صفحة N» under a review tile.
  final String Function(int number) pageShort;

  /// «كل الصفحات»: the preview's page sidebar.
  final String allPages;
  final String filtersHint;
  final String filterOriginal;
  final String filterAuto;
  final String filterText;
  final String filterShadow;
  final String filterContrast;
  final String filterGray;
  final String filterBw;
  final String applyToAllPages;
  final String resetFilters;

  // Build
  final String buildDocument;
  final String stepAnalyze;
  final String stepExtract;
  final String stepPdf;
  final String buildFailed;
  final String storageFull;
  final String retry;

  // Preview, edit, redact
  final String previewTitle;
  final String previewTip;
  final String noTextOnPage;
  final String Function(double megabytes) fileSize;
  final String edit;
  final String done;
  final String editHint;
  final String hideSelection;
  final String showText;
  final String hideParagraph;
  final String showParagraph;
  final String redactedText;

  /// Redaction counter with Arabic number agreement (FR-016).
  final String Function(int count) redactedWords;
  final String textView;
  final String photoView;
  final String scanColor;
  final String colorColor;
  final String colorGray;
  final String colorBw;
  final String sendsAsText;
  final String rename;
  final String renameSave;

  // Attach
  final String attach;
  final String attachNote;
  final String Function(double sizeMb, double limitMb) sizeLimit;

  /// File name stem before «-NN.pdf».
  final String defaultFileStem;

  factory DocScanStrings.ar() {
    return DocScanStrings(
      scanTitle: 'مسح مستند',
      modeAuto: 'تلقائي',
      modeManual: 'يدوي',
      cancel: 'إلغاء',
      close: 'إغلاق', // TODO(ahmed): pending UX approval
      back: 'رجوع', // TODO(ahmed): pending UX approval
      capture: 'التقاط', // TODO(ahmed): pending UX approval
      hintAuto: 'ضع المستند داخل الإطار، يُلتقط تلقائيًا',
      hintManual: 'ضع المستند داخل الإطار ثم التقط',
      hintNextPage: 'ضع الصفحة التالية ثم التقط',
      // TODO(ahmed): pending UX approval
      hintLowLight: 'الإضاءة ضعيفة، قرّب المستند من مصدر ضوء',
      // TODO(ahmed): pending UX approval
      hintHoldSteady: 'ثبّت الجهاز حتى تتضح الصفحة',
      pageCaptured: 'تم التقاط الصفحة',
      // TODO(ahmed): pending UX approval
      announcePageDetected: 'تم اكتشاف الصفحة',
      // TODO(ahmed): pending UX approval
      announcePageSteady: 'الصفحة ثابتة، جارٍ الالتقاط',
      // TODO(ahmed): pending UX approval
      announcePageCaptured: (int count) => 'تم التقاط الصفحة. ${_arPages(count)}',
      // TODO(ahmed): pending UX approval
      pageLimitReached: (int max) => 'وصلت إلى الحد الأقصى: ${_arPages(max)}',
      // TODO(ahmed): pending UX approval
      cameraPermissionTitle: 'نحتاج إلى إذن الكاميرا لمسح المستند',
      cameraPermissionRetry: 'السماح بالكاميرا', // TODO(ahmed): pending UX approval
      openSettings: 'افتح الإعدادات', // TODO(ahmed): pending UX approval
      reviewPages: 'مراجعة الصفحات',
      reorderHint: 'اسحب الصفحة لتغيير ترتيبها في الملف.',
      addPage: 'إضافة صفحة',
      retakeLast: 'إعادة التقاط الأخيرة',
      undoMove: 'إرجاع الصفحة لمكانها',
      moveEarlier: 'نقل للأمام', // TODO(ahmed): pending UX approval
      moveLater: 'نقل للخلف', // TODO(ahmed): pending UX approval
      pageLabel: (int number) => 'الصفحة $number',
      pageCount: _arPages,
      deletePage: 'حذف الصفحة',
      deletePageTitle: (int number) => 'حذف الصفحة $number؟',
      deletePageBody: 'ستُحذف الصورة من هذا المسح ولن تُضاف إلى الملف.',
      deleteConfirm: 'حذف', // TODO(ahmed): pending UX approval
      cornersTitle: 'زاوية الصفحة',
      cornersHint: 'يمكنك ضبط حدود الصفحة بسحب الزوايا',
      savePage: 'حفظ الصفحة',
      retake: 'إعادة الالتقاط',
      filtersTitle: 'توضيح الصفحات',
      filtersPanelTitle: 'الفلاتر',
      next: 'التالي',
      pageOf: (int n, int total) => 'صفحة $n / $total',
      saveCount: (int n) => 'حفظ ($n)',
      pageShort: (int n) => 'صفحة $n',
      allPages: 'كل الصفحات',
      filtersHint: 'يمكن الجمع بين أكثر من فلتر لتوضيح النص، وتُقرأ الصفحة بعد التحسين بدقة أعلى.',
      filterOriginal: 'الأصل',
      filterAuto: 'تحسين تلقائي',
      filterText: 'إبراز النص',
      filterShadow: 'إزالة الظلال',
      filterContrast: 'تباين عالٍ',
      filterGray: 'رمادي',
      filterBw: 'أبيض وأسود',
      applyToAllPages: 'تطبيق على كل الصفحات',
      resetFilters: 'إعادة الضبط',
      buildDocument: 'إنشاء مستند قابل للتعديل',
      stepAnalyze: 'تحليل الصور',
      stepExtract: 'استخراج النص',
      stepPdf: 'إنشاء ملف PDF',
      // TODO(ahmed): pending UX approval
      buildFailed: 'تعذّر إنشاء الملف، حاول مرة أخرى',
      // TODO(ahmed): pending UX approval
      storageFull: 'لا توجد مساحة كافية على الجهاز',
      retry: 'إعادة المحاولة',
      previewTitle: 'معاينة ملف PDF',
      previewTip: 'يمكنك تحديد أي نص لحجبه أو تعديله قبل الإرسال.',
      // TODO(ahmed): pending UX approval
      noTextOnPage: 'لم يُعثر على نص في هذه الصفحة',
      fileSize: (double mb) => '${mb.toStringAsFixed(1)} MB',
      edit: 'تعديل',
      done: 'تم',
      editHint: 'عدّل نص أي فقرة، أو احجبها كاملة بزر العين.',
      hideSelection: 'إخفاء النص المحدد',
      showText: 'إظهار النص',
      hideParagraph: 'حجب الفقرة',
      showParagraph: 'إظهار الفقرة',
      redactedText: 'نص محجوب',
      redactedWords: _arRedactedWords,
      textView: 'عرض النص', // TODO(ahmed): pending UX approval
      photoView: 'عرض الصور', // TODO(ahmed): pending UX approval
      scanColor: 'لون المسح',
      colorColor: 'ألوان',
      colorGray: 'رمادي',
      colorBw: 'أبيض وأسود',
      sendsAsText: 'سيُرسل الملف كنص', // TODO(ahmed): pending UX approval
      rename: 'إعادة تسمية المستند',
      renameSave: 'حفظ', // TODO(ahmed): pending UX approval
      attach: 'إرفاق كملف PDF',
      attachNote: 'تُدمج الصفحات في ملف PDF واحد ويُقرأ نصها قبل الإجابة.',
      // TODO(ahmed): pending UX approval
      sizeLimit: (double size, double limit) =>
          'حجم الملف ${size.toStringAsFixed(1)} MB، والحد الأقصى '
          '${limit.toStringAsFixed(0)} MB. احذف بعض الصفحات ثم حاول مرة أخرى.',
      defaultFileStem: 'مستند-ممسوح',
    );
  }

  factory DocScanStrings.en() {
    return DocScanStrings(
      scanTitle: 'Scan document',
      modeAuto: 'Auto',
      modeManual: 'Manual',
      cancel: 'Cancel',
      close: 'Close',
      back: 'Back',
      capture: 'Capture',
      hintAuto: 'Place the document inside the frame. It is captured automatically',
      hintManual: 'Place the document inside the frame, then capture',
      hintNextPage: 'Place the next page, then capture',
      hintLowLight: 'Low light. Move the document closer to a light source',
      hintHoldSteady: 'Hold steady until the page is sharp',
      pageCaptured: 'Page captured',
      announcePageDetected: 'Page detected',
      announcePageSteady: 'Page steady, capturing',
      announcePageCaptured: (int count) => 'Page captured. ${_enPages(count)}',
      pageLimitReached: (int max) => 'Limit reached: ${_enPages(max)}',
      cameraPermissionTitle: 'Camera access is needed to scan the document',
      cameraPermissionRetry: 'Allow camera',
      openSettings: 'Open Settings',
      reviewPages: 'Review pages',
      reorderHint: 'Drag a page to change its order in the file.',
      addPage: 'Add page',
      retakeLast: 'Retake last',
      undoMove: 'Move page back',
      moveEarlier: 'Move earlier',
      moveLater: 'Move later',
      pageLabel: (int number) => 'Page $number',
      pageCount: _enPages,
      deletePage: 'Delete page',
      deletePageTitle: (int number) => 'Delete page $number?',
      deletePageBody: 'The image will be removed from this scan and not added to the file.',
      deleteConfirm: 'Delete',
      cornersTitle: 'Page corners',
      cornersHint: 'Drag the corners to adjust the page edges',
      savePage: 'Save page',
      retake: 'Retake',
      filtersTitle: 'Enhance pages',
      filtersPanelTitle: 'Filters',
      next: 'Next',
      pageOf: (int n, int total) => 'Page $n / $total',
      saveCount: (int n) => 'Save ($n)',
      pageShort: (int n) => 'Page $n',
      allPages: 'All pages',
      filtersHint: 'Combine filters to make text clearer. The page is read more accurately after enhancing.',
      filterOriginal: 'Original',
      filterAuto: 'Auto enhance',
      filterText: 'Sharpen text',
      filterShadow: 'Remove shadows',
      filterContrast: 'High contrast',
      filterGray: 'Grayscale',
      filterBw: 'Black and white',
      applyToAllPages: 'Apply to all pages',
      resetFilters: 'Reset',
      buildDocument: 'Create editable document',
      stepAnalyze: 'Analyzing images',
      stepExtract: 'Extracting text',
      stepPdf: 'Creating PDF',
      buildFailed: 'The file could not be created. Try again',
      storageFull: 'Not enough storage on the device',
      retry: 'Retry',
      previewTitle: 'Preview PDF',
      previewTip: 'Select any text to hide or edit it before sending.',
      noTextOnPage: 'No text was found on this page',
      fileSize: (double mb) => '${mb.toStringAsFixed(1)} MB',
      edit: 'Edit',
      done: 'Done',
      editHint: 'Edit any paragraph, or hide it fully with the eye button.',
      hideSelection: 'Hide selected text',
      showText: 'Show text',
      hideParagraph: 'Hide paragraph',
      showParagraph: 'Show paragraph',
      redactedText: 'Hidden text',
      redactedWords: (int n) => n == 1 ? '1 hidden word' : '$n hidden words',
      textView: 'Text',
      photoView: 'Photos',
      scanColor: 'Scan color',
      colorColor: 'Color',
      colorGray: 'Grayscale',
      colorBw: 'Black and white',
      sendsAsText: 'The file will be sent as text',
      rename: 'Rename document',
      renameSave: 'Save',
      attach: 'Attach as PDF',
      attachNote: 'Pages are merged into one PDF and its text is read before answering.',
      sizeLimit: (double size, double limit) =>
          'The file is ${size.toStringAsFixed(1)} MB and the limit is '
          '${limit.toStringAsFixed(0)} MB. Remove some pages and try again.',
      defaultFileStem: 'scanned-document',
    );
  }

  DocScanStrings copyWith({
    String? scanTitle,
    String? modeAuto,
    String? modeManual,
    String? cancel,
    String? close,
    String? back,
    String? capture,
    String? hintAuto,
    String? hintManual,
    String? hintNextPage,
    String? hintLowLight,
    String? hintHoldSteady,
    String? pageCaptured,
    String? announcePageDetected,
    String? announcePageSteady,
    String Function(int count)? announcePageCaptured,
    String Function(int max)? pageLimitReached,
    String? cameraPermissionTitle,
    String? cameraPermissionRetry,
    String? openSettings,
    String? reviewPages,
    String? reorderHint,
    String? addPage,
    String? retakeLast,
    String? undoMove,
    String? moveEarlier,
    String? moveLater,
    String Function(int number)? pageLabel,
    String Function(int count)? pageCount,
    String? deletePage,
    String Function(int number)? deletePageTitle,
    String? deletePageBody,
    String? deleteConfirm,
    String? cornersTitle,
    String? cornersHint,
    String? savePage,
    String? retake,
    String? filtersTitle,
    String? filtersPanelTitle,
    String? next,
    String Function(int number, int total)? pageOf,
    String Function(int count)? saveCount,
    String Function(int number)? pageShort,
    String? allPages,
    String? filtersHint,
    String? filterOriginal,
    String? filterAuto,
    String? filterText,
    String? filterShadow,
    String? filterContrast,
    String? filterGray,
    String? filterBw,
    String? applyToAllPages,
    String? resetFilters,
    String? buildDocument,
    String? stepAnalyze,
    String? stepExtract,
    String? stepPdf,
    String? buildFailed,
    String? storageFull,
    String? retry,
    String? previewTitle,
    String? previewTip,
    String? noTextOnPage,
    String Function(double megabytes)? fileSize,
    String? edit,
    String? done,
    String? editHint,
    String? hideSelection,
    String? showText,
    String? hideParagraph,
    String? showParagraph,
    String? redactedText,
    String Function(int count)? redactedWords,
    String? textView,
    String? photoView,
    String? scanColor,
    String? colorColor,
    String? colorGray,
    String? colorBw,
    String? sendsAsText,
    String? rename,
    String? renameSave,
    String? attach,
    String? attachNote,
    String Function(double sizeMb, double limitMb)? sizeLimit,
    String? defaultFileStem,
  }) {
    return DocScanStrings(
      scanTitle: scanTitle ?? this.scanTitle,
      modeAuto: modeAuto ?? this.modeAuto,
      modeManual: modeManual ?? this.modeManual,
      cancel: cancel ?? this.cancel,
      close: close ?? this.close,
      back: back ?? this.back,
      capture: capture ?? this.capture,
      hintAuto: hintAuto ?? this.hintAuto,
      hintManual: hintManual ?? this.hintManual,
      hintNextPage: hintNextPage ?? this.hintNextPage,
      hintLowLight: hintLowLight ?? this.hintLowLight,
      hintHoldSteady: hintHoldSteady ?? this.hintHoldSteady,
      pageCaptured: pageCaptured ?? this.pageCaptured,
      announcePageDetected: announcePageDetected ?? this.announcePageDetected,
      announcePageSteady: announcePageSteady ?? this.announcePageSteady,
      announcePageCaptured: announcePageCaptured ?? this.announcePageCaptured,
      pageLimitReached: pageLimitReached ?? this.pageLimitReached,
      cameraPermissionTitle: cameraPermissionTitle ?? this.cameraPermissionTitle,
      cameraPermissionRetry: cameraPermissionRetry ?? this.cameraPermissionRetry,
      openSettings: openSettings ?? this.openSettings,
      reviewPages: reviewPages ?? this.reviewPages,
      reorderHint: reorderHint ?? this.reorderHint,
      addPage: addPage ?? this.addPage,
      retakeLast: retakeLast ?? this.retakeLast,
      undoMove: undoMove ?? this.undoMove,
      moveEarlier: moveEarlier ?? this.moveEarlier,
      moveLater: moveLater ?? this.moveLater,
      pageLabel: pageLabel ?? this.pageLabel,
      pageCount: pageCount ?? this.pageCount,
      deletePage: deletePage ?? this.deletePage,
      deletePageTitle: deletePageTitle ?? this.deletePageTitle,
      deletePageBody: deletePageBody ?? this.deletePageBody,
      deleteConfirm: deleteConfirm ?? this.deleteConfirm,
      cornersTitle: cornersTitle ?? this.cornersTitle,
      cornersHint: cornersHint ?? this.cornersHint,
      savePage: savePage ?? this.savePage,
      retake: retake ?? this.retake,
      filtersTitle: filtersTitle ?? this.filtersTitle,
      filtersPanelTitle: filtersPanelTitle ?? this.filtersPanelTitle,
      next: next ?? this.next,
      pageOf: pageOf ?? this.pageOf,
      saveCount: saveCount ?? this.saveCount,
      pageShort: pageShort ?? this.pageShort,
      allPages: allPages ?? this.allPages,
      filtersHint: filtersHint ?? this.filtersHint,
      filterOriginal: filterOriginal ?? this.filterOriginal,
      filterAuto: filterAuto ?? this.filterAuto,
      filterText: filterText ?? this.filterText,
      filterShadow: filterShadow ?? this.filterShadow,
      filterContrast: filterContrast ?? this.filterContrast,
      filterGray: filterGray ?? this.filterGray,
      filterBw: filterBw ?? this.filterBw,
      applyToAllPages: applyToAllPages ?? this.applyToAllPages,
      resetFilters: resetFilters ?? this.resetFilters,
      buildDocument: buildDocument ?? this.buildDocument,
      stepAnalyze: stepAnalyze ?? this.stepAnalyze,
      stepExtract: stepExtract ?? this.stepExtract,
      stepPdf: stepPdf ?? this.stepPdf,
      buildFailed: buildFailed ?? this.buildFailed,
      storageFull: storageFull ?? this.storageFull,
      retry: retry ?? this.retry,
      previewTitle: previewTitle ?? this.previewTitle,
      previewTip: previewTip ?? this.previewTip,
      noTextOnPage: noTextOnPage ?? this.noTextOnPage,
      fileSize: fileSize ?? this.fileSize,
      edit: edit ?? this.edit,
      done: done ?? this.done,
      editHint: editHint ?? this.editHint,
      hideSelection: hideSelection ?? this.hideSelection,
      showText: showText ?? this.showText,
      hideParagraph: hideParagraph ?? this.hideParagraph,
      showParagraph: showParagraph ?? this.showParagraph,
      redactedText: redactedText ?? this.redactedText,
      redactedWords: redactedWords ?? this.redactedWords,
      textView: textView ?? this.textView,
      photoView: photoView ?? this.photoView,
      scanColor: scanColor ?? this.scanColor,
      colorColor: colorColor ?? this.colorColor,
      colorGray: colorGray ?? this.colorGray,
      colorBw: colorBw ?? this.colorBw,
      sendsAsText: sendsAsText ?? this.sendsAsText,
      rename: rename ?? this.rename,
      renameSave: renameSave ?? this.renameSave,
      attach: attach ?? this.attach,
      attachNote: attachNote ?? this.attachNote,
      sizeLimit: sizeLimit ?? this.sizeLimit,
      defaultFileStem: defaultFileStem ?? this.defaultFileStem,
    );
  }
}

/// Arabic page count with number agreement, as in the design: «صفحة واحدة»,
/// «صفحتان», «3 صفحات», «11 صفحة».
String _arPages(int n) {
  if (n == 1) return 'صفحة واحدة';
  if (n == 2) return 'صفحتان';
  if (n >= 3 && n <= 10) return '$n صفحات';
  return '$n صفحة';
}

/// FR-016: 1 «كلمة محجوبة», 2 «كلمتان محجوبتان», 3 to 10 «كلمات محجوبة»,
/// 11 and above «كلمة محجوبة», with Latin numerals.
String _arRedactedWords(int n) {
  if (n == 1) return 'كلمة محجوبة';
  if (n == 2) return 'كلمتان محجوبتان';
  if (n >= 3 && n <= 10) return '$n كلمات محجوبة';
  return '$n كلمة محجوبة';
}

String _enPages(int n) => n == 1 ? '1 page' : '$n pages';
