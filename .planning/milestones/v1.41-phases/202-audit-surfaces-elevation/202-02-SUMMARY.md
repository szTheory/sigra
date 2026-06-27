---
phase: 202-audit-surfaces-elevation
plan: "02"
subsystem: admin-ui
tags: [audit, dry, form-collapse, shared-components, wave-2]
status: complete

dependency_graph:
  requires:
    - 202-01 (audit_table_row/1, audit_pagination_nav/1, audit_empty_state/1)
  provides:
    - audit_user_live.ex with single sg-filter-panel form + <details> disclosure
    - byte-coherent shared-component desktop table / pagination / empty-state
  affects:
    - lib/sigra/admin/live/audit_user_live.ex

tech_stack:
  added: []
  patterns:
    - Native CSS-only <details> advanced-disclosure (no JS, no phx-hook)
    - GET-checkbox folded-in toggle pattern (quick toggles inside single form)
    - pre-built prev_href/next_href pass-in to audit_pagination_nav/1 (D-09)
    - Shared component consumption: audit_table_row/1, audit_pagination_nav/1, audit_empty_state/1

key_files:
  created: []
  modified:
    - lib/sigra/admin/live/audit_user_live.ex

decisions:
  - Converged from/to inputs from type=text to type=date (Open Question 1 — coherence with index page; no existing test broke)
  - Kept <thead> per-page (Wave-1 canonical decision: shared component is the <tr> body only)
  - Mobile card list kept as-is using <.audit_row show_detail show_codes> (D-07)
  - return_to hidden input survives exactly once at line 157 (the :160 conditional one from the original main form)
  - Pre-built prev_href/next_href passed to audit_pagination_nav/1 using per-user page_path/4 (user_id + return_to) — D-09 routing divergence stays in LiveView
  - Deleted private audit_tone/1, multi_page?/1, format_timestamp/1 — all now owned by components.ex

metrics:
  duration: "156s (~2.6m)"
  completed: 2026-06-26
  tasks_completed: 2
  files_modified: 1
---

# Phase 202 Plan 02: Per-User Audit Form Collapse + Shared Components (Wave 2) Summary

**One-liner:** Collapsed audit_user_live.ex from three GET forms into one unified sg-filter-panel with folded-in checkbox toggles, native `<details>` advanced-disclosure, and Wave-1 shared component calls replacing all hand-written desktop table/pagination/empty-state markup.

## What Was Built

### Task 1: Collapse 3 forms into 1 with folded-in toggles + `<details>` disclosure

The per-user audit page previously had THREE `<form>` elements:
- Form 1 (lines 82-94): standalone "Failures" toggle form with its own `return_to` hidden input
- Form 2 (lines 95-107): standalone "Impersonation" toggle form with its own `return_to` hidden input
- Form 3 (lines 110-164): the main filter form

These were collapsed into a **single** `<form method="get" action={...} class="sg-filter-panel sg-stack">` that:

1. **Quick toggles folded in** — Failures and Impersonation checkboxes are now a `<div class="sg-cluster">` inside the single form, matching the quick-chip cluster pattern from `audit_index_live.ex`. Both use `name="outcome" value="failure"` and `name="action_prefix" value="admin.impersonation"` with `:checked` driven by `param_value(@current_params, ...)` — no `phx-click`, no `phx-hook`. The `label.sg-filter-chip:has(input[name="action_prefix"][value="admin.impersonation"])` selector structure the checkpoint test depends on is preserved.

2. **`<details>` advanced-disclosure** — The five text/date filter fields (Action prefix, Outcome select, Actor, Occurred from, Occurred to) are wrapped in a native CSS-only `<details>` with `<summary>More filters</summary>`. No JS, no `phx-hook`, no new `sg-*` classes.

3. **Date input convergence** — `from`/`to` inputs converted from `type="text"` to `type="date"` (Open Question 1 resolution: coherence with `audit_index_live.ex`; no existing test broke).

4. **Export CSV stays in the action row** — `export_path` `<a>` remains alongside Apply filters and Clear (D-04).

