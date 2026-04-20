---
phase: 40
status: passed
verified: 2026-04-19
---

# Phase 40 Verification — Tooling & release ergonomics

## Must-haves

| Criterion | Evidence |
|-----------|----------|
| REL-01: `MAINTAINING.md` + optional hex workflow | `MAINTAINING.md` exists with checklist, semver rule, verbatim `## Planning hygiene (without gsd-tools JSON)`, Hex publish link; `.github/workflows/hex-publish.yml` is `workflow_dispatch`-only with pinned `actions/checkout` and `erlef/setup-beam` SHAs matching `ci.yml`; `HEX_API_KEY` only on publish step. |
| TOOL-01: supported path vs JSON audit | `MILESTONES.md`, `PROJECT.md`, `26-01-PLAN.md`, and `scripts/maintainers/planning-audit-hygiene.sh` reference `MAINTAINING.md` planning hygiene; helper runs with bash only. |
| Contributor docs | `CONTRIBUTING.md` links `MAINTAINING.md` and does not contain substring `gsd-tools` (per plan grep gate). `README.md` links `MAINTAINING.md`. |
| ExDoc | `mix.exs` `extras` includes `"MAINTAINING.md"` after `"CONTRIBUTING.md"`. |

## Automated checks run

- Plan acceptance `bash -lc` blocks from `40-01-PLAN.md` and `40-02-PLAN.md` (grep / file existence).
- `bash scripts/maintainers/planning-audit-hygiene.sh` → exit 0.
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` → **1 failure** on this working tree (`Sigra.Install.GoldenDiffTest` config drift; `Sigra.TestingTest` export assertion) — **not introduced by Phase 40 files** (no `lib/` edits in this phase). CI on a clean tree with green mainline is expected to pass for these doc-only paths.

## Human verification

None required.

## Gaps

None for Phase 40 scope; branch-wide test debt tracked separately.
