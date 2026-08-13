---
phase: 246-hosted-and-direct-login-ceremonies
plan: 06
subsystem: auth
tags: [elixir, mix, installer, app-sessions, tdd]
requires:
  - phase: 245-opaque-app-session-core
    provides: app-session ownership and lifecycle contract
provides:
  - Independent installer flags for app sessions and direct password login
  - Additive app-session generator feature with deterministic migration slots
affects: [246-07, 246-08, generated-host-installation]
tech-stack:
  added: []
  patterns: [additive installer feature, fail-closed CLI dependency]
key-files:
  created: [lib/sigra/install/features/app_sessions.ex, test/sigra/install/app_sessions_generator_test.exs]
  modified: [lib/mix/tasks/sigra.install.ex, test/mix/tasks/sigra.install_test.exs]
key-decisions:
  - "App sessions, direct password login, API, and JWT remain independent installer selections; direct password login requires explicit app-session selection."
  - "App-session migration timestamps are Runner-owned and allocated in family, token, and ceremony order."
patterns-established:
  - "New generator surfaces are isolated Feature modules registered after Core."
requirements-completed: [APP-01]
coverage:
  - id: D1
    description: Independent app-session, password-login, API, and JWT installer selection contract
    requirement: APP-01
    verification:
      - kind: unit
        ref: MIX_ENV=test mix test test/mix/tasks/sigra.install_test.exs test/sigra/install/app_sessions_generator_test.exs test/sigra/install/features/core_test.exs --trace
        status: pass
    human_judgment: false
duration: 4min
completed: 2026-08-12
status: complete
---

# Phase 246 Plan 06: Independent App-Session Installer Selection Summary

**Independent app-session and direct-password installer flags now fail closed, preserve API/JWT isolation, and reserve deterministic generator migration slots.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-08-13T01:43:20Z
- **Completed:** 2026-08-13T01:45:25Z
- **Tasks:** 1/1
- **Files modified:** 4

## Accomplishments

- Added false-default `--app-sessions` and `--app-password-login` switches without coupling them to API or JWT selection.
- Added the isolated `Sigra.Install.Features.AppSessions` feature with symbolic host artifact inventory and Runner-allocated family, token, and ceremony migration slots.
- Locked the complete boolean option matrix and invalid direct-password prerequisite with deterministic tests.

## Task Commits

1. **Task 1: Select one app-session generator feature without selecting API or JWT** - `257eafb7` (test), `a4f749b6` (feat)

## Files Created/Modified

- `lib/mix/tasks/sigra.install.ex` - Parses independent app installer flags and rejects invalid direct-password selection.
- `lib/sigra/install/features/app_sessions.ex` - Additive, feature-gated artifact and migration contract.
- `test/mix/tasks/sigra.install_test.exs` - Covers the fail-closed CLI prerequisite.
- `test/sigra/install/app_sessions_generator_test.exs` - Covers the complete flag matrix and deterministic migration allocation.

## Decisions Made

- Direct password login never implies app-session ownership and is rejected unless `--app-sessions` is selected.
- Later plans own real ceremony templates; this plan establishes only their feature-gating and symbolic inventory contract.

## Deviations from Plan

### Deferred State-Tool Issue

- `state.advance-plan` could not parse the pre-existing `Current Plan` / `Total Plans in Phase` fields in `STATE.md`.
- Remaining state, roadmap, requirement, decision, metric, and session updates completed through the SDK.

## Issues Encountered

The focused ExUnit process logged unavailable local PostgreSQL connections during startup, but all selected installer tests completed successfully and do not require a database connection.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 07 can populate the reserved app-session artifact inventory with generated host schemas, migration, profiles, and delegates while preserving this selection contract.

## Self-Check: PASSED

- Confirmed `lib/sigra/install/features/app_sessions.ex` and `test/sigra/install/app_sessions_generator_test.exs` exist.
- Confirmed commits `257eafb7` and `a4f749b6` exist in git history.
