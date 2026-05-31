---
phase: 148-evaluator-funnel-and-first-run-dx
plan: 01
subsystem: docs
tags: [adoption, evaluator-funnel, hexdocs, llms-index]
requires:
  - phase: 147-upgrade-and-migration-lanes
    provides: explicit upgrade and migration lanes reused by top-level routing
provides:
  - Canonical evaluator-first lane in README, Hex package metadata, and AI index
  - Explicit adoption lanes for greenfield, upgrade, migration, and advanced control
affects: [readme-routing, hexdocs-landing, ai-consumption-index]
tech-stack:
  added: []
  patterns: [single canonical evaluator entry, top-level lane router]
key-files:
  created:
    - doc/llms.txt
    - .planning/phases/148-evaluator-funnel-and-first-run-dx/148-01-SUMMARY.md
  modified:
    - README.md
    - mix.exs
key-decisions:
  - "Route evaluator-first traffic to demo-showcase from every top-level docs surface in this plan scope."
  - "Keep non-evaluator adoption lanes explicit instead of collapsing into a single integration path."
patterns-established:
  - "README lane router is the top-level audience switchboard, not deep implementation content."
requirements-completed: [ADOPT-01, ADOPT-03]
duration: 7 min
completed: 2026-05-31
---

# Phase 148 Plan 01: Evaluator Funnel And First-Run DX Summary

**Unified evaluator-first entry routing across README, Hex package metadata, and AI docs index while preserving greenfield, upgrade, migration, and advanced-control lanes.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-05-31T21:08:30Z
- **Completed:** 2026-05-31T21:15:42Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Replaced README `## Pick your lane` rows with the required evaluator/greenfield/upgrade/migration/advanced-control routing map.
- Updated `mix.exs` to set ExDoc `main: "demo-showcase"` and point package description to `https://hexdocs.pm/sigra/demo-showcase.html`.
- Reordered `doc/llms.txt` Introduction entries so Demo Showcase is evaluator-first and added direct Introduction-level discoverability for `mix sigra.doctor`.

## Task Commits

1. **Task 1: Rebuild the README lane router around the canonical evaluator path** - `493281c0` (docs)
2. **Task 2: Align Hex package metadata and AI routing to the same evaluator-first guide** - `55122a1b`, `9bc2e08a` (docs)

**Plan metadata:** pending

## Files Created/Modified

- `README.md` - Replaced top-level lane table with explicit evaluator/adoption lanes and required guide links.
- `mix.exs` - Set ExDoc landing page to demo-showcase and updated package description evaluator pointer.
- `doc/llms.txt` - Moved Demo Showcase to evaluator-first Introduction position; preserved troubleshooting and doctor visibility.

## Decisions Made

- Kept README as an audience router and intentionally avoided deep implementation expansion.
- Kept upgrade and migration lanes visible in both README and AI index while still making evaluator flow first.

## Deviations from Plan

None - plan executed as specified.

## Issues Encountered

- `doc/` is ignored by default in this repository, so `doc/llms.txt` required force-staging (`git add -f`) to land as part of Task 2.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Evaluator-first entry routing is aligned for plan 148-01 surfaces.
- Ready for remaining Phase 148 plans that deepen demo walkthrough and doctor/troubleshooting contract tests.

## Verification Commands Run

- `rg -n "Pick your lane|Evaluating|Greenfield Phoenix app|Existing Sigra app / upgrade|Migrating from another auth stack|Advanced control|demo-showcase|troubleshooting-install|deployment" README.md`
- `rg -n 'main: "demo-showcase"|https://hexdocs.pm/sigra/demo-showcase.html|Demo Showcase — Vaultr Example App|mix sigra.doctor|Troubleshooting' mix.exs doc/llms.txt`
- `mix docs --warnings-as-errors`
- `rg -n "demo-showcase|Greenfield Phoenix app|Existing Sigra app / upgrade|Migrating from another auth stack|Advanced control" README.md mix.exs doc/llms.txt`

## Known Stubs

None.

## Self-Check: PASSED

- Found summary file: `.planning/phases/148-evaluator-funnel-and-first-run-dx/148-01-SUMMARY.md`
- Found commit `493281c0` in git history
- Found commit `55122a1b` in git history
- Found commit `9bc2e08a` in git history
