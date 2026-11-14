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

All rows are planned and unexecuted. A command naming a new file or flag is used only after that task creates it. Every task's PLAN also contains an immediately following `fails_when` condition; CLI exit zero alone never establishes the speed target.

| Task ID | Wave | Requirement | Behavior | Automated check | Status |
|---------|------|-------------|----------|-----------------|--------|
| 254-01-01 | 1 | Both | Frozen source/ref/archive/blob feasibility | `node --test scripts/ci/ci-baseline-source-preflight.test.mjs && node scripts/ci/ci-baseline-source-preflight.mjs --root . --contract .planning/phases/252-measure-current-ci/252-COMPARISON-CONTRACT.json --bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --output .planning/phases/254-speed-up-the-measured-slow-jobs/254-SOURCE-READINESS.json && bash scripts/ci/ci-run-metrics.sh --verify-baseline --source-bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --baseline .planning/phases/252-measure-current-ci/252-BASELINE.json` | Unexecuted |
| 254-01-02 | 1 | Both | Actual preparation components, real exits and scoped cleanup | `node --test scripts/ci/ci-prep-profile.test.mjs && node scripts/ci/ci-prep-profile.mjs --root . --scope admin_behavior --mode current --output .planning/phases/254-speed-up-the-measured-slow-jobs/254-PREP-PROFILE.json` | Unexecuted |
| 254-02-01 | 2 | Both | Real CLI exact native identity/status tracer | `node --test scripts/ci/ci-browser-records.test.mjs scripts/ci/ci-playwright-report.test.mjs` | Unexecuted |
| 254-02-02 | 2 | Both | All-owner project/skip/exclusion and origin parity | `node --test scripts/ci/ci-browser-records.test.mjs scripts/ci/ci-playwright-report.test.mjs && python3 -B scripts/ci/ci-hosted-gate-verify.test.py` | Unexecuted |
| 254-03-01 | 2 | Both | Real auth→fresh context→original presentation case | `node --test scripts/ci/ci-admin-theme-prep.test.mjs && node scripts/ci/ci-admin-theme-check.mjs --root . --mode tracer --output .planning/phases/254-speed-up-the-measured-slow-jobs/254-ADMIN-THEME-CHECK.json` | Unexecuted |
| 254-03-02 | 2 | Both | Individual/file/backend/anonymous lockout and auth-file controls | `node --test scripts/ci/ci-admin-theme-prep.test.mjs && node scripts/ci/ci-admin-theme-check.mjs --root . --mode all --output .planning/phases/254-speed-up-the-measured-slow-jobs/254-ADMIN-THEME-CHECK.json && node --test scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` | Unexecuted |
| 254-04-01 | 2 | Both | Real new-invitee lifecycle in both projects | `node --test scripts/ci/ci-org-prep.test.mjs && npm --prefix test/example/priv/playwright test -- tests/organizations.spec.ts --grep "organization invitations: new user accepts through the mailbox signup path" --project=chromium --project=mobile --retries=0` | Unexecuted |
| 254-04-02 | 2 | Both | Complete original organization file and standalone cases | `node --test scripts/ci/ci-org-prep.test.mjs && npm --prefix test/example/priv/playwright test -- tests/organizations.spec.ts --project=chromium --project=mobile --retries=0 && node --test scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` | Unexecuted |
| 254-05-01 | 2 | Both | Proved setup deduplication through actual library contributor path | `node --test scripts/ci/ci-prep-semantics.test.mjs scripts/ci/ci-measure-workflow.test.mjs && MIX_ENV=test mix ci` | Unexecuted |
| 254-05-02 | 2 | Both | Real cold/warm/migration/seed/failure composition and caches | `node --test scripts/ci/ci-prep-semantics.test.mjs scripts/ci/ci-prep-profile.test.mjs && bash scripts/ci/playwright-cache-key-guard.test.sh && node scripts/ci/ci-prep-profile.mjs --root . --scope admin_behavior --mode compare-preparation --output .planning/phases/254-speed-up-the-measured-slow-jobs/254-SETUP-CHECK.json` | Unexecuted |
| 254-06-01 | 3 | Both | Frozen balanced schedule/proximity and early registration | `python3 -B scripts/ci/ci-metrics-security.test.py && bash scripts/ci/ci-run-metrics-comparison.test.sh` | Unexecuted |
| 254-06-02 | 3 | Both | All-attempt costs and ordinary median/p95/verdict math | `bash scripts/ci/ci-run-metrics-comparison.test.sh && node --test scripts/ci/ci-run-metrics-replay.test.mjs && bash scripts/ci/ci-run-metrics.test.sh` | Unexecuted |
| 254-06-03 | 3 | Both | Authenticated raw-family derivation and finite acquisition | `bash scripts/ci/ci-run-metrics-comparison.test.sh && node --test scripts/ci/ci-run-metrics-replay.test.mjs && python3 -B scripts/ci/ci-metrics-security.test.py && python3 -B scripts/ci/ci-hosted-gate-verify.test.py` | Unexecuted |
| 254-07-01 | 4 | Both | All five optimized isolated owners end to end | `node --test scripts/ci/ci-prep-profile.test.mjs scripts/ci/ci-browser-records.test.mjs` and pinned Node20.19.5 `ci-prep-profile.mjs --mode workload`; final source-bound assembly reused unchanged `test/example` and workflow inputs | Passed: 45 focused tests; five isolated owners profiled; 108 exact rows compared, 105 product + 3 setup, all passed. Native report byte-tamper replay returned blocked (exit 2); evidence transfer and validation duration counters are now checked. |
| 254-07-02 | 4 | Both | Measured keep/move decision, exact mapping and gate policy | `node --test scripts/ci/ci-browser-records.test.mjs scripts/ci/ci-measure-workflow.test.mjs && bash scripts/ci/honest-skip-verdict.test.sh && bash scripts/ci/ci-run-metrics-comparison.test.sh` | Passed: exact identity/setup mapping, workflow owner contract, missing/blocked parity receipts rejected before network calls. Existing five owners retained. |
| 254-07-03 | 4 | Both | Retained controls and final review/readiness boundary | `bash scripts/ci/ci-run-metrics.test.sh && bash scripts/ci/ci-run-metrics-comparison.test.sh && node --test scripts/ci/ci-browser-records.test.mjs scripts/ci/ci-playwright-report.test.mjs scripts/ci/ci-measure-workflow.test.mjs scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs && python3 -B scripts/ci/ci-hosted-gate-verify.test.py && bash scripts/ci/honest-skip-verdict.test.sh && bash scripts/ci/playwright-cache-key-guard.test.sh` | Passed: full retained suite; 53 Node tests, 153 verifier tests, honest-skip and cache-key guard. Code review found zero unresolved findings; Plan08 hosted prerequisites remain open. |

