---
phase: 13-organizations-schemas-context
plan: 02
subsystem: organizations
tags: [query-scoping, tenant-isolation, slug-validation, reserved-words]
dependency_graph:
  requires: [13-01]
  provides: [for-org-query-scoping, slug-validation, prepare-query-enforcement]
  affects: [13-03, 14-plugs, 18-generator-wiring]
tech_stack:
  added: []
  patterns: [ecto-query-ast-inspection, prepare-query-defense-in-depth, parameterized-reserved-word-tests]
key_files:
  created:
    - lib/sigra/organizations/query.ex
    - lib/sigra/organizations/slug.ex
    - test/sigra/organizations/query_test.exs
    - test/sigra/organizations/slug_test.exs
  modified: []
decisions:
  - "WHERE clause heuristic walks Ecto query AST for organization_id field reference; logs warning and passes through on inspection failure to avoid false positives (T-13-08)"
  - "maybe_enforce_org_scope/4 skips :insert, :insert_all, :delete, :delete_all, :update, :update_all operations (only enforces :all and :one)"
metrics:
  duration_seconds: 220
  completed: "2026-04-12T16:45:00Z"
  tasks_completed: 2
  tasks_total: 2
  test_count: 54
  files_created: 4
  files_modified: 0
---

# Phase 13 Plan 02: Query Scoping and Slug Validation Summary

for_org/2 tenant scoping with ArgumentError on missing :organization_id, maybe_enforce_org_scope/4 prepare_query defense-in-depth, and slug validation with 25 hardcoded reserved words plus configurable extensions

## What Was Built

### Sigra.Organizations.Query
- `for_org/2` accepts `%Scope{}` with `active_organization.id` or raw binary org_id
- Scopes any Ecto queryable with `WHERE organization_id = ?`
- Raises `ArgumentError` on schemas without `:organization_id` field (O-1 defense)
- Raises `ArgumentError` when `active_organization` is nil (no org selected)
- Raises `ArgumentError` on non-schema-based queries (e.g., raw table strings)
- `maybe_enforce_org_scope/4` for generated Repo's `prepare_query/3` callback (D-14)
- Skips enforcement for: `skip_org_check: true`, preloads, schema_migrations, non-query operations
- WHERE clause heuristic walks `%Ecto.Query.BooleanExpr{}` AST for `organization_id` field binding
- Falls back to pass-through with logged warning on AST inspection failure (T-13-08 accept disposition)

### Sigra.Organizations.Slug
- `validate_slug/2` validates format `^[a-z][a-z0-9-]*[a-z0-9]$`, length 3-63 chars
- 25 hardcoded reserved slugs: admin, api, app, auth, billing, blog, cdn, dashboard, docs, help, login, logout, new, oauth, register, settings, signup, static, status, support, system, webhooks, www
- `additional_reserved_slugs` config key for app-level extensions (additive, cannot drop library defaults)
- `slug_format` and `slug_length` configurable via config map
- `generate_slug/1` produces slug candidates: downcase, replace non-alphanumeric with hyphens, trim
- `default_reserved_slugs/0` exposes the list for test assertions

## Commits

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Query.for_org/2 + maybe_enforce_org_scope/4 | 07c6a67 | lib/sigra/organizations/query.ex, test/sigra/organizations/query_test.exs |
| 2 | Slug validation + generation + reserved words | ad501e0 | lib/sigra/organizations/slug.ex, test/sigra/organizations/slug_test.exs |

## Deviations from Plan

None - plan executed exactly as written.

## Verification

- `mix compile --warnings-as-errors` exits 0
- `mix test test/sigra/organizations/query_test.exs` -- 12 tests, 0 failures
- `mix test test/sigra/organizations/slug_test.exs` -- 42 tests, 0 failures
- All 25 reserved slugs have parameterized regression tests
- Every reserved word tested individually via `for reserved <- @default_reserved` macro

## Self-Check: PASSED
