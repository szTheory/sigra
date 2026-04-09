---
phase: 08-account-lifecycle
plan: 04
subsystem: auth
tags: [email-change, account-deletion, password-change, hooks, migration, ecto, templates]

# Dependency graph
requires:
  - phase: 08-02
    provides: Sigra.Account orchestrator with EmailChange, PasswordChange, Deletion modules
  - phase: 08-03
    provides: Sigra.Auth config-aware wrappers for account lifecycle operations
provides:
  - Migration template with 5 new user columns and adapter-specific indexes
  - User schema with lifecycle fields and changesets (pending_email, deletion, force_password)
  - Auth context template delegating 11 lifecycle functions to Sigra.Auth/Account
  - Hooks stub module with 4 commented operations (on_register, on_email_change, on_password_change, on_delete)
  - 7 email templates matching UI-SPEC copywriting contract
  - UserToken TTL updated from 2 days to 1 day for email change tokens
affects: [08-05, 08-06, 09-audit-logging]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Partial unique indexes for PostgreSQL (WHERE deleted_at IS NULL, WHERE pending_email IS NOT NULL)"
    - "Composite indexes as MySQL/SQLite fallback for partial indexes"
    - "Config-based hooks with {module, function} tuples and Ecto.Multi integration"

key-files:
  created:
    - priv/templates/sigra.install/auth_hooks.ex
  modified:
    - priv/templates/sigra.install/migration.exs
    - priv/templates/sigra.install/user.ex
    - priv/templates/sigra.install/user_token.ex
    - priv/templates/sigra.install/auth.ex
    - priv/templates/sigra.install/emails.ex

key-decisions:
  - "Token TTL set to 1 day (Ecto ago/2 day granularity) as closest match to 24h requirement from D-03"
  - "Postgres unique_index on email replaced with partial index WHERE deleted_at IS NULL for soft-delete support"
  - "MySQL/SQLite retain unconditional unique_index on email plus composite index for app-level enforcement"
  - "Email templates kept in single emails.ex file rather than split into separate files to match existing pattern"

patterns-established:
  - "Account lifecycle delegation: auth context delegates to Sigra.Auth (config-aware) which delegates to Sigra.Account (repo-aware)"
  - "Hooks stub generation: commented-out functions with full documentation and config example"

requirements-completed: [ACCT-01, ACCT-02, ACCT-03, ACCT-04]

# Metrics
duration: 4min
completed: 2026-04-09
---

# Phase 8 Plan 04: Generated Templates Summary

**Migration template with 5 lifecycle columns, user schema with 3 new changesets, auth context delegating 11 functions, hooks stub module, 7 email templates matching UI-SPEC, and token TTL fix**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-09T02:12:44Z
- **Completed:** 2026-04-09T02:16:40Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments
- Migration template extended with pending_email, deleted_at, scheduled_deletion_at, original_email, must_change_password columns across all 3 adapter branches (Postgres, MySQL, SQLite)
- User schema includes lifecycle fields plus pending_email_changeset, deletion_changeset, and force_password_changeset
- Auth context template delegates 11 account lifecycle functions (email change, password change, deletion management) to Sigra.Auth and Sigra.Account
- Hooks stub module generated with all 4 operations documented and commented per D-51
- 7 email templates implemented with exact UI-SPEC copywriting, consistent inline CSS styling, and proper security_footer_text/footer_text usage
- Token TTL updated from 2 days to 1 day to match D-03 24h requirement

## Task Commits

Each task was committed atomically:

1. **Task 1: Migration template + User schema + UserToken TTL update** - `21332d3` (feat)
2. **Task 2: Auth context delegation + Hooks stub module** - `ada92fb` (feat)
3. **Task 3: Email templates (7 new templates)** - `36363df` (feat)

## Files Created/Modified
- `priv/templates/sigra.install/migration.exs` - Added 5 lifecycle columns with adapter-specific indexes (partial unique for Postgres, composite for MySQL/SQLite)
- `priv/templates/sigra.install/user.ex` - Added 5 lifecycle fields and 3 new changesets
- `priv/templates/sigra.install/user_token.ex` - Updated @change_email_validity_in_days from 2 to 1
- `priv/templates/sigra.install/auth.ex` - Added 11 account lifecycle delegation functions
- `priv/templates/sigra.install/auth_hooks.ex` - NEW: Hooks stub module with 4 commented operations
- `priv/templates/sigra.install/emails.ex` - Added 7 new email templates plus format_date/1 helper

## Decisions Made
- Token TTL set to 1 day using Ecto's ago/2 day granularity (closest integer match to 24h). The existing verify_email_token_query uses `ago(^days, "day")` pattern, so fractional days are not supported without refactoring the query.
- Kept all 7 email templates in the single emails.ex file rather than splitting into separate files, matching the established pattern from phases 3-7.
- Postgres email unique_index replaced with partial index `WHERE deleted_at IS NULL` to support soft-delete email reuse. MySQL/SQLite retain the unconditional unique_index plus a composite `(email, deleted_at)` index for application-level enforcement.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All generated templates ready for Phase 8 Plans 05-06 (LiveView settings pages, generator wiring)
- Auth context has all lifecycle delegation in place for end-to-end integration
- Email templates match the callback signatures in Sigra.EmailTemplates behaviour from Plan 01

## Self-Check: PASSED

All 6 files verified present. All 3 commit hashes verified in git log. All 16 acceptance criteria spot checks passed.

---
*Phase: 08-account-lifecycle*
*Completed: 2026-04-09*
