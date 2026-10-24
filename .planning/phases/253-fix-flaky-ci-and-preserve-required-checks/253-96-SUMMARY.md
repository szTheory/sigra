---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "96"
subsystem: ci-reliability
tags: [gsd-sdk, completion, disposition, historical-disposition, r7]
requires:
  - phase: 253-95
    provides: R7 freeze and publication manifest, publisher readback fix
  - phase: 253-90
    provides: R6 contract pattern and --require-dispositioned gating
provides:
  - additive --revision r7 in the reconciliation helper (contract, dry-run, prepare, apply, check-index)
  - committed R7 reconciliation contract (44 never-executed responsibilities, 12 halted records, final owner 253-99)
affects: [253-97, 253-98, 253-99]
actuals:
  tokens: 48000
  tasks: 3
  commits: 3
plan_head_before: 7fb42f30929673bd77d69198a6314aac7919f48a
plan_head_after: a124e6c831e70272f9fa7419368a2d1be3a24c11
tech-stack:
  added: []
  patterns: ["additive reconciliation revision over frozen earlier contracts", "tooling receipts frozen at the last owning commit's blobs"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R7.json
  modified:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.mjs
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.test.mjs
key-decisions:
  - "R7 completed = R6 thirty-five + 89, 90, 91; halted = R6 eleven + 92; never-ran 93, 94; unstarted 44"
  - "Owner remap 91 -> 91,95; 92 -> 97; 93 -> 98; 94 -> 96,99; halted 92 proof -> 95,97"
  - "253-90 tooling receipts frozen at the blobs of commit 6eb2fbbad, read with git"
requirements-completed: ["CIREL-01", "CIREL-02"]
coverage:
  - id: D1
    description: "--revision r7 exists end to end with the 94-plan partition and --require-dispositioned gating; v1-r5 keep --require-accepted"
    requirement: "CIREL-02"
    verification:
      - kind: unit
        ref: "253-LOAD-RECOVERY-reconcile.test.mjs#R7 revision skeleton: partition, dispositioned gating and CLI"
        status: pass
    human_judgment: false
  - id: D2
    description: "R7 mapping, frozen receipts, pins and the real installed SDK pairing proof on temporary committed copies"
    requirement: "CIREL-01"
    verification:
      - kind: integration
        ref: "253-LOAD-RECOVERY-reconcile.test.mjs#R7 pairing through the real installed SDK on a copy of the current plan set"
        status: pass
    human_judgment: false
  - id: D3
    description: "Committed R7 contract; --check-only exits 0 for v1, r2-r7; earlier contract hashes unchanged"
    verification:
      - kind: other
        ref: "node 253-LOAD-RECOVERY-reconcile.mjs --revision r7 --prepare-contract --output <R7> --check-only"
        status: pass
    human_judgment: false
duration: 40min
completed: 2026-10-15
status: complete
---

# Phase 253 Plan 96: R7 reconciliation contract Summary

**Additive `--revision r7` reconciliation (44 never-executed responsibilities and 12 literal halted records re-pointed to plans 95-99, gated by `--require-dispositioned`) proven against the real installed SDK on temporary copies, with a committed R7 contract.**

## Performance

- **Duration:** about 40 min
- **Completed:** 2026-10-15
- **Tasks:** 3
- **Files modified:** 3 (helper, its test, new R7 contract)

## Accomplishments

- R7 partitions plans 01-94 into 38 completed (R6's 35 plus 89, 90, 91), 12 halted (R6's 11 plus 92) and 44 never-executed (R6's 42 plus 93, 94). The builder throws if they stop partitioning.
- 93 and 94 never ran because halted 253-92 stopped at publication on the publisher's commit-message readback mismatch. Their rows carry `blocked_by ["253-92"]`.
- Owners are only completed plans or R7 plans 95-99 (92 -> 97, 93 -> 98, 94 -> 96 and 99, 91 -> 91 and 95). The halted proof map adds 92 -> 95, 97. Tests assert no owner is halted or never-executed.
- The R7 disposition text says CIREL-02 is accepted by the linked completion evidence and CIREL-01 is recorded partial under Jon's not_reproduced disposition. A test asserts it never claims CIREL-01 accepted.
- r6 and r7 share one dispositioned-revision set (`--require-dispositioned`); v1-r5 keep `--require-accepted` (test-asserted).

## Task Commits

1. **Task 1 (tracer): R7 skeleton, dispositioned gating, CLI** - `eace4a76c` (feat)
2. **Task 2: mapping, frozen receipts, pins, real-SDK pairing** - `a6ccee580` (feat)
3. **Task 3: R7 contract** - `a124e6c83` (feat)

## RED counts

- Task 1: RED `node --test` exit 1, 78 tests, 69 pass, 9 fail; GREEN exit 0, 78 pass.
- Task 2: RED exit 1, 89 tests, 80 pass, 9 fail; GREEN exit 0, 89 pass (after the measured-SDK adjustment below).

## Hashes

- R7 contract: `8b077547940cf3ef953aaf5c539366e8cf506215a3502357f982ce45f2389df7`
- Unchanged earlier contracts: v1 `5eba0fad1a70ae70d073ac4d4c1d4cc4ab09d1c919e8f3a7f9b6e0daf5c1dfd5`, R2 `dc29b096...`, R3 `6a50c6fe...`, R4 `2c335138...`, R5 `f92fefe3f028de90112c9693ab5f1d7d769ab4087493f0fedbb39a46f7af1601`, R6 `4e7c33fe072e344f9b0c2f39065af50e99f7208c7c50afff788df564f3078f63` (re-checked after each task).
- 253-90 frozen tooling receipts (last 253-90 commit touching each file, `6eb2fbbad`, read with `git show`):
  - `253-LOAD-RECOVERY-reconcile.mjs` `1f2f600eb383215400ddae459c23ae22602f36defe97db5f3b25ba86962769e3`
  - `253-LOAD-RECOVERY-reconcile.test.mjs` `bf652d4e7ceb3919aeda75438841bdabe8ae424bdf2ba72eb5c865a057af385a`
- `--check-only` results after this plan: v1, r2, r3, r4, r5, r6, r7 all exit 0.

## --check-index report (r7, read-only, at generation time)

`ok: false`, route `phase_stuck`, `old_unsummarized` 44, `any_unsummarized` 48 (the 44 plus the unexecuted R7 plans 96-99; 96 is this plan), `halted_literal` true, `originals_intact` true, SDK pins ok. This is the expected pre-disposition state.

## Deviations from Plan

**1. [Rule 1 - Spec mismatch] "253-96 is runnable" does not hold in the SDK's `runnable` sense**
- **Found during:** Task 2 (real-SDK now-state test)
- **Issue:** The installed SDK 1.16.0 propagates `blocked_by` through `depends_on` even past summarized plans (the same behaviour R6's test documents). On a copy, 95-99 report `blocked_by ["253-84", "253-92"]`, `ready: false`, and `runnable` is `[]`.
- **Fix:** The test asserts the measured facts instead: 96 has no summary, is not halted, and is the next explicitly dispatched plan; 93 and 94 are incomplete and blocked behind 253-92; 92 is halted. Behaviour of the helper is unchanged.
- **Files modified:** test file only
- **Committed in:** `a6ccee580`

**Total deviations:** 1 (a test expectation corrected to the measured SDK behaviour). **Impact:** none on the contract; the post-disposition proof (nothing incomplete, twelve halted, no blocked summary, init agrees, route `resume_phase_gates`) passes against the real SDK.

## Issues Encountered

None. No product file, STATE.md, state.json, ROADMAP.md or REQUIREMENTS.md was touched. `.planning/config.json` stays dirty and byte-identical (sha256 `8e312f6c...`).

## Known Stubs

None.

## Next Phase Readiness

253-97 (hosted canary), 253-98 (PR proofs) and 253-99 (completion and bundle) can use `--revision r7`; the bundle needs the final summary of 253-99. Whole-phase verification stays `not_started`.

## Self-Check: PASSED

- R7 contract, helper and test exist; commits `eace4a76c`, `a6ccee580`, `a124e6c83` are on HEAD; `commits` measured 3 from the ledger.