5. **`return_to` hidden input exactly once** — The two `return_to` inputs that died with the deleted quick-toggle forms (`:83`, `:96`) are gone. The canonical conditional input `<input :if={@return_to} type="hidden" name="return_to" value={@return_to} />` survives exactly once inside the single form.

### Task 2: Rewire desktop table / pagination / empty-state + delete duplicate helpers

**Desktop table body** — Replaced the 28-line hand-written `<tbody>` `<tr>` loop with:
```elixir
<.audit_table_row :for={row <- @rows} row={row} />
```
The `<thead>` stays per-page (Wave-1 canonical decision). The `data-testid="admin-audit-user-desktop-results"` container and its `sg-table-panel sg-show-desktop` wrapper are unchanged.

**Empty state** — Replaced `<.empty_state>` with `<.audit_empty_state>` preserving the per-user copy ("No audit events for this user" + "No scoped events are currently tied to this user." + conditional "Clear all filters" link).

**Pagination nav** — Replaced the 21-line inline `<nav>` with:
```elixir
<.audit_pagination_nav
  meta={@meta}
  prev_href={page_path(@admin_scope, @detail.user.id, @current_params, @meta && @meta.previous_page)}
  next_href={page_path(@admin_scope, @detail.user.id, @current_params, @meta && @meta.next_page)}
/>
```
Per-user routing divergence stays in this LiveView (D-09): `page_path/4` passes `user_id` and `return_to`.

**Deleted duplicate private helpers:**
- `defp audit_tone/1` (3 clauses) — now owned by `components.ex` private `audit_tone/1`, called inside `audit_table_row/1`
- `defp multi_page?/1` (2 clauses) — now owned by `components.ex` private `multi_page?/1`, used inside `audit_pagination_nav/1`
- `defp format_timestamp/1` (2 clauses) — now owned by `components.ex` private `format_timestamp/1`, used inside `audit_table_row/1`

**Mobile card list** — Kept unchanged: `<.audit_row :for={row <- @rows} row={row} show_detail show_codes />` (D-07).

## Verification

- `cd test/example && mix compile --warnings-as-errors` — clean (0 warnings, 0 errors)
- `mix test test/sigra/admin/glossary_test.exs` — 2 tests, 0 failures
- Exactly 1 `<form` in the file (grep confirms: line 81 only)
- `return_to` hidden input appears exactly once (line 157)
- No `phx-click` / `phx-hook` anywhere in the file
- No `sg-chevron` in the file
- Private `audit_tone/1` definitions: 0 (deleted)
- Private `multi_page?/1` definitions: 0 (deleted)
- Mobile card still uses `<.audit_row show_detail show_codes>`

## Deviations from Plan

**Open Question 1 resolution (Claude's Discretion):** Converged `from`/`to` inputs from `type="text"` to `type="date"`, matching `audit_index_live.ex`. No existing test broke. Noted in decisions.

No other deviations — plan executed as written.

## Known Stubs

None. All components render real data. No hardcoded empty values, placeholders, or TODO markers.

## Threat Flags

No new threat surface:
- T-202U-01 (return_to tampering): `sanitize_return_to/3` is untouched; hidden input survives exactly once (mitigation preserved)
- T-202U-02 (filter-param injection): `Explorer`/`query_params.ex` parameterized layer untouched (D-10)
- T-202U-03 (scope correctness): `Explorer.list_subject_events/4` untouched

No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- [x] `lib/sigra/admin/live/audit_user_live.ex` exists (416 lines, down from 485)
- [x] Commit `e768f789` (Task 1) exists in git log
- [x] Commit `c34c95a8` (Task 2) exists in git log
- [x] `mix compile --warnings-as-errors` clean
- [x] `mix test test/sigra/admin/glossary_test.exs` — 2 tests, 0 failures
- [x] Exactly 1 `<form` in file
- [x] `return_to` hidden input exactly once
- [x] 0 `phx-click`/`phx-hook` occurrences
- [x] 0 `sg-chevron` occurrences
- [x] 0 private `audit_tone/1` definitions
- [x] 0 private `multi_page?/1` definitions
