---
phase: 160-regression-hardening-baseline-ratification
plan: 03
subsystem: testing
tags: [playwright, snapshots, dark-mode, wcag, axe, admin-ui]

# Dependency graph
requires:
  - phase: 160-01
    provides: D-06 brand-strong CSS fix that causes legitimate dark baseline diffs

provides:
  - 7 updated dark checkpoint baselines reflecting brand-strong WCAG-AA fix
  - steady-state empty snapshot-allowlist (no phase-specific slug entries)
  - axe WCAG-AA confirmation: 0 contrast violations on dark brand-chrome surfaces

affects:
  - 160-04 (milestone proof bundle references these re-recorded baselines)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Sanctioned re-record pattern: populate allowlist → bulk re-record → restore canary → run gate → reset allowlist"
    - "snapshot-canary-guard --require-all enforces both: ALL declared slugs changed AND no undeclared slug changed"
    - "Gate exit 0 IS the axe confirmation (assertNoAxeViolations runs inside each checkpoint capture)"

key-files:
  created: []
  modified:
    - test/example/priv/playwright/snapshot-allowlist
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-dark.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-overview-admin-checkpoints-dark.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-audit-admin-checkpoints-dark.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-user-index-admin-checkpoints-dark.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-detail-admin-checkpoints-dark.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-scoped-admin-admin-checkpoints-dark.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/audit-explorer-admin-checkpoints-dark.png

key-decisions:
  - "impersonation-banner canary restored from git HEAD after bulk --update-snapshots=all (canary must never re-record)"
  - "snapshot-allowlist reset to steady-state in separate commit from re-records for reviewability (D-03)"
  - "GATE-01 dark-AA claim now genuinely true: axe runs inside each checkpoint capture, gate exit 0 confirms 0 violations"

patterns-established:
  - "Sanctioned re-record sequence: pre-compile → boot server → update allowlist → bulk re-record → restore canary → verify diff → run gate → reset allowlist → final commit"

requirements-completed:
  - GATE-01

# Metrics
duration: 15min
completed: 2026-06-05
---

# Phase 160 Plan 03: Dark Baseline Ratification (D-06 Brand-Strong Fix) Summary

**7 dark admin-checkpoint PNGs re-recorded for WCAG-AA brand-strong fix; impersonation-banner canary byte-green; axe 0 violations; snapshot-allowlist reset to steady state**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-06-05T09:45:00Z
- **Completed:** 2026-06-05T09:58:00Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Re-recorded exactly 7 dark checkpoint baselines (global-overview, org-overview, user-audit, global-user-index, user-detail, org-scoped-admin, audit-explorer) to incorporate the D-06 brand-strong WCAG-AA fix from Plan 01
- impersonation-banner canary restored from git HEAD — byte-green, never re-recorded
- snapshot-recapture-gate.sh exits 0: 3-project compare green, canary guard PASS (7 changed slug(s), all within allowlist), ExUnit component byte-goldens 19/0
- axe WCAG-AA 0 violations on dark brand-chrome surfaces confirmed by gate exit 0
- snapshot-allowlist reset to steady-state (comment block only, 0 slug entries) per D-03

## Task Commits

Each task was committed atomically:

1. **Task 1: Populate snapshot-allowlist with 7 dark slugs, re-record dark baselines, verify axe green** - `e3cacd1b` (feat)
2. **Task 2: Reset snapshot-allowlist to steady-state (D-03)** - `4e028d90` (chore)

## Files Created/Modified

- `test/example/priv/playwright/snapshot-allowlist` - Reset to steady-state (comment block only, 0 slug entries)
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-dark.png` - Re-recorded
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-overview-admin-checkpoints-dark.png` - Re-recorded
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-audit-admin-checkpoints-dark.png` - Re-recorded
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-user-index-admin-checkpoints-dark.png` - Re-recorded
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-detail-admin-checkpoints-dark.png` - Re-recorded
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-scoped-admin-admin-checkpoints-dark.png` - Re-recorded
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/audit-explorer-admin-checkpoints-dark.png` - Re-recorded

## Decisions Made

- Impersonation-banner canary restored from `git checkout HEAD` after `--update-snapshots=all` re-recorded all 8 dark slugs including the canary
- Allowlist populated before re-record (Task 1) and reset in a separate commit (Task 2) to keep the intent reviewable in git history
- Gate exit 0 serves as the axe WCAG-AA confirmation — `assertNoAxeViolations` runs inside each checkpoint capture in the spec, so a clean compare-mode run with all 3 projects passing IS the axe proof

## Deviations from Plan

None - plan executed exactly as written. The `--update-snapshots=all` re-recorded all 8 dark PNGs (including canary) as documented in the environment notes; canary was restored from HEAD per the prescribed procedure.

## Issues Encountered

None. The Chimeway.Repo connection errors in ExUnit output are pre-existing test isolation noise (unrelated repo attempting to connect without a database key) — 19 tests, 0 failures confirmed.

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Next Phase Readiness

- Plan 03 complete: 7 dark baselines re-recorded, gate green, allowlist steady-state
- Ready for Plan 04: milestone proof bundle assembly (GATE-01/GATE-02 flip, v1.34-MILESTONE-AUDIT.md)
- GATE-01 dark-AA claim is now genuinely true (no latent dark-contrast gap)

## Self-Check: PASSED

Files exist:
- FOUND: test/example/priv/playwright/snapshot-allowlist
- FOUND: test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-dark.png
- FOUND: test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-overview-admin-checkpoints-dark.png
- FOUND: test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-audit-admin-checkpoints-dark.png
- FOUND: test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-user-index-admin-checkpoints-dark.png
- FOUND: test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-detail-admin-checkpoints-dark.png
- FOUND: test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-scoped-admin-admin-checkpoints-dark.png
- FOUND: test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/audit-explorer-admin-checkpoints-dark.png

Commits exist:
- FOUND: e3cacd1b (feat(160-03): re-record 7 dark checkpoint baselines)
- FOUND: 4e028d90 (chore(160-03): reset snapshot-allowlist to steady-state)

---
*Phase: 160-regression-hardening-baseline-ratification*
*Completed: 2026-06-05*
