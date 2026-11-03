---

description: "Task list for Document Scan (001)"
---

# Tasks: Document Scan (مسح مستند)

**Input**: Design documents from `specs/001-document-scan/` ([plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md))

**Tests**: Included. Constitution P6 requires unit tests for every cubit and for the PDF and redaction builder. The spec's success criteria SC-006 to SC-010 are test-verified.

**Organization**: Tasks are grouped by user story (spec stories US1 to US15). US16 (search) is deferred and has no tasks (FR-060).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an incomplete task).
- **[Story]**: the spec user story the task serves.
- All paths are relative to the repo root.

## Rules for every task

- **Code**:
  - Cubits only, no logic in widgets.
  - Repos return `Either<Failure, T>`.
  - freezed with relative `part` directives; never `--delete-conflicting-outputs`.
- **Design**:
  - Every color, text style, spacing, and radius comes from `DocScanTheme` (`lib/src/core/doc_scan_theme.dart`).
  - Literals live only in `example/lib/fallback_theme.dart`.
  - Icons: iconsax, then untitled-ui, then qn, as SVG via flutter_svg.
- **Strings**:
  - Every user-facing string comes from `DocScanStrings`.
  - Arabic copy: فصحى مبسطة, Latin numerals, no em-dash, never «استشارة».
- **Privacy**: never log, print, or put in an event any document text, word, image, or file name.
- **Done means** `flutter analyze` is clean and `flutter test` passes.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Fix the toolchain, remove the template scaffold, and add dependencies.

- [X] T001 Set `environment: sdk: ">=3.9.0 <4.0.0"` and `flutter: ">=3.35.0"` in `pubspec.yaml` (research R1); add `.fvmrc` with `{"flutter": "3.35.2"}`.
- [X] T002 Delete the template scaffold:
  - `lib/qanoniah_doc_scan_platform_interface.dart`, `lib/qanoniah_doc_scan_method_channel.dart`
  - `test/qanoniah_doc_scan_test.dart`, `test/qanoniah_doc_scan_method_channel_test.dart`
  - The `getPlatformVersion` handlers in `ios/Classes/` and `android/src/main/`
  - The `plugin_platform_interface` dependency in `pubspec.yaml`
  - Fix `example/lib/main.dart`, `example/test/widget_test.dart`, and `example/integration_test/plugin_integration_test.dart` so they no longer reference it (research R14).
- [X] T003 Add dependencies to `pubspec.yaml` with the plan's pins: `camera`, `opencv_dart` (1.4.x), `pdf ^3.11.3`, `printing`, `flutter_bloc ^9.1.1`, `dartz ^0.10.1`, `freezed_annotation ^2.4.1`, `permission_handler ^12.0.1`, `path_provider ^2.1.3`, `flutter_svg ^2.0.10+1`, `uuid ^4.4.0`, `ffi`. Dev dependencies: `freezed ^2.4.7`, `build_runner`, `bloc_test`, `mocktail`. Run `flutter pub get` in the root and in `example/`, and confirm it resolves.
- [X] T004 [P] Add camera permission strings to the example app: `NSCameraUsageDescription` in `example/ios/Runner/Info.plist` and the `CAMERA` permission in `example/android/app/src/main/AndroidManifest.xml`. Document both as host requirements in `README.md`.
- [X] T005 [P] Create the empty folder layout from plan.md under `lib/src/` (`core/`, `core/session/`, `capture/`, `review/`, `page_prep/`, `recognition/`, `document/`, `viewer/`) and `test/` with matching folders. Do not add placeholder files.
- [X] T006 [P] Extend `analysis_options.yaml` with `prefer_relative_imports`, `avoid_print`, and `always_declare_return_types`, keeping `flutter_lints`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Spikes that de-risk the stack, the public types, the session, and the three ports. Every story depends on this phase.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Spikes (on real devices; record results in research.md under each R entry)

- [ ] T007 Spike R2. Build the example with `opencv_dart` (core and imgproc only) on iOS and Android with Flutter 3.35.2. Run Canny plus contour detection on a 640 px frame in an isolate and record the fps on a mid-range Android phone. Record the added release app size against the 12 MB budget, in `specs/001-document-scan/research.md` under R2.
- [ ] T008 Spike R4, Android. Add `tesseract4android` to `android/build.gradle`. Confirm `TessBaseAPICreate`, `TessBaseAPIInit3`, `TessBaseAPISetImage`, `TessBaseAPIGetIterator`, and the result-iterator symbols are callable from `dart:ffi` via `DynamicLibrary.open('libtesseract.so')`. Recognize one Arabic page with `ara.traineddata` (tessdata_fast). Record the outcome and fallback decision under R4.
- [ ] T009 Spike R4, iOS. Vendor `tesseract.xcframework` and `leptonica.xcframework` in `ios/Frameworks/`, link them in `ios/qanoniah_doc_scan.podspec`, and call the same C API via `DynamicLibrary.process()`. Record the outcome. If it fails, stop and ask the owner about the Vision-only fallback (R4).
- [X] T010 Spike R7. With the `pdf` package, render one Arabic court-ruling paragraph mixing Latin article numbers, plus a «نص محجوب» bar, using Noto Sans Arabic bytes. Also render an image page with an invisible text layer and check that its text extracts. Record shaping and bidi findings under R7.

### Public types and contracts

