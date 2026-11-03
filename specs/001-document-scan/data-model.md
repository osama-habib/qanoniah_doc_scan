# Data Model: Document Scan (001)

All entities are in-memory for one scan session, except the page image files, which live in the
session temp directory (research R11). Nothing is persisted across sessions. Public types
(see [contracts/public-api.md](contracts/public-api.md)) are marked **public**; everything else is
internal under `lib/src/`.

## ScanSession (internal)

One run from `DocScan.start` to attach or cancel. It is owned by `ScanSessionRepo`, which every
cubit reads.

| Field | Type | Rule |
|-------|------|------|
| `id` | String (uuid v4) | Names the temp directory |
| `dir` | Directory | `tmp/qanoniah_doc_scan/<id>/` |
| `pages` | List<CapturedPage> | In review order; the list order IS the PDF order (FR-011) |
| `lastMove` | PageMove? | Only the most recent move; set by a move, cleared by undo or by any other edit (FR-007) |
| `captureMode` | auto / manual | Default auto |
| `startedAt` | DateTime | For `scan_attached` duration |
| `maxPages` | int? | From config; null means no limit (FR-009) |

States: `capturing ⇄ reviewing → building → previewing → attached | cancelled`. Cancel is
reachable from every state, and it deletes `dir` (FR-021).

## CapturedPage (internal)

| Field | Type | Rule |
|-------|------|------|
| `id` | String | Stable across reorder |
| `rawFile` | File | The original capture, kept for corner re-adjust (story 12) |
| `corners` | Quad | Detected corners, or the full frame when none were found (FR-005) |
| `filters` | Set<PageFilter> | Default `{original}`; combinable (story 13) |
| `preparedFile` | File | Warped and filtered image the user sees; image-form output |
| `ocrInputFile` | File | Hidden copy of `preparedFile` with shadow removal and binarization always applied; recognition input only, never shown or put in the PDF |
| `recognition` | RecognitionState | pending / done(PageText) / noText / failed |

Changing `corners` or `filters` regenerates `preparedFile` and `ocrInputFile` and resets `recognition` to pending
(story 12 scenario 1). Deleting a page deletes its files immediately (story 11).

## PageText (internal)

The output of post-processing (research R6). It is immutable.

| Field | Type | Rule |
|-------|------|------|
| `language` | ar / en | Chosen per page (FR-062) |
| `paragraphs` | List<Paragraph> | Reading order |

**Paragraph**: `id`, `words: List<Word>`, `text` (derived, bidi-isolated).
**Word**: `text`, `box: Rect` (image coordinates), `confidence: double`.

## DocumentEdits (internal)

The user's changes, keyed by `(pageId, paragraphId)`. It is kept apart from PageText so that a
revert restores the original.

| Field | Type | Rule |
|-------|------|------|
| `replacements` | Map<ParagraphKey, String> | Edited paragraph text (FR-015) |
| `redactedWords` | Map<ParagraphKey, Set<int>> | Word indexes (story 8) |
| `redactedParagraphs` | Set<ParagraphKey> | Whole paragraphs (story 9) |

Derived values:

- **`isDirty`**: true when any replacement differs from the original, or any redaction exists. Edits and redactions the user reverted don't count (FR-011).
- **`redactedWordCount`**: drives the counter with Arabic agreement (FR-016).
- **`finalText(page)`**: per paragraph, a redacted paragraph produces nothing. Otherwise the text is the replacement if one exists, else the original, minus redacted words. This is the only source for the returned text and the text-form PDF (FR-041, FR-042).

Editing a paragraph that has word redactions clears those word redactions. The user is editing
the text directly, so the edited text is what gets sent.

## PdfForm (**public** enum `DocScanPdfForm`)

`text` or `image`. Chosen at attach: `isDirty ? text : image` (FR-011). Build step 3 writes the image-form PDF; attach rebuilds in text form when `isDirty`. The preview's size estimate follows the form that `isDirty` currently implies and is recomputed after each edit or redaction.

## BuildOutput (internal)

| Field | Type | Rule |
|-------|------|------|
| `file` | File | Written to `tmp/qanoniah_doc_scan/out/` |
| `form` | PdfForm | |
| `sizeBytes` | int | Checked against `maxFileBytes` |
| `compressed` | bool | Image form only (FR-061) |

`PdfBuilder.build` returns `Either<BuildFailure, BuildOutput>`. Its failures are `tooLarge(size,
limit)`, `storageFull`, and `unknown`.

## DocScanResult (**public**)

What the host receives. It is a plain value and deliberately NOT the host's attachment model
(FR-032).

| Field | Type |
|-------|------|
| `pdf` | File (the host now owns it) |
| `fileName` | String (`مستند-ممسوح-NN.pdf` or the renamed name plus `.pdf`) |
| `form` | DocScanPdfForm |
| `pageCount` | int |
| `sizeBytes` | int |
| `pageTexts` | List<String> (final text per page, in order) |

## DocScanEvent (**public**)

`name` (one of the names in [contracts/events.md](contracts/events.md)) and `params`
(`Map<String, Object>`, where the values are only `int`, `bool`, `double`, or an allowed enum
string). The constructor is private; events come from named factories only, so free text cannot be
attached.

## EvaluationSample (tooling, not shipped)

`tool/ocr_eval/pages/<id>.jpg` plus `<id>.txt`, and `language`. A result row holds `engine`,
`modelId`, `cer`, `wer`, `der`, and `date`.
