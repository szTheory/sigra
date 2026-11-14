# Phase 249: Publish and Prove Sigra 1.6.0 - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `249-CONTEXT.md`; this log preserves the analysis.

**Date:** 2026-10-09
**Phase:** 249-publish-and-prove-sigra-1-6-0
**Mode:** assumptions
**Areas analyzed:** exact source and release identity; live HexDocs proof; generated docs index and release automation; worktree and PR closeout

## Assumptions Presented

### Exact source and release identity
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Bind tag `v1.6.0`, gated source SHA, Hex package, docs, required CI, and committed receipt to one release identity. | Confident | `.planning/phases/248-exact-source-release-gate/248-CONTEXT.md`; `.planning/ROADMAP.md` Phase 249; `.planning/REQUIREMENTS.md` REL-01/REL-02 |

### Live HexDocs proof
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Verify that the live versioned docs and their source reference resolve to the release tag and commit; rendered-link text alone is insufficient. | Likely | `.github/workflows/release-please.yml`; `scripts/ci/release-post-publish-verify.sh`; `.planning/REQUIREMENTS.md` REL-01 |

### Generated docs index automation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Keep the tracked ExDoc index build-equal and guard it in required CI; refresh Release Please candidates automatically before exact-head auto-merge. | Likely after external research | `.planning/todos/pending/2026-09-16-docs-index-goes-stale-on-every-version-bump.md`; `mix.exs`; `.github/workflows/ci.yml`; official Release Please, ExDoc, and GitHub Actions references below |

### Worktree and PR closeout
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Re-inventory all worktrees and PRs, record every disposition, preserve inherited work, and prove cleanliness without destructive cleanup. | Likely | `.planning/ROADMAP.md` Phase 249; `.planning/phases/247-release-candidate-and-repository-readiness/247-CONTEXT.md`; live `main` and PR #302 observations |

## Corrections Made

### Generated docs index automation
- **Original assumption:** Defer the `doc/llms.txt` refresh and durable drift guard unless the user chose to fold them into Phase 249.
- **User choice:** “follow ur recs” — include both the 1.6.0 index refresh and the CI drift guard.
- **Reason:** Keep release documentation accurate and prevent repeat version/module drift without introducing a manual Release Please step.

## External Research

- Release Please `extra-files` can update annotated/static content but does not regenerate ExDoc's dynamic module/navigation rows; ExDoc rebuilds the generated file and removes updater annotations. Recommended a trusted-main candidate refresh, followed by ordinary CI on the new exact head. Sources: [Release Please customization docs](https://github.com/googleapis/release-please/blob/main/docs/customizing.md), [Release Please manifest-releaser docs](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md), [ExDoc](https://github.com/elixir-lang/ex_doc), [ExDoc changelog](https://hexdocs.pm/ex_doc/changelog.html).
- GitHub does not trigger ordinary push workflows from a push made with `GITHUB_TOKEN`; keep the candidate refresh event chain explicit and its write token out of the build step. Source: [GitHub Actions events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows).
- Sigra's prompt/research guidance favors Release Please → exact required CI → Hex, ExDoc docs as a quality gate, narrowly scoped secrets, and durable machine-readable evidence. Source: `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md`.
