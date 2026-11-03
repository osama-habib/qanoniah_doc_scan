# Research: Document Scan (001)

Phase 0 output for [plan.md](plan.md). Each entry: Decision, Rationale, Alternatives considered.
Items marked **Spike** must be proven on a real device in the first implementation task before
anything builds on them.

## R1. Toolchain compatibility with the host

- **Decision**: `environment: sdk: ">=3.9.0 <4.0.0"`, `flutter: ">=3.35.0"`. Every dependency is chosen to resolve against the host's pins.
- **Rationale**: The host builds with Flutter 3.35.2 (`.fvmrc`), so Dart 3.9. The current package pubspec says `sdk: ^3.10.8`, which the host cannot resolve. Host targets: iOS 15.0, Android minSdk 26, compileSdk/targetSdk 36.
- **Alternatives**: Upgrading the host's Flutter version. Rejected: out of this feature's scope, and it would force a host-wide upgrade.

## R2. Camera and live edge detection

- **Decision**: `camera` (flutter.dev) for preview, image stream, and still capture. Edge detection runs in Dart on a downscaled luminance plane of the stream, in a background isolate, with `opencv_dart` (Canny, contours, largest convex quadrilateral). It runs at about 8 to 10 frames per second and drops frames while busy. Auto capture fires when the quadrilateral's corners move less than 2% of the frame width for 600 ms, Laplacian variance (sharpness) is above a threshold, and mean luminance is above a threshold. The thresholds are tuned on device.
- **Rationale**: One implementation serves both platforms, so there is no duplicated Kotlin and Swift logic. The same library also does page preparation (R3). `camera` is the standard plugin with permission and lifecycle handling.
- **Alternatives**:
  - VisionKit / ML Kit Document Scanner: rejected in the brief because they impose their own UI.
  - Native CameraX and AVFoundation with a texture and native detectors: better frame throughput, but two codebases for the same rule.
  - Pure-Dart `image` package: too slow for live frames.
- **Spike**: `opencv_dart` must build with Flutter 3.35 on both platforms using the classic FFI plugin build (pin the 1.4.x line, not the native-assets 2.x line), with only the `core` and `imgproc` modules. Measure the added app size; budget is 12 MB per platform.

## R3. Page preparation layer (FR-051 layer 1, story 13 filters)

- **Decision**: All in Dart over `opencv_dart`. Perspective warp to the detected or adjusted corners, deskew, shadow removal (divide by a morphological-closing background estimate), and adaptive binarization. The design's filters map onto these operations:

  | Filter | Operations |
  |--------|------------|
  | «الأصل» | none |
  | «تحسين تلقائي» | auto contrast plus light sharpen |
  | «إبراز النص» | unsharp mask |
  | «إزالة الظلال» | shadow removal |
  | «تباين عالٍ» | CLAHE |
  | «رمادي» | grayscale |
  | «أبيض وأسود» | adaptive threshold |

  Filters combine in a fixed order. Recognition runs on `ocrInputFile`: the prepared image with shadow removal and binarization always applied on top of the user's filters. It is hidden and never goes into the PDF.
- **Rationale**: The same operations serve the filters (shown to the user) and the recognition input (hidden). This is one pipeline, not two.
- **Alternatives**: Separate native image processing per platform. Rejected, same duplication argument as R2.

## R4. Recognition engines (FR-050 to FR-053)

- **Decision**: One port, `TextRecognizer`, with two adapters:
  1. **Vision adapter (iOS)**, over a platform channel in Swift. It uses `VNRecognizeTextRequest`, `.accurate`, one language per call (`ar-SA` or `en-US`), and returns lines with bounding boxes. On iOS 26+ it uses `RecognizeDocumentsRequest`, which returns paragraphs natively. It is chosen when `supportedRecognitionLanguages()` includes Arabic.
  2. **Tesseract adapter (Android and older iOS)**: Tesseract 5 through its C API over `dart:ffi`, with a single Dart binding. It uses `ara.traineddata` and `eng.traineddata` from tessdata_fast, run in a background isolate, and returns words with boxes and confidences.

  Engine selection is a capability check at session start, not an OS version string.
- **Rationale**: The owner's benchmark (brief, 2026-11-02): Vision Arabic is excellent; Tesseract `ara` is very good; PaddleOCR and ML Kit are rejected. One FFI binding avoids two native Tesseract glue layers.
- **Native libraries**:
  - Android: `tesseract4android` (Apache 2.0) supplies `libtesseract.so`.
  - iOS: a prebuilt `tesseract.xcframework` plus `leptonica` (Apache 2.0 / BSD), vendored in `ios/Frameworks/`.
