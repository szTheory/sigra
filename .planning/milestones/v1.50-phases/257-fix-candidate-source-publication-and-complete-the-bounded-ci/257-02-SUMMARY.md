---
phase: 257-fix-candidate-source-publication-and-complete-the-bounded-ci
plan: "02"
subsystem: ci
tags: [ci, authorization, source-proof, proposal]
requires:
  - phase: 257 Plan01
    provides: Reviewed publisher, preparation controls, and final local implementation
provides:
  - Exact source-bound Phase257 preparation proposal, contract, registrations, standing authorization, and unused one-use claim
  - Independent persisted readback proving the fixed caps and zero hosted spend
affects: [257-03, CISPEED-01, CISPEED-02]
actuals:
  tokens: null
  tasks: 2
  commits: 0
tech-stack:
  added: []
  patterns:
    - Validate a Phase256 adoption wrapper with its own reader, then validate its hash-bound Gen17 source record
    - Apply Phase257's exact one-candidate preparation rule while retaining the legacy four-entry validator elsewhere
key-files:
  created:
    - .planning/execution/257/PREP-CONTRACT.json
    - .planning/execution/257/PREP-PROPOSAL.json
    - .planning/execution/257/PREP-REGISTRATIONS.json
    - .planning/execution/257/PREP-AUTHORIZATION.json
    - .planning/execution/257/PREPARE-INVOCATION-CLAIM.json
    - .planning/debug/phase257-local/PLAN01-POSTFIX-REVIEW-02.json
    - .planning/phases/257-fix-candidate-source-publication-and-complete-the-bounded-ci/257-02-SUMMARY.md
  modified:
    - scripts/ci/ci-repaired-comparison.py
    - scripts/ci/ci-repaired-comparison.test.py
key-decisions:
  - "Keep Phase255.1 and Phase256 control records unchanged; validate each versioned wrapper at its own boundary."
  - "Keep the claim prepared but unconsumed until the single Plan03 wrapper invocation."
  - "The 11 Phase256 requests remain charged; proposal generation creates no new hosted spend or performance samples."
patterns-established:
  - "When a phase-specific wrapper contains a versioned inner record, validate both layers and compare their bound identities rather than passing the wrapper to the inner-schema validator."
  - "Use the Phase257-aware one-candidate contract validation in both proposal construction and persisted verification; leave the legacy validator intact."
requirements-completed: []
coverage: [CISPEED-01, CISPEED-02]
duration: "not recorded"
completed: 2026-11-05
status: complete
---

# Phase 257 Plan 02: Freeze the bounded preparation proposal

**The exact Phase257 proposal and unused preparation claim are frozen and independently verified with zero hosted spend.**

## Accomplishments

- Wrote the five canonical Phase257 files: contract, proposal, registrations, standing authorization, and prepared one-use claim.
- Bound the proposal to the reviewed implementation, Phase257 plan and scope, source proof, object closure, standing authorization, and immutable Phase256 history.
- Added a shared Phase257 adapter that validates the Phase256 control-adoption wrapper and captured run, PR, merge, artifact, and job records, then validates the hash-bound Gen17 adoption and compares identities.
- Corrected proposal construction to use the same exact one-candidate validation as persisted contract verification, while retaining all other finite-policy checks.
- Recorded both deterministic local failures and their fixes in the append-only post-fix review; neither failure wrote canonical output or spent hosted authority.

## Verification and limits

- `Phase257ScopeTests`: 22 passed under a 60-second timeout.
- Python byte compilation passed.
- The retained Phase256 control record and captures validated: PR367, 26 artifacts, 27 jobs, zero requests, mutations, workloads, or samples.
- Independent `phase257-verify-local` returned `ready_for_consent`; the claim is `prepared_unconsumed`. It verified proposal SHA `0ea3fb4b922765077bf0ffef14b7cfc538defab93454cf24378cc973507ceef9`, contract SHA `4d0b7eb06876703b9acefdb38029836354a536c5cd598e219514cb37504d4e1b`, all recorded limits, and the 11-request predecessor charge.
- No GitHub request, Git network operation, cache operation, workflow, merge, release, or performance sample occurred. Phase255.1 and Phase256 history remain unchanged. CISPEED-01/02 remain open.

## Next readiness

Plan03 is the only next ready plan. It may consume this one-use claim for one source-bound candidate preparation under the recorded 503-new-request, one-ref-update, one-workload, 280 runner-minute, 45-minute first-request, and 2,700-second outer-timeout limits. It permits no retry, renewal, merge, or release.

---
*Phase: 257*
*Completed: 2026-11-05*
