---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "69"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, validator-fix, re-freeze, r4]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "halted 253-63 R3 lineage (evidence, freeze, approval, budget, summary, raw receipts)"
provides:
  - "controlContextIdentitiesR4 / crossRowContextReuseR4 and the opt-in per_row_union mode of verifyNativeLoadAttempt"
  - "faithful excerpt fixture of the preserved R3 CR3-DESKTOP-MOBILE-FIRST report"
  - "R4 ledger (2222537 ms / 8 launches / 9 spent), R3-lineage history reader, freeze create/validate/check, evidence init, path routing"
affects: [253-70, 253-71, 253-72, 253-73]
actuals:
  tokens: 60000
  tasks: 2
  commits: 5
plan_head_before: faf89508db040b3e5e43e191c85318ddfbaf99bf
plan_head_after: b6b430870a9848a3bd9c37a45f89965123d1ccdf
tech-stack:
  added: []
  patterns: ["opt-in options parameter keeps frozen revisions byte-compatible", "additive revision block beside R3"]
key-files:
  created:
    - scripts/ci/fixtures/r3-mirrored-context-annotations.json
  modified:
    - scripts/ci/ci-registration-recovery.mjs
    - scripts/ci/ci-registration-recovery.test.mjs
key-decisions:
  - "Per-row context ids are the deduplicated union of test-level and result-level annotations; dedupe never crosses rows"
  - "R4 ledger lists every expired and retired identity of all earlier revisions plus CR3-INFRA-RETRY and CR3-*-SECOND"
  - "R4 approval binding and R4 verify/run are left to 253-70; init without an injected approval reader refuses before writing"
requirements-completed: ["CIREL-01", "CIREL-02"]
duration: "~75min"
completed: 2026-10-14
status: complete
coverage:
  - id: D1
    description: "R4-only per-row union context identity: accepts the mirrored R3 excerpt (16 rows, 18 distinct ids), still rejects cross-row reuse"
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#R4 per-row union gives 18 distinct ids on the preserved R3 excerpt and reports no cross-row reuse"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#a mirrored R3 first slot is rejected by the frozen R3 and legacy verifiers but accepted by per_row_union"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#per_row_union still fails a genuine cross-row reuse injected into the mirrored first slot"
        status: pass
    human_judgment: false
  - id: D2
    description: "R4 ledger, R3-lineage history reader and freeze/init with caps equal to the R4 budget document"
    requirement: CIREL-02
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#R4 freeze creation, check and init produce a ready ledger whose caps equal the R4 budget document"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#the R4 history reader reads the real preserved R3 lineage and reaches the 2222537 ms ledger"
        status: pass
    human_judgment: false
---

# Phase 253 Plan 69: Context-identity validator fix and R4 ledger/history/freeze Summary

**R4-only per-row union context identity (red-first on a faithful excerpt of the preserved R3 report) plus an additive R4 ledger, R3-lineage history reader and freeze/init revision carrying 2222537 ms, 8 launches and 9 spent identities.**

## Accomplishments
- Task 1: `controlContextIdentitiesR4` and `crossRowContextReuseR4` added; `verifyNativeLoadAttempt(attempt, freeze, baseDir, {contextIdentity: 'per_row_union'})` routes only the per-row presence/format check and the cross-row check through them. The default path is unchanged, so the v1, R2 and R3 verifiers still reject the mirrored report with "two selected rows reused the same browser-context identity" (asserted). `playReportTests` is now exported.
- Fixture `scripts/ci/fixtures/r3-mirrored-context-annotations.json`: 16 rows, both annotation arrays verbatim, provenance sha256 `ef73675158c0e260eefff8d0d3b672cb63546dc7da74fc1d49c556f46a62f53c` (equals the preserved report). Legacy flatten yields 36 ids with duplicates; R4 yields 18 distinct (2 for each of the three collision rows, 1 for the other control rows, 0 for the dark board).
- Task 2: R4 constants (freeze v4, evidence v4, approval v3, five paths), `loadRecoverySlotDefinitionsR4`, `buildLoadRecoveryLedgerR4` (14 charges, 8 launches, nine spent, preparation 5963), `readLoadHistoryR4` (re-hashes R3 evidence, freeze, approval, budget, 253-63-SUMMARY and every referenced and unreferenced R3 raw file; reuses `readLoadHistoryR3`), `createLoadRecoveryFreezeR4`, `validateLoadRecoveryFreezeR4`, `initializeLoadRecoveryEvidenceR4`, and `--create-load-recovery-r4` plus path routing of check/init/verify.
- Cap table equals the R4 budget document: approve 910000 / 3132537 / 13 / 5472537 / 22; approve-without-retry 670000 / 2892537 / 12 / 5232537 / 21.

