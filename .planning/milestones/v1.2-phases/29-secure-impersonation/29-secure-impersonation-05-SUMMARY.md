---
phase: 29-secure-impersonation
plan: 5
subsystem: auth
tags: [impersonation, api-tokens, phoenix, templates, testing]
requires:
  - phase: 29-04
    provides: shared impersonation denial semantics and audited blocked-operation patterns
provides:
  - guarded generated API-token wrapper calls for create, revoke-one, and revoke-all
  - explicit controller-level impersonation-forbidden responses for generated API-token mutations
  - focused example coverage for blocked API-token mutation attempts during impersonation
affects: [api-tokens, impersonation, generated-auth-surfaces]
tech-stack:
  added: []
  patterns: [guarded wrapper seam, explicit impersonation_forbidden tuple, example parity helper]
key-files:
  created: [test/example/test/example_web/impersonation_api_token_blocked_ops_test.exs]
  modified:
    [
      priv/templates/sigra.install/core/auth_api_token.ex,
      priv/templates/sigra.install/core/api_token_controller.ex,
      test/example/lib/example/accounts.ex
    ]
key-decisions:
  - "Generated API-token mutations now reuse the same admin.impersonation.denied audit stream and explicit impersonation reason as other sensitive operations."
  - "The example app uses a narrow parity helper for API-token seams because the example fixture app does not currently generate the API-token controller surface."
patterns-established:
  - "Generated wrapper seams may accept optional scope opts to fail closed during impersonation without breaking existing call sites."
  - "Generated API controllers should translate impersonation-forbidden tuples into explicit 403 JSON payloads."
requirements-completed: [IMPR-04]
duration: 5min
completed: 2026-04-17
---

# Phase 29 Plan 5: Secure Impersonation Summary

**Generated API-token create, revoke-one, and revoke-all seams now fail closed during impersonation with explicit denial responses and focused parity coverage.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-17T00:22:28Z
- **Completed:** 2026-04-17T00:27:21Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Added focused blocked-operation coverage for API-token create, revoke-one, and revoke-all impersonation paths.
- Guarded the generated API-token wrapper seam so impersonated scopes receive an explicit denial tuple and audited denial event.
- Updated the generated controller and example parity helper to surface clear impersonation-forbidden behavior without adding a second policy path.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add blocked-operation tests for generated API-token mutation seams** - `2a33ade` (`test`)
2. **Task 2: Guard generated API-token wrapper and controller mutations during impersonation** - `8ff24ee` (`feat`)

## Files Created/Modified
- `test/example/test/example_web/impersonation_api_token_blocked_ops_test.exs` - Focused direct-path coverage for blocked create, revoke-one, and revoke-all behavior.
- `priv/templates/sigra.install/core/auth_api_token.ex` - Generated wrapper seam now rejects impersonated create/revoke operations with explicit denial tuples and denial audit logging.
- `priv/templates/sigra.install/core/api_token_controller.ex` - Generated controller translates impersonation-forbidden wrapper results into 403 JSON responses.
- `test/example/lib/example/accounts.ex` - Example-side parity helper mirrors the guarded API-token semantics for tests without inventing a separate policy layer.

## Decisions Made
- Kept the generated wrapper as the canonical impersonation guard for API-token mutations and let the controller focus on translating denial tuples into HTTP responses.
- Added only a parity helper in `Example.Accounts` because the example fixture app does not currently wire the generated API-token controller or schema surface.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- The RED test exposed that `Example.Accounts` had no API-token seam at all; the implementation added the minimal parity helper required by the plan and nothing broader.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 29 now covers the full sensitive-operation set called out for impersonation blocking, including the previously missed generated API-token mutation seam.
- The denial tuple plus controller translation pattern is available for any later generated JSON mutation surfaces that need impersonation-aware behavior.

## Self-Check: PASSED

---
*Phase: 29-secure-impersonation*
*Completed: 2026-04-17*
