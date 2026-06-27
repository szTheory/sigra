---
phase: 201
plan: "02"
subsystem: example-host-seam
tags:
  - host-seam
  - blind-spot
  - list-seam
  - extra-badges
  - extra-columns
  - d-07
dependency_graph:
  requires:
    - "201-01 (DRY refactor of users_index_live desktop+mobile layouts)"
  provides:
    - "Non-empty extra_list_badges + extra_list_columns for live equivalence spec coverage"
  affects:
    - "assertUserResultEquivalence Playwright spec (exercises extra_badges/extra_columns seam in both layouts)"
tech_stack:
  added: []
  patterns:
    - "Host-seam blind-spot close: emit non-empty fixture values to make live specs exercise the seam"
key_files:
  modified:
    - test/example/lib/example/sigra_admin_users.ex
decisions:
  - "Used binary 'Example badge' for extra_list_badges/1 — matches badge_text/1's binary clause (users_index_live.ex:634)"
  - "Used %{label: 'Region', value: 'us-east'} for extra_list_columns/0 — matches column_text/2's label+value map clause (users_index_live.ex:637)"
  - "Copy is glossary-clean: neutral demo labels (Region/us-east/Example badge) avoid banned admin terms"
metrics:
  duration: "34s"
  completed: "2026-06-26"
  tasks_completed: 1
  tasks_total: 1
  files_changed: 1
status: complete
---

# Phase 201 Plan 02: Example Host-Seam Blind-Spot Close (extra_list_badges + extra_list_columns) Summary

**One-liner:** Emit non-empty badge + column from example `SigraAdminUsers` hooks so the live `assertUserResultEquivalence` spec exercises the `extra_badges`/`extra_columns` seam in both desktop and mobile layouts (INDEX-03 / D-07).

## What Was Built

Changed two callback implementations in `test/example/lib/example/sigra_admin_users.ex`:

- `extra_list_badges/1`: `[]` → `["Example badge"]`  
  Matches `badge_text/1`'s binary clause (`users_index_live.ex:634`), which passes the string through as-is into the badge slot in both the desktop status `<td>` and mobile cluster.

- `extra_list_columns/0`: `[]` → `[%{label: "Region", value: "us-east"}]`  
  Matches `column_text/2`'s `%{label:, value:}` map clause (`users_index_live.ex:637`), which renders `"Region: us-east"` into both the desktop activity `<td>` and mobile `dl`.

The host-seam callback contract is unchanged: both functions still have the same arity, same `@impl true` annotation (total count 7), and return the same type (a list). Only the example's return values changed from empty to one-element lists.

## Verification Results

- `grep -c 'def extra_list_badges(_user), do: \[\]'` → 0 (empty default gone)
- `grep -c 'def extra_list_columns, do: \[\]'` → 0 (empty default gone)
- `grep -c '@impl true'` → 7 (unchanged; callback contract intact)
- `cd test/example && mix compile --warnings-as-errors` → clean (no warnings, no errors)

## Deviations from Plan

None — plan executed exactly as written.

## Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Emit non-empty extra_list_badges + extra_list_columns from example hook | a44fd23d | test/example/lib/example/sigra_admin_users.ex |

## Known Stubs

None — this plan only changed test fixture return values to non-empty; no stubs introduced.

## Threat Flags

None — badge/column values render through HEEx (auto-escaped) and are test-fixture strings under our control, not user input. No new security surface introduced.

## Self-Check: PASSED

- [x] `test/example/lib/example/sigra_admin_users.ex` exists with non-empty return values
- [x] Commit `a44fd23d` exists in git log
- [x] `mix compile --warnings-as-errors` clean
- [x] `@impl true` count unchanged at 7
