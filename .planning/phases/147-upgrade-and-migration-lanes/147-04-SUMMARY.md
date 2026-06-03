---
phase: 147-upgrade-and-migration-lanes
plan: 04
subsystem: docs
tags: [release-evidence, upgrade, migration, ci, runbook]
requires:
  - phase: 147-upgrade-and-migration-lanes
    provides: upgrade smoke lane and migration guides
provides:
  - Release runbook includes dedicated `upgrade_smoke` release proof lane
  - UAT-vs-CI coverage captures v1.32 machine-vs-editorial migration boundary
  - GA evidence router points to upgrade/migration canonical guides and smoke proof lane
affects: [release-evidence, maintainer-operations, adoption-docs]
tech-stack:
  added: []
  patterns: [router-style evidence docs, machine-vs-editorial proof boundary notes]
key-files:
  created:
    - .planning/phases/147-upgrade-and-migration-lanes/147-04-SUMMARY.md
  modified:
    - docs/release-runbook-v1-0.md
    - docs/uat-ci-coverage.md
    - docs/ga-evidence.md
key-decisions:
  - "Keep migration lanes explicitly editorial/human-reviewed and avoid claims of automated cutover equivalence."
  - "Thread `upgrade_smoke` into canonical release and evidence surfaces instead of duplicating gate matrices."
patterns-established:
  - "Release evidence updates must name machine proof lanes and residual human judgment boundaries separately."
requirements-completed: [UPGRADE-01, UPGRADE-02, MIGRATE-01, MIGRATE-02]
duration: 1 min
completed: 2026-05-31
---

# Phase 147 Plan 04: Upgrade And Migration Lanes Summary

**Release evidence surfaces now explicitly carry the `upgrade_smoke` lane and route maintainers to canonical upgrade/migration proof docs with a clear machine-vs-editorial boundary**

## Performance

- **Duration:** 1 min
- **Started:** 2026-05-31T14:16:51-04:00
- **Completed:** 2026-05-31T18:17:18Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added `upgrade_smoke` as a first-class gate in both the runbook release matrix and release evidence checklist.
- Added `## v1.32 upgrade and migration proof` in UAT/CI coverage, explicitly separating machine proof (`upgrade_smoke` + `scripts/ci/upgrade-smoke.sh`) from residual editorial migration judgment.
- Added `## Upgrade and migration proof` router section in GA evidence linking the three canonical guide pages and naming the canonical machine proof lane.

## Task Commits

1. **Task 1: Add upgrade-smoke release proof and machine-vs-editorial boundary notes** - `8641bc6` (docs)
2. **Task 2: Route the GA evidence hub to the new upgrade and migration proof surfaces** - `5d9f612` (docs)

## Files Created/Modified

- `docs/release-runbook-v1-0.md` - Added `upgrade_smoke` row to release gate matrix and release evidence checklist.
- `docs/uat-ci-coverage.md` - Added v1.32 proof section with machine-vs-editorial migration boundary wording.
- `docs/ga-evidence.md` - Added router section linking upgrade/migration guides and smoke proof lane.

## Decisions Made

- Keep the GA evidence page as a router and avoid duplicating release gate matrix content.
- Treat migration-lane residuals as editorial review only, not executable cutover automation.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 147 is fully documented across runbook, CI coverage, and evidence routing surfaces.
- Ready for Phase 148 evaluator funnel and first-run DX work.

## Verification Commands Run

- `mix docs --warnings-as-errors`
- `rg -n 'upgrade_smoke|v1\.32 upgrade and migration proof|UPGRADE-02|MIGRATE-01|MIGRATE-02|scripts/ci/upgrade-smoke\.sh' docs/release-runbook-v1-0.md docs/uat-ci-coverage.md`
- `rg -n 'Upgrade and migration proof|upgrading-to-v1.0|migrating-from-phx-gen-auth|migrating-from-pow-guardian-ueberauth|upgrade_smoke|latest published 0\.3\.x' docs/ga-evidence.md`

## Self-Check: PASSED

- Found file: `.planning/phases/147-upgrade-and-migration-lanes/147-04-SUMMARY.md`
- Found file: `docs/release-runbook-v1-0.md`
- Found file: `docs/uat-ci-coverage.md`
- Found file: `docs/ga-evidence.md`
- Found commit: `8641bc6`
- Found commit: `5d9f612`
