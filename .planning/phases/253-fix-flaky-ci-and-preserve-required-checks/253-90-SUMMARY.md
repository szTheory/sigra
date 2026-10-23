---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "90"
subsystem: ci-reliability
tags: [completion, disposition, historical-disposition, r6]
requires:
  - phase: 253
    provides: "253-89 committed, Jon-approved not_reproduced target disposition and runner --require-target-disposition predicate"
provides:
  - "--require-dispositioned completion mode in scripts/ci/ci-hosted-gate-verify.py (optional disposition links, per-requirement statuses)"
  - "--revision r6 in 253-LOAD-RECOVERY-reconcile.mjs and the committed R6 contract (42 responsibilities, 11 halted, final owner 253-94)"
affects: [253-91, 253-92, 253-93, 253-94]
actuals:
  tokens: 36000
  tasks: 3
  commits: 5
plan_head_before: 10b42ed189cd644091555d9c3246f7881ab1118f
plan_head_after: 83d011312671d0958818153763778cf2bbcb1e03
tech-stack:
  added: []
  patterns: [additive R-revision beside frozen builders, per-plan frozen tooling receipts, strict route first then disposition route]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R6.json
  modified:
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.mjs
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.test.mjs
key-decisions:
  - "R6 completion accepts exactly the disposition shape (status dispositioned, one disposition gap, CIREL-01 partial_not_reproduced, CIREL-02 accepted); the strict accepted shape is not an R6 predicate"
  - "R6 dispositions use dispositioned_by (not accepted_by) so no field name implies CIREL-01 acceptance"
  - "253-81 tooling receipts frozen per plan at the 4bb3f303a bytes"
requirements-completed: []
coverage:
  - id: D1
    description: "Completion verifier --require-dispositioned with optional hash- and path-bound disposition links; strict LOAD_CHECKS argv unchanged and tried first"
    requirement: "CIREL-01"
    verification:
      - kind: unit
        ref: "scripts/ci/ci-hosted-gate-verify.test.py#CompletionDispositionTests"
        status: pass
      - kind: integration
        ref: "scripts/ci/ci-hosted-gate-verify.test.py#CompletionDispositionEndToEndTests (real runner subprocess)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Additive R6 reconciliation revision and committed contract proven against the real installed SDK on temporary committed copies"
    requirement: "CIREL-02"
    verification:
      - kind: integration
        ref: "253-LOAD-RECOVERY-reconcile.test.mjs#R6 reconciliation contract, R6 dispositioned completion gating, R6 pairing"
        status: pass
    human_judgment: false
duration: 
completed: 2026-10-14
status: complete
---

# Phase 253 Plan 90: Dispositioned completion mode and R6 contract Summary

**The completion verifier now honestly verifies a Jon-approved not_reproduced disposition as `dispositioned` (CIREL-01 partial_not_reproduced, CIREL-02 accepted, never accepted), and an additive R6 reconciliation contract re-points the 42 never-executed responsibilities and 11 halted records to plans 89-94.**

## Performance

- **Completed:** 2026-10-14
- **Tasks:** 3
- **Commits:** 5 (measured from `plan_head_before`)

## Task outcomes

1. **Task 1 (tracer, TDD).** RED `f357b1486`: 16 new tests, 17 failing results (3 failures, 14 errors) out of 60. GREEN `3031b97f0`: 60/60 pass, exit 0.
   - `--require-dispositioned` is mutually exclusive with `--require-accepted`.
   - The optional links `load_target_disposition` and `load_target_disposition_approval` are both-or-neither, re-hashed, and bound to the reviewed 253-89 paths (`DISPOSITION_PATHS`) when the production checker is used.
   - `LINKS`, `LOAD_CHECKS` and `LOAD_PATHS` are untouched. Strict argv runs first. Exit 3 plus both links then runs `--verify-load-acceptance <path> --require-target-disposition`.
   - A real-runner end-to-end test (no injected checker) proves the disposition route and that `--require-accepted` and a link-less record still fail.
   - Tracer gate: the verify (`python3 scripts/ci/ci-hosted-gate-verify.test.py` plus the two greps) passes end to end, so the expansion tasks proceeded.
