---
phase: 202-audit-surfaces-elevation
plan: "03"
subsystem: admin-ui
tags: [audit, dry, shared-components, disclosure, wave-2]
status: complete

dependency_graph:
  requires:
    - Sigra.Admin.Components.audit_table_row/1 (202-01)
    - Sigra.Admin.Components.audit_pagination_nav/1 (202-01)
    - Sigra.Admin.Components.audit_empty_state/1 (202-01)
  provides: []
  affects:
    - lib/sigra/admin/live/audit_index_live.ex

tech_stack:
  added: []
  patterns:
    - Native CSS-only <details>/<summary> advanced-disclosure (no phx-hook, no chevron class)
    - Shared component adoption: audit_table_row/1, audit_pagination_nav/1, audit_empty_state/1
    - Pre-built href pass-in for per-page routing divergence (D-09 pattern)

key_files:
  created: []
  modified:
    - lib/sigra/admin/live/audit_index_live.ex

decisions:
  - "<details><summary>More filters</summary> summary text matches audit_user_live.ex byte-for-byte (CANONICAL Plan 02 wording)"
  - "audit_table_row/1 (<tr> only) used inside existing <thead>-per-page container — Wave-1 canonical decision honored"
  - "audit_pagination_nav/1 receives pre-built prev_href/next_href from page_path/3 — keeps index routing divergence local (D-09)"
  - "audit_empty_state/1 parametrized with same title and inner copy as before — no copy regression"
  - "Deleted private audit_tone/1, multi_page?/1, format_timestamp/1 — all now owned by components.ex"
  - "data-testid=admin-audit-desktop-results wrapper preserved — code.sg-code nodes remain inside Event <td> via shared audit_table_row/1"

metrics:
  duration: "116s (~2m)"
  completed: 2026-06-26
  tasks_completed: 2
  files_modified: 1
---

# Phase 202 Plan 03: Global Audit Page Disclosure + Shared Components (Wave 2) Summary

**One-liner:** Added native `<details>` advanced-disclosure to the global audit filter form and rewired desktop table / pagination / empty-state to Wave-1 shared components, deleting three private duplicate helpers.

## What Was Built

### Task 1: `<details>` advanced-disclosure

Wrapped the `sg-form-grid` advanced fields block (Actor, Effective user, Action prefix, Outcome, Occurred from, Occurred to) in a native CSS-only `<details><summary>More filters</summary>...</details>`. The summary text `"More filters"` is byte-identical to `audit_user_live.ex` (Plan 02). Quick chips (Failures / Impersonation checkboxes) remain outside the disclosure as always-visible summary controls. Export CSV stays in the action row cluster. The single `<form method="get">` and all named inputs are intact. No new `sg-*` class introduced.

### Task 2: Shared component adoption + helper deletion

Replaced the hand-written `<tbody>` `<tr>` loop (formerly lines 163-194) with:
```heex
<.audit_table_row :for={row <- @rows} row={row} />
```

The `<thead>` stays per-page (Wave-1 canonical decision: shared component is the `<tr>` body only).

Replaced `<.empty_state>` with `<.audit_empty_state>` carrying the same filter-aware index copy.

Replaced the hand-written `<nav>` (formerly lines 219-239) with:
```heex
<.audit_pagination_nav
  meta={@meta}
  prev_href={page_path(@admin_scope, @current_params, @meta && @meta.previous_page)}
  next_href={page_path(@admin_scope, @current_params, @meta && @meta.next_page)}
/>
```

Deleted three now-dead private helpers:
- `defp audit_tone/1` — owned by `components.ex` (single source of truth)
- `defp multi_page?/1` — owned by `audit_pagination_nav/1` in `components.ex`
- `defp format_timestamp/1` — owned by `audit_table_row/1` in `components.ex`

Kept all index-specific helpers: `scope_copy/1`, `6-key @chip_keys` (incl. actor/effective_user), `index_path/1`, `sort_path/3`, `page_path/3`, `remove_chip_path/3`, `export_path/2`.

## Verification

- `cd test/example && mix compile --warnings-as-errors` — clean
- `mix test test/sigra/admin/glossary_test.exs` — 2 tests, 0 failures
- `<details><summary>More filters</summary>` matches `audit_user_live.ex` byte-for-byte
- `data-testid="admin-audit-desktop-results"` wrapper preserved; `code.sg-code` nodes inside Event `<td>` via shared `audit_table_row/1` — `firstTexts(desktop, 'code.sg-code', 2)` content-equivalence contract intact (D-06)
- Zero `sg-chevron` in changed file (D-13 triple-copy gate is a no-op — no new CSS)
- Single GET form and all filter inputs intact; Export in action row (D-03/D-04)
- 6-key `@chip_keys` (incl. actor/effective_user) preserved (D-09)

## Deviations from Plan

None — plan executed exactly as written.

All tasks executed in two atomic commits:
- Task 1 (`e664e7f1`): `<details>` advanced-disclosure
- Task 2 (`1e9c1fab`): shared component adoption + helper deletion

## Known Stubs

None. All renders use real data from `@rows`, `@meta`, `@current_params`. No hardcoded empty values or placeholder markers introduced.

## Threat Flags

No new threat surface introduced. Changes are:
- Pure HEEx restructuring within the existing admin-gated LiveView
- All row/filter values render through HEEx auto-escaping (no `raw/1`)
- CSS-only `<details>` — no JS, no new network requests, no new auth boundary
- The deferred raw codes (event id + action code) were already visible on this admin-gated page; they are now behind the shared `<details>` disclosure in the Event `<td>` (T-202I-02: accepted)

## Self-Check: PASSED

- [x] `lib/sigra/admin/live/audit_index_live.ex` exists and contains `<details>` disclosure + shared component calls
- [x] Commit `e664e7f1` (Task 1) exists in git log
- [x] Commit `1e9c1fab` (Task 2) exists in git log
- [x] `mix compile --warnings-as-errors` clean
- [x] `mix test test/sigra/admin/glossary_test.exs` passes (2 tests, 0 failures)
- [x] `<summary>More filters</summary>` byte-identical in both audit LiveViews
- [x] `defp audit_tone`, `defp multi_page?`, `defp format_timestamp` not present in `audit_index_live.ex`
- [x] Zero `sg-chevron` in changed file
