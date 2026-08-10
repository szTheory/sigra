---
phase: 239-hosted-session-interop
plan: "03"
subsystem: hosted-session-interop
tags: [crosswake, sigra, ecto, session, revocation, expiry]
requires:
  - phase: 239-hosted-session-interop
    provides: "Fresh cookie-to-session Crosswake projection and database-backed personal-session tracer"
provides:
  - "Fail-closed host binding resolution for malformed, missing, deleted, missing-subject, and inactive sessions"
  - "Deterministic idle and absolute expiry boundary proof before Crosswake evaluation"
affects: [239-04, 239-05, 239-06, crosswake-consumption]
tech-stack:
  added: []
  patterns: ["Revalidate the canonical Ecto session and user before invoking an injected pure evaluator", "Use fixed UTC instants and real Ecto rows for authority expiry boundaries"]
key-files:
  created: []
  modified:
    - test/example/lib/example/accounts/crosswake_session_adapter.ex
    - test/example/test/example/accounts/crosswake_session_adapter_test.exs
key-decisions:
  - "Both expected binding projection and replay evaluation resolve and validate current host state; cached opaque bindings never confer fallback authority."
  - "The evaluator seam is injected only after storage, state, binding, and expiry checks, enabling a deterministic zero-invocation assertion."
patterns-established:
  - "Host denial normalizes malformed and unavailable session states to :session_unavailable without surfacing host credential or row details."
requirements-completed: [XW-02]
coverage:
  - id: D1
    description: "Real Ecto rows prove malformed, deleted, missing-subject, and inactive host state all deny before the evaluator can run."
    requirement: XW-02
    verification:
      - kind: integration
        ref: "cd test/example && mix test test/example/accounts/crosswake_session_adapter_test.exs --only crosswake_currentness"
        status: pass
    human_judgment: false
  - id: D2
    description: "Real Ecto rows prove strict idle and absolute session boundaries deny at equality and allow one microsecond inside."
    requirement: XW-02
    verification:
      - kind: integration
        ref: "cd test/example && mix test test/example/accounts/crosswake_session_adapter_test.exs --only crosswake_expiry"
        status: pass
    human_judgment: false
duration: 7min
completed: 2026-08-10
status: complete
---

# Phase 239 Plan 03: Current Host Session Denial Summary

**The example Crosswake adapter now rejects stale or unavailable canonical session state before constructing authority facts or invoking the evaluator, with exact real-row expiry boundaries.**

## Performance

- **Duration:** 7min
- **Started:** 2026-08-10T00:25:00Z
- **Completed:** 2026-08-10T00:32:45Z
- **Tasks:** 2 completed
- **Files modified:** 2

## Accomplishments

- Revalidated canonical storage state on every expected-binding projection and replay evaluation, denying malformed, deleted, missing-subject, and inactive sessions through one safe class.
- Added an injected evaluator seam that is reached only after fresh storage, binding, and validity checks; the denial matrix asserts zero invocations.
- Proved strict-less-than idle and absolute expiry behavior with fixed UTC microsecond boundaries and real Ecto rows, without sleeps.

## Task Commits

1. **Tasks 1–2 TDD RED: add real-row currentness and expiry denial matrix** - `801d44d7` (test)
2. **Tasks 1–2 TDD GREEN: fail closed before Crosswake evaluation** - `034315e6` (feat)

## Files Created/Modified

- `test/example/lib/example/accounts/crosswake_session_adapter.ex` - validates current host state before opaque binding projection or evaluator use and exposes the test evaluator seam.
- `test/example/test/example/accounts/crosswake_session_adapter_test.exs` - Ecto-backed storage currentness, deletion replay, and precise expiry-boundary proof.

## Decisions Made

- A serialized opaque binding is evidence to compare, never authority to reuse; fresh session/user validation remains mandatory for all public adapter operations.
- All host-binding failures collapse to `:session_unavailable`, keeping diagnostics categorical and free of supplied credentials, digests, or row identifiers.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test precision] Used microsecond-precision fixed datetimes for Ecto session rows.**
- **Found during:** Tasks 1–2 RED run
- **Issue:** `:utc_datetime_usec` rejects fixed timestamps without microsecond precision.
- **Fix:** Expressed all matrix timestamps with `.000000Z` and retained the one-microsecond boundary controls.
- **Files modified:** `test/example/test/example/accounts/crosswake_session_adapter_test.exs`
- **Verification:** Both focused tags and the complete adapter test file pass.

**2. [Rule 3 - Blocking] Started the repository-provided ephemeral PostgreSQL service.**
- **Found during:** Task 1 RED run
- **Issue:** The configured local PostgreSQL port was unavailable, preventing the real Ecto matrix from creating its test database.
- **Fix:** Ran `scripts/db/up.sh` and sourced `tmp/db.env` for deterministic test execution.
- **Files modified:** None tracked.
- **Verification:** All adapter tests pass against the real Ecto store.

**Total deviations:** 2 auto-fixed (1 Rule 1, 1 Rule 3).
**Impact on plan:** Both fixes were necessary for deterministic database-backed proof; no scope expansion.

## Issues Encountered

The first RED run exposed the intentionally missing evaluator seam and an unavailable local test database. The seam was implemented after the red test, and the repository database helper supplied the test store.

## Known Stubs

None.

## User Setup Required

None - the repository's ephemeral PostgreSQL helper provides the database-backed verification environment.

## Next Phase Readiness

Plans 04–06 can rely on the adapter's fail-closed currentness and expiry boundary: invalid server state cannot be revived by a cached binding or reach the pure Crosswake evaluator.

## Self-Check: PASSED

- Confirmed both modified adapter files exist.
- Confirmed commits `801d44d7` and `034315e6` exist in Git history.
- Confirmed both focused tags, the complete adapter test file, formatter check, no-sleep guard, and whitespace check pass.
