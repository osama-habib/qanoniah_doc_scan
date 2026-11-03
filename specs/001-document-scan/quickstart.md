# Quickstart: Validate Document Scan (001)

How to prove the feature works. This page covers commands and expected outcomes only. The API is
in [contracts/public-api.md](contracts/public-api.md), the events in
[contracts/events.md](contracts/events.md), and the entities in [data-model.md](data-model.md).

## Prerequisites

- Flutter 3.35.2, the host's pin (`fvm use 3.35.2` if you use fvm).
- An iOS simulator (iOS 18+ for the Vision path; iOS 15 to 17 for the Tesseract path) and an Android emulator or a mid-range device (API 26+).
- A physical device for the camera, edge detection, and performance checks.

## 1. Static checks

```bash
flutter pub get
```

```bash
flutter analyze
```

```bash
flutter test
```

Expected:
- Analyze is clean.
- All unit and widget tests pass, including `architecture_test.dart`: no `http`/`dio`/`HttpClient`/`package:qanoniah` imports under `lib/`, and no color or size literals in widgets.

## 2. Privacy and correctness tests (inside `flutter test`)

| Test | Proves |
|------|--------|
| `document/pdf_builder_test.dart` | Any redaction yields text form, and the PDF bytes contain none of the redacted strings (SC-006, FR-041) |
| `document/pdf_builder_test.dart` | Page order equals review order; `pageTexts` equals `finalText` (SC-009) |
| `document/size_fitter_test.dart` | Image form ends at or under `maxFileBytes`, or returns `tooLarge` |
| `core/scan_session_repo_test.dart` | Cancel and attach leave no session files; start removes orphans (SC-007) |
| `capture/capture_cubit_test.dart` | Auto capture fires once on a steady, sharp, bright fake stream, never on a dark or blurred one |
| `core/doc_scan_event_test.dart` | No event param is free text |

## 3. Full flow in the example app

```bash
cd example && flutter run
```

1. Tap «مسح مستند» in the fake composer. The camera sheet opens.
2. Capture 3 pages: 2 auto, 1 manual. The thumbnail count shows 3.
3. In review, move page 3 to first, undo, then move it again. Delete page 2 and retake the last page.
4. Tap «إنشاء مستند قابل للتعديل». The three steps complete in order, then preview opens.
5. Attach without changes. The composer chip «مستند-ممسوح-01.pdf» appears; the debug panel shows form `image`, size at or under 5 MB, and per-page text.
6. Repeat, redact 2 words and 1 paragraph, then attach. The form is `text`; the debug panel's text and the PDF contain neither.
7. Tap the chip. The viewer opens read-only and the redacted parts show as «نص محجوب».
8. Repeat, then cancel at each step. No result; the temp directory is empty.

The automated version runs with a fake camera:

```bash
cd example && flutter test integration_test/flow_test.dart
```

## 4. OCR evaluation gate

```bash
cd example && flutter test integration_test/ocr_eval_test.dart -d <ios-simulator>
```

```bash
cd example && flutter test integration_test/ocr_eval_test.dart -d <android-emulator>
```

Expected:
- Every engine shows CER at most 3%, WER at most 8%, DER at most 1%, with no regression against `tool/ocr_eval/results/` baselines (SC-010).
- To swap a model: replace the asset, rerun, and commit the new baseline. No code change (SC-011).

## 5. On-device checks (manual, before release)

- Mid-range Android phone:
  - One page recognized in 3 s or less.
  - A 5-page document reaches preview within 10 s (SC-005).
  - Edge detection feels live.
- Network monitor (Charles or Proxyman) during a full scan: zero requests from the app (SC-008).
- VoiceOver and TalkBack: capture, reorder via actions, and attach 3 pages without sight (SC-012).
- System text at 200%: no clipped text on any screen.
- Camera permission:
  - Deny: explanation and retry.
  - Permanently deny: the settings shortcut works.
- iPad, portrait and landscape: the review grid has at least 3 columns and nothing is stretched.