## Plan 254-07 Nyquist Audit

| Behavior checked | Adversarial evidence | Result |
|------------------|----------------------|--------|
| Owner evidence cannot be relabeled after capture | Changed one candidate native report byte in a temporary copy while leaving the owner's recorded digest unchanged; `ci-prep-profile.mjs --mode workload` exited 2 with `native_artifact_digest_not_retained`. | Filled |
| Native evidence transfer validates and measures retained bytes | `ci-prep-profile.test.mjs` transfers a native file, checks exact byte count/SHA, and proves a wrong source digest throws before copy; comparison CLI timing is included in the workload parity result. | Filled |
| Native mapping keeps product and setup identities separate | `ci-browser-records.test.mjs` rejects setup/product cross-pairing and wrong-owner setup rows; actual 108-row comparison has 105 product rows and 3 design-gallery setup rows. | Filled |
| Collection requires a complete successful parity receipt | `ci-run-metrics-comparison.test.sh` verifies missing receipt digest and blocked owner-integration status both fail before GitHub requests or bundle creation. | Filled |
| Comparison family origin is repository-bound | `ci-hosted-gate-verify.test.py` refuses a wrong repository name and an artifact from a different repository ID. | Filled |

Audit command for the retained suite is the 254-07-03 command above; focused commands and the temporary-copy digest mutation check were also executed. No implementation edits were made by the Nyquist audit.
| 254-08-01 | 5 | Both | Source/real-PR/cache/image feasibility and frozen plan | `node scripts/ci/ci-baseline-source-preflight.mjs --root . --contract .planning/phases/252-measure-current-ci/252-COMPARISON-CONTRACT.json --bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --check-only && bash scripts/ci/ci-run-metrics.sh --validate-comparison-plan --contract .planning/phases/254-speed-up-the-measured-slow-jobs/254-COMPARISON-RUN-CONTRACT.json --format json` | Unexecuted; prerequisites unresolved |
| 254-08-02 | 5 | Both | Conditional extra preparation budget only | `bash scripts/ci/ci-run-metrics.sh --validate-comparison-plan --contract .planning/phases/254-speed-up-the-measured-slow-jobs/254-COMPARISON-RUN-CONTRACT.json --format json` | Unexecuted; conditional checkpoint |
| 254-08-03 | 5 | Both | Actual fixed forty-family comparison; real pass/miss/insufficient_data | `bash scripts/ci/ci-run-metrics.sh --evaluate-comparison --contract .planning/phases/254-speed-up-the-measured-slow-jobs/254-COMPARISON-RUN-CONTRACT.json --registrations .planning/phases/254-speed-up-the-measured-slow-jobs/254-COMPARISON-REGISTRATIONS.json --before-bundle .planning/execution/254-comparison/before --after-bundle .planning/execution/254-comparison/after --baseline-source-bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --format json > .planning/phases/254-speed-up-the-measured-slow-jobs/254-COMPARISON-RESULT.json` | Unexecuted; hosted blocked until ready |

