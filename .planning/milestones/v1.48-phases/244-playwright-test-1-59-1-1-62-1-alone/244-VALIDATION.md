---
phase: "244"
slug: "playwright-test-1-59-1-1-62-1-alone"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-09-26"
---

# Phase 244 — Validation Strategy

> Automated validation contract for the isolated Playwright package update. No human visual UAT is required: comparison must fail closed on any pixel drift and preserve machine-readable evidence.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Playwright Test; focused Node/shell contract tests for inventory, comparator, cache guard, and receipt validation |
| **Config file** | `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `bash scripts/ci/playwright-cache-key-guard.test.sh` plus the new focused measurement-harness tests (command to be fixed in the plan) |
| **Full suite command** | Existing `example_playwright_shard` matrix, `example_playwright_smoke`, and `generated_admin_playwright_smoke` workflow jobs; exact commands remain owned by `.github/workflows/ci.yml` |
| **Estimated runtime** | CI-dependent; measure and record from the workflow run |

---

## Sampling Rate

- **After every task commit:** Run the cache-key guard self-test and focused measurement/receipt contract tests.
- **After every plan wave:** Run the exact-pixel measurement on Ubuntu for both package/browser versions, then relevant existing browser consumers.
- **Before phase verification:** Require a committed measurement/decision artifact and, for the resulting main SHA, one successful workflow run containing every required consumer job individually.
- **Max feedback latency:** Record measured CI duration; no unmeasured local screenshot run substitutes for Ubuntu evidence.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 244-01-01 | 01 | 0 | QUEUE-02 | — | Reject incomplete or unsafe screenshot paths; never modify committed baselines | unit/contract | New measurement-harness test command, fixed in plan | ❌ W0 | ⬜ pending |
| 244-01-02 | 01 | 0 | QUEUE-02 | — | Reject missing/extra paths, dimensions mismatch, and any changed pixel; accept only exact equality | unit/contract | New comparator tests: equal, one-pixel drift, dimensions, missing and extra image cases | ❌ W0 | ⬜ pending |
| 244-01-03 | 01 | 1 | QUEUE-02 | — | Render complete tracked PNG inventory using tagged browser revisions on the same Ubuntu source revision | CI integration | New CI measurement workflow/job; fail unless both output path sets match the committed inventory | ❌ W0 | ⬜ pending |
| 244-01-04 | 01 | 1 | QUEUE-02 | T-244-01 | Validate structured GitHub job data and bind evidence to one exact SHA; do not accept skipped jobs | unit/integration | New receipt-validator tests for wrong SHA, missing job, skipped job, and all-success exact-SHA receipt | ❌ W0 | ⬜ pending |
| 244-01-05 | 01 | 1 | QUEUE-02 | — | Preserve chromium and chromium-webkit cache families and update all versioned keys | shell contract | `bash scripts/ci/playwright-cache-key-guard.sh` and `bash scripts/ci/playwright-cache-key-guard.test.sh` | ✅ | ⬜ pending |
| 244-01-06 | 01 | 2 | QUEUE-02 | — | Record merge/defer outcome and exact resulting-main SHA; no stale August checks count | CI integration | Receipt validator plus fresh GitHub status/check evidence on one resulting SHA | ❌ W0 | ⬜ pending |

---

## Wave 0 Requirements

- [ ] Measurement harness tests for exact inventory equality, missing and extra paths, dimension mismatch, single-pixel drift, and zero drift.
- [ ] Machine-readable measurement/decision manifest schema and validator.
- [ ] Exact-SHA consumer receipt schema and validator that requires `ci-gate`, every shard, example smoke, and generated-admin smoke to conclude `success` in a single run; `skipped` is a failure.
- [ ] Extend cache guard contract coverage to validate both browser-set key variants rather than relying on a first-match check.
- [ ] Pin and verify the decoder/comparator used in the Ubuntu measurement environment; fail closed if unavailable.

---

## Manual-Only Verifications

All phase behaviors have automated verification. GitHub PR restoration or reopening is an execution-time external state decision: the plan must treat the already-closed PR as deferred unless an authorized live candidate is intentionally restored. No manual visual review can override a pixel difference or missing evidence.

---

## Validation Sign-Off

- [ ] All tasks have executable `<automated>` verification or Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification.
- [ ] Wave 0 covers all MISSING references.
- [ ] No watch-mode flags.
- [ ] Feedback latency recorded from CI.
- [ ] `nyquist_compliant: true` set in frontmatter after validation infrastructure exists and checks pass.

**Approval:** pending
