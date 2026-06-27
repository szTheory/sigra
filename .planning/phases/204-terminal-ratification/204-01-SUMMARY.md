---
phase: 204-terminal-ratification
plan: "01"
subsystem: test
tags: [audit, pagination, disclosure, test-hardening, ratification]
dependency_graph:
  requires: []
  provides: [WR-01-closed, WR-02-closed]
  affects: [audit-user-live-ledger-citation]
tech_stack:
  added: []
  patterns: [deterministic-boundary-test, disclosure-structural-lock]
key_files:
  created: []
  modified:
    - test/example/test/example_web/live/admin_audit_user_live_test.exs
decisions:
  - "Used distinct subject emails per test for isolation (no cross-test contamination)"
  - "extract_disclosure_region/1 targets 'Event codes' summary text specifically to skip the 'More filters' <details> that appears earlier on the per-user audit page"
  - "extract_next_href_forward/1 handles both attribute orderings in the rendered <a> tag for the Next page link"
  - "page_size=25 passed as query param to both boundary tests so the threshold is deterministic and independent of default config"
metrics:
  duration: "129s"
  completed: "2026-06-27"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 1
status: complete
---

# Phase 204 Plan 01: Per-user Audit Pagination Boundary + Event-codes Disclosure Lock Summary

**One-liner:** Two deterministic ExUnit tests lock the per-user audit pagination boundary at 25/26 events and the desktop Event-cell inline-code disclosure archetype, closing WR-01 and WR-02.

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Deterministic per-user audit pagination boundary test (WR-02 / D-06) | 3b15c28a | test/example/test/example_web/live/admin_audit_user_live_test.exs |
| 2 | Structural Event-codes disclosure lock (WR-01 / D-07) | 3b15c28a | test/example/test/example_web/live/admin_audit_user_live_test.exs |

## What Was Built

### Task 1: Per-user audit pagination boundary (WR-02 / D-06)

Added `describe "204 per-user audit pagination boundary (WR-02 / D-06)"` with two tests:

- **Test A (nav PRESENT):** Inserts exactly 26 events for a fresh subject, GETs `/admin/users/<id>/audit?page_size=25`. Asserts the pagination nav renders with a Next page link whose href contains `/admin/users/<subject_id>/audit` (user-scoped), `cursor=` (honest cursor), and `return_to=` (preserved). Exercises `page_path/4` contract, not the index `page_path/3`.

- **Test B (nav ABSENT):** Inserts exactly 25 events for a separate subject, GETs with `page_size=25`. Asserts NO Next or Previous pagination nav renders — single-page result is nav-free.

Both tests use distinct subject emails and insert explicit event counts with no reliance on seed data.

### Task 2: Structural Event-codes disclosure lock (WR-01 / D-07)

Added `describe "204 Event-codes disclosure archetype (WR-01 / D-07)"` with one structural test:

- GETs the per-user audit route for a subject with one inserted event.
- Asserts the desktop results table (`data-testid="admin-audit-user-desktop-results"`) is present.
- Asserts `<details>` exists and has **no** `open` attribute (default-collapsed).
- Asserts `<summary>` contains `Event codes` (the ratified disclosure label from `audit_table_row/1`).
- Asserts the event `id` (UUID) and `action` code appear inside the disclosure region (after `</summary>`) wrapped in `<code class="sg-code">` elements.

Private helpers added to the test module:
- `extract_next_href/1` / `extract_next_href_forward/1`: regex-based Next page href extraction handling both attribute orderings.
- `extract_disclosure_region/1`: slices the HTML after the `Event codes` summary close tag (skips the earlier `More filters` `<details>` on the page).

## Verification

```
MIX_ENV=test mix test test/example_web/live/admin_audit_user_live_test.exs
7 tests, 0 failures
```

`git diff --name-only` for this plan lists exactly one file: `test/example/test/example_web/live/admin_audit_user_live_test.exs`. No LiveView source or component code was changed.

## Deviations from Plan

None — plan executed exactly as written.

The plan called for these as two separate tasks but they touch the same file; both were committed atomically in a single `git commit` (3b15c28a) since both describe blocks were implemented and verified together.

## Known Stubs

None.

## Threat Flags

None — test-only changes, no new endpoints or security surface introduced.

## Self-Check: PASSED

- [x] `test/example/test/example_web/live/admin_audit_user_live_test.exs` modified: confirmed
- [x] Commit `3b15c28a` exists: confirmed
- [x] 7 tests, 0 failures: confirmed
- [x] No product code changed: confirmed
