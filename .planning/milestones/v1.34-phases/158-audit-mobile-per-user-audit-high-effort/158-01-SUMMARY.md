---
phase: 158-audit-mobile-per-user-audit-high-effort
plan: "01"
subsystem: admin-components
tags:
  - audit-row
  - components
  - tdd
  - format-date
  - tone-derivation
  - d09
  - d10
dependency_graph:
  requires: []
  provides:
    - audit_row/1 component in Sigra.Admin.Components
    - audit_tone/1 unified tone helper (single source of truth)
    - format_date/1 with NaiveDateTime support (D-09 fix)
  affects:
    - wave-2 plans (158-02 through 158-04) that consume audit_row/1
tech_stack:
  added: []
  patterns:
    - TDD red-green with render_component byte-goldens
    - Private tone + date helpers co-located with component
key_files:
  created: []
  modified:
    - lib/sigra/admin/components.ex
    - test/sigra/admin/components_test.exs
decisions:
  - audit_tone/1 placed as private helper in components.ex (co-located with consumer, no public API widening)
  - format_date/1 uses def/do body for raise clause to avoid Elixir ambiguity warning
  - golden strings captured via probe test run against actual Phoenix.Component output (not hand-authored)
  - compact golden characterizes component's real output with trailing space on root class (house convention with @class=nil)
metrics:
  duration: "~10 minutes"
  completed: "2026-06-04"
  tasks_completed: 2
  files_modified: 2
---

# Phase 158 Plan 01: audit_row/1 Component + Goldens Summary

`audit_row/1` added as the 11th shared component in `Sigra.Admin.Components`, with a unified `audit_tone/1` tone helper and a corrected `format_date/1` that handles `%NaiveDateTime{}` (D-09 fix) and raises on wrong types (T-158-01 mitigation). Byte-equal goldens freeze both compact and full variants plus tone-mapping and date-helper unit cases.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| RED | Add failing tests for audit_row/1 | a381102c | test/sigra/admin/components_test.exs |
| GREEN | Add audit_row/1 + helpers to components.ex | e56ccd7c | lib/sigra/admin/components.ex |
| STYLE | Fix ambiguous do: syntax in format_date/1 | a9687643 | lib/sigra/admin/components.ex |

## What Was Built

### `audit_row/1` (11th component)

A card-form component rendering the `sg-list-row <article>` shape for all three audit consumer sites:
- `AuditIndexLive` mobile card list (`show_detail: true`, `show_codes: true`)
- `AuditUserLive` mobile card list (`show_detail: true`, `show_codes: true`)
- `UserShowLive` "Recent Audit" compact block (defaults: `show_detail: false`, `show_codes: false`)

Attrs follow house style: `row` (required), `show_detail` (default false), `show_codes` (default false), plus `:class`/`:rest` convention. No `variant` attr (D-01 hard-fail honored).

### `audit_tone/1` (private, D-10)

Single source of truth for audit tone derivation, retiring the divergent `row_tone/1` (×2) in `AuditIndexLive`/`AuditUserLive` and the old `audit_tone/1` in `UserShowLive`:
- outcome not in `["success", nil, ""]` → `"risk"`
- action_badge present → `"info"`
- otherwise → `nil`

### `format_date/1` (private, D-09)

Handles `%DateTime{}` and `%NaiveDateTime{}` (formats as `"%Y-%m-%d %H:%M"`, no seconds), `nil` → `"—"`, any other value → `raise ArgumentError` (T-158-01: no silent swallow of a wrong-typed value).

### Tests

9 new test cases in `components_test.exs`:
- Compact byte-equal golden (frozen against `@audit_row_compact_golden`)
- Full byte-equal golden (frozen against `@audit_row_full_golden`)
- Tone-mapping: failure → risk, impersonation → info, success → no data-tone
- `format_date` unit cases: `%DateTime`, `%NaiveDateTime`, `nil→"—"`, wrong-type → `ArgumentError`

All 19 tests (10 existing + 9 new) pass with no Postgres dependency (`@endpoint nil`).

## TDD Gate Compliance

RED commit (a381102c): `test(158-01)` — failing tests for `audit_row/1` (undefined function confirmed).
GREEN commit (e56ccd7c): `feat(158-01)` — implementation making all tests pass.

## Deviations from Plan

None. Plan executed exactly as written with one minor style fix:

**Style cleanup:** The initial `format_date/1` catch-all used multi-line `do:` syntax with `raise`, triggering an Elixir compiler ambiguity warning. Changed to `def/do` body form (commit a9687643). No behavior change.

## Verification

- `mix test test/sigra/admin/components_test.exs` — 19 tests, 0 failures
- `grep -n "def audit_row" lib/sigra/admin/components.ex` — line 374
- `grep -n "raise ArgumentError" lib/sigra/admin/components.ex` — line 412
- `grep "Provides 11" lib/sigra/admin/components.ex` — matches
- `grep "variant" lib/sigra/admin/components.ex` — 0 matches (D-01 honored)
- `grep -c "raw(" lib/sigra/admin/components.ex` — 0 (T-158-02 honored)

## Known Stubs

None. All fields are wired to real assigns from the presenter row map. No placeholder text or TODO items in the implementation.

## Threat Flags

None. The only modification is to an internal component library. No new network endpoints, auth paths, or schema changes. The `format_date/1` catch-all raises `ArgumentError` rather than rendering struct internals (T-158-01 mitigated). All dynamic HEEx interpolation uses `{...}` (auto-escaped, no `raw/1`).

## Self-Check: PASSED

- lib/sigra/admin/components.ex — FOUND (def audit_row at line 374, raise ArgumentError at line 412)
- test/sigra/admin/components_test.exs — FOUND (audit_row_compact_golden, audit_row_full_golden, assert_raise ArgumentError)
- Commits exist: a381102c (RED test), e56ccd7c (GREEN impl), a9687643 (style)
