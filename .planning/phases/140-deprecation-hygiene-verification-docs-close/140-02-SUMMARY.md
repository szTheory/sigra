---
phase: 140-deprecation-hygiene-verification-docs-close
plan: "02"
subsystem: docs
tags: [documentation, deployment-guide, maintaining, roadmap-reconciliation]
completed: "2026-05-29"
duration: "~5 min"

dependency_graph:
  requires: [140-01-PLAN.md]
  provides: [guides/recipes/deployment.md operator-diagnostics section, MAINTAINING.md three new sections, ROADMAP.md Phase 137 reconciliation]
  affects: [guides/recipes/deployment.md, MAINTAINING.md, .planning/ROADMAP.md]

tech_stack:
  added: []
  patterns: [ExDoc extras append, MAINTAINING.md directive sections, ROADMAP checkbox reconciliation]

key_files:
  created: []
  modified:
    - guides/recipes/deployment.md
    - MAINTAINING.md
    - .planning/ROADMAP.md

decisions:
  - "Section placement in deployment.md: after ## Health check endpoint, before ## Fly.io specifics — matches operator operations flow"
  - "OptionalDeps SOT scope claim explicitly scoped to runtime guards with documented exceptions (D-11)"
  - "Recipe-contract fixture note marks test as maintainer-internal, not Hex-facing (D-11)"
  - "Deprecation removal timeline uses Hex SemVer 0.x minors, not internal v1.x labels (D-01)"
  - "ROADMAP reconciliation is cosmetic only — work already landed in git, summaries confirmed 2026-05-29"

metrics:
  duration: "~5 min"
  completed: "2026-05-29"
  tasks_completed: 3
  files_modified: 3
---

# Phase 140 Plan 02: DOC-01 Guide Appends + ROADMAP Phase 137 Reconciliation Summary

Three targeted documentation edits: `mix sigra.doctor` operator diagnostics section in the deployment guide, three maintainer-audience sections in MAINTAINING.md, and cosmetic Phase 137 checkbox reconciliation in ROADMAP.md.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Add ## Operator diagnostics section to deployment.md | 49d2be5 | guides/recipes/deployment.md |
| 2 | Add three ## sections to MAINTAINING.md | b6ef1b4 | MAINTAINING.md |
| 3 | Reconcile stale ROADMAP.md Phase 137 entries | 3566ec4 | .planning/ROADMAP.md |

## What Was Done

**Task 1 — guides/recipes/deployment.md:** Inserted a new `## Operator diagnostics` section between `## Health check endpoint` and `## Fly.io specifics`. The section documents `mix sigra.doctor` with standard and `--quiet` invocations, the exit 0 / exit 1 contract, nine covered features, and four possible states per feature. Notes that absent deps are not an error (only configured-but-broken wiring triggers exit 1). Instructs operators to run from the application directory.

**Task 2 — MAINTAINING.md:** Inserted three new `##` sections after `## Semver for Sigra (pre-1.0)` and before `## Planning hygiene (without gsd-tools JSON)`:
- `## OptionalDeps single source of truth (Phase 137)` — documents `Sigra.OptionalDeps` as the canonical runtime guard module with the narrow documented exceptions (compile-time, dynamic atoms, boot-warning, doctor dynamic-forwarder).
- `## Recipe-contract fixture (Phase 139)` — documents `test/sigra/recipes/companion_lib_contract_test.exs` as a maintainer-internal CI drift guard (explicitly NOT a Hex-facing recipe).
- `## Deprecation removal timeline` — documents `cookie_opts/0` removal in `0.4.0` and `audit_forced_password_change/2` removal in `0.5.0` with migration guidance.

**Task 3 — .planning/ROADMAP.md:** Four targeted edits: flipped `[ ]` to `[x]` on lines 45 (Phase 137 heading), 70 (137-02-PLAN.md), and 71 (137-03-PLAN.md); updated progress table row from `1/3 | In Progress` to `3/3 | Complete | 2026-05-29`. Justified by 137-02-SUMMARY.md and 137-03-SUMMARY.md both carrying `completed: "2026-05-29"`.

## Deviations from Plan

None — plan executed exactly as written. All three tasks matched the specified content and placement guidance from 140-RESEARCH.md.

## Verification

```
grep "## Operator diagnostics" guides/recipes/deployment.md  → 1 match (line 205)
grep -c "mix sigra.doctor" guides/recipes/deployment.md      → 3 matches
grep -c "## OptionalDeps\|## Recipe-contract\|## Deprecation removal" MAINTAINING.md → 3
grep -n "[x].*Phase 137" .planning/ROADMAP.md               → line 45 flipped
grep "3/3.*Complete.*2026-05-29" .planning/ROADMAP.md        → match found
git diff mix.exs                                              → empty (no mix.exs changes)
```

## Known Stubs

None.

## Threat Flags

None — documentation-only changes with no new attack surface.

## Self-Check: PASSED

Files exist and are modified:
- guides/recipes/deployment.md — has `## Operator diagnostics` section
- MAINTAINING.md — has three new `##` sections
- .planning/ROADMAP.md — Phase 137 entries reconciled

Commits exist:
- 49d2be5: docs(140-02): add ## Operator diagnostics section to deployment.md
- b6ef1b4: docs(140-02): add three ## sections to MAINTAINING.md
- 3566ec4: docs(140-02): reconcile stale ROADMAP.md Phase 137 entries
