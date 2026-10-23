---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "70"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, runner, approval, r4]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-69 R4 ledger/history/freeze, controlContextIdentitiesR4 and per_row_union validator mode"
provides:
  - "R4 run, prepare, evidence verify and approval record/read in scripts/ci/ci-registration-recovery.mjs"
  - "LOAD_PATHS binding of completion load links to the R4 native evidence and acceptance evidence"
affects: [253-72, 253-73, 253-78]
actuals:
  tokens: 52000
  tasks: 3
  commits: 2
plan_head_before: 081e6b6a047a9305c21bcfc8b44f4345a91f13e1
plan_head_after: 29fead1092b27d67b6cc8b4fe5e0e7a8fbbdd20e
tech-stack:
  added: []
  patterns: ["additive revision block cloned from R3 by text transform; shared R3 accounting/host/diagnostics predicates reused", "defense-in-depth schema+caps check on the approval object even when injected"]
key-files:
  created: []
  modified:
    - scripts/ci/ci-registration-recovery.mjs
    - scripts/ci/ci-registration-recovery.test.mjs
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py
key-decisions:
  - "R4 infrastructure retry opens only on a proven host fault (suspension or lost caffeinate holder). R3's 'host_failure' cause (rows 0 with setup.error) is dropped, so a setup failure without suspension is always terminal."
  - "Run refuses any approval object that is not schema v3 with the exact R4 caps, in addition to the default reader's committed-bytes/hash checks."
  - "Tasks 1 and 2 share one commit because the R4 run path, approval gates and verifier are one cloned block; tests were red against the previous runner (21 of 35 R4-named tests failed, 4/4 new run tests failed)."
requirements-completed: ["CIREL-01", "CIREL-02"]
duration: "~70min"
completed: 2026-10-14
status: complete
coverage:
  - id: D1
    description: "R4 run path judges rows per row (mirrored annotations accepted at --stage first, genuine reuse halts non-infrastructure) with separately bounded and charged setup and deduplicated lifecycle.context_ids"
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#R4 accepts a mirrored-annotation first slot at --stage first and records per-row deduplicated context ids, not the doubled list"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#R4 halts a genuine cross-row context reuse as a non-infrastructure halt with per-test rows, charged and counted"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#R4 runs all four regular slots once in order and verifies the complete 22-row proof"
        status: pass
    human_judgment: false
  - id: D2
    description: "R4 approval binding, host probe before predebit, single-use gated CR4-INFRA-RETRY, per_test_rows on every halt, terminal evidence verification after later runner commits"
    requirement: CIREL-02
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#an R4 run needs a committed v3 approval bound to the R4 budget and freeze, and the R3 approval is refused"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#the R4 retry is never available after an assertion failure, a setup failure without suspension, a non-suspension overrun, a second infrastructure halt or approve-without-retry"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#R4 accepted evidence verifies by git ancestry and object reads after a later committed runner change, while a live check still demands the working tree"
        status: pass
    human_judgment: false
  - id: D3
    description: "Completion verifier accepts load_controls only at the R4 native evidence and load_acceptance only at the acceptance evidence under the production checker"
    requirement: CIREL-02
    verification:
      - kind: unit
        ref: "scripts/ci/ci-hosted-gate-verify.test.py#CompletionLoadLinkBindingTests"
        status: pass
    human_judgment: false
---

# Phase 253 Plan 70: R4 runner run path, approval binding and completion load-link binding Summary

**Additive R4 runner (setup-phase run, per-row union context identity, v3 approval binding, gated single-use retry, terminal git-object verification) plus a fail-closed binding of the completion verifier's load links to the R4 artifacts.**

