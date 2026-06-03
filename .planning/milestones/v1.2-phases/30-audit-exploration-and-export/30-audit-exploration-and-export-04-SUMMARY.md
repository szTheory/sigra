---
phase: 30-audit-exploration-and-export
plan: 04
subsystem: audit
tags: [audit, csv, admin, phoenix, playwright]
requires:
  - phase: 30-audit-exploration-and-export
    provides: shared audit query normalization, global/org explorer routes, and per-user audit investigation flows
provides:
  - Stable CSV export over the existing normalized admin audit filter contract
  - Thin example and generated controller routes for global, org, and per-user audit downloads
  - Browser-backed audit export verification across global and scoped investigation paths
affects: [phase-31, admin-audit, generated-admin-routes, browser-verification]
tech-stack:
  added: []
  patterns: [thin controller export seam over shared query contract, fixed CSV schema with formula-prefix escaping]
key-files:
  created:
    - lib/sigra/admin/audit/csv_export.ex
    - lib/sigra/admin/audit/export.ex
    - test/example/lib/example_web/controllers/admin/audit_export_controller.ex
    - priv/templates/sigra.install/admin/audit_export_controller.ex
    - test/example/test/example_web/controllers/admin/audit_export_controller_test.exs
    - test/example/priv/playwright/tests/admin-audit.spec.ts
  modified:
    - lib/sigra/admin/live/audit_index_live.ex
    - lib/sigra/admin/live/audit_user_live.ex
    - test/example/lib/example_web/router.ex
    - priv/templates/sigra.install/admin/router_injection.ex
key-decisions:
  - "Kept CSV export on the exact Phase 30 query-param contract, including scoped per-user semantics, instead of introducing export-only filters."
  - "Used a library-owned CSV encoder with explicit apostrophe prefix escaping for dangerous spreadsheet prefixes instead of adding a new dependency."
  - "Mirrored explorer routes with GET export endpoints for global, organization, and per-user paths so the downloaded evidence URL stays reproducible."
patterns-established:
  - "Admin audit downloads are controller-owned, but filter normalization and scope enforcement stay in Sigra.Admin.Audit modules."
  - "Audit LiveViews carry their full current query string directly into Export CSV links so browser and controller paths prove the same slice."
requirements-completed: [AUD-04, AUD-02, AUD-03]
duration: 8 min
completed: 2026-04-17
---

# Phase 30 Plan 04: Audit Exploration and Export Summary

**Scope-safe admin audit CSV exports now ship on the same normalized filter contract as the explorer UI, with fixed evidence columns and browser-backed download verification**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-17T01:34:24Z
- **Completed:** 2026-04-17T01:42:51Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments
- Added RED coverage for fixed-schema CSV downloads, metadata exclusion, dangerous-prefix escaping, and browser-visible export flows.
- Implemented shared audit export orchestration and CSV encoding without widening the existing explorer filter contract.
- Wired global, organization, and per-user audit export routes into the example app and generated admin templates, plus real export links in both audit LiveViews.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add controller and browser tests for scope-safe CSV export over the shared filter contract** - `5e4459a` (test)
2. **Task 2: Implement shared CSV export, generated/example controller wiring, and final audit-flow verification** - `770d8fd` (feat)

## Files Created/Modified
- `lib/sigra/admin/audit/csv_export.ex` - Fixed header order, CSV quoting, and spreadsheet-formula prefix escaping.
- `lib/sigra/admin/audit/export.ex` - Shared export orchestration over the normalized admin audit filters and scope model.
- `test/example/lib/example_web/controllers/admin/audit_export_controller.ex` - Thin example controller for CSV responses across all audit scopes.
- `priv/templates/sigra.install/admin/audit_export_controller.ex` - Generated controller parity for installed apps.
- `test/example/lib/example_web/router.ex` - Mounted global, org, and per-user audit export routes beside the explorer routes.
- `priv/templates/sigra.install/admin/router_injection.ex` - Kept generated router wiring aligned with the example app.
- `lib/sigra/admin/live/audit_index_live.ex` - Added `Export CSV` links that preserve the current global or org query string.
- `lib/sigra/admin/live/audit_user_live.ex` - Added per-user `Export CSV` links that preserve scope and return context.
- `test/example/test/example_web/controllers/admin/audit_export_controller_test.exs` - Direct-path export coverage for scope, filter parity, header order, and formula mitigation.
- `test/example/priv/playwright/tests/admin-audit.spec.ts` - Browser verification for global investigation plus org-scoped per-user export.

## Decisions Made
- Export uses the same `Sigra.Admin.Audit.QueryParams` normalization path as the explorer views, so controller downloads cannot drift from LiveView filters.
- The v1 CSV schema omits raw `metadata` entirely and relies on canonical ids, labels, and derived impersonation state instead.
- Export links live in the existing audit LiveViews rather than a separate control surface so operators export the slice they are already viewing.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the browser stop-impersonation step to follow the app-wide banner path**
- **Found during:** Task 2 (Implement shared CSV export, generated/example controller wiring, and final audit-flow verification)
- **Issue:** The first Playwright flow tried to click `End impersonation` directly on `/`, but the existing stop control is rendered on authenticated pages with the persistent impersonation banner.
- **Fix:** Updated the browser spec to navigate through the authenticated organization page before ending impersonation, matching the shipped Phase 29 behavior.
- **Files modified:** `test/example/priv/playwright/tests/admin-audit.spec.ts`
- **Verification:** `cd test/example/priv/playwright && pnpm exec playwright test tests/admin-audit.spec.ts --project=chromium`
- **Committed in:** `770d8fd`

**2. [Rule 3 - Blocking] Added explicit export links to the existing audit LiveViews**
- **Found during:** Task 2 (Implement shared CSV export, generated/example controller wiring, and final audit-flow verification)
- **Issue:** The plan-owned controller and route work was not enough for browser verification because the explorer pages had no concrete `Export CSV` trigger.
- **Fix:** Added scoped export links to `AuditIndexLive` and `AuditUserLive` that forward the current query string unchanged.
- **Files modified:** `lib/sigra/admin/live/audit_index_live.ex`, `lib/sigra/admin/live/audit_user_live.ex`
- **Verification:** `cd test/example/priv/playwright && pnpm exec playwright test tests/admin-audit.spec.ts --project=chromium`
- **Committed in:** `770d8fd`

---

**Total deviations:** 2 auto-fixed (1 bug fix, 1 blocking fix)
**Impact on plan:** Both fixes were required to keep the browser contract aligned with the shipped admin surface. No architectural scope change.

## Issues Encountered
- The plan's Playwright command from `test/example` failed with `ERR_PNPM_RECURSIVE_EXEC_NO_PACKAGE` because the local Playwright package lives under `test/example/priv/playwright`. Verification used the equivalent package-directory command instead.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 31 can reuse the new direct-path audit export controller test and browser flow as milestone verification anchors.
- The generated admin templates now include the audit export controller and route shape that later verification and docs work can assume.

## Self-Check: PASSED

---
*Phase: 30-audit-exploration-and-export*
*Completed: 2026-04-17*
