---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "103"
subsystem: ci-reliability
tags: [gsd-sdk, completion, disposition, historical-disposition, r8]
requires:
  - phase: 253-102
    provides: R8 publication manifest and canary freeze (r8 ref pair)
  - phase: 253-96
    provides: R7 contract pattern, --require-dispositioned gating, R7 contract lineage
provides:
  - additive --revision r8 in the reconciliation helper (contract, dry-run, prepare, apply, check-index)
  - committed R8 reconciliation contract (46 never-executed responsibilities, 13 halted records, final owner 253-106)
  - three-digit plan id helpers (planIdOf, comparePlanIds, parsePlanFile)
affects: [253-104, 253-105, 253-106]
actuals:
  tokens: 53000
  tasks: 3
  commits: 3
plan_head_before: 02dc90be00c882f3a26f12d11d669e826b1da25a
plan_head_after: e0ad49f8cace0e0938b4083ea6d76504d6894173
tech-stack:
  added: []
  patterns: ["additive reconciliation revision over frozen earlier contracts", "tooling receipts frozen at the last owning commit's blobs", "numeric plan-id ordering for three-digit ids"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R8.json
  modified:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.mjs
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.test.mjs
key-decisions:
  - "R8 completed = R7 thirty-eight + 95, 96 (40); halted = R7 twelve + 97 (13); never-ran 98, 99; unstarted 46"
  - "OWNER_REMAP_R8 = {95: [95, 102], 96: [96, 103], 97: [104], 98: [105], 99: [103, 106]}, deduplicated in first-seen order (96 and 99 both map to 103)"
  - "Halted proof map = R7 map remapped through OWNER_REMAP_R8, plus 97 -> 100, 101, 102, 104"
  - "253-96 tooling receipts frozen at the blobs of commit a6ccee580, read with git"
requirements-completed: []
coverage:
  - id: D1
    description: "--revision r8 exists end to end with the 99-plan partition, --require-dispositioned gating and three-digit plan id handling; v1-r5 keep --require-accepted"
    requirement: "CIREL-02"
    verification:
      - kind: unit
        ref: "253-LOAD-RECOVERY-reconcile.test.mjs#R8 revision skeleton: partition, dispositioned gating, CLI and three-digit plan IDs"
        status: pass
    human_judgment: false
  - id: D2
    description: "R8 mapping, frozen receipts, pins and the real installed SDK pairing proof on temporary committed copies"
    requirement: "CIREL-01"
    verification:
      - kind: integration
        ref: "253-LOAD-RECOVERY-reconcile.test.mjs#R8 pairing through the real installed SDK on a copy of the current plan set"
        status: pass
    human_judgment: false
  - id: D3
    description: "Committed R8 contract; --check-only exits 0 for v1 and r2-r8; earlier contract hashes unchanged"
    verification:
      - kind: other
        ref: "node 253-LOAD-RECOVERY-reconcile.mjs --revision r8 --prepare-contract --output <R8> --check-only"
        status: pass
    human_judgment: false
duration: 13min
completed: 2026-10-15
status: complete
---

# Phase 253 Plan 103: R8 reconciliation contract Summary

**Additive `--revision r8` reconciliation: 46 never-executed responsibilities and 13 literal halted records are re-pointed to plans 100-106, gated by `--require-dispositioned`. It is proven against the real installed SDK on temporary copies, with three-digit plan ids handled end to end and a committed R8 contract whose final owner is 253-106.**

## Performance

- **Duration:** about 13 min (2026-10-15T18:25:52Z to 18:38:30Z)
- **Tasks:** 3
- **Files:** 3 (helper, its test, new R8 contract)

## Accomplishments

- **Partition:** R8 splits plans 01-99 into 40 completed (R7's 38 plus 95, 96), 13 halted (R7's 12 plus 97) and 46 never-executed (R7's 44 plus 98, 99). The builder throws if these stop partitioning 01-99.
- **Never-ran rows:** 98 and 99 carry `blocked_by ["253-97"]` and the R8 never-ran reason (the canary driver passed the whole regex match plus a literal `[1]` suffix as the check_runs commit_sha route parameter). Earlier rows keep their own reasons. Every row carries `successor_revision: R8`.
- **Owners:** only completed plans or R8 plans 100-106. Native is unchanged from R7. Completion is 43, 50, 61, 71, 81, 90, 96, 103, 106. Examples: 08 -> 42, 105; 22/85 -> 91, 95, 102; 86 -> 104; 88 -> 90, 96, 103, 106; 93/98 -> 105; 94 -> 96, 103, 106; 99 -> 103, 106. Tests assert that no owner (and no halted-proof owner) is halted or never executed, including 97-99.
- **Halted proof:** 92 -> 95, 102, 104. 07/12 -> 18, 19, 20, 42, 91, 95, 102, 104. 97 -> 100, 101, 102, 104.
- **Disposition text:** it says CIREL-02 is accepted by the linked completion evidence and CIREL-01 is recorded partial under Jon's not_reproduced disposition. A test asserts it never contains the R5 "CIREL-01 and CIREL-02 are accepted" sentence and never says CIREL-01 is or was accepted. `status: superseded`; `original_status: blocked` appears only as a frontmatter field.
- **Gating:** r6, r7 and r8 share the dispositioned-revision set. v1-r5 keep `--require-accepted` (test-asserted).
- **Three-digit ids:** the exported helpers `planIdOf`, `comparePlanIds` and `parsePlanFile` are unit-tested with 253-99, 253-100 and 253-106. The R8 plan pins are in numeric order (253-99 before 253-100). The R8 fixture copies PLANs 01-106 through the helper's matcher and asserts the count.

## Task Commits

1. **Task 1 (tracer): R8 skeleton, dispositioned gating, CLI, three-digit helpers** - `bacd185c3` (feat)
2. **Task 2: mapping, frozen receipts, pins, real-SDK pairing** - `6a898e019` (feat)
3. **Task 3: R8 contract** - `e0ad49f8c` (feat)

## RED counts

- **Baseline before edits:** exit 0, 89 tests, 89 pass.
- **Task 1:**
  - RED: `node --test` exit 1, 95 tests, 84 pass, 11 fail. The 11 failures are the 6 new R8 tests plus the 5 REVISIONS equality assertions.
  - GREEN: exit 0, 95 pass.
- **Task 2:**
  - RED: exit 1, 106 tests, 99 pass, 7 fail.
  - GREEN: exit 0, 106 pass, after the measured-SDK adjustment below.
- **Tracer gate:** the Task 1 `<verify>` was re-run end to end (suite plus r5-r7 `--check-only`) and passed before expanding.

## Hashes

- **R8 contract:** `a23aba456917fd295463f92304e595e16c405f628f0327681036efd1b9552c7b` (156813 bytes).
- **Unchanged earlier contracts,** re-checked after every task with `shasum -c`:
  - v1 `5eba0fad1a70ae70d073ac4d4c1d4cc4ab09d1c919e8f3a7f9b6e0daf5c1dfd5`
  - R2 `dc29b0963c4b6948bcb5a3b1c2cc058f84ea5b81da7364bafc7509f2448694ed`
  - R3 `6a50c6fe4b8a439778f0594c532a271dc7d1e1e8900c15d831693127c850333d`
  - R4 `2c3351381844664c887e016e3db16ef67674e1877472865c5616409acf060a7c`
  - R5 `f92fefe3f028de90112c9693ab5f1d7d769ab4087493f0fedbb39a46f7af1601`
  - R6 `4e7c33fe072e344f9b0c2f39065af50e99f7208c7c50afff788df564f3078f63`
  - R7 `8b077547940cf3ef953aaf5c539366e8cf506215a3502357f982ce45f2389df7`
- **253-96 frozen tooling receipts:** read with `git show` from `a6ccee580`, the last commit carrying `(253-96)` that touched each file (`git log -1 --grep='(253-96)' -- <file>`):
  - `253-LOAD-RECOVERY-reconcile.mjs` `6f64c8811e6a56460eb67cc4c55226cbc7d8db9bf9979374514311e9d8710911`
  - `253-LOAD-RECOVERY-reconcile.test.mjs` `dec1661dda1fc31693e8e31b218dbed24f5f6a3f0823dc2409bab89a5b27b1d0`
  - A test asserts both receipts equal the blob at that commit and differ from the live, now-edited files.
- **R8 freeze and publication, unchanged:**
  - FREEZE-R8 `3c07f4e35c3eea8b347f7019178cc2a71595eb2b2a26708382074eea8172cb25`
  - PUBLICATION-R8 `6ad1c2ee42160c1500f70430ce9d6b3709ba2471f98d15f3a67ca205ff80d893`
  - `ci-gate-canary.sh --check-only --revision-freeze <FREEZE-R8>` exits 0 before and after.
- **`--check-only` after this plan:** v1 and r2-r8 all exit 0. Two negative controls were run on a copy of the R8 contract with the final owner mutated to 253-99: the shape check exits 1, and `--check-only` exits 1.

## Contract contents

- 46 responsibilities, 13 halted plans (they include 253-92 and 253-97), 40 completed plans and 99 originals.
- 106 PLAN pins in numeric order.
- 39 summary pins: R7's 34, plus 96, 97, 100, 101, 102.
- Lineage pins for v1 through R7.
- Application block:
  - `accepted_only_predicate`: `scripts/ci/ci-hosted-gate-verify.py --mode completion --require-dispositioned`
  - `bundle_requires_final_summary_of`: `253-106`
  - `targets`: the forty-six previously nonexistent SUMMARY paths
  - `then_run` and `never` are the same as R7.

## --check-index report (r8, read-only, at generation time)

The CLI printed `{"ok":false,"route":"phase_stuck","old_unsummarized":46,"any_unsummarized":50}` (exit 1).

Full report:
- `sdk_ok` true and `halted_literal` true.
- `originals_intact` true and `dispositions_invalid` [].
- `verification_status` missing.
- The 50 unsummarized are the 46 responsibilities plus 253-103, 253-104, 253-105 and 253-106. 253-103 is this plan, so its SUMMARY did not exist yet.

This is the expected pre-disposition state.

## Real-SDK proofs (temporary committed copies only)

- **Now-state:** a copy of PLANs 01-106 with the real SUMMARYs through 97 plus 100-102.
  - The SDK lists all 106 plans, including 253-100..106.
  - 98 and 99 are incomplete and blocked behind 253-97, and 97 is halted.
  - 253-103 has no summary and is not halted.
  - `checkIndex` reports the 46 old unsummarized plans, plus 103-106.
- **Post-disposition:** simulated R8 superseded summaries for the 46, plus ordinary summaries for 103-106.
  - `incomplete` and `init.execute-phase` `incomplete_plans` are both empty.
  - Exactly 13 plans are halted, and they are the R8 halted list.
  - No summary has `status: blocked`.
  - `init.execute-phase` agrees with `phase-plan-index` on all 106 plans.
  - `checkIndex` is ok, with route `resume_phase_gates`.
- **Refusals:**
  - A `status: blocked` 253-105 owner summary is refused.
  - A rewritten 253-104-PLAN.md is refused.
  - Neither refusal wrote 253-98-SUMMARY.md.
  - The builder refuses a missing 253-104 or 253-106 PLAN. Positive control: the same clone builds before the removal and after the file is restored.

## Deviations from Plan

**1. [Rule 1 - Spec mismatch] The SDK derives `wave` from depends_on, and 103-106 do not inherit a 97 block**
- **Found during:** Task 2 (real-SDK now-state test)
- **Issue:** the installed SDK 1.16.0 does not echo the frontmatter wave. 253-100 declares wave 18, but `phase-plan-index` reports 15, the same as 253-97, which has the same dependencies. As in R6 and R7, `blocked_by` propagates through depends_on past summarized plans: 103-106 report `["253-84", "253-92"]`, and `runnable` is `[]`.
- **Fix:** the test asserts the measured facts instead:
  - wave is numeric, equal to 97's, and 101 is one higher;
  - depends_on is literal;
  - 103-106 inherit only the 84 and 92 blocks and are not halted;
  - 253-103 is the next explicitly dispatched plan.

  Helper behaviour is unchanged.
- **Files modified:** test file only
- **Committed in:** `6a898e019`

**2. [Rule 3 - Blocking] One earlier-suite literal beyond REVISIONS had to change**
- **Found during:** Task 1
- **Issue:** the R7 skeleton CLI test probed `--revision r8` as the unknown revision. Adding r8 makes that probe valid, so the assertion would fail by construction.
- **Fix:** the probe now uses `r9`, as the R2 suite already does. The assertion still checks that an unknown revision exits 2 with "unknown revision". No other earlier-suite assertion changed besides the five REVISIONS lists.
- **Committed in:** `bacd185c3`

**3. [Rule 3 - Blocking] A separate three-digit fixture**
- **Issue:** `worldFixture` matches only two-digit plan files.
- **Fix:** instead of editing the shared helper, the R8 suite adds `r8Fixture`, which uses the helper's `parsePlanFile` (two or three digits) and asserts every PLAN 01..maxPlan was copied. `r7Fixture` and the earlier fixtures are untouched.

**Total deviations:** 3. **Impact:** none on the contract or on v1-R7 behaviour.

## Issues Encountered

None. No product file, STATE.md, state.json, ROADMAP.md, REQUIREMENTS.md or HANDOFF.json was touched. No disposition SUMMARY was written to the real phase directory, and no GSD writer verb, GitHub request, push or fetch was used. `.planning/config.json` stays dirty, unstaged and byte-identical (sha256 prefix `8e312f6ccd34`). `state.json` is 70229 bytes (sha256 prefix `e45278c2cee0`). `scripts/ci/__pycache__` was removed after every run. 253-98 and 253-99 were not executed; this plan only maps them.

## Known Stubs

None.

## Next Phase Readiness

- **253-104 (hosted canary on the r8 ref pair):** the R8 contract pins every PLAN 01-106 and SUMMARYs 96, 97 and 100-102 byte-for-byte. 104 must not edit any of those. Its own SUMMARY is not pinned. 104 owns the canary rows (23, 33, 45, 54, 66, 76, 86) and part of the halted proof for 92, 97, 07 and 12.
- **253-105:** owns the PR rows (08, 13, 21, 24, 30, 34, 46, 55, 67, 77, 87, 93, 98).
- **253-106:** runs `--revision r8` dry-run, prepare and apply after a real `--require-dispositioned` completion. The bundle needs 253-106's own final SUMMARY.
- **Contract regeneration:** `--check-only` for r8 regenerates from the live tree. Editing a pinned PLAN or SUMMARY, the R7 contract, or a receipt file of a completed or halted plan would make it fail. That includes 253-95's and 253-96's phase-dir receipts and 253-97's five R7 canary records.
- **Verification status:** whole-phase verification stays `not_started`.

## Self-Check: PASSED

- `253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R8.json`, the helper and the test exist.
- Commits `bacd185c3`, `6a898e019` and `e0ad49f8c` are ancestors of HEAD.
- `commits` was measured as 3 from the ledger base `02dc90be0`.
