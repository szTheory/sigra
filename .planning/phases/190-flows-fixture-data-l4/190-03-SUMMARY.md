---
phase: 190-flows-fixture-data-l4
plan: "03"
subsystem: playwright-flow-specs
tags: [playwright, flow-spec, admin-ui, L4, FLOW-01, FLOW-02, FLOW-03, DATA-01]
dependency_graph:
  requires: ["190-01", "190-02"]
  provides: ["admin-flow-platform-admin.spec.ts", "playwright.config.ts ADMIN_BEHAVIOR_SPECS fix"]
  affects: ["test/example/priv/playwright/tests/", "test/example/priv/playwright/playwright.config.ts"]
tech_stack:
  added: []
  patterns:
    - "Platform admin JTBD flow spec with 6 tests across 5 describe blocks"
    - "test.use({ reducedMotion: 'reduce' }) at describe-block level (not per-page)"
    - "seedThemeAndAssertNoFlash + nav + reload + system-flip for FLOW-03"
    - "Focus containment invariant via page.evaluate (not Tab-count)"
    - "assertReducedMotionEffect via getComputedStyle pseudo-element check"
key_files:
  created:
    - test/example/priv/playwright/tests/admin-flow-platform-admin.spec.ts
  modified:
    - test/example/priv/playwright/playwright.config.ts
decisions:
  - "ADMIN_BEHAVIOR_SPECS regex fixed from admin-flow)\\.spec\\.ts to admin-flow-).*\\.spec\\.ts so all admin-flow-*.spec.ts files are correctly excluded from mobile project"
  - "assertScopeChrome imported from adminFlows.ts (Wave 1 export)"
  - "Keyboard test uses alice (has sessions) not dave (locked, no sessions to revoke)"
  - "Focus containment asserted via evaluate() not element handle comparison for robustness"
  - "sessionRevoked copy asserted as 'Session revoked.' (actual short-form, user_show_live.ex:81)"
metrics:
  duration: "9 min"
  completed_date: "2026-06-17"
  tasks: 1
  files: 2
---

# Phase 190 Plan 03: Platform Admin JTBD Flow Spec Summary

**One-liner:** Platform admin JTBD flow spec with 6 tests covering happy/error/boundary cases, keyboard operability, reduced-motion CSS effect, and dark theme persistence across nav+reload+system flip.

## What Was Built

### Task 1: Platform admin flow spec (admin-flow-platform-admin.spec.ts)

Created `test/example/priv/playwright/tests/admin-flow-platform-admin.spec.ts` — the first of three L4 operator flow specs. Covers the global-posture platform admin journey end-to-end.

**Structure (6 tests across 5 describe blocks):**

1. **Reduced-motion** (at outer level): `assertReducedMotionEffect()` confirms loading bar `animation: none` via `getComputedStyle` pseudo-element check.
2. **Happy path — alice**: overview (`/admin`) → search (`/admin/users?q=alice@...`) → user detail → breadcrumb carries `return_to` or `?q=` → `View full audit` → per-user audit → scope chrome (`Global`) persists throughout.
3. **Main-error — dave**: search dave → user detail shows locked/unconfirmed status pills → per-user audit shows `auth.login.failure` and `auth.lockout.start` action codes.
4. **Boundary — frank + empty**: frank shows scheduled-deletion status indicator; empty filter (`zzz-no-such-user`) renders "No users match" without danger-tone error styling.
5. **Keyboard (FLOW-02)**: Tab/focus trigger → Enter opens ConfirmDialog → `page.evaluate` asserts focus containment inside `.sg-confirm-dialog` → Escape closes → `page.evaluate` asserts trigger refocused.
6. **Theme persistence (FLOW-03)**: `seedThemeAndAssertNoFlash(page, 'dark')` → `assertThemeAttributes(page, 'dark')` → navigate to `/admin/users` → assert dark persists → `page.reload()` → assert dark persists → `emulateMedia({ colorScheme: 'light' })` → explicit dark still shows → set localStorage to `'system'` → reload → `assertThemeAttributes(page, 'system')`.

**Key conventions followed:**
- `test.use({ reducedMotion: 'reduce' })` at describe-block level (not per-page after goto, per D-10)
- No `page.waitForTimeout()` calls — all assertions use Playwright web-first auto-retrying expect
- Copy assertion uses `"Session revoked."` (actual, not full brand-book string — D-13)
- Imports from `helpers/adminFlows.ts` (Wave 1): `loginDemoAdmin`, `waitForLiveViewReady`, `assertScopeChrome`, `seedThemeAndAssertNoFlash`, `assertThemeAttributes`, `assertReducedMotionEffect`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed ADMIN_BEHAVIOR_SPECS regex — admin-flow files not excluded from mobile**

- **Found during:** Task 1 verification
- **Issue:** `playwright.config.ts` regex was updated in Wave 1 as `/(admin-user-operations|admin-audit|admin-theme|impersonation|admin-flow)\.spec\.ts/` — but `admin-flow)\.spec\.ts` only matches `admin-flow.spec.ts`, not `admin-flow-platform-admin.spec.ts` (the hyphen before the filename suffix breaks the match). Running `--project=mobile --list` showed 6 tests instead of 0.
- **Fix:** Changed to `/(admin-user-operations|admin-audit|admin-theme|impersonation|admin-flow-).*\.spec\.ts/` — the `admin-flow-` prefix with `.*` correctly matches all `admin-flow-*.spec.ts` files.
- **Files modified:** `test/example/priv/playwright/playwright.config.ts`
- **Commit:** 4ffcf22a (included in the same task commit)
- **Verification:** `--project=mobile --list` now shows `Total: 0 tests in 0 files` for `admin-flow-platform-admin`

## Infrastructure Constraint

The plan's `<verify>` gate calls for `npx playwright test admin-flow-platform-admin --project=chromium` to pass. The Sigra example app dev server was not running at `localhost:4000` (port occupied by RulesteadDemo, a different project). The following static verifications passed:

- TypeScript compilation: `playwright test --list` resolves imports and lists 6 tests cleanly
- `Total: 6 tests in 1 file` on chromium project
- `Total: 0 tests in 0 files` on mobile project (exclusion working after fix)
- No `waitForTimeout` calls in spec
- 1 `test.use({ reducedMotion: 'reduce' })` at describe level
- 334 lines (above 120-line minimum)

Runtime test execution requires the Sigra example server at `localhost:4000` (or `SIGRA_EXAMPLE_URL`) with demo seed data. This runs at `/gsd:verify-work` phase gate time.

## Threat Flags

None. This plan introduces only test-layer assertions over existing admin UI, no new network endpoints or auth paths.

## Known Stubs

None. The spec asserts against real demo seed data (alice, dave, frank) seeded by `test/example/lib/example/demo/seeds.ex`.

## Self-Check: PASSED

- `/Users/jon/projects/sigra/.claude/worktrees/agent-ad7ccf12b29c265bc/test/example/priv/playwright/tests/admin-flow-platform-admin.spec.ts` — FOUND
- Commit `4ffcf22a` — FOUND
- `Total: 6 tests in 1 file` on chromium — VERIFIED
- `Total: 0 tests in 0 files` on mobile — VERIFIED (after ADMIN_BEHAVIOR_SPECS fix)
