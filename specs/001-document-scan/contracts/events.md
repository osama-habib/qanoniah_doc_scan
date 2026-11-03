# Contract: Analytics Events

The package delivers events through `DocScanConfig.onEvent`, and the host records them (FR-057).
Param values are only ints, bools, doubles, or the enum strings listed. No text, words, images,
file names, or redaction content appear in any event, ever (FR-041).

| Event | Params |
|-------|--------|
| `scan_started` | none |
| `scan_permission_denied` | none |
| `scan_permission_permanently_denied` | none |
| `scan_page_captured` | `mode`: `auto`/`manual`, `page_count`: int |
| `scan_page_limit_reached` | `max_pages`: int (only when the host set a maximum) |
| `scan_review_opened` | `page_count` |
| `scan_page_moved` | `via`: `drag`/`action` |
| `scan_page_move_undone` | none |
| `scan_page_added` | `page_count` |
| `scan_page_retaken` | none |
| `scan_page_deleted` | `page_count` |
| `scan_corners_adjusted` | none |
| `scan_filter_applied` | `filters`: comma list of `original,auto,text,shadow,contrast,gray,bw`; `all_pages`: bool |
| `scan_build_started` | `page_count` |
| `scan_build_completed` | `page_count`, `duration_ms`, `languages`: `ar`/`en`/`mixed` |
| `scan_build_failed` | `error`: `storage_full`/`unknown` |
| `scan_page_no_text` | none |
| `scan_preview_opened` | none |
| `scan_photo_view_opened` | none |
| `scan_color_mode_changed` | `mode`: `color`/`gray`/`bw` |
| `scan_edit_mode_entered` | none |
| `scan_paragraph_edited` | none |
| `scan_text_redacted` | `word_count`: int |
| `scan_paragraph_redacted` | none |
| `scan_redaction_removed` | none |
| `scan_document_renamed` | none (the name is never sent) |
| `scan_size_limit_exceeded` | `size_bucket`: `5-10`/`10-20`/`20+` (MB) |
| `scan_attached` | `page_count`, `form`: `text`/`image`, `redaction_count`, `edited_paragraph_count`, `size_bucket`: `<1`/`1-2`/`2-5` (MB), `compressed`: bool, `duration_ms` (since `scan_started`) |
| `scan_cancelled` | `step`: `permission`/`capture`/`review`/`build`/`preview` |
| `scan_viewer_opened` | none |

Funnel for SC-001: `scan_started` → `scan_page_captured` → `scan_review_opened` →
`scan_build_completed` → `scan_preview_opened` → `scan_attached`.
