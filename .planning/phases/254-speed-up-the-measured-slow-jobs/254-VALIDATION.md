---
phase: "254"
slug: "speed-up-the-measured-slow-jobs"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-23"
---

# Phase 254 — Validation Strategy

Planning defines the checks below; none is recorded as executed by this document.

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Existing shell regressions, Node `node:test`, Python `unittest`, Playwright Test, Mix |
| Config | `test/example/priv/playwright/playwright.config.ts`; `.github/workflows/ci.yml` |
| Quick comparison command | `bash scripts/ci/ci-run-metrics-comparison.test.sh` |
| Quick coverage command | `node --test scripts/ci/ci-browser-records.test.mjs scripts/ci/ci-playwright-report.test.mjs` |
| Gate regression command | `python3 scripts/ci/ci-hosted-gate-verify.test.py` |
| Full local regression command | `bash scripts/ci/ci-run-metrics.test.sh && bash scripts/ci/ci-run-metrics-comparison.test.sh && node --test scripts/ci/ci-browser-records.test.mjs scripts/ci/ci-playwright-report.test.mjs scripts/ci/ci-measure-workflow.test.mjs && python3 scripts/ci/ci-hosted-gate-verify.test.py` |
| Runtime | Measure during execution; browser runs are longer integration checks |

## Sampling Rate

- After each task, run its focused automated check; run applicable controls after each wave.
- Run the full local regression command before collection and before phase verification.
- Resolve missing browser binaries and the local npm cache permission error with a task-scoped writable cache before real browser verification. Do not count collection families as development tests.
- Fast checks should return within 60 seconds where practical; real browser and hosted comparisons have separately bounded execution.

## Per-Task Verification Map

The planner must replace this requirement map with its concrete task IDs and commands before the checker runs.

| Requirement | Behavior | Automated check | Status |
|-------------|----------|-----------------|--------|
| CISPEED-01 | Frozen schedule, source identities, 20 matched successful pairs, ordinary median threshold | `bash scripts/ci/ci-run-metrics-comparison.test.sh` plus real recorded comparison | Pending |
| CISPEED-02 | Empirical p95, all-attempt runner cost, exact useful-case/project/status parity | Comparison regression, native browser records and report tests plus real recorded comparison | Pending |
| Both | Existing required owner names and honest failure/cancel/missing/unexpected-skip behavior | Workflow and hosted-gate verifier regressions | Pending |

## Wave 0 Requirements

- Extend existing comparison fixtures for frozen order/proximity, nonreplacement, incompatible conditions, missing data, and all-attempt cost accounting.
- Extend existing native records for exact case/project identity and intentional versus unexplained skip/exclusion parity.
- Add focused checks for fixture isolation, standalone eligible tests, anonymous lockout, and unchanged invitation lifecycle.
- Add cold/warm/failure Mix preparation checks before selecting the combined invocation.
- Each new check must be created before the task that depends on it, inside a vertical plan; no separate evidence framework or new dependency.

## Hosted Acceptance

Use the unchanged Phase 252 comparison contract: 20 matched pairs, 40 primary real-PR families, predeclared all-warm allocation, compatible actual runner conditions and one 48-hour window. Resolve cache preparation and any separately authorized warm-up budget before collection. Freeze identities, schedule and proximity rule before starting. Retain failure/cancellation/retry costs and original families. Fewer than 20 valid successful comparable pairs is insufficient data; missing a threshold with 20 valid pairs is a miss. Neither establishes the phase speed target.

Local tests and synthetic comparisons prove behavior of the machinery only. They do not prove a speedup or authorize renewing any prior acceptance budget.

## Manual-Only Verifications

None planned. Use deterministic checks and bounded automation. If baseline/cache feasibility cannot be established within authorized work, save the concrete blocker and stop collection without marking it passed.

## Validation Sign-Off

- [ ] Every task has an automated command and explicit observable failure signal.
- [ ] New test paths have a creation task before use.
- [ ] No three consecutive tasks lack automated feedback.
- [ ] Focused browser runs and full retained gate controls pass before collection.
- [ ] Actual hosted inputs and comparison outcome are saved without replacing failed families.
- [ ] Execution evidence supports updating this document to validated.

Approval: pending execution evidence.
