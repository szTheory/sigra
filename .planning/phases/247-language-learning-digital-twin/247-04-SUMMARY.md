---
phase: 247-language-learning-digital-twin
plan: 04
subsystem: replay-api
tags: [phoenix, ecto, postgresql, csrf, idempotency]
requires:
  - phase: 247-03
    provides: account-bound leases, replay receipt schema, and authenticated lesson route
provides:
  - Current-Scope-authorized terminal replay classification
  - Durable duplicate-safe replay receipts
  - CSRF-protected bounded replay transport with learner-safe responses
affects: [247-06, offline-replay, learning-twin]
tech-stack:
  added: []
  patterns: [transactional idempotency receipt, current-Scope-only ownership, explicit SQL Sandbox barriers]
key-files:
  created: []
  modified:
    - test/example/lib/example/learning_twin.ex
    - test/example/test/example/learning_twin/learning_twin_test.exs
    - test/example/test/example_web/controllers/learning_twin_controller_test.exs
key-decisions:
  - "Replay derives its account partition solely from the active current-Scope lease; request parameters cannot choose an owner."
  - "The existing unique receipt identity is the durable application record for this bounded lesson action."
  - "Public replay responses contain only client mutation correlation, terminal status, and terminal timestamp."
patterns-established:
  - "Replay retries insert once and always reload the stored receipt, including after PostgreSQL unique-key contention."
requirements-completed: [OFF-02]
coverage:
  - id: D1
    description: "Current-Scope replay records mutually exclusive accepted, rejected, and conflict receipts exactly once, including duplicate contention and rollback recovery."
    requirement: OFF-02
    verification:
      - kind: integration
        ref: "cd test/example && mix test test/example/learning_twin/learning_twin_test.exs --trace"
        status: pass
    human_judgment: false
  - id: D2
    description: "The browser replay endpoint enforces its existing cookie/CSRF route boundary and returns a bounded learner-safe terminal response."
    requirement: OFF-02
    verification:
      - kind: integration
        ref: "cd test/example && mix test test/example_web/controllers/learning_twin_controller_test.exs --trace"
        status: pass
    human_judgment: false
metrics:
  duration: 15min
  completed: 2026-08-18
status: complete
---

# Phase 247 Plan 04: Server-authorized replay summary

**Current-Scope replay now stores a single, retry-stable accepted, rejected, or conflict receipt and exposes it only through the authenticated CSRF browser boundary.**

## Performance

- **Duration:** 15 min
- **Tasks:** 2/2
- **Files modified:** 3

## Accomplishments

- Classified bounded lesson answers into durable accepted, rejected, and conflict outcomes after active-lease reauthorization.
- Made sequential and barrier-controlled concurrent duplicates return the original stored receipt, and proved enclosing transaction rollback leaves a retryable identity.
- Restricted POST replay input to scalar bounded fields, rejected owner smuggling, and returned only stable mutation correlation, status, and terminal timestamp.

## Task Commits

1. **Task 1: Persist one terminal accepted, rejected, or conflict receipt** — `503b9394` (RED), `6e543016` (GREEN), `af56f365` (rollback evidence)
2. **Task 2: Enforce replay transport, CSRF, ownership, and response bounds** — `7d7f6a68` (RED), `c16956f1` (GREEN)

## Verification

- `cd test/example && mix test test/example/learning_twin/learning_twin_test.exs --trace` — PASS (9 tests)
- `cd test/example && mix test test/example_web/controllers/learning_twin_controller_test.exs --trace` — PASS (5 tests)

## Decisions Made

- Ownership is derived only from the active lease associated with `current_scope`; `account_partition` is not a replay request input.
- The receipt remains the bounded authoritative record of a completed lesson answer; no Crosswake module is imported or invoked.
- Duplicate responses reuse stored terminal fields instead of recomputing a result or revealing internal authorization data.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The local PostgreSQL test container was not running. Started the repository’s documented ephemeral test database via `scripts/db/up.sh`; focused verification then passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 06 can consume stable replay terminal states for its client/evidence work. No replay transport or persistence blockers remain.

## Self-Check: PASSED

- All three planned source/test files exist.
- All five task commits are present in git history.
