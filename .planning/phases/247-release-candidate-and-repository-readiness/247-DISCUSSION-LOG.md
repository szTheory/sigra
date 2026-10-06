# Phase 247: Release Candidate and Repository Readiness - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in 247-CONTEXT.md — this log preserves the analysis.

**Date:** 2026-10-06
**Phase:** 247-release-candidate-and-repository-readiness
**Mode:** assumptions
**Areas analyzed:** release candidate identity, changelog and adopter guidance, source checkout and PR disposition, phase boundary and evidence

## Assumptions Presented

### Release candidate identity and source
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Keep the 1.6.0 target and PR #224, but refresh and review the candidate after Phase 246 evidence and inherited-work disposition. | Confident | .planning/PROJECT.md; .planning/ROADMAP.md; .planning/STATE.md; live PR #224; current local Phase 246 commit history |
| Do not treat the current PR head as a complete candidate; reconcile package metadata, changelog, and source reference against reviewed source. | Confident | PR #224 head 276e8c3f changes only .release-please-manifest.json, CHANGELOG.md, and mix.exs; .planning/phases/246-generated-confirmation-recovery/246-MIX-CI-BLOCKED.md |

### Release notes and adopter guidance
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Use a curated reader-facing summary under the 1.6.0 version heading while retaining useful release commit traceability; do not present phase IDs as product changes. | Confident | PR #224 changelog diff; CHANGELOG.md; READY-01 |
| Add a version-specific v1.6 upgrade path from README and explain compatibility, commands, migration state, and generated-host actions. | Likely | .planning/ROADMAP.md; .planning/REQUIREMENTS.md; README.md; guides/introduction/upgrading-to-v1.5.md; Phase 246 context |
| Existing generated hosts do not receive host-owned template changes from a dependency update alone. | Confident | .planning/phases/246-generated-confirmation-recovery/246-CONTEXT.md; priv/templates/sigra.install/core/confirmation_live.ex; Sigra hybrid library/generator model |

### Repository and PR readiness
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Inventory committed ancestry, dirty/untracked paths, and every open PR; preserve and disposition them before creating a clean release checkout. | Confident | .planning/REQUIREMENTS.md READY-02; .planning/research/v1.49-release-scope/REPO-STATE.md; git branch/status snapshot |

### Phase boundary and evidence
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Phase 247 prepares the candidate and adopter materials; Phase 246 must supply its required evidence, while Phase 248 owns exact-source gate proof and Phase 249 owns publication proof. | Confident | .planning/ROADMAP.md; .planning/STATE.md; Phase 246 blocked evidence |

## Corrections Made

No corrections. The user accepted the recommendation set and chose to fold the candidate-specific changelog check into Phase 247.

## Folded Todo

- .planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md — folded only as a 1.6.0 candidate check that the reader-facing summary is under the versioned heading rather than stranded under Unreleased. The lasting Release Please/CI prevention work remains deferred.

## Reviewed but Not Folded

- .planning/todos/pending/2026-09-16-docs-index-goes-stale-on-every-version-bump.md — generated documentation-index drift is outside this candidate-readiness requirement.
- .planning/todos/pending/2026-09-18-packaged-docs-surface-carries-planning-paths-into-the-hex-tarball.md — broad packaged-docs cleanup is outside scope; the 1.6.0 summary still must be adopter-focused.
- .planning/todos/pending/2026-09-16-upgrade-guide-link-removal-was-lossy-where-a-lossless-fix-existed.md — older guide cleanup is separate; new guide links should be valid.
- .planning/todos/pending/2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md and .planning/todos/pending/2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md — release-gate behavior is out of Phase 247 scope.

## External Research

- Release Please uses manifest-driven release PRs to update version files and changelogs; retain it for candidate/version mechanics and review its public changelog output. [Manifest releaser](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md)
- Hex publishes versioned documentation with a package and documents dry-run plus unpacked package inspection; use the existing verification path, with exact-source gate execution remaining in Phase 248. [Hex publish task](https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html)
- Phoenix’s auth generator is relevant prior art for generated host code and migration guidance. Laravel’s upgrade guide labels impact by likelihood, a useful pattern for helping adopters identify applicable changes. [Phoenix generator](https://phoenix.hexdocs.pm/Mix.Tasks.Phx.Gen.Auth.html) · [Laravel upgrade guide](https://laravel.com/framework/docs/12.x/upgrade)
- Ecto’s release notes group enhancements and fixes by version, supporting a readable release summary while preserving detail. [Ecto changelog](https://github.com/elixir-ecto/ecto/blob/master/CHANGELOG.md)
- The 2026-10-06 live GitHub snapshot showed PR #224 open/mergeable at 276e8c3f and 14 open PRs total. The local checkout was on phase-244-playwright-measurement at e16f413d4, with Phase 246 commits plus dirty paths and no upstream. Re-fetch both sources at execution time.

## Project Prompt Review

No prompt.txt file was present. Reviewed the applicable prompts:
- prompts/elixir-opensource-libs-best-practices-deep-research.md
- prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md
- prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md
- prompts/Building the gold-standard Elixir:Phoenix authentication library.md

The phase changes documentation UX rather than application UI; admin UI visual principles do not apply.
