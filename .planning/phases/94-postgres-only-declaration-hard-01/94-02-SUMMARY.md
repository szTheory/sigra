---
phase: 94-postgres-only-declaration-hard-01
plan: 02
status: complete
requirements-completed: [HARD-01]
subsystem: install
tags:
  - migrations
  - postgres
  - core
  - organizations
dependency_graph:
  requires:
    - HARD-01
  provides:
    - Simplified Postgres-only core migration templates
    - Updated generator tests for single-branch migrations
  affects:
    - priv/templates/sigra.install/core/migration.exs
    - priv/templates/sigra.install/core/api_token_migration.exs
    - priv/templates/sigra.install/organizations/migration.exs
    - test/sigra/install/api_token_generator_test.exs
    - test/sigra/templates/session_templates_test.exs
    - test/sigra/install/features/organizations_test.exs
tech_stack:
  added: []
  patterns: []
key_files:
  created: []
  modified:
    - priv/templates/sigra.install/core/migration.exs
    - priv/templates/sigra.install/core/api_token_migration.exs
    - priv/templates/sigra.install/organizations/migration.exs
    - test/sigra/install/api_token_generator_test.exs
    - test/sigra/templates/session_templates_test.exs
    - test/sigra/install/features/organizations_test.exs
key_decisions:
  - "Replaced multi-adapter check tests with tests that ensure Postgres-specific configurations like `citext` remain intact."
metrics:
  duration: 2m
  completed_date: "2024-05-18T00:00:00Z"
---

# Phase 94 Plan 02: Simplify core and organizations migration templates

Collapsed the core auth/session and organizations templates to one Postgres path and replaced their adapter-matrix tests with supported-contract assertions.

## Tasks Completed

- **Task 1:** Removed all MySQL and SQLite fallback conditionals in the core and organizations migration templates, collapsing them into a single Postgres-only implementation.
- **Task 2:** Updated generator tests to remove assertions that count the number of branches and replaced them with assertions that verify expected Postgres structure (such as table definition checks and index counts).

## Commits

- `e89a2f9`: refactor(94-02): collapse core and organizations migration templates to postgres only
- `a4e14e8`: test(94-02): update generator tests for Postgres-only migration templates

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

