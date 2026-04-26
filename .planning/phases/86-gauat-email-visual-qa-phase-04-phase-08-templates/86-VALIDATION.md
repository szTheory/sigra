---
phase: 86
slug: gauat-email-visual-qa-phase-04-phase-08-templates
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-26
---

# Phase 86 — Validation Strategy

> Maintainer documentation: automated email visual regression harness for GAUAT-01 and GAUAT-02, covering the 9-template matrix with ExUnit semantics, CSS compatibility lint, Playwright baselines, CI evidence, and tag-time release-asset promotion.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (`MIX_ENV=test`) + Playwright + GitHub Actions workflow grep checks |
| **Config files** | `mix.exs`, `test/example/priv/playwright/playwright.config.ts`, `.github/workflows/ci.yml` |
| **Quick run command** | `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example/accounts/emails_security_html_test.exs test/example/accounts/emails_lifecycle_html_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/a11y/contrast_test.exs && MIX_ENV=test mix sigra.email.snapshot --check && MIX_ENV=test mix sigra.uat.report --phase=04 --check && MIX_ENV=test mix sigra.uat.report --phase=08 --check && cd test/example/priv/playwright && npx playwright test tests/email-visual.spec.ts --project=email-visual-chromium-light --project=email-visual-chromium-dark --project=email-visual-webkit-light --project=email-visual-webkit-dark` |
| **Estimated runtime** | ~2-6 minutes depending on Playwright/browser cache |

---

## Sampling Rate

- **After every Commit A task change:** run the quick ExUnit matrix so `Sigra.Email.CssLint` stays build-breaking in the normal CI path.
- **After snapshot/report task changes:** run `mix sigra.email.snapshot --check` and both `mix sigra.uat.report --phase=... --check` commands.
- **Before sign-off:** run the narrow Playwright matrix against the committed baselines under `test/example/priv/playwright/__snapshots__/email-visual.spec.ts/`.
- **Before merge:** grep `.github/workflows/ci.yml` and `86-VERIFICATION.md` for `email_visual_regression`, `refs/tags/v1.20.0`, and release-asset references.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 86-01-01 | 01 | 1 | GAUAT-01, GAUAT-02 | T-86-01, T-86-04 | WCAG contrast math and helper contracts are deterministic | ExUnit | `mix test test/sigra/a11y/contrast_test.exs` | ✅ | ⬜ pending |
| 86-01-02 | 01 | 1 | GAUAT-01, GAUAT-02 | T-86-01, T-86-03 | Unsupported CSS is rejected by vendored caniemail policy | ExUnit + grep | `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example/accounts/emails_security_html_test.exs test/example/accounts/emails_lifecycle_html_test.exs` | ✅ | ⬜ pending |
| 86-01-03 | 01 | 1 | GAUAT-01, GAUAT-02 | T-86-02, T-86-04 | All 9 templates enforce G1-G9 and execute `Sigra.Email.CssLint` inside the normal `mix test` CI path | ExUnit | `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example/accounts/emails_security_html_test.exs test/example/accounts/emails_lifecycle_html_test.exs` | ✅ | ⬜ pending |
| 86-02-01 | 02 | 2 | GAUAT-01, GAUAT-02 | T-86-05 | Deterministic prerender and report-generation inputs stay drift-free | Mix task | `MIX_ENV=test mix sigra.email.snapshot --check && MIX_ENV=test mix sigra.uat.report --phase=04 --check && MIX_ENV=test mix sigra.uat.report --phase=08 --check` | ⬜ | ⬜ pending |
| 86-02-02 | 02 | 2 | GAUAT-01, GAUAT-02 | T-86-06 | Playwright enforces the 36 committed baselines under the canonical `__snapshots__/email-visual.spec.ts/` path | Playwright | `cd test/example/priv/playwright && npx playwright test tests/email-visual.spec.ts --project=email-visual-chromium-light --project=email-visual-chromium-dark --project=email-visual-webkit-light --project=email-visual-webkit-dark` | ⬜ | ⬜ pending |
| 86-03-01 | 03 | 3 | GAUAT-01, GAUAT-02 | T-86-05, T-86-08 | CI uploads the full bundle on every run, promotes that exact bundle to the `v1.20.0` release asset on tag runs, and records the merge-gate contract in `86-VERIFICATION.md` | grep + artifact contract | `rg -n "email_visual_regression|refs/tags/v1.20.0|gh release upload|release asset|snapshot count = 36|contrast min ratio|byte budget max" .github/workflows/ci.yml docs/uat-ci-coverage.md .planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-VERIFICATION.md` | ✅ | ⬜ pending |
| 86-03-02 | 03 | 3 | GAUAT-01 | T-86-09 | Phase 04 evidence directory contains the README/manifest/reports plus eight SHA-suffixed hero PNGs derived from the canonical baselines | Mix task + file contract | `MIX_ENV=test mix sigra.uat.report --phase=04 --check && find .planning/uat-evidence/v1.20/email-phase-04/snapshots -maxdepth 1 -type f | wc -l | grep -qx '8' && find .planning/uat-evidence/v1.20/email-phase-04/snapshots -maxdepth 1 -type f | sed 's#.*/##' | sort | rg "^(lockout-notification|suspicious-login)__(chromium|webkit)__(light|dark)__sha-[0-9a-f]{7}\\.png$"` | ✅ | ⬜ pending |
| 86-04-01 | 04 | 3 | GAUAT-02 | T-86-09 | Phase 08 evidence directory contains the README/manifest/reports plus twenty-eight SHA-suffixed hero PNGs derived from the canonical baselines | Mix task + file contract | `MIX_ENV=test mix sigra.uat.report --phase=08 --check && find .planning/uat-evidence/v1.20/email-phase-08/snapshots -maxdepth 1 -type f | wc -l | grep -qx '28' && find .planning/uat-evidence/v1.20/email-phase-08/snapshots -maxdepth 1 -type f | sed 's#.*/##' | sort | rg "^(email-change-confirmation|email-change-notification|email-changed|password-changed|deletion-scheduled|deletion-cancelled|deletion-finalized)__(chromium|webkit)__(light|dark)__sha-[0-9a-f]{7}\\.png$"` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

