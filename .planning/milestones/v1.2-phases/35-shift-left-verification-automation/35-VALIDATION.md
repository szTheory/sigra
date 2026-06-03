---
phase: 35
slug: shift-left-verification-automation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-17
---

# Phase 35 — Validation Strategy

> Per-phase validation contract for execution sampling.

---

## Test infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Playwright (Node 20+) |
| **Config file** | `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/templates/generator_emission_audit_test.exs` |
| **Full suite command** | `mix test test/sigra/templates/generator_emission_audit_test.exs test/sigra/templates/installer_drift_test.exs` **and** `cd test/example/priv/playwright && npm ci && npx playwright test tests/admin-checkpoints.spec.ts` |
| **Estimated runtime** | ~3–15 minutes (Playwright dominates) |

---

## Sampling rate

- **After every task commit:** Quick ExUnit slice **or** `bash -n` on any new/edited shell script
- **After every plan wave:** Wave’s `mix test` / Playwright project subset listed in that plan’s `<verification>`
- **Before `/gsd-verify-work`:** Full suite commands above green locally
- **Max feedback latency:** Target < 20 minutes on laptop (Playwright three projects)

---

## Per-task verification map

| Task ID | Plan | Wave | Requirement | Threat ref | Secure behavior | Test type | Automated command | Status |
|---------|------|------|---------------|------------|-----------------|-----------|-------------------|--------|
| 35-01-01 | 01 | 1 | SC1 | T-35-FN | Emission audit fails closed | unit | `mix test test/sigra/templates/generator_emission_audit_test.exs` | ⬜ |
| 35-02-01 | 02 | 1 | SC2 | T-35-FN | Drift `must_not` catches dead nav | unit | `mix test test/sigra/templates/installer_drift_test.exs` | ⬜ |
| 35-03-01 | 02 | 2 | SC3 | T-35-FN | axe violations = 0 | e2e | `npx playwright test tests/admin-checkpoints.spec.ts -g axe` (or full spec) | ⬜ |
| 35-03-02 | 02 | 2 | SC3 | T-35-FN | Snapshots match | e2e | `npx playwright test tests/admin-checkpoints.spec.ts --update-snapshots` (authoring only); CI without update | ⬜ |
| 35-04-01 | 04 | 3 | SC4 | T-35-FN | Gate script exits 0 | shell | `bash scripts/ci/milestone-verification-gate.sh` | ⬜ |
| 35-05-01 | 05 | 3 | SC5 | T-35-FN | Installer audit greps | shell | `bash scripts/ci/installer-milestone-audit.sh` | ⬜ |
| 35-06-01 | 06 | 4 | SC6 | T-35-FN | PNG count + size | shell | `bash scripts/ci/admin-artifact-bundle-contract.sh` | ⬜ |

---

## Wave 0 requirements

- Existing infrastructure covers Playwright + Postgres; Wave 0 adds **no** new framework—only new test files, scripts, and `npm` devDependency.

---

## Manual-only verifications

| Behavior | Why manual | Test instructions |
|----------|------------|---------------------|
| “Are screenshots **useful** to a human reviewer?” | Subjective aesthetic | Spot-check once per snapshot refresh in PR description |

---

## Validation sign-off

- [ ] All tasks include `<automated>` or explicit shell verify
- [ ] No watch-mode flags in CI commands
- [ ] `nyquist_compliant: true` set on each PLAN frontmatter when execution completes

**Approval:** pending