- **Spike**:
  - Confirm the Tesseract C API symbols (`TessBaseAPICreate`, …) are exported from the tesseract4android `.so`, and that the xcframework links in the pod.
  - Fallback if the Android `.so` lacks them: a thin Kotlin channel to tesseract4android's Java API.
  - Fallback if the iOS build fails: Vision only on iOS, and the host hides the scan card where Arabic Vision is unavailable. That fallback would be a product decision for the owner.
- **Model assets**: `.traineddata` files ship as package assets under `assets/tessdata/`. On first use they are copied into app-support storage, because Tesseract reads from a path. Swapping the file is the whole model update (FR-053).

## R5. Language per page (FR-062)

- **Decision**: Recognize in Arabic first. If the Arabic pass's mean word confidence is below a threshold, or Arabic letters are under 40% of recognized characters, run an English pass and keep whichever pass has the higher mean confidence. A page mixing both scripts keeps its dominant-script result. The two languages are never run in one combined pass.
- **Rationale**: Arabic is the common case, so it costs one pass. English pages cost two. The combined `ara+eng` mode injects junk words (brief benchmark).
- **Alternatives**:
  - Tesseract OSD (`osd.traineddata`, about 10 MB, Tesseract only): rejected for size and because it doesn't cover Vision.
  - The user picks the language: rejected in clarification.

## R6. Post-processing (FR-051 layer 3)

- **Decision**: Pure Dart, engine-independent. It does four things:
  - Orders words right to left per line for Arabic lines, left to right for Latin runs, using Unicode bidi isolation in the returned text.
  - Groups lines into paragraphs by vertical gap and indent (skipped when the engine already returns paragraphs).
  - Normalizes Arabic-Indic and Persian digits to Latin and fixes misplaced `%` and decimal separators.
  - Keeps word boxes in image coordinates for selection and redaction.
- **Rationale**: Both engines feed one normalizer, so the evaluation set measures engines and not formatting differences.

## R7. PDF building (FR-011, FR-061)

