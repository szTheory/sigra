---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "142"
subsystem: ci-reliability
status: complete
gap_closure: true
tags: [gsd-sdk, completion, disposition, historical-disposition, r12]
requirements: [CIREL-01, CIREL-02]
requirements-completed: []
requires:
  - phase: 253-141
    provides: FREEZE-R12 / PUBLICATION-R12 on fetched main 09df342a with frozen product source ded90ae9c
  - phase: 253-132
    provides: R11 contract pattern (921c3500), assertProofOwnerR11, numeric revision order, --require-dispositioned gating
provides:
  - additive --revision r12 in the reconciliation helper (contract, dry-run, prepare, apply, check-index)
  - committed R12 reconciliation contract (53 never-executed responsibilities, 17 halted records, final owner 253-145)
affects: [253-143, 253-144, 253-145]
tech-stack:
  added: []
  patterns: ["additive reconciliation revision over frozen earlier contracts", "tooling receipts frozen at the last owning commit's blobs", "numeric (never string-sorted) revision order", "superseded-candidate evidence pinned and excluded from completion links"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R12.json
  modified:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.mjs
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.test.mjs
key-decisions:
  - "R12 completed = R11 fifty-six + 125-133 (65); halted = R11 sixteen + 134 (17); never-ran 135; unstarted 53. The builder throws unless these partition 01-135"
  - "OWNER_REMAP_R12 = {131: [131, 141], 132: [132, 142], 133: [143], 134: [144], 135: [142, 145]}, deduplicated in first-seen order"
  - "Halted proof map = R11 map remapped through OWNER_REMAP_R12, plus 134 -> 136, 137, 138, 139, 140, 141, 143, 144"
  - "253-132 tooling receipts frozen at the blobs of commit e5ce3d578 (mjs b932d539..., test e17c86b6...), read with git"
  - "The eleven 253-133 R11 canary records are pinned in an additive superseded_evidence_records block (R11 candidate 2b239a98 only); no responsibility, link, halted-proof row or application field references them"
  - "R11's fixture_only_records block is carried through unchanged"
coverage:
  - id: D1
    description: "--revision r12 exists end to end with the 01-135 partition, --require-dispositioned gating, numeric revision order and plan ids up to 253-145; v1-r5 keep --require-accepted"
    requirement: "CIREL-02"
    verification:
      - kind: unit
        ref: "253-LOAD-RECOVERY-reconcile.test.mjs#R12 revision skeleton: partition, dispositioned gating, numeric revision order, CLI and plan IDs"
        status: pass
    human_judgment: false
  - id: D2
    description: "R12 mapping, frozen 253-132 receipts, 253-133 and 253-134 records, pins and the real installed SDK pairing proof on temporary committed copies"
    requirement: "CIREL-01"
    verification:
      - kind: integration
        ref: "253-LOAD-RECOVERY-reconcile.test.mjs#R12 pairing through the real installed SDK on a copy of the current plan set"
        status: pass
    human_judgment: false
  - id: D3
    description: "Committed R12 contract; --check-only exits 0 for v1 and r2-r12; earlier contract hashes unchanged"
    verification:
      - kind: other
        ref: "node 253-LOAD-RECOVERY-reconcile.mjs --revision r12 --prepare-contract --output <R12> --check-only"
        status: pass
    human_judgment: false
estimate: {tokens: 34000, tasks: 3}
actuals:
  tokens: 78394
  tasks: 3
  commits: 3
commits: 3
plan_head_before: f503034acf3419d55174518f686548d6ca3be69a
plan_head_after: 8e47400611cbf7054b513b96e5a2b1c81196c810
duration: "about 17 minutes (08:49Z to 09:07Z)"
completed: 2026-10-19
---

# Phase 253 Plan 142: R12 reconciliation contract Summary

**`--revision r12` is now an additive reconciliation revision. It re-points 53 never-executed responsibilities (R11's 52 plus 253-135) to the R12 plans 136-145 and keeps 17 halted records literal (R11's 16 plus 253-134). It is gated by `--require-dispositioned` and proven against the real installed SDK on temporary copies. The committed R12 contract `d36a2ab0…` pins PLANs 01-145 and 71 existing SUMMARYs; its final owner is 253-145. v1 and R2-R11 are byte-identical and still check, and FREEZE-R12 still validates.**

## Performance

- **Started:** 2026-10-19T08:49:48Z
- **Completed:** 2026-10-19T09:07Z
- **Tasks:** 3/3
- **Files:** 1 created and 2 modified (+6,629 / -34 lines; most of the added lines are the contract)

## Task Commits

1. **Task 1 (tracer): R12 skeleton with partition, dispositioned gating, numeric revision order and CLI:** `f228601b2` (feat)
2. **Task 2: mapping, frozen 253-132 receipts, pins, real-SDK pairing:** `fa2b080e2` (feat)
3. **Task 3: R12 contract:** `8e4740061` (feat)

## Preconditions (positive controls, before any edit)

- The 253-141 SUMMARY is `status: complete`.
- `ci-gate-canary.sh --check-only --revision-freeze FREEZE-R12` exits 0 ("local fixture contract passed"), with `scripts/ci/__pycache__` deleted first.
- `--check-only` exits 0 for v1 and r2-r11. Control: `--revision r12` was refused with exit 2 ("unknown revision r12"). `shasum -c PRESERVATION-R12.sha256` exits 0.
- The R12 contract file was absent.

## RED / GREEN counts

- **Baseline (no edits):** `node --test` exit 0, 159 tests, 159 pass (94 s). This equals 253-132's final 159/159.
- **Task 1 RED:** the new tests and the permitted earlier-suite edits were in place, and the helper was at HEAD bytes. The filtered run (`--test-name-pattern=R12`) exited 1: 7 new tests, 0 pass, 7 fail, 159 skipped. Every failure is an assertion on the missing feature, not a load or syntax fault. Examples: `REVISIONS` lacks r12, `reconcile.R12_PLAN_IDS is not iterable`, `unknown revision r12; expected one of v1, …, r11`.
- **Task 1 GREEN:** the filtered run exits 0, 7/7 pass. The full suite passes 166/166 on the first run.
  - **Tracer gate:** after commit `f228601b2`, the verbatim Task 1 `<verify>` ran on the clean tree and exited 0 (166/166, v1-r11 check-only all 0, clean tree). Expansion followed.
- **Task 2 RED:** the helper was at the committed skeleton. The filtered run exited 1 with 18 R12 tests: 12 pass, 6 fail.
  - The 6 failures: the partition (134 not halted, 125-133 not completed); the owner/halted-proof mapping (no 134 key, no superseded-evidence block); the pins and application block (135 pins, not 145); the frozen receipts (`Cannot read properties of undefined (reading 'receipts')` for 253-132); the missing-PLAN refusal (135 !== 145); and the rewritten-253-143-PLAN refusal ("Missing expected exception", same cause).
  - The other 5 new Task 2 tests already passed on the skeleton: earlier-contract byte identity, CLI drift, disposition text, SDK now-state and SDK post-disposition.
- **Task 2 GREEN:** the filtered run passes 18/18. I then added the measured SDK propagation assertions (below); the full suite passes 177/177. The verbatim Task 2 `<verify>` exited 0 after commit `fa2b080e2` (177/177, v1-r11 check-only all 0, preservation `shasum -c` 0, clean tree).
- **Task 3:** the verbatim `<verify>` exited 0 after commit `8e4740061`.
  - Negative control: the same node predicate run against a copy with `bundle_requires_final_summary_of` set to 253-135 exits 1.
  - Negative control: `--check-only` against that mutated copy exits 1 ("differs from the regenerated contract").

## Partition and mapping

- **Completed (65):** R11's 56 plus 125, 126, 127, 128, 129, 130, 131, 132 and 133. **Halted (17):** 02, 07, 09, 12, 16, 27, 40, 51, 63, 73, 84, 92, 97, 104, 113, 122 and 134. **Never-executed (53):** R11's 52 plus 135.
- **135:** `blocked_by ["253-134"]`, with `never_ran_reason` NEVER_RAN_REASON_R12 ("dependency 253-134 halted: normal draft PR #337 got no pull_request run; its frozen candidate 2b239a98 sat on the stale server parent 84ebcea60 and conflicted with current main, and GitHub creates no pull_request run for a conflicting PR"). Earlier rows keep their own reasons, and every row carries `successor_revision: R12`.
- **Owners:** native is unchanged. Completion is 43, 50, 61, 71, 81, 90, 96, 103, 112, 121, 132, 142, 145. Examples:
  - 08 -> 42, 144
  - 22 -> 91, 95, 102, 111, 120, 131, 141
  - 86 -> 143
  - 93, 114, 123 -> 144
  - 94 -> 96, 103, 112, 121, 132, 142, 145
  - 124 -> 132, 142, 145
  - 135 -> 142, 145 (all completion links plus load_target_disposition)

  No owner is halted, never executed, or 133. The builder throws otherwise (through `assertProofOwnerR12`), and a test asserts the throw for 134, 135, 122, 123, 124, 113, 104 and 92. As the positive control, 141, 142, 143, 145, 131, 132, 136 and 144 are accepted.
- **Halted proof:** 07/12 -> 18, 19, 20, 42, 91, 95, 102, 111, 120, 131, 141, 143; 92 -> 95, 102, 111, 120, 131, 141, 143; 104 -> 107, 108, 110, 111, 120, 131, 141, 143; 113 -> 116-120, 131, 141, 143; 122 -> 125-131, 141, 143; **134 -> 136, 137, 138, 139, 140, 141, 143, 144**. No halted-proof row names 133, 134 or 135.
- **R11 canary records (superseded evidence):** the eleven 253-133 records (ten `CANARY-*-R11*` records plus `253-R11-CANARY-OPERATOR.sh`) appear in an additive `superseded_evidence_records` block, each pinned at its PRESERVATION-R12 sha256, under the note "the 253-133 R11 canary records are superseded evidence for the R11 candidate 2b239a98 only; they are never an R12 completion link or acceptance evidence". A test asserts that no link key, responsibility, halted-proof row, application field or rendered disposition references them. They also appear as 253-133's own completed-plan receipts, which is where R11 records completed plans' outputs; that is not a completion link.
- **Probe records:** R11's `fixture_only_records` block (six -R11-PROBE records) is carried through unchanged (test-asserted deepEqual with R11).

## Frozen receipts

- Every R11 completed and halted record is held exactly as R11 holds it (test-asserted with deepEqual). That includes 253-96, 253-103, 253-112 and 253-121's frozen receipts.
- **253-132** lists this helper and its test as modified, and this plan edits both. Its receipts are held at the bytes of the last 253-132 commit touching each, found with `git log -1 --grep='(253-132)' -- <file>`. That commit is **`e5ce3d5780c30036f55651a5ee59a4fabd8047fd`** for both files:
  - `253-LOAD-RECOVERY-reconcile.mjs`: `b932d5392ec1a03909b22bd336f9064f9a5af2dc264bbae5c82dbccc40b74a62`
  - `253-LOAD-RECOVERY-reconcile.test.mjs`: `e17c86b61b638c9792437f46530791cb498559968b004fde0e5b9eef29d28acc`
  - The test re-reads both blobs with `git show e5ce3d578…:<path>`, checks that commit is the last 253-132 commit touching each file, and checks the live bytes now differ, so the freeze is load-bearing. 253-132's third receipt is the R11 contract at 921c3500.
- **253-133** is described as completed (`status: complete`, SUMMARY sha256 equal to PRESERVATION-R12 e8ba84fb…). Its eleven canary records are at their PRESERVATION-R12 bytes.
- **253-134** is described with `requireReceipts: true`. Its SUMMARY key-files list six paths, and all exist at their PRESERVATION-R12 bytes: PR-ACTION-APPROVAL-R11, PR-ALLOCATION-R11, PR-FREEZE-R11, PR-HTTP-LEDGER-R11, PR-NORMAL-EVIDENCE-R11 and `253-R11-PR-OPERATOR.sh` (4d59c9d5…). Its SUMMARY hash equals PRESERVATION-R12 (188a64be…). See deviation 3 on the count.

## Contract and hashes

- **R12 contract:** `253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R12.json`, sha256 **`d36a2ab07ff2e716d777bc784432b12ab6c01cef987c81e170fd852dcdefc45c`**, 231,046 bytes. Schema `sigra.phase253.load-recovery-reconciliation-contract/r12`.
  - 135 originals, 65 completed, 17 halted, 53 responsibilities, 145 plan pins, **71 summary pins (measured from the directory)**: R11's 62 plus 132, 133, 134 and 136-141. 6 fixture-only records and 11 superseded-evidence records.
  - Lineage `v1_contract` … `r11_contract` in numeric order; `r11_contract` sha256 921c3500f99299f2f84478a047c3c5dbf53d9d31064bd9d0ce80a4cd32f1c84c. The SDK pins and capture equal R11's (SDK 1.16.0, 7 files).
  - Application: `accepted_only_predicate` "scripts/ci/ci-hosted-gate-verify.py --mode completion --require-dispositioned"; `targets` "only the fifty-three previously nonexistent SUMMARY paths; existing files are never overwritten"; `bundle_requires_final_summary_of` "253-145". `then_run` and `never` equal R11's.
  - **Halted list key path:** the plan said R11 keeps the halted list under a key other than a top-level `halted_plans` array. Checked with jq: the R11 contract has a **top-level `halted_plans` array** (16 entries, each `{plan, summary{path, sha256, status}, receipts[]}`), plus a separate top-level `halted_proof_map` object keyed by plan id. R12 uses the same layout: `.halted_plans` (17) and `.halted_proof_map` (17 keys). The Task 3 verify block does not check a halted count, so nothing depended on the other key.
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
  - R11 `921c3500f99299f2f84478a047c3c5dbf53d9d31064bd9d0ce80a4cd32f1c84c`

## check-index report (read-only, before the contract commit)

`--revision r12 --check-index 253` exited 1 with `{"ok":false,"route":"phase_stuck","old_unsummarized":53,"any_unsummarized":57}`.
- The 57 unsummarized items are the 53 responsibilities plus the unexecuted R12 plans 253-142, 253-143, 253-144 and 253-145. 142 was in progress, since its SUMMARY did not exist yet.
- Also from the record: `sdk_ok: true`, `halted_literal: true`, `originals_intact: true`, `dispositions_invalid: []`, `verification_status: missing`.
- This is the expected pre-disposition state. The report was written to the session scratchpad, not the repo.

## Real-SDK proofs (temporary committed copies only)

- **Now-state:** a copy of PLANs 01-145 with the real SUMMARYs through 141. Measured with installed SDK 1.16.0 and asserted:
  - 145 plans are listed and `runnable` is [].
  - `incomplete` is exactly the 53 plus 142-145.
  - 135 is incomplete, has no summary, is not halted, and `blocked_by` includes 253-134 (the SDK reports [253-134, 253-122, 253-84, 253-92]). 134 is halted and summarized.
  - 125-133 and 136-141 are summarized.
  - 142-145 have no summary, are not halted and inherit [253-134, 253-122, 253-84, 253-92]. 136 depends on halted 134, so its line inherits the block. 142 depends only on 141, which is summarized, so it is the next explicitly dispatched plan. SDK waves: 142 = 48, 143 = 49 (asserted as 142 + 1), 144 = 50, 145 = 51.
- **Post-disposition:** simulated R12 superseded summaries for the 53, plus ordinary summaries for 142-145, applied through `applyBundle`.
  - `incomplete` and `init.execute-phase` `incomplete_plans` are both empty.
  - Exactly 17 plans are halted, and they are the R12 halted list.
  - No summary has `status: blocked`, and `init.execute-phase` agrees with `phase-plan-index` on all 145 plans.
  - `checkIndex` is ok, with route `resume_phase_gates`.
- **Refusals:**
  - A `status: blocked` 253-144 owner summary is refused.
  - A rewritten 253-143-PLAN.md is refused.
  - Neither refusal wrote 253-135-SUMMARY.md.
  - The builder refuses a missing 253-143, 253-145 or 253-138 PLAN. Positive control: the same clone builds before each removal and after each restore.
- **Disposition text:** all 53 entries carry:
  - `tags: [historical-disposition, load-recovery, dispositioned]`, `status: superseded`, `execution_performed: false`, `original_status: blocked`, `phase_verification_status: not_started` and an empty `requirements-completed`;
  - the statements that CIREL-02 is accepted by the linked completion evidence and that CIREL-01 is recorded partial under Jon's not_reproduced disposition.

  None contains the R5 "CIREL-01 and CIREL-02 are accepted" sentence, "CIREL-01 is/was accepted", a -R11-PROBE path or an R11 canary record. 135's entry names #337, the stale server parent 84ebcea60, `original_blocked_by: ["253-134"]`, "Its R12 successor is 253-142, 253-145." and links load_target_disposition. 123's entry names "Its R12 successor is 253-144."; 124's names 253-132, 253-142 and 253-145.

## Deviations from Plan

**1. [Rule 2 - Plan truth] R11 canary records named in the contract as superseded evidence**
- **Found during:** Task 2
- **Issue:** the plan's truths say "The R11 canary records are named as superseded evidence for the R11 candidate only, never as an R12 completion link", and no existing contract field can name them without being a link.
- **Fix:** the contract has an additive `superseded_evidence_records` block that pins the eleven 253-133 records with that note, following 253-132's `fixture_only_records` precedent. `application`'s `then_run` and `never` still equal R11's. Tests assert the block and the absence of any canary-record reference in links, responsibilities, halted proof, application and the rendered dispositions.
- **Committed in:** `fa2b080e2`

**2. [Process] Earlier-suite edits: 31 test lines, including one R11 ordering assertion**
- Checked with `git diff f503034ac`: 31 removed lines in the test file, and nothing else in earlier suites:
  - the nine REVISIONS lists gain r12 (seven `deepEqual(REVISIONS)` lines plus `R10_REVISIONS` and `R11_REVISIONS`);
  - the two `expected one of …, r11\n` stderr regexes gain `, r12` (they are REVISIONS lists);
  - the 19 unknown-revision probe lines move from r12 to r13.
- One line goes beyond the plan's literal "REVISIONS lists and probes": the R11 test `REVISIONS.indexOf("r11") === REVISIONS.length - 1`. It cannot hold once r12 exists. It now asserts `indexOf("r11") === indexOf("r10") + 1` (r11 directly follows r10, numeric order), exactly as 253-132 handled the R10 line. The new R12 test asserts r12 is last.
- The helper's removed lines are only the dispositioned set, REVISIONS and the `contractPathFor` chain. `buildContractR11` is untouched.

**3. [Rule 1 - Spec measurement] 253-134 has six receipts, not seven**
- The plan says "its six R11 PR records plus 253-R11-PR-OPERATOR.sh". The 253-134 SUMMARY's key-files list six paths in total: five PR records plus the operator script. Its own text says "All six 253-134 records exist". Two planned docs records (PR-DOCS-EVIDENCE-R11, PR-DOCS-PUBLICATION-RECEIPT-R11) never existed because `remaining` was not run. PRESERVATION-R12 also covers exactly these six. The test asserts the measured six by name, each at PRESERVATION-R12 bytes, with no `missing_receipts`.

**4. [Rule 1 - Spec measurement] SDK propagation asserted as measured**
- The SDK reports 135's `blocked_by` as [253-134, 253-122, 253-84, 253-92], so the test asserts `includes("253-134")`. 142-145 inherit the same four and `runnable` is []. This is the same propagation 253-132 recorded, plus 134, because 136 depends on it.

**5. [Process] RED observed without a RED commit**
- RED was observed with the new tests in place and the helper at the previous committed bytes (HEAD for Task 1, the skeleton commit for Task 2). Each task is one `feat` commit, following the 253-112/121/132 precedent. RED runs used `--test-name-pattern=R12`; every task's verbatim `<verify>` ran the full suite.

**6. [Process] `r12Fixture` is `r8Fixture({ maxPlan: 145, maxSummary: 141 })`**
- r11Fixture is unchanged, and every R11 test passes unchanged with the R12 PLANs and SUMMARYs in the real directory. The SDK facts above were first measured on an equivalent throwaway copy in the scratchpad, then asserted in the test.

**7. [Process] Verify blocks ran from bash script files**
- They ran from script files in the session scratchpad (zsh does not word-split), following the 253-111/119/120/131/132 precedent. The chains are verbatim.

**Total deviations:** 7 (1 plan-truth addition, 2 spec measurements, 4 process notes). **Impact:** none on the contract's meaning or on v1-R11 behaviour.

**Not done by design:** the STATE, ROADMAP and REQUIREMENTS writer steps were skipped, per the orchestrator's hard constraints. WINDOWS.md was not appended: there are no stubs, skipped tests or unrun verifies.

## Known Stubs

None.

## Threat Flags

None.
- **T-253-306:** mitigated. 134 is halted with `requireReceipts: true` and its six receipts are at PRESERVATION-R12 bytes. No row names 134 or 135 as owner; the builder throws on a halted or unstarted owner; seventeen halted is asserted through the real SDK.
- **T-253-307:** mitigated. v1-R11 check-only passed before and after; the R11 lineage pin is 921c3500; 253-132's receipts are read from its own commit; a rewritten pinned plan is refused on the copy.
- **T-253-SC:** no new dependency.

## Notes for 253-143 and later

- **Product source is unchanged.** This plan touched only .planning files (the helper, its test and the R12 contract). After Task 3:
  - `ci-git-publication.py --validate-frozen-source ded90ae9c5455d6dc69a68a34a99eb900006c0f5` reports frozen_source matches, head 8e4740061, planning_only_movement true, product tree 62058134606110982f003deaa80c8bb571b4e2fe;
  - `ci-gate-canary.sh --check-only --revision-freeze FREEZE-R12` exits 0.
- **Pinned bytes.** The R12 contract pins byte-for-byte:
  - PLANs 01-145;
  - 71 SUMMARYs through 141 (excluding the never-written 135);
  - the six -R11-PROBE records and the eleven 253-133 R11 canary records;
  - the receipts of every completed and halted plan as recorded in the contract (for example the phase-dir files that 253-125..141 list in key-files).

  Later plans must not edit any of them. The 142-145 SUMMARYs are not pinned. If a later plan must touch a phase-dir file that a 125-141 SUMMARY lists, `--revision r12 --check-only` will fail; that needs the freeze pattern used here.
- **Ownership:**
  - 253-143 owns the canary rows (23, 33, 45, 54, 66, 76, 86) and is in the halted proof for 07, 12, 92, 104, 113, 122 and 134.
  - 253-144 owns the PR rows, including 93, 98, 105, 114, 123 and the 134 line (08 -> 42, 144).
  - 253-145 runs `--revision r12` dry-run, prepare and apply after a real `--require-dispositioned` completion, and the bundle needs 253-145's own final SUMMARY.
- **Verification status:** whole-phase verification stays `not_started`.

## Invariants

- `git status --short` shows only ` M .planning/config.json`.
- config.json sha256 is `8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d`.
- state.json is 70229 bytes with sha256 prefix `e45278c2cee0`.
- STATE.md, state.json, ROADMAP.md, REQUIREMENTS.md and HANDOFF.json are untouched (`git diff f503034ac HEAD` over them is empty). No GSD writer verb was run; only read-only `phase-plan-index`, `init.execute-phase` and `verification status` (inside check-index and on temporary copies).
- No disposition SUMMARY was written to the real phase directory.
- `scripts/ci/__pycache__` is absent; it was removed after every python run.
- `shasum -a 256 -c PRESERVATION-R12.sha256` exits 0. FREEZE-R12 (fd1a27cb…) and PUBLICATION-R12 (151765e5…) are unchanged. Local `refs/remotes/origin/main` is still 09df342a82e03c3d5d40173c912b70e827f7eadc.
- Zero GitHub requests.

## Self-Check: PASSED

- The R12 contract, the helper, the test and this SUMMARY exist.
- Commits `f228601b2`, `fa2b080e2` and `8e4740061` are ancestors of HEAD. No commit deleted a file.
- `commits` was measured as 3 from the ledger base `f503034ac`.