- [X] T011 [P] Create `DocScanTheme extends ThemeExtension<DocScanTheme>` in `lib/src/core/doc_scan_theme.dart`. It holds color, `TextStyle`, spacing, and radius fields for every surface (camera sheet dark surface, overlay frame, thumbnails, grid, build steps, preview, action bar, redaction bar, viewer), with `copyWith` and `lerp` and no default values. Add a static `of(BuildContext)` that throws `StateError` when the extension is missing (contract public-api).
- [X] T012 [P] Create `DocScanIcons` (one SVG asset path per icon listed in `specs/001-document-scan/contracts/public-api.md`) in `lib/src/core/doc_scan_icons.dart`, add `final DocScanIcons icons` to `DocScanTheme`, and add an internal `DocScanIcon` widget that renders a path via `SvgPicture.asset` tinted by a theme color. Copy nothing from the design kit (FR-072). Export `DocScanIcons` from `lib/qanoniah_doc_scan.dart`.
- [X] T013 [P] Create `DocScanStrings` in `lib/src/core/doc_scan_strings.dart`. It needs:
  - One named field per user-facing string in spec.md (stories 1 to 15, edge cases, accessibility labels), plus a plural helper `redactedWords(int n)` that follows FR-016.
  - `DocScanStrings.ar()`, `DocScanStrings.en()`, and `copyWith`.
  - The no-design-source copy from the spec's open question 7, marked `// TODO(ahmed): pending UX approval`.
- [X] T014 [P] Create the `DocScanEvent` class in `lib/src/core/doc_scan_event.dart`. Use a private constructor and one named factory per event in `specs/001-document-scan/contracts/events.md`, with typed parameters (int, bool, double, or Dart enums serialized to the listed strings).
- [X] T015 [P] Create `DocScanConfig`, `DocScanResult`, and the `DocScanPdfForm` enum in `lib/src/core/doc_scan_config.dart` and `lib/src/core/doc_scan_result.dart`, exactly as in `specs/001-document-scan/contracts/public-api.md`.
- [X] T016 [P] Create `lib/src/core/failures.dart` with freezed unions `CameraFailure` (permissionDenied, permanentlyDenied, unavailable), `RecognitionFailure` (engineUnavailable, failed), `BuildFailure` (tooLarge(size, limit), storageFull, unknown), and `StorageFailure`.
- [X] T017 Create `lib/qanoniah_doc_scan.dart` exporting only `DocScan`, `DocScanConfig`, `DocScanResult`, `DocScanPdfForm`, `DocScanTheme`, `DocScanIcons`, `DocScanStrings`, `DocScanEvent`, and `DocScanViewer` (P2). `DocScan` and `DocScanViewer` are exported when US1 and US10 implement them (no stub classes, to avoid dead code).
- [X] T018 [P] Test that `DocScanStrings.redactedWords` returns the correct form for n = 1, 2, 3, 10, 11, and 100, and that the ar/en defaults have no em-dash, no Arabic-Indic digits, and no «استشارة», in `test/core/doc_scan_strings_test.dart`.
- [X] T019 [P] Test that every `DocScanEvent` factory produces only allowed parameter types and names from `contracts/events.md`, in `test/core/doc_scan_event_test.dart`.

### Session and temp storage

- [X] T020 Create the freezed entities `ScanSession`, `CapturedPage`, `Quad`, `PageFilter`, `RecognitionState`, `PageText`, `Paragraph`, `Word`, and `PageMove` per `specs/001-document-scan/data-model.md`, in `lib/src/core/session/scan_session.dart`. Run `flutter pub run build_runner build`.
- [X] T021 Implement `ScanSessionRepo` in `lib/src/core/session/scan_session_repo.dart`. It must:
  - Start a session by deleting every directory under `tmp/qanoniah_doc_scan/` except `out/`, deleting files in `out/` older than 24 hours, then creating `<uuid>/`.
  - Add, replace, move, and remove pages. Removing a page deletes its files.
  - Expose a `Stream<ScanSession>`.
  - On cancel, delete the session directory.
  - On finish, delete it after the output PDF is moved to `out/`.
  - Return `Either<StorageFailure, T>` throughout (research R11).
- [X] T022 [P] Test `ScanSessionRepo` against a temp `Directory` in `test/core/scan_session_repo_test.dart`: orphan cleanup, `out/` files older than 24 hours removed and newer ones kept, cancel leaves no files, finish leaves only the output PDF (SC-007), and remove deletes files.

### Ports and test fakes

- [X] T023 [P] Define the `CameraSource` port (`initialize`, `previewWidget`, `Stream<CameraFrame> frames` with a downscaled luminance plane, `takePicture() → File`, `pause`/`resume`, `dispose`) in `lib/src/capture/data/camera_source.dart`, and a `FakeCameraSource` in `test/fakes/fake_camera_source.dart`.
- [X] T024 [P] Define the `EdgeDetector` port (`Future<FrameAnalysis> analyze(CameraFrame)` returning `Quad?`, sharpness, and luminance) in `lib/src/capture/data/edge_detector.dart`, and a `FakeEdgeDetector` in `test/fakes/fake_edge_detector.dart`.
- [X] T025 [P] Define the `TextRecognizer` port (`Future<Either<RecognitionFailure, RawRecognition>> recognize(File image, RecognitionLanguage lang)`, where `RawRecognition` holds lines or paragraphs of words with boxes and confidence) in `lib/src/recognition/data/text_recognizer.dart`, and a `FakeTextRecognizer` in `test/fakes/fake_text_recognizer.dart`.

### Architecture guard

- [X] T026 Create `test/architecture_test.dart`. It scans `lib/` and fails on:
  - Any import of `package:http`, `package:dio`, `dart:io` `HttpClient`, or `package:qanoniah`.
  - Any `print(`, `debugPrint(`, `log(`, `developer.log`, `stdout`, or `stderr` use (FR-043).
  - Any `Color(0x`, hex literal, or numeric `fontSize:` / `EdgeInsets` / `BorderRadius` literal under `lib/src/**/presentation/` (P1, P3, FR-040, FR-070).

**Checkpoint**: Spikes are recorded; public types, the session, and the ports compile and are tested.

---

## Phase 3: User Story 1 - Start a scan from the attach menu (Priority: P1) 🎯 MVP

**Goal**: `DocScan.start` opens the camera sheet directly. The example app's composer has the three cards.

**Independent Test**: In the example, open the attach menu, see «الصور · الملفات · مسح مستند» with no Camera, tap «مسح مستند», and the camera sheet opens.

