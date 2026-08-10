---
phase: 239-hosted-session-interop
plan: "05"
subsystem: hosted-session-interop
tags: [crosswake, sigra, auth-return, callback, evidence, authority, security]
requires:
  - phase: 239-hosted-session-interop
    provides: "Fresh host session resolution plus opaque expected-binding and account-switch denial"
provides:
  - "Released AuthReturn envelope validation before every hosted-return evaluation"
  - "Evidence-only hosted-return result handling that cannot select or replace SIGRA authority"
  - "Published B2C recipe aligned with crosswake_sigra ~> 0.1.3 and executable adapter proof"
affects: [239-06, crosswake-consumption, b2c-alpha]
tech-stack:
  added: []
  patterns: ["Validate callback input through the public companion constructor, then independently resolve current host authority", "Return approved navigation evidence in a separate result field only"]
key-files:
  created: [.planning/phases/239-hosted-session-interop/239-05-SUMMARY.md]
  modified:
    - test/example/lib/example/accounts/crosswake_session_adapter.ex
    - test/example/test/example/accounts/crosswake_session_adapter_test.exs
    - guides/recipes/b2c-alpha.md
key-decisions:
  - "Hosted-return input enters the host only through AuthReturn.new_envelope/1 and is rejected before any evaluator call when invalid."
  - "Approved envelopes are returned as result.evidence after the unchanged host resolution, binding, projection, and evaluator path."
  - "The B2C recipe consumes only the proof-validated crosswake_sigra ~> 0.1.3 range."
patterns-established:
  - "Evidence validity is never authority validity: fresh canonical session/user resolution and expected-binding comparison remain mandatory."
requirements-completed: [XW-01, XW-02]
coverage:
  - id: D1
    description: "Hosted-return evidence is parsed through the released public AuthReturn constructor and cannot admit missing, expired, revoked, or switched host state."
    requirement: XW-02
    verification:
      - kind: integration
        ref: "cd test/example && mix test test/example/accounts/crosswake_session_adapter_test.exs --only crosswake_return_evidence"
        status: pass
    human_judgment: false
  - id: D2
    description: "Authority and credential smuggling fields are rejected and approved evidence stays separate from binding, evaluator options, and route result."
    requirement: XW-01
    verification:
      - kind: integration
        ref: "test/example/test/example/accounts/crosswake_session_adapter_test.exs#released AuthReturn rejects every authority or credential smuggling field"
        status: pass
    human_judgment: false
  - id: D3
    description: "The B2C recipe names the proof-validated dependency range and links the complete deterministic host adapter suite."
    requirement: XW-01
    verification:
      - kind: integration
        ref: "cd test/example && mix test test/example/accounts/crosswake_session_adapter_test.exs"
        status: pass
    human_judgment: false
duration: 6min
completed: 2026-08-10
status: complete
---

# Phase 239 Plan 05: Hosted Return Evidence Boundary Summary

**Hosted-return data now travels only as validated AuthReturn evidence while fresh, bound SIGRA session state remains the sole Crosswake authority source.**

## Performance

- **Duration:** 6min
- **Started:** 2026-08-10T00:36:00Z
- **Completed:** 2026-08-10T00:42:18Z
- **Tasks:** 2 completed
- **Files modified:** 3

## Accomplishments

- Added `evaluate_return/5-6`, which validates input solely through released `AuthReturn.new_envelope/1`, then follows the existing fresh host lookup, currentness, binding, projection, and evaluator order.
- Added deterministic matrix coverage that denies valid evidence with no, expired, revoked, or switched host state before evaluation and rejects all listed authority/credential-smuggling fields through the public constructor.
- Updated the B2C recipe with exact `crosswake_sigra ~> 0.1.3` consumption, personal `org_id: nil`, opaque server-owned bindings, replay re-resolution, and the full executable adapter command.

## Task Commits

1. **Task 1: Keep hosted-return data evidence-only under replay** - `44f15b73` (test), `189c14ef` (test), `eb4f4a41` (feat)
2. **Task 2: Align the B2C interop recipe with the released contract** - `b1e7bc19` (docs)

## Files Created/Modified

- `test/example/lib/example/accounts/crosswake_session_adapter.ex` - validates return envelopes without allowing them to alter host authority.
- `test/example/test/example/accounts/crosswake_session_adapter_test.exs` - executable return-evidence, smuggling, host-state, and recipe contract matrix.
- `guides/recipes/b2c-alpha.md` - released B2C Crosswake consumption and fail-closed hosted-return instructions.

## Decisions Made

- Evidence validation precedes host resolution, but a valid envelope alone cannot call the evaluator or select any authority.
- The approved public envelope is preserved only in `result.evidence`; no envelope field is forwarded to the lane, context, evaluator options, expected binding, or route decision.
- Unknown `stored_digest` claims are rejected by the released constructor as unsupported; named session, subject, org, authority, grant, token, provider, and OAuth claims are rejected by its forbidden-field policy.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test bug] Used a predicate assertion for the per-field public-constructor error matrix.**
- **Found during:** Task 1 RED test compilation.
- **Issue:** The original assertion attempted to pin a loop variable inside an `in` expression, which Elixir does not allow.
- **Fix:** Matched the corresponding error with `Enum.any?/2`, preserving exact field and released rejection-class checks.
- **Files modified:** `test/example/test/example/accounts/crosswake_session_adapter_test.exs`
- **Verification:** Focused return-evidence suite passes.
- **Committed in:** `44f15b73`

**Total deviations:** 1 auto-fixed (1 Rule 1).
**Impact on plan:** Test syntax correction only; the required public-constructor rejection matrix remains intact.

## Issues Encountered

None beyond the corrected RED-test assertion syntax.

## Known Stubs

None.

## User Setup Required

None - deterministic example-host tests use the repository-provided local database environment.

## Next Phase Readiness

- Plan 06 can mechanically compare the recipe requirement with the immutable release receipt and rely on the complete adapter suite for the evidence-only authority contract.

## Self-Check: PASSED

- Confirmed the adapter, its deterministic test suite, B2C recipe, and this summary exist.
- Confirmed task commits `44f15b73`, `189c14ef`, `eb4f4a41`, and `b1e7bc19` exist in Git history.

---
*Phase: 239-hosted-session-interop*
*Completed: 2026-08-10*
