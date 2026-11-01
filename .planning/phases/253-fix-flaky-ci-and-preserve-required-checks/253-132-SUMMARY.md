---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "132"
subsystem: ci-reliability
status: complete
gap_closure: true
tags: [gsd-sdk, completion, disposition, historical-disposition, r11]
requirements: [CIREL-01, CIREL-02]
requirements-completed: []
requires:
  - phase: 253-131
    provides: FREEZE-R11 / PUBLICATION-R11 on the reviewed source 8d648821 and the r11 scoped ref pair
  - phase: 253-121
    provides: R10 contract pattern (ac05a22c), assertProofOwnerR10, numeric revision order, --require-dispositioned gating
provides:
  - additive --revision r11 in the reconciliation helper (contract, dry-run, prepare, apply, check-index)
  - committed R11 reconciliation contract (52 never-executed responsibilities, 16 halted records, final owner 253-135)
affects: [253-133, 253-134, 253-135]
tech-stack:
  added: []
  patterns: ["additive reconciliation revision over frozen earlier contracts", "tooling receipts frozen at the last owning commit's blobs", "numeric (never string-sorted) revision order", "fixture-only records pinned and excluded from completion links"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R11.json
  modified:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.mjs
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.test.mjs
key-decisions:
  - "R11 completed = R10 fifty + 116-121 (56); halted = R10 fifteen + 122 (16); never-ran 123, 124; unstarted 52. The builder throws unless these partition 01-124"
  - "OWNER_REMAP_R11 = {120: [120, 131], 121: [121, 132], 122: [133], 123: [134], 124: [132, 135]}, deduplicated in first-seen order"
  - "Halted proof map = R10 map remapped through OWNER_REMAP_R11, plus 122 -> 125, 126, 127, 128, 129, 130, 131, 133"
  - "253-121 tooling receipts frozen at the blobs of commit 3d73201b6 (mjs 583f84ff..., test 2b79a502...), read with git"
  - "The six -R11-PROBE records are pinned in a separate fixture_only_records block with a note naming them real-shape fixture evidence only; no responsibility, link, completed plan or application field references them"
  - "Owner validation uses the exported assertProofOwnerR11, as R10 did"
coverage:
  - id: D1
    description: "--revision r11 exists end to end with the 01-124 partition, --require-dispositioned gating, numeric revision order and plan ids up to 253-135; v1-r5 keep --require-accepted"
    requirement: "CIREL-02"
    verification:
      - kind: unit
        ref: "253-LOAD-RECOVERY-reconcile.test.mjs#R11 revision skeleton: partition, dispositioned gating, numeric revision order, CLI and plan IDs"
        status: pass
    human_judgment: false
  - id: D2
    description: "R11 mapping, frozen 253-121 receipts, 253-122's eleven records, pins and the real installed SDK pairing proof on temporary committed copies"
    requirement: "CIREL-01"
    verification:
      - kind: integration
        ref: "253-LOAD-RECOVERY-reconcile.test.mjs#R11 pairing through the real installed SDK on a copy of the current plan set"
        status: pass
    human_judgment: false
  - id: D3
    description: "Committed R11 contract; --check-only exits 0 for v1 and r2-r11; earlier contract hashes unchanged"
    verification:
      - kind: other
        ref: "node 253-LOAD-RECOVERY-reconcile.mjs --revision r11 --prepare-contract --output <R11> --check-only"
        status: pass
    human_judgment: false
estimate: {tokens: 34000, tasks: 3}
actuals:
  tokens: 70561
  tasks: 3
  commits: 3
commits: 3
plan_head_before: d536e01099f58e09b84e4fe17a17983433f4a63c
plan_head_after: 4e6bea18ea36726e10c4ce5fa20eb34218759a05
duration: "about 17 minutes (07:46Z to 08:03Z)"
completed: 2026-10-17
---

# Phase 253 Plan 132: R11 reconciliation contract Summary

**`--revision r11` is now an additive reconciliation revision. It re-points 52 never-executed responsibilities (R10's 50 plus 253-123 and 253-124) to the R11 plans 125-135 and keeps 16 halted records literal (R10's 15 plus 253-122). It is gated by `--require-dispositioned` and proven against the real installed SDK on temporary copies. The committed R11 contract `921c3500…` pins PLANs 01-135 and 62 existing SUMMARYs; its final owner is 253-135. v1 and R2-R10 are byte-identical and still check, and FREEZE-R11 still validates.**

## Performance

- **Started:** 2026-10-17T07:46:31Z
- **Completed:** 2026-10-17T08:03Z
- **Tasks:** 3/3
- **Files:** 1 created and 2 modified (+6,065 / -27 lines; 5,381 of the added lines are the contract)

## Task Commits

1. **Task 1 (tracer): R11 skeleton with partition, dispositioned gating, numeric revision order and CLI:** `49e49e9ba` (feat)
2. **Task 2: mapping, frozen 253-121 receipts, pins, real-SDK pairing:** `e5ce3d578` (feat)
3. **Task 3: R11 contract:** `4e6bea18e` (feat)

## Preconditions (positive controls, before any edit)

- The 253-131 SUMMARY is `status: complete`.
- `ci-gate-canary.sh --check-only --revision-freeze FREEZE-R11` exits 0 ("local fixture contract passed"), with `scripts/ci/__pycache__` deleted first.
- `--check-only` exits 0 for v1 and r2-r10. `shasum -c PRESERVATION-R11.sha256` exits 0.
- The R11 contract file was absent.

## RED / GREEN counts

- **Baseline (no edits):** `node --test` exit 0, 141 tests, 141 pass (84 s).
  - Caveat: the Task 1 helper edit was written while this baseline was still running, so the subprocess probes in the later suites could have loaded the edited helper. The count equals 253-121's final 141/141, and every earlier-suite test passes on the committed tree anyway.
- **Task 1 RED:** the new tests were in place and the helper was restored to HEAD bytes. The filtered run (`--test-name-pattern=R11`) exited 1: 7 new tests, 0 pass, 7 fail, 141 skipped. Every failure is an assertion on the missing feature, not a load or syntax fault. Examples: `REVISIONS` lacks r11, `reconcile.R11_PLAN_IDS is not iterable`, `unknown revision r11; expected one of v1, …, r10`.
- **Task 1 GREEN:** the filtered run exits 0, 7/7 pass.
  - The first full run failed 9 tests. That was my own edit bug: the r11→r12 probe rename also rewrote the eight just-extended REVISIONS lists to end in `"r12"`. I corrected those lists to `"r11"`; nothing else changed.
  - The full suite then passed 148/148.
  - **Tracer gate:** after commit `49e49e9ba`, the verbatim Task 1 `<verify>` ran on the clean tree and exited 0 (148/148, v1-r10 check-only all 0, clean tree). Expansion followed.
- **Task 2 RED:** the helper was at the committed skeleton. The filtered run exited 1 with 18 R11 tests: 12 pass, 6 fail.
  - The 6 failures: the partition (122 not halted, 116-121 not completed); the owner/halted-proof mapping (no 122 key, no fixture block); the pins and application block; the frozen receipts (`Cannot read properties of undefined (reading 'receipts')` for 253-121); the missing-PLAN refusal (the skeleton pinned only 01-124); and the rewritten-253-133-PLAN refusal ("Missing expected exception", same cause).
  - The other 5 new Task 2 tests already passed on the skeleton: earlier-contract byte identity, CLI drift, disposition text, SDK now-state and SDK post-disposition.
- **Task 2 GREEN:** the filtered run passes 18/18. The full suite passes 159/159. The verbatim Task 2 `<verify>` exited 0 after commit `e5ce3d578` (159/159, v1-r10 check-only all 0, preservation `shasum -c` 0, clean tree).
- **Task 3:** the verbatim `<verify>` exited 0 after commit `4e6bea18e`.
  - Negative control: the same node predicate expecting 134 plan pins exits 1.
  - Negative control: `--check-only` against a copy with `bundle_requires_final_summary_of` mutated to 253-124 exits 1 ("differs from the regenerated contract").

## Partition and mapping

- **Completed (56):** R10's 50 plus 116, 117, 118, 119, 120 and 121. **Halted (16):** 02, 07, 09, 12, 16, 27, 40, 51, 63, 73, 84, 92, 97, 104, 113 and 122. **Never-executed (52):** R10's 50 plus 123 and 124.
- **123 and 124:** `blocked_by ["253-122"]`, with `never_ran_reason` NEVER_RAN_REASON_R11 (run 38963239851's logs redirected to results-receiver.actions.githubusercontent.com, refused by the then-frozen trusted download policy before its socket, `redirect_rejected`). Earlier rows keep their own reasons, and every row carries `successor_revision: R11`.
- **Owners:** native is unchanged. Completion is 43, 50, 61, 71, 81, 90, 96, 103, 112, 121, 132, 135. Examples:
  - 08 -> 42, 134
  - 22 -> 91, 95, 102, 111, 120, 131
  - 86 -> 133
  - 93, 114, 123 -> 134
  - 94 -> 96, 103, 112, 121, 132, 135
  - 106 -> 112, 121, 132, 135
  - 115 -> 121, 132, 135
  - 124 -> 132, 135 (all completion links plus load_target_disposition)

  No owner is halted or never executed. The builder throws otherwise (through `assertProofOwnerR11`), and a test asserts the throw for 122, 123, 124, 113, 114, 115, 104 and 92. As the positive control, 131-135, 120 and 121 are accepted.
- **Halted proof:** 07/12 -> 18, 19, 20, 42, 91, 95, 102, 111, 120, 131, 133; 92 -> 95, 102, 111, 120, 131, 133; 104 -> 107, 108, 110, 111, 120, 131, 133; 113 -> 116, 117, 118, 119, 120, 131, 133; **122 -> 125, 126, 127, 128, 129, 130, 131, 133**. No halted-proof row names 122.
- **Probe records:** the six `253-LOAD-RECOVERY-PROBE-*-R11-PROBE.json` records (records commit 64679fcc3) appear only in `fixture_only_records`.
  - That block pins each record's sha256, under the note "the 253-127 probe window records are real-shape fixture evidence only; they are never a completion link or acceptance evidence".
  - A test asserts that no responsibility, required link, completed plan, halted-proof row or application field references them.

## Frozen receipts

- Every R10 completed and halted record is held exactly as R10 holds it (test-asserted with deepEqual). That includes 253-96 at a6ccee580, 253-103 at 6a898e019 and 253-112 at 17f3db955.
- **253-121** lists this helper and its test as modified, and this plan edits both. Its receipts are held at the bytes of the last 253-121 commit touching each, found with `git log -1 --grep='(253-121)' -- <file>`. That commit is **`3d73201b6efbfcdb57d12acc005644e0e125ad60`** for both files:
  - `253-LOAD-RECOVERY-reconcile.mjs`: `583f84ffb3c45e7319a09b89349e0f979a504d345dca6fb5917cda4f8d5239ed`
  - `253-LOAD-RECOVERY-reconcile.test.mjs`: `2b79a502b4faa73062e02802e04da90030fe2f0910bb4a88437b7d8be48b7c1a`
  - The test re-reads both blobs with `git show 3d73201b6…:<path>`, checks that commit is the last 253-121 commit touching each file, and checks the live bytes now differ, so the freeze is load-bearing. 253-121's third receipt is the R10 contract at ac05a22c.
- **253-122** is described with `requireReceipts: true`. All eleven records exist (the ten R10 records plus `253-R10-CANARY-OPERATOR.sh`, da70cbba…). Each receipt sha256 equals its PRESERVATION-R11 entry. Its SUMMARY hash also equals the PRESERVATION-R11 entry (0dfe297b…).

## Contract and hashes

- **R11 contract:** `253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R11.json`, sha256 **`921c3500f99299f2f84478a047c3c5dbf53d9d31064bd9d0ce80a4cd32f1c84c`**, 207,221 bytes. Schema `sigra.phase253.load-recovery-reconciliation-contract/r11`.
  - 124 originals, 56 completed, 16 halted, 52 responsibilities, 135 plan pins, 62 summary pins (R10's 53 plus 121, 122 and 125-131), 6 fixture-only records.
  - Lineage `v1_contract` … `r10_contract` in numeric order; `r10_contract` sha256 ac05a22cc27f9e2718b3c93e94133c2c3c71d3a5fe8d9c059ff1bb8117b0509f. The SDK pins and capture equal R10's (SDK 1.16.0, 7 files).
  - Application: `accepted_only_predicate` "scripts/ci/ci-hosted-gate-verify.py --mode completion --require-dispositioned"; `targets` "only the fifty-two previously nonexistent SUMMARY paths; existing files are never overwritten"; `bundle_requires_final_summary_of` "253-135". `then_run` and `never` equal R10's.
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
  - R10 `ac05a22cc27f9e2718b3c93e94133c2c3c71d3a5fe8d9c059ff1bb8117b0509f`

## check-index report (read-only, before the contract commit)

`--revision r11 --check-index 253` exited 1 with `{"ok":false,"route":"phase_stuck","old_unsummarized":52,"any_unsummarized":56}`.
- The 56 unsummarized items are the 52 responsibilities plus the unexecuted R11 plans 253-132, 253-133, 253-134 and 253-135. 132 was in progress, since its SUMMARY did not exist yet.
- This is the expected pre-disposition state. The report was written to the session scratchpad, not the repo.

## Real-SDK proofs (temporary committed copies only)

- **Now-state:** a copy of PLANs 01-135 with the real SUMMARYs through 131. Measured with installed SDK 1.16.0 and asserted:
  - 135 plans are listed and `runnable` is [].
  - `incomplete` is exactly the 52 plus 132-135.
  - 123 and 124 are incomplete, have no summary, are not halted, and `blocked_by` includes 253-122 (the SDK reports [253-122, 253-84, 253-92]). 122 is halted.
  - 116-121 and 125-131 are summarized.
  - 132-135 have no summary, are not halted and inherit [253-122, 253-84, 253-92]. 125 depends on halted 122, so its line inherits the block. 132 depends only on 131, which is summarized, so it is the next explicitly dispatched plan; 133's wave is 132's plus one.
- **Post-disposition:** simulated R11 superseded summaries for the 52, plus ordinary summaries for 132-135, applied through `applyBundle`.
  - `incomplete` and `init.execute-phase` `incomplete_plans` are both empty.
  - Exactly 16 plans are halted, and they are the R11 halted list.
  - No summary has `status: blocked`, and `init.execute-phase` agrees with `phase-plan-index` on all 135 plans.
  - `checkIndex` is ok, with route `resume_phase_gates`.
- **Refusals:**
  - A `status: blocked` 253-134 owner summary is refused.
  - A rewritten 253-133-PLAN.md is refused.
  - Neither refusal wrote 253-123-SUMMARY.md.
  - The builder refuses a missing 253-133, 253-135 or 253-128 PLAN. Positive control: the same clone builds before each removal and after each restore.
- **Disposition text:** all 52 entries carry:
  - `tags: [historical-disposition, load-recovery, dispositioned]`, `status: superseded`, `execution_performed: false`, `original_status: blocked`, `phase_verification_status: not_started` and an empty `requirements-completed`;
  - the statements that CIREL-02 is accepted by the linked completion evidence and that CIREL-01 is recorded partial under Jon's not_reproduced disposition.

  None contains the R5 "CIREL-01 and CIREL-02 are accepted" sentence, "CIREL-01 is/was accepted", or a -R11-PROBE path. 123's entry names results-receiver.actions.githubusercontent.com, `redirect_rejected` and "Its R11 successor is 253-134."; 124's names 253-132 and 253-135 and links load_target_disposition.

## Deviations from Plan

**1. [Rule 2 - Plan truth] Probe records named in the contract as fixtures**
- **Found during:** Task 2
- **Issue:** the plan says the -R11-PROBE records are "named as fixtures, never as a completion link", and no existing contract field can name them without being a link.
- **Fix:** the contract has an additive `fixture_only_records` block that pins the six `-R11-PROBE.json` records with a fixture-only note. `application`, `then_run` and `never` still equal R10's. Tests assert the block and the absence of any probe reference elsewhere. `253-R11-PROBE-OPERATOR.sh` is not listed, because it is the runner rather than a `-R11-PROBE` record.
- **Committed in:** `e5ce3d578`

**2. [Process] Earlier-suite edits: 24 lines, including one R10 ordering assertion**
- 24 lines changed in earlier suites, and nothing else; checked with `git diff d536e0109`, which shows 24 removed lines in the test file:
  - the eight REVISIONS lists gain r11 (seven earlier-suite lists plus the R10 suite's `R10_REVISIONS`);
  - the 14 unknown-revision probe lines move from r11 to r12;
  - the R10 suite's `expected one of …, r10\n` stderr regex gains `, r11` (it is a REVISIONS list).
- One line goes beyond the plan's literal "REVISIONS lists and probes": the R10 test `REVISIONS.indexOf("r10") === REVISIONS.length - 1`. It cannot hold once r11 exists. It now asserts `indexOf("r10") === indexOf("r9") + 1`, which keeps its intent (r10 directly follows r9, numeric order). The new R11 test asserts r11 is last.
- The helper's removed lines are only the dispositioned set, REVISIONS and the `contractPathFor` chain.

**3. [Rule 1 - Spec measurement] SDK propagation asserted as measured**
- The SDK reports 123/124 `blocked_by` as [253-122, 253-84, 253-92], so the test asserts `includes("253-122")`. 132-135 inherit [253-122, 253-84, 253-92] and `runnable` is []. This is the same propagation 253-121 recorded, plus 122, because 125 depends on it.

**4. [Process] RED observed without a RED commit**
- RED was observed with the new tests in place and the helper at the previous committed bytes (HEAD for Task 1, the skeleton commit for Task 2). Each task is one `feat` commit, following the 253-112/121 precedent. RED runs used `--test-name-pattern=R11`; every task's verbatim `<verify>` ran the full suite.

**5. [Process] `r11Fixture` is `r8Fixture({ maxPlan: 135, maxSummary: 131 })`**
- r10Fixture is unchanged, and every R10 test passes unchanged with the R11 PLANs and SUMMARYs in the real directory.

**6. [Process] Verify blocks ran from bash script files**
- They ran from script files in the session scratchpad (zsh does not word-split), following the 253-111/119/120/131 precedent. The chains are verbatim.

**Total deviations:** 6 (1 plan-truth addition, 1 spec measurement, 4 process notes). **Impact:** none on the contract's meaning or on v1-R10 behaviour.

**Not done by design:** the STATE, ROADMAP and REQUIREMENTS writer steps were skipped, per the orchestrator's hard constraints. WINDOWS.md was not appended: there are no stubs, skipped tests or unrun verifies.

## Known Stubs

None.

## Threat Flags

None.
- **T-253-280:** mitigated by:
  - the 135 PLAN pins and 62 summary pins;
  - owners that exclude 122-124 (enforced by the builder and asserted by tests);
  - 253-121 receipts read from its commit;
  - the earlier contracts re-checked against PRESERVATION-R11;
  - plan ids up to 135 and numeric revision order, both tested.
- **T-253-281:** mitigated by the disposition-text test, the probe-record exclusion test and the r11 `--require-dispositioned` gating test.
- **T-253-SC:** no new dependency.

## Notes for 253-133 and later

- **Product source is unchanged.** This plan touched only .planning files (the helper, its test and the R11 contract). After Task 3:
  - `ci-git-publication.py --validate-frozen-source 8d648821fac5414774b173f579a847a27a122b73` reports frozen_source matches, head 4e6bea18e, planning_only_movement true, product tree e58d2f75f9cf3603f077904a47e4f76c61942c2a;
  - `ci-gate-canary.sh --check-only --revision-freeze FREEZE-R11` exits 0.
- **Pinned bytes.** The R11 contract pins byte-for-byte:
  - PLANs 01-135;
  - SUMMARYs through 131 (62 of them);
  - the six -R11-PROBE records.

  Later plans must not edit any of them, nor any receipt file of a completed or halted plan (including 253-122's eleven records, and 253-121's R10 contract). The 132-135 SUMMARYs are not pinned.
- **Ownership:**
  - 253-133 owns the canary rows (23, 33, 45, 54, 66, 76, 86) and is in the halted proof for 07, 12, 92, 104, 113 and 122.
  - 253-134 owns the PR rows, including 93, 98, 105, 114 and 123.
  - 253-135 runs `--revision r11` dry-run, prepare and apply after a real `--require-dispositioned` completion, and the bundle needs 253-135's own final SUMMARY.
- **Verification status:** whole-phase verification stays `not_started`.

## Invariants

- `git status --short` shows only ` M .planning/config.json`.
- config.json sha256 is `8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d`.
- state.json is 70229 bytes with sha256 prefix `e45278c2cee0`.
- STATE.md, state.json, ROADMAP.md, REQUIREMENTS.md and HANDOFF.json are untouched. No GSD writer verb was run; only read-only `phase-plan-index`, `init.execute-phase` and `verification status` (inside check-index and on temporary copies).
- No disposition SUMMARY was written to the real phase directory.
- `scripts/ci/__pycache__` is absent; it was removed after every python run. Positive control: a created directory is detected by the same check.
- FREEZE-R11 sha256 e6eb4cd0…129c90 and PUBLICATION-R11 sha256 fd2e9004…01db8 are unchanged. FREEZE-R11's outward_actions_sha256 are canary 898ffa48…a410f and docs_and_prs f0e47f00…46ee2.
- Zero GitHub requests.

## Self-Check: PASSED

- The R11 contract, the helper, the test and this SUMMARY exist.
- Commits `49e49e9ba`, `e5ce3d578` and `4e6bea18e` are ancestors of HEAD. No commit deleted a file.
- `commits` was measured as 3 from the ledger base `d536e0109`.
