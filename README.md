# qanoniah_doc_scan

Qanoniah document scan («مسح مستند»): capture with edge detection, review and reorder,
on-device text recognition, preview with edit and redaction, and one PDF.
Consumed by qanoniah-mobile through a pinned git tag.

Spec and plan: `specs/001-document-scan/`.

## Host requirements

- **iOS**: add `NSCameraUsageDescription` to the app's `Info.plist`. Minimum iOS 15.0.
- **Android**: declare `<uses-permission android:name="android.permission.CAMERA" />`. Minimum API 26.
- **iOS Podfile**: `permission_handler` needs `'PERMISSION_CAMERA=1'` in
  `GCC_PREPROCESSOR_DEFINITIONS`, and every pod at `IPHONEOS_DEPLOYMENT_TARGET = 15.0`.
- **Android repositories**: tesseract4android comes from JitPack. If the host sets
  `repositoriesMode` to `FAIL_ON_PROJECT_REPOS`, add `maven { url = uri("https://jitpack.io") }`
  to the host's `settings.gradle` repositories.
- **Toolchain**: Flutter 3.35.2 or later (`.fvmrc`).
- **iOS Tesseract**: `ios/qanoniah_doc_scan/Frameworks/CTesseract.xcframework` is built from
  source by `tool/build_ios_tesseract.sh` (Tesseract and Leptonica, Apache 2.0 / BSD-2).
- **Release**: the plugin has native code, so adopting or updating it needs a full app release,
  not a Shorebird patch.

## Host integration, in short

```dart
final DocScanResult? r = await DocScan.start(
  context,
  DocScanConfig(
    pdfFont: notoSansArabicRegularBytes,   // host asset
    pdfFontFallback: notoSansRegularBytes, // host asset
    fileNumber: nextScanNumber,
    maxFileBytes: 5 * 1024 * 1024,         // host upload limit
    onEvent: (DocScanEvent e) => analytics.track(e.name, properties: e.params),
  ),
);
// null: cancelled. Otherwise upload r.pdf as an attachment; the host owns and deletes it.
```

- Add a `DocScanTheme` (from the host's design tokens) to `ThemeData.extensions`.
- Gate before calling `start`: signed in, entitled, has credit.
- `DocScanViewer(pdf: r.pdf, fileName: r.fileName)` shows the attached file read-only; record
  `DocScanEvent.viewerOpened()` when opening it.

The full host integration (theme, icons, PDF font, gating, result mapping, events, viewer)
is in `specs/001-document-scan/contracts/public-api.md`.
