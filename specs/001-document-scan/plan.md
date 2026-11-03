# Implementation Plan: Document Scan (مسح مستند)

**Branch**: `001-document-scan` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-document-scan/spec.md`

## Summary

`qanoniah_doc_scan` is a standalone Flutter plugin. `DocScan.start` runs the whole journey
(capture with live edge detection, review and reorder, on-device text recognition, preview with
edit and redaction) and returns one PDF plus per-page final text, or null on cancel. The host
(qanoniah-mobile) keeps gating, upload, and analytics recording.

Technical approach:

- **Camera and page prep**: the `camera` plugin, with edge detection and page preparation in one shared Dart implementation over `opencv_dart`.
- **Text recognition**: three layers. Preparation and post-processing are package code. The engine sits behind one `TextRecognizer` port with two adapters: Apple Vision on capable iOS, and Tesseract 5 over `dart:ffi` elsewhere. Each page is recognized in its detected language.
- **PDF**: built with `pdf` in text form when the user edited or redacted, image form otherwise. Image form is compressed to fit the host's 5 MB limit.
- **Viewer and state**: the read-only viewer rasterizes with `printing`; Cubits per screen.

Details in [research.md](research.md).

## Technical Context

**Language/Version**: Dart `>=3.9.0 <4.0.0`, Flutter `>=3.35.0` (host pins 3.35.2). Swift 5.9 for the Vision channel. No Kotlin beyond the generated plugin class.

**Primary Dependencies**:

| Package | Version | Note |
|---------|---------|------|
| `camera` | — | |
| `opencv_dart` | 1.4.x (core and imgproc only) | spike |
| `pdf` | ^3.11.3 | host pin |
| `printing` | — | |
| `flutter_bloc` | ^9.1.1 | host pin |
| `dartz` | ^0.10.1 | host pin |
| `freezed_annotation` | ^2.4.1 | host pin; `freezed` ^2.4.7 as dev |
| `permission_handler` | ^12.0.1 | host pin |
| `path_provider` | ^2.1.3 | host pin |
| `flutter_svg` | ^2.0.10+1 | host pin |
| `uuid` | ^4.4.0 | host pin |
| `ffi` | — | |

Native: `tesseract4android` (Android), a vendored `tesseract.xcframework` and `leptonica` (iOS). Tessdata assets: `ara` and `eng` from tessdata_fast.

**Storage**: app temp directory only, one directory per session, deleted on cancel or attach. No database, no preferences, no disk persistence of session state.

**Testing**:

- `flutter_test`: cubits, post-processing, the PDF and redaction builder, the size fitter, strings, and events, with fakes for the three ports.
- Widget tests at 1.0× and 2.0× text scale.
- `integration_test` in `example/`: the full flow with a fake camera, plus the OCR evaluation run on a simulator and an emulator.

**Target Platform**: iOS 15+ (Vision Arabic where supported, Tesseract otherwise) and Android API 26+ (Tesseract). Phones and iPad. No web.

**Project Type**: Flutter plugin (library) with an `example/` app.

**Performance Goals**:

- Live edge detection at 8 fps or more on a mid-range Android phone.
- One page recognized in 3 s or less on a mid-range Android phone (SC-005).
- A 5-page document reaches preview within 10 s of tapping build.
- Review and preview stay smooth at 50 pages.

**Constraints**:

- Zero network I/O. No redacted content in any output or log.
- PDF size at or under the host's limit (5 MB).
- Added app size budget: 12 MB per platform (OpenCV + Tesseract + tessdata).
- Tokens only; no literals in widgets.
- Must resolve against the host's dependency pins.

**Scale/Scope**: one active scan per app. Documents of 1 to 50+ pages. About 9 screens or sheets: camera, review, corner adjust, filters, build, preview, edit, rename, viewer.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | How |
|-----------|--------|-----|
| I. Clean Architecture | PASS | Each feature under `lib/src/<feature>/` has `data/`, `manager/`, `presentation/`. Shared contracts are in `lib/src/core/`. No presentation-to-foreign-data imports. |
| II. Flavor Isolation | N/A | The package reads no dart-defines or `AppConfig` (P1). |
| III. Code Generation | PASS | freezed with relative `part` directives; generated files committed; never `--delete-conflicting-outputs`. |
| IV. State Management | PASS (via P8) | Cubits only, constructor-injected in `DocScan.start` and provided to the flow subtree. No get_it, per Package Addendum P8 (constitution 1.6.0). |
| V. OTA vs Release | PASS | Contains native code, so host adoption is a full release (contract, host step 7). |
| VI. Anti-Koshary | PASS | No logic in widgets. One image pipeline serves filters and recognition. One post-processor serves both engines. The result type is not the host's attachment. No dead template code (R14). Deferred search leaves no code behind. |
| P1. Host-agnostic | PASS | No `package:qanoniah` imports, no HTTP client (CI grep, R11), no auth or session state. |
| P2. Narrow public API | PASS | Exactly the surface in [contracts/public-api.md](contracts/public-api.md); everything else lives in `lib/src/`. |
| P3. Tokens from the host | PASS with open items | Everything comes from `DocScanTheme`, including icons as host SVG asset paths (`DocScanIcons`); literals only in `example/lib/fallback_theme.dart`, and only for tokened values. Values with no token (spec, "Open design questions for Ahmed" 1 to 10) are left unset, never improvised, until Ahmed answers. The PDF font comes from the host as bytes, not bundled. |
| P4. Privacy of redaction | PASS | Any redaction forces text form, whose PDF holds no photos and never receives redacted characters (data-model `finalText`). Temp cleanup per R11. |
| P5. Ports only at real seams | PASS | Three ports: `CameraSource`, `EdgeDetector`, `TextRecognizer`. All are platform/ML seams with test fakes. Nothing else is abstract. |
| P6. Runnable and tested | PASS | `example/` runs the full flow with the fallback theme. Unit tests for every cubit and for `PdfBuilder`. Analyze is clean per commit. |
| P8. Flow-scoped state, no locator | PASS | Composition root in `DocScan.start`; no locator. |
| P7. On-device OCR, measured | PASS | Vision and Tesseract on-device. Models are assets. The evaluation gate is R12. No training on user data. |
| Branching | PASS | `001-document-scan` from `main`; PR targets `main`. |

**Post-design re-check (after Phase 1)**: unchanged, all PASS. The design added no new port and
no new public type beyond the contract.

## Project Structure

### Documentation (this feature)

```text
specs/001-document-scan/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── public-api.md
│   └── events.md
├── checklists/requirements.md
└── tasks.md              # /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── qanoniah_doc_scan.dart              # exports only (P2)
└── src/
    ├── core/                           # public types + shared internals
    │   ├── doc_scan.dart               # DocScan.start: composition root, flow navigator
    │   ├── doc_scan_config.dart
    │   ├── doc_scan_result.dart
    │   ├── doc_scan_theme.dart         # ThemeExtension
    │   ├── doc_scan_icons.dart         # host SVG asset paths, part of the theme
    │   ├── doc_scan_strings.dart       # ar()/en()/copyWith
    │   ├── doc_scan_event.dart         # named factories only
    │   ├── failures.dart
    │   └── session/
    │       ├── scan_session.dart       # entities (data-model)
    │       ├── scan_session_repo.dart  # in-memory session + temp dir lifecycle
    │       └── document_edits.dart     # edits, redactions, finalText, isDirty
    ├── capture/
    │   ├── data/
    │   │   ├── camera_source.dart      # port + camera-plugin adapter
    │   │   ├── edge_detector.dart      # port + opencv adapter (isolate)
    │   │   └── permission_repo.dart
    │   ├── manager/capture_cubit.dart  # auto/manual, steadiness, limit
    │   └── presentation/               # camera sheet, frame overlay, thumbnails
    ├── review/
    │   ├── manager/review_cubit.dart   # reorder, undo, add, retake, delete
    │   └── presentation/               # grid, corner adjust, filters sheet
    ├── page_prep/
    │   └── data/page_preparer.dart     # warp, deskew, shadows, binarize, filters (R3)
    ├── recognition/
    │   ├── data/
    │   │   ├── text_recognizer.dart    # port
    │   │   ├── vision_recognizer.dart  # iOS channel adapter
    │   │   ├── tesseract_recognizer.dart # ffi adapter (isolate)
    │   │   ├── tesseract_bindings.dart
    │   │   ├── post_processor.dart     # RTL order, paragraphs, digits, boxes (R6)
    │   │   └── recognition_repo.dart   # engine choice, per-page language (R5), background queue
    │   └── manager/                    # none: recognition progress is read by build_cubit
    ├── document/
    │   ├── data/
    │   │   ├── pdf_builder.dart        # text/image form
    │   │   └── size_fitter.dart        # image-form compression (FR-061)
    │   ├── manager/
    │   │   ├── build_cubit.dart        # three steps, real progress
    │   │   └── preview_cubit.dart      # views, edit, redact, rename, color mode, attach
    │   └── presentation/               # build screen, preview, edit mode, action bar
    └── viewer/
        └── presentation/doc_scan_viewer.dart

