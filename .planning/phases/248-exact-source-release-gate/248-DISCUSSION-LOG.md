# Phase 248: Exact-Source Release Gate - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-10-07
**Phase:** 248-Exact-Source Release Gate
**Mode:** assumptions
**Areas analyzed:** release authority and auto-merge, source identity, credential boundaries, run safety and receipts, candidate content, maintainer DX

## Assumptions Presented

### Release authority and auto-merge
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add guarded exact-head auto-merge for one valid Release Please PR after candidate preflight and `ci-gate` pass; preserve branch protection and never bypass it. | Confident after user confirmation | `.github/workflows/release-please.yml`; `lattice_stripe/.github/workflows/release-pr-automerge.yml`; user selected “Add guarded auto-merge” and then approved the recommendation set. |
| Use the existing `RELEASE_PLEASE_TOKEN` for the merge event chain; do not silently use `GITHUB_TOKEN` if that would suppress the main push workflow. | Confident | `gh secret list` showed the name `RELEASE_PLEASE_TOKEN`; Release Please action and GitHub token-trigger docs describe downstream event suppression. |

### Source identity and Hex evaluation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Resolve the Release Please tag and require its commit, output `sha`, and checked-out `HEAD` to match before package work. | Confident | `.github/workflows/release-please.yml`; `scripts/ci/wait-for-ci-gate.sh`; Release Please action output documentation. |
| Use a read-only Hex key for the authenticated dry-run and reserve `HEX_API_KEY` for publish; local Hex login is not part of CI. | Confident after user confirmation | `.github/workflows/release-please.yml`; `.github/workflows/hex-publish.yml`; Hex task source shows dry-run authenticates but skips the release POST; repository has `HEX_API_KEY` configured. |

### Run safety and outcome evidence
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Prevent later main pushes from cancelling active release evaluations and retain machine-readable linked stage receipts for every terminal result, including cancellation. | Confident | `.github/workflows/release-please.yml` currently uses cancelling concurrency; gate/publish artifact and notification jobs are success/failure oriented; `AUTO-02` requires success/failure/cancellation receipts. |
| Use a trusted default-branch completion observer only for cancellation/finalization and correlate it to the source run ID and SHA. | Confident | Official GitHub `workflow_run` event and security semantics; source run SHA differs from the observer workflow's default-branch context. |

### Candidate content and maintainer experience
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Auto-merge must be gated by machine checks for versioned changelog placement and candidate-note completeness; the current green PR #224 remains blocked by a duplicated entry and omitted Phase 246 notes. | Confident | Phase 247 D-03/D-04; `.planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md`; current PR #224 review. |
| No application UI is in scope; optimize the maintainer flow through zero per-release local auth, an automatic happy path, and actionable run/artifact links. | Confident | Phase 248 roadmap contract; current Release Please and Hex workflows; user emphasis on automated DevOps. |

## Corrections Made

No corrections to the recommended implementation set. The user explicitly confirmed guarded auto-merge and approved the full recommendation set.

## External Research

- Release Please action outputs: `sha` identifies the commit associated with the created release tag; use it together with `tag_name` and compare the resolved Git commit before packaging. Source: https://github.com/googleapis/release-please-action
- GitHub token event chaining: events caused by `GITHUB_TOKEN` do not normally start new workflow runs; use the configured release token for the merge event chain or an explicit source-validated dispatch. Source: https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow
- GitHub `workflow_run`: consumer context defaults to the default branch and the event can access elevated secrets/permissions, so validate the source workflow/run and execute trusted default-branch code only. Source: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_run
- Hex dry-run: `mix hex.publish --dry-run --yes` performs authenticated preflight/local packaging but returns before the release upload call; it does not prove write permission. Sources: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html and https://raw.githubusercontent.com/hexpm/hex/v2.5.1/lib/mix/tasks/hex.publish.ex
- Lattice Stripe prior art: trusted candidate preflight, exact `ci-gate` head, revalidation immediately before `--match-head-commit` merge, and no branch-protection bypass. Source: `/Users/jon/projects/lattice_stripe/.github/workflows/release-pr-automerge.yml`.
