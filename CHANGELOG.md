## 0.1.0

* First release: `DocScan.start` runs capture with live edge detection (auto and manual),
  review (reorder, undo, add, retake, delete, corners, filters), on-device text recognition
  (Apple Vision on iOS, Tesseract `ara`/`eng` tessdata_fast on Android), preview with edit,
  word and paragraph redaction, photo view and scan color, rename, and one PDF under the host's
  size limit. `DocScanViewer` shows the result read-only.
* Bundled models: `assets/tessdata/ara.traineddata` and `eng.traineddata` from
  tesseract-ocr/tessdata_fast (Apache 2.0, see `assets/tessdata/LICENSE`).
