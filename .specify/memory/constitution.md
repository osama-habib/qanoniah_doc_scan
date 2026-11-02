<!--
SYNC IMPACT REPORT
==================
Version change: 1.4.0 → 1.5.0
Modified principles: none
Modified sections:
  - Development Workflow: "Feature branches MUST branch from main" gains a dependent-branch
    exception. A feature that depends on an unmerged feature branch (edits the same files, or
    its spec relies on that feature's behavior) MAY branch from that parent branch, provided it
    names the parent in plan.md, does not open its PR until the parent has merged to main, and
    is rebased onto main before the PR is opened. PRs still target main. MINOR bump: materially
    expanded guidance, nothing removed. Owner decision 2026-10-11 (spec 029 branched from
    unmerged 028).
Added sections: none
Removed sections: none
Templates requiring updates:
  - .specify/templates/plan-template.md ✅ reviewed (Constitution Check reads this file; no change)
  - .specify/templates/spec-template.md ✅ reviewed (no change)
  - .specify/templates/tasks-template.md ✅ reviewed (no change)
  - .specify/templates/commands/*.md ✅ none present
  - CLAUDE.md ✅ reviewed (no branch-base rule stated; no change)
  - specs/029-inline-source-references/plan.md ✅ branch-base row changed from justified
    violation to PASS, parent branch named
Deferred TODOs:
  - TODO(RATIFICATION_DATE): Confirm original project adoption date
-->

# Qanoniah Mobile Constitution

## Core Principles

### I. Clean Architecture (NON-NEGOTIABLE)

Every feature MUST follow the layered structure: `data/` (models, remote, local, repo),
a feature-root `manager/` (cubits/blocs), and `presentation/` (screens, widgets). An optional
feature-root `common/` MAY hold cross-cutting widgets/helpers used across the feature. The
reference modules `ai_module` and `setting_module` are the canonical examples. Cross-layer
imports are forbidden in the downward direction — presentation MUST NOT import from other
features' data layers directly. Shared contracts go through `lib/core/` or `lib/shared/`.

### II. Flavor Isolation

All environment-specific values MUST be read exclusively from `lib/core/config/app_config.dart`
via `String.fromEnvironment()`. Direct `const String.fromEnvironment()` calls outside
`AppConfig` are forbidden. Every build MUST target a named flavor (`dev` or `prod`) — no
default fallback. `AppConfig.isProd` gates prod-only behavior.

### III. Code Generation Discipline

Models using `@freezed`, `@JsonSerializable`, or `hive_generator` annotations MUST have their
generated files committed and kept in sync. After any annotated file changes, run:
`flutter pub run build_runner build`. PRs with stale generated files MUST NOT be merged.

Exception — this repo MUST NOT run `build_runner` with `--delete-conflicting-outputs`
repo-wide: ~83 model files declare their generated parts with an ABSOLUTE package URI
(`part 'package:qanoniah/…/foo.freezed.dart';`), which the current freezed skips (warning
only); the flag then deletes their committed output and produces ~1700 analyzer errors.
Convert a file to a RELATIVE `part` directive before regenerating it. Recover a bad run with:
`git ls-files -d | xargs git checkout --`.

### IV. State Management Consistency

State management MUST use flutter_bloc (BLoC or Cubit). All cubits/blocs MUST be registered
via get_it, either in `lib/core/utils/service_locator.dart` or in a module `*LocatorModule` it
delegates to, and app-wide or cross-screen state MUST be provided at root in `lib/main.dart`.

Exception (screen-scoped cubits): a cubit whose state belongs to a single screen and MUST NOT
outlive it (for example `ClarifyingQuestionsCubit`, spec 024; `EditLastQuestionCubit`, spec 028)
MAY be registered as a factory in its module's `*LocatorModule` and provided at that screen
instead of at root. Such a cubit MUST NOT be read from outside the screen's subtree; once a
second screen needs it, it MUST move to root. Rationale: root provision would keep per-screen
state alive across navigation and force manual resets on every exit path.
Local widget state (ephemeral UI-only) may use `StatefulWidget`. Redux, Provider, Riverpod,
and other state solutions are forbidden unless explicitly exempted via amendment.

### V. OTA Patch vs Release Discipline

Shorebird OTA patches (`shorebird patch`) are for hotfixes to existing releases only.
New features, breaking API changes, or dependency upgrades MUST go through a full release
(`shorebird release`). Patches that include non-hotfix changes are a governance violation.

### VI. Anti-Koshary Discipline (NON-NEGOTIABLE)

Koshary code — rice, pasta, and lentils stirred into one bowl that can never be separated —
is the failure mode this principle bans. New code MUST NOT deepen the drift already present in
this repo. Specifically, planned or generated changes MUST NOT:

- put business logic in the wrong layer (controllers, widgets, cubits doing repo/domain work
  that Principle I assigns to `data/`);
- duplicate validation, formatting, or domain logic that already exists elsewhere — reuse or
  extract instead of copy-pasting;
- add a second copy of a domain model already modeled elsewhere (e.g. `User` is owned by
  `auth/data/models/user/user_model.dart` — do not add a third);
- introduce an abstraction that has one implementation and no test or cross-boundary reason;
- leave dead code, unread god functions, or files grown past the point anyone opens them.

Enforcement: the `anti-koshary` skill (`~/.claude/skills/anti-koshary/`) is the standing audit
tool. Any non-trivial refactor of a known god file (`login_bloc.dart`, `ai_chat_cubit.dart`,
`authentication_repo.dart`, `file_cubit.dart`, `custom_html_extention.dart`, `main.dart`) MUST
run its **Pass 1 report before any edit**, and its **Pass 2 fixes only after the user approves**.
A plan or task set that would collapse a layer, duplicate logic, or add a speculative
abstraction is a Constitution Check violation and MUST be justified or redesigned.

## Architecture Standards

Flutter clean architecture project (`qanoniah-mobile`) targeting Android and iOS (dev + prod
flavors). Key technology contracts:

- **Navigation**: go_router — all routes in `lib/core/routes/routes.dart`
- **Networking**: Dio via `lib/core/api/api_client.dart`; endpoints in `lib/core/api/endpoints.dart`
- **Localization**: easy_localization; translation files in `resources/langs/`
- **Analytics/Monitoring**: Sentry, Smartlook, HubSpot — same keys across flavors
- **Local storage**: Hive; model annotations via hive_generator

Any addition of a new state management library, navigation solution, or HTTP client requires
an amendment with rationale.

## Development Workflow

- Pre-commit hooks run `flutter analyze` via lefthook — commits with analysis errors are blocked
- Feature branches MUST branch from `main`; PRs target `main`. Exception (dependent branches):
  a feature that depends on an unmerged feature branch (it edits the same files, or its spec
  relies on that feature's behavior) MAY branch from that parent branch. Such a branch MUST name
  its parent branch in its `plan.md`, MUST NOT open its PR until the parent has merged to `main`,
  and MUST be rebased onto `main` before the PR is opened. Rationale: avoids building against
  stale `main` and resolving the same conflicts twice, while `main` stays the only merge target.
- `flutter analyze` MUST pass before PR review
- `flutter test` MUST pass before merge
- Code generation MUST be re-run and committed if any annotated file changed
- Shorebird patch commands are only valid on commits already cut as a release

## Governance

This constitution supersedes all other practices documented in `README.md` or ad-hoc team
agreements. Amendments MUST:

1. Update this file with version bump per semantic versioning:
   - MAJOR: principle removal, redefinition, or backward-incompatible governance change
   - MINOR: new principle or materially expanded guidance
   - PATCH: clarification, wording, or typo fix
2. Propagate changes to affected `.specify/templates/` files
3. Be committed with message: `docs: amend constitution to vX.Y.Z (<reason>)`

All specification, planning, and task generation done via Spec Kit MUST comply with these
principles. `CLAUDE.md` serves as runtime development guidance and MUST stay aligned with
this constitution.

**Version**: 1.5.0 | **Ratified**: TODO(RATIFICATION_DATE): confirm original adoption date | **Last Amended**: 2026-10-11
## Package Addendum: qanoniah_doc_scan

This repo is a standalone Flutter plugin consumed by `qanoniah-mobile` via a pinned git tag
in `pubspec.yaml`. Principles I–VI above apply, read with these package rules:

### P1. Host-agnostic (NON-NEGOTIABLE)
The package MUST NOT import anything from `package:qanoniah/...`, call any Qanoniah endpoint,
hold auth/session state, read `AppConfig`/dart-defines, or use the host's get_it. It returns a
result object; the host uploads it. Gating (unauthenticated / not entitled / out of credit) is
the host's job before it calls `DocScan.start`.

### P2. Narrow public API
`lib/qanoniah_doc_scan.dart` exports only the public surface (entry point, config, result,
theme extension, strings, events, read-only viewer). Everything else lives under `lib/src/`.
A breaking change to the public API requires a major version bump and a CHANGELOG entry.

### P3. Design from tokens, injected by the host
Colors, typography, spacing and radii come from a `ThemeExtension` the host fills from the
Qanoniah design kit tokens. No hex/size literals in widgets; the only literal values live in the
example-app fallback theme. No bundled fonts (the host owns Noto Sans Arabic). Icons: iconsax →
untitled-ui → qn, SVG via flutter_svg, never Material/Lucide/emoji. RTL + Arabic first. Any value
the design uses that has no token is listed as an open question for Ahmed, never improvised.

### P4. Privacy of redaction
Redacted content MUST be removed from the text layer and burned into the page image before the
result leaves the package. No redacted text in logs, analytics payloads, temp files that survive
the flow, or the returned object. Cancel at any step deletes every temp file.

### P5. Ports only at real seams
Allowed interfaces: platform/ML seams that need fakes in tests (edge detection, text
recognition, camera). Everything else is concrete.

### P6. Independently runnable and tested
`example/` runs the whole flow with the fallback theme. Every cubit and the PDF/redaction
builder have unit tests; `flutter analyze` is clean before every commit.

### P7. On-device OCR, measured
Text recognition runs only on the device, free, with no backend call. Image preparation and
post-processing are package code; the recognition engine (Vision / Tesseract) sits behind one
port and its model file is an asset, so a model update needs no code change. A fixed evaluation
set gates every engine or model change. User images and text are never used for training.
