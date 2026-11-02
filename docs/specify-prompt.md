Feature: Document Scan (مسح مستند) for Qanoniah AI chat, delivered as this standalone Flutter
package `qanoniah_doc_scan` that the qanoniah-mobile app adds via pubspec (git tag).

Read docs/feature-brief.md fully. It is the source: journey, states, Arabic copy, acceptance
criteria, metrics, host constraints, risks. The visual source of truth is the Claude Design
artifact named in CLAUDE.md; where it is richer than ClickUp, list each extra (filters, corner
adjust, delete page, rename, search, color mode) as a user story with its own priority and mark
the scope decision [NEEDS CLARIFICATION] instead of silently including or dropping it.

Write the spec for WHAT and WHY:
- User stories per journey step (entry, capture auto/manual, review/reorder/undo/add/retake,
  build progress, preview, edit, redact by selection and by paragraph, attach, read-only view),
  each independently testable, P1 = capture → review → one PDF → attach.
- The package/host contract as a requirement: the package takes a host-supplied theme, strings
  override, and event callback; it returns one PDF + per-page final text (edited, redaction-free)
  or nothing on cancel; it never uploads, authenticates, or knows Qanoniah endpoints. Gating
  (unauthenticated / not entitled / out of credit) stays in the host.
- Privacy requirements: redacted text never leaves the device, not in the PDF text layer, not
  in the image, not in events or logs; cancel deletes all temp files.
- Edge cases: camera permission denied/permanently denied, 0 pages, very many pages, result over
  the host's 5 MB upload limit, low light/blurry page, no edges found, OCR finds no text,
  app backgrounded mid-flow, RTL and mixed Arabic/Latin text, iPad layout.
- Measurable success criteria from the brief (drop-off per step, time to attach, redaction/edit use).
- Analytics events the package emits per step (names only, no payload content from the document).
- Design rules: Qanoniah design kit tokens only, Noto Sans Arabic from the host, iconsax icons,
  Arabic-first فصحى مبسطة copy (no em-dashes, Latin numerals, never «استشارة»), and an explicit
  list of design values that have no token, as questions for Ahmed.
- Out of scope: web platform; the existing Photos and Files options; uploading.

Text recognition is decided: fully on-device, free, no backend (see "OCR decision" in the
brief). State it as a requirement: no page image or text leaves the device before the user taps
attach. Specify the OCR service as three layers (image preparation and post-processing owned by
the package; recognition engine replaceable behind one port) and add requirements for: a fixed
OCR evaluation set with measurable character/word/digit error targets that any engine or model
update must meet, a model swap that needs no code change, and a ban on using user data for
training. The v1.1 fine-tuned Tesseract model is a later phase, not in this spec's MVP.
Mark as [NEEDS CLARIFICATION] at most these: scope of the design-only extras, whether
scan also appears in the document-assistant composer, the 5 MB limit strategy, and how English
or mixed-language documents are recognized.

Honor the constitution, especially VI Anti-Koshary and the Package Addendum P1–P6: no layer
collapse, no duplicated domain model of the host's attachment, no speculative abstractions,
no dead code.
