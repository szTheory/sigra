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

The planner replaces this behavior map with exact task IDs, waves, created paths, threat IDs and commands before the plan-checker gate.

| Requirement | Behavior | Test type | Existing command or planned proof | Status |
|-------------|----------|-----------|-----------------------------------|--------|
| CIREL-01 | Legacy replay unchanged; actual failed producer/step selected before display cap | Offline contract | `bash scripts/ci/ci-run-metrics.test.sh`; legacy `--verify-baseline` with Phase 252 archive | pending |
| CIREL-01 | Registration condition reproduced on pinned source; readiness/state/trace negative controls | Browser integration | Freeze exact current spec/projects/order before results; scope trace capture | pending |
| CIREL-01 | Proven fix survives fresh targeted repeats | Browser integration | Three fresh invocations per affected project; conditional narrow ExUnit seeds 101/202/303 | pending |
| CIREL-02 | Unit smoke included in internal gate ownership | Offline contract | `bash scripts/ci/honest-skip-verdict.test.sh` | pending |
| CIREL-02 | Manifest describes actual body boundaries | Offline contract | p10/p21 Node tests plus exact mismatch negative fixture | pending |
| CIREL-02 | Exactly five producer records with complete expected native reports | Offline contract | New stdlib validator tests; missing/duplicate/identity/skip/report negative fixtures | pending |
| CIREL-02 | Failures, missing bodies and real cancellation prevent green | Hosted fixture | Six scenarios and separate verifier on sealed fixture ref | pending |
| CIREL-02 | All five required names pass on normal PR head/tested revision | Hosted integration | One production pull_request family; independently verified jobs/artifact origins | pending |

## Wave 0 Requirements

- Extend existing metrics contracts for late failure context, passing banner, expected negative output, partial jobs, changed hashes and truncation.
- Add stdlib producer-record/native-report validator and negative tests before workflow wiring.
- Add signal-controlled delayed/missing readiness, collision/isolation and first-failure trace controls before claiming a registration fix.
- Implement finite acquisition/reproduction/canary/PR budget ledgers and evidence verifier before hosted acceptance.
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
