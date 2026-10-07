# Phase 243: Drain the Queue — Dependabot Tiers A/B, Stale PRs, Todo Triage - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-09-24
**Phase:** 243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage
**Mode:** assumptions
**Areas analyzed:** Todo population and ownership, FUT todo identity, dependency merge failure disposition, stale PR closure reasons

## Assumptions Presented

### Todo population and ownership
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Freeze and triage all 66 pending todo files present at execution start; the 41 count is historical, and ownership markers do not replace evidence. | Confident | `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/todos/pending/` |

### FUT todo identity
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Reuse matching existing FUT records and add only missing identities; avoid duplicates caused by the roadmap's “five plus two” wording. | Likely | `.planning/REQUIREMENTS.md`, `.planning/todos/pending/2026-09-17-fut-01-template-example-parity-guard.md`, `.planning/todos/pending/2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md` |

### Dependency merge failure disposition
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Pause after an unexpected blocker/red gate, collect exact-SHA evidence and compare to baseline; revert only for a demonstrated bump-caused regression; do not make unrelated fixes. | Likely | `.planning/ROADMAP.md`, `.planning/research/FEATURES.md`, `.planning/research/PITFALLS.md` |

### Stale PR closure reasons
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Give each PR an individually accurate public reason, indexed in phase evidence, and verify its closed state and comment while retaining branches. | Likely | `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/research/PITFALLS.md` |

## Research and Recommendations

- Three focused advisor reviews compared queue failure recovery, PR closure reasons, and todo inventory/dispositions. Their cohesive recommendations were adopted in the context.
- Repository research cautions against bulk merging without reading changes and against silent PR closure. Individual PR comments are more truthful where dispositions differ.
- The recommended todo boundary is a frozen execution-start inventory. A rolling queue can expand indefinitely; the historic 41-item snapshot omits current pending work.
- The recommendation for a dependency-induced red gate is causal and evidence-based: pause first, revert only when the bump is shown to cause the failure, and do not waive checks.
- No code changes were made. External live GitHub state and job results remain execution-time evidence because they change over time.

## User Guidance

The user requested deep, subagent-supported, project-specific research and a coherent one-shot recommendation set, emphasizing expert perspectives and DX. Relevant lenses for this non-UI maintenance phase are maintainer/developer ergonomics, supply-chain security, release engineering, SRE/evidence quality, least surprise, and planning honesty. Visual design and end-user UI lenses do not apply here.

## Corrections Made

No explicit correction was made after the recommendations were presented. The user approved proceeding with the recommended set.

## External Research

- GitHub Dependabot automation documentation — required checks should be satisfied before automated dependency merges: https://docs.github.com/en/code-security/dependabot/working-with-dependabot/automating-dependabot-with-actions
- GitHub CLI PR commands — public closing comments and closed-state verification: https://cli.github.com/manual/gh_pr_close, https://cli.github.com/manual/gh_pr_view, https://cli.github.com/manual/gh_pr_list
