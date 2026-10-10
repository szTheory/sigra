---
phase: 250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat
plan: 01
subsystem: ci
tags: [github-actions, release-receipts, canary, bash, jq]
requires: []
provides:
  - No-publish canary workflows, exact-run controller, trusted observer path, and isolated receipt contract.
  - Durable, sanitized hosted proof recording the consumed retry's blocked result and its causes.
affects: [phase-248-verification, phase-250-plans-02-and-03, AUTO-02]
actuals:
  tokens: 41280
  tasks: 3
  commits: 11
plan_head_before: d3021c112d9f6188e37578d83e989031491a5b8b
plan_head_after: 4ea0d130d73ed7d375b621aef3c03e5233219d71
commits: 11
tech-stack:
  added: []
  patterns: ["No-publish hosted canary with exact run and artifact identity", "Sanitized failure/cancellation receipt namespaces"]
key-files:
  created:
    - .github/workflows/release-receipt-canary.yml
    - .github/workflows/release-receipt-canary-controller.yml
    - scripts/ci/release-canary.sh
    - scripts/ci/release-canary.test.sh
    - test/sigra/planning/phase_250_canary_contract_test.exs
  modified:
    - .github/workflows/release-run-observer.yml
    - scripts/ci/release-observer.sh
    - scripts/ci/release-receipt.sh
    - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-CANARY-PREFLIGHT.json
    - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-CANARY-PROOF.json
    - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-CANARY-CONTROLLER-PROOF-38059620443.json
key-decisions:
  - "Record the authorized controller retry as blocked after it failed to produce a failure receipt; no additional dispatch is authorized."
  - "Keep AUTO-02 unsatisfied and Phase 248 as its owner; Plan 01 contributes evidence only."
requirements-completed: []
coverage:
  - id: D1
    description: "The no-publish canary, controller, trusted observer, and receipt trust boundaries have local regression coverage."
    verification:
      - kind: unit
        ref: "bash scripts/ci/release-canary.test.sh (32 passed)"
        status: pass
      - kind: unit
        ref: "bash scripts/ci/release-receipt.test.sh (15 passed); bash scripts/ci/release-observer.test.sh (22 passed)"
        status: pass
      - kind: integration
        ref: "actionlint for the three canary/observer workflows; exact-head CI run 38060050307"
        status: pass
    human_judgment: false
  - id: D2
    description: "The hosted proof is durably blocked with exact run identities and the missing receipt cause; it does not claim AUTO-02."
    requirement: AUTO-02
    verification:
      - kind: other
        ref: "jq structural assertions over 250-CANARY-PROOF.json and 250-CANARY-CONTROLLER-PROOF-38059620443.json"
        status: pass
    human_judgment: false
duration: 2h 42m
completed: 2026-10-10
status: complete
---

# Phase 250 Plan 01: Hosted Failure and Cancellation Canary Summary

**The no-publish canary and receipt validator are covered locally and by exact-head CI; the one authorized hosted retry produced no failure receipt, so AUTO-02 remains open.**

## Performance

- **Duration:** 2h 42m
- **Started:** 2026-10-10T12:18:03Z
- **Completed:** 2026-10-10T15:00:00Z
- **Tasks:** 3/3 (Task 3 completed as a truthful blocked-proof report)
- **Files modified:** 20

## Accomplishments

- Completed the canary source, controller, trusted observer extension, shared receipt contract, and negative fixtures. PR #317 merged the scenario-preservation and bounded correlation fixes (source commit `c570e0449`, main merge `6b2bd9e8`); exact-head CI run `38060050307` passed.
- Captured the consumed authorized controller retry, source failure run, and its exact blocker in the canonical proof and controller artifact record. The source controlled-failure step ran, but its receipt builder failed before upload; no cancellation probe or receipt artifact was produced.
- Re-ran local shell contracts, canary self-test, and workflow lint. Kept AUTO-02 unsatisfied and requirement ownership with Phase 248.

## Task Commits

