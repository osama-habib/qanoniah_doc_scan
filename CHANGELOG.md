## 0.6.1

* iOS OCR keeps punctuation: words are split on whitespace instead of
  `.byWords`, which dropped every comma and full stop (Arabic «،» and «.» too).
  Checked on an iPhone 13 Pro Max: native page prep 85 to 161 ms, recognition
  0.73 s, text PDF 77 ms.
* The example's pipeline test also writes its log next to its artifacts, since a
  profile build on a phone does not send `print` to the launch console.

## 0.6.0

Scanner-grade capture and layout-aware OCR.

* Page prep runs natively: Core Image on iOS (about 3 to 5 times faster than the
  Dart pipeline on the same photo), Bitmap and Matrix on Android. The Dart
  pipeline stays as the fallback.
* Straightening keeps the sheet's real proportions, recovered from the perspective
  of its corners (Zhang and He): an A4 page photographed at an angle comes out at
  0.702 against 0.707. Shadows are flattened. A thin margin inside the edge is
  cropped so no desk shows.
* iOS finds the page with Vision's document segmentation, live and on the photo.
  On a test page the corners were off by 0.26% of the width. Sharpness,
  brightness and the signature come from the same native call.
* The live frame eases between detections, holds through brief misses and
  pulses. The flash, the corner step's fade, the shot flying into the page stack
  and the sheet sliding up follow the design. The camera is no longer reopened
  around the corner step.
* OCR keeps the page layout through a new `LayoutAnalyzer`:
  * tables with wrapped cells and one alignment per column;
  * paragraphs that keep their printed lines;
  * alignment measured in each paragraph's own direction;
  * headings, indents and spacing;
  * text columns read column by column.
* The preview and the text-form PDF on iOS and Android draw that layout: ruled
  tables, aligned and justified blocks, larger headings. Latin words keep their
  order inside Arabic lines.
* Fixed: Dart black-and-white pages came out dark (the one-channel JPEG encoding).

## 0.5.0

Matches the Claude Design «Full App - Document Scan» screen by screen.

* Camera: manual capture by default with no mode toggle and no hint line. Each shot opens a
  corner step on the photo (four draggable corners, outside dimmed) with «إعادة الالتقاط» and
  «حفظ الصفحة». Full-width preview on black, 72/58 shutter, a stacked-pages button with the
  count badge, and «حفظ (N)». Auto capture stays in the cubit for a host that turns it on.
* Review: «صفحة N» under each tile, a ✕ on the tile opens the delete card, a grip on each tile,
  and the moved page shows a dashed ring with an undo button. No tile menu.
* Delete: a bottom card with the page thumbnail, «إلغاء» and a red «حذف».
* Build: a page sketch with a moving scan line over the three steps.
* Preview: every page on a gray canvas; header with the PDF icon, the file name renamed in place
  («.pdf» fixed), the page count and «كل الصفحات» (a thumbnail column). Hidden words show
  blurred. The selection pill hides or shows text and «تعديل» opens the paragraph in place.
  Photo pages for «إرفاق كملف PDF». No text/photo toggle, scan color or edit mode in the UI.
* Viewer: the preview's header with ✕, gray canvas, no attach.
* Breaking for hosts: `DocScanTheme` adds `canvas`, `surfaceTertiary`, `inverseSurface`;
  `DocScanIcons` adds `undo`, `dragHandle`, `pages`, `search`, `chevronUp`, `chevronDown`, `pdf`.
* Design sizes that have no kit token live in `ScanMetrics` (pending design confirmation).

## 0.4.1

* Fixed on iOS: the live page frame was drawn on swapped axes. iOS delivers upright frames
  once portrait is locked, and they were rotated a second time.
* Scanner-like straightening: after each capture the page edges are found again on the
  full-resolution photo (Vision on iOS, Dart elsewhere) and the page is warped to them; the
  live frame's corners are the fallback.
* Auto capture re-arms when a new page is laid where the last one was (a stack of pages),
  not only when the page moves or leaves the frame.
* Header buttons such as «إلغاء» / Cancel no longer wrap onto several lines.

## 0.4.0

* Matches the current design: after the camera comes «توضيح الصفحات», a full-screen filter step
  (page with previous/next, six combinable filters previewed on the page, «تطبيق على كل
  الصفحات» on by default, «التالي» to review).
* Review: dashed «إضافة صفحة» tile at the end of the grid, back to the filters, and a second
  action «إرفاق كملف PDF» that attaches the photos as one PDF straight from the preview.
* Fixed: the filter strip overflowed by a few pixels at some text sizes.

## 0.3.0

* Text-form PDF (after an edit or redaction) is laid out by each platform's own text engine:
  TextKit/CoreText on iOS, StaticLayout + PdfDocument on Android. English inside Arabic keeps
  its order, and digits, `%` and brackets render correctly. Falls back to the `pdf` package
  when the native side is missing.
* Android: JitPack is added for every project, so hosts need no repository change for
  tesseract4android.

## 0.2.0

* OpenCV removed: it had no arm64 iOS simulator build (the host app stopped running on
  Apple-silicon simulators) and added about 155 MB of static code. Page edges are found in
  Dart on every platform and with Apple Vision on iOS; page preparation and filters are pure
  Dart (`image` package).
* iOS 15 to 17: Arabic and English text recognition falls back to Tesseract 5.5.3 (built from
  source, `tool/build_ios_tesseract.sh`) when Vision cannot read the language.
* Camera cancel keeps captured pages and opens review; review and preview cancel discard.
* The camera captures at 1080p.

## 0.1.0

* First release: `DocScan.start` runs capture with live edge detection (auto and manual),
  review (reorder, undo, add, retake, delete, corners, filters), on-device text recognition
  (Apple Vision on iOS, Tesseract `ara`/`eng` tessdata_fast on Android), preview with edit,
  word and paragraph redaction, photo view and scan color, rename, and one PDF under the host's
  size limit. `DocScanViewer` shows the result read-only.
* Bundled models: `assets/tessdata/ara.traineddata` and `eng.traineddata` from
  tesseract-ocr/tessdata_fast (Apache 2.0, see `assets/tessdata/LICENSE`).
