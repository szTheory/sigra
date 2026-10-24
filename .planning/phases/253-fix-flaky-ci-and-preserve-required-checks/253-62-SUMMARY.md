---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "62"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, re-freeze, r3]
requires:
  - phase: 253
    provides: 253-57 library fix, 253-58 control repair, 253-59 diagnostics, 253-60 R3 runner
provides:
  - Committed R3 native freeze pinning final product source, R2 lineage and the R3 budget doc
affects: [253-63]
actuals:
  tokens: 6000
  tasks: 2
  commits: 1
plan_head_before: 663a2423b6f839a627654ab563dd79c85e503967
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-FREEZE-R3.json
  modified: []
key-decisions:
  - "Freeze created from clean committed HEAD 663a2423b after a fully green offline gate; no capacity granted."
requirements-completed: ["CIREL-01", "CIREL-02"]
coverage:
  - id: D1
    description: "Offline chain green on exact committed HEAD before freezing"
    verification:
      - kind: unit
        ref: "node 20.18.1 --test ci-registration-recovery/ci-playwright-load/ci-registration-control-audit/p17 (162 pass, 0 fail)"
        status: pass
      - kind: integration
        ref: "mix test test/sigra/auth_test.exs + golden_diff_test + auth_ui_contract_test (85 tests, 0 failures)"
        status: pass
      - kind: integration
        ref: "test/example mix test --include example_app register_login_logout_test + registration_live_test (12 tests, 0 failures)"
        status: pass
    human_judgment: false
  - id: D2
    description: "R3 freeze committed; check exits 0; 27 blobs equal HEAD; budget sha bound; R2 lineage unchanged; R2 verify is a clean exit-3 rejection"
    verification:
      - kind: other
        ref: "ci-registration-recovery.mjs --check-load-recovery-freeze (exit 0)"
        status: pass
    human_judgment: false
duration: 15min
completed: 2026-10-14
status: complete
---

# Phase 253 Plan 62: R3 Native Freeze Summary

**R3 native load-recovery freeze committed on the offline-green fixed source, binding the R3 budget doc by sha256 and re-hashing the halted R2 lineage as spent, with no capacity granted.**

## Gate results (Task 1, HEAD 663a2423b)

- Predecessor commits ae40f7439 (57), d93b1cbf4 (58), c2b355482 (59), e908d41fa (60): all ancestors of HEAD.
- Node 20.18.1 suites (recovery, load, control-audit, p17 prohibition): 162 pass, 0 fail.
- Root ExUnit auth_test + golden_diff_test + auth_ui_contract_test: 85 tests, 0 failures (the latter two are the orchestrator drift advisory).
- Example smoke + registration LiveView: the plan's literal command runs with the `example_app` tag excluded (6 excluded, exit 0, vacuous). Re-ran with `--include example_app` as the positive control: 12 tests, 0 failures.
- Internal review of the four diffs: auth.ex duplicate-email detection now covers both `unsafe_unique` validation and the DB constraint, strips uniqueness entries when other errors coexist (enumeration-safe); playwright.config.ts diff has no retries/timeout/trace changes; no weakened collision expectation seen. No unresolved high finding.

## Freeze (Task 2)

- File: `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-FREEZE-R3.json`
- **sha256: effaef5139fff83a0b3cda6a2d7d9f36f4fac5888942f9dd151ed101b2216284**
- source.checkout_head 663a2423b6f839a627654ab563dd79c85e503967; 27 blobs, all equal `git rev-parse HEAD:<path>`; includes all three registration_live.ex sources, lib/sigra/auth.ex, admin-eval.spec.ts, registrationControls.mjs, failure-jsonl.mjs, ci-registration-recovery.mjs.
- Budget doc sha256 dabbcf59bab20a432d7fd328c2555180561b0beae02736476408e28196bed78c bound in freeze and equals the committed doc.
- R2 lineage unchanged: evidence be47d624..., freeze b26d5a0c..., approval d5c85aaa....
- `--check-load-recovery-freeze`: exit 0. R2 `--verify-load-recovery`: exit 3, "R2 native load recovery evidence rejected: frozen R2 source identity mismatch for scripts/ci/ci-registration-recovery.mjs", no crash text.

## Commits

- `d7589f64d` feat(253-62): R3 freeze.

## Deviations from Plan

None - plan executed exactly as written (the example_app positive control was an additive extra check).

## Remaining gaps

Approval record and R3 evidence belong to 253-63 (Jon's decision). No Playwright, native window or GitHub request was made. Full Phase253 verification stays not_started.

## Self-Check: PASSED
