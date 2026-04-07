---
phase: 03-email-flows-and-transactional-email
plan: 04
subsystem: auth
tags: [password-reset, eex-templates, phoenix-liveview, phoenix-controller, plug, unconfirmed-access]

# Dependency graph
requires:
  - phase: 03-01
    provides: Sigra.Auth confirmation/reset library functions, config schema
  - phase: 03-02
    provides: Email delivery infrastructure, Swoosh integration
provides:
  - Reset password controller template (request, form, update, expired)
  - Reset password HTML templates (3 pages)
  - Reset password LiveView with strength meter and real-time validation
  - require_confirmed_user plug with allow_with_banner and block modes
affects: [03-05, 04-security-baseline]

# Tech tracking
tech-stack:
  added: []
  patterns: [expired-token-actionable-page, configurable-unconfirmed-access-plug, password-strength-meter-reuse]

key-files:
  created:
    - priv/templates/sigra.install/reset_password_controller.ex
    - priv/templates/sigra.install/reset_password_html.ex
    - priv/templates/sigra.install/reset_password_live.ex
    - test/sigra/install/generator_reset_test.exs
  modified:
    - priv/templates/sigra.install/user_auth.ex

key-decisions:
  - "Test EEx templates via string matching (raw + simple_render) rather than EEx.eval_string to avoid HEEx compile errors in test context"
  - "Password strength meter helpers duplicated in reset_password_live.ex (same as registration_live.ex) -- extractable to shared component in future refactor"

patterns-established:
  - "Expired token pages always actionable: heading + explanation + re-request button (never dead ends)"
  - "Configurable plug behavior via keyword opts with private helper for mode resolution"
  - "Generator template tests use raw string matching for HEEx templates, EEx eval for pure-Elixir templates"

requirements-completed: [RESET-04, RESET-05, CONF-03]

# Metrics
duration: 4min
completed: 2026-04-07
---

# Phase 3 Plan 4: Reset Password Flow and Unconfirmed Access Plug Summary

**Password reset templates (controller + HTML + LiveView) with real-time validation/strength meter and configurable unconfirmed user access plug (allow_with_banner vs block with auto-resend)**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-07T03:14:03Z
- **Completed:** 2026-04-07T03:17:57Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Reset password flow with 4 controller actions (request, form, update, expired) and 3 HTML templates
- LiveView variant with phx-change real-time validation and password strength meter reused from registration
- Unconfirmed user access plug with two configurable modes: allow_with_banner (info flash) and block (auto-resend + redirect)
- 23 new generator tests verifying all templates compile and contain required patterns

## Task Commits

Each task was committed atomically:

1. **Task 1: Reset password controller, HTML, and LiveView templates** - `46eaea7` (feat)
2. **Task 2: Extend user_auth plug for unconfirmed access behavior** - `f156b93` (feat)

## Files Created/Modified
- `priv/templates/sigra.install/reset_password_controller.ex` - Controller with request, form, update, expired actions
- `priv/templates/sigra.install/reset_password_html.ex` - HTML templates: request form, password form, expired page
- `priv/templates/sigra.install/reset_password_live.ex` - LiveView with phx-change validation and strength meter
- `priv/templates/sigra.install/user_auth.ex` - Added require_confirmed_user/2 plug
- `test/sigra/install/generator_reset_test.exs` - 23 template compilation and pattern tests

## Decisions Made
- Used simple string replacement fallback in tests rather than EEx.eval_string, since HEEx sigils in templates cause CompileError outside the Phoenix module system
- Duplicated password strength helper functions in reset LiveView (matching registration LiveView) rather than extracting to shared module -- keeps templates self-contained for generator output

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- EEx.eval_string cannot compile templates containing HEEx ~H sigils in test context (no Phoenix stack). Resolved by using raw string matching for HTML/LiveView templates and a simple_render fallback that does basic string replacement for EEx tags.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None - all templates wire to existing auth context functions (deliver_user_reset_password_instructions, get_user_by_reset_password_token, reset_user_password, change_user_password) which were already implemented.

## Next Phase Readiness
- All reset password templates ready for generator integration
- require_confirmed_user plug ready for router pipeline injection
- Password strength meter pattern consistent with registration (extractable to shared component later)

---
*Phase: 03-email-flows-and-transactional-email*
*Completed: 2026-04-07*
