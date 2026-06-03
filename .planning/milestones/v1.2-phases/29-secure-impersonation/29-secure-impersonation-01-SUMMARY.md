---
phase: 29-secure-impersonation
plan: 01
subsystem: auth
tags: [impersonation, sessions, audit, scope, admin]
requires:
  - phase: 27-admin-access-foundation
    provides: resolved admin scope and direct-path admin authorizer helpers
  - phase: 28-user-operations-surface
    provides: admin user detail target context and return-path conventions
provides:
  - library-owned impersonation runtime over real Sigra sessions
  - dual-actor session and scope metadata for impersonation-aware hydration
  - canonical audit attribution with actor_id on the real admin and effective_user_id on the impersonated user
  - direct-path impersonation authorization coverage for global and organization admin scopes
affects: [phase-29-web-wiring, phase-30-audit-explorer, admin-liveviews, plug-liveview-scope-parity]
tech-stack:
  added: []
  patterns: [library-owned runtime orchestration, additive session metadata, dual-actor audit via canonical columns]
key-files:
  created:
    - lib/sigra/impersonation.ex
    - test/sigra/impersonation_test.exs
    - test/sigra/scope/hydration_impersonation_test.exs
  modified:
    - lib/sigra/session.ex
    - lib/sigra/scope.ex
    - lib/sigra/scope/hydration.ex
    - lib/sigra/audit.ex
    - lib/sigra/admin/authorizer.ex
    - test/sigra/admin/authorizer_test.exs
    - test/sigra/audit/log_safe_scope_test.exs
    - test/sigra/scope/build_test.exs
    - test/sigra/session_test.exs
key-decisions:
  - "Impersonation start, stop, and timeout evaluation live in a dedicated library module that reuses Sigra.Auth session primitives instead of creating a parallel persistence path."
  - "Session metadata remains additive: impersonation stores the real admin user id and original admin session id on the effective-user session."
  - "Scope hydration remains the single seam for Plug and LiveView parity, and dual-actor audit attribution stays in Sigra.Audit.scope_fields/1."
patterns-established:
  - "Impersonation runtime returns explicit restore decisions as {:admin_session, token} or :login_required."
  - "Organization-scoped impersonation authorization is reusable through Sigra.Admin.Authorizer.authorize_impersonation_target!/2."
requirements-completed: [IMPR-01, IMPR-02, IMPR-03, IMPR-05]
duration: 6min
completed: 2026-04-16
---

# Phase 29 Plan 1: Secure Impersonation Summary

**Library-owned impersonation runtime with additive session metadata, impersonation-aware scope hydration, and canonical dual-actor audit attribution**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-16T23:13:00Z
- **Completed:** 2026-04-16T23:18:54Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments
- Locked the impersonation runtime contract with direct-path tests for authorization, non-nesting, stop, timeout, audit attribution, and hydration parity.
- Added `Sigra.Impersonation` to start, stop, and evaluate timeout over real Sigra sessions while returning explicit restore-vs-login outcomes.
- Extended session, scope, hydration, audit, and admin authorizer seams additively so later web-layer work can consume one impersonation-aware contract.

## Task Commits

Each task was committed atomically:

1. **Task 1: Lock the impersonation runtime contract with direct-path tests** - `9d86b51` (test)
2. **Task 2: Implement library-owned impersonation orchestration and additive scope/session/audit plumbing** - `e9f9805` (feat)

## Files Created/Modified
- `lib/sigra/impersonation.ex` - Runtime for impersonation start, stop, denied attempts, and timeout evaluation.
- `lib/sigra/session.ex` - Additive impersonation session metadata contract.
- `lib/sigra/scope.ex` - Scope builder now propagates `impersonating_from`.
- `lib/sigra/scope/hydration.ex` - Hydrates the real admin alongside the effective user.
- `lib/sigra/audit.ex` - Canonical dual-actor audit attribution uses the real admin for `actor_id`.
- `lib/sigra/admin/authorizer.ex` - Reusable target-user impersonation authorization helper.
- `test/sigra/impersonation_test.exs` - Direct-path impersonation runtime coverage.
- `test/sigra/scope/hydration_impersonation_test.exs` - Plug/LiveView-facing impersonation hydration contract coverage.

## Decisions Made
- Kept impersonation session lifecycle on top of `Sigra.Auth.create_session/4` and `Sigra.Auth.delete_session/3`, so Phase 29 does not fork session storage semantics.
- Stored only additive impersonation metadata on the session struct and left preserved admin raw-token handling to explicit runtime return values for the web layer.
- Preserved the existing audit seam by making the real admin flow through `scope.impersonating_from` instead of creating a second impersonation-specific audit writer.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The RED pass initially exposed two test-shape mistakes in the new contract suite; those were corrected before the failing gate was committed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 29 now has the library/runtime contract needed for controller, LiveView, and plug wiring.
- Later web-surface work can consume explicit restore decisions and one impersonation-aware scope shape instead of inferring partial session state.

## Self-Check

PASSED

---
*Phase: 29-secure-impersonation*
*Completed: 2026-04-16*