## Task Commits
1. Baseline fix (deviation): `9d7025153` (test)
2. Task 1 RED: `90e6fec7b` (test); GREEN: `534626141` (feat)
3. Task 2 RED: `b3b276bb8` (test); GREEN: `b6b430870` (feat)

## Test results
- `ci-registration-recovery.test.mjs` + `ci-playwright-load.test.mjs`: baseline 148 tests with 1 failing (pre-existing, see deviation); final 168 tests, 168 pass, 0 fail, 0 skipped.
- Pinned bytes verified unchanged: R3 evidence/freeze/approval/budget, 253-63-SUMMARY, R2 freeze. `--verify-load-recovery` on R3 and R2 evidence exits 3 with their own labelled rejection and no crash text.

## Call-site audit decisions (Task 1)
- ~1927 / ~2589 `transport_observations` writers (older control paths): informational, frozen; left as is.
- verifyNativeControlAttempt per-row presence/format (~2319/2323): duplicate-invariant; left.
- Result-annotation parses via `find` (~2340/2349/~3503: fresh-state, collision, refill/readiness): duplicate-invariant; left.
- verifyNativeControlAttempt cross-row check (~2356-2357, older 253-15/16 verifier): same latent defect, but its revisions are terminal and never run again. Left frozen; disclosed as a known latent defect.
- Shared verifyNativeLoadAttempt per-row (~3485) and cross-row (~3525-3526) checks: fixed only under `per_row_union`; R2/R3 stay frozen.
- `lifecycle.context_ids` writers (~3748/4377/5292): informational doubled lists, no verifier reads them; left. The R4 writer in 253-70 must record per-row deduplicated ids via `controlContextIdentitiesR4`.

## Decisions Made
- R4 `expired_identities`/`retired_identities` accumulate across revisions (CR2-INFRA-RETRY, CR3-INFRA-RETRY; CR-*-SECOND, CR3-*-SECOND) so 253-70 can refuse every closed identity from one list. The terminal-halt record lists only the R3 ones, per the plan.
- `initializeLoadRecoveryEvidenceR4` has no default approval reader: the R4 approval binding is 253-70's. Without an injected reader it throws before writing (tested). 253-70 should replace `readCommittedApprovalPendingR4` and `verifyLoadRecoveryFileR4` (both clean-rejection placeholders) rather than redefine the exports.
- Refusal of a spent/expired/retired identity at run time is 253-70 (no R4 run function exists yet). Here, the ledger builder rejects any non-exact spent inventory and no R4 slot id collides with a closed identity (tested).

## Deviations from Plan

**1. [Rule 1 - Bug] Pre-existing failing R3 approval-recorder CLI test**
- **Found during:** baseline run before Task 1
- **Issue:** `the approval recorder CLI routes the R3 freeze path...` asserted the R3 approval file does not exist, but Jon's R3 approval was committed in 253-63, so the suite was red before this plan started.
- **Fix:** record the file's bytes (or absence) before the reject run and assert they are unchanged afterwards; the reject-writes-nothing contract is kept.
- **Files modified:** scripts/ci/ci-registration-recovery.test.mjs
- **Commit:** 9d7025153

**2. [Rule 3 - Blocking] `playReportTests` exported**
- The plan requires parsing the excerpt "through playReportTests"; the function was module-private, so the keyword `export` was added (no behavior change). Included in `534626141`.

**Total deviations:** 2 auto-fixed (1 bug in a stale test assertion, 1 blocking export). **Impact:** none on frozen behavior.

## Issues Encountered
None. No Playwright CLI, psql, caffeinate or GitHub request was made.

## Known limitations / remaining for 253-70..72
- The R3 freeze check (working-tree equality) no longer passes because the runner and test were changed; expected per the execution contract. The R3 lineage is protected by byte identity.
- R4 run, prepare, verify, approval record/binding and retry gates: 253-70. R4 freeze creation and commit: 253-72.
- Out-of-scope follow-ups recorded, not acted on: review the `:pending_email` change-email path for the same `unsafe_unique` enumeration leak fixed in 253-57; phase verification after 253 closes (not_started); re-applying the Claude-tier config after phase 253 (orchestrator-owned).
- `.planning/config.json` (sha256 8e312f6ccd34...) untouched; no STATE/ROADMAP/REQUIREMENTS writers run.

## Self-Check: PASSED
- Fixture, SUMMARY, test and runner files exist; commits 9d7025153, 90e6fec7b, 534626141, b3b276bb8, b6b430870 are ancestors of HEAD; full suites green (168/168).
