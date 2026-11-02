# Feature brief: Document Scan in Qanoniah AI (مسح المستندات في قانونية AI)

ClickUp: https://app.clickup.com/t/z8y71x069k (estimate: 24). Mobile app only.

## Goal
Inside a Qanoniah AI chat, the user photographs a paper document and it becomes ONE PDF whose
text is read before the answer. Before sending they can reorder pages, edit the extracted text,
or redact parts they don't want shared. «مسح مستند» replaces the Camera option: the attach menu
becomes three equal cards «الصور · الملفات · مسح مستند».

## Journey (6 steps, design states)
01 Entry `attach-menu`: three equal cards, 76px tall; «مسح مستند» opens the camera directly.
02 Capture `scan-find`, `scan-pages`: camera in a dark bottom sheet, frame tracks page edges;
   Auto captures when steady, Manual on tap; each shot flies to a bottom thumbnail with a short
   white flash + page count; drag the handle down closes. Copy: «مسح مستند · تلقائي · يدوي · إلغاء»,
   «ضع المستند داخل الإطار، يُلتقط تلقائيًا», «ضع المستند داخل الإطار ثم التقط»,
   «ضع الصفحة التالية ثم التقط», «تم التقاط الصفحة».
03 Review `scan-review`, `scan-reordered`: 3-column grid; long-press/drag reorders (scanOrder);
   undo after move; add page; retake last. Copy: «مراجعة الصفحات · إضافة صفحة ·
   إعادة التقاط الأخيرة · اسحب الصفحة لتغيير ترتيبها في الملف. · إرجاع الصفحة لمكانها».
04 Build `scan-build`: animated scan line, three steps complete in order: «تحليل الصور ·
   استخراج النص · إنشاء ملف PDF». Entry button: «إنشاء مستند قابل للتعديل».
05 Preview & edit `scan-pdf`, `scan-edit`: PDF preview + page sidebar; selecting text opens an
   action bar to redact or edit; edit mode: every paragraph editable, eye button redacts the
   whole paragraph; redacted paragraph shows as «نص محجوب» and is NOT sent to Qanoniah AI.
   Copy: «معاينة ملف PDF», «يمكنك تحديد أي نص لحجبه أو تعديله قبل الإرسال.»,
   «عدّل نص أي فقرة، أو احجبها كاملة بزر العين.», «إخفاء النص المحدد», «إظهار النص»,
   «إظهار الفقرة», «حجب الفقرة», «كلمة محجوبة / كلمتان محجوبتان / كلمات محجوبة».
06 Attach `scan-attached`, `scan-view`: «إرفاق كملف PDF» puts «مستند-ممسوح-01.pdf» in the
   composer; tapping opens it read-only; redactions stay. Copy: «تُدمج الصفحات في ملف PDF واحد
   ويُقرأ نصها قبل الإجابة.»

## In the design but not in ClickUp (decide in /speckit-clarify)
- Page filters «توضيح الصفحات»: «الأصل», «تحسين تلقائي», «إبراز النص», «إزالة الظلال»,
  «تباين عالٍ», «رمادي», «أبيض وأسود»; combinable; «تطبيق على كل الصفحات»; «إعادة الضبط»;
  hint «يمكن الجمع بين أكثر من فلتر لتوضيح النص، وتُقرأ الصفحة بعد التحسين بدقة أعلى.»
- Corner adjust «زاوية الصفحة»: «يمكنك ضبط حدود الصفحة بسحب الزوايا», «حفظ الصفحة», «إعادة الالتقاط».
- Delete page «حذف الصفحة» with «ستُحذف الصورة من هذا المسح ولن تُضاف إلى الملف.»
- Rename «إعادة تسمية المستند»; search «ابحث في المستند» / «لا نتائج»; image vs text color
  mode «لون المسح» / «ألوان».

## Acceptance (from ClickUp)
- Attach menu shows «الصور · الملفات · مسح مستند», no Camera.
- Pages merge into ONE PDF in the review-screen order.
- Redacted text never reaches the model and stays redacted in the read-only view.
- Edited text is what the model reads.
- Cancel or swipe-down at any step discards everything; nothing attached.

## Success metrics (package emits events, host records them)
Share of attachments from scan; started vs attached (drop-off per step); share using
redaction/edit; time from camera open to attached.

## Host constraints (qanoniah-mobile)
- Host uploads via existing multipart `/agent-attachment-upload`, 5 MB per file limit today.
- Host gates on `user.features.agentFileUpload == 'full'` before starting.
- Host already ships: pdf, image_picker, file_picker, permission_handler, flutter_bloc,
  flutter_svg, path_provider, dartz, freezed. Dart SDK >=3.3.0 <4.0.0.
- Native plugin ⇒ host needs a full release, not a Shorebird patch.

## OCR decision (owner: on-device, free, no backend; benchmark 2026-11-02)
Tested on two real Arabic court-ruling pages from the design:
- Apple Vision `.accurate` `ar-SA`: ~1 s/page, excellent, numbers intact. Use on iOS when
  `supportedRecognitionLanguages()` lists Arabic (expected iOS 18+); on iOS 26 prefer
  `RecognizeDocumentsRequest` (returns paragraphs).
- Tesseract `ara` fast (Apache 2.0, 1.4 MB, bundled): ~1.7 s/page on Mac, very good, a few
  digit errors. Use on Android (tesseract4android) and older iOS. Use `-l ara` only;
  `ara+eng` injects Latin junk words.
- PaddleOCR Arabic PP-OCRv5 mobile: rejected (drops digits, breaks dense paragraphs).
- Google ML Kit: no Arabic.
OCR runs per page in the background right after capture. Must finish before preview.
Open: English/mixed documents, real-device timings on mid-range Android.

## OCR service (decided 2026-11-02: no model trained from scratch)
Three layers inside the plugin:
1. Image preparation (ours): perspective correction, deskew, shadow removal, binarization;
   same operations as the design's page filters.
2. Character recognition (engines): Vision on iOS / Tesseract `ara` on Android, behind one
   `TextRecognizer` port. Swapping the engine or the model file changes no other code.
3. Post-processing (ours): RTL word order, paragraph grouping, digit and `%` normalization,
   word boxes for redaction.
v1.1: fine-tune Tesseract `ara` with `tesstrain` on (a) Qanoniah library documents already
OCR'd server-side (words + bbox from `/files/{id}/loadPage`) after a quality check and
(b) synthetic legal text rendered in court fonts and Noto with noise and shadows. Ship the new
`.traineddata` as an asset swap. User images or text are NEVER used for training.
A fixed evaluation set (real legal pages + ground-truth text) measures character, word and
digit error rates per engine and model version; a new model ships only if it beats the
current one on that set.

## Known risks
- Ready-made scanners (VisionKit, ML Kit Document Scanner) impose their own UI and can't match
  the design.
- Design values with no token: #5b8cff, #0b0f19, #1e4192, #f7f8fc, #dc2626; font sizes
  9/11/13/15; radii 2/4/6/8/10/14/16/18; dark camera surface (kit has no dark palette).
