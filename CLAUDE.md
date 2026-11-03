# CLAUDE.md: qanoniah_doc_scan

Standalone Flutter plugin: the «مسح مستند» journey for Qanoniah AI chat (capture with edge
detection → review/reorder → build → preview, edit, redact → one PDF). Consumed by
`qanoniah-mobile` (host repo: `/Users/osamahabib/StudioProjects/qanoniah-mobile`) via a pinned git tag.

Read first: `.specify/memory/constitution.md` (incl. the Package Addendum) and
`docs/feature-brief.md`.

## Design
- Design kit (read-only, never copy files out of it, never share outside the company):
  `/Users/osamahabib/Downloads/qanoniah_design_system/qanoniah-design-kit`. Read its CLAUDE.md before any UI work. Tokens: `tokens/tokens.json`.
- Font in this app family = Noto Sans Arabic (host spec 038), supplied by the host theme.
- Source of truth for this feature's look: Claude Design artifact
  https://claude.ai/artifact/Vz5kynfXF3ttVKssM5Sg8S, files
  `project/Full App - Document Scan.dc.html` and `project/Export - Document Scan Experience.dc.html`.
- Missing token/icon/color → stop and ask Ahmed.
- Arabic copy: فصحى مبسطة, no em-dashes, Latin numerals, never «استشارة» or derivatives.

## Code quality
- Anti-Koshary is binding: run the `anti-koshary` skill Pass 1 before non-trivial refactors;
  Pass 2 only after the owner approves. Honor it in every /speckit-* step.
- State: flutter_bloc Cubits. Errors: `Either<Failure, T>` from repos, cubits fold.
- Never `build_runner --delete-conflicting-outputs`; use relative `part` directives.

## Commands
```bash
flutter analyze
flutter test
cd example && flutter run
```

<!-- SPECKIT START -->
Active feature plan: `specs/001-document-scan/plan.md` (research, data model, contracts, quickstart alongside).
<!-- SPECKIT END -->
