---
phase: 242-close-gap-xw-01-xw-02-add-rendered-crosswake-start-control
plan: "01"
subsystem: hosted-crosswake-runtime
tags: [crosswake, phoenix-liveview, playwright, csrf, security]
requires:
  - phase: 240.3-close-gap-xw-01-xw-02-wire-hosted-crosswake-runtime-flow
    provides: authenticated controller start route and real-cookie-jar return proof
provides:
  - Rendered Tasklane control for the existing authenticated Crosswake start route
  - Source contract rejecting browser-side fabricated Crosswake submission
affects: [XW-01, XW-02]
tech-stack:
  added: []
  patterns: [native-phoenix-post-form, role-driven-browser-navigation, source-contract-guard]
key-files:
  created: []
  modified:
    - test/example/lib/example_web/live/app_live.ex
    - test/example/test/example_web/live/app_live_test.exs
    - test/example/priv/playwright/tests/crosswake-hosted-runtime.spec.ts
    - test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs
decisions:
  - Keep Crosswake initiation as a native CSRF-protected POST from the existing authenticated Tasklane account hub.
  - Keep all continuation, session, evaluator, and navigation authority server-owned; the browser proof only clicks the rendered control.
metrics:
  duration: 12m
  completed_date: 2026-08-12
  tasks_completed: 2
  files_changed: 4
status: complete
---

# Phase 242 Plan 01: Rendered Crosswake Start Control Summary

**Authenticated Tasklane users can now click a native `Continue to Crosswake` control that drives the established CSRF-protected Crosswake return journey with their real browser cookie jar.**

## Accomplishments

- Added a fourth Tasklane quick-action panel containing the native `POST /crosswake/start` form, stable `app-crosswake-start` hook, standard CSRF field, and no application-defined inputs or LiveView binding.
- Replaced Playwright DOM fabrication with a visible role/name assertion and native button click, retaining request observers, exact callback keys, absent Referer, fixed `/app` destination, and disclosure sentinels.
- Extended the existing Phase 240.3 source contract to lock the rendered form markers, role-driven click, no fabricated submission, serial worker, and zero-retry constraints.

## Verification

- `cd test/example && mix test test/example_web/live/app_live_test.exs` — passed (4 tests).
- `MIX_ENV=test mix test test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs` — passed (8 tests).
- `scripts/ci/hosted-session-interop-proof.sh --browser-only` — passed (1 serial Chromium test).
- Final adapter/continuation/controller/P14 matrix — attempted after restoring the browser runner's selected-port compilation; one pre-existing residual-row cleanup assertion failed (`expected 2`, `got 4`) in `CrosswakeContinuationsTest`. Details are recorded in `deferred-items.md`.

## Task Commits

1. **Task 1 RED: Add Crosswake start form contract** — `e5adc7e6` (`test`)
2. **Task 1 GREEN: Render Crosswake start control** — `32b635b6` (`feat`)
3. **Task 2: Lock rendered Crosswake entry** — `54459fac` (`test`)

## Decisions Made

- Kept the rendered entry in the host-owned Tasklane `vt-*` account hub; no admin `sg-*` work, generated-host output, or protocol API changed.
- Required the browser proof to use the exact accessible button name and removed the browser-side synthetic form so the real cookie jar owns the entire journey.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Restore the default test compile port after the browser runner**
- **Found during:** Final security matrix verification.
- **Issue:** The browser runner deliberately compiles the example host for a selected free port, causing Mix's compile-time endpoint guard to reject the following default-port matrix.
- **Fix:** Recompiled the test host with the default scoped test environment before retrying the unchanged matrix.
- **Files modified:** None.

## Deferred Issues

- The final aggregate security command has one pre-existing database-isolation failure in the shared local `example_test` database. The Phase 240.3 milestone audit already records this residual terminal-continuation-row issue; no Crosswake behavior was changed to mask it.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed all four modified implementation/test artifacts exist.
- Confirmed commits `e5adc7e6`, `32b635b6`, and `54459fac` resolve in git history.
