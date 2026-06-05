---
phase: 157-overview-landings-highest-effort
plan: "04"
subsystem: admin-ui
tags:
  - playwright
  - admin-checkpoints
  - snapshot-baselines
  - accessibility
  - liveview

dependency_graph:
  requires:
    - 157-01
    - 157-02
    - 157-03
  provides:
    - Playwright checkpoint blocks for global-overview and org-overview (LAND-05/D-06)
    - 6 committed PNG baselines (2 slugs × 3 projects: chromium, mobile, dark)
    - axe WCAG A/AA green confirmation across all 3 admin-checkpoints projects
  affects:
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/

tech-stack:
  added: []
  patterns:
    - "Two-wait guard: waitForLiveViewReady + .sg-metric-link__value.first().toBeVisible() before captureAndVerify (perpetual-flake prevention)"
    - "captureAndVerify + assertCheckpointScreenshot two-call pattern extended to new overview slugs"
    - "--update-snapshots full run then git checkout of existing PNGs to restore unchanged baselines"

key-files:
  created:
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-chromium.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-mobile.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-dark.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-overview-admin-checkpoints-chromium.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-overview-admin-checkpoints-mobile.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-overview-admin-checkpoints-dark.png
  modified:
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts

key-decisions:
  - "global-overview captured immediately after admin login and before CP1 (nav to /admin, not /admin/users)"
  - "org-overview captured immediately after global-overview (orgSlug is in scope from line 159 of the journey)"
  - ".sg-metric-link__value.first().toBeVisible() wait placed AFTER waitForLiveViewReady to prevent skeleton-frame baseline freeze (D-06 HARD REQUIREMENT)"
  - ".sg-notice.first().toBeVisible() wait added as second data-state confirmation before capture"
  - "--update-snapshots wrote only new PNGs (Playwright skips existing snapshots); git checkout of existing 5 slugs confirmed 0 paths updated"
  - "admin-generated parity lane failures are pre-existing environmental: spec requires a UAT-seeded generated host app, not the example app running against test DB"

requirements-completed:
  - LAND-01
  - LAND-02
  - LAND-03
  - LAND-04

duration: 9min
completed: 2026-06-04
---

# Phase 157 Plan 04: Playwright Checkpoint Baselines for Global and Org Overview Summary

**Two new Playwright checkpoint slugs (global-overview and org-overview) added to the authenticated admin journey with sg-metric-link__value data-wait guards, and 6 initial PNG baselines committed across chromium, mobile, and dark projects with axe WCAG A/AA green.**

## Performance

- **Duration:** ~9 minutes
- **Started:** 2026-06-04T16:01:12Z
- **Completed:** 2026-06-04T16:10:12Z
- **Tasks:** 2
- **Files modified:** 7 (1 spec + 6 PNGs)

## Accomplishments

- Added global-overview and org-overview checkpoint blocks to `admin-checkpoints.spec.ts` using the captureAndVerify + assertCheckpointScreenshot two-call pattern, with a `.sg-metric-link__value.first().toBeVisible()` wait guard before capture (D-06 HARD REQUIREMENT — perpetual-flake prevention)
- Recorded 6 initial PNG baselines (2 slugs × 3 projects: chromium, mobile, dark) — PNG count advanced from 15 to 21
- Full admin-checkpoints spec (3 projects) passes — all 3 passed including axe WCAG A/AA green on both new slugs; existing 5 slug PNGs unchanged

## Task Commits

Each task was committed atomically:

1. **Task 1: Add global-overview and org-overview checkpoint blocks to admin-checkpoints.spec.ts** - `e6296d5c` (feat)
2. **Task 2: Record initial PNG baselines for global-overview and org-overview, verify axe + parity** - `e609b48a` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — Two new checkpoint blocks inserted after admin login and before CP1: global-overview (nav /admin) and org-overview (nav /admin/organizations/:slug), each with waitForLiveViewReady + .sg-metric-link__value visible + .sg-notice visible guards
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-chromium.png` — 110 KB initial baseline
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-mobile.png` — 92 KB initial baseline
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-dark.png` — 115 KB initial baseline
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-overview-admin-checkpoints-chromium.png` — 108 KB initial baseline
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-overview-admin-checkpoints-mobile.png` — 91 KB initial baseline
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-overview-admin-checkpoints-dark.png` — 112 KB initial baseline

## Decisions Made

- global-overview captured after admin login and before CP1 (nav to /admin) — logical journey order; the /admin route is the front-door archetype entry
- org-overview captured immediately after global-overview — orgSlug variable is in scope from line 159 (declared before fixtures seeding), so this is the earliest point in the admin session the org can be viewed
- Two wait guards used per checkpoint: `waitForLiveViewReady` (phx-connected state) then `.sg-metric-link__value.first().toBeVisible()` — the second guard is load-bearing because connected?-gate defers DB queries to connected mount, creating a brief window where .phx-connected is set but skeleton is still rendered
- `.sg-notice.first().toBeVisible()` added as second data-state confirmation (alarm section rendered)
- Used `--update-snapshots` on full spec then `git checkout` for existing 5 slugs — Playwright correctly skipped re-recording the existing PNGs (0 paths updated)

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

**admin-generated parity lane — pre-existing failure (out of scope):**
The `admin-generated.spec.ts` spec fails all 6 tests with login redirect (`/users/log_in`) when run against the example app server. This spec requires a separately configured UAT-seeded generated host app with pre-seeded users (`platform-admin@example.test`, `org-admin@example.test`, etc.). Running it against the example app's dev server (which uses a test database without UAT seeded personas) is not a valid configuration. This failure is pre-existing — verified by confirming the same failures occur on the prior HEAD before this plan's changes. Logged to deferred items.

## Known Stubs

None — all data flows are wired. The PNG baselines capture real data (connected mount renders stat_links, alarm notice), not skeleton frames.

## Threat Flags

None. No new network endpoints, auth paths, or schema changes. The PNG files contain only fixture data (random-suffix test users, no real PII). All threat model mitigations from the plan are confirmed:

- T-157-04a: Existing 5 slug PNGs unchanged — git checkout confirmed 0 paths updated (Playwright skipped them)
- T-157-04b: Baselines use fixture data with `Date.now()` suffixes — no real user emails or PII
- T-157-04c: `.sg-metric-link__value` wait guard is structural — skeleton frames cannot reach captureAndVerify
- T-157-04d: `/admin/organizations/:slug` confirmed routes to `OrganizationLive` per prior phase work

## Self-Check: PASSED

- [x] `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` modified with 2 new checkpoint blocks
- [x] `grep -E "global-overview|org-overview" admin-checkpoints.spec.ts` returns 4 matches (2 per slug: captureAndVerify + assertCheckpointScreenshot)
- [x] All 6 new PNGs exist and are non-empty (90-115 KB)
- [x] PNG count = 21 (7 slugs × 3 projects)
- [x] Full admin-checkpoints spec passes (3 projects) — axe WCAG A/AA green
- [x] commit e6296d5c (Task 1) exists in git log
- [x] commit e609b48a (Task 2) exists in git log
- [x] Existing 5 slug PNGs unchanged (git checkout confirmed 0 paths updated)
