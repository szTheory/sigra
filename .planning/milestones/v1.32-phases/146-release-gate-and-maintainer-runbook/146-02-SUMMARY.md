---
phase: 146-release-gate-and-maintainer-runbook
plan: 02
subsystem: docs
tags: [release-runbook, release-please, hex, maintainer-docs]
requires:
  - phase: 146-release-gate-and-maintainer-runbook
    provides: CI release-ref dispatch and hardened publish/recovery workflow truth surface
provides:
  - Canonical 1.0 release runbook with gate matrix, evidence checklist, recovery tree, and 14-day hotfix policy
  - Maintainer routers aligned to one release-evidence source
  - Stale GA-evidence routing removed and replaced with pinned-tag proof policy
affects: [maintainer-operations, release-evidence, launch-readiness]
tech-stack:
  added: []
  patterns: [single-source runbook routing, release-ref evidence capture, explicit waiver schema]
key-files:
  created:
    - docs/release-runbook-v1-0.md
    - .planning/phases/146-release-gate-and-maintainer-runbook/146-02-SUMMARY.md
  modified:
    - MAINTAINING.md
    - docs/NEXT-STEPS-MANUAL.md
    - docs/ga-evidence.md
key-decisions:
  - "Made docs/release-runbook-v1-0.md the only full release-gate matrix and retained MAINTAINING.md as index-only maintainer entry point."
  - "Set GitHub Actions Hex publish (manual recovery) as primary no-invention recovery path; local trusted-machine publish remains fallback only."
patterns-established:
  - "All release gates require explicit evidence rows with reviewer and waiver tracking when needed."
  - "GitHub-hosted release proof outside tarball must use pinned v<version> links, never main blob URLs."
requirements-completed: [REL1-02, REL1-03]
duration: 16min
completed: 2026-05-31
---

# Phase 146 Plan 02: Release Gate And Maintainer Runbook Summary

**Canonical 1.0 release runbook shipped with deterministic gate/evidence/recovery policy, and all maintainer routers now point to that single truth surface**

## Performance

- **Duration:** 16 min
- **Started:** 2026-05-31T16:22:00Z
- **Completed:** 2026-05-31T16:38:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Created `docs/release-runbook-v1-0.md` with required gate matrix rows, evidence checklist schema, dry-run/package inspection checks, publish paths, recovery decision tree, and first-14-day hotfix policy.
- Updated `MAINTAINING.md` and `docs/NEXT-STEPS-MANUAL.md` to route maintainers to the canonical runbook while preserving index/entry-point behavior.
- Rewrote `docs/ga-evidence.md` from stale `v1.4` framing into a generic release-evidence router with pinned-tag guidance.

## Task Commits

1. **Task 146-02-01: Create the canonical 1.0 release runbook, evidence checklist, and hotfix policy** - `d2da7f0` (feat)
2. **Task 146-02-02: Point maintainer entry surfaces at the canonical runbook and retire stale release-evidence routing** - `4409ed3` (docs)

## Files Created/Modified

- `docs/release-runbook-v1-0.md` - canonical release gate and policy runbook.
- `MAINTAINING.md` - maintainer index now points to canonical runbook for Phase 146 release operations.
- `docs/NEXT-STEPS-MANUAL.md` - manual router now defers release checks/recovery details to canonical runbook.
- `docs/ga-evidence.md` - generic release-evidence router with pinned-tag proof-link policy.

## Decisions Made

- Keep `MAINTAINING.md` as stable entry-point index, not a duplicate release matrix.
- Keep `Hex publish (manual recovery)` as primary manual recovery path and explicitly demote local publish to fallback.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The Task 2 grep command pattern containing `` `?v<version>`? `` triggered shell command-substitution parsing in one verification run. Resolved by re-running acceptance checks with equivalent safe grep patterns; all criteria still passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 146 Plan 02 deliverables are complete and verified.
- Maintainers now have one canonical release runbook and aligned router docs for deterministic 1.0 release operations.

## Verification Commands Run

- `bash -lc 'set -euo pipefail; test -f docs/release-runbook-v1-0.md; rg -n "## Release Gate Matrix|## Release Evidence Checklist|## Dry Run And Package Inspection|## Publish Paths|## Post-Publish Visibility|## Recovery Decision Tree|## First 14 Days Hotfix Policy|## Post-1\.0 Release Please Cleanup" docs/release-runbook-v1-0.md; rg -n "library_tests|install_golden_contract|install_smoke|example_http_smoke|example_playwright_smoke|generated_admin_playwright_smoke|library_tests_dep_off|Release Please|Hex publish \(manual recovery\)|gh workflow run|gh run view|gh release view|mix hex.build --unpack --output sigra-hex-inspect|mix hex.publish --dry-run --yes|source_ref|release-as|Reviewer|Waiver\?|P0|P1|P2|P3|replace|revert|follow-up patch|24 hours|1 hour" docs/release-runbook-v1-0.md'`
- `bash -lc 'set -euo pipefail; rg -n "release-runbook-v1-0|gate matrix|first-14-day hotfix|manual recovery" MAINTAINING.md docs/NEXT-STEPS-MANUAL.md docs/ga-evidence.md; ! rg -n "v1\.4 GA narrative|144-VERIFICATION\.md|blob/main/.planning/phases/144" docs/ga-evidence.md; rg -n "pinned|main blob URLs" docs/ga-evidence.md; mix docs --warnings-as-errors'`
- `bash -lc 'set -euo pipefail; test -f docs/release-runbook-v1-0.md; rg -n "## Release Gate Matrix|## Release Evidence Checklist|## Dry Run And Package Inspection|## Publish Paths|## Post-Publish Visibility|## Recovery Decision Tree|## First 14 Days Hotfix Policy|## Post-1\.0 Release Please Cleanup" docs/release-runbook-v1-0.md; rg -n "release-runbook-v1-0|manual recovery|first-14-day hotfix" MAINTAINING.md docs/NEXT-STEPS-MANUAL.md docs/ga-evidence.md; ! rg -n "v1\.4 GA narrative|144-VERIFICATION\.md|blob/main/.planning/phases/144" docs/ga-evidence.md; mix docs --warnings-as-errors'`

## Self-Check: PASSED

- Found file: `docs/release-runbook-v1-0.md`
- Found file: `MAINTAINING.md`
- Found file: `docs/NEXT-STEPS-MANUAL.md`
- Found file: `docs/ga-evidence.md`
- Found file: `.planning/phases/146-release-gate-and-maintainer-runbook/146-02-SUMMARY.md`
- Found commit: `d2da7f0`
- Found commit: `4409ed3`