assets/tessdata/ara.traineddata, eng.traineddata
ios/Classes/VisionRecognizerPlugin.swift
ios/Frameworks/tesseract.xcframework, leptonica.xcframework
android/build.gradle                    # tesseract4android dependency

test/
├── core/      (strings, events, document_edits, session repo)
├── capture/   (capture_cubit with fake camera/edge detector)
├── review/    (review_cubit)
├── recognition/ (post_processor, recognition_repo with fake recognizer)
├── document/  (pdf_builder privacy tests, size_fitter, build_cubit, preview_cubit)
├── widgets/   (golden-free widget tests at 1.0x and 2.0x)
└── architecture_test.dart  # no http/dio/qanoniah imports under lib/, no literals in widgets

example/
├── lib/main.dart, lib/fallback_theme.dart, lib/fake_composer.dart
└── integration_test/{flow_test.dart, ocr_eval_test.dart}

tool/ocr_eval/{pages/, results/, README.md}
```

**Structure Decision**: Single plugin package. Feature folders under `lib/src/` mirror the
journey, each with constitution I layering. `core/` holds the public value types and the
session that every step shares. `recognition` has no cubit of its own: its progress is a stream
from `RecognitionRepo` that `BuildCubit` folds. The template scaffold files are deleted (R14).

## Complexity Tracking

| Deviation | Why needed | Simpler alternative rejected because |
|-----------|------------|--------------------------------------|
| Two recognition adapters behind one port | The owner's OCR decision: Vision is clearly better where it supports Arabic, and Tesseract covers Android and older iOS | Tesseract-only loses quality on most iOS devices; Vision-only drops Android |

## Phase 2 preview (for /speckit-tasks)

Order:

1. Spikes R2, R4, R7 and the toolchain fix.
2. Core types and session.
3. P1 stories (capture, review, build, attach) end to end in `example/`.
4. P2 stories (preview, edit, redaction, viewer, delete, corners).
5. P3 stories (filters, photo view and color mode, rename).
6. Accessibility.
7. OCR evaluation gate.
8. Host integration notes.

Blocked on Ahmed: any widget that needs an untokened value.