## Wave 0 Requirements

- Extend existing comparison fixtures for frozen order/proximity, nonreplacement, incompatible conditions, missing data, and all-attempt cost accounting.
- Extend existing native records for exact case/project identity and intentional versus unexplained skip/exclusion parity.
- Add focused checks for fixture isolation, standalone eligible tests, anonymous lockout, and unchanged invitation lifecycle.
- Add cold/warm/failure Mix preparation checks before selecting the combined invocation.
- Each new check must be created before the task that depends on it, inside a vertical plan; no separate evidence framework or new dependency.

## Hosted Acceptance

Use the unchanged Phase 252 comparison contract: 20 matched pairs, 40 primary real-PR families, predeclared all-warm allocation, compatible actual runner conditions and one 48-hour window. Resolve cache preparation and any separately authorized warm-up budget before collection. Freeze identities, schedule and proximity rule before starting. Retain failure/cancellation/retry costs and original families. Fewer than 20 valid successful comparable pairs is insufficient data; missing a threshold with 20 valid pairs is a miss. Neither establishes the phase speed target.

Local tests and synthetic comparisons prove behavior of the machinery only. They do not prove a speedup or authorize renewing any prior acceptance budget.

Concrete future blocker: the unchanged workflow accepts PRs against `main`, so an arbitrary measurement base or dispatch cannot prove execution of the historical frozen baseline. Exact real-PR source/merge/workflow feasibility, all-warm cache access, compatible actual images and any separate extra warm-up budget must be proven before the first family. If unavailable, save blocked; do not edit the baseline or extend collection.

The two spec-less edge rows (CISPEED-01/02) remain explicitly unclassified/unresolved assumptions in Plan 08. Its two kept bespoke reporting prohibitions are descriptor-less and flagged-unverified; no local test silently resolves them.

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
