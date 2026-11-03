# Feature Specification: Document Scan (مسح مستند)

**Feature Branch**: `001-document-scan`

**Created**: 2026-11-02

**Status**: Draft

**Input**: User description: "Document Scan (مسح مستند) for Qanoniah AI chat, delivered as the standalone package `qanoniah_doc_scan` that qanoniah-mobile adds via a pinned git tag. Source: `docs/feature-brief.md` (ClickUp z8y71x069k) and the Claude Design artifact named in CLAUDE.md. Full prompt: `docs/specify-prompt.md`."

## Context

Inside a Qanoniah AI chat, a user photographs a paper document. The pages become ONE PDF whose
text Qanoniah AI reads before answering. Before sending, the user can reorder pages, edit the
recognized text, and redact parts they do not want shared. «مسح مستند» replaces the Camera option
in the attach menu, which becomes three equal cards: «الصور · الملفات · مسح مستند».

The journey runs in two owners:

- **Host app (qanoniah-mobile)** owns the attach menu, gating (unauthenticated, not entitled,
  out of credit), uploading, the composer chip, and analytics recording.
- **This package** owns everything between "start scan" and "here is the result": camera,
  capture, review, text recognition, build, preview, edit, redaction, and the read-only viewer.

Journey steps and their design states (from the brief): 01 Entry `attach-menu` · 02 Capture
`scan-find`, `scan-pages` · 03 Review `scan-review`, `scan-reordered` · 04 Build `scan-build` ·
05 Preview and edit `scan-pdf`, `scan-edit` · 06 Attach `scan-attached`, `scan-view`.

## Clarifications

### Session 2026-11-02

- Q: Which design-only extras are in scope? → A: All except document search. Delete page, corner adjust, filters, color mode and PDF form, rename are in. Search is deferred: the design has its bar but no control that opens it and no storyboard state.
- Q: What happens when the PDF exceeds the host's 5 MB limit? → A: Depends on the PDF form. Image form: compress page images until it fits. Text form (built from recognized and edited text): pages carry no photos, so the file is small and normally fits. If either form still exceeds 5 MB, attach is blocked with the size shown and the user removes pages.
- Q: How are English or mixed-language pages recognized? → A: Detect the script of each page and recognize it with the matching language.
- Q: Which PDF form is the default? → A: None is chosen by the user. At attach the package picks automatically: text form if the document has any edit or redaction, image form otherwise.
- Q: If the OS ends the app mid-scan, is the session recovered? → A: No. The session is lost and its leftover files are deleted the next time a scan starts.
- Q: What accessibility support is required? → A: Basic: spoken labels on every control, spoken announcements for edge detection and capture, a non-drag way to reorder, and layouts that hold up at 200% text size.
- Q: What is the maximum number of pages per scan? → A: No limit by default. The host app can set a maximum when it starts the scan and change it at any time without a package update.
- Q: Are the proposed success targets fixed now? → A: Accuracy and speed targets (SC-005, SC-010) are fixed now as release gates. Analytics targets (SC-001 to SC-003) get their numbers after measuring the first 30 days; until then they are tracked without a target.

## User Scenarios & Testing *(mandatory)*

Stories 1 to 5 together form the MVP slice: capture, review, one PDF, attach. Each story is
testable on its own in the `example/` app with the fallback theme and fake camera / text
recognition.

### User Story 1 - Start a scan from the attach menu (Priority: P1)

The user taps + in the chat composer, sees three equal cards «الصور · الملفات · مسح مستند», and
taps «مسح مستند». The camera opens directly, with no intermediate screen.

**Why this priority**: It is the only way into the feature; without it nothing else is reachable.