2. **Task 2 (TDD).** RED `538520f48`: 13 new R6 tests plus the three REVISIONS equality assertions fail (16 of 73). GREEN `6eb2fbbad`: 73/73 pass.
   - `--revision r6` is added to REVISIONS, the dispatcher and `contractPathFor`.
   - `completionArgv(revision, path)` is exported. v1-r5 call `--require-accepted`; r6 calls `--require-dispositioned`. Both are test-asserted.
   - R6 renders `tags: [historical-disposition, load-recovery, dispositioned]` and `dispositioned_by`. The body says CIREL-02 is accepted by the linked evidence and CIREL-01 is recorded partial under Jon's not_reproduced disposition; a test asserts the R5 "both accepted" sentence never appears.
   - Only the REVISIONS equality assertions in earlier tests were edited.
3. **Task 3.** The R6 contract was generated and committed in `83d011312`. `--check-only` exits 0.

## Hashes and reports

- R6 contract sha256: `4e7c33fe072e344f9b0c2f39065af50e99f7208c7c50afff788df564f3078f63`
- Earlier contracts unchanged: v1 `5eba0fad...`, R2 `dc29b096...`, R3 `6a50c6fe...`, R4 `2c335138...`, R5 `f92fefe3f028de90112c9693ab5f1d7d769ab4087493f0fedbb39a46f7af1601`. All five `--check-only` commands exit 0 before and after.
- 253-81 tooling receipts frozen at commit `4bb3f303a`: `253-LOAD-RECOVERY-reconcile.mjs` `9f1ff7f7e1ca455d722a725a3608aa7907c7b36aa4745fe623a1ee807a4b8a83`, `253-LOAD-RECOVERY-reconcile.test.mjs` `dcae48ec9f39b87f8448363ccfaca01443fc3be33ff7d54939dad09d56030c6f`.
- `--revision r6 --check-index 253` (read-only), as expected `ok:false`: `{"ok":false,"route":"phase_stuck","old_unsummarized":42,"any_unsummarized":47}`. The 47 are the 42 responsibilities plus 90-94. `halted_literal` true, `originals_intact` true, SDK pins ok, verification status `missing`.

## Final-verifier-change note

This is the last R6 completion-verifier change before 253-91's Task 3 freeze (253-91 Task 2 changes only the canary, publication and PR collector scripts).

## Deviations from Plan

**1. [Rule 1 - Plan assumption] The installed SDK does not report 253-90 as ready with empty blocked_by.**
- **Found during:** Task 2 (real-SDK now-state test).
- **Issue:** 253-89 declares `depends_on: ["253-83", "253-84"]`, and halted 253-84 propagates. The installed SDK 1.16.0 reports `blocked_by: ["253-84"]` for 89 (which has a SUMMARY) and for 90-94, with `ready: false` and `runnable: []`. The behavior spec said 90 is ready with empty blocked_by.
- **Fix:** The test asserts the measured SDK behavior and documents it. Pinned PLAN files cannot be edited. The contract and dispositions are unaffected: summarized plans leave the incomplete set, and the post-disposition test still reaches `resume_phase_gates` with nothing incomplete.
- **Consequence for the orchestrator:** 253-91..94 are not selectable by an unfiltered `execute-phase`. They must be dispatched explicitly, as 253-90 was.
- **Files modified:** `253-LOAD-RECOVERY-reconcile.test.mjs`
- **Commit:** `6eb2fbbad`

**Total deviations:** 1 (Rule 1 plan assumption). **Impact:** None on the delivered artifacts; a dispatch-routing caveat for 91-94.

## Known Stubs

None.

## Threat Flags

None. No new network endpoints, auth paths or trust-boundary schema. The new verifier links are hash- and path-bound (T-253-175, T-253-176 mitigated); the contract pins PLANs 01-94 and existing SUMMARYs, owners exclude halted and never-run plans, and the R6 text is tested against overclaiming (T-253-177).

## Remaining gaps

- The R6 dispositions are not applied; that is 253-94's job once 91-93 finish.
- CIREL-01 stays partial under Jon's disposition. Full Phase 253 verification stays `not_started`.

## Self-Check: PASSED

- Commits `f357b1486`, `3031b97f0`, `538520f48`, `6eb2fbbad`, `83d011312` are ancestors of HEAD.
- The R6 contract file exists and matches `--check-only`. `.planning/config.json` is byte-pinned (`8e312f6c...`) and `state.json` is 70229 bytes. `scripts/ci/__pycache__` removed.
