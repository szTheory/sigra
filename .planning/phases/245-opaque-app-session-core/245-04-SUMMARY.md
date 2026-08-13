---
phase: 245-opaque-app-session-core
plan: 04
subsystem: auth
tags: [ecto, postgres, opaque-tokens, refresh-rotation, audit, concurrency]
requires:
  - phase: 245-opaque-app-session-core
    provides: Locked opaque refresh classification with digest-addressed family rotation and reuse revocation.
  - phase: 244-pat-and-advanced-jwt-truth-repair
    provides: Optional audit Multi and post-commit telemetry pattern.
provides:
  - App-session refresh audit co-fate for rotation and reuse in audit-on and audit-off configurations.
  - Constraint-fault rollback proof that returns no replacement credential.
  - Barrier-controlled PostgreSQL concurrency proof for one rotate winner and one reuse outcome.
affects: [246-first-party-app-session-install-and-issuance]
tech-stack:
  added: []
  patterns: [optional audit Multi step, post-commit audit telemetry, barrier-controlled Sandbox concurrency]
key-files:
  created: [test/sigra/app_session_audit_cofate_test.exs, test/sigra/app_session/concurrency_test.exs]
  modified: [lib/sigra/app_session.ex]
key-decisions:
  - "App-session refresh appends its optional audit insert to the same lifecycle Multi rather than selecting a distinct audit path."
  - "Audit metadata contains only family ID, app-session kind, and lifecycle action; raw credentials, digests, client references, and authorization material stay excluded."
  - "Concurrent refresh proof uses only Sandbox allow plus explicit ready/go barriers, never sleeps, retries, or mocked locks."
patterns-established:
  - "Normalize Ecto persistence exceptions at the public refresh boundary after the transaction rolls back, so no in-memory replacement can escape."
requirements-completed: [APP-04]
coverage:
  - id: D1
    description: Audit-on/off refresh rotation and reuse commit their audit and lifecycle records together, while constraint faults roll back all lifecycle mutations.
    requirement: APP-04
    verification:
      - kind: integration
        ref: "source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_audit_cofate_test.exs --trace"
        status: pass
    human_judgment: false
  - id: D2
    description: Two barrier-released PostgreSQL callers produce exactly one rotation and one serialized reuse-family revocation in both audit modes.
    requirement: APP-04
    verification:
      - kind: integration
        ref: "source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session/concurrency_test.exs --trace"
        status: pass
    human_judgment: false
metrics:
  duration: 17min
  completed: 2026-08-13
  tasks: 2
  files: 4
status: complete
---

# Phase 245 Plan 04: App-Session Refresh Co-Fate Summary

**Opaque app-session refresh now commits lifecycle state and optional bounded audit evidence together, with rollback-safe responses and deterministic two-caller PostgreSQL serialization proof.**

## Performance

- **Duration:** 17 min
- **Completed:** 2026-08-13T00:48:03Z
- **Tasks:** 2/2
- **Files modified:** 4

## Accomplishments

- Appended `session.app_refresh` and `session.app_refresh_reuse` to the existing refresh Multi only when audit is configured, then emitted audit telemetry only after commit.
- Proved audit-on/off lifecycle equivalence, audit/persistence constraint rollback, unchanged usable state after abort, and no replacement return on failure.
- Added a no-sleep ready/go barrier test using real Sandbox-allowed PostgreSQL callers; both audit modes yield one rotate, one reuse result, and one fully revoked family.

## Task Commits

1. **Task 1: Prove refresh persistence and audit share one rollback boundary** — `0b77818f` (RED), `a5d53549` (GREEN)
2. **Task 2: Serialize double refresh with barriers and row locks** — `30c36009` (test proof)

## Files Created/Modified

- `lib/sigra/app_session.ex` — composes bounded optional refresh/reuse audit steps into the lifecycle transaction and emits telemetry only after commit.
- `test/sigra/app_session_audit_cofate_test.exs` — validates audit modes, bounded metadata, constraint rollback, and no-secret abort outcomes.
- `test/sigra/app_session/concurrency_test.exs` — validates real two-process refresh serialization using deterministic ready/go barriers.
- `lib/sigra/app_session/refresh_token.ex` — retained the Plan 03 `FOR UPDATE` lifecycle implementation verified by the new concurrency proof.

## Decisions Made

- Used reserved `session.app_*` action names with one explicit Multi step per lifecycle outcome.
- Kept the public failure shape uniformly `{:error, :app_session_refresh_aborted}` for storage and audit failures, including Ecto constraint exceptions.
- Did not alter the existing lock ordering: the new Task 2 proof passed against the Plan 03 locked classifier, so no speculative production refactor was needed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test bug] Returned the required setup callback value from the co-fate fixture**
- **Found during:** Task 1 RED verification
- **Issue:** The PostgreSQL setup callback ended on a query result rather than `:ok`, invalidating every test before the intended contract executed.
- **Fix:** Explicitly returned `:ok` from the setup callback.
- **Files modified:** `test/sigra/app_session_audit_cofate_test.exs`
- **Verification:** Focused co-fate suite passes.
- **Committed in:** `0b77818f`

**Total deviations:** 1 auto-fixed Rule 1 test fix. No scope expansion.

## Issues Encountered

- Task 2's newly introduced deterministic test passed immediately because Plan 03 already established the required `FOR UPDATE` serialization and Task 1 made audit co-fate consistent. The test-only commit records that evidence; production code was not changed unnecessarily.

## Known Stubs

None.

## User Setup Required

None - `tmp/db.env` supplied the required PostgreSQL test connection.

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_audit_cofate_test.exs --trace` — passed, 4 tests / 0 failures.
- `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session/concurrency_test.exs --trace` — passed, 1 test / 0 failures.
- `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_test.exs test/sigra/app_session_audit_cofate_test.exs test/sigra/app_session/concurrency_test.exs --trace` — passed, 11 tests / 0 failures.
- `mix format --check-formatted lib/sigra/app_session.ex lib/sigra/app_session/refresh_token.ex test/sigra/app_session_audit_cofate_test.exs test/sigra/app_session/concurrency_test.exs` — passed.
- `git diff --check` — passed.

## Next Phase Readiness

Phase 246 can expose the app-session refresh lifecycle knowing rotation, reuse-family revocation, optional audit evidence, and rollback responses have deterministic PostgreSQL proof.

## Self-Check: PASSED

- `lib/sigra/app_session.ex`, `test/sigra/app_session_audit_cofate_test.exs`, and `test/sigra/app_session/concurrency_test.exs` exist.
- Task commits `0b77818f`, `a5d53549`, and `30c36009` exist in git history.
