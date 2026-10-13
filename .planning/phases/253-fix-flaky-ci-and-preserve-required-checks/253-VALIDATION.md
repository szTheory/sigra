---
phase: "253"
slug: "fix-flaky-ci-and-preserve-required-checks"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-13"
---

# Phase 253 — Validation Strategy

Planning contract only. No implementation, reproduction, repeat, canary or production PR acceptance is claimed.

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Existing Bash contracts, Node built-in test runner, Mix/ExUnit, Playwright 1.59.1 |
| Config files | `mix.exs`, `.github/workflows/ci.yml`, `test/example/priv/playwright/playwright.config.ts` |
| Quick run command | `bash scripts/ci/honest-skip-verdict.test.sh` |
| Library suite owner | `MIX_ENV=test mix ci` |
| Browser integration | Five existing isolated seams, selected commands unchanged, zero retries |
| Runtime | Contract duration unmeasured; measure during execution. Browser/hosted checks have separate finite budgets. |

## Sampling Rate

- Each task runs its relevant automated contract before its commit; no three consecutive tasks lack verification.
- Each wave runs affected contracts and applicable targeted checks. Run the full library suite once through its ordinary owner; reuse equivalent production PR integration coverage.
- Every runnable plan command names its observable failing direction.
- Planning checks do not execute future commands, and planned scripts must be created before use.
- No human-only verification, watch-mode tests, unbounded polling, or retry-until-green acceptance.

## Behavior Verification Map

The exact prior clean bytes were read back from commit c87dfb3b5ea73d64708537a3b43aafaa60348bf9 immediately before this scoped edit (SHA-256 f5e56c0382c6d4843d0a7e689b1db1acfe5de26427dc568b1961e785698804a5). The source audit retains that recovery identity. All rows are pending execution.

| Requirement | Task / wave | Created proof and behavior | Automated command or bounded run | Threat ref | Status |
|-------------|-------------|----------------------------|----------------------------------|------------|--------|
| CIREL-01 | 253-01 T1–T2 / W1 | 253-DIAGNOSIS.json corrects Test D/Test Z, keeps full replay and per-producer unknowns | `bash scripts/ci/ci-run-metrics.test.sh && bash scripts/ci/ci-run-metrics.sh --verify-baseline --source-bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --baseline .planning/phases/252-measure-current-ci/252-BASELINE.json` | T-253-01, T-253-02 | pending |
| CIREL-01 | 253-02 T1 / W1 | 253-REPRO-FREEZE.json precedes 253-REGISTRATION-EVIDENCE.json for all three projects | `bash scripts/ci/ci-registration-repro.test.sh && bash scripts/ci/ci-registration-repro.sh --run-frozen .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-REPRO-FREEZE.json --output .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-REGISTRATION-EVIDENCE.json` | T-253-03, T-253-04 | pending |
| CIREL-01 | 253-02 T2–T3 / W1 | Signal/state/trace negatives; cause-backed fix and fresh repeats or explicit gap | `bash scripts/ci/ci-registration-repro.sh --verify-controls .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-REGISTRATION-EVIDENCE.json`; then `--verify-acceptance` on same evidence | T-253-03, T-253-04 | pending |
| CIREL-02 | 253-03 T1–T2 / W1 | Unit smoke needs/result/verdict and failure/cancel/skip fixtures | `bash scripts/ci/honest-skip-verdict.test.sh` | T-253-05, T-253-06 | pending |
| CIREL-02 | 253-04 T1–T2 / W1 | Actual selected-body manifest/MAINTAINING parity and old aggregate mismatch fixture | `node --test scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs` | T-253-07, T-253-08 | pending |
| CIREL-02 | 253-05 T1–T2 / W1 | ci-browser-records.mjs exact five, empty/byte-variant/identity/report negatives | `node --test scripts/ci/ci-browser-records.test.mjs scripts/ci/ci-playwright-report.test.mjs` | T-253-09, T-253-10 | pending |
| CIREL-02 | 253-06 T1–T2 / W2 | ci.yml unique records and complete selected native reports reach aggregate | `node --test scripts/ci/ci-measure-workflow.test.mjs scripts/ci/ci-browser-records.test.mjs`; p10/p21 and honest-skip contracts | T-253-11, T-253-12 | pending |
| CIREL-02 | 253-07 T1–T2 / W3 | 253-CANARY-EVIDENCE.json holds six hosted outcomes and independent verifier | `bash scripts/ci/ci-gate-canary.test.sh`, `python3 scripts/ci/ci-hosted-gate-verify.test.py`; then bounded `ci-gate-canary.sh --scenario full-pass` and `--remaining-scenarios` | T-253-13, T-253-14 | pending |
| CIREL-01, CIREL-02 | 253-08 T1–T2 / W4 | 253-PR-EVIDENCE.json normal PR proof and 253-COMPLETION-RECORD.json honest statuses | `python3 scripts/ci/ci-hosted-gate-verify.py --mode pr --evidence .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-PR-EVIDENCE.json`; then completion mode on 253-COMPLETION-RECORD.json | T-253-15, T-253-16 | pending |

## Wave 0 Requirements

- W1/253-01 extends metrics contracts for late failure context, passing banner, expected negative output, partial jobs, changed hashes and truncation.
- W1/253-05 adds producer-record/native-report validator and negatives before W2/253-06 wiring.
- W1/253-02 adds signal-controlled delayed/missing readiness, collision/isolation and first-failure trace controls before any fix claim.
- W1/253-02 and W3/253-07 create separate finite acquisition/reproduction/canary ledgers and verifier before W4/253-08 production acceptance.
- Existing frameworks suffice; no dependency is added.

## Fixed Budgets and Acceptance

- At most three selected signatures. Additional selected diagnostics: at most 60 HTTP requests or 15 minutes, including retries/redirects.
- Reproduction: at most 10 targeted invocations or 20 minutes per signature, 60 minutes total. Stop deterministic failures to diagnose; preserve originals.
- Post-fix: three fresh invocations per affected project plus deterministic regression/negative controls; fresh app/database/context, not repeat-each alone.
- Six hosted canary scenarios: full pass, docs-only fixture, actual body failure, missing seam, unexpected skip, actual cancellation. At most one infrastructure-only rerun; 45 tiny jobs, 60 minutes, 120 requests including separate verifier.
- Production PR: one normal family plus at most one diagnosed infrastructure rerun; predeclare separate acquisition ceiling of 120 requests/60 minutes. PR head, tested merge/source and workflow identities remain distinct.
- One watcher per run, 60-second interval; stop core budget at 250 or less, and stop HTTP 403/429 until reset/retry time.
- An exhausted budget or unresolved selected registration failure remains `not_reproduced`, `diagnosis_incomplete` or a requirement gap. It cannot prove no flake. Independent gate work can continue.

## Manual-Only Verifications

None. All acceptance is automated; unavailable evidence remains a recorded gap.

## Validation Sign-Off

- [ ] Exact task verification map and creation dependencies populated.
- [ ] Every task has automated verification and observable failure criteria.
- [ ] Negative controls check actual expected nonzero/cancelled outcomes.
- [ ] No missing report, trace, source identity or diagnostic is treated as passing.
- [ ] Wave 0 dependencies satisfied by implementation.
- [ ] Local, browser and hosted checks executed under frozen limits.
- [ ] `nyquist_compliant: true` set only by subsequent validation with execution evidence.

**Approval:** Pending execution evidence; this file is a planning contract.
