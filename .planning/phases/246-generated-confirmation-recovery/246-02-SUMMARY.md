---
phase: 246-generated-confirmation-recovery
plan: 02
subsystem: auth
tags: [elixir, phoenix-liveview, confirmation, ecto, accessibility]
requires:
  - phase: 246-01
    provides: Optional-scope confirmation routes, explicit link submission, shared feedback region, and account-scoped verifier entry point.
provides:
  - Exact email-spaced confirmation-code entry with ASCII-only validation and account-scoped, validity-filtered lookup.
  - Visible localized success and invalid-code feedback with retryable confirmation form state.
  - Generated-host persistence probes for cross-account rejection, malformed input, spaced-code success, and token cleanup.
affects: [246-03, generated-auth, confirmation-codes]
actuals:
  tokens: 4066
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns:
    - Generated confirmation lookup prefers the schema's scoped query and falls back to a user-scoped 48-hour query.
    - Confirmation form changes update state only; explicit submit strips literal U+0020 spaces and validates six ASCII digits.
key-files:
  created: []
  modified:
    - lib/sigra/auth.ex
    - priv/templates/sigra.install/core/confirmation_live.ex
    - scripts/ci/generated-confirmation-probe.exs
    - test/sigra/auth_test.exs
    - test/sigra/install/generator_email_test.exs
    - test/sigra/install/auth_ui_contract_test.exs
key-decisions:
  - "Use the generated UserToken scoped query when available; preserve generic schema callers with a user_id and 48-hour validity fallback."
  - "Keep malformed input out of both token lookup and the per-account attempt counter; preserve the entered value for retry."
patterns-established:
  - "Rendered confirmation feedback uses the shared auth page's status and alert regions without moving focus."
requirements-completed: [CONF-02, CONF-03]
coverage:
  - id: D1
    description: "The displayed spaced code verifies only for its signed-in owner; malformed input and another account's code leave persisted accounts unchanged."
    requirement: CONF-02
    verification:
      - kind: unit
        ref: "test/sigra/auth_test.exs#verify_confirmation_code/3 account-scoped lookup"
        status: pass
      - kind: integration
        ref: "TMP_APP_DIR=/tmp/sigra_246_02_red bash scripts/ci/install-smoke.sh — generated confirmation probe"
        status: pass
    human_judgment: false
  - id: D2
    description: "Confirmation success and validation errors are localized, visible live-region messages, and an invalid attempt can be retried."
    requirement: CONF-03
    verification:
      - kind: unit
        ref: "test/sigra/install/generator_email_test.exs and test/sigra/install/auth_ui_contract_test.exs"
        status: pass
      - kind: integration
        ref: "TMP_APP_DIR=/tmp/sigra_246_02_red bash scripts/ci/install-smoke.sh — generated confirmation probe"
        status: pass
    human_judgment: false
duration: 28min
completed: 2026-10-06
status: complete
plan_head_before: 5ea8b12795d0f1eb87947969f726b7974935daec
plan_head_after: 0278d9162d364c0cccb2f668864c076f72207832
commits: 3
---

# Phase 246 Plan 02: Generated Confirmation Recovery Summary

**Generated confirmation accepts the email's spaced code only for the current account and announces visible success or retryable validation feedback.**

## Performance

- **Duration:** 28 minutes
- **Started:** 2026-10-06T13:40:00-04:00
- **Completed:** 2026-10-06T14:07:29-04:00
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Confirmation submission removes only literal ASCII spaces and requires exactly six ASCII digits before calling the verifier. Form changes update state without confirming.
- Confirmation-code lookup uses the generated schema's user-scoped 48-hour query when available, with a scoped 48-hour fallback for generic token schemas. The atomic confirmation and credential cleanup transaction remains intact, and the rate-limit key remains per user.
- The shared auth page renders localized success and error live regions on the confirmation screen; the entered value remains available after an invalid attempt, and the owner can retry successfully.
- Fresh-host coverage proves account A's code cannot change either account while B is signed in, malformed whitespace/digits are rejected, and successful owner submission sets persisted state and consumes confirmation tokens.

## Task Commits

1. **Task 1 RED: Prove account-bound spaced-code behavior** - `1d6d818f` (`test`)
2. **Task 1 GREEN: Accept scoped spaced confirmation codes** - `978c84f5` (`feat`)
3. **Task 2: Assert accessible feedback and retry behavior** - `0278d916` (`test`)

**Plan metadata:** `7903d8a9` (summary), `fc6eccde` (state and roadmap).

## Files Created/Modified

