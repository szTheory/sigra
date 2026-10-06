# Phase 245: Branch Prune — Local and Remote - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `245-CONTEXT.md` — this log preserves the analysis.

**Date:** 2026-09-27
**Phase:** 245-branch-prune-local-and-remote
**Mode:** assumptions
**Areas analyzed:** Prune Readiness, Object Recoverability, Open PR Exclusions, Safety Refs on Origin

## Assumptions Presented

### Prune Readiness
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Planning may proceed now, but branch deletion waits for Phase 244 completion; its separate blocker stays out of Phase 245. | Confident | `.planning/ROADMAP.md`; `.planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-03-SUMMARY.md`; `continue.md` |

### Object Recoverability
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Commit a pre-prune ref snapshot, verify each recorded SHA afterward with `git cat-file -e`, preserve the milestone no-GC/no-reflog-expiry rule, and leave stashes untouched. | Confident | `.planning/ROADMAP.md`; `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-CONTEXT.md` D-09; `237-GIT-OBJECT-SNAPSHOT.md`; `.planning/phases/238-tag-guard-then-tag-deletion/238-VERIFICATION.md` |

### Open PR Exclusions
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Derive the keep set from current open PR heads and bases; retain the #219 head branch while that PR remains open. | Confident | `.planning/ROADMAP.md`; `.planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-STALE-PR-EVIDENCE.json`; `243-03-SUMMARY.md` |

### Safety Refs on Origin
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Preserve each named safety ref's type and identity, publish required refs missing on origin, and stop rather than force-update a conflicting remote ref; retain the archive ref as its existing tag. | Unclear before confirmation | `.planning/ROADMAP.md`; `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-RESEARCH.md`; `.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md` |

## Corrections Made

No corrections — the user confirmed all assumptions, including the recommended safety-ref treatment.

## Reviewed Todos

- `.planning/todos/pending/2026-09-26-phase-244-mix-ci-blocked-by-phase-242-hex-contract.md` remains separate. It blocks Phase 244 resumption but does not expand Phase 245's branch-pruning scope.

## External Research

No external research was needed. Execution requires fresh origin refs, current open PR head/base pairs, and Phase 244 completion status.
