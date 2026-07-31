---
phase: 232
slug: playwright-economics-authenticate-once-then-shard
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-31
---

# Phase 232 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit planning contracts, Playwright 1.59.1, and observed GitHub Actions runs |
| **Config file** | `test/test_helper.exs`, `test/example/priv/playwright/playwright.config.ts`, `.github/workflows/ci.yml` |
| **Quick run command** | `mix test test/sigra/planning/phase_232_playwright_economics_test.exs` |
| **Full suite command** | `mix test test/sigra/planning/` |
| **Estimated runtime** | Quick structural feedback under 30 seconds; observed CI receipts depend on GitHub runner availability |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/planning/phase_232_playwright_economics_test.exs`.
- **After every plan wave:** Run `mix test test/sigra/planning/` and `cd test/example/priv/playwright && npx playwright test --list` for every affected project.
- **Before `$gsd-verify-work`:** Structural suites must be green and ordered real-run receipts must be recorded in `232-EVIDENCE.md`.
- **Max feedback latency:** 30 seconds for local structural checks; real GitHub Actions observations are explicit manual gates.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 232-01-01 | 01 | 1 | PW-01 | T-232-01 | Auth state is ephemeral, project-specific, and excluded from artifacts | structural | `mix test test/sigra/planning/phase_232_playwright_economics_test.exs` | ❌ W0 | ⬜ pending |
| 232-01-02 | 01 | 1 | PW-01 | — | Registration removal preserves LiveView/font readiness and assertion/snapshot counts | observed CI | `bash scripts/ci/ci-run-metrics.sh --jobs <before-run-id> && bash scripts/ci/ci-run-metrics.sh --jobs <after-pw01-run-id>` | ❌ evidence | ⬜ pending |
| 232-02-01 | 02 | 2 | PW-02 | T-232-02 | Every concurrent shard owns an isolated PostgreSQL service/database, app, and port | structural | `mix test test/sigra/planning/phase_232_playwright_economics_test.exs` | ❌ W0 | ⬜ pending |
| 232-02-02 | 02 | 2 | PW-02 | T-232-03 | All shards affect the required verdict and execute with `--retries=0` | observed CI | `gh run view <after-shard-run-id> --json jobs` | ❌ evidence | ⬜ pending |
| 232-03-01 | 03 | 2 | PW-03 | — | Exactly one shared boot definition is consumed by every app-booting Playwright job | structural | `mix test test/sigra/planning/phase_232_playwright_economics_test.exs` | ❌ W0 | ⬜ pending |
| 232-03-02 | 03 | 3 | PW-02, PW-03 | T-232-03 | The byte-identical required check resolves on a real PR and all consumers boot | observed CI | `gh pr checks <pr-number> && gh run view <after-shard-run-id> --json jobs` | ❌ evidence | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/planning/phase_232_playwright_economics_test.exs` — non-vacuous structural contracts for distinct setup projects/dependencies/state paths, no per-test design registration, preserved readiness, isolated shard inputs, retry-zero commands, exact aggregator name, and single boot definition/consumer coverage.
- [ ] `.planning/phases/232-playwright-economics-authenticate-once-then-shard/232-EVIDENCE.md` — durable before/after run IDs, job and step duration tables, assertion/snapshot counts, concurrent shard timestamps, retry-zero command proof, consumer boot results, and `gh pr checks` output.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| PW-01 has an attributable performance receipt before topology changes | PW-01 | Requires observed GitHub-hosted job timing from two ordered real runs | Record BEFORE-PW-01 and AFTER-PW-01 run IDs; compare the same design-gallery step with identical passing assertion and snapshot counts using `gh run view --json jobs` and `scripts/ci/ci-run-metrics.sh`. |
| Concurrent shards pass without masked interference | PW-02 | Requires a real multi-runner GitHub Actions observation | Inspect the post-shard PR run for overlapping non-zero-duration shard jobs, successful isolated database/app/port ownership, and explicit `--retries=0`. |
| Required branch-protection context remains resolved | PW-02 | Workflow YAML cannot prove repository ruleset resolution | Run `gh pr checks <pr-number>` and record the exact successful context `Example Playwright smoke (full lifecycle)`. |
| Event-gated snapshot, recapture, and eval consumers still boot | PW-03 | These paths require non-PR/manual event execution | Record a qualifying non-PR run and verify every shared-boot consumer starts successfully and preserves its intended snapshot routing. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s for structural checks
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
