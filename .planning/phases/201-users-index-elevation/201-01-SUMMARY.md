---
phase: 201
plan: "01"
subsystem: admin-ui
status: complete
tags:
  - users-index
  - admin-ui
  - drY
  - filter-panel
  - metric-strip
  - status-pills
dependency_graph:
  requires: []
  provides:
    - user_name_stack/1 (shared field-slice component)
    - user_status_cluster/1 (shared field-slice component)
    - reduced status_pills/1 (Unconfirmed/No MFA/Locked/Deletion scheduled)
    - no_security?/1 predicate
    - recomposed render/1 (search-first, 3-chip metric strip, consolidated filter panel)
  affects:
    - lib/sigra/admin/live/users_index_live.ex
tech_stack:
  added: []
  patterns:
    - shared field-slice function components (DRY desktop+mobile per-row presentation)
    - GET-form-safe applied chip relocation (navigation-only <a> tags inside form)
    - reduced pill vocabulary (decision-bearing signals only)
key_files:
  created: []
  modified:
    - lib/sigra/admin/live/users_index_live.ex
decisions:
  - D-01: Applied chips relocated inside <form> below search row — chips remain navigation-only <a> tags (no named inputs) so GET form contract is preserved
  - D-02: GET form contract kept intact — method=get, quick-filter checkboxes, only toggle_filters is a LiveView event
  - D-03: Metric strip demoted below Find users filter section; slimmed to 3 chips (Total + Locked + Deletion scheduled)
  - D-04: status_pills/1 reduced to Unconfirmed/No MFA (warn)/Locked/Deletion scheduled; Confirmed dropped, 4-way security cond collapsed
  - D-05: DRY via two shared field-slice components (user_name_stack/1 and user_status_cluster/1) authored once, called from both desktop <td> and mobile <article>
  - D-11: sg-chevron dropped from markup (had zero CSS rules; fewest moving parts)
metrics:
  duration: 274s
  completed: "2026-06-26T09:20:35Z"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 1
---

# Phase 201 Plan 01: Users Index Recompose Summary

**One-liner:** Recomposed users_index_live.ex search-first with consolidated filter panel, demoted 3-chip metric strip, DRY shared field-slice components, and reduced decision-bearing pill vocabulary.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Reduce status_pills/1 to decision-bearing signals | 0323fc2c | users_index_live.ex |
| 2 | DRY per-row presentation via shared field-slice components | 467c2cdd | users_index_live.ex |
| 3 | Consolidate filter panel, demote metric strip, resolve sg-chevron | 216b64c0 | users_index_live.ex |

## What Was Built

### Task 1: Reduced status_pills/1

Rewrote the `status_pills/1` body to return only decision-bearing signals:
- **Dropped:** always-present `{"Confirmed", "ok"}` branch (absence of Unconfirmed implies confirmed)
- **Collapsed:** 4-way security cond (`MFA + passkeys` / `MFA` / `Passkeys` / `No MFA`) into `{"No MFA", "warn"}` when unsecured and nothing when secured
- **Added:** private `no_security?/1` predicate — `not row.has_mfa and row.passkey_count == 0`
- **Kept:** Unconfirmed (warn), Locked (risk), Deletion scheduled (warn)
- Fully-secured rows show zero security pills

### Task 2: DRY Shared Field-Slice Components

Introduced two private function components that are each authored once and called from both the desktop `<td>` and the mobile `<article>`:

1. **`user_name_stack/1`** — name/email/id identity stack (the byte-identical block that was duplicated at desktop `:262-268` ≡ mobile `:306-310`)
2. **`user_status_cluster/1`** — status pills + extra_badges cluster (the byte-identical block at desktop `:269-276` ≡ mobile `:312-317`)

The `extra_badges` host seam (D-07) is rendered inside `user_status_cluster/1`, which is called from both layouts — seam preserved in both. The `extra_columns` host seam is rendered in the layout-specific shells (desktop activity `<td>` and mobile `<dl>`) — both preserved.

Desktop frozen 5-column order preserved: User / Status / Organizations / Activity / Action. The `<td>` boundaries stay authored in the table (D-06), only inner content is shared.

### Task 3: Consolidated Filter Panel, Demoted Metric Strip, sg-chevron Resolved

**Applied chips consolidated (D-01):** Moved the detached applied-chip block (was a sibling `<div>` after `</form>`) up to sit directly below the search row, INSIDE the `<form>`. Chips remain navigation-only `<a>` tags — no named inputs — so GET form submission is unaffected (D-02).

**Metric strip demoted (D-03):** Reordered DOM:
1. page-header → scope_ribbon  
2. Find users filter section (search-first, dominant affordance) — `:85`
3. User health metric strip (demoted, secondary) — `:182`
4. Desktop table → mobile cards → empty state → pagination

Slimmed from 6 chips to 3: Total + Locked + Deletion scheduled (risk/warn-toned decision chips only; Confirmed/MFA/Passkeys coverage KPIs dropped from the list view).

**sg-chevron resolved (D-11):** Dropped the `<span class="sg-chevron">▾</span>` from the "More filters" button. The class had zero CSS rules in all three CSS copies — removing the span is fewest moving parts.

**CSS parity maintained:** The three `sigra_admin.css` copies remain byte-identical (`md5 | sort -u | wc -l` = 1).

## Verification Results

| Check | Result |
|-------|--------|
| `mix compile --warnings-as-errors` | PASS — clean |
| `"Confirmed"` count = 0 | PASS |
| `"No MFA"` present with warn tone | PASS |
| Locked/Unconfirmed/Deletion scheduled present | PASS |
| `"MFA + passkeys"` count = 0 | PASS |
| Desktop thead = 5 columns User/Status/Organizations/Activity/Action | PASS |
| Desktop `<tr>` emits exactly 5 `<td>` | PASS |
| extra_badges in both desktop and mobile | PASS (3 occurrences via shared component) |
| extra_columns in both desktop and mobile | PASS (2 explicit render sites) |
| `method="get"` GET form intact | PASS |
| Only `toggle_filters` is a LiveView event | PASS (1 phx-click) |
| summary_chip count = 3 (Total/Locked/Deletion) | PASS |
| sg-chevron count = 0 in LiveView | PASS |
| CSS triple-copy parity = 1 unique md5 | PASS |
| Find users renders BEFORE User health | PASS (line 85 vs 182) |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. All data is wired: shared components call existing helpers, metric strip reads from `summary_stats/3`, host seams read from `decorate_rows/2`.

## Self-Check

### Files Exist
- lib/sigra/admin/live/users_index_live.ex: EXISTS ✓

### Commits Exist
- 0323fc2c: feat(201-01): reduce status_pills/1 to decision-bearing signals ✓
- 467c2cdd: feat(201-01): DRY per-row presentation via shared field-slice components ✓
- 216b64c0: feat(201-01): consolidate filter panel, demote metric strip, resolve sg-chevron ✓

## Self-Check: PASSED
