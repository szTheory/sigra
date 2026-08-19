---
phase: 247-language-learning-digital-twin
plan: 03
subsystem: authentication
tags: [elixir, phoenix, ecto, postgres, liveview, offline-lease]
requires:
  - phase: 247-01
    provides: LearningTwin leases, replay receipts, authenticated routes, and lesson surface
provides:
  - Exact microsecond lease validation with a bounded seven-day default
  - Current-Scope-first lease and partition authorization for bootstrap and replay
  - Account-safe bootstrap denial and focused expired lesson replacement rendering
affects: [247-05, language-learning-digital-twin, offline-lease, replay]
tech-stack:
  added: []
  patterns: [current-Scope-first partition lookup, strict utc_datetime_usec expiry, focused replacement rendering]
key-files:
  created:
    - test/example/test/example/learning_twin/learning_twin_test.exs
    - test/example/test/example_web/controllers/learning_twin_controller_test.exs
    - test/example/test/example_web/live/learning_twin_live_test.exs
  modified:
    - test/example/lib/example/learning_twin.ex
key-decisions:
  - "Lease validity uses DateTime.compare/2 with strict less-than, so the exact expiry microsecond is invalid."
  - "Client partition selectors are compared only after current-Scope-owned lease lookup and never select an account."
  - "Unavailable, expired, or mismatched lesson state replaces all lesson and receipt markup with a focusable recovery heading."
patterns-established:
  - "Offline lease consumers return normalized :unavailable, :expired, or :partition_mismatch outcomes."
requirements-completed: [TWIN-01, OFF-02]
coverage:
  - id: D1
    description: Exact configured lease TTL validation and microsecond expiry boundary authorization.
    requirement: OFF-02
    verification:
      - kind: integration
        ref: "mix test test/example/learning_twin/learning_twin_test.exs --trace"
        status: pass
    human_judgment: false
  - id: D2
    description: Current-account-only bootstrap and expired replacement rendering without prior-account disclosure.
    requirement: TWIN-01
    verification:
      - kind: integration
        ref: "mix test test/example_web/controllers/learning_twin_controller_test.exs test/example_web/live/learning_twin_live_test.exs --trace"
        status: pass
    human_judgment: false
metrics:
  duration: 14min
  completed: 2026-08-19
status: complete
---

# Phase 247 Plan 03: Lease and Account Boundary Summary

**Host-owned, microsecond-exact offline leases now authorize only the current Scope and replace unsafe lesson state without exposing prior-account content.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-08-19T02:10:00Z
- **Completed:** 2026-08-19T02:23:35Z
- **Tasks:** 2/2
- **Files modified:** 4

## Accomplishments

- Added bounded positive TTL validation with a 604800-second default and strict `utc_datetime_usec` expiry semantics.
- Added current-Scope-first active lease and opaque partition authorization, including replay hardening.
- Added controller and LiveView denial paths that omit prior lesson and receipt content and focus the recovery heading.

## Task Commits

1. **Task 1: Define exact lease and current-account activation boundaries** - `0fcaad98` (test), `48671fe0` (feat)
2. **Task 2: Enforce account-safe bootstrap and replacement rendering** - `5fd408b7` (test), `6b5e3172` (feat)

## Files Created/Modified

- `test/example/lib/example/learning_twin.ex` - Validates leases, authorizes partitions from the trusted scope, and renders safe bootstrap state.
- `test/example/test/example/learning_twin/learning_twin_test.exs` - PostgreSQL-backed TTL, expiry, and partition authority tests.
- `test/example/test/example_web/controllers/learning_twin_controller_test.exs` - Login-bound bootstrap and foreign-selector denial tests.
- `test/example/test/example_web/live/learning_twin_live_test.exs` - Current-account lesson and focused expired-replacement tests.

## Decisions Made

- Exact expiry is closed: only `as_of < expires_at` is valid.
- Partition input remains opaque correlation data; it cannot select a user or authorize a replay.
- Denial rendering uses the approved recovery copy and a `phx-mounted` focus command on its heading.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Replaced an invalid local-function guard in active lease lookup**
- **Found during:** Task 1
- **Issue:** Elixir guards cannot invoke the local `lease_valid?/2` function.
- **Fix:** Performed the strict lease comparison inside the selected lease branch.
- **Files modified:** `test/example/lib/example/learning_twin.ex`
- **Verification:** Focused context tests pass.
- **Committed in:** `48671fe0`

**2. [Rule 1 - Bug] Corrected the unauthenticated controller assertion to inspect the redirect body**
- **Found during:** Task 2
- **Issue:** The test incorrectly requested a 200 response after proving the authenticated pipeline redirects with 302.
- **Fix:** Asserted absence of lesson content from the actual redirect body.
- **Files modified:** `test/example/test/example_web/controllers/learning_twin_controller_test.exs`
- **Verification:** Focused controller and LiveView tests pass.
- **Committed in:** `6b5e3172`

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs).
**Impact on plan:** Both fixes were required to make the intended tests and implementation executable; no scope expanded.

## Issues Encountered

- The initial focused test run could not connect to the local PostgreSQL service. Started the repository-provided ephemeral database via `scripts/db/up.sh`; all final tests ran against its configured PostgreSQL endpoint.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 05 can consume normalized lease/partition failures to make local cache activation and replay fail closed across logout and account switches.
- The focused PostgreSQL-backed boundary tests provide deterministic regression proof; no human UAT remains.

## Self-Check: PASSED

- All four planned source/test files exist.
- All four Task 1/Task 2 TDD commits exist in git history.
- Both plan verification commands and formatter validation passed.

---
*Phase: 247-language-learning-digital-twin*
*Completed: 2026-08-19*
