---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "112"
subsystem: ci-reliability
status: complete
gap_closure: true
tags: [gsd-sdk, completion, disposition, historical-disposition, r9]
requirements: [CIREL-01, CIREL-02]
requirements-completed: []
requires:
  - phase: 253-111
    provides: FREEZE-R9 / PUBLICATION-R9 and the r9 scoped ref pair
  - phase: 253-103
    provides: R8 contract pattern, three-digit plan id helpers, --require-dispositioned gating
provides:
  - additive --revision r9 in the reconciliation helper (contract, dry-run, prepare, apply, check-index)
  - committed R9 reconciliation contract (48 never-executed responsibilities, 14 halted records, final owner 253-115)
affects: [253-113, 253-114, 253-115]
tech-stack:
  added: []
  patterns: ["additive reconciliation revision over frozen earlier contracts", "tooling receipts frozen at the last owning commit's blobs"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R9.json
  modified:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.mjs
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.test.mjs
key-decisions:
  - "R9 completed = R8 forty + 100, 101, 102, 103 (44); halted = R8 thirteen + 104 (14); never-ran 105, 106; unstarted 48"
  - "OWNER_REMAP_R9 = {102: [102, 111], 103: [103, 112], 104: [113], 105: [114], 106: [112, 115]}, deduplicated in first-seen order"
  - "Halted proof map = R8 map remapped through OWNER_REMAP_R9, plus 104 -> 107, 108, 110, 111, 113"
  - "253-103 tooling receipts frozen at the blobs of commit 6a898e019, read with git"
  - "Every unknown-revision probe that used r9 (four call sites in the R2, R7 and R8 suites) now uses r10"
coverage:
  - id: D1
    description: "--revision r9 exists end to end with the 01-106 partition, --require-dispositioned gating and three-digit ids up to 253-115; v1-r5 keep --require-accepted"
    requirement: "CIREL-02"
    verification:
      - kind: unit
        ref: "253-LOAD-RECOVERY-reconcile.test.mjs#R9 revision skeleton: partition, dispositioned gating, CLI and three-digit plan IDs"
        status: pass
    human_judgment: false
  - id: D2
    description: "R9 mapping, frozen receipts, pins and the real installed SDK pairing proof on temporary committed copies"
    requirement: "CIREL-01"
    verification:
      - kind: integration
        ref: "253-LOAD-RECOVERY-reconcile.test.mjs#R9 pairing through the real installed SDK on a copy of the current plan set"
        status: pass
    human_judgment: false
  - id: D3
    description: "Committed R9 contract; --check-only exits 0 for v1 and r2-r9; earlier contract hashes unchanged"
    verification:
      - kind: other
        ref: "node 253-LOAD-RECOVERY-reconcile.mjs --revision r9 --prepare-contract --output <R9> --check-only"
        status: pass
    human_judgment: false
estimate: {tokens: 32000, tasks: 3}
actuals:
  tokens: 54842
  tasks: 3
  commits: 3
commits: 3
plan_head_before: a8c215f479e451c594ee76aafe27ddd2aa3624dc
plan_head_after: 0bda1cb3c4d84aedd747348d2521bb1577244efe
duration: "about 1h 14m (10:58Z to 12:13Z), most of it the 692 s baseline suite and the verify runs"
completed: 2026-10-16
---

# Phase 253 Plan 112: R9 reconciliation contract Summary

**`--revision r9` is now an additive reconciliation revision. It re-points 48 never-executed responsibilities (R8's 46 plus 253-105 and 253-106) to plans 107-115 and keeps 14 halted records literal (R8's 13 plus 253-104). It is gated by `--require-dispositioned` and proven against the real installed SDK on temporary copies. The committed R9 contract `857b2397…` pins PLANs 01-115, and its final owner is 253-115. v1 and R2-R8 are byte-identical and still check.**

## Performance

- **Started:** 2026-10-16T10:58:58Z
- **Completed:** 2026-10-16T12:13:18Z
- **Tasks:** 3/3
- **Files:** 1 created and 2 modified (+5123 / -15 lines, 4,523 of the added lines are the contract)

## Task Commits

1. **Task 1 (tracer): R9 skeleton with partition, dispositioned gating, CLI and three-digit ids:** `6ad0fe272` (feat)
2. **Task 2: mapping, frozen 253-103 receipts, pins, real-SDK pairing:** `17f3db955` (feat)
3. **Task 3: R9 contract:** `0bda1cb3c` (feat)

## Preconditions (positive controls, before any edit)

- The 253-111 SUMMARY is `status: complete`.
- `ci-gate-canary.sh --check-only --revision-freeze FREEZE-R9` exits 0. FREEZE-R9 sha256 is `3ddde073…d432d`.
- `--check-only` exits 0 for v1 and r2-r8. `shasum -c PRESERVATION-R9.sha256` exits 0.

## RED / GREEN counts

- **Baseline (no edits):** `node --test` exit 0, 106 tests, 106 pass (692 s).
- **Task 1 RED:** a filtered run (`--test-name-pattern=R9`) exits 1 with 6 new tests, 0 pass and 6 fail. The earlier-suite REVISIONS edits were also red by construction until GREEN.
- **Task 1 GREEN:** the filtered run exits 0, 6/6 pass.
  - Tracer gate: the verbatim Task 1 `<verify>` ran end to end after the commit and exited 0 (112/112 tests, v1-r8 check-only all 0, clean tree).
- **Task 2 RED:** the filtered run exits 1 with 17 R9 tests, 10 pass and 7 fail.
  - 4 of the 11 new Task 2 tests already passed on the skeleton: the byte-identity guard for earlier contracts, the missing-PLAN 107-115 refusal (the skeleton already pinned them), the CLI drift test and the SDK now-state test.
  - The 7 failures covered the partition counts, the owner mapping, the pins and application block, the frozen receipts, the disposition text, the post-disposition SDK proof and the refusals.
- **Task 2 GREEN:** the filtered run passes 17/17. The verbatim Task 2 `<verify>` exited 0 (123/123 tests, v1-r8 check-only all 0, preservation `shasum -c` 0, clean tree).
- **Task 3:** the verbatim `<verify>` exited 0.
  - Negative control: the same block expecting 116 plan pins exits 1.
  - Negative control: `--check-only` against a copy with `bundle_requires_final_summary_of` mutated to 253-106 exits 1 ("differs from the regenerated contract").

## Partition and mapping

- **Completed (44):** R8's 40 plus 100, 101, 102 and 103. **Halted (14):** 02, 07, 09, 12, 16, 27, 40, 51, 63, 73, 84, 92, 97 and 104. **Never-executed (48):** R8's 46 plus 105 and 106. The builder throws unless these partition 01-106.
- **105 and 106:** `blocked_by ["253-104"]`, with `never_ran_reason` NEVER_RAN_REASON_R9 (the transport refused the approved 302 redirect to productionresultssa17.blob.core.windows.net). Earlier rows keep their own reasons and every row carries `successor_revision: R9`.
- **Owners:** native is unchanged. Completion is 43, 50, 61, 71, 81, 90, 96, 103, 112, 115. Examples:
  - 08 -> 42, 114
  - 22 -> 91, 95, 102, 111
  - 86 -> 113
  - 93, 98, 105 -> 114
  - 94 -> 96, 103, 112, 115
  - 99 -> 103, 112, 115
  - 106 -> 112, 115

  No owner is halted or never executed (the builder throws otherwise, and a test asserts it for 104-106 too).
- **Halted proof:**
  - 07/12 -> 18, 19, 20, 42, 91, 95, 102, 111, 113
  - 92 -> 95, 102, 111, 113
  - 97 -> 100, 101, 102, 111, 113
  - 104 -> 107, 108, 110, 111, 113
- **Disposition text:** tags `[historical-disposition, load-recovery, dispositioned]`, `status: superseded`, `execution_performed: false`, and `original_status: blocked` as a frontmatter field only. It says CIREL-02 is accepted and CIREL-01 is recorded partial under Jon's not_reproduced disposition. A test asserts it never contains the R5 "both accepted" sentence or "CIREL-01 is/was accepted".

## Hashes

- **R9 contract:** `857b23970613e5a0bf73fee613fcb0f9b523074d4c6d375bb23311a59aecd207` (171341 bytes).
- **Unchanged earlier contracts** (re-checked after every task with `shasum -c PRESERVATION-R9.sha256` and by the regeneration tests):
  - v1 `5eba0fad…`, R2 `dc29b096…`, R3 `6a50c6fe…`, R4 `2c335138…`, R5 `f92fefe3…`, R6 `4e7c33fe…`, R7 `8b077547…`
  - R8 `a23aba456917fd295463f92304e595e16c405f628f0327681036efd1b9552c7b`
- **253-103 frozen tooling receipts:** read with `git show` from `6a898e0195bfcbc509af1b8fc1dee3ca1748346c`, which `git log -1 --grep='(253-103)' -- <file>` returns for both files.
  - `253-LOAD-RECOVERY-reconcile.mjs` `80da1a200d6c5a4da23768713c6baa757ca1fd71414f1219b18e871ab6a29aa8`
  - `253-LOAD-RECOVERY-reconcile.test.mjs` `afac0fe9a385a79e7cf3c0b913e0ede794e4b2f5131f7ec2bc81d24044439b17`
  - A test asserts both equal the blob at that commit and differ from the live, now-edited files. Before this plan's edits the live files equalled these blobs (measured).
- **253-104:** described with `requireReceipts: true`. All ten R8 records are present at their live bytes and none are missing.
- **FREEZE-R9** `3ddde073…d432d` and **PUBLICATION-R9** `1f820993…3228` are unchanged, and the freeze `--check-only` still exits 0.

## Contract contents

- 48 responsibilities, 14 halted plans (including 253-97 and 253-104), 44 completed plans and 106 originals.
- 115 PLAN pins in numeric order.
- 46 summary pins: R8's 39, plus 103, 104, 107, 108, 109, 110 and 111.
- Lineage pins for v1 through R8 (`r8_contract` is `a23aba45…`). The SDK and capture pins are identical to R8's.
- Application block:
  - `accepted_only_predicate`: `scripts/ci/ci-hosted-gate-verify.py --mode completion --require-dispositioned`
  - `targets`: only the forty-eight previously nonexistent SUMMARY paths
  - `bundle_requires_final_summary_of`: `253-115`
  - `then_run` and `never` are the same as R8.

## --check-index report (r9, read-only, at generation time)

The CLI printed `{"ok":false,"route":"phase_stuck","old_unsummarized":48,"any_unsummarized":52}` (exit 1).

- `sdk_ok` true, `halted_literal` true, `originals_intact` true, `dispositions_invalid` [] and `verification_status` missing.
- The 52 unsummarized are the 48 responsibilities plus 253-112, 253-113, 253-114 and 253-115. 253-112 is this plan, so its SUMMARY did not exist yet.

This is the expected pre-disposition state. The report record was written to the session scratchpad, not the repo.

## Real-SDK proofs (temporary committed copies only)

- **Now-state:** a copy of PLANs 01-115 with the real SUMMARYs through 111. Measured with installed SDK 1.16.0 and asserted:
  - 115 plans are listed and `runnable` is [].
  - 105 and 106 are incomplete with `blocked_by` [253-104, 253-84, 253-92], and are not halted. 104 is halted.
  - 112-115 have no summary, are not halted and inherit only [253-84, 253-92]. 112 depends only on 111, which is summarized, so it is the next explicitly dispatched plan.
- **Post-disposition:** simulated R9 superseded summaries for the 48, plus ordinary summaries for 112-115, applied through `applyBundle`.
  - `incomplete` and `init.execute-phase` `incomplete_plans` are both empty.
  - Exactly 14 plans are halted, and they are the R9 halted list.
  - No summary has `status: blocked`, and `init.execute-phase` agrees with `phase-plan-index` on all 115 plans.
  - `checkIndex` is ok, with route `resume_phase_gates`.
- **Refusals:**
  - A `status: blocked` 253-114 owner summary is refused.
  - A rewritten 253-113-PLAN.md is refused.
  - Neither refusal wrote 253-105-SUMMARY.md.
  - The builder refuses a missing 253-113, 253-115 or 253-109 PLAN. Positive control: the same clone builds before the removal and after the restore.

## Deviations from Plan

**1. [Rule 3 - Blocking] Four earlier-suite unknown-revision probes, not one**
- **Found during:** Task 1
- **Issue:** the plan names "the unknown-revision probe that now uses r9". r9 was the unknown value at four places:
  - the R2 suite's `buildContract({ revision: "r9" })` throw and its CLI probe;
  - the R7 skeleton CLI probe;
  - the R8 skeleton CLI probe.

  All four become valid once r9 exists.
- **Fix:** each now uses `r10` and still asserts refusal ("unknown revision", exit 2 where it did before). Apart from these and the six REVISIONS lists, no earlier-suite line changed: 12 removed lines in total, checked with `git diff`.
- **Committed in:** `6ad0fe272`

**2. [Rule 1 - Spec measurement] SDK propagation asserted as measured**
- The SDK reports 105/106 `blocked_by` as [253-104, 253-84, 253-92], not only 104. The test asserts `includes("253-104")`.
- 112-115 inherit [253-84, 253-92], and `runnable` is []. This is the same propagation 253-103 recorded. Helper behaviour is unaffected.

**3. [Process] RED runs used `--test-name-pattern=R9`**
- A full run takes up to 11.5 minutes. Each task's verbatim `<verify>` ran the full, unfiltered suite.

**4. [Process] `r9Fixture` is `r8Fixture({ maxPlan: 115, maxSummary: 111 })`**
- This reuses the unchanged r8Fixture instead of copying it. Its own assertion checks that all 115 PLANs were copied.

**Total deviations:** 4. **Impact:** none on the contract or on v1-R8 behaviour.

## Known Stubs

None.

## Threat Flags

None.
- **T-253-232:** mitigated by the 115 PLAN pins and 46 summary pins, owners that exclude 104-106 (enforced by the builder and asserted by a test), 253-103 receipts read from its commit, and three-digit ids tested.
- **T-253-233:** mitigated by the disposition-text test and the r9 `--require-dispositioned` gating test.
- **T-253-SC:** no new dependency.

## Notes for 253-113

- **Product source is unchanged.** This plan touched only .planning files (the helper, its test and the R9 contract), so FREEZE-R9 still validates. Its `--check-only` exited 0 after Task 3.
- **Pinned bytes.** The R9 contract pins PLANs 01-115 and SUMMARYs 103, 104 and 107-111 byte-for-byte. 253-113 must not edit any of them, nor any receipt file of a completed or halted plan (including 253-104's ten R8 records). Its own SUMMARY is not pinned.
- **Ownership.** 253-113 owns the canary rows (23, 33, 45, 54, 66, 76, 86) and is in the halted proof for 07, 12, 92, 97 and 104. 253-114 owns the PR rows, including 98 and 105. 253-115 runs `--revision r9` dry-run, prepare and apply after a real `--require-dispositioned` completion, and the bundle needs 253-115's own final SUMMARY.
- **Verification status:** whole-phase verification stays `not_started`.

## Invariants

- `git status --short` shows only ` M .planning/config.json`.
- config.json sha256 is `8e312f6c…0b8d`.
- state.json is 70229 bytes with sha256 prefix `e45278c2cee0`.
- STATE.md, state.json, ROADMAP.md, REQUIREMENTS.md and HANDOFF.json are untouched. No GSD writer verb was run; only read-only `phase-plan-index`, `init.execute-phase` and `verification status` (inside check-index).
- No disposition SUMMARY was written to the real phase directory.
- `scripts/ci/__pycache__` is absent and was removed after the freeze check.
- Zero GitHub requests.

## Self-Check: PASSED

- The R9 contract, the helper and the test exist.
- Commits `6ad0fe272`, `17f3db955` and `0bda1cb3c` are ancestors of HEAD. No commit deleted a file.
- `commits` was measured as 3 from the ledger base `a8c215f47`.
