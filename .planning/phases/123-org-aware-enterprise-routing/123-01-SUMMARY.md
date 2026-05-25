---
phase: 123-org-aware-enterprise-routing
plan: 01
subsystem: auth
tags: [enterprise-sso, organizations, oauth, oidc, routing, callback]
requires: []
provides:
  - library-owned enterprise discovery and canonical org-entry lookup
  - signed OAuth enterprise context mirrored in session params and callback validation
  - explicit active-organization session metadata for enterprise callbacks
affects: [enterprise-routing, generated-host-entry, example-app-routing]
tech-stack:
  added: []
  patterns: [fail-closed exact domain routing, signed-state enterprise context, explicit-org session precedence]
key-files:
  created:
    - lib/sigra/enterprise_routing.ex
    - test/sigra/enterprise_routing/discovery_test.exs
    - test/sigra/oauth/enterprise_callback_test.exs
  modified:
    - lib/sigra/oauth.ex
    - lib/sigra/oauth/callback.ex
    - lib/sigra/auth.ex
    - lib/sigra/error.ex
    - test/sigra/oauth/oauth_test.exs
    - test/sigra/auth_org_selection_test.exs
key-decisions:
  - "Kept enterprise routing library-owned so generated hosts only delegate into canonical org and connection APIs."
  - "Bound enterprise context into both signed OAuth state and session params, then revalidated both copies before any callback session metadata is returned."
  - "Treat explicit enterprise active_organization_id as authoritative over the generic selector during first-session creation."
patterns-established:
  - "Enterprise discovery only auto-routes exact active login-hint domain matches; duplicates and inactive matches fail closed."
  - "Enterprise callback truth flows through OAuth state, mirrored session context, and explicit session metadata instead of post-login re-inference."
requirements-completed: [SSO-03]
duration: 1 hr
completed: 2026-05-25
---

# Phase 123 Plan 01 Summary

**Sigra now has a library-owned enterprise routing core that resolves one exact active enterprise connection, binds that org truth into OAuth state, revalidates it on callback, and preserves the initiating organization in first-session metadata.**

## Performance

- **Duration:** 1 hr
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Added `Sigra.EnterpriseRouting` for exact-match email discovery and canonical org-entry connection lookup with bounded failure reasons.
- Extended `Sigra.OAuth` to persist `enterprise_context` into both session params and signed `sigra_state`, and pass the verified context through callback handling.
- Extended `Sigra.OAuth.Callback` and `Sigra.Auth.create_session/4` so enterprise callbacks fail closed on mismatched or unavailable context and preserve explicit initiating-org session truth.
- Added Wave 0 proof for discovery failure modes, enterprise callback revalidation, signed-state round trips, and explicit-org session precedence.

## Task Commits

1. **Task 1: Add exact-match enterprise routing and signed enterprise authorize context** - `9a0c129` (feat)
2. **Task 2: Revalidate enterprise callback context and preserve initiating org in first-session truth** - `9a0c129` (feat)

## Files Created/Modified

- `lib/sigra/enterprise_routing.ex` - library-owned discovery and canonical org-entry routing contract.
- `lib/sigra/oauth.ex` - enterprise-aware authorize state and callback context plumbing.
- `lib/sigra/oauth/callback.ex` - mirrored state/session enterprise validation and enterprise session metadata shaping.
- `lib/sigra/auth.ex` - explicit active organization precedence during first-session creation.
- `test/sigra/enterprise_routing/discovery_test.exs`, `test/sigra/oauth/oauth_test.exs`, `test/sigra/oauth/enterprise_callback_test.exs`, `test/sigra/auth_org_selection_test.exs` - Wave 0 proof for fail-closed routing and callback/session truth.

## Decisions Made

- Used the Phase 122 enterprise connection table as the only routing source of truth instead of introducing a domain-only runtime API.
- Kept mismatched enterprise context and unavailable connections as distinct OAuth failure cases so the generated host can stay in enterprise mode without guessing.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- None beyond a small compile-time refactor to move email validation out of a guard.

## Verification

- `mix test test/sigra/enterprise_routing/discovery_test.exs test/sigra/oauth/oauth_test.exs` -> passed (`28 tests, 0 failures`).
- `mix test test/sigra/oauth/enterprise_callback_test.exs test/sigra/auth_org_selection_test.exs` -> passed (`13 tests, 0 failures`).
- `rg -n "enterprise_context|no_org_match|multiple_org_matches|org_connection_unavailable|active_organization_id|enterprise_connection_id" lib/sigra/enterprise_routing.ex lib/sigra/oauth.ex lib/sigra/oauth/callback.ex lib/sigra/auth.ex` -> passed.

## User Setup Required

None - this plan only adds library behavior and tests.

## Next Phase Readiness

- Template-owned generated-host work can now call `Sigra.EnterpriseRouting` and `Sigra.OAuth.authorize_url/3` without reimplementing routing or callback trust logic.
- Example-app and installer waves can prove the org-scoped enterprise entry surface against a stable library contract.

## Self-Check: PASSED
