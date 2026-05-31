# Phase 146: Release Gate And Maintainer Runbook - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md -- this log preserves the analysis.

**Date:** 2026-05-31
**Phase:** 146-release-gate-and-maintainer-runbook
**Mode:** assumptions
**Areas analyzed:** Release Ref Truth And Version Alignment, Release Gate Matrix, Recovery Path, Dedicated Runbook And Hotfix Policy, Release Please Cleanup

## Assumptions Presented

### Release Ref Truth And Version Alignment

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 146 should enforce that publish gates run on the immutable release ref (`v*` tag / release SHA), with `mix.exs @version` and Release Please outputs as authoritative cross-checks. | Confident | `.planning/ROADMAP.md`; `.github/workflows/release-please.yml`; `.planning/phases/145-1-0-contract-and-release-truth/145-CONTEXT.md`; `mix.exs` |

### Release Gate Matrix

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The Phase 146 gate matrix should map to existing CI jobs/scripts as canonical evidence, then add release-time execution pointers rather than inventing a parallel test stack. | Likely | `.github/workflows/ci.yml`; `MAINTAINING.md`; `docs/uat-ci-coverage.md`; install/browser smoke scripts and tests |

### Recovery Path

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Failed dry-run/publish recovery should standardize on the existing `Hex publish (manual recovery)` workflow as the primary no-invention path, with local trusted-machine publish only as fallback. | Likely | `.github/workflows/hex-publish.yml`; `MAINTAINING.md`; `docs/NEXT-STEPS-MANUAL.md`; Hex publish docs |

### Dedicated Runbook And Hotfix Policy

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| First-14-day hotfix and triage expectations are missing and should be introduced in a dedicated Phase 146 release-runbook/policy doc, with `MAINTAINING.md` pointing to it instead of duplicating the full matrix. | Likely | `.planning/ROADMAP.md`; `MAINTAINING.md`; repository doc shape favoring concise entry points plus focused detail docs |

### Release Please Cleanup

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Cleanup of the one-time `release-as: "1.0.0"` override should be a release-gate/runbook item after the 1.0 Release PR merges and cuts the release. | Confident | `MAINTAINING.md`; `release-please-config.json`; Release Please manifest docs |

## Corrections Made

No corrections -- all assumptions confirmed.

## External Research

- Hex publish recovery semantics: Hex publishes docs automatically with package publish; docs can be republished independently; public package replacement/revert is time-limited; `--dry-run` performs local checks and `mix hex.build --unpack` is the package inspection tool. Source: `https://hex.pm/docs/publish`, `https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html`
- Release Please `release-as` cleanup: Release Please docs state that after a release PR using `release-as` merges, the override should be removed or changed because later runs will keep using it. Source: `https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md`
