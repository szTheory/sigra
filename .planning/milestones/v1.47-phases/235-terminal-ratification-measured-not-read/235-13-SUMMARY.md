---
phase: 235
plan: 13
subsystem: ci-evidence
tags: [fast-01, protected-main, attestation, offline-verification, gate-05]
requires: [235-12]
provides: [FAST-01 strict protected pass reconciliation]
affects: [REQUIREMENTS.md, terminal ratification]
tech-stack:
  added: []
  patterns: [offline attestation verification, independent median recomputation, immutable historical receipts]
key-files:
  created: []
  modified:
    - test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs
    - .planning/REQUIREMENTS.md
    - .planning/todos/pending/2026-08-02-fast-01-terminal-p50-miss.md
decisions:
  - FAST-01 closes only from the independently recomputed protected-main n=15 p50=486s receipt.
  - GATE-05 remains independently complete on protected run 30782184713 and its 93-row proof.
metrics:
  duration: 8m
  completed: 2026-08-04
status: complete
coverage:
  - id: D1
    description: FAST-01 strict protected evidence reconciliation
    requirement: FAST-01
    verification:
      - kind: integration
        ref: bash scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh
        status: pass
      - kind: unit
        ref: test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs
        status: pass
    human_judgment: false
  - id: D2
    description: GATE-05 protected ownership-proof non-regression
    requirement: GATE-05
    verification:
      - kind: integration
        ref: bash scripts/ci/verify-terminal-ratification-attestation-offline.sh
        status: pass
      - kind: unit
        ref: test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
        status: pass
    human_judgment: false
---

# Phase 235 Plan 13: Protected FAST-01 Reconciliation Summary

**FAST-01 closes from one independently attested protected-main population of 15 terminal PR runs at a strict 486-second p50, while GATE-05's 93-row ownership proof remains unchanged.**

## Performance

- **Duration:** 8m
- **Started:** 2026-08-04T00:21:36Z
- **Completed:** 2026-08-04T00:29:42Z
- **Tasks:** 2 completed (Task 1 resumed as committed 1a/1b; Task 2 completed here)
- **Files modified:** 7 tracked task artifacts across the plan, plus this summary

## Accomplishments

- Retained and offline-verified the sole qualifying protected receipt: cutoff `2026-08-03T21:37:08Z`, endpoint `2026-08-04T00:19:10Z`, producer run `30865183650`, n=15, and canonical queue-inclusive wall p50=486 seconds.
- Independently recomputed the strict result in the focused contract and added adverse cases for provenance, cutoff/endpoint, population size, duplicates, old-ID overlap, terminal conclusions, comparator, status, and GATE-05 mutation.
- Marked only FAST-01 Complete and closed its residual without erasing the 19-run/772-second or 13-run/724-second misses; GATE-05 retains protected run `30782184713`, its 93 ownership rows, retained files, and offline verifier.

## Task Commits

Each task was committed atomically:

1. **Task 1a: Correct bounded selector candidate identity scope** — `2d1a7d58` (fix)
2. **Task 1b: Capture and verify protected evidence** — `a7feaaa5` (feat)
3. **Task 2: Reconcile FAST-01 from the protected verdict and prove GATE-05 unchanged** — `c15ec6ee` (feat)

## Files Created/Modified

- `scripts/ci/correlate-terminal-ratification-dispatch.sh` — scopes candidate identity to the new post-dispatch run set.
- `scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh` — validates the exact protected subject under network denial.
- `235-FAST-01-GAP-CLOSURE-REMEASUREMENT.{json,attestation.jsonl,TRUSTED-ROOT.jsonl}` — retained protected receipt, bundle, and trusted root.
- `test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs` — independent recomputation and FAST/GATE reconciliation adversarial contract.
- `.planning/REQUIREMENTS.md` — FAST-01-only strict-pass completion and exact traceability.
- `.planning/todos/pending/2026-08-02-fast-01-terminal-p50-miss.md` — closes the residual while preserving both prior misses.

## Decisions Made

- The new receipt is the sole closure authority because its valid protected-main provenance and independent recomputation produce n=15 and p50=486; readiness data does not drive status.
- The `< 720` comparator remains strict; the prior 724-second result remains a miss even though FAST-01 is now complete from the later non-overlapping population.
- GATE-05 is verified independently rather than inferred from FAST-01: protected run `30782184713`, its 93 rows, retained artifacts, and offline verifier stay intact.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test contract] Corrected two focused-contract implementation defects**
- **Found during:** Task 2
- **Issue:** The new test initially called a helper with the wrong arity name, and its GATE-05 verifier mutation case raised `File.Error` instead of the expected contract failure.
- **Fix:** Corrected the helper call and made the verifier validator fail closed when the protected verifier path is absent.
- **Files modified:** `test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs`
- **Verification:** Focused contract 4/4 passes; plan-wide planning contracts 124 passed, 12 skipped.
- **Committed in:** `c15ec6ee`

### Execution Recovery Record

- Prior safe-resume commits `6cd2f5e2`, `f5c1e063`, `7ec3b55a`, and `2d1a7d58` repaired bounded terminal selection without changing the immutable comparator or accepting nonterminal evidence.
- Failed producer runs `30863048191` and `30863688526` remain historical failed attempts; producer repair PRs #198, #200, and #201 established the final protected producer path. The successful producer run is `30865183650`; no result-preference rerun occurred.
- The selector recovered from GitHub eventual consistency through retained pre/post projections and a durable pre-file-mtime lower bound. No dispatch timestamp was invented; a durable one-second boundary corroborated the recovery.
- The selector identity-scope correction treats historical IDs as the before-set and requires full candidate identity only for newly observed rows, preserving adverse selection semantics.

**Total deviations:** 1 auto-fixed (Rule 1); recovery details above document the resumed Task 1 evidence chain.
**Impact on plan:** No scope expansion. The exact protected population produces the planned strict pass, and all old receipts remain unchanged.

## TDD Gate Compliance

Task 2 resumed after the Task 1 evidence boundary. Its expanded contract was validated against the completed protected artifacts; a historical RED run was not fabricated. The final focused contract is green and covers the plan's required adverse cases.

## Issues Encountered

The planning contracts log unavailable local PostgreSQL connections during test startup, but all are filesystem-backed and completed successfully without database access.

## User Setup Required

None.

## Next Phase Readiness

Phase 235 has strict measured evidence for both terminal requirements: FAST-01 is Complete from protected run `30865183650`, and GATE-05 remains Complete from protected run `30782184713`.

## Self-Check: PASSED

- Verified committed Task 1 and Task 2 hashes exist in git history.
- Verified the new receipt, its bundle/root, both offline verifiers, and the focused contract exist and passed the plan verification commands.

---
*Phase: 235-terminal-ratification-measured-not-read*
*Completed: 2026-08-04*
