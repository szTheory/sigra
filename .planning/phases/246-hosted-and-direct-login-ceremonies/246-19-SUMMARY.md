---
phase: 246-hosted-and-direct-login-ceremonies
plan: 19
subsystem: auth
tags: [elixir, ecto, postgresql, hosted-login, cancellation, concurrency]
requires:
  - phase: 246-17
    provides: signed hosted continuations and generated explicit approve/cancel routes
provides:
  - Durable terminal hosted-cancellation decisions keyed by the existing approval nonce digest
  - Generated `:hosted_cancel` attempt-schema parity and post-commit controller ordering proof
  - Barrier-controlled approve-versus-cancel PostgreSQL serialization coverage
affects: [hosted-login, app-sessions, generated-app-sessions, replay-protection]
tech-stack:
  added: []
  patterns: [shared Ecto.Multi decision claim, nonce-digest unique arbitration, barrier concurrency invariants]
key-files:
  created: []
  modified:
    - lib/sigra/app_login.ex
    - test/support/app_login_schemas.ex
    - test/sigra/app_login_test.exs
    - test/sigra/app_login/concurrency_test.exs
    - priv/templates/sigra.install/app_sessions/user_app_login_attempt.ex
    - test/sigra/install/app_sessions_generator_test.exs
    - test/sigra/install/app_sessions_routes_test.exs
key-decisions:
  - "Approve and cancel contend on the same nonce-derived approval_digest; the cancel row digest remains domain-separated storage identity only."
  - "Cancellation is terminal at commit time and clears the generated browser continuation only after its durable claim succeeds."
patterns-established:
  - "Hosted terminal decisions share continuation validation and one Ecto.Multi insert constrained by approval_digest."
requirements-completed: [APP-02]
coverage:
  - id: D1
    description: "Copied hosted continuations cannot mint a code after a committed cancellation, including cancellation rollback recovery."
    requirement: APP-02
    verification:
      - kind: integration
        ref: "test/sigra/app_login_test.exs#cancelling one copied continuation terminally rejects the retained copy"
        status: pass
      - kind: integration
        ref: "test/sigra/app_login_test.exs#failed hosted cancellation persistence leaves its continuation retryable"
        status: pass
    human_judgment: false
  - id: D2
    description: "Generated attempt schemas and controller transport preserve terminal cancellation and post-commit local-session consumption."
    requirement: APP-02
    verification:
      - kind: unit
        ref: "test/sigra/install/app_sessions_generator_test.exs"
        status: pass
      - kind: unit
        ref: "test/sigra/install/app_sessions_routes_test.exs"
        status: pass
    human_judgment: false
  - id: D3
    description: "Concurrent hosted approve and cancel operations produce exactly one persisted terminal decision."
    requirement: APP-02
    verification:
      - kind: integration
        ref: "test/sigra/app_login/concurrency_test.exs#barrier-released approval and cancellation claim one signed continuation"
        status: pass
    human_judgment: false
metrics:
  duration: 18m
  completed: 2026-08-16
status: complete
---

# Phase 246 Plan 19: Durable Hosted Cancellation Summary

Hosted cancellation now atomically claims the signed continuation nonce, making copied continuations permanently unable to mint an authorization code.

## Performance

- **Duration:** 18 min
- **Completed:** 2026-08-16T21:07:03Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Unified approval and cancellation behind validated, transactional hosted-decision creation using the existing unique `approval_digest` arbiter.
- Persisted terminal `:hosted_cancel` rows with a separate domain-prefixed row digest, no code material, and terminal lifecycle timestamps.
- Added copied-continuation, cancellation rollback, generated-controller ordering, and repeated barrier race evidence without sleeps or application-selected winners.

## Task Commits

1. **Task 1: Cancel one copied continuation into a durable terminal decision** - `2b1c3fec` (RED), `28186af6` (GREEN), `9e584f07` (rollback regression)
2. **Task 2: Propagate terminal cancellation through generated storage and concurrent controller decisions** - `1ed2d090` (RED), `79b4fc97` (GREEN), `28288826` (formatting)

## Files Created/Modified

- `lib/sigra/app_login.ex` - validates and persists either hosted terminal decision in one transaction.
- `test/support/app_login_schemas.ex` - recognizes the persisted `:hosted_cancel` discriminator.
- `test/sigra/app_login_test.exs` - proves copied-handle terminality and rollback-safe cancellation.
- `test/sigra/app_login/concurrency_test.exs` - proves approve/cancel serialization with ready/go barriers.
- `priv/templates/sigra.install/app_sessions/user_app_login_attempt.ex` - emits generated enum parity without migration changes.
- `test/sigra/install/app_sessions_generator_test.exs` and `test/sigra/install/app_sessions_routes_test.exs` - pin generated storage and post-commit controller transport.

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login_test.exs test/sigra/app_login_audit_cofate_test.exs --trace` — passed (13 tests).
- `source tmp/db.env && MIX_ENV=test mix test test/sigra/install/app_sessions_generator_test.exs test/sigra/install/app_sessions_routes_test.exs test/sigra/app_login/concurrency_test.exs --trace` — passed (18 tests).
- `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login/concurrency_test.exs:224 --repeat-until-failure 8 --trace` — passed (8 runs).
- Focused formatter check and `git diff --check` — passed.

## Decisions Made

- Approval and cancellation use only the shared nonce-derived `approval_digest` to arbitrate the terminal decision; `Token.hash_token("hosted_cancel:" <> nonce)` is distinct row storage identity.
- The generated controller keeps its separate CSRF-protected cancel POST and consumes its local continuation only after the facade confirms durable cancellation.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 1 - Test bug] Scoped the controller-order assertion to `cancel/2`**
   - **Found during:** Task 2
   - **Issue:** The first global continuation-consumption match was from `approve/2`, not `cancel/2`.
   - **Fix:** Compared durable service success and `AppLoginContinuation.take/1` within the rendered cancellation function.
   - **Files modified:** `test/sigra/install/app_sessions_routes_test.exs`
   - **Verification:** Generated route suite passed.
   - **Committed in:** `79b4fc97`

**Total deviations:** 1 auto-fixed (Rule 1 test bug). No scope expansion.

## Known Stubs

None.

## Self-Check: PASSED

- Verified all seven modified implementation, template, schema, and regression files exist.
- Verified task commits `2b1c3fec`, `28186af6`, `1ed2d090`, `79b4fc97`, `28288826`, and `9e584f07` exist in git history.

## Next Phase Readiness

APP-02 terminal cancellation is fully covered with deterministic PostgreSQL and generated-source evidence; no external setup or manual verification is required.
