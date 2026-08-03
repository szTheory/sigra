---
phase: 235-terminal-ratification-measured-not-read
plan: 11
subsystem: testing
tags: [mix-ci, github-actions, evidence, fast-01, gate-05]
requires:
  - phase: 235-10
    provides: "Immutable 13-run FAST-01 miss and terminal attestation baseline"
provides:
  - "Exact-once ordinary/scaffold mix ci execution preserved by the remediation merge"
  - "Source-bound PR #195 remediation receipt and protected-main population cutoff"
affects: [235-12, 235-13, fast-01-measurement]
tech-stack:
  added: []
  patterns:
    - "Separate evidence-only PR CI from the immutable remediation measurement PR"
    - "Bind future population cutoffs to protected merge identity, not favorable timing"
key-files:
  created:
    - ".planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-REMEDIATION.json"
  modified:
    - "mix.exs"
    - "test/sigra/planning/phase_233_library_economics_contract_test.exs"
key-decisions:
  - "PR #195 run 30854850199 is the sole remediation measurement; PR #196 only stores and verifies that receipt."
  - "The next FAST-01 population begins strictly after protected-main remediation merge 54c33e904155a454255952666711c882afdd06e4."
patterns-established:
  - "Receipt contracts retain immutable predecessor evidence and fail closed on altered identity, timing, digest, or cutoff fields."
requirements-completed: []
coverage:
  - id: D1
    description: "Protected exact-once Library tests remediation is retained with its source-bound receipt and cutoff."
    requirement: GATE-05
    verification:
      - kind: integration
        ref: "PR #196 CI run 30856451464; Library tests shard and Library tests aggregate"
        status: pass
      - kind: unit
        ref: "test/sigra/planning/phase_233_library_economics_contract_test.exs"
        status: pass
    human_judgment: false
  - id: D2
    description: "The strict FAST-01 residual remains open pending a new independent population of at least ten PR runs."
    requirement: FAST-01
    verification:
      - kind: other
        ref: "235-FAST-01-REMEDIATION.json immutable_prior_receipt"
        status: pass
    human_judgment: false
duration: 42min
completed: 2026-08-03
status: complete
---

# Phase 235 Plan 11: Exact-once remediation receipt Summary

**Protected exact-once `mix ci` remediation with a retry-free PR #195 timing receipt and a merge-identity cutoff for the next FAST-01 population.**

## Performance

- **Duration:** 42 min
- **Started:** 2026-08-03T21:19:50Z
- **Completed:** 2026-08-03T21:59:57Z
- **Tasks:** 2/2
- **Files modified:** 5

## Accomplishments

- Kept the seven-leg `mix ci` interface while running ordinary and canonical scaffold suites exactly once.
- Recorded PR #195 run `30854850199` as the sole retry-free remediation measurement: Library tests shard 148s, contributor step 108s, and wall 470s.
- Merged evidence-only PR #196 through protected CI at `50b8ce955be1f4fbe4868254cc40afe672134f1d`; it is explicitly not timing evidence.
- Froze protected-main remediation merge `54c33e904155a454255952666711c882afdd06e4` at `2026-08-03T21:37:08Z` as the Plan 12 lower cutoff; FAST-01 remains open.

## Task Commits

1. **Task 1: Trace every scaffold test through one exact-once mix ci execution** - `6a50eb7f` (feat)
2. **Task 2: Prove the remediation on a retry-free PR and freeze its protected-main cutoff** - `50b8ce95` (protected squash merge; source commit `684836f8` formats the receipt contract)

## Files Created/Modified

- `mix.exs` - excludes scaffold tests from the broad leg and routes the canonical six modules through `ci.install_golden`.
- `CONTRIBUTING.md` - documents exact-once ordinary/scaffold ownership.
- `test/sigra/planning/phase_198_contributor_dx_contract_test.exs` - protects the seven-leg direct invocation contract.
- `test/sigra/planning/phase_233_library_economics_contract_test.exs` - validates universe ownership and the closed remediation receipt.
- `.planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-REMEDIATION.json` - persists source observations, immutable prior miss, and cutoff.

## Decisions Made

- PR #196 was repaired and merged only to persist evidence; its CI was never used as a remediation timing sample.
- The cutoff is the protected remediation merge identity, not any CI completion time or favorable window.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Formatted the remediation receipt contract**
- **Found during:** Task 2
- **Issue:** PR #196 CI rejected the new ExUnit contract under `mix format --check-formatted`.
- **Fix:** Applied the project formatter and pushed the normal formatting-only commit `684836f8`; its replacement evidence-only run `30856451464` passed the Library tests shard and aggregate before auto-merge.
- **Files modified:** `test/sigra/planning/phase_233_library_economics_contract_test.exs`
- **Verification:** focused ExUnit tests, formatting check, and protected PR CI passed.

**Total deviations:** 1 auto-fixed (Rule 1).

## Issues Encountered

The initial evidence-only PR run `30855678496` failed before tests because the receipt contract was unformatted. It was replaced by the successful non-measurement run `30856451464`; no remediation measurement was retried or replaced.

## Next Phase Readiness

Plan 12 may collect a fresh independent post-cutoff population. FAST-01 remains an explicit strict miss until at least ten qualifying runs yield p50 below 720 seconds.

## Self-Check: PASSED

- Task commits `6a50eb7f`, `684836f8`, and protected merge `50b8ce95` exist.
- The merged receipt validates PR #195/run `30854850199` and cutoff `54c33e9`.
- Focused receipt/terminal contracts, formatting, and the offline attestation verifier passed.