1. **Task 1: Wire one complete dual-outcome canary tracer** — `a068230ee` (`feat`)
2. **Task 2: Lock down canary identity and cancellation boundaries with fixtures** — `8f0de1720` (`test`), `93434c9f9` (`feat`)
3. **Task 3: Capture the exact hosted proof and fail closed** — `4ea0d130d` (`chore`, synced hosted evidence)

The Plan 01 evidence also records follow-up repair commits and protected merges. The summary and its self-check are committed atomically.

## Files Created/Modified

- The two `release-receipt-canary` workflows and `scripts/ci/release-canary.sh` implement the on-demand source and exact-run controller without release publishing authority.
- `scripts/ci/release-receipt.sh` and `scripts/ci/release-observer.sh` preserve distinct canary and production receipt rules.
- `scripts/ci/release-canary.test.sh` and `phase_250_canary_contract_test.exs` cover malformed identities, namespace crossover, correlation, cancellation, and artifact integrity.
- `250-CANARY-PROOF.json` and `250-CANARY-CONTROLLER-PROOF-38059620443.json` record the hosted attempt and its blocked outcome.

## Decisions Made

- The single authorized retry is consumed by controller run `38059620443`; no additional workflow dispatch, source dispatch, controller run, or cancellation is authorized by this closeout.
- The failure run `38059634695` is evidence of the controlled-failure step only. Its receipt builder error and absent artifact mean it cannot satisfy AUTO-02.
- Phase 248 retains AUTO-02 ownership. Plan 01 records evidence only and sets `requirements-completed: []`.

## Deviations from Plan

Task 3 completed with the plan's explicitly allowed truthful blocked-proof outcome. The controller's one-shot exact-title lookup raced source-run visibility, then run `38059634695` reached the controlled failure but the receipt builder reported `source failure receipt requires the failure scenario`; zero artifacts were uploaded and no cancellation probe was dispatched. The controller proof is blocked, and the canonical proof preserves that cause. Repairs merged afterward and exact-head CI passed, but hosted receipt proof still requires a new explicit authorization. No retry was made.

## Verification

- Passed: `bash scripts/ci/release-canary.sh --self-test`.
- Passed: `bash scripts/ci/release-receipt.test.sh` (15), `bash scripts/ci/release-observer.test.sh` (22), and `bash scripts/ci/release-canary.test.sh` (32).
- Passed: `actionlint` on the canary source, controller, and trusted observer workflows.
- Passed: exact-head GitHub CI run `38060050307` after PR #317 merged.
- Passed: JSON parse and structural assertions confirm both proof records are blocked, identify the expected controller/source run IDs, and record `credential_values_recorded: false`.
- Could not run locally: `mix test test/sigra/planning/phase_250_canary_contract_test.exs` stopped before test execution because the checked-out Phoenix dependency does not match `mix.lock`; `mix deps.get` would be required. Exact-head CI run `38060050307` passed.
- Expected rejection: `release-canary.sh --validate-proof 250-CANARY-PROOF.json` rejects the proof because it is blocked. This is the correct result; it does not turn the hosted attempt into a pass.

## Issues Encountered

The hosted failure receipt builder lost the workflow-provided scenario value, while immediate exact-title lookup exposed an eventual-consistency race. Both were repaired in PR #317 and covered by local tests; hosted outcomes remain unproven because the authorized retry is consumed. The local ExUnit invocation was unavailable due to the existing Phoenix lock mismatch.

## Next Phase Readiness

Plan 01 is complete as an evidence/reporting task. Plans 02 and 03 can proceed with the blocked proof as input. Phase 250 implementation and verification remain incomplete; AUTO-02 remains unsatisfied. Any further controller dispatch requires fresh explicit user authorization.

---
*Phase: 250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat*
*Completed: 2026-10-10*

## Self-Check: PASSED

- Summary file exists and coverage classification reports no errors.
- Task commits `a068230ee`, `8f0de1720`, `93434c9f9`, and evidence sync `4ea0d130d` are ancestors of the checked-out commit.
- Both hosted proof JSON files parse and retain `status: blocked` with `credential_values_recorded: false`.
- The plan commit ledger measures 11 commits from `d3021c112d9f6188e37578d83e989031491a5b8b` through `4ea0d130d73ed7d375b621aef3c03e5233219d71`.
