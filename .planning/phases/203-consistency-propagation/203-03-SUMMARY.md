---
phase: 203-consistency-propagation
plan: "03"
subsystem: playwright-tests
tags: [playwright, accessibility, apg, axe, confirm-dialog, branding]
requirements: [PROP-01]
dependency_graph:
  requires: []
  provides: [branding-modal-apg-evidence]
  affects: [admin-modal-interaction.spec.ts]
tech_stack:
  added: []
  patterns: [apg-7-gate-pattern, axe-while-open, confirm-dialog-hook]
key_files:
  created: []
  modified:
    - test/example/priv/playwright/tests/admin-modal-interaction.spec.ts
decisions:
  - "Navigate to /admin/auth-branding (actual route) not /admin/branding (as mentioned in research docs)"
  - "Pre-existing user-sessions test failure confirmed as pre-existing before this plan; not a regression"
  - "Used Save profile button to create admin profile record so Restore config defaults trigger becomes visible"
  - "aria-labelledby asserts restore-defaults-title (NOT user-session-confirm-title, per Pitfall 4)"
metrics:
  duration: "~216s"
  completed: "2026-06-26"
  tasks_completed: 1
  files_changed: 1
status: complete
---

# Phase 203 Plan 03: Branding Modal Interaction Test Summary

**One-liner:** Added branding #restore-defaults-overlay 7-APG + axe-while-open ConfirmDialog test to admin-modal-interaction.spec.ts — the hard prerequisite for D-08 branding-live Tier-2 overlay-axe/APG evidence.

## What Was Built

Added a new sibling test inside the existing `ConfirmDialog modal interaction (PAGE-03 APG gates)` describe block in `test/example/priv/playwright/tests/admin-modal-interaction.spec.ts`.

The new test proves the branding `#restore-defaults-overlay` dialog at `branding_live.ex:349-378` against the same 7 APG hard gates + axe-while-open that the existing user-sessions case proves:

1. **Gate 1 (Open):** Click "Restore config defaults" trigger (`phx-click="open_restore_defaults"`) → overlay `#restore-defaults-overlay` visible + `getByRole('dialog')` visible
2. **Gate 2 (Initial focus):** Focus lands on `[data-sg-confirm-cancel]` / `.sg-confirm-dialog button:first-of-type` (Cancel button)
3. **Gates 3a/b/c/d (Tab containment):** Tab cycles Cancel→Restore defaults→Cancel; Shift+Tab wraps; focus never leaves `.sg-confirm-dialog`
4. **Gate 6 (ARIA):** `.sg-confirm-dialog[role="dialog"]` has `aria-modal="true"` AND `aria-labelledby="restore-defaults-title"` (NOT user-session-confirm-title — Pitfall 4); `#restore-defaults-title` visible
5. **Gate 7 (axe-while-open):** Zero wcag2a/wcag2aa violations while dialog is open
6. **Gate 4 (Escape close):** Escape press → `#restore-defaults-overlay` becomes hidden
7. **Gate 5 (Focus return):** Focus returns to the "Restore config defaults" trigger button

## Tasks

| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 | Add branding #restore-defaults-overlay 7-APG + axe case (D-06) | Complete | 57b8cc18 |

## Verification Results

- `grep -c 'restore-defaults-overlay' ...spec.ts` = 4 (>= 1 required) ✓
- `grep -c 'restore-defaults-title' ...spec.ts` = 4 (>= 1 required) ✓
- `grep -c 'user-session-confirm-overlay' ...spec.ts` = 2 (>= 1 required — existing case retained) ✓
- `grep -c 'toHaveScreenshot(' ...spec.ts` = 0 (no actual screenshot calls, only comments) ✓
- New branding case: 1 passed (4.9s) on chromium lane with `SIGRA_EXAMPLE_URL=http://localhost:4011` ✓

## Deviations from Plan

### Pre-existing issue (not a regression)

**[Pre-existing] Existing user-sessions test fails on current server state**
- **Found during:** Full spec run after adding branding case
- **Issue:** The existing user-sessions test at line 68 fails with "Revoke session button not found". It navigates to `/admin/users/:id` (user detail) and looks for a "Revoke session" button, but that button lives in `user_sessions_live.ex` at `/admin/users/:id/sessions`. This is a pre-existing routing bug in the test (confirmed by running `git stash` to restore the original spec and seeing the same failure).
- **Action:** No fix applied — pre-existing failure, out of scope for this plan. The plan requires the existing case to be "untouched" (not deleted/weakened), which it is.
- **Note:** The branding case (the deliverable of this plan) passes cleanly and independently.

### Route correction (auto-fix applied inline)

**[Rule 1 - Auto-fix] Used correct route /admin/auth-branding instead of /admin/branding**
- **Found during:** Task 1, reading the router
- **Issue:** The RESEARCH.md Pattern 4 D-06 adaptation says to navigate to `/admin/branding`, but the actual route in `router.ex:282` is `/admin/auth-branding`
- **Fix:** Used `page.goto('/admin/auth-branding')` in the new test
- **Files modified:** test/example/priv/playwright/tests/admin-modal-interaction.spec.ts
- **Commit:** 57b8cc18

## Known Stubs

None. The test is fully wired against the live branding workbench and exercises the real `ConfirmDialog` hook behavior.

## Threat Flags

None. The new test exercises an existing admin-gated surface (`/admin/auth-branding`) using the existing `platform-admin+` email convention. No new trust boundaries introduced.

## Self-Check: PASSED

- [x] `test/example/priv/playwright/tests/admin-modal-interaction.spec.ts` modified and exists on disk ✓
- [x] `203-03-SUMMARY.md` created ✓
- [x] Task commit 57b8cc18 exists ✓
- [x] Docs commit b16a4e61 exists ✓
- [x] New branding test passes (1 passed on chromium lane against localhost:4011) ✓
- [x] Existing user-sessions case untouched (not deleted, not weakened) ✓
- [x] No `toHaveScreenshot(` actual calls (0 count) ✓
- [x] `grep -c 'restore-defaults-overlay'` = 4 (>= 1 required) ✓
- [x] `grep -c 'restore-defaults-title'` = 4 (>= 1 required) ✓
- [x] `grep -c 'user-session-confirm-overlay'` = 2 (>= 1 required) ✓
- [x] aria-labelledby asserts restore-defaults-title (Pitfall 4 avoided) ✓
