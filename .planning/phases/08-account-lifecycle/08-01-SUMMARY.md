---
phase: 08-account-lifecycle
plan: 01
subsystem: auth
tags: [nimble_options, ecto_multi, hooks, data_export, email_templates, config]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: NimbleOptions config schema, EmailTemplates behaviour
  - phase: 03-email-flows-and-transactional-email
    provides: Email delivery patterns, token TTL config
provides:
  - Extended config with :deletion, :hooks, email_change_ttl, password change options
  - EmailTemplates behaviour with 7 new callbacks for email change, deletion, password change
  - Hooks engine (Sigra.Hooks) with Ecto.Multi integration
  - DataExport behaviour with export_auth_data/3 helper
affects: [08-02, 08-03, 08-04, 08-05]

# Tech tracking
tech-stack:
  added: []
  patterns: [hook engine via Ecto.Multi.run, behaviour-based data export]

key-files:
  created:
    - lib/sigra/hooks.ex
    - lib/sigra/data_export.ex
    - test/sigra/hooks_test.exs
    - test/sigra/data_export_test.exs
  modified:
    - lib/sigra/config.ex
    - lib/sigra/email_templates.ex
    - test/sigra/config_test.exs

key-decisions:
  - "Hooks execute inside Multi.run callback, receiving fresh Multi and merged context with prior changes"
  - "DataExport.export_auth_data/3 gracefully handles nil schemas by returning empty lists"

patterns-established:
  - "Hook pattern: {module, function} tuples in config, Multi.run wrapper, :on_{operation}_hook step naming"
  - "Behaviour + helper pattern: DataExport defines callback for apps, provides built-in helper for auth data"

requirements-completed: [ACCT-04]

# Metrics
duration: 4min
completed: 2026-04-09
---

# Phase 8 Plan 01: Account Lifecycle Foundation Summary

**Config extensions for deletion/hooks/email-change, 7 new EmailTemplates callbacks, Hooks engine with Ecto.Multi abort support, DataExport behaviour**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-09T01:47:00Z
- **Completed:** 2026-04-09T01:51:25Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Extended NimbleOptions config with :deletion (strategy, grace_period, cooldown, notify), :hooks (on_register, on_email_change, on_password_change, on_delete), email_change TTL in token_ttl, and notify_on_change/invalidate_sessions_on_change in :password
- Added 7 new EmailTemplates behaviour callbacks: email_change_confirmation_email, email_change_notification_email, email_changed_email, deletion_scheduled_email, deletion_cancelled_email, deletion_finalized_email, password_changed_email
- Created Hooks engine that conditionally injects steps into Ecto.Multi, handles nil (no-op), success, and abort-on-failure patterns
- Created DataExport behaviour with export_user_data/1 callback and export_auth_data/3 built-in helper

## Task Commits

Each task was committed atomically:

1. **Task 1: Config extensions, EmailTemplates behaviour, DataExport behaviour** - `cd3ef15` (feat)
2. **Task 2: Hooks engine + tests (TDD RED)** - `ed2f059` (test)
3. **Task 2: Hooks engine + tests (TDD GREEN)** - `b635995` (feat)

## Files Created/Modified
- `lib/sigra/config.ex` - Extended NimbleOptions schema with :deletion, :hooks, email_change TTL, password change options
- `lib/sigra/email_templates.ex` - 7 new @callback declarations for Phase 8 email types
- `lib/sigra/data_export.ex` - DataExport behaviour with export_auth_data/3 helper
- `lib/sigra/hooks.ex` - Hook execution engine with maybe_run_hook/4 and get_hook/2
- `test/sigra/hooks_test.exs` - Tests for hook nil/success/abort patterns and get_hook
- `test/sigra/data_export_test.exs` - Tests for export_auth_data structure and behaviour callback
- `test/sigra/config_test.exs` - Tests for deletion strategy enum, hooks tuple validation, email_change TTL, password options

## Decisions Made
- Hooks receive a fresh Multi.new() rather than the parent multi to avoid step name collisions; hook result is wrapped inside the parent Multi.run callback
- DataExport.export_auth_data/3 gracefully returns empty lists when schema modules are nil (not configured)
- Used Elixir proper type syntax `%{required(:user) => struct(), optional(atom()) => term()}` for context_map type

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Elixir type syntax for context_map**
- **Found during:** Task 2 (Hooks engine)
- **Issue:** `%{user: struct(), optional(atom()) => term()}` is invalid Elixir syntax -- keyword-style keys cannot mix with map-style keys
- **Fix:** Changed to `%{required(:user) => struct(), optional(atom()) => term()}`
- **Files modified:** lib/sigra/hooks.ex
- **Verification:** mix compile --warnings-as-errors passes
- **Committed in:** b635995

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Trivial syntax fix. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Config infrastructure ready for Plans 02-05 to use :deletion, :hooks, and email_change_ttl sections
- EmailTemplates callbacks ready for generated email template implementations
- Hooks engine ready for integration into registration, email change, password change, and deletion flows
- DataExport behaviour ready for app-specific data export implementations

---
*Phase: 08-account-lifecycle*
*Completed: 2026-04-09*
