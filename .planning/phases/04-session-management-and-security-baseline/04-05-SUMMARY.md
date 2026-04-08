---
phase: 04-session-management-and-security-baseline
plan: 05
subsystem: auth
tags: [session, migration, ecto-schema, sudo, cookie-security, email-templates, generator]

requires:
  - phase: 04-02
    provides: Sigra.Auth session management functions (create_session, list_sessions, revoke_session, confirm_sudo)
  - phase: 04-03
    provides: Sigra.Lockout module with locked?/2 and lock_status/2
provides:
  - user_sessions table migration template (postgres, mysql, sqlite)
  - UserSession Ecto schema generator template
  - Auth context session management functions (list, revoke, sudo, lockout)
  - Sudo re-authentication controller and HTML template
  - Suspicious login and lockout notification email templates
  - Secure cookie defaults (http_only, secure, same_site)
affects: [04-06, 04-07, phase-5, phase-6]

tech-stack:
  added: []
  patterns:
    - "Generated sudo controller uses HTTP POST (not LiveView events) for re-auth"
    - "Security event emails use separate security_footer_text distinct from transactional footer"
    - "Session schema uses utc_datetime_usec for sub-second precision timestamps"

key-files:
  created:
    - priv/templates/sigra.install/user_session.ex
    - priv/templates/sigra.install/sudo_controller.ex
    - priv/templates/sigra.install/sudo_html.ex
    - test/sigra/templates/session_templates_test.exs
  modified:
    - priv/templates/sigra.install/migration.exs
    - priv/templates/sigra.install/auth.ex
    - priv/templates/sigra.install/user_auth.ex
    - priv/templates/sigra.install/emails.ex

key-decisions:
  - "sigra_config/0 helper centralized in generated auth context for controller/plug access"
  - "Security emails use distinct footer text for security events vs transactional emails"
  - "Sudo controller handles missing return_to param gracefully with fallback to root path"

patterns-established:
  - "Generated controllers delegate to context functions which delegate to Sigra library"
  - "Email templates follow consistent pattern: heading, body paragraphs, CTA button, footer"

requirements-completed: [SESS-06, SESS-08]

duration: 8min
completed: 2026-04-07
---

# Phase 4 Plan 5: Generator Templates Summary

**Session management generator templates: migration, UserSession schema, sudo re-auth, cookie security, and lockout/suspicious-login email templates**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-07T21:42:42Z
- **Completed:** 2026-04-07T21:50:42Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Migration template extended with user_sessions table across all three DB adapters (postgres, mysql, sqlite) with proper indexes
- UserSession Ecto schema template created mapping all fields from Sigra.Session library struct
- Auth context extended with session listing, revocation, sudo confirmation, and lockout status functions
- Sudo controller/template following GitHub's re-auth pattern with UI-SPEC compliance
- Suspicious login and lockout notification email templates with HTML+text multipart
- Cookie security hardened with http_only and secure flags on remember-me cookie
- 50 template tests covering all new content

## Task Commits

Each task was committed atomically:

1. **Task 1: Migration template, UserSession schema, auth context extensions** - `4dcf8f2` (feat)
2. **Task 2: Sudo controller/template, user_auth cookie updates, email templates** - `dc5966c` (feat)

## Files Created/Modified
- `priv/templates/sigra.install/migration.exs` - Added user_sessions table to all 3 adapter sections
- `priv/templates/sigra.install/user_session.ex` - New UserSession Ecto schema template
- `priv/templates/sigra.install/auth.ex` - Added sigra_config/0, list_sessions, revoke_session, confirm_sudo, locked?, lock_status
- `priv/templates/sigra.install/sudo_controller.ex` - New sudo re-auth controller (GitHub pattern)
- `priv/templates/sigra.install/sudo_html.ex` - New sudo re-auth HTML template (max-w-sm, autofocus)
- `priv/templates/sigra.install/user_auth.ex` - Added http_only and secure to remember-me cookie
- `priv/templates/sigra.install/emails.ex` - Added suspicious_login_email/2 and lockout_notification_email/2
- `test/sigra/templates/session_templates_test.exs` - 50 tests for all template content

## Decisions Made
- Added `sigra_config/0` public helper in generated auth context so sudo controller and other generated code can access Sigra configuration without duplicating config construction
- Security event emails use a separate `security_footer_text/0` helper distinct from the transactional `footer_text/0` to differentiate security notifications from routine emails
- Sudo controller gracefully handles missing `return_to` param with fallback clause to avoid pattern match errors

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added fallback clause for missing return_to in sudo controller**
- **Found during:** Task 2 (Sudo controller implementation)
- **Issue:** Plan only showed create/2 with both password and return_to in params. If return_to is missing from form submission, it would cause a FunctionClauseError.
- **Fix:** Added second create/2 clause matching when return_to is absent, defaulting to root path.
- **Files modified:** priv/templates/sigra.install/sudo_controller.ex
- **Verification:** Template compiles, test passes
- **Committed in:** dc5966c (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Minor robustness improvement. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All generator templates ready for `mix sigra.install` integration
- Sudo controller expects `conn.private[:sigra_session]` to be populated by FetchSession plug
- Email templates expect `reset_password_url` EEx binding from generator

---
*Phase: 04-session-management-and-security-baseline*
*Completed: 2026-04-07*
