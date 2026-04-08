---
phase: 06-multi-factor-authentication
plan: 04
subsystem: auth
tags: [mfa, totp, backup-codes, cloak-ecto, ecto-schema, eex-template, swoosh]

# Dependency graph
requires:
  - phase: 06-01
    provides: Sigra.MFA.Credential library struct with from_schema/to_params
provides:
  - MFA migration tables (user_mfa_credentials, user_backup_codes, mfa_trust_epoch)
  - Generated UserMFACredential Ecto schema with cloak_ecto encryption
  - Generated UserBackupCode Ecto schema with atomic consumption
  - 4 MFA email templates (enabled, disabled, backup used, lockout)
  - Auth context MFA delegation functions (7 functions)
  - MFA test fixtures (mfa_user, mfa_pending_session, mfa_locked)
affects: [06-05, phase-07]

# Tech tracking
tech-stack:
  added: []
  patterns: [cloak_ecto Encrypted.Binary for TOTP secrets in generated schema, atomic backup code consumption via used_at timestamp]

key-files:
  created:
    - priv/templates/sigra.install/user_mfa_credential.ex
    - priv/templates/sigra.install/user_backup_code.ex
  modified:
    - priv/templates/sigra.install/migration.exs
    - priv/templates/sigra.install/emails.ex
    - priv/templates/sigra.install/auth.ex
    - priv/templates/sigra.install/auth_fixtures.ex

key-decisions:
  - "MFA tables follow existing migration pattern (binary_id conditionals, all three adapter sections)"
  - "enabled_at included directly in create table (not separate alter) since credential only created after confirmation"

patterns-established:
  - "Generated MFA schemas map to library structs via Sigra.MFA.Credential.from_schema/to_params"
  - "MFA email templates use security_footer_text for security event notifications"

requirements-completed: [MFA-01, MFA-04, MFA-09]

# Metrics
duration: 3min
completed: 2026-04-08
---

# Phase 6 Plan 4: MFA Generator Templates Summary

**MFA migration tables, encrypted credential schema, 4 notification emails, Auth context delegation, and test fixtures for generated host apps**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-08T17:09:10Z
- **Completed:** 2026-04-08T17:12:28Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Migration template creates user_mfa_credentials and user_backup_codes tables across all 3 database adapters with proper indexes, cascade deletes, and binary_id support
- UserMFACredential schema uses cloak_ecto Encrypted.Binary for TOTP secret encryption at rest
- 4 MFA email templates with correct subject lines, copy per UI-SPEC, and conditional backup code warning
- Auth context delegates 7 MFA functions to Sigra.MFA with schema injection pattern

## Task Commits

Each task was committed atomically:

1. **Task 1: Migration template and generated Ecto schemas** - `e66b8f4` (feat)
2. **Task 2: Email templates and Auth context MFA delegation** - `8a93edb` (feat)

## Files Created/Modified
- `priv/templates/sigra.install/migration.exs` - Added MFA tables to PostgreSQL, MySQL, SQLite sections + down migration cleanup
- `priv/templates/sigra.install/user_mfa_credential.ex` - Generated TOTP credential schema with cloak_ecto encryption
- `priv/templates/sigra.install/user_backup_code.ex` - Generated backup code schema with atomic consumption
- `priv/templates/sigra.install/emails.ex` - 4 MFA email builders (enabled, disabled, backup used, lockout)
- `priv/templates/sigra.install/auth.ex` - 7 MFA delegation functions to Sigra.MFA
- `priv/templates/sigra.install/auth_fixtures.ex` - 3 MFA test fixtures (user, pending session, locked)

## Decisions Made
- MFA tables follow existing migration pattern with binary_id conditionals and all three adapter sections (PostgreSQL up/down, MySQL change, SQLite change)
- enabled_at included directly in create table rather than separate alter since credential rows are only created after user confirms enrollment code (D-03)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- MFA generator templates ready for host app generation via `mix sigra.install`
- Templates depend on Sigra.MFA module (plan 06-01) and Sigra.Testing helpers for fixtures
- Phase 06-05 can build MFA LiveView/controller pages using these generated schemas and context functions

---
*Phase: 06-multi-factor-authentication*
*Completed: 2026-04-08*
