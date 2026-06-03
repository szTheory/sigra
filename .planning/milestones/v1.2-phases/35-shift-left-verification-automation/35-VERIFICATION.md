---
phase: 35-shift-left-verification-automation
verified: 2026-04-17T00:00:00Z
status: passed
score: 6/6 must-haves verified
overrides_applied: 0
---

# Phase 35: Shift-Left Verification Automation — Verification Report

**Phase goal:** Install machine gates for generator drift, installer integration, browser a11y/visual baselines, milestone verification presence, installer-scoped audit, and admin artifact bundle contracts.

## Must-haves

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| SC1 | `generator_emission_audit_test.exs` ties `<%= web_module %>.…` refs to feature `files/1` | ✓ | `test/sigra/templates/generator_emission_audit_test.exs`; `mix test` green |
| SC2 | `installer_drift_test.exs` fix #19 generalizes INT-04 dead span nav | ✓ | Fixture `fix #19` in `test/sigra/templates/installer_drift_test.exs` |
| SC3 | axe + `toHaveScreenshot` for five checkpoints × three projects | ✓ | `@axe-core/playwright`, `admin-checkpoints.spec.ts`, 15 PNGs under `tests/admin-checkpoints.spec.ts-snapshots/` |
| SC4 | `milestone-verification-gate.sh` + CI job | ✓ | `scripts/ci/milestone-verification-gate.sh`, job `milestone_verification_gate` in `.github/workflows/ci.yml` |
| SC5 | `installer-milestone-audit.sh` + paths-filtered PR job | ✓ | `scripts/ci/installer-milestone-audit.sh`, job `installer_milestone_audit` |
| SC6 | Artifact bundle contract + `CONTRIBUTING.md` | ✓ | `scripts/ci/admin-artifact-bundle-contract.sh`, step in `example_playwright_smoke`, `CONTRIBUTING.md` |

## Automated checks run locally

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/templates/`
- `bash scripts/ci/milestone-verification-gate.sh`
- `bash scripts/ci/installer-milestone-audit.sh`
- `bash scripts/ci/admin-artifact-bundle-contract.sh` (with populated `artifacts/admin-checkpoints/` from a green Playwright run)
- `npx playwright test tests/admin-checkpoints.spec.ts` (three checkpoint projects) against a running `test/example` dev server

## Notes

- `milestone-verification-gate.sh` currently requires phases **27–32** and **35** (phases 33–34 have no `*-VERIFICATION.md` on disk).
- Example `layouts.ex` gained `alt=""` on the navbar logo so WCAG **image-alt** passes under scoped axe runs.
