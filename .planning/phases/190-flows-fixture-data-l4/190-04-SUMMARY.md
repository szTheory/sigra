---
phase: 190-flows-fixture-data-l4
plan: "04"
subsystem: playwright-specs
tags: [playwright, admin-flow, jtbd, impersonation, org-admin, e2e]
dependency_graph:
  requires: ["190-01", "190-02"]
  provides: ["admin-flow-support-investigator.spec.ts", "admin-flow-org-admin.spec.ts"]
  affects: ["chromium behavior-truth lane", "ADMIN_BEHAVIOR_SPECS regex exclusion"]
tech_stack:
  added: []
  patterns:
    - "test.use({ reducedMotion: 'reduce' }) at describe-block level (D-10)"
    - "openUserDetail helper scoped to adminUsersEmailLocator (visibility filter)"
    - "Browser context isolation for theme initScript + 403 tests"
    - "Date-range filter boundary (2020 range) for deterministic empty-state assertion"
key_files:
  created:
    - test/example/priv/playwright/tests/admin-flow-support-investigator.spec.ts
    - test/example/priv/playwright/tests/admin-flow-org-admin.spec.ts
  modified: []
decisions:
  - "Step 9 of investigator happy path navigates to /organizations/acme-corp/settings (not /organizations/acme-corp — no such route)"
  - "Empty audit boundary uses date-range filter to 2020 rather than morgan user audit page — loginDemoMorgan in beforeEach creates live session.create events, making morgan's per-user audit non-empty"
  - "Theme test uses fresh browser context (browser.newContext) to isolate addInitScript from shared beforeEach page"
metrics:
  duration: "~120 minutes (continuation from prior session)"
  completed: "2026-06-17T19:21:32Z"
  tasks_completed: 2
  files_created: 2
---

# Phase 190 Plan 04: Investigator + Org Admin JTBD Flow Specs Summary

Two Playwright spec files authored covering the support investigator and org admin JTBD flows — completing FLOW-01/02/03 and DATA-01 L4 coverage with impersonation banner continuity, 403 anti-enumeration, and empty-state boundary assertions.

## Tasks Completed

### Task 1: admin-flow-support-investigator.spec.ts (commit: 1d547ece)

Support investigator JTBD flow spec. Five tests on the chromium behavior-truth lane:

- **Happy path** (alice): loginDemoAdmin → search alice → open user detail → per-user audit (sees alice events) → sudo confirm → Start impersonation → banner shows "Impersonating Alice" / "Signed in as Admin" → navigate to /organizations/acme-corp/members (banner persists) → navigate to /organizations/acme-corp/settings (banner persists across navigation, D-12) → End impersonation → URL is `/admin/users?.*q=` → assertScopeChrome('Global')
- **Main-error** (dave): user detail shows `.sg-status-pill[data-tone="risk"]` Locked pill — no impersonation attempt (D-01 scope boundary)
- **Boundary** (frank): user detail shows `.sg-status-pill[data-tone="warn"]` Deletion scheduled pill
- **Keyboard** (FLOW-02): Tab navigation + sudo flow + impersonation start via keyboard + scope chrome assertion after return
- **Theme** (FLOW-03): dark theme seeded via addInitScript → survives impersonation journey → page.reload() → assertThemeAttributes persists

### Task 2: admin-flow-org-admin.spec.ts (commit: dea4e480)

Org admin JTBD flow spec. Five tests on the chromium behavior-truth lane:

