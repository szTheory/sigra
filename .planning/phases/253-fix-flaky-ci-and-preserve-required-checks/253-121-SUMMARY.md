---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "121"
subsystem: ci-reliability
status: complete
gap_closure: true
tags: [gsd-sdk, completion, disposition, historical-disposition, r10]
requirements: [CIREL-01, CIREL-02]
requirements-completed: []
requires:
  - phase: 253-120
    provides: FREEZE-R10 / PUBLICATION-R10 on the reviewed source 7e681e6a and the r10 scoped ref pair
  - phase: 253-112
    provides: R9 contract pattern (857b2397), three-digit plan id helpers, --require-dispositioned gating
provides:
  - additive --revision r10 in the reconciliation helper (contract, dry-run, prepare, apply, check-index)
  - committed R10 reconciliation contract (50 never-executed responsibilities, 15 halted records, final owner 253-124)
affects: [253-122, 253-123, 253-124]
tech-stack:
  added: []
  patterns: ["additive reconciliation revision over frozen earlier contracts", "tooling receipts frozen at the last owning commit's blobs", "numeric (never string-sorted) revision order"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R10.json
  modified:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.mjs
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.test.mjs
key-decisions:
  - "R10 completed = R9 forty-four + 107-112 (50); halted = R9 fourteen + 113 (15); never-ran 114, 115; unstarted 50. The builder throws unless these partition 01-115"
  - "OWNER_REMAP_R10 = {111: [111, 120], 112: [112, 121], 113: [122], 114: [123], 115: [121, 124]}, deduplicated in first-seen order"
  - "Halted proof map = R9 map remapped through OWNER_REMAP_R10, plus 113 -> 116, 117, 118, 119, 120, 122"
  - "253-112 tooling receipts frozen at the blobs of commit 17f3db955 (mjs 7653cf4b..., test a166f6c4...), read with git"
  - "Owner validation is factored into the exported assertProofOwnerR10, so the halted/never-executed owner refusal is directly testable"
  - "The six unknown-revision probes that used r10 (nine lines) now use r11; the seven REVISIONS equality lists gain r10"
coverage:
  - id: D1
    description: "--revision r10 exists end to end with the 01-115 partition, --require-dispositioned gating, numeric revision order and plan ids up to 253-124; v1-r5 keep --require-accepted"
    requirement: "CIREL-02"
    verification:
      - kind: unit
        ref: "253-LOAD-RECOVERY-reconcile.test.mjs#R10 revision skeleton: partition, dispositioned gating, numeric revision order, CLI and plan IDs"
        status: pass
    human_judgment: false
  - id: D2
    description: "R10 mapping, frozen 253-112 receipts, 253-113's ten records, pins and the real installed SDK pairing proof on temporary committed copies"
    requirement: "CIREL-01"
    verification:
      - kind: integration
        ref: "253-LOAD-RECOVERY-reconcile.test.mjs#R10 pairing through the real installed SDK on a copy of the current plan set"
        status: pass
    human_judgment: false
  - id: D3
    description: "Committed R10 contract; --check-only exits 0 for v1 and r2-r10; earlier contract hashes unchanged"
    verification:
      - kind: other
        ref: "node 253-LOAD-RECOVERY-reconcile.mjs --revision r10 --prepare-contract --output <R10> --check-only"
        status: pass
    human_judgment: false
estimate: {tokens: 34000, tasks: 3}
actuals:
  tokens: 60209
  tasks: 3
  commits: 3
commits: 3
plan_head_before: 40a4d08afefc84fbc4011552bc85c52474346045
plan_head_after: bc3cdb208fdef98cfcc668ba30369afedaac6598
duration: "about 15 minutes (19:49Z to 20:04Z)"
completed: 2026-10-16
---

# Phase 253 Plan 121: R10 reconciliation contract Summary

**`--revision r10` is now an additive reconciliation revision. It re-points 50 never-executed responsibilities (R9's 48 plus 253-114 and 253-115) to the R10 plans 116-124 and keeps 15 halted records literal (R9's 14 plus 253-113). It is gated by `--require-dispositioned` and proven against the real installed SDK on temporary copies. The committed R10 contract `ac05a22c…` pins PLANs 01-124 and 53 existing SUMMARYs; its final owner is 253-124. v1 and R2-R9 are byte-identical and still check, and FREEZE-R10 still validates.**

## Performance

- **Started:** 2026-10-16T19:49:03Z
- **Completed:** 2026-10-16T20:04Z
- **Tasks:** 3/3
- **Files:** 1 created and 2 modified (+5,558 / -19 lines; 4,925 of the added lines are the contract)

## Task Commits

1. **Task 1 (tracer): R10 skeleton with partition, dispositioned gating, numeric revision order and CLI:** `17f2112de` (feat)
2. **Task 2: mapping, frozen 253-112 receipts, pins, real-SDK pairing:** `3d73201b6` (feat)
3. **Task 3: R10 contract:** `bc3cdb208` (feat)

## Preconditions (positive controls, before any edit)

- The 253-120 SUMMARY is `status: complete`.
- `ci-gate-canary.sh --check-only --revision-freeze FREEZE-R10` exits 0 ("local fixture contract passed").
- `--check-only` exits 0 for v1 and r2-r9. `shasum -c PRESERVATION-R10.sha256` exits 0.
- The R10 contract file was absent.

## RED / GREEN counts

- **Baseline (no edits):** `node --test` exit 0, 123 tests, 123 pass (87 s; the suite is much faster than the planned 12 minutes).
- **Task 1 RED:** the helper was restored to HEAD bytes and the filtered run (`--test-name-pattern=R10`) exited 1: 7 new tests, 0 pass, 7 fail. Every failure is an assertion on the missing feature (`REVISIONS` lacking r10, `R10_PLAN_IDS is not iterable`, `unknown revision r10; expected one of v1, …, r9`), not a load or syntax fault.
- **Task 1 GREEN:** the filtered run exits 0, 7/7 pass. The full suite passes 130/130.
  - Tracer gate: the verbatim Task 1 `<verify>` ran on the clean tree after the commit and exited 0 (130/130, v1-r9 check-only all 0, clean tree). Expansion followed.
- **Task 2 RED:** the filtered run exited 1 with 18 R10 tests, 14 pass and 4 fail.
  - 7 of the 11 new Task 2 tests already passed on the skeleton: the byte-identity guard for earlier contracts, the missing-PLAN 116-124 / owner refusal, the CLI drift test, the disposition text, and the three SDK tests (the skeleton already carried the remapped rows, and the SDK itself counts 113 as halted).
  - The 4 failures were the partition (113 not halted, 107-112 not completed), the owner/halted-proof mapping (no 113 key), the pins and application block, and the frozen receipts (`Cannot read properties of undefined (reading 'receipts')` for 253-112).
- **Task 2 GREEN:** the filtered run passes 18/18. The full suite passes 141/141. The verbatim Task 2 `<verify>` exited 0 (141/141, v1-r9 check-only all 0, preservation `shasum -c` 0, clean tree).
- **Task 3:** the verbatim `<verify>` exited 0.
  - Negative control: the same node predicate expecting 125 plan pins exits 1.
  - Negative control: `--check-only` against a copy with `bundle_requires_final_summary_of` mutated to 253-115 exits 1 ("differs from the regenerated contract").

## Partition and mapping

- **Completed (50):** R9's 44 plus 107, 108, 109, 110, 111 and 112. **Halted (15):** 02, 07, 09, 12, 16, 27, 40, 51, 63, 73, 84, 92, 97, 104 and 113. **Never-executed (50):** R9's 48 plus 114 and 115.
- **114 and 115:** `blocked_by ["253-113"]`, with `never_ran_reason` NEVER_RAN_REASON_R10 (the frozen verifier required the bare workflow name; GitHub returned the run-name `Phase 253 Gate Canary / full-pass / 38906314106-1`). Earlier rows keep their own reasons, and every row carries `successor_revision: R10`.
- **Owners:** native is unchanged. Completion is 43, 50, 61, 71, 81, 90, 96, 103, 112, 121, 124. Examples:
  - 08 -> 42, 123
  - 22 -> 91, 95, 102, 111, 120
  - 86 -> 122
  - 93, 98, 105, 114 -> 123
  - 94 -> 96, 103, 112, 121, 124
  - 99 -> 103, 112, 121, 124
  - 106 -> 112, 121, 124
  - 115 -> 121, 124 (all completion links plus load_target_disposition)

  No owner is halted or never executed. The builder throws otherwise (through `assertProofOwnerR10`), and a test asserts the throw for 113, 114, 115, 104, 105 and 92, with 120-122/124 accepted as the positive control.
- **Halted proof:** 07/12 -> 18, 19, 20, 42, 91, 95, 102, 111, 120, 122; 84 -> 89, 90; 92 -> 95, 102, 111, 120, 122; 97 -> 100, 101, 102, 111, 120, 122; 104 -> 107, 108, 110, 111, 120, 122; **113 -> 116, 117, 118, 119, 120, 122**. No halted-proof row names 113.

## Frozen receipts

- Every R9 completed and halted record is held exactly as R9 holds it (test-asserted with deepEqual), including 253-96 at a6ccee580 and 253-103 at 6a898e019.
- **253-112** lists this helper and its test as modified, and this plan edits both. Its receipts are held at the bytes of the last 253-112 commit touching each, found with `git log -1 --grep='(253-112)' -- <file>`. That is **`17f3db955601b3bd3da7e126a7e1f6b57efead22`** for both, as planning saw:
  - `253-LOAD-RECOVERY-reconcile.mjs`: `7653cf4b4e1b68b71526d004c428e2e7320453d7761764bb127f1200281a54f5`
  - `253-LOAD-RECOVERY-reconcile.test.mjs`: `a166f6c40c91fa9958d35c06f8fdf6e8a6cdbf9d336f246aaf206eda92b8e833`
  - The test re-reads both blobs with `git show 17f3db955:<path>`, checks that commit is the last 253-112 commit touching each file, and checks the live bytes now differ (so the freeze is load-bearing). 253-112's third receipt is the R9 contract at 857b2397.
- **253-113** is described with `requireReceipts: true`. All ten R9 records exist, and each receipt sha256 equals its PRESERVATION-R10 entry. Its SUMMARY hash also equals the PRESERVATION-R10 entry (a5d7aabc…).

## Contract and hashes

- **R10 contract:** `253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R10.json`, sha256 **`ac05a22cc27f9e2718b3c93e94133c2c3c71d3a5fe8d9c059ff1bb8117b0509f`**, 187,406 bytes. Schema `sigra.phase253.load-recovery-reconciliation-contract/r10`.
  - 115 originals, 50 completed, 15 halted, 50 responsibilities, 124 plan pins, 53 summary pins (R9's 46 plus 112, 113 and 116-120).
  - Lineage `v1_contract` … `r9_contract` in numeric order; `r9_contract` sha256 857b23970613e5a0bf73fee613fcb0f9b523074d4c6d375bb23311a59aecd207. SDK pins and capture equal R9's (SDK 1.16.0, 7 files).
  - Application: `accepted_only_predicate` "scripts/ci/ci-hosted-gate-verify.py --mode completion --require-dispositioned"; targets "only the fifty previously nonexistent SUMMARY paths; existing files are never overwritten"; `bundle_requires_final_summary_of` "253-124"; `then_run` and `never` equal R9's.
- **Earlier contracts (unchanged; check-only 0 before and after):**
  - v1 `5eba0fad1a70ae70d073ac4d4c1d4cc4ab09d1c919e8f3a7f9b6e0daf5c1dfd5`
  - R2 `dc29b0963c4b6948bcb5a3b1c2cc058f84ea5b81da7364bafc7509f2448694ed`
  - R3 `6a50c6fe4b8a439778f0594c532a271dc7d1e1e8900c15d831693127c850333d`
  - R4 `2c3351381844664c887e016e3db16ef67674e1877472865c5616409acf060a7c`
  - R5 `f92fefe3f028de90112c9693ab5f1d7d769ab4087493f0fedbb39a46f7af1601`
  - R6 `4e7c33fe072e344f9b0c2f39065af50e99f7208c7c50afff788df564f3078f63`
  - R7 `8b077547940cf3ef953aaf5c539366e8cf506215a3502357f982ce45f2389df7`
  - R8 `a23aba456917fd295463f92304e595e16c405f628f0327681036efd1b9552c7b`
  - R9 `857b23970613e5a0bf73fee613fcb0f9b523074d4c6d375bb23311a59aecd207`

## check-index report (read-only, before the contract commit)

`--revision r10 --check-index 253` exited 1 with `{"ok":false,"route":"phase_stuck","old_unsummarized":50,"any_unsummarized":54}`:
- sdk_ok true, no SDK mismatches; halted_literal true; originals_intact true; dispositions_invalid []; verification_status missing.
- The 54 unsummarized items are the 50 responsibilities plus the unexecuted R10 plans 253-121, 253-122, 253-123 and 253-124. 121 was in progress, since its SUMMARY did not exist yet.

This is the expected pre-disposition state. The report record was written to the session scratchpad, not the repo.

## Real-SDK proofs (temporary committed copies only)

- **Now-state:** a copy of PLANs 01-124 with the real SUMMARYs through 120. Measured with installed SDK 1.16.0 and asserted:
  - 124 plans are listed and `runnable` is [].
  - 114 and 115 are incomplete, have no summary, are not halted, and `blocked_by` includes 253-113 (the SDK reports [253-113, 253-84, 253-92]). 113 is halted.
  - 107-112 and 116-120 are summarized.
  - 121-124 have no summary, are not halted and inherit only [253-84, 253-92]. 121 depends only on 120, which is summarized, so it is the next explicitly dispatched plan; 122's wave is 121's plus one.
- **Post-disposition:** simulated R10 superseded summaries for the 50, plus ordinary summaries for 121-124, applied through `applyBundle`.
  - `incomplete` and `init.execute-phase` `incomplete_plans` are both empty.
  - Exactly 15 plans are halted, and they are the R10 halted list.
  - No summary has `status: blocked`, and `init.execute-phase` agrees with `phase-plan-index` on all 124 plans.
  - `checkIndex` is ok, with route `resume_phase_gates`.
- **Refusals:**
  - A `status: blocked` 253-123 owner summary is refused.
  - A rewritten 253-122-PLAN.md is refused.
  - Neither refusal wrote 253-114-SUMMARY.md.
  - The builder refuses a missing 253-122, 253-124 or 253-118 PLAN. Positive control: the same clone builds before each removal and after each restore.
- **Disposition text:** all 50 entries carry `tags: [historical-disposition, load-recovery, dispositioned]`, `status: superseded`, `execution_performed: false`, `original_status: blocked`, `phase_verification_status: not_started` and an empty `requirements-completed`. Each says CIREL-02 is accepted by the linked completion evidence and CIREL-01 is recorded partial under Jon's not_reproduced disposition. None contains the R5 "CIREL-01 and CIREL-02 are accepted" sentence or "CIREL-01 is/was accepted". 114's entry names the run workflow identity mismatch and "Its R10 successor is 253-123."; 115's names 253-121, 253-124 and links load_target_disposition.

## Deviations from Plan

**1. [Rule 2 - Testability] Owner validation factored into an exported helper**
- **Found during:** Task 1
- **Issue:** the plan requires the builder to throw for a halted or unstarted owner, but owners come from frozen constants, so the throw cannot be reached from a test by editing files.
- **Fix:** `buildContractR10` calls the exported `assertProofOwnerR10(phaseDir, owner)` for every row owner, and a Task 2 test drives it directly with forbidden owners and live-owner positive controls. Halted-proof owners keep the R9-style inline check. R9 and earlier builders are unchanged.
- **Committed in:** `17f2112de`, test in `3d73201b6`

**2. [Process] Unknown-revision probes: six probes, nine lines**
- The six probes the plan names span nine lines (several probes have both a call and a stderr regex). All nine now use `r11`; with the seven REVISIONS lists that makes 16 changed earlier-suite lines and nothing else (checked with `git diff 17f3db955`, 16 removed lines in the test file). The helper's removed lines are only the dispositioned set, REVISIONS and the `contractPathFor` chain.

**3. [Rule 1 - Spec measurement] SDK propagation asserted as measured**
- The SDK reports 114/115 `blocked_by` as [253-113, 253-84, 253-92], so the test asserts `includes("253-113")`. 121-124 inherit [253-84, 253-92] and `runnable` is []. This is the same propagation 253-103 and 253-112 recorded.

**4. [Process] RED observed without a RED commit**
- RED was observed by restoring the helper to HEAD bytes while the new tests were in place, then reapplying GREEN. Each task is one `feat` commit, following the 253-112 precedent. RED runs used `--test-name-pattern=R10`; every task's verbatim `<verify>` ran the full suite.

**5. [Process] `r10Fixture` is `r8Fixture({ maxPlan: 124, maxSummary: 120 })`**
- This reuses the unchanged r8Fixture; its own assertion checks that all 124 PLANs were copied. r9Fixture is unchanged, and every R9 test passes with the R10 PLANs and SUMMARYs in the real directory.

**Total deviations:** 5 (1 testability addition, 1 spec measurement, 3 process notes). **Impact:** none on the contract's meaning or on v1-R9 behaviour.

**Not done by design:** the STATE, ROADMAP and REQUIREMENTS writer steps were skipped, per the orchestrator's hard constraints. WINDOWS.md was not appended: there are no stubs, skipped tests or unrun verifies.

## Known Stubs

None.

## Threat Flags

None.
- **T-253-253:** mitigated by the 124 PLAN pins and 53 summary pins, owners that exclude 113-115 (enforced by the builder and asserted by tests), 253-112 receipts read from its commit, the earlier contracts re-checked against PRESERVATION-R10, and numeric plan-id and revision order tested.
- **T-253-254:** mitigated by the disposition-text test and the r10 `--require-dispositioned` gating test.
- **T-253-SC:** no new dependency.

## Notes for 253-122 and later

- **Product source is unchanged.** This plan touched only .planning files (the helper, its test and the R10 contract). After Task 3, `ci-git-publication.py --validate-frozen-source 7e681e6a9f4cbf10b1824f294a4fec54871da905` reports planning_only_movement true at head bc3cdb208, product tree 0a1412c8…, and `ci-gate-canary.sh --check-only --revision-freeze FREEZE-R10` exits 0.
- **Pinned bytes.** The R10 contract pins PLANs 01-124 and SUMMARYs through 120 (53 of them) byte-for-byte. Later plans must not edit any of them, nor any receipt file of a completed or halted plan (including 253-113's ten R9 records). The 121-124 SUMMARYs are not pinned.
- **Ownership.** 253-122 owns the canary rows (23, 33, 45, 54, 66, 76, 86) and is in the halted proof for 07, 12, 92, 97, 104 and 113. 253-123 owns the PR rows, including 98, 105 and 114. 253-124 runs `--revision r10` dry-run, prepare and apply after a real `--require-dispositioned` completion, and the bundle needs 253-124's own final SUMMARY.
- **Verification status:** whole-phase verification stays `not_started`.

## Invariants

- `git status --short` shows only ` M .planning/config.json`.
- config.json sha256 is `8e312f6c…0b8d`.
- state.json is 70229 bytes with sha256 prefix `e45278c2cee0`.
- STATE.md, state.json, ROADMAP.md, REQUIREMENTS.md and HANDOFF.json are untouched. No GSD writer verb was run; only read-only `phase-plan-index`, `init.execute-phase` and `verification status` (inside check-index and on temporary copies).
- No disposition SUMMARY was written to the real phase directory.
- `scripts/ci/__pycache__` is absent; it was removed after every python run.
- Zero GitHub requests.

## Self-Check: PASSED

- The R10 contract, the helper and the test exist.
- Commits `17f2112de`, `3d73201b6` and `bc3cdb208` are ancestors of HEAD. No commit deleted a file.
- `commits` was measured as 3 from the ledger base `40a4d08af`.