- [X] T027 [US1] Implement `DocScan.start` in `lib/src/core/doc_scan.dart`. It must:
  - Throw `StateError` if a scan is already running or `DocScanTheme` is missing.
  - Resolve strings from `config.strings`, or from `DocScanStrings.ar()`/`.en()` by `Localizations.localeOf`.
  - Build the composition root (repo, ports, cubits).
  - Push a full-height modal flow with a nested `Navigator` for capture → review → build → preview.
  - Return `Future<DocScanResult?>`.
  - Emit `scan_started`.
- [X] T028 [P] [US1] Create `example/lib/fallback_theme.dart`: a `DocScanTheme` filled with Qanoniah kit token values for every field that has a token, and `DocScanIcons` pointing at iconsax SVGs the example copies from the host app's `assets/icons/ds/iconsax/` (not from the design kit). This is the only place literals are allowed. Fields with no token (spec, open design questions 1 to 6) are left unset; never invent a value (P3, FR-075). Until T029 is done, screens using those fields can be tested with fakes but the example does not run end to end.
- [ ] T029 [US1] After Ahmed answers spec open design questions 1 to 6 and 8, fill the remaining `DocScanTheme` and `DocScanIcons` fields in `example/lib/fallback_theme.dart` with the values he gives, and record them in `specs/001-document-scan/spec.md` under "Open design questions for Ahmed".
- [X] T030 [P] [US1] Create the example's fake composer in `example/lib/fake_composer.dart`:
  - An attach menu with three equal-width cards (76 px tall per design) «الصور · الملفات · مسح مستند». Photos and Files are inert.
  - «مسح مستند» calls `DocScan.start` with Noto Sans Arabic bytes from an example asset `example/assets/fonts/NotoSansArabic-Regular.ttf` (Google Fonts, OFL).
  - A debug panel showing the last result's fields and an event log.
- [X] T031 [US1] Wire `example/lib/main.dart`: RTL, `ar` locale, `fallbackTheme` in `ThemeData.extensions`, and the fake composer as home.
- [X] T032 [US1] Widget test: tapping «مسح مستند» in `FakeComposer`, with `FakeCameraSource` injected through a test-only parameter on the internal flow widget, shows the camera sheet; a second concurrent `start` throws. File: `example/test/fake_composer_test.dart`.

**Checkpoint**: The entry point works and the flow shell opens.

---

## Phase 4: User Story 2 - Capture pages automatically or manually (Priority: P1) 🎯 MVP

**Goal**: A dark camera sheet with a live edge frame, auto and manual capture, flash, thumbnails, and count. Cancel or drag-down discards everything.

**Independent Test**: With the fake camera, capture 2 pages auto and 1 manual, see a count of 3, cancel, and confirm no files remain.

- [X] T033 [P] [US2] Implement `CameraPluginSource` (adapter over `camera`) in `lib/src/capture/data/camera_source.dart`:
  - Back camera, highest still resolution, image stream downscaled to a 640 px long-edge Y plane.
  - Pause and resume on app lifecycle, dispose on exit.
- [X] T034 [P] [US2] Implement `OpenCvEdgeDetector` in `lib/src/capture/data/edge_detector.dart`, in a long-lived isolate. Per frame it runs blur → Canny → findContours → the largest convex quadrilateral with area at least 20% of the frame; it also computes Laplacian variance (sharpness) and mean luminance. Busy frames are dropped (research R2).
- [X] T035 [P] [US2] Implement `PermissionRepo` in `lib/src/capture/data/permission_repo.dart` (`permission_handler`): status, request, permanently denied, and `openAppSettings`, returning `Either<CameraFailure, Unit>`.
- [X] T036 [P] [US2] Implement `PagePreparer.prepare(File raw, Quad corners, Set<PageFilter> filters) → File` in `lib/src/page_prep/data/page_preparer.dart`. For US2 it does perspective warp and deskew, using the full frame when there are no corners (FR-005), and also writes `ocrInputFile` with shadow removal and adaptive binarization applied (FR-051 layer 1, research R3). User-visible filters come in US13.
- [X] T037 [US2] Implement `CaptureCubit` in `lib/src/capture/manager/capture_cubit.dart`:
  - States: permission (checking / denied / permanentlyDenied), searching, detected(Quad), steady, capturing, captured(count), limitReached.
  - Auto mode fires once when corners move less than 2% of width for 600 ms and sharpness and luminance pass their thresholds. A low-light or blur hint shows when they don't.
  - Manual mode captures on tap.
  - After capture: `PagePreparer` → `ScanSessionRepo.addPage`, and stop at `config.maxPages` (FR-009).
  - Events: `scan_page_captured`, `scan_page_limit_reached`, the permission events, and `scan_cancelled(step: capture)`.
- [X] T038 [US2] Unit tests for `CaptureCubit` with the fakes, in `test/capture/capture_cubit_test.dart`:
  - Steady, sharp, bright frames capture exactly once.
  - Dark or blurred frames never auto-capture.
  - Manual capture works with no corners (full frame).
  - Max pages stops capture.
  - Permission denied and permanently denied states.
  - Cancel calls repo cancel.
- [X] T039 [US2] Build the camera sheet in `lib/src/capture/presentation/camera_sheet.dart`:
  - Dark bottom sheet, title «مسح مستند», and a «تلقائي / يدوي» toggle.
  - «إلغاء» and a drag handle; dragging down cancels.
  - Hint text by state: «ضع المستند داخل الإطار، يُلتقط تلقائيًا» / «ضع المستند داخل الإطار ثم التقط» / «ضع الصفحة التالية ثم التقط».
  - Shutter button and «تم التقاط الصفحة» toast.
