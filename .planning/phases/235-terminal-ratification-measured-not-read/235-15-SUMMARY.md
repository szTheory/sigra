---
phase: 235-terminal-ratification-measured-not-read
plan: 15
subsystem: ci
tags: [github-actions, sigstore, attestation, performance, tdd]

requires:
  - phase: 235-08
    provides: protected terminal measurement, 93-row ownership proof, and the honest FAST-01 miss
provides:
  - independently attested 43-run post-remediation PR population with p50 466 seconds
  - network-denied exact-subject verification with adverse provenance and population checks
  - evidence-driven FAST-01 completion preserving both historical misses and GATE-05
affects: [milestone-closeout, ci-performance, protected-evidence]

actuals:
  tokens: 25000
  tasks: 2
  commits: 5

tech-stack:
  added: []
  patterns: [fixed-path offline attestation verification, strict evidence-driven requirement reconciliation]

key-files:
  created:
    - .planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-GAP-CLOSURE-REMEASUREMENT.json
    - .planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-GAP-CLOSURE-REMEASUREMENT.attestation.jsonl
    - .planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-GAP-CLOSURE-REMEASUREMENT-TRUSTED-ROOT.jsonl
    - scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh
  modified:
    - test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs
    - .planning/REQUIREMENTS.md
    - .planning/todos/pending/2026-08-02-fast-01-terminal-p50-miss.md

key-decisions:
  - "Completed FAST-01 only from the independently recomputed strict 466-second p50 over all 43 fresh protected runs."
  - "Preserved the 772- and 724-second misses plus the 692-to-148-second Library and 724-to-470-second wall remediation as immutable history."
  - "Bound the sole dispatch through its returned run identity, one structured summary, and exact attestation after stale local origin/main prevented the planned set-difference selector from matching."

patterns-established:
  - "Fresh performance evidence uses a fixed remediation cutoff, one protected endpoint, disjoint run identities, all terminal conclusions, and canonical {wall_seconds, run_id} ordering."
  - "Requirement state changes only after offline provenance succeeds and tests independently recompute the population and strict comparator."

requirements-completed: [FAST-01, GATE-05]

coverage:
  - id: D1
    description: "A fresh protected population proves FAST-01 with 43 unique runs and independently recomputed p50 466 seconds."
    requirement: FAST-01
    verification:
      - kind: integration
        ref: "scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh"
        status: pass
      - kind: unit
        ref: "test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs#independently derives canonical population, poles, and strict 719/720/721 verdicts"
        status: pass
    human_judgment: false
  - id: D2
    description: "FAST-01 requirements and the residual now cite the exact cutoff, endpoint, population, p50, producer, subject, and attestation while retaining both misses."
    requirement: FAST-01
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs#strict pass reconciles only FAST-01 and leaves GATE-05 byte-exact"
        status: pass
      - kind: unit
        ref: "test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs#pass closure retains both misses and measured remediation evidence"
        status: pass
    human_judgment: false
  - id: D3
    description: "GATE-05 remains independently Complete with its original protected run and 93-row ownership proof unchanged."
    requirement: GATE-05
    verification:
      - kind: integration
        ref: "scripts/ci/verify-terminal-ratification-attestation-offline.sh"
        status: pass
      - kind: unit
        ref: "test/sigra/planning/phase_235_terminal_ratification_contract_test.exs"
        status: pass
    human_judgment: false

duration: 20 min
completed: 2026-09-08
status: complete
---

# Phase 235 Plan 15: FAST-01 Gap Closure Summary

**A fresh independently attested 43-run protected population records p50 466 seconds, completing FAST-01 without altering GATE-05 or erasing earlier misses.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-09-08T20:00:31Z
- **Completed:** 2026-09-08T20:20:00Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments

- Captured and retained one protected-main population of 43 unique terminal PR runs, disjoint from both historical populations, with canonical p50 466 seconds.
- Added a fixed-path offline verifier that binds the exact subject digest, signer workflow, protected ref, workflow SHA, cutoff, endpoint, bundle, and trust root under network denial.
- Reconciled FAST-01 to Complete from independent recomputation while preserving the 772/724-second misses, measured remediation, and byte-exact GATE-05 requirement records.

