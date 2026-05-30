---
phase: 143
slug: playwright-demo-spec-screenshots
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-30
---

# Phase 143 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Playwright (TypeScript) + ExUnit |
| **Config file** | `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `cd test/example && npx playwright test --project=demo-showcase-chromium --reporter=line` |
| **Full suite command** | `cd test/example && npx playwright test --project=demo-showcase-chromium` |
| **ExUnit seeds-smoke** | `cd test/example && mix test test/example/demo/seeds_test.exs` |
| **Estimated runtime** | ~30–60 seconds (Playwright) + ~5 seconds (ExUnit seeds-smoke) |

---

## Sampling Rate

- **After every task commit:** Run `cd test/example && npx playwright test --project=demo-showcase-chromium --reporter=line`
- **After every plan wave:** Run full Playwright suite + ExUnit seeds-smoke
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 143-01-01 | 01 | 1 | PW-01 | — | N/A | integration | `cd test/example && npx playwright test --project=demo-showcase-chromium demo-showcase.spec.ts --reporter=line` | ✅ | ⬜ pending |
| 143-01-02 | 01 | 1 | PW-01 | — | N/A | integration | `cd test/example && npx playwright test --project=demo-showcase-chromium --reporter=line` | ✅ | ⬜ pending |
| 143-02-01 | 02 | 2 | PW-02 | — | N/A | integration | `cd test/example && npx playwright test --project=demo-showcase-chromium --update-snapshots --reporter=line` | ✅ | ⬜ pending |
| 143-03-01 | 03 | 1 | PW-03 | — | N/A | unit | `cd test/example && mix test test/example/demo/seeds_test.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements:
- `test/example/priv/playwright/playwright.config.ts` — Playwright config already present
- `test/example/priv/playwright/tests/` — spec directory already present
- `test/example/test/example/demo/seeds_test.exs` — ExUnit seeds-smoke already present and passing

*No Wave 0 installation tasks needed — all tooling is already in place.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Screenshot baselines look correct visually | PW-02 | PNG diffs can pass numerically while looking wrong | Review committed PNGs in `tests/demo-showcase.spec.ts-snapshots/` and confirm they show the expected content (populated persona table, admin user list, MFA row, audit log variety) |
| `demo-showcase-chromium` does not appear in `chromium`/`mobile` run output | PW-01 | No automated way to assert "this project was excluded" from another project's run | Run `cd test/example && npx playwright test --project=chromium --reporter=list 2>&1 | grep demo-showcase` — should return empty |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