- [X] T040 [P] [US2] Build the edge overlay in `lib/src/capture/presentation/edge_frame_overlay.dart`: a `CustomPainter` that draws the tracked `Quad`, mapped from frame coordinates to preview coordinates.
- [X] T041 [P] [US2] Build the capture feedback in `lib/src/capture/presentation/capture_feedback.dart`: a short white flash, the shot flying to the bottom thumbnail, and the page-count badge.
- [X] T042 [P] [US2] Build the permission view in `lib/src/capture/presentation/camera_permission_view.dart`: an explanation, retry for denied, and «افتح الإعدادات» for permanently denied, re-checking on app resume.
- [ ] T043 [US2] Widget test for `CameraSheet` with fakes, in `test/widgets/camera_sheet_test.dart`: the hints change by state, the count updates, drag-down cancels, and the permission view shows on denied.

**Checkpoint**: Pages can be captured into the session.

---

## Phase 5: User Story 3 - Review, reorder, add, and retake pages (Priority: P1) 🎯 MVP

**Goal**: A 3-column grid with drag reorder, undo of the last move, add page, and retake last.

**Independent Test**: With 3 fake pages, move 3 to 1, undo, move again, add a 4th, retake the 4th, and confirm the order.

- [X] T044 [US3] Implement `ReviewCubit` in `lib/src/review/manager/review_cubit.dart`:
  - `move(from, to)` stores `lastMove`; `undoMove()`; any other change clears `lastMove` (data-model).
  - `addPage` returns to the camera; `retakeLast` replaces the last page and deletes its files.
  - Exposes `canBuild` (pages ≥ 1).
  - Events: `scan_review_opened`, `scan_page_moved(via)`, `scan_page_move_undone`, `scan_page_added`, `scan_page_retaken`.
- [X] T045 [US3] Unit tests for `ReviewCubit` in `test/review/review_cubit_test.dart`: move and undo, undo cleared by add or retake, retake keeps the count, an empty session can't build, and the order persists to the session.
- [X] T046 [US3] Build the review screen in `lib/src/review/presentation/review_screen.dart`:
  - Title «مراجعة الصفحات» and the hint «اسحب الصفحة لتغيير ترتيبها في الملف.».
  - A reorderable grid: 3 columns on phones, more as width allows (iPad, minimum 3), with long-press drag.
  - «إرجاع الصفحة لمكانها» snackbar after a move, «إضافة صفحة», «إعادة التقاط الأخيرة» (hidden at 0 pages), and the «إنشاء مستند قابل للتعديل» button.
- [X] T047 [US3] Wire the camera ⇄ review navigation in `lib/src/core/doc_scan.dart`. «مراجعة الصفحات» on the camera sheet opens review; «إضافة صفحة» and «إعادة التقاط الأخيرة» return to the camera in add or replace mode.
- [ ] T048 [US3] Widget test for `ReviewScreen` in `test/widgets/review_screen_test.dart`: the drag reorders, undo appears and works, iPad width shows at least 3 columns, and retake is hidden at 0 pages.

**Checkpoint**: The order is set and is what the PDF will use.

---

## Phase 6: User Story 4 - Build one PDF (Priority: P1) 🎯 MVP

**Goal**: Background recognition per page, a three-step build screen, and one image-form PDF in review order.

**Independent Test**: With the fake recognizer returning known text for 3 pages, build, and get one 3-page PDF in review order with matching text.

- [X] T049 [P] [US4] Implement `PostProcessor` in `lib/src/recognition/data/post_processor.dart` (research R6). It turns `RawRecognition` into `PageText`:
  - RTL word order for Arabic lines, LTR for Latin runs, with bidi isolation.
  - Line-to-paragraph grouping by gap and indent (skipped when the engine returns paragraphs).
  - Arabic-Indic and Persian digits to Latin, and `%` and decimal-separator fixes.
  - Word boxes kept in image coordinates.
- [X] T050 [P] [US4] Unit tests for `PostProcessor` in `test/recognition/post_processor_test.dart`: an Arabic line with Latin article numbers keeps its order, `٢٠٢٤` becomes `2024`, `% 15` becomes `15%`, paragraphs split on a large gap, and boxes are preserved.
- [ ] T051 [P] [US4] Implement `TesseractBindings` (an ffi `DynamicLibrary` loader per platform plus the C API signatures used in spike T008/T009) in `lib/src/recognition/data/tesseract_bindings.dart`, and `TesseractRecognizer` in `lib/src/recognition/data/tesseract_recognizer.dart`. The recognizer runs in an isolate, copies `assets/tessdata/<lang>.traineddata` to app-support on first use, and iterates words with boxes and confidence.
- [X] T052 [P] [US4] Add `assets/tessdata/ara.traineddata` and `assets/tessdata/eng.traineddata` (tessdata_fast, Apache 2.0) and declare them in the `pubspec.yaml` `flutter.assets`. Add `assets/tessdata/LICENSE` and a `CHANGELOG.md` note giving the model identifiers.
- [X] T053 [P] [US4] Implement the Vision channel in `ios/Classes/VisionRecognizerPlugin.swift`:
  - `supportsArabic` checks `supportedRecognitionLanguages()`.
  - `recognize(path, lang)` runs `VNRecognizeTextRequest` (`.accurate`, one language) on a background queue and returns lines with normalized boxes and confidence.
  - On iOS 26+ it uses `RecognizeDocumentsRequest` and returns paragraphs.
  - Register it in the plugin class.
- [X] T054 [P] [US4] Implement `VisionRecognizer` (a MethodChannel adapter that maps the payload to `RawRecognition`) in `lib/src/recognition/data/vision_recognizer.dart`.
- [X] T055 [US4] Implement `RecognitionRepo` in `lib/src/recognition/data/recognition_repo.dart`:
  - At session start, pick the engine by capability: Vision if iOS and `supportsArabic`, else Tesseract.
  - Queue each page's `ocrInputFile` in the background right after capture (FR-010), cancelling and re-queuing when the page changes.
  - Per-page language rule (research R5): Arabic first; an English pass if mean confidence is below the threshold or Arabic letters are under 40%; keep the higher-confidence pass.
  - Set `RecognitionState`: done, `noText` when there are no words, or failed.
  - Expose a progress stream.
