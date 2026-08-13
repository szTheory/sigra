---
phase: 246-hosted-and-direct-login-ceremonies
plan: 08
subsystem: authentication
tags: [elixir, phoenix, generated-routes, pkce, app-sessions]
requires:
  - phase: 246-05
    provides: hardened hosted and direct ceremony services
  - phase: 246-07
    provides: generated app-session persistence and host facade
provides:
  - Generated hosted browser approval and JSON exchange routes
  - Bounded signed continuation that survives normal browser login
  - Explicit accessible approval and cancellation surface
affects: [generated-host-installation, first-party-native-clients]
tech-stack:
  added: []
  patterns: [signed session handle, explicit browser approval, dedicated public rate limit]
key-files:
  created:
    - priv/templates/sigra.install/app_sessions/app_login_controller.ex
    - priv/templates/sigra.install/app_sessions/app_login_continuation.ex
    - priv/templates/sigra.install/app_sessions/router_injection.ex
    - priv/templates/sigra.install/app_sessions/app_login_html.ex
    - priv/templates/sigra.install/app_sessions/app_login_approve.html.heex
  modified:
    - lib/sigra/install/features/app_sessions.ex
    - priv/templates/sigra.install/core/user_auth.ex
    - test/sigra/install/app_sessions_routes_test.exs
key-decisions:
  - "Hosted browser state persists only as a bounded signed continuation handle through normal session renewal."
  - "Approval and cancellation are separate CSRF-protected POST decisions in the existing sigra-auth shell."
requirements-completed: [APP-02, APP-03]
coverage:
  - id: D1
    description: Generated hosted start, approval, cancellation, and exchange route contract.
    requirement: APP-02
    verification:
      - kind: integration
        ref: MIX_ENV=test mix test test/sigra/install/app_sessions_routes_test.exs test/sigra/install/app_sessions_generator_test.exs --trace
        status: pass
    human_judgment: false
  - id: D2
    description: Explicit generated auth-shell approval decision with stable test hooks.
    requirement: APP-03
    verification:
      - kind: integration
        ref: test/sigra/install/app_sessions_routes_test.exs#renders an explicit accessible approval decision in the auth shell
        status: pass
    human_judgment: false
metrics:
  duration: 6m
  completed: 2026-08-13
  tasks: 2
  files: 9
status: complete
---

# Phase 246 Plan 08: Generated App Login Routes Summary

**Generated Phoenix routes now carry hosted PKCE login through an explicit, no-referrer browser approval and strict JSON exchange.**

## Accomplishments

- Added generated hosted start, continuation, approve, cancel, and exchange transport with dedicated public rate limiting and strict scalar request contracts.
- Preserved only a signed continuation handle through normal browser login; approval emits no-referrer callback responses and no ceremony credentials enter flash, URLs, or browser storage.
- Added the existing sigra-auth-shell approval page with explicit CSRF-protected approve/cancel controls, accessible headings, and deterministic test hooks.

## Task Commits

1. **Task 1: Complete one hosted system-browser route journey through explicit approval** — `485335e6` (RED), `2cde357b` (GREEN)
2. **Task 2: Render explicit approval and cancellation in the existing auth shell** — `7e9df155` (GREEN)

## Verification

- `MIX_ENV=test mix test test/sigra/install/app_sessions_routes_test.exs test/sigra/install/app_sessions_generator_test.exs --trace` — PASS (13 tests, 0 failures).
- `mix format --check-formatted lib/sigra/install/features/app_sessions.ex test/sigra/install/app_sessions_generator_test.exs test/sigra/install/app_sessions_routes_test.exs` — PASS.
- Rendered generated Elixir templates parsed and formatted successfully, including the app-session-aware core user-auth template — PASS.
- Negative source contract found no flash, browser-storage, cookie, or raw code/verifier/state/password session writes in the generated ceremony controller/continuation — PASS.
- `git diff --check HEAD~2..HEAD` — PASS.

## Decisions Made

- The continuation helper stores only a short-lived Phoenix-signed handle; the library remains the owner of PKCE and callback state.
- The generated approval surface uses the existing `sigra-auth-*` shell rather than admin components, so its existing Light, Dark, and System theme support remains intact.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Preserve hosted continuation through browser login renewal**
- **Found during:** Task 1
- **Issue:** Normal generated `UserAuth.log_in_user/3` renews and clears the session, which would discard the signed hosted continuation before the user could reach approval.
- **Fix:** Captured and restored only the signed continuation handle around session renewal when app sessions are enabled.
- **Files modified:** `priv/templates/sigra.install/core/user_auth.ex`
- **Verification:** Rendered app-session user-auth template parses; focused route/generator suites pass.
- **Committed in:** `2cde357b`

**Total deviations:** 1 auto-fixed (Rule 2). **Impact:** Required for correct hosted browser return behavior; it does not expand the ceremony surface or retain raw credential material.

## Known Stubs

None.

## Issues Encountered

The focused installer suites passed while the local test runtime logged unavailable PostgreSQL connections during application startup. The selected route and generator tests are database-independent; no test result failed.

## Next Phase Readiness

Generated hosts can now route first-party browser ceremonies into the existing service state machine with an explicit user decision.

## Self-Check: PASSED

- Confirmed all five generated route, continuation, and approval templates exist.
- Confirmed task commits `485335e6`, `2cde357b`, and `7e9df155` exist in git history.