- **Decision**: The `pdf` package (^3.11.3, the host's pin).
  - **Text form**: pages laid out from the final paragraphs with the host-supplied font bytes (the PDF must embed a font). RTL with Arabic shaping uses the package's built-in bidi support. Redacted spans render as filled bars with «نص محجوب»; their characters are never passed to the PDF.
  - **Image form**: the prepared photo as a JPEG per page, plus the recognized text drawn with invisible text rendering mode at the word boxes, so it is selectable and searchable.
  - **Size fitting** (image form only): re-encode JPEGs at descending quality (85, 75, 65, 55) and long-edge resolution (2200 to 1600 px) until the file fits under the host's limit. Stop at the legibility floor (quality 55, 1600 px). Text form is built once.
- **Rationale**: The host already ships `pdf`, so there is no new dependency. The package needs fonts only for the PDF, and the host owns the font file (P3), so the host passes the bytes in the config.
- **Spike**: Arabic shaping and mixed Arabic/Latin order in `pdf` text form, checked against the evaluation pages; and whether the invisible text layer is extractable server-side.
- **Spike result (T010, 2026-11-02, `pdf` 3.12.0, Noto Sans Arabic + Noto Sans fallback)**: **FAILED, owner decision needed.**
  - Works: Arabic shaping and joining; RTL paragraph flow; the «نص محجوب» bar; invisible text via `TextStyle(renderingMode: PdfTextRenderingMode.invisible)`. `PdfGraphics.drawString` is unusable for Arabic (no shaping, reversed).
  - Needs a Latin fallback font: with Noto Sans Arabic alone, `(`, `)`, `%` and Latin letters are dropped. The host's canvas PDF already passes Noto Sans as `fontFallback`, so `DocScanConfig` must take a Latin font too.
  - Defect 1, visual: Latin runs inside Arabic render reversed (`Article` shows as `elcitrA`), and parentheses are not mirrored (`(2)` shows as `)2(`). Unicode isolates (U+2066/U+2069) and a separate Latin-font span do not help.
  - Defect 2, text layer: each glyph cluster is a separate positioned run with no space glyphs, Latin letters are emitted one by one in visual order, and Arabic is emitted as presentation forms (U+FExx). Extraction (pypdf) gives `ﻭﻓﻖArticle5ﻣﻦﺍﻟﻠﺎﺋﺤﺔ` in plain mode and reversed Latin in layout mode. How well Qanoniah AI reads it depends on the server's extractor.
  - The same defects apply to the host's existing canvas PDF export, which uses the same package.
  - **Owner decision (2026-11-02): C then A.** First ask the backend team how `/agent-attachment-upload` reads a PDF's text (text-layer extraction, and with which library, or OCR). If the server extracts the text layer, build the PDF with each platform's own text engine (CoreText via `UIGraphicsPDFRenderer` on iOS, `PdfDocument` with `StaticLayout` on Android) behind one `PdfRenderer` port. That port is a platform seam allowed by P5. Phases 6 and 9 (PDF building) wait for the backend answer.

## R8. Read-only viewer (story 10)

- **Decision**: `DocScanViewer` rasterizes the returned PDF with `printing` (`Printing.raster`, from the same author as `pdf`). It uses the platform's own PDF renderer, so no pdfium binary is added. The viewer shows the pages with no tools.
- **Rationale**: The host cannot read an uploaded attachment back: `/agent-attachment-upload` stores a vault-encrypted blob with no GET (host `ai_converted_text_store.dart`). So the viewer works on the local PDF in the session that created it. After a reload the host shows a plain chip, matching its existing converted-draft behavior.
- **Alternatives**: `pdfrx` (pdfium, about 5 MB per platform), rejected for size; rendering from the in-memory model, rejected because the viewer must show exactly what was sent.

## R9. State, errors, codegen

- **Decision**:
  - State: `flutter_bloc` ^9.1.1 Cubits, one per screen, all scoped to the flow.
  - Errors: repos return `Either<Failure, T>` (`dartz` ^0.10.1).
  - Codegen: `freezed` ^2.4.7 with `freezed_annotation` ^2.4.1 for states and value types, using relative `part` directives.
  - Dependency injection: constructor injection only, wired in one composition root inside `DocScan.start`. No service locator.
- **Rationale**: Matches the host's pins and CLAUDE.md. P1 forbids the host's get_it, and the package has a single entry point, so a locator would add nothing.

## R10. Permissions

- **Decision**: `permission_handler` ^12.0.1 (the host's pin) for status, request, permanently denied, and `openAppSettings()`.
- **Rationale**: `camera` alone can't tell "denied" from "permanently denied" on both platforms.

## R11. Temp storage and privacy (FR-040 to FR-045)

- **Decision**:
  - Each session lives in `getTemporaryDirectory()/qanoniah_doc_scan/<sessionId>/`. At start, every other directory under `qanoniah_doc_scan/` is deleted, which removes orphans from OS-killed sessions.
  - On cancel the session directory is deleted. On attach it is deleted after the PDF is moved to `qanoniah_doc_scan/out/`. The host owns and deletes that file; at each start the package also deletes `out/` files older than 24 hours.
  - The package has no logging calls at all (`print`, `debugPrint`, `log`, `developer.log`, `stdout`, `stderr`), and no `INTERNET` usage: it adds no network dependency and no HTTP client.
  - A test grep in CI fails on `http`, `dio`, or `HttpClient` imports under `lib/`.
- **Rationale**: Enforceable by tests (SC-006 to SC-008).

## R12. OCR evaluation set (FR-054, FR-055, SC-010)

- **Decision**:
  - Location: `tool/ocr_eval/pages/` holds 20 Arabic legal pages (court rulings, contracts, digit-heavy tables, low-light photos) and 5 English pages. Each page has a `.txt` ground truth. All are public or synthetic legal text, none is user data.
  - Runner: `example/integration_test/ocr_eval_test.dart` runs on an iOS simulator (Vision) and an Android emulator (Tesseract), through the real preparation, engine, and post-processing layers.
  - Metrics: CER, WER, and DER (Levenshtein over digits and `%` only).
  - Output: writes `tool/ocr_eval/results/<engine>-<model>.json`, and fails if SC-010 is not met or any metric regresses against the committed baseline.
- **Rationale**: It measures the shipped engines in the shipped pipeline, and a model swap is then "replace asset, run eval, commit baseline".
- **Open**: the starting page set. The design's 4 court-ruling pages (`assets/scan/case-1..4.jpg` in the design artifact) are internal, and must not be copied out of the design project without the owner's approval.

## R13. Accessibility (FR-064 to FR-067)

- **Decision**:
  - `Semantics` labels come from `DocScanStrings`.
  - Camera announcements go through `SemanticsService.announce`, throttled to one per state change.
  - Reorder offers semantic custom actions (move earlier, move later) plus a visible menu on each tile.
  - Widget tests run at `textScaler: TextScaler.linear(2.0)`.

## R14. Template code

- **Decision**: Delete the generated `getPlatformVersion` scaffold: `qanoniah_doc_scan_platform_interface.dart`, `qanoniah_doc_scan_method_channel.dart`, the matching tests, the native `getPlatformVersion` handlers, and the `plugin_platform_interface` dependency. Replace it with the Vision channel only.
- **Rationale**: No dead code (VI). The method-channel platform-interface pattern would add an abstraction with one implementation (P5).