- **Happy path** (morgan): loginDemoMorgan → /admin/organizations/acme-corp (200) → assertScopeChrome('Acme Corp') → org users list shows alice → openOrgUserDetail(alice) → scope chrome still Acme Corp
- **Main-error** (403): Fresh browser context → loginDemoMorgan → page.goto('/admin') → response.status() === 403 → body contains generic denial copy → body NOT containing 'Acme Corp' or morgan's email (T-190-10 anti-enumeration)
- **Boundary** (empty state): Org audit index → fill date filter 2020-01-01 to 2020-01-02 → Apply filters → `.sg-empty-state` visible with "No audit events match this view"
- **Keyboard** (FLOW-02): Tab focus check + Search button focus assertion in org-scoped view
- **Theme** (FLOW-03): Fresh browser context → addInitScript dark → loginDemoMorgan → org admin journey → assertThemeAttributes persists → page.reload() → assertThemeAttributes persists

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Step 9 in happy path used non-existent route /organizations/acme-corp**
- **Found during:** Task 1 first test run (Phoenix.Router.NoRouteError)
- **Issue:** Plan said navigate to `/organizations/acme-corp` but this route doesn't exist in ExampleWeb.Router — only `/organizations/:org/settings` and `/organizations/:org/members` exist
- **Fix:** Changed step 9 navigation to `/organizations/acme-corp/settings`
- **Files modified:** admin-flow-support-investigator.spec.ts

**2. [Rule 1 - Bug] Morgan empty audit assumption invalid during test runs**
- **Found during:** Task 2 first test run — `.sg-empty-state` not visible on morgan's per-user audit page
- **Issue:** The `beforeEach` calls `loginDemoMorgan` for every test, creating a `session.create` audit event for morgan on each run. Morgan's per-user audit page therefore shows events even though seeds have 0 events for morgan
- **Fix:** Changed the boundary test to use org audit INDEX page (`/admin/organizations/acme-corp/audit`) with a 2020 date range filter — guaranteed zero results independent of test-created events. The empty_state title changed from "No audit events for this user" (AuditUserLive) to "No audit events match this view" (AuditIndexLive), which is equally valid for the DATA-01 boundary coverage
- **Files modified:** admin-flow-org-admin.spec.ts

**3. [Rule 1 - Bug] Theme test re-called loginDemoMorgan on already-authenticated page**
- **Found during:** Task 2 first test run — `page.fill('#login_form input[name="user[email]"]')` timeout
- **Issue:** The theme describe block called `loginDemoMorgan(page)` but the outer `beforeEach` had already logged morgan in and navigated to `/admin/organizations/acme-corp`. Calling `loginDemoMorgan` again navigated to `/users/log_in` which immediately redirected (session active), so `#login_form` was never found
- **Fix:** Changed theme test to use `browser.newContext()` for a fresh page with no prior session, matching the pattern already used by the 403 test. This also correctly isolates `addInitScript` from shared-context beforeEach navigations
- **Files modified:** admin-flow-org-admin.spec.ts

**4. [Rule 1 - Bug] Audit filter input names were wrong**
- **Found during:** Task 2 boundary test implementation
- **Issue:** Initial implementation used `input[name="filter[occurred_from]"]` but `audit_index_live.ex:119-124` uses bare names `from` and `to`
- **Fix:** Updated selectors to `input[name="from"]` and `input[name="to"]`
- **Files modified:** admin-flow-org-admin.spec.ts

## Known Stubs

None. Both specs use real seeded fixture data and live example app assertions.

## Threat Flags

None. No new network endpoints, auth paths, or schema changes introduced. Tests are read-only against the existing example app. T-190-10 (anti-enumeration) and T-190-11 (org admin 403) are verified by the plan's assertions.

## Self-Check: PASSED

Files exist:
- `test/example/priv/playwright/tests/admin-flow-support-investigator.spec.ts` — FOUND
- `test/example/priv/playwright/tests/admin-flow-org-admin.spec.ts` — FOUND

Commits exist:
- `1d547ece` (Task 1 — investigator spec) — FOUND
- `dea4e480` (Task 2 — org admin spec) — FOUND

Verification: `npx playwright test admin-flow --project=chromium` → 10 passed (0 failed)
No sleeps: `grep -c 'waitForTimeout|sleep' *.spec.ts` → 0 in both files