- [X] T056 [US4] Unit tests for `RecognitionRepo` with `FakeTextRecognizer` in `test/recognition/recognition_repo_test.dart`:
  - Arabic is accepted with no English pass.
  - A low-confidence Arabic page triggers an English pass, and the higher pass wins.
  - Never a combined language.
  - A changed page re-queues.
  - No words gives `noText`.
- [X] T057 [P] [US4] Implement image form in `PdfBuilder` in `lib/src/document/data/pdf_builder.dart`: one page per `CapturedPage` in session order, the prepared JPEG at full bleed, and the recognized text drawn with invisible rendering mode at the word boxes (research R7). Return `Either<BuildFailure, BuildOutput>`.
- [X] T058 [P] [US4] Implement `SizeFitter` in `lib/src/document/data/size_fitter.dart`: for image form, re-encode at quality 85→75→65→55 and long edge 2200→1600 px until it is under `maxFileBytes`; if it is still over at the floor, return `BuildFailure.tooLarge(size, limit)` (FR-061, research R7).
- [X] T059 [US4] Unit tests in `test/document/pdf_builder_image_test.dart` and `test/document/size_fitter_test.dart`: page order equals session order, the text layer equals the recognized text, an oversize document is compressed under the limit, an impossible document returns `tooLarge`, and storage full maps to `storageFull`.
- [X] T060 [US4] Implement `BuildCubit` in `lib/src/document/manager/build_cubit.dart`:
  - Steps «تحليل الصور» (all pages prepared), «استخراج النص» (waits on the `RecognitionRepo` progress), and «إنشاء ملف PDF» (the builder, image form), with real progress (FR-012).
  - Cancel stops and cleans up.
  - Events: `scan_build_started`, `scan_build_completed`, `scan_build_failed`, `scan_page_no_text`.
- [ ] T061 [US4] Unit tests for `BuildCubit` in `test/document/build_cubit_test.dart`: the steps complete in order, a pending recognition holds step 2, pages already done are not reprocessed, cancel mid-build deletes intermediates, and a failure surfaces.
- [X] T062 [US4] Build the build screen in `lib/src/document/presentation/build_screen.dart`: an animated scan line and the three steps from `BuildCubit` state.

**Checkpoint**: One correct PDF is produced from the reviewed pages.

---

## Phase 7: User Story 5 - Attach the PDF and return to chat (Priority: P1) 🎯 MVP

**Goal**: «إرفاق كملف PDF» returns `DocScanResult`, cancel returns null, and temp files are cleaned up.

**Independent Test**: In the example, finish a scan and attach. The debug panel shows one PDF, the file name, the form, the size, and the per-page text, and the chip appears.

- [X] T063 [US5] Implement attach and finish in `lib/src/core/doc_scan.dart`:
  - The file name is «مستند-ممسوح-NN.pdf» with `NN = config.fileNumber` padded to 2 digits and bidi-isolated (FR-022).
  - Move the PDF to `out/`, call `ScanSessionRepo` finish, pop the flow with `DocScanResult` (`pageTexts` from `finalText` per page), and emit `scan_attached` with the contract params.
  - Every cancel path pops null and emits `scan_cancelled(step)`.
- [X] T064 [US5] Add the MVP attach bar (attach button «إرفاق كملف PDF», note «تُدمج الصفحات في ملف PDF واحد ويُقرأ نصها قبل الإجابة.», and the size-limit message on `tooLarge` with `scan_size_limit_exceeded`) in `lib/src/document/presentation/attach_bar.dart`. Place it on the build screen's completion state until US6 replaces it with the preview.
- [X] T065 [US5] Show the result chip «مستند-ممسوح-01.pdf» and the debug fields in `example/lib/fake_composer.dart`.
- [X] T066 [US5] Integration test `example/integration_test/flow_test.dart`, with the fake camera and fake recognizer injected:
  - Capture 3 pages → reorder → build → attach gives one result with 3 pages in order, form `image`, and an empty session directory.
  - Cancel at each step gives null and no files (SC-007, SC-009).

**Checkpoint**: The MVP is complete: capture, review, one PDF, attach. Demo-able end to end.

---

## Phase 8: User Story 6 - Preview the PDF before attaching (Priority: P2)

**Goal**: A preview of every page with a page sidebar, the count, the size, and the tip.

**Independent Test**: Build a fake 4-page document; the preview shows all pages, the sidebar jumps, and the tip shows.

- [X] T067 [US6] Implement `PreviewCubit` (core part) in `lib/src/document/manager/preview_cubit.dart`. It has the view (text / photo), the current page, the page count, and the size of the form `edits.isDirty` currently implies (recomputed after each edit or redaction), and an `attach()` that reuses the build-step image-form PDF when not dirty and rebuilds in text form when dirty (FR-011). Emits `scan_preview_opened`.
- [X] T068 [US6] Build the preview screen in `lib/src/document/presentation/preview_screen.dart`: title «معاينة ملف PDF», the page sidebar, «N صفحات · X MB», the tip «يمكنك تحديد أي نص لحجبه أو تعديله قبل الإرسال.», the text view rendering `PageText` paragraphs, a «لم يُعثر على نص في هذه الصفحة» marker for `noText` pages, and the attach bar from T064.
- [X] T069 [US6] Route build-complete → preview in `lib/src/core/doc_scan.dart`, and remove the temporary placement of the attach bar on the build screen from T064.
- [ ] T070 [US6] Unit test `test/document/preview_cubit_test.dart` (navigation and size) and widget test `test/widgets/preview_screen_test.dart` (sidebar jump, tip, no-text marker).

---

## Phase 9: User Story 7 - Edit recognized text (Priority: P2)

**Goal**: An edit mode where every paragraph is editable; edited text is what is sent, in text form.

**Independent Test**: Edit one paragraph and attach. The returned text and the PDF contain the edit, not the original, and the form is `text`.

