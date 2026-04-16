---
phase: 28-user-operations-surface
plan: 3
subsystem: ui
tags: [phoenix, liveview, admin, sessions, audit]
requires:
  - phase: 28-02
    provides: user list routing, scope-safe admin user query, preserved return_to context
provides:
  - user detail aggregation for admin identity, sessions, security, organizations, and audit preview
  - scope-safe session revoke actions routed through canonical Sigra auth APIs
  - global and organization-scoped user detail LiveView routes with explicit org pivot links
affects: [phase-29-secure-impersonation, phase-30-audit-exploration-export, admin-user-operations]
tech-stack:
  added: []
  patterns: [library-owned detail assembler, LiveView confirmation modal for guarded admin actions]
key-files:
  created:
    - lib/sigra/admin/users/detail.ex
    - lib/sigra/admin/users/actions.ex
    - lib/sigra/admin/live/user_show_live.ex
  modified:
    - test/example/lib/example_web/router.ex
    - test/sigra/admin/users_actions_test.exs
    - test/example/test/example_web/live/admin_user_show_live_test.exs
key-decisions:
  - "Kept the user detail loader library-owned and scope-safe so both global and organization routes resolve the same target data contract."
  - "Reused Sigra.Auth revoke APIs for revoke-one and revoke-all so audit logging and disconnect side effects remain centralized."
patterns-established:
  - "Admin user detail pages load one aggregate payload per URL and refresh that payload after guarded mutations."
  - "Global admin detail pages expose explicit org pivot links instead of silently mutating scope in place."
requirements-completed: [USER-03, USER-04]
duration: 7min
completed: 2026-04-16
---

# Phase 28 Plan 3: User Detail Surface Summary

**Admin user detail LiveView with scope-safe session revocation, audit preview, and explicit organization pivots**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-16T22:02:00Z
- **Completed:** 2026-04-16T22:08:31Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Added a library-owned detail assembler that returns identity, sessions, security, identities, organizations, recent audit, and danger-zone data in one payload.
- Added scope-safe admin session revoke actions that load the target through the same authorized path as the detail view and call canonical `Sigra.Auth` APIs.
- Shipped global and organization-scoped user detail routes and a LiveView that preserves `return_to`, renders the required section order, and offers explicit org pivots for platform admins.

## Task Commits

1. **Task 1: Implement the detail assembler and scope-safe session actions** - `cde5596` (feat)
2. **Task 2: Build the anchored user detail LiveView with guarded session revoke UX** - `ec93262` (feat)

## Files Created/Modified
- `lib/sigra/admin/users/detail.ex` - Aggregates scope-safe user detail data and recent audit previews.
- `lib/sigra/admin/users/actions.ex` - Wraps revoke-one and revoke-all through canonical auth APIs.
- `lib/sigra/admin/live/user_show_live.ex` - Renders the detail surface, guarded confirmation modal, and org pivot links.
- `test/example/lib/example_web/router.ex` - Mounts global and org-scoped user detail routes.
- `test/sigra/admin/users_actions_test.exs` - Verifies audit coverage and scope checks for session revoke actions.
- `test/example/test/example_web/live/admin_user_show_live_test.exs` - Verifies section order, confirmation copy, and global-to-org pivots.

## Decisions Made
- Kept detail aggregation in `Sigra.Admin.Users.Detail` instead of pushing related lookups into LiveView assigns.
- Used `Sigra.Admin.Users.Detail.load_user!/3` as the shared scope-safe path for both read and mutation flows.
- Preserved the global detail lens while making organization pivots explicit in link copy and destination URLs.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Focused verification surfaced two test-harness issues during execution: one `utc_datetime` precision mismatch in the new action test and one ambiguous LiveView test selector. Both were fixed inline before task completion.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The user detail surface now gives Phase 29 and Phase 30 a stable URL-addressable page to extend for impersonation and richer audit exploration.
- Session revocation behavior is covered at both the library and example LiveView layers.

## Self-Check: PASSED