- `lib/sigra/auth.ex` - Uses the generated scoped query or a 48-hour user-scoped fallback before transaction mutation.
- `priv/templates/sigra.install/core/confirmation_live.ex` - Removes browser truncation/native pattern validation, validates on explicit submit, and retains visible result state for retries.
- `scripts/ci/generated-confirmation-probe.exs` - Checks wrong-account persistence, change-only behavior, malformed input, spaced-code retry, rendered feedback, and credential cleanup.
- `test/sigra/auth_test.exs` - Covers the scoped fallback, mismatch without transaction, and per-account rate limiting.
- `test/sigra/install/generator_email_test.exs` and `test/sigra/install/auth_ui_contract_test.exs` - Lock the full-length explicit-submit and accessible feedback contracts.

## Decisions Made

- Reused `UserToken.verify_confirmation_code_query/2` for generated hosts so its hash, context, account, and 48-hour validity predicates stay authoritative.
- Kept malformed submissions out of the verifier and rate limiter, while preserving form content for the user to correct and retry.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test contract] Updated verifier mocks to match the account-scoped lookup already added in Plan 246-01**
- **Found during:** Task 1
- **Issue:** Two existing mock expectations still described the old lookup without `user_id`, so the focused library suite failed before exercising its assertions.
- **Fix:** Updated those expectations and changed the test token schema to a queryable Ecto schema for exercising the 48-hour fallback query.
- **Files modified:** `test/sigra/auth_test.exs`
- **Verification:** `mix test test/sigra/auth_test.exs` passed with 71 tests.
- **Committed in:** `978c84f5`

**2. [Task overlap] Kept the confirmation status transition with the shared submit-handler implementation**
- **Found during:** Task 1
- **Issue:** Task 1 and Task 2 both modify the same `do_confirm/2` branch; separately committing the success transition and parser would split one state change across task commits.
- **Fix:** Included the success/error screen state in the Task 1 implementation commit; Task 2 added focused contracts and retry evidence without a further source change.
- **Files modified:** `priv/templates/sigra.install/core/confirmation_live.ex`
- **Verification:** Generator/UI contracts passed (47 tests), and the final fresh-host install smoke passed all 8 generated-host tests.
- **Committed in:** `978c84f5`

**Total deviations:** 2 (1 existing test-contract correction, 1 shared-file task-boundary adjustment)
**Impact on plan:** Scope stayed within the planned files and acceptance criteria; Plan 246-01's account-scoping implementation was preserved and extended with validity filtering.

## TDD Gate Compliance

- **Task 1 RED:** The generated-host probe failed at the planned assertion: the owner could not submit the exact spaced code, while the mismatched-account case left both records unchanged. Commit: `1d6d818f`.
- **Task 1 GREEN:** The verifier and LiveView changes accepted the spaced owner code and the fresh-host probe passed. Commit: `978c84f5`.
- **Task 2:** The visible result behavior shared the Task 1 handler change; newly added template and retry contracts passed against that implementation. Commit: `0278d916`.
- Project `tdd_mode` was false; task-level RED/GREEN work was applied without a phase-level TDD gate.

## Issues Encountered

- The first generated-host probe used `Plug.Conn.init_test_session/2`, which is not public in the pinned Plug version. It was corrected to `Phoenix.ConnTest.init_test_session/2`; the subsequent fresh-host runs reached the intended code assertions.
- The signed-in cross-account test creates its session token directly for an unconfirmed visitor so the generated confirmed-login policy does not bypass the account-boundary check.
- D-06 remains a documented residual boundary: anonymous email-link confirmation does not prevent account pre-hijacking. This plan does not change or claim to resolve that contract.

## User Setup Required

None.

## Next Phase Readiness

Plan 02 is complete and ready for Plan 246-03's generated-host browser and CI evidence work. Phase 246 remains in progress; the shared CONF-01/02/03 requirements stay pending until Plan 03 completes.

---
*Phase: 246-generated-confirmation-recovery*
*Completed: 2026-10-06*

## Self-Check: PASSED

- All six modified implementation/test files exist.
- Task commits `1d6d818f`, `978c84f5`, and `0278d916` are ancestors of the recorded plan head.
- Summary commit `7903d8a9` and state/roadmap commit `fc6eccde` are present.
- Focused library tests passed: 71 tests, 0 failures.
- Focused generator/UI contract tests passed: 47 tests, 0 failures.
- Fresh-host install smoke passed: 8 generated-host tests, 0 failures.
- Stub scan found no new incomplete implementation placeholders.
- Threat-surface scan found no new endpoint or trust boundary; the existing verifier and current-scope account boundary were tightened.