## Task Commits

1. **Task 1 readiness:** `196cabe4` (chore)
2. **Task 1 prerequisite diagnostic:** `0814649d` (docs)
3. **Task 1 protected population and verification:** `b5fc9389` (feat)
4. **Task 2 RED reconciliation contract:** `db5511e8` (test)
5. **Task 2 GREEN requirement reconciliation:** `817e3033` (feat)

## Files Created/Modified

- `.planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-GAP-CLOSURE-READINESS.json` - Retains the single non-authoritative readiness probe.
- `.planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-GAP-CLOSURE-REMEASUREMENT.json` - Stores the fresh protected 43-run population and strict verdict.
- `.planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-GAP-CLOSURE-REMEASUREMENT.attestation.jsonl` - Retains exact-subject Sigstore provenance.
- `.planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-GAP-CLOSURE-REMEASUREMENT-TRUSTED-ROOT.jsonl` - Retains contemporaneous trust material.
- `scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh` - Verifies provenance and population contracts without network access.
- `test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs` - Independently recomputes population semantics and requirement reconciliation.
- `.planning/REQUIREMENTS.md` - Marks only FAST-01 Complete with exact fresh evidence; GATE-05 is unchanged.
- `.planning/todos/pending/2026-08-02-fast-01-terminal-p50-miss.md` - Appends the evidence-backed closure without deleting history.

## Decisions Made

- The stored verdict was not trusted directly; the contract independently sorted the full population, selected `floor(n/2)`, and applied strict `<720` semantics.
- The one dispatched run was retained despite local dispatch-correlation failure because the dispatch response, one structured run summary, exact subject bytes, and offline attestation bind the same protected workflow execution.
- Erlang 28.4.1 was selected only through process-local ASDF overrides because the repository-requested 28.5 is not installed; `.tool-versions` was left untouched.

## Deviations from Plan

### Auto-fixed Issues

**1. Blocking local Erlang version mismatch**

- **Found during:** Task 1 prerequisite proof
- **Issue:** Repository Erlang 28.5 was unavailable, so the planned ExUnit command did not start.
- **Fix:** Used installed Erlang 28.4.1 and Elixir 1.19.5-otp-28 through process-local ASDF overrides.
- **Files modified:** None
- **Verification:** Phase 233 contract passed 6 tests; final focused contracts passed 31 tests and the planning suite passed 129 tests with 12 skipped.
- **Committed in:** `b5fc9389` diagnostics and authenticated evidence commit

**2. Dispatch selector could not match stale local origin/main**

- **Found during:** Task 1 protected dispatch
- **Issue:** `/usr/bin/date` was unavailable and local `origin/main` pointed at `10904571`, while the dispatched protected run used `c6580d79`; bounded projections therefore returned no candidate.
- **Fix:** Did not redispatch. Bound the sole returned run `34272746647` through its single structured summary and the exact offline-verified attestation, recording the deviation durably.
- **Files modified:** `.planning/phases/235-terminal-ratification-measured-not-read/235-15-EXECUTION-DIAGNOSTICS.md`
- **Verification:** One watcher concluded success; the downloaded subject digest and attestation certificate bind workflow SHA `c6580d793710aaeef01a1f34d7000ead9ebcdcd2`.
- **Committed in:** `b5fc9389`

---

**Total deviations:** 2 auto-fixed (1 blocking toolchain issue, 1 dispatch-correlation issue)
**Impact on plan:** No extra workflow dispatch, evidence window, threshold, population selection, product scope, or GATE-05 state change occurred.

## Issues Encountered

- The initial prerequisite diagnostic was intentionally retained and amended with the resolution and exact dispatch facts rather than erased.
- Expected errors printed by adverse attestation cases are part of the passing offline verifier contract.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

All Phase 235 plans now have summaries. The phase is ready for drift gates, code review, regression validation, and independent goal verification.

## Self-Check

PASSED: all declared evidence paths exist; RED precedes GREEN; both offline verifiers pass; focused contracts pass 31/31; the planning contract suite passes 129/129 with 12 intentional skips.

---
*Phase: 235-terminal-ratification-measured-not-read*
*Completed: 2026-09-08*
