---
phase: 157-overview-landings-highest-effort
plan: "03"
subsystem: admin-ui
tags:
  - liveview
  - loading-state
  - connected-gate
  - admin-overview
  - accessibility
  - exunit
dependency_graph:
  requires:
    - 157-01
    - 157-02
  provides:
    - ExUnit two-mount proof for Global Overview (LAND-04 disconnected + connected)
    - ExUnit two-mount proof for Org Overview (LAND-04 disconnected + connected)
    - Archetype-order assertions for LAND-01/02/03 on both screens
    - Full mix test suite green — prerequisite for Playwright wave
  affects:
    - test/example/test/example_web/admin_shell_test.exs
tech_stack:
  added: []
  patterns:
    - ConnCase GET → html_response/2 for disconnected (skeleton) state assertions
    - Phoenix.LiveViewTest live/2 for connected (data) state assertions
    - html_offset/2 private helper reused for archetype-order assertions
key_files:
  created: []
  modified:
    - test/example/test/example_web/admin_shell_test.exs
decisions:
  - Two-mount semantics proven via ConnCase GET (disconnected) + live/2 (connected) — the only reliable way to observe skeleton vs data state in ExUnit
  - Alarm-before-task-grid and task-grid-before-posture-strip order assertions use existing html_offset/2 helper (no new helper needed)
  - Each test creates its own fixture with System.unique_integer([:positive]) email suffix to avoid collision across parallel runs
  - Org live/2 test asserts Members and Pending invitations section headings are present even with no fixture members beyond the org_admin
metrics:
  duration: "~5 minutes"
  completed: "2026-06-04"
  tasks_completed: 1
  tasks_total: 1
  files_modified: 1
---

# Phase 157 Plan 03: ExUnit Two-Mount Proof for Overview Redesign Summary

## One-liner

Added `describe "Phase 157 Overview redesign"` to `admin_shell_test.exs` with 4 tests proving skeleton (ConnCase GET) and data (live/2) states for both Global and Org Overview screens, plus archetype-order assertions for LAND-01/02/03.

## Tasks Completed

| Task | Commit | Description |
|------|--------|-------------|
| Task 1: Add Phase 157 Overview redesign describe block with two-mount tests for Global and Org | b1247a2b | 4 new tests — skeleton state (GET) + data state (live/2) for both Overview screens |

## What Was Built

`test/example/test/example_web/admin_shell_test.exs` — new `describe "Phase 157 Overview redesign"` block appended before `describe "denied states are not blank pages"`:

**Test 1: global overview disconnected mount (GET) renders skeleton, not stat values**
- Creates platform-admin+ user, GETs `/admin` via ConnCase
- Asserts: `sg-skeleton` present, `aria-busy="true"` present, `sg-metric-link__value` absent, `sg-posture-strip__risk` absent
- Proves LAND-04 disconnected state and LAND-01 cleanup

**Test 2: global overview connected mount (live/2) renders data, not skeleton**
- Creates platform-admin+ user, calls `live/2` on `/admin`
- Asserts: `sg-skeleton` absent, `aria-busy="true"` absent, `sg-metric-link__value` present, `sg-notice` present, `role="status"` present, `sg-posture-strip__risk` absent
- Archetype-order: alarm notice before `sg-grid sg-grid--3`, task grid before `sg-card sg-posture-strip`
- Proves LAND-04 connected state + LAND-01/02/03

**Test 3: org overview disconnected mount (GET) renders skeleton, not stat values**
- Creates org_admin user + organization + membership, GETs `/admin/organizations/:slug`
- Asserts: `sg-skeleton` present, `aria-busy="true"` present, `sg-metric-link__value` absent, `sg-posture-strip__risk` absent, `Scoped attention` absent
- Proves LAND-04 disconnected state and D-07 fix (Scoped attention card deleted)

**Test 4: org overview connected mount (live/2) renders data, not skeleton**
- Same org_admin + organization + membership setup, calls `live/2` on org slug path
- Asserts: `sg-skeleton` absent, `aria-busy="true"` absent, `sg-metric-link__value` present, `sg-notice` present, `role="status"` present, `sg-posture-strip__risk` absent, `Scoped attention` absent
- Archetype-order: alarm notice before `sg-grid sg-grid--2`, task grid before `sg-card sg-posture-strip`
- LAND-03: `sg-posture-strip` present, `Members` present, `Pending invitations` present
- Proves LAND-04 connected state + LAND-01/02/03 + D-05 org tail

## Verification

- `mix test test/example/test/example_web/admin_shell_test.exs` — 10 tests, 0 failures (6 existing + 4 new)
- `cd test/example && mix test` — 191 tests, 0 failures, 73 excluded (full example app suite green)
- `grep -c "Phase 157 Overview redesign" ...admin_shell_test.exs` — 1 (describe block present)
- `grep -c "sg-skeleton" ...admin_shell_test.exs` — 4 (assertions in all 4 new tests)
- `grep -c "sg-metric-link__value" ...admin_shell_test.exs` — 4 (refute in GET tests, assert in live/2 tests)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — test-only file addition. No production code changed.

## Threat Flags

None. Test-only file addition — no new network endpoints, auth paths, or schema changes. All trust boundary mitigations from the plan's threat model are satisfied:

- T-157-03a: Tests run in SQL Sandbox (async: false). Fixture data isolated per-test.
- T-157-03b: `role="status"` assertion confirms the ARIA contract holds.
- T-157-SC: No new packages installed.

## Self-Check: PASSED

- [x] `test/example/test/example_web/admin_shell_test.exs` modified
- [x] `grep -c "Phase 157 Overview redesign"` returns 1
- [x] commit b1247a2b exists in git log
- [x] 10 tests, 0 failures in targeted file
- [x] 191 tests, 0 failures in example app full suite
