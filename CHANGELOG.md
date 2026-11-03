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