- [X] T071 [US7] Implement `DocumentEdits` per data-model (replacements, redactedWords, redactedParagraphs, `isDirty` ignoring reverted changes, `redactedWordCount`, `finalText(page)`, and an edit clearing word redactions in that paragraph) in `lib/src/core/session/document_edits.dart`.
- [X] T072 [US7] Unit tests for `DocumentEdits` in `test/core/document_edits_test.dart`: an edit then a revert is not dirty, `finalText` uses the replacement, and an edit clears word redactions.
- [X] T073 [US7] Implement text form in `PdfBuilder` in `lib/src/document/data/pdf_builder.dart`: pages laid out from `finalText` paragraphs with `config.pdfFont` (and `pdfFontBold` if given), RTL with Arabic shaping and mixed-script order from spike T010, and no photos.
- [X] T074 [US7] Unit test `test/document/pdf_builder_text_test.dart`: the text-form PDF contains the edited strings and not the originals, and contains no image XObjects (FR-042).
- [X] T075 [US7] Add edit mode to `PreviewCubit`: enter and exit, `editParagraph`, and the action bar's «تعديل» opening the selected paragraph. Events: `scan_edit_mode_entered`, `scan_paragraph_edited`.
- [X] T076 [US7] Build edit mode in `lib/src/document/presentation/edit_mode_view.dart`: hint «عدّل نص أي فقرة، أو احجبها كاملة بزر العين.», each paragraph an RTL-aware text field (`TextDirection` by the paragraph's language), and a «تم» / «تعديل» toggle.
- [ ] T077 [US7] Tests: the `PreviewCubit` edit flow in `test/document/preview_cubit_edit_test.dart`, and edit then attach giving form `text` with the edited `pageTexts`.

---

## Phase 10: User Story 8 - Redact selected text (Priority: P2)

**Goal**: Select words → «إخفاء النص المحدد» / «إظهار النص», with a counter; redacted words never leave the package.

**Independent Test**: Redact two words and attach. The words are absent from `pageTexts`, the PDF bytes, and all events; the form is `text`.

- [X] T078 [US8] Add word selection and redaction to `PreviewCubit`: a selection range over words, `redactSelection`, `revealSelection`, and the counter. Events: `scan_text_redacted(word_count)`, `scan_redaction_removed`.
- [X] T079 [US8] Build the selectable text view and the floating action bar in `lib/src/document/presentation/selection_action_bar.dart`. Use word-level hit testing on paragraphs, «إخفاء النص المحدد» / «إظهار النص» and «تعديل», the redacted-word style, and the counter with `DocScanStrings.redactedWords`.
- [X] T080 [US8] Privacy test `test/document/redaction_privacy_test.dart`, with redacted strings chosen to be unique:
  - They are absent from the decompressed PDF content streams, `pageTexts`, every `DocScanEvent` emitted, and the files left on disk after finish.
  - Any redaction gives form `text` (SC-006, FR-041).

---

## Phase 11: User Story 9 - Redact a whole paragraph (Priority: P2)

**Goal**: An eye button per paragraph in edit mode toggles «حجب الفقرة» / «إظهار الفقرة»; the paragraph shows as «نص محجوب».

**Independent Test**: Redact one paragraph and attach. It is absent everywhere, and the text-form PDF shows a «نص محجوب» bar.

- [X] T081 [US9] Add `toggleParagraphRedaction` to `PreviewCubit`; revealing restores prior edits. Event: `scan_paragraph_redacted`, and `scan_redaction_removed` on reveal.
- [X] T082 [US9] Add the eye button and the «نص محجوب» bar to `lib/src/document/presentation/edit_mode_view.dart`, and the bar rendering to text form in `lib/src/document/data/pdf_builder.dart`.
- [ ] T083 [US9] Extend `test/document/redaction_privacy_test.dart` with paragraph redaction: the paragraph is absent, the bar is present, and a reveal restores the edited text.

---

## Phase 12: User Story 10 - Open the attached PDF read-only (Priority: P2)

**Goal**: `DocScanViewer` shows the returned PDF read-only; redactions stay.

**Independent Test**: Attach with a redacted paragraph, tap the chip; the viewer has no tools and shows the bar.

- [X] T084 [US10] Implement `DocScanViewer` in `lib/src/viewer/presentation/doc_scan_viewer.dart`: rasterize with `Printing.raster`, page by page, lazily; show the file name in the header; no edit or reveal controls. Emit no events itself; the host's tap emits `scan_viewer_opened` through a static helper `DocScanEvent.viewerOpened()` exposed for the host.
- [X] T085 [US10] Open the viewer from the chip in `example/lib/fake_composer.dart`.
- [ ] T086 [US10] Widget test in `test/widgets/doc_scan_viewer_test.dart`, using a PDF from `PdfBuilder` text form: it renders the pages and finds no editable or reveal widget.

---

## Phase 13: User Story 11 - Delete a page (Priority: P2)

**Goal**: «حذف الصفحة» with confirmation removes a page and its files.

**Independent Test**: Delete page 2 of 3 and build; the result is a 2-page PDF.

- [X] T087 [US11] Add `deletePage(id)` to `ReviewCubit` (deletes files via the repo, clears `lastMove`, returns to the camera when 0 pages remain). Event: `scan_page_deleted`.
- [X] T088 [US11] Add a delete action on the tile and a confirmation dialog («حذف الصفحة N؟» / «ستُحذف الصورة من هذا المسح ولن تُضاف إلى الملف.») in `lib/src/review/presentation/delete_page_dialog.dart`.
- [ ] T089 [US11] Extend `test/review/review_cubit_test.dart`: the files are deleted, deleting the last page returns to the camera, and build yields N-1 pages.

---

## Phase 14: User Story 12 - Adjust page corners (Priority: P2)

**Goal**: «زاوية الصفحة»: drag four corners, then «حفظ الصفحة» re-crops and re-recognizes, or «إعادة الالتقاط».

**Independent Test**: Move the corners and save; the prepared image is re-cropped and recognition re-queues.

- [X] T090 [US12] Add `adjustCorners(pageId, Quad)` to `ReviewCubit`: it re-runs `PagePreparer` from `rawFile`, replaces `preparedFile`, and resets recognition to pending (via `RecognitionRepo` re-queue). Event: `scan_corners_adjusted`.
- [X] T091 [US12] Build the corner screen in `lib/src/review/presentation/corner_adjust_screen.dart`: the raw image, four draggable handles constrained to the image, the hint «يمكنك ضبط حدود الصفحة بسحب الزوايا», «حفظ الصفحة», and «إعادة الالتقاط».
- [ ] T092 [US12] Tests: `ReviewCubit` re-prepare and re-queue in `test/review/review_cubit_corners_test.dart`.

---

## Phase 15: User Story 13 - Page filters (Priority: P3)

**Goal**: «توضيح الصفحات» with combinable filters, «تطبيق على كل الصفحات», and «إعادة الضبط»; recognition runs on the filtered page.

**Independent Test**: Apply two filters to all pages; all change, and reset restores «الأصل».

- [X] T093 [P] [US13] Add the user-visible filters to `PagePreparer` in `lib/src/page_prep/data/page_preparer.dart`, using the research R3 mapping (auto contrast, unsharp, CLAHE, gray, and reusing T036's shadow removal and adaptive threshold) applied in a fixed order; `ocrInputFile` is still produced on top.
- [ ] T094 [P] [US13] Unit tests in `test/page_prep/page_preparer_test.dart` on a fixture image: each filter changes the output deterministically, the combination order is fixed, and «الأصل» equals the warp only.
- [X] T095 [US13] Add `setFilters(pageId | all, filters)` and `resetFilters` to `ReviewCubit`, re-preparing and re-queuing recognition. Event: `scan_filter_applied`.
- [X] T096 [US13] Build the filters sheet in `lib/src/review/presentation/filters_sheet.dart`: the seven filter chips, «تطبيق على كل الصفحات», «إعادة الضبط», and the hint «يمكن الجمع بين أكثر من فلتر لتوضيح النص، وتُقرأ الصفحة بعد التحسين بدقة أعلى.».

---

## Phase 16: User Story 14 - Photo view and scan color (Priority: P3)

**Goal**: The preview switches to a photo view; «لون المسح» (ألوان / رمادي / أبيض وأسود) applies when the PDF is image form.

**Independent Test**: Without edits, choose «رمادي» and attach; the PDF is image form with grayscale photos.

- [X] T097 [US14] Add `showPhotoView`, `setColorMode` (color/gray/bw), and the availability rule (color mode disabled with a note «سيُرسل الملف كنص» when `edits.isDirty`) to `PreviewCubit`. Pass the color mode to the image-form builder. Events: `scan_photo_view_opened`, `scan_color_mode_changed`.
- [X] T098 [US14] Build the photo view and the «لون المسح» control in `lib/src/document/presentation/photo_view.dart`, and apply the color mode in `lib/src/document/data/pdf_builder.dart` image form.
- [ ] T099 [US14] Tests in `test/document/preview_cubit_photo_test.dart`: the photo view has no edit tools, gray gives grayscale JPEGs, and a dirty document disables color mode and yields text form.

---

## Phase 17: User Story 15 - Rename the document (Priority: P3)

**Goal**: «إعادة تسمية المستند» sets the returned file name.

**Independent Test**: Rename and attach; `fileName` is the new name plus `.pdf`.

- [X] T100 [US15] Add `rename(String)` to `PreviewCubit`: trim the input, reject an empty name or path separators, keep `.pdf`, and keep the name out of events. Event: `scan_document_renamed`. Use the name in T063's result.
- [X] T101 [US15] Build the rename sheet in `lib/src/document/presentation/rename_sheet.dart`, with the title «إعادة تسمية المستند».
- [X] T102 [US15] Tests in `test/document/preview_cubit_rename_test.dart`: the name is applied, an invalid name is rejected, and no event carries the name.

---

## Phase 18: OCR evaluation gate (FR-054, FR-055, SC-010, SC-011)

**Purpose**: Make every engine or model change measurable and gated.

- [ ] T103 Ask the owner which pages may form the evaluation set (research R12 open item), then add the approved pages and their ground truth to `tool/ocr_eval/pages/` (20 Arabic, 5 English, public or synthetic legal text, no user data), with `tool/ocr_eval/README.md` explaining provenance and the swap procedure.
- [ ] T104 [P] Implement the metrics (Levenshtein CER, WER, DER over digits and `%`) in `tool/ocr_eval/metrics.dart`, with unit tests in `test/tool/ocr_eval_metrics_test.dart`.
- [ ] T105 Write `example/integration_test/ocr_eval_test.dart`. It runs each page through the real `PagePreparer` → `RecognitionRepo` (the device's engine) → `PostProcessor`, computes the metrics, writes `tool/ocr_eval/results/<engine>-<model>.json`, and fails if CER > 3%, WER > 8%, DER > 1%, or any metric regresses against the committed baseline.
- [ ] T106 Run T105 on an iOS 18+ simulator (Vision) and an Android emulator (Tesseract), and commit the baselines in `tool/ocr_eval/results/`. If a target is missed, report it to the owner before continuing.

---

## Phase 19: Polish & Cross-Cutting Concerns

**Purpose**: Accessibility (FR-064 to FR-067), edge cases, docs, final verification.

- [ ] T107 [P] Add `Semantics` labels from `DocScanStrings` to every control in `lib/src/**/presentation/` (FR-064).
- [ ] T108 [P] Add spoken camera announcements via `SemanticsService.announce` (page detected, steady, captured with count), throttled to one per state change and only when a screen reader is active, in `lib/src/capture/presentation/camera_sheet.dart` (FR-065).
- [X] T109 [P] Add non-drag reorder (semantic custom actions plus a tile menu «نقل للأمام» / «نقل للخلف») in `lib/src/review/presentation/review_screen.dart`, wired to `ReviewCubit.move(via: action)` (FR-066).
- [ ] T110 Widget tests at `TextScaler.linear(2.0)` for every screen in `test/widgets/text_scale_test.dart`: no overflow errors (FR-067).
- [ ] T111 [P] Handle storage full in capture and build: an error message, pages kept, no PDF returned. Do this in `lib/src/capture/manager/capture_cubit.dart` and `lib/src/document/manager/build_cubit.dart`, with tests.
- [ ] T112 [P] Handle backgrounding: pause the camera and resume it on return, and keep the build going or restart it, with no partial result. Do this in `lib/src/capture/manager/capture_cubit.dart` and `lib/src/document/manager/build_cubit.dart`, with tests.
- [ ] T113 [P] Document the host integration steps from `specs/001-document-scan/contracts/public-api.md` (theme, font bytes, gating, mapping the result, events, viewer, full release) in `README.md`. Add a `CHANGELOG.md` 0.1.0 entry.
- [ ] T114 Run the quickstart.md sections 1 to 4 and record the results in `specs/001-document-scan/quickstart.md`.
- [ ] T115 Run the quickstart.md section 5 on devices (performance, network monitor, VoiceOver, TalkBack, 200% text, permissions, iPad) and record the results in `specs/001-document-scan/quickstart.md`. Report any failed SC to the owner.
- [ ] T116 Run the `anti-koshary` skill Pass 1 over `lib/` and report the findings. Apply Pass 2 only after the owner approves (CLAUDE.md).

---

## Implementation notes (2026-11-03)

- **R4 changed:** recognition uses one MethodChannel (`qanoniah_doc_scan/recognition`), not `dart:ffi`. Android answers with tesseract4android 4.8.0 (JitPack) through its Java API, the fallback research R4 already allowed; iOS answers with Vision. So T051 (ffi bindings) is replaced by `PlatformTextRecognizer`, and T009 (vendored iOS Tesseract) is not done: on iOS without Arabic Vision the page stays image-only (`engineUnavailable`). Owner decision still open for iOS 15 to 17.
- **T053:** `RecognizeDocumentsRequest` (iOS 26) is not used yet; it needs the iOS 26 SDK on CI. Vision lines are grouped into paragraphs by `PostProcessor`.
- **PagePreparer** is a concrete class; tests implement it (no new port).
- **R7 still open:** text-form Latin-in-Arabic ordering defect remains (pdf package). `DocScanConfig.pdfFontFallback` added (contract updated).
- **T032/T066** are covered by `test/widgets/flow_test.dart` (full flow with fakes, cancel, second start), not in `example/`.
- **Camera cancel never discards captured pages** (owner, 2026-11-03): with pages it opens review, with none it closes the flow. This changes FR-021 for the camera step; review and preview «إلغاء» still discard the scan.
- **Scan in the document assistant:** shown there too, through the shared tiles (owner, 2026-11-03).
- **Not done yet:** device spikes T007 to T009, T029 (Ahmed), T043, T048, T061, T070, T077, T083, T086, T089, T092, T094 (needs the OpenCV dylib in tests), T099, OCR gate T103 to T106 (needs the owner's page set), T108, T110 to T112, T114 to T116. Android build not verified locally: this machine has only JDK 8, 11 and 25, and Gradle 8.14 needs 17 or 21.

## Dependencies & Execution Order

### Phase dependencies

- **Setup (1)** → **Foundational (2)** → the user stories.
- If a spike (T007 to T010) fails, stop: the owner decides the fallback before Phase 4 and Phase 6 start.
- **US1 → US2 → US3 → US4 → US5**: this is the MVP chain. Each needs the previous one's flow position.
- **US6** needs US5. **US7** needs US6. **US8** and **US9** need US7 (`DocumentEdits` and text form). **US10** needs US5 and benefits from US9.
- **US11, US12, US13** need US3 (review) and are independent of US6 to US10.
- **US14** needs US6. **US15** needs US6.
- **OCR gate (18)** needs US4 (the real engines); it can run alongside US6 onward.
- **Polish (19)** comes after all chosen stories.

### Within each story

The engine and data layer come before cubits, cubits before widgets, then tests. Privacy tests (T080, T083) must pass before the story is called done.

### Blocked on Ahmed

Widgets read every value from `DocScanTheme`, so code is not blocked. Only `example/lib/fallback_theme.dart` values and the host's theme values for untokened items wait on the spec's "Open design questions for Ahmed". New copy marked `TODO(ahmed)` waits for UX approval before release.

## Parallel Example

```text
# Foundational, once T020 is done:
T022 ScanSessionRepo tests | T023 CameraSource port | T024 EdgeDetector port | T025 TextRecognizer port

# US2:
T033 CameraPluginSource | T034 OpenCvEdgeDetector | T035 PermissionRepo | T036 PagePreparer warp
then T040 overlay | T041 feedback | T042 permission view

# US4:
T049 PostProcessor | T051 Tesseract | T053 Vision Swift | T054 Vision adapter | T057 image PdfBuilder | T058 SizeFitter

# After US5: US11, US12, US13 (review side) in parallel with US6 → US7 (preview side)
```

## Implementation Strategy

### MVP first (US1 to US5)

1. Phases 1 and 2, including the spikes. Stop if a spike fails.
2. Phases 3 to 7: capture, review, one image-form PDF, attach. **Stop and validate** with `example/integration_test/flow_test.dart` and a device run.
3. Optionally hand the MVP to the host team for an integration build.

### Incremental delivery

1. Next: US6 → US7 → US8 → US9 → US10 (preview, edit, redaction, viewer). This completes the ClickUp acceptance criteria.
2. Then: US11, US12 (P2 extras).
3. Then: US13, US14, US15 (P3 extras).
4. Then: the OCR gate (18) and polish (19) before tagging `v0.1.0` for the host's pubspec.
