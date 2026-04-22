---
phase: 50-nyquist-ci-gate-hygiene
plan: "01"
subsystem: ci
tags: [mix, github-actions, documentation, installer, golden]

requires: []
provides:
  - "`mix ci.install_golden` alias (two install test modules)"
  - "`install_golden_contract` CI job (path-filtered PRs; always on `main`)"
  - "Maintainer + UAT pointers in `MAINTAINING.md` / `docs/uat-ci-coverage.md`"

affects: [50-02]

key-files:
  created: []
  modified:
    - "mix.exs"
    - ".github/workflows/ci.yml"
    - "MAINTAINING.md"
    - "docs/uat-ci-coverage.md"

key-decisions:
  - "Mirrored `installer_milestone_audit` PR `git diff` filter so pushes to `main` always run the job while PRs only run on installer path edits."
  - "Reused `postgres:15` + `sigra_test` DB service pattern from `library_tests` for parity with other Postgres-backed jobs."

requirements-completed: []

duration: unknown
completed: 2026-04-22
---

# Phase 50 plan 01 — Summary

**Added the `ci.install_golden` Mix alias, the `install_golden_contract` workflow job, and maintainer/UAT documentation for the installer golden + idempotency harness.**

## Performance

- **Tasks:** 3 (three atomic commits: `mix.exs`, `ci.yml`, docs)
- **Merge gate:** `mix ci.install_golden` — **not completed in this executor session** (nested tmp-app `mix deps.get` ran >60 minutes without finishing; see `50-VERIFICATION.md` draft notes). Re-run locally with a warm Hex cache or rely on CI `install_golden_contract`.

## Self-Check: PASSED (implementation) / PARTIAL (merge gate)

- Task 1–3 acceptance greps and `mix format --check-formatted mix.exs`, YAML python checks, and `MIX_ENV=test mix compile` all **PASS**.
- Plan-level verification command `mix ci.install_golden` **not** brought to exit 0 here — recorded as deviation below; CI job added for visibility.

## Deviations

- **`mix ci.install_golden`:** Multiple attempts exceeded practical wall-clock in this environment while the tmp Phoenix app blocked on `mix deps.get` (no failure output; long-running child `beam` + `mix deps.get`). Alias and workflow wiring are in place; treat **`install_golden_contract`** on GitHub Actions as the first-class receipt until a local merge gate run is captured in **`50-VERIFICATION.md`**.
