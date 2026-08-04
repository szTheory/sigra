---
phase: 236-closeout-evidence-reconciliation
plan: 02
subsystem: testing
tags: [nyquist, validation, evidence-integrity, mix, playwright]
requires:
  - phase: 236-closeout-evidence-reconciliation
    provides: "Immutable-evidence contract from Plan 01."
provides:
  - "Fresh canonical validation audits for Phases 230, 231, and 232."
  - "Durable, fail-closed Phase 234 formatter diagnostic without a lifecycle promotion."
affects: [236-03, v1.47-milestone-audit]
tech-stack:
  added: []
  patterns:
    - "Validator lifecycle fields change only after the phase's retained deterministic coverage passes."
    - "A validator failure is recorded verbatim and stops later lifecycle work."
key-files:
  created: [.planning/phases/236-closeout-evidence-reconciliation/236-02-SUMMARY.md]
  modified:
    - .planning/phases/230-tier-1-critical-path-reclamation/230-VALIDATION.md
    - .planning/phases/231-gate-honesty-nightly-revival/231-VALIDATION.md
    - .planning/phases/232-playwright-economics-authenticate-once-then-shard/232-VALIDATION.md
    - .planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-VALIDATION.md
key-decisions:
  - "Retained observed GitHub receipts were not queried or recaptured; canonical local validator checks supplied the fresh audit."
  - "Phase 234 remains unpromoted because its required formatter gate reports Phase 235 drift."
patterns-established:
  - "Fail closed at the first validator failure and retain the generated diagnostic in the target VALIDATION artifact."
requirements-completed: []
coverage:
  - id: D1
    description: "Phases 230, 231, and 232 received fresh canonical lifecycle audits from passing deterministic evidence."
    verification:
      - kind: unit
        ref: "mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs"
        status: pass
    human_judgment: false
  - id: D2
    description: "Phase 234 formatter failure is preserved and blocks lifecycle promotion."
    verification:
      - kind: other
        ref: "mix format --check-formatted"
        status: fail
    human_judgment: false
duration: 7min
completed: 2026-08-04
status: blocked
---

# Phase 236 Plan 02: Canonical Lifecycle Reconciliation Summary

**Phases 230, 231, and 232 were canonically revalidated from retained deterministic evidence; Phase 234 is fail-closed on a formatter diagnostic in Phase 235 files.**

## Performance

- **Duration:** 7 min
- **Tasks:** 1.5/2 completed; Task 2 stopped at the Phase 234 validator gate.
- **Files modified:** 4 validation artifacts and this summary.

## Accomplishments

- Revalidated Phase 230 with its CI-metrics, docs-only, cache-key, ExUnit, and actionlint coverage; all checks passed.
- Revalidated Phase 231 with seven deterministic shell suites, the 66-test prohibition suite, and actionlint; all checks passed.
- Revalidated Phase 232 with its focused contract (6/0), planning suite (130/0, 12 skipped), and retry-zero Playwright inventory (393 tests in 21 files).
- Preserved the Phase 234 formatter failure in its canonical validation artifact without changing its lifecycle header.

## Task Commits

1. **Task 1: Canonically validate Phases 230 and 231** — `d93bb10a`
2. **Task 2 (partial): Canonically validate Phase 232** — `06f3734c`

## Verification

- `mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` passed repeatedly: 3 tests, 0 failures.
- Phase 230: `bash scripts/ci/ci-run-metrics.test.sh`, `bash scripts/ci/docs-only-classify.test.sh`, `bash scripts/ci/playwright-cache-key-guard.test.sh`, two focused Phase-230 contracts, and `actionlint -shellcheck= .github/workflows/ci.yml` passed.
- Phase 231: seven shell suites passed (11/0, 20/0, 8/0, 7/0, 11/0, 19/0, 7/0); `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` passed 66/0; actionlint passed for `ci.yml`, `ci-observe.yml`, and `playwright-github-pages.yml`.
- Phase 232: focused contract 6/0; planning suite 130/0 with 12 skipped; Playwright list 393 tests in 21 files.
- Phase 234: six focused planning contracts passed 41/0, then `mix format --check-formatted` failed on three Phase-235 planning tests. No later Phase-234 verification or lifecycle promotion was run.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Corrected an inferred nonexistent actionlint target during the Phase 231 audit**
- **Found during:** Task 1
- **Issue:** An extra historical workflow path, `.github/workflows/ci-release-please.yml`, does not exist.
- **Fix:** Re-ran actionlint only for the three repository workflows named by retained Phase 231 evidence.
- **Files modified:** None.
- **Verification:** Actionlint exited zero for all three actual workflow files.

**Total deviations:** 1 auto-fixed (Rule 3 blocking).
**Impact on plan:** No product or evidence change; the validator audit used only existing, evidenced targets.

## Issues Encountered

- Phase 234 is blocked by `mix format --check-formatted`. The exact generated diagnostic names `phase_235_fast_01_remeasurement_contract_test.exs`, `phase_235_terminal_ratification_contract_test.exs`, and `phase_235_fast_01_gap_closure_contract_test.exs`; it is retained in `234-VALIDATION.md`.
- Expected local Postgrex connection-refused startup noise accompanied filesystem-backed planning contracts; every reported passing ExUnit command exited zero.

## Next Phase Readiness

- Do not run Phase 236 Plan 03 or promote Phase 234 until the recorded Phase 235 formatter drift is resolved by its owner and `$gsd-validate-phase 234` succeeds.
- Phase 233 and 235 protected validation artifacts and all protected receipts remain unmodified; no CI/GitHub evidence lookup occurred.

## Self-Check: PASSED

- Commits `d93bb10a` and `06f3734c` exist in history.
- The 230, 231, and 232 validation artifacts exist and declare `status: validated`, `nyquist_compliant: true`, and `wave_0_complete: true`.
- The Phase 234 validation artifact retains the formatter diagnostic and does not declare `status: validated`.
- `git diff --check` passed before this summary was written.