**Existing infrastructure is sufficient** — no new Wave 0 harness is required beyond the phase-created ExUnit helpers, Mix tasks, and Playwright spec.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Human read of evidence README/frontmatter honesty | GAUAT-01, GAUAT-02 | Tone and claim precision | Spot-check `.planning/uat-evidence/v1.20/email-phase-04/README.md` and `email-phase-08/README.md` against the residual policy and confirm there is no false “real-mail-client tested” claim |

---

## Validation Sign-Off

- [ ] `Sigra.Email.CssLint` is executed from the ExUnit template tests so unsupported CSS fails the normal `mix test` CI path
- [ ] CTA contrast default is `#1d4ed8` and the stronger `>= 4.5` gate is enforced by tests
- [ ] `mix sigra.email.snapshot --check` and both `mix sigra.uat.report --phase=... --check` commands pass
- [ ] Playwright passes the full 36-cell matrix against `test/example/priv/playwright/__snapshots__/email-visual.spec.ts/`
- [ ] `.github/workflows/ci.yml` uploads the raw bundle every run and has a tag-conditional `v1.20.0` release-asset promotion path using the same generated bundle
- [ ] `.planning/uat-evidence/v1.20/email-phase-04/snapshots/` contains the eight required `__sha-{short-sha}.png` hero PNGs for GAUAT-01
- [ ] `.planning/uat-evidence/v1.20/email-phase-08/snapshots/` contains the twenty-eight required `__sha-{short-sha}.png` hero PNGs for GAUAT-02
- [ ] `86-VERIFICATION.md` has placeholders for CI run URL, snapshot count, contrast minimum, byte-budget maximum, and release-asset name/digest

**Approval:** pending
