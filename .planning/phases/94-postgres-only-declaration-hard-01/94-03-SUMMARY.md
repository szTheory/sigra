---
phase: 94-postgres-only-declaration-hard-01
plan: 03
subsystem: generators
tags:
  - postgres-only
  - migrations
  - passkeys
  - audit
depends_on: []
provides: [94-04]
tech_stack:
  - elixir
  - ecto
  - postgres
key_files:
  - priv/templates/sigra.install/passkeys/create_user_passkeys.exs
  - priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs
  - priv/templates/sigra.install/core/user_api_token.ex
  - test/sigra/passkeys/migration_test.exs
decisions:
  - "Removed all adapter branches from adjacent generator templates to enforce Postgres-only schemas across the board."
---

# Phase 94 Plan 03: Simplify Adjacent Templates and Tests Summary

Cleaned up adjacent installer-surface drift from API-token, passkeys, and audit-events templates and updated tests to assert only Postgres structures.

## Completed Tasks

1. **Task 1: Simplify adjacent templates** - Removed `:mysql` and `:sqlite` fallback conditionals from the adjacent templates, retaining only the `:postgres` path logic.
2. **Task 2: Replace adjacent adapter-matrix tests with Postgres assertions** - Updated `test/sigra/passkeys/migration_test.exs` to only test Postgres-style outputs and removed the adapter binding.

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED
- `priv/templates/sigra.install/passkeys/create_user_passkeys.exs` is missing adapter checks.
- `priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs` only contains Postgres migration structure.
- `priv/templates/sigra.install/core/user_api_token.ex` is missing adapter checks.
- `test/sigra/passkeys/migration_test.exs` correctly asserts only Postgres structures.