## Accomplishments
- Task 1 and 2: `verifyNativeLoadAttemptR4`, `verifyLoadRecoveryEvidenceDataR4`, `verifyLoadRecoveryFileR4` (exported), `prepareLoadRecoveryR4`, `recordBudgetApprovalR4`, `readCommittedApprovalR4`, `runLoadRecoverySlotR4` and `runHeldLoadRecoverySlotR4`. They replace the 253-69 placeholders `readCommittedApprovalPendingR4` and `verifyLoadRecoveryFileR4`. The R4 branch is matched before the R3 branch in `--record-budget-approval`, and prepare, run and verify route by exact R4 path. The R3 accounting, host-awake and diagnostics predicates are reused unchanged.
- `lifecycle.context_ids` is written through `controlContextIdentitiesR4` (per-row deduplicated). The synthetic harness mirrors annotations at both report levels, so the first slot is accepted at `--stage first`, and one id shared by two rows halts with the exact reuse message, `per_test_rows` and status `halted`.
- Task 3: `LOAD_PATHS` and `LOAD_PATH_ERRORS` in `ci-hosted-gate-verify.py`. Applied only when `load_checker is None`, before the file is read and before the checker is invoked. `LINKS` and `LOAD_CHECKS` are untouched, and a test asserts the exact two argv lists.
- Completion runs use the production checker, which resolves `node` via PATH, so they must put `$HOME/.asdf/installs/nodejs/20.18.1/bin` first on PATH (253-78 does).

## Task Commits
1. Tasks 1 and 2 (runner + tests): `8c33e484e` (feat)
2. Task 3 (verifier + tests): `29fead109` (feat)

Red-first evidence: the new R4 tests were run against the previous runner copied from HEAD (0 of the 4 new run tests passed; 21 R4-named tests failed) and the 6 new verifier tests failed against the previous verifier, before the green runs below.

## Test results
- `ci-registration-recovery.test.mjs` + `ci-playwright-load.test.mjs`: 195/195 pass (baseline 168; +27 R4 tests, R3 assertions unchanged). With `ci-registration-control-audit.test.mjs` and `p17-no-playwright-retry-wrapper.test.mjs`: 209/209.
- `python3 scripts/ci/ci-hosted-gate-verify.test.py`: 44/44 (baseline 38, +6). `scripts/ci/__pycache__` deleted.
- Reconcile `--prepare-contract --check-only` (default, r2, r3, r4, run from repo root): all exit 0, so no pinned file drifted and nothing was regenerated.
- `.planning/config.json` sha256 `8e312f6ccd34...` unchanged. No STATE, ROADMAP, REQUIREMENTS or state.json writes.

## Decisions Made
- Dropped R3's `host_failure` infrastructure cause for R4 (see key-decisions). R4 infrastructure is `host_sleep` or `holder_lost` only, so the plan's rule 'never after a setup failure without suspension' holds. A setup suspension still opens the retry.
- The run itself rejects any approval that is not schema v3 with exact R4 caps. The injected-reader test showed the R3-shaped approval slipped through the decision-only check.

## Deviations from Plan

**1. [Rule 2 - Missing critical] Run-time approval schema and caps check**
- **Found during:** Task 2 (new test 'an R3 approval handed to the R4 run is refused', initially failing).
- **Issue:** the run accepted any approval object whose `decision` was recognised, so an R3-shaped record passed through an injected or future reader.
- **Fix:** `runLoadRecoverySlotR4` now requires `schema_version === LOAD_R4_APPROVAL_SCHEMA` and caps equal to the R4 table.
- **Commit:** 8c33e484e

**2. [Process] Tasks 1 and 2 in a single commit; tests written after the cloned code**
- The R4 run path was produced by a text transform of the R3 block and the matching tests by a transform of the R3 tests, so the two tasks were not separable. Red-first was established afterwards by running the new tests against the HEAD runner (all new run-path tests failed there).

**Total deviations:** 1 auto-fixed (Rule 2), 1 process note. **Impact:** none on frozen R2/R3 behavior; R3 test assertions are unchanged.

## Issues Encountered
- One R3 first-slot test (`a synthetic R3 first slot ...`) failed once during a mid-edit run and passed on every later full run; it is timing-bound (wall/monotonic bounds) and was not touched. Worth watching for flakiness under load.

## Known Stubs
None.

## Threat Flags
None. T-253-136 and T-253-137 are mitigated as planned (committed matching R4 approval required, R3/R2 approvals refused, host probe before predebit, single-use gated retry, min(freeze, approval) caps; load links bound to R4 artifacts before the checker runs).

## Next Phase Readiness
- 253-72 can commit the R4 freeze, and Jon's R4 approval record can then be written with `--record-budget-approval` on the R4 doc and freeze.
- Remaining and not done here: the R4 freeze commit and evidence init (253-72), any native run (253-73), completion wiring (253-78). Full Phase253 verification stays not_started.

## Self-Check: PASSED
- Runner, test, verifier and verifier-test files modified; commits 8c33e484e and 29fead109 are ancestors of HEAD; suites green as listed above.