**Independent Test**: In the host (or the example app's stand-in menu), open the attach menu,
confirm the three cards and the absence of a Camera option, tap «مسح مستند», confirm the camera
sheet opens.

**Acceptance Scenarios**:

1. **Given** an entitled, signed-in user in a chat, **When** they open the attach menu, **Then** they see exactly three equal cards «الصور», «الملفات», «مسح مستند» and no Camera option.
2. **Given** the attach menu is open, **When** the user taps «مسح مستند», **Then** the camera sheet opens directly.
3. **Given** a user who is signed out, not entitled to file upload, or out of credit, **When** they tap «مسح مستند», **Then** the host handles it with its existing gating and the package is never started.

---

### User Story 2 - Capture pages automatically or manually (Priority: P1)

The camera opens in a dark bottom sheet titled «مسح مستند». A frame tracks the page edges. In
«تلقائي» mode the page is captured once the frame is steady; in «يدوي» mode the user taps to
capture. Each capture shows a short white flash, flies to a bottom thumbnail, and updates the page
count. «إلغاء» or dragging the sheet handle down closes the camera and discards everything.

**Why this priority**: Capture is the first half of the core value: a paper page becomes a clean
digital page.

**Independent Test**: With a fake camera feed of a page, capture 2 pages in auto mode and 1 in
manual mode; confirm thumbnail and count show 3; cancel and confirm nothing remains.

**Acceptance Scenarios**:

1. **Given** the camera is open in «تلقائي», **When** a page is held steady inside the frame, **Then** it is captured once, with flash, thumbnail animation, and «تم التقاط الصفحة».
2. **Given** the camera is open in «تلقائي», **When** no page is in view, **Then** the hint reads «ضع المستند داخل الإطار، يُلتقط تلقائيًا» and nothing is captured.
3. **Given** the camera is open in «يدوي», **When** the user taps capture, **Then** the current frame is captured and the hint reads «ضع المستند داخل الإطار ثم التقط».
4. **Given** at least one page is captured, **When** the camera is ready for the next page, **Then** the hint reads «ضع الصفحة التالية ثم التقط» and the page count is visible.
5. **Given** any number of pages are captured, **When** the user taps «إلغاء» or drags the handle down, **Then** the flow closes, every captured image is deleted, and the host receives "cancelled".

---

### User Story 3 - Review, reorder, add, and retake pages (Priority: P1)

From the camera the user opens «مراجعة الصفحات»: a 3-column grid of captured pages. Long-press or
drag moves a page; after a move «إرجاع الصفحة لمكانها» undoes it. «إضافة صفحة» returns to the camera
to add pages at the end. «إعادة التقاط الأخيرة» replaces the last page. Hint: «اسحب الصفحة لتغيير
ترتيبها في الملف.»

**Why this priority**: The acceptance criterion "pages merge in review order" depends on it, and
paper pages are often captured out of order.

**Independent Test**: Capture 3 fake pages, move page 3 to position 1, undo, move again, add a
4th page, retake the 4th; confirm the final order shown matches the expected order.

**Acceptance Scenarios**:

1. **Given** 3 captured pages, **When** the user drags page 3 to the first position, **Then** the grid shows the new order and «إرجاع الصفحة لمكانها» appears.
2. **Given** a page was just moved, **When** the user taps «إرجاع الصفحة لمكانها», **Then** the page returns to its previous position.
3. **Given** the review grid, **When** the user taps «إضافة صفحة» and captures a page, **Then** the new page is appended at the end and the grid shows it.
4. **Given** at least 1 page, **When** the user taps «إعادة التقاط الأخيرة» and captures, **Then** the last page is replaced and the count is unchanged.
5. **Given** the review grid, **When** the user cancels, **Then** all pages are deleted and the host receives "cancelled".

---

### User Story 4 - Build one PDF (Priority: P1)

The user taps «إنشاء مستند قابل للتعديل». A progress screen with an animated scan line shows three
steps completing in order: «تحليل الصور · استخراج النص · إنشاء ملف PDF». The result is one PDF whose
pages follow the review order. Its form (text or image) is chosen automatically at attach (see
FR-011).

**Why this priority**: One PDF with readable text is the deliverable Qanoniah AI consumes.

**Independent Test**: With fake text recognition returning known text for 3 pages in a known
order, build; confirm one PDF of 3 pages in review order and that each page's text matches.

**Acceptance Scenarios**:

1. **Given** at least 1 reviewed page, **When** the user taps «إنشاء مستند قابل للتعديل», **Then** the three steps complete in order and exactly one PDF is produced.
2. **Given** pages reordered in review, **When** the PDF is built, **Then** its page order equals the review order.
3. **Given** text recognition already finished for some pages in the background, **When** build starts, **Then** finished pages are not processed again.
4. **Given** the build is in progress, **When** the user cancels, **Then** the build stops and all intermediate files are deleted.

---

### User Story 5 - Attach the PDF and return to chat (Priority: P1)

The user taps «إرفاق كملف PDF». The package returns the result to the host; the host shows
«مستند-ممسوح-01.pdf» in the composer with the note «تُدمج الصفحات في ملف PDF واحد ويُقرأ نصها قبل
الإجابة.» The host uploads it when the message is sent.

**Why this priority**: Completes the MVP loop; without attach the scan has no effect on the chat.

**Independent Test**: In the example app, finish a scan and tap attach; confirm the callback
receives one PDF plus per-page text and the example composer shows the file chip.

**Acceptance Scenarios**:

1. **Given** a built PDF, **When** the user taps «إرفاق كملف PDF», **Then** the host receives exactly one result containing one PDF file, its file name, and the final text of every page in order.
2. **Given** the user cancelled at any step, **When** the flow closes, **Then** the host receives no result and nothing is attached.
3. **Given** a result was returned, **When** the flow closes, **Then** every temp file except the returned PDF is deleted.

---

### User Story 6 - Preview the PDF before attaching (Priority: P2)

After build, «معاينة ملف PDF» shows the document with a page sidebar for navigation and the tip
«يمكنك تحديد أي نص لحجبه أو تعديله قبل الإرسال.»

**Why this priority**: Lets the user check the result and is the surface that edit and redaction
live on. The MVP can attach straight after build without it.

**Independent Test**: Build a fake 4-page document; confirm preview shows all pages, the sidebar
jumps to the selected page, and the tip is visible.

**Acceptance Scenarios**:

1. **Given** a built document, **When** the preview opens, **Then** all pages render in order with the sidebar and the tip.
2. **Given** the preview, **When** the user taps a page in the sidebar, **Then** the preview scrolls to that page.

---

### User Story 7 - Edit recognized text (Priority: P2)

In edit mode («عدّل نص أي فقرة، أو احجبها كاملة بزر العين.») every recognized paragraph is
editable. The edited text is what Qanoniah AI reads.

**Why this priority**: Recognition errors in names, dates, and article numbers change legal
meaning; correcting them before sending improves answers.

**Independent Test**: Enter edit mode on a fake page, change one paragraph, attach; confirm the
returned page text and the PDF text contain the edited paragraph and not the original.

**Acceptance Scenarios**:

1. **Given** the preview, **When** the user enters edit mode, **Then** every paragraph becomes editable.
2. **Given** a paragraph was edited, **When** the user attaches, **Then** the returned text and the PDF text layer contain the edited text.
3. **Given** the user selected text in preview, **When** they choose «تعديل» in the action bar, **Then** the containing paragraph opens for editing.

---

### User Story 8 - Redact selected text (Priority: P2)

In preview, selecting text opens an action bar above it. «إخفاء النص المحدد» redacts the selection;
selecting redacted text offers «إظهار النص» to undo. A counter shows «كلمة محجوبة / كلمتان محجوبتان
/ كلمات محجوبة».

**Why this priority**: Legal documents carry names, ID numbers, and amounts users must not share.
Redaction is a ClickUp acceptance criterion, but the MVP slice is usable without it.

**Independent Test**: Select two words on a fake page, redact, attach; confirm both words are
absent from the returned text, the PDF, and every emitted event, and that the PDF is in text form
with no photo.

**Acceptance Scenarios**:

1. **Given** selected text, **When** the user taps «إخفاء النص المحدد», **Then** the words show as redacted and the counter updates with correct Arabic number agreement.
2. **Given** redacted words, **When** the user selects them and taps «إظهار النص», **Then** they are restored.
3. **Given** redacted words, **When** the user attaches, **Then** the PDF is in text form, and those words are not in the returned text or anywhere in the PDF.

---

### User Story 9 - Redact a whole paragraph (Priority: P2)

In edit mode, the eye button next to a paragraph redacts it entirely («حجب الفقرة»); it then shows
as a «نص محجوب» bar and «إظهار الفقرة» restores it.

**Why this priority**: Faster than word selection for whole clauses; same privacy guarantee.

**Independent Test**: Redact one paragraph of a fake page, attach; confirm the paragraph is absent
from the returned text, the PDF, and events, and that the PDF is in text form.

**Acceptance Scenarios**:

1. **Given** edit mode, **When** the user taps the eye button on a paragraph, **Then** it shows as «نص محجوب».
2. **Given** a redacted paragraph, **When** the user taps «إظهار الفقرة», **Then** it is restored with any prior edits.
3. **Given** a redacted paragraph, **When** the user attaches, **Then** none of its text leaves the package.

---

### User Story 10 - Open the attached PDF read-only (Priority: P2)

Tapping the attachment chip in the composer opens the PDF in a read-only viewer with no edit
tools. Redactions stay redacted.

**Why this priority**: Lets the user confirm what is about to be sent.

**Independent Test**: Attach a document with one redacted paragraph; tap the chip in the example
composer; confirm the viewer opens, shows no edit tools, and shows the paragraph covered.

**Acceptance Scenarios**:

1. **Given** an attached scan, **When** the user taps the chip, **Then** the viewer opens read-only.
2. **Given** the document had redactions, **When** it is viewed, **Then** redacted parts appear covered and cannot be revealed.

---

### Design-only extras

The design artifact includes six capabilities that ClickUp does not. Each is a separate story.
Decided 2026-11-02 (FR-060): stories 11 to 15 are in scope; story 16 is deferred and nothing of it
is built, not even a hidden or flagged partial version.

#### User Story 11 - Delete a page (Priority: P2, in scope)

In review, «حذف الصفحة» asks «حذف الصفحة N؟» with «ستُحذف الصورة من هذا المسح ولن تُضاف إلى الملف.»
and removes the page.

**Independent Test**: Capture 3 pages, delete page 2, build; confirm a 2-page PDF.

**Acceptance Scenarios**:

1. **Given** 3 pages, **When** the user confirms deleting page 2, **Then** the grid shows 2 pages and the deleted image is removed from disk.

#### User Story 12 - Adjust page corners (Priority: P2, in scope)

«زاوية الصفحة»: the user drags the four corners to fix the page border («يمكنك ضبط حدود الصفحة بسحب
الزوايا»), then «حفظ الصفحة» or «إعادة الالتقاط».

**Independent Test**: Capture a fake page with wrong edges, drag corners, save; confirm the page
image is re-cropped to the new corners.

**Acceptance Scenarios**:

1. **Given** a captured page, **When** the user moves the corners and taps «حفظ الصفحة», **Then** the page is re-cropped and its text is recognized again.

#### User Story 13 - Page filters (Priority: P3, in scope)

«توضيح الصفحات»: «الأصل», «تحسين تلقائي», «إبراز النص», «إزالة الظلال», «تباين عالٍ», «رمادي»,
«أبيض وأسود»; combinable; «تطبيق على كل الصفحات»; «إعادة الضبط»; hint «يمكن الجمع بين أكثر من فلتر
لتوضيح النص، وتُقرأ الصفحة بعد التحسين بدقة أعلى.»

**Independent Test**: Apply two filters to one page and «تطبيق على كل الصفحات»; confirm all pages
change and «إعادة الضبط» restores «الأصل».

**Acceptance Scenarios**:

1. **Given** a page, **When** the user combines two filters, **Then** both apply and recognition runs on the filtered page.

#### User Story 14 - Photo view and scan color (Priority: P3, in scope)

The preview opens on the text view (editable, as in the design) and can switch to a photo view of
the captured pages (no editing). In the photo view «لون المسح» offers «ألوان», «رمادي»,
«أبيض وأسود», which applies when the PDF is attached in image form.

**Independent Test**: Without editing or redacting, switch to the photo view, choose «رمادي»,
attach; confirm the PDF is in image form with grayscale photos.

**Acceptance Scenarios**:

1. **Given** the preview text view, **When** the user switches to the photo view, **Then** pages show the photos and edit tools are unavailable.
2. **Given** no edit or redaction, **When** the user picks a color mode and attaches, **Then** every page in the image-form PDF uses it.
3. **Given** the document has an edit or redaction, **When** the user opens the photo view, **Then** «لون المسح» is unavailable and a note says the file will be sent as text.

#### User Story 15 - Rename the document (Priority: P3, in scope)

«إعادة تسمية المستند» replaces the default «مستند-ممسوح-01» name.

**Independent Test**: Rename to a custom name, attach; confirm the returned file name uses it with `.pdf`.

**Acceptance Scenarios**:

1. **Given** the preview, **When** the user renames the document, **Then** the returned file name is the new name plus `.pdf`.

#### User Story 16 - Search the document (Priority: P3, deferred)

«ابحث في المستند» highlights matches in the recognized text; «لا نتائج» when none. Deferred: the
design has the search bar but no control that opens it, no storyboard state, and the Arabic tip
does not mention search. Needs a design decision from Ahmed before it is scheduled.

**Independent Test**: Search a word present on page 2; confirm the preview jumps to and highlights it.

**Acceptance Scenarios**:

1. **Given** the preview, **When** the user searches a word that exists, **Then** matches are highlighted; **When** it does not exist, **Then** «لا نتائج» shows.

---

### Edge Cases

- **Camera permission denied**: the package shows an explanation with a retry that asks again; the user can cancel; the host receives "cancelled". No capture UI is shown without permission.
- **Camera permission permanently denied**: the explanation offers a shortcut to the system settings page for the app; on return with permission granted the camera opens.
- **0 pages**: «مراجعة الصفحات» and «إنشاء مستند قابل للتعديل» are unavailable; «إعادة التقاط الأخيرة» is hidden. Deleting the last page in review returns to the camera.
- **Very many pages**: by default there is no page limit. If the host set a maximum, capture is disabled at that count with a message. Review, build, and preview stay responsive at 50 pages; beyond that the 5 MB check (FR-061) is the practical bound.
- **Result over the host's 5 MB limit**: per FR-061. The user is never told the file attached and then sees an upload failure for size.
- **Low light or blurry page**: auto capture does not fire on a frame judged too dark or blurred, and a hint tells the user to improve light or hold steady; manual capture stays available.
- **No edges found**: auto capture does not fire; manual capture captures the full frame.
- **Text recognition finds no text on a page**: the page is kept as an image in the PDF; preview marks it as having no readable text; its returned text is empty; text edit and text redaction are unavailable on that page.
- **App backgrounded mid-flow**: the camera is released while backgrounded and resumes on return; captured pages, order, edits, and redactions are kept for as long as the app process lives. If the OS ends the process, the session is not recovered: nothing is offered back to the user, and its leftover temp files are deleted the next time a scan starts. No session state is ever written to disk for recovery.
- **Interruption during build** (call, backgrounding): build resumes or restarts on return; no partial PDF is ever returned.
- **RTL and mixed Arabic/Latin text**: the UI is RTL; Latin words, numbers, percentages, and article references inside Arabic text keep correct reading order in preview, edit, and returned text; digits are never reordered or converted to Arabic-Indic.
- **English or mixed-language pages**: per FR-062. A document may mix Arabic and English pages; each page is recognized in its own language. A page mixing both scripts is recognized in its dominant script.
- **iPad**: the flow fits the larger screen without stretched content; the review grid shows at least 3 columns and may show more as width allows; camera sheet, preview, and viewer work in portrait and landscape.
- **Storage full while saving a page or the PDF**: the user sees an error, captured pages are kept where possible, and no corrupt PDF is returned.
- **Recognition is slower than the user** (user reaches build before background recognition finishes): build waits for remaining pages; the «استخراج النص» step stays active until done.

## Requirements *(mandatory)*

### Functional Requirements

**Capture and review**

- **FR-001**: The package MUST open the camera directly when started, in a dark bottom sheet titled «مسح مستند».
- **FR-002**: The camera MUST show a frame that tracks detected page edges live.
- **FR-003**: In auto mode the package MUST capture once when the detected page is steady, sharp, and lit well enough; in manual mode it MUST capture on tap. The user MUST be able to switch modes with «تلقائي» / «يدوي».
- **FR-004**: Each capture MUST give visible feedback (short white flash, thumbnail animation, updated page count, «تم التقاط الصفحة»).
- **FR-005**: Each captured page MUST be perspective-corrected to the detected edges (full frame when none were found).
- **FR-006**: The review grid MUST show all captured pages in current order, 3 columns on phones.
- **FR-007**: Users MUST be able to move a page to any position by long-press or drag, and undo the last move with «إرجاع الصفحة لمكانها».
- **FR-008**: Users MUST be able to add pages (appended at the end) and retake the last page.
- **FR-009**: A scan MUST have no page limit unless the host passes a maximum page count when starting it; with a maximum set, capture MUST stop at that count with a message.

**Build, preview, edit, redact**

- **FR-010**: Text recognition MUST start per page in the background right after capture and MUST finish before the preview opens.
- **FR-011**: Build MUST produce exactly one PDF whose page order equals the review order, in one of two forms. The user does not choose the form; at attach the package picks text form if the document has any active edit or redaction, and image form otherwise:
  - **Text form**: each page is built from its final text (edited, redaction-free), with redacted parts shown as «نص محجوب» bars. It carries no photo.
  - **Image form**: each page is the captured photo in the chosen color mode, plus a selectable text layer of its recognized text.
  An edit or redaction the user reverted before attach does not count.
  Build step 3 produces the image-form PDF. At attach, if the document has any edit or redaction, the package rebuilds it in text form. The size shown in preview is the size of the form that would be attached at that moment, recomputed after each edit or redaction.
- **FR-012**: Build MUST show the three steps «تحليل الصور · استخراج النص · إنشاء ملف PDF» completing in order with real progress, not a fixed timer.
- **FR-013**: The preview MUST show every page with a page sidebar, the page count, the file size, and the tip «يمكنك تحديد أي نص لحجبه أو تعديله قبل الإرسال.»
- **FR-014**: Selecting text in preview MUST open an action bar with «إخفاء النص المحدد» (or «إظهار النص» on redacted text) and «تعديل».
- **FR-015**: Edit mode MUST make every recognized paragraph editable and give each paragraph an eye button toggling «حجب الفقرة» / «إظهار الفقرة»; a redacted paragraph MUST show as «نص محجوب».
- **FR-016**: The redaction counter MUST follow Arabic number agreement: 1 «كلمة محجوبة», 2 «كلمتان محجوبتان», 3 to 10 «كلمات محجوبة», 11 and above «كلمة محجوبة», always with Latin numerals.
- **FR-017**: Redaction MUST be reversible until the user attaches; after attach it is final.
- **FR-018**: Text edit and redaction MUST be available in the preview's text view only; edits and redactions MUST persist when switching between text and photo views. Because any redaction forces text form (FR-011), a redacted document's PDF MUST contain no photo of any page.

**Attach, cancel, view**

- **FR-020**: «إرفاق كملف PDF» MUST end the flow and return the result to the host (see Package/host contract).
- **FR-021**: Cancel («إلغاء») on review, build or preview MUST end the flow, return no result, and delete every temp file of the session. On the camera, «إلغاء» or dragging the sheet down MUST NOT discard captured pages: with pages it opens review, with none it ends the flow as above (owner, 2026-11-03).
- **FR-022**: The default file name MUST be «مستند-ممسوح-NN.pdf», where NN is a 2-digit number the host supplies (default 01), shown with correct bidi isolation.
- **FR-023**: The package MUST provide a read-only viewer the host opens with a returned PDF; it MUST offer no edit or reveal tools.

**Package/host contract**

- **FR-030**: The host MUST start the flow with: the PDF font bytes (Noto Sans Arabic, from its own assets), optional overrides for any user-facing string, an event callback, the file-name number, an optional maximum page count, and the maximum file size. The theme, including icons, is read from the host's `ThemeData.extensions`, filled from Qanoniah design kit tokens and the host's own iconsax assets. Nothing else is required to run.
- **FR-031**: On attach the package MUST return exactly one result: one PDF file, its file name, its form (text or image), its page count, its size, and the final text of each page in order (edited, redaction-free). On cancel it MUST return nothing.
- **FR-032**: The result MUST be a plain value describing the scan. It MUST NOT model or duplicate the host's attachment type; the host maps it into its own attachment.
- **FR-033**: The package MUST NOT upload, authenticate, hold session state, know any Qanoniah endpoint, read host configuration, or use the host's service locator.
- **FR-034**: Gating (signed out, not entitled to file upload, out of credit) MUST stay in the host, before it starts the package. The package MUST NOT check entitlement.
- **FR-035**: Ownership of the returned PDF MUST pass to the host, which deletes it when done.
- **FR-036**: The package MUST ship default strings in Arabic and English and use the host's locale and text direction.
- **FR-037**: The public surface MUST be limited to: entry point, start configuration, result, theme extension, strings, events, read-only viewer.

**Privacy**

- **FR-040**: No page image or text MUST leave the device before the user taps attach. The package itself MUST make no network request at any time.
- **FR-041**: Redacted text MUST NOT appear in the PDF text layer, the page image, the returned text, any emitted event, any log or crash report, or any file left on disk after the flow ends.
- **FR-042**: Edited-away original text MUST NOT appear in the returned text or the PDF text layer.
- **FR-043**: The package MUST NOT log document text, recognized words, or image content at any log level.
- **FR-044**: All session files MUST live in app-private temp storage and MUST be deleted on cancel, on result (except the returned PDF), and at the next start for any session the OS ended early. At each start the package MUST also delete returned PDFs older than 24 hours that the host did not delete.
- **FR-045**: User images, recognized text, and user corrections MUST NEVER be stored, collected, or sent for model training or evaluation.

**Text recognition service**

- **FR-050**: Text recognition MUST run fully on the device, free of charge, with no backend.
- **FR-051**: Recognition MUST be structured as three layers: (1) image preparation owned by the package (perspective correction, deskew, shadow removal, binarization); (2) a recognition engine behind one replaceable interface; (3) post-processing owned by the package (RTL word order, paragraph grouping, digit and `%` normalization, word boxes for redaction).
- **FR-052**: Each device MUST use the best on-device engine available to it for Arabic, chosen by the device's actual capability.
- **FR-053**: Replacing the engine's model file MUST require no code change: the model ships as an asset, and swapping the asset plus passing the evaluation gate is the whole change.
- **FR-054**: A fixed evaluation set (real legal pages with ground-truth text in Arabic and English, held in the repo, containing no user data) MUST measure character error rate, word error rate, and digit error rate (digits and `%`) per engine and per model version.
- **FR-055**: Any engine or model change MUST meet the targets in SC-010 and MUST NOT regress any metric versus the current shipped version on that set; otherwise it does not ship.
- **FR-056**: The fine-tuned model (v1.1) is a later phase and NOT part of this feature.

**Analytics events**

- **FR-057**: The package MUST emit the events below through the host's callback. Events MUST carry only the step name and non-document metadata (counts, durations, mode, error kind). They MUST NOT carry document text, words, images, file names, or redaction content.

  | Step | Events |
  |------|--------|
  | Entry | `scan_started` |
  | Permission | `scan_permission_denied`, `scan_permission_permanently_denied` |
  | Capture | `scan_page_captured` (mode: auto/manual), `scan_page_limit_reached` (only when the host set a maximum) |
  | Review | `scan_review_opened`, `scan_page_moved`, `scan_page_move_undone`, `scan_page_added`, `scan_page_retaken` |
  | Build | `scan_build_started`, `scan_build_completed` (duration, page count), `scan_build_failed` (error kind), `scan_page_no_text` |
  | Review extras | `scan_page_deleted`, `scan_corners_adjusted`, `scan_filter_applied` (filter names, all pages or one) |
  | Preview / edit | `scan_preview_opened`, `scan_edit_mode_entered`, `scan_paragraph_edited`, `scan_text_redacted`, `scan_paragraph_redacted`, `scan_redaction_removed`, `scan_photo_view_opened`, `scan_color_mode_changed`, `scan_document_renamed` |
  | Attach | `scan_attached` (page count, PDF form, redaction count, edited-paragraph count, size bucket, compressed yes/no, time since `scan_started`), `scan_size_limit_exceeded` |
  | Exit | `scan_cancelled` (step) |
  | Viewer | `scan_viewer_opened` |

  `scan_document_renamed` MUST NOT carry the new name.

**Scope decisions**

- **FR-060**: Design-only extras: User Stories 11 to 15 (delete page, corner adjust, filters, photo view and scan color, rename) are in scope. User Story 16 (search) is deferred and MUST NOT be built.
- **FR-061**: Before attach the package MUST check the PDF against the host's 5 MB per-file limit (the host passes the limit). In image form, if over the limit, page images MUST be compressed step by step until the file fits, keeping text legible. If either form still exceeds the limit, attach MUST be blocked with a message showing the size and the limit, and the user removes pages. The package MUST NOT split one scan into several files.
- **FR-062**: The package MUST detect the script of each page (Arabic or English) and recognize the page with the matching language only. It MUST NOT run Arabic and English recognition together in one pass. Both languages MUST meet SC-010 on the evaluation set.

**Accessibility**

- **FR-064**: Every control MUST have a spoken label for screen readers (VoiceOver, TalkBack), in the active language.
- **FR-065**: With a screen reader on, the camera MUST announce when a page is detected, when it is steady, and when it is captured, including the new page count.
- **FR-066**: Reordering MUST have a non-drag alternative: each page offers move earlier and move later actions, reachable by screen reader and by tap.
- **FR-067**: Every screen MUST stay usable, with no clipped or overlapping text, at system text size up to 200%.

**Design rules**

- **FR-070**: All colors, type sizes, spacing, and radii MUST come from the host-supplied theme filled from Qanoniah design kit tokens. Widgets MUST contain no literal values; the only literals live in the example app's fallback theme.
- **FR-071**: The package MUST NOT bundle fonts; text uses the host's Noto Sans Arabic. The host supplies the font bytes used inside the PDF.
- **FR-072**: Icons MUST come from iconsax, then untitled-ui only where iconsax has no match, then qn for bespoke actions. The host supplies them as SVG asset paths through the theme; the package bundles no icon files and copies nothing from the design kit. No Material, Lucide, Heroicons, Font Awesome, or emoji.
- **FR-073**: The UI MUST be RTL and Arabic first; chevrons and back arrows mirror, logos and status icons do not.
- **FR-074**: All Arabic copy MUST be فصحى مبسطة, MUST use Latin numerals, MUST contain no em-dash, and MUST never use «استشارة» or its derivatives.
- **FR-075**: Any design value without a token (see Open design questions) MUST NOT be built until Ahmed answers.

### Constraints from the constitution

- Package rule P1 (host-agnostic) is FR-033/FR-034; P2 (narrow API) is FR-037; P3 (tokens) is FR-070 to FR-075; P4 (redaction privacy) is FR-040 to FR-045; P7 (on-device OCR, measured) is FR-050 to FR-056.
- P5: interfaces exist only at the real platform seams that tests must fake (camera, edge detection, text recognition). Everything else is concrete. No engine registry, plugin system, or second recognition interface.
- VI Anti-Koshary: capture, review, build, and preview logic stays out of widgets; the result does not duplicate the host's attachment model; deferred extras leave no dead or flagged code behind.
- P6: the `example/` app runs the whole flow with the fallback theme; every state holder and the PDF/redaction builder have unit tests.

### Key Entities

- **Scan session**: one run from start to attach or cancel. Holds pages, their order, the last move (for undo), mode, and its temp folder.
- **Captured page**: one perspective-corrected image plus its recognition state (pending, done, no text).
- **Recognized text**: per page, paragraphs in reading order; each paragraph has words with positions on the image, used for selection and redaction.
- **Edit**: replacement text for one paragraph.
- **Redaction**: a set of redacted words or one whole paragraph on a page; drives both text removal and image covering.
- **Scan result**: what the host receives on attach: PDF file, file name, form (text or image), page count, size, per-page final text. A plain value; not the host's attachment.
- **Scan event**: a step name plus non-document metadata, delivered to the host's callback.
- **Evaluation set**: fixed legal pages with ground-truth text, used to score each engine and model version.

## Success Criteria *(mandatory)*

### Measurable Outcomes

Analytics outcomes, measured by the host from FR-057 events. Targets are set by the product owner after the first 30 days of data; until then they are tracked as baselines.

- **SC-001**: Completion rate: share of `scan_started` that end in `scan_attached`, with drop-off measurable at every step. Target set after 30 days (initial reference: 60%).
- **SC-002**: Median time from camera open to `scan_attached` for a 3-page document. Target set after 30 days (initial reference: under 60 seconds).
- **SC-003**: Share of all chat attachments that come from scan. Target set after 30 days (initial reference: 15%).
- **SC-004**: Share of attached scans using edit and share using redaction are both reported from events from day one (baseline metric; no target in v1).

Release gates, fixed now and verified before every release:

- **SC-005**: On a mid-range Android phone, recognition of one page takes no more than 3 seconds, so a 5-page document reaches preview within 10 seconds of tapping build.
- **SC-006**: In an automated test corpus, 0 redacted words appear in the returned text, PDF text layer, any event, or any log, and every PDF with a redaction is in text form with no page photo.
- **SC-007**: After cancel at every step, 0 session files remain on disk; after attach, only the returned PDF remains.
- **SC-008**: During a full scan, the package makes 0 network requests.
- **SC-009**: 100% of results have pages in the review order and text equal to the final edited, redaction-free text.
- **SC-010**: On the evaluation set, every shipping engine meets: character error rate at most 3%, word error rate at most 8%, digit error rate at most 1%.
- **SC-011**: A model update ships as an asset swap plus a passing evaluation run, with no code change.
- **SC-012**: A screen-reader user can complete capture, reorder, and attach for a 3-page document without sighted help, verified on VoiceOver and TalkBack.

## Assumptions

- Host-side scope: the attach menu change (three cards, Camera removed), gating, upload, composer chip, and recording events are host work in qanoniah-mobile; this spec states them so the contract is clear.
- Scan appears only in the Qanoniah AI chat composer in this feature. Showing it in the document-assistant composer is a host decision that needs no package change, so it is not marked for clarification here.
- The host sets any page limit through its start configuration, so changing it needs no package release. Performance is verified at 50 pages.
- SC-005 and SC-010 are fixed release gates. SC-001 to SC-003 carry reference numbers only; the product owner fixes their targets after 30 days of data.
- Engine choice from the brief's OCR decision: Apple Vision on iOS where it supports Arabic, Tesseract Arabic on Android and older iOS. PaddleOCR and ML Kit are rejected.
- The preview opens on the text view, as in the design (text mode is the editable default; image mode disables editing). The output form is separate from the view and is chosen by FR-011.
- Image form only ships unedited, unredacted documents, so its photos and text layer both match the captured page.
- English recognition needs an English model asset alongside Arabic, chosen per page by FR-062.
- The package returns per-page text alongside the PDF for the host to use; how the host passes it to Qanoniah AI is host work.
- The package is a native plugin, so adopting it needs a full host release, not an OTA patch.
- Platforms: Android and iOS phones and iPad. Web is out of scope.

## Out of Scope

- Web platform.
- The existing «الصور» and «الملفات» attach options.
- Uploading, retries, and server-side processing.
- The fine-tuned recognition model (v1.1) and any training pipeline.
- Document search (User Story 16), deferred under FR-060.
- Splitting one scan into several PDFs.

## Open design questions for Ahmed

Values the design uses with no token in `tokens/tokens.json`. Nothing using them is built until
answered (FR-075).

1. Dark camera surface: the kit has no dark palette. Which tokens for the camera sheet background, text, and controls?
2. Colors `#5b8cff`, `#0b0f19`, `#1e4192`, `#f7f8fc` have no token. Map to existing tokens, or add?
3. `#dc2626` matches `red.600`. Confirm that is the intended token (the brief listed it as untokened).
4. Font sizes 9, 11, 12, 13, 14, 15: the kit's size scale starts at 16 (`textMd`). Which tokens apply?
5. Radii 2, 4, 6, 8, 10, 14, 16, 18: the kit has only 12 (`xl`) and 20 (`3xl`). Which tokens apply?
6. Attach-menu card height 76px and any spacing not on the kit scale (2, 4, 8, 12, 16, 20, 32, 48, 64, 80, 128): confirm or map.
7. Copy and visuals with no design source: camera permission denied and permanently denied, page limit reached, size limit (per FR-061), low light or blur hint, page with no readable text, build failure, storage full. Proposed copy, for UX approval: «نحتاج إلى إذن الكاميرا لمسح المستند», «افتح الإعدادات», «وصلت إلى الحد الأقصى: N صفحة», «الإضاءة ضعيفة، قرّب المستند من مصدر ضوء», «لم يُعثر على نص في هذه الصفحة», «تعذّر إنشاء الملف، حاول مرة أخرى». Also the non-drag reorder actions (proposed «نقل للأمام» / «نقل للخلف») and the spoken camera announcements.
8. Icons: confirm iconsax matches for auto/manual capture, eye (redact), drag handle, corner handles, filters, text/photo view toggle, and the PDF file chip; name any that need untitled-ui or qn.
9. Document search (deferred): the design has the bar but no control that opens it. Where should it open from, if it is scheduled later?
10. Text-form page layout: font size, margins, and how headings and paragraphs render on a text-form PDF page.
