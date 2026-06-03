---
phase: 27-admin-access-foundation
plan: 2
subsystem: auth
tags: [admin, authorization, plug, liveview, ecto]
requires:
  - phase: 27-admin-access-foundation
    provides: installer-owned admin policy seam and router injection scaffolding
provides:
  - explicit resolved admin scope for global and organization admin routes
  - plug and liveview admin enforcement parity
  - direct-path admin authorizer helpers for queries, exports, and mutations
affects: [phase-27-plan-03, admin-runtime, impersonation, audit]
tech-stack:
  added: []
  patterns: [resolved admin scope, plug-liveview parity, structural org query scoping]
key-files:
  created:
    - lib/sigra/admin/scope.ex
    - lib/sigra/admin/authorizer.ex
    - lib/sigra/plug/require_admin_access.ex
    - lib/sigra/live_view/admin_scope.ex
    - test/sigra/admin/authorizer_test.exs
    - test/sigra/plug/require_admin_access_test.exs
    - test/sigra/live_view/admin_scope_test.exs
  modified:
    - lib/sigra/admin/policy.ex
key-decisions:
  - "Admin route intent resolves into a library-owned Sigra.Admin.Scope that distinguishes :global from :organization access."
  - "Denied global admin access uses insufficient_scope, while unknown or out-of-scope organization routes collapse to not_found."
  - "Direct-path admin queries must scope organization access through Sigra.Organizations.Query.for_org/2."
patterns-established:
  - "Admin boundaries use the same resolver in Plug and LiveView so live_session navigation cannot bypass authorization."
  - "Non-router admin code should call Sigra.Admin.Authorizer rather than re-implementing global vs organization checks."
requirements-completed: [ADMIN-02, ADMIN-03, ADMIN-04]
duration: 4 min
completed: 2026-04-16
---

# Phase 27 Plan 2: Admin Access Foundation Summary

**Resolved admin scope plus Plug, LiveView, and direct-path enforcement for global and organization admin access**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-16T19:12:28Z
- **Completed:** 2026-04-16T19:16:09Z
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments
- Added an explicit admin policy helper and resolved admin scope contract that fails closed for global and org-routed access.
- Enforced the same admin scope rules at both Plug and LiveView mount boundaries.
- Added direct-path authorization helpers for future exports, mutations, and structurally scoped admin queries.

## Task Commits

Each task was committed atomically:

1. **Task 1: Define the explicit admin policy behaviour and resolved admin scope contract** - `e6d05f2` (feat)
2. **Task 2: Implement Plug and LiveView admin enforcement plus foundation LiveViews** - `1b82836` (feat)
3. **Task 3: Add direct-path admin authorizer and structural query-scoping helpers for exports and mutations** - `49052cc` (feat)

## Files Created/Modified
- `lib/sigra/admin/policy.ex` - Adds the explicit membership-derived org-admin helper for host policies.
- `lib/sigra/admin/scope.ex` - Resolves route-owned admin intent into a shared global or organization scope struct.
- `lib/sigra/admin/authorizer.ex` - Provides reusable direct-path authorization and query-scoping helpers.
- `lib/sigra/plug/require_admin_access.ex` - Enforces admin access in Plug pipelines and assigns resolved admin scope.
- `lib/sigra/live_view/admin_scope.ex` - Re-runs admin scope resolution in `on_mount/4` for LiveView parity.
- `test/sigra/admin/authorizer_test.exs` - Covers global, org, out-of-scope, and structural query-scoping behavior.
- `test/sigra/plug/require_admin_access_test.exs` - Covers global route denial, org-route not_found handling, and plug assignment behavior.
- `test/sigra/live_view/admin_scope_test.exs` - Covers live_session denial, redirect, and org-route parity behavior.

## Decisions Made
- Kept org-route denial split between `:insufficient_scope` for forbidden global admin entry and `:not_found` for unknown or out-of-scope organization URLs so org existence stays private.
- Scoped non-global admin queries through `Sigra.Organizations.Query.for_org/2` instead of depending on caller-side filtering.
- Left admin scope attached as a separate assign (`:admin_scope`) rather than mutating the host `current_scope` contract.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Plan 27-03 can wire the example app router and shell against the finished admin policy and enforcement surface.
- Later admin, impersonation, and audit code now has a library-owned direct-path authorizer instead of inventing its own scope checks.

## Self-Check: PASSED

- Found `.planning/phases/27-admin-access-foundation/27-admin-access-foundation-02-SUMMARY.md`
- Found commit `e6d05f2`
- Found commit `1b82836`
- Found commit `49052cc`
