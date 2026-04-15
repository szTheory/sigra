---
phase: 13-organizations-schemas-context
plan: 03
subsystem: organizations
tags: [context-module, nimble-options, use-macro, last-owner-guard, audit, ecto-multi, soft-delete]
dependency_graph:
  requires: [13-01, 13-02]
  provides: [organizations-context-api, use-macro-delegators, last-owner-guard, overridable-hooks]
  affects: [14-plugs, 15-liveviews, 16-invitations, 17-admin, 18-generator-wiring]
tech_stack:
  added: []
  patterns:
    - library-first-thin-delegator-macro
    - nimble-options-compile-time-config-validation
    - ecto-multi-guard-with-for-update-lock
    - multi-error-normalization-to-2-tuple
    - audit-log-multi-safe-emission
    - defoverridable-lifecycle-hooks
    - mox-unit-tests-with-inline-test-schemas
key_files:
  created:
    - lib/sigra/organizations.ex
    - lib/sigra/organizations/callbacks.ex
    - test/sigra/organizations/context_test.exs
    - test/sigra/organizations/last_owner_test.exs
    - test/example/lib/example/accounts/organization.ex
    - test/example/lib/example/accounts/organization_membership.ex
    - test/example/lib/example/accounts/organization_invitation.ex
    - test/example/priv/repo/migrations/20260410125245_create_organizations.exs
    - test/example/test/example/organizations/last_owner_test.exs
  modified:
    - test/support/mock_repo_behaviour.ex
decisions:
  - "guard_last_owner uses SELECT id + FOR UPDATE then list check instead of aggregate(:count) — PostgreSQL does not allow FOR UPDATE with aggregate functions; result is equivalent but compatible"
  - "Real-DB FOR UPDATE integration tests live in the example app (test/example/test/example/organizations/last_owner_test.exs) because the library itself has no Repo; unit-level guarantees (error normalization, guard firing, role change paths) are covered by Mox in test/sigra/organizations/last_owner_test.exs"
  - "Test wrapper modules define inline Ecto schemas (TestOrg/TestMembership/TestInvitation/TestUser) so context tests remain self-contained and do not depend on example app schemas"
  - "MockRepo.Behaviour extended with one!/1 and aggregate/2 callbacks to cover get_organization! and any future aggregate queries"
metrics:
  duration_seconds: 1800
  completed: "2026-04-12T00:00:00Z"
  tasks_completed: 2
  tasks_total: 2
  test_count: 17
  files_created: 9
  files_modified: 2
---

# Phase 13 Plan 03: Organizations Context + Last-Owner Guard Summary

Sigra.Organizations context module with NimbleOptions-validated use macro, Ecto.Multi CRUD with FOR UPDATE last-owner guard, audit emission, and 17 passing Mox unit tests plus real-DB integration tests in the example app

## What Was Built

### Sigra.Organizations (lib/sigra/organizations.ex, 561 LOC)

**Public API (config-first arity):**
- `create_organization/3` — Multi inserts org + owner membership atomically, auto-generates slug from name when absent, runs before/after_create hooks, emits `organization.create` audit event
- `update_organization/4` — Cast/validate/slug-check changeset, emits `organization.update`
- `soft_delete_organization/3` — Sets `deleted_at` via Multi, runs before/after_delete hooks, emits `organization.delete`
- `add_member/4` — Multi insert membership with role, hooks, emits `organization.member_add`
- `remove_member/3` — Multi with `guard_last_owner` step + delete, emits `organization.member_remove`, runs after_member_remove hook
- `change_role/4` — Conditionally runs last-owner guard when demoting from owner_role, Multi update, emits `organization.member_role_change`
- `get_organization!/2` — `repo.one!` query with `is_nil(deleted_at)` filter, raises Ecto.NoResultsError
- `get_organization_by_slug/2` — `repo.one` query with slug + `is_nil(deleted_at)` filter, returns nil when absent
- `list_organizations_for_user/2` — Joins memberships on user_id, filters soft-deleted orgs, orders by name
- `get_membership/3` — Returns membership by user_id + organization_id or nil

**`__using__/1` macro (D-02, D-03, D-04):**
- Validates opts via `NimbleOptions.validate!` against `@org_config_schema`
- Stores validated config map as `@sigra_org_config` (adds `caller_module: __MODULE__` for hook dispatch)
- Declares `@behaviour Sigra.Organizations.Callbacks`
- Injects 10 thin delegators (create/update/soft_delete/add/remove/change_role/get!/get_by_slug/list/get_membership) — each one line
- Injects 8 no-op default implementations of lifecycle callbacks
- `defoverridable` all 8 callbacks so app code customizes by overriding

**NimbleOptions config schema:**
`repo` (required atom), `schemas` (required keyword with organization/membership/invitation/user/scope), `roles` (default `[:owner, :admin, :member]`), `owner_role` (default `:owner`), `reserved_slugs`, `additional_reserved_slugs`, `slug_format`, `slug_length`, `enforce_org_scope`, `audit_schema`, `hooks`

**Internal helpers:**
- `guard_last_owner/3` — `Multi.run` step issuing `SELECT id ... WHERE role = owner_role AND id != membership_id FOR UPDATE`, returns `{:error, :last_owner}` when result is empty, `{:ok, :safe}` otherwise
- `normalize_multi_result/1` — Maps `{:ok, changes}` → `{:ok, changes}`, `{:error, :guard_last_owner, :last_owner, _}` → `{:error, :last_owner}`, `{:error, _, %Changeset{}, _}` → `{:error, changeset}`, `{:error, _, reason, _}` → `{:error, reason}`
- Audit helper builds opts keyword list with `repo`, `audit_schema`, `actor_id`, and action metadata

### Sigra.Organizations.Callbacks (lib/sigra/organizations/callbacks.ex, 49 LOC)

Behaviour with 8 `@callback` specs: `before_create_organization/2`, `after_create_organization/2`, `before_delete_organization/2`, `after_delete_organization/2`, `before_add_member/4`, `after_add_member/3`, `before_role_change/3`, `after_member_remove/2`. All return `:ok | {:error, term()}` or `{:ok, changeset} | {:error, term()}`.

### Test Coverage

**test/sigra/organizations/context_test.exs (12 tests, Mox, async)** — inline `TestOrg`/`TestMembership`/`TestInvitation`/`TestUser`/`TestScope` schemas; `@test_config` map:
- `create_organization/3`: valid attrs, missing name, reserved slug, auto-slug generation
- `update_organization/4`: valid attrs
- `soft_delete_organization/3`: deleted_at set
- `get_organization!/2`: raises on deleted/missing
- `get_organization_by_slug/2`: nil on nonexistent
- `list_organizations_for_user/2`: returns orgs, empty when all soft-deleted
- `normalize_multi_result/1`: guard_last_owner → `{:error, :last_owner}`, changeset → `{:error, changeset}`

**test/sigra/organizations/last_owner_test.exs (5 tests, Mox, async)** — focused on guard + change_role paths:
- `remove_member` fires guard → `{:error, :last_owner}`
- `remove_member` passes guard → `{:ok, _}`
- `change_role` demoting owner → `{:error, :last_owner}`
- `change_role` non-owner role change → succeeds, does not trigger guard
- `change_role` promoting member to owner → succeeds, does not trigger guard

**test/example/test/example/organizations/last_owner_test.exs (integration, real DB, async: false)** — exercises actual FOR UPDATE serialization against Postgres using Example.DataCase. Covers sole-owner removal failure, multi-owner removal success, change_role demotion guarantees, and concurrent removal serialization. Runs inside the example app's test suite (not the library's `mix test`).

### Supporting Infrastructure

- `test/example/lib/example/accounts/organization.ex`, `organization_membership.ex`, `organization_invitation.ex` — Example app schemas for integration tests
- `test/example/priv/repo/migrations/20260410125245_create_organizations.exs` — Organizations + memberships + invitations tables for example app
- `test/support/mock_repo_behaviour.ex` — Added `@callback one!/1` and `@callback aggregate/2`

## Commits

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Sigra.Organizations context + Callbacks behaviour + use macro | 0801f1a | lib/sigra/organizations.ex, lib/sigra/organizations/callbacks.ex |
| 2 | Context + last-owner guard tests | 343d307 | test/sigra/organizations/context_test.exs, test/sigra/organizations/last_owner_test.exs, test/example/test/example/organizations/last_owner_test.exs, example app schemas + migration, lib/sigra/organizations.ex (guard_last_owner fix), test/support/mock_repo_behaviour.ex |

## Verification

- `mix test test/sigra/organizations/context_test.exs test/sigra/organizations/last_owner_test.exs` → 17 tests, 0 failures (0.1s async)
- `mix compile` → exits 0, no warnings
- Acceptance criteria from PLAN.md Task 2 satisfied: `describe "create_organization"`, `describe "soft_delete_organization"`, `{:error, changeset}` for invalid attrs, reserved slug test, `{:error, :last_owner}` assertions, 2+ owner removal succeeds, `change_role` demoting last owner

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] guard_last_owner incompatible with PostgreSQL FOR UPDATE + aggregate**

- **Found during:** Task 2 (running integration tests against real Postgres in the example app)
- **Issue:** The plan's `guard_last_owner/4` sketch uses `repo.aggregate(:count)` with `lock: "FOR UPDATE"`. PostgreSQL rejects FOR UPDATE alongside aggregate functions (`SELECT count(*) ... FOR UPDATE` is not permitted).
- **Fix:** Switched to `select: m.id` + `repo.all()` + `if other_owners != [], do: {:ok, :safe}, else: {:error, :last_owner}`. Semantically equivalent (presence check), locks rows, and satisfies the acceptance criterion `lock: "FOR UPDATE"`.
- **Files modified:** lib/sigra/organizations.ex
- **Commit:** 343d307

**2. [Rule 3 - Blocking] MockRepo behaviour missing callbacks**

- **Found during:** Task 2 (Mox expectations raised "unknown callback" errors)
- **Issue:** Context module uses `repo.one!/1` (for get_organization!) and the original guard_last_owner used `repo.aggregate/2`. Neither was declared in the MockRepo behaviour.
- **Fix:** Added `@callback one!/1` and `@callback aggregate/2` to `Sigra.MockRepo.Behaviour`.
- **Files modified:** test/support/mock_repo_behaviour.ex
- **Commit:** 343d307

**3. [Rule 3 - Blocking] Real-DB integration tests require example app schemas**

- **Found during:** Task 2 (last-owner FOR UPDATE semantics cannot be exercised without a real Repo, which the library test suite lacks)
- **Issue:** Plan asks for integration tests proving FOR UPDATE lock serialization. The library itself has no database; this can only run inside the example app.
- **Fix:** Added Example.Accounts.Organization/Organization{Membership,Invitation} schemas, a migration, and `test/example/test/example/organizations/last_owner_test.exs` that uses `Example.DataCase` and exercises concurrent removal via `Task.async`. The library's `test/sigra/organizations/last_owner_test.exs` remains Mox-based (fast, async, always-runs) and proves the normalization + dispatch paths.
- **Files created:** test/example/lib/example/accounts/organization.ex, organization_membership.ex, organization_invitation.ex, test/example/priv/repo/migrations/20260410125245_create_organizations.exs, test/example/test/example/organizations/last_owner_test.exs
- **Commit:** 343d307

### Clarifications

- **`--no-start` flag from PLAN verify command not used.** Mox requires the Mox.Server GenServer, which is part of the Mox application started by the test helper. Running `mix test ... --no-start` crashes Mox with "no process". Running without `--no-start` (standard `mix test`) passes all 17 tests. This is expected Mox behavior, not a plan deviation of substance — just a command-line correction.

## Requirements Satisfied

- **ORG-05** (Last-owner guard) — `guard_last_owner/3` with FOR UPDATE row lock, returns `{:error, :last_owner}` when removing or demoting the sole owner; integration test proves concurrent serialization
- **ORG-08** (Organizations context CRUD API) — `create/update/soft_delete/add_member/remove_member/change_role/get!/get_by_slug/list/get_membership` all implemented and tested

## Threat Mitigations Applied

| Threat ID | Mitigation | Evidence |
|-----------|------------|----------|
| T-13-09 (EoP: last-owner removal) | `guard_last_owner/3` FOR UPDATE row lock in Ecto.Multi; `{:error, :last_owner}` returned to caller | lib/sigra/organizations.ex guard_last_owner; test/sigra/organizations/last_owner_test.exs remove_member guard test; example app concurrent removal integration test |
| T-13-10 (EoP: admin demotes owner self-promotion) | `change_role/4` runs guard before owner demotion | test/sigra/organizations/last_owner_test.exs change_role guard test |
| T-13-11 (Repudiation: unaudited mutations) | Every mutation emits `organization.*` event via `Sigra.Audit.log_multi_safe` | grep `log_multi_safe` in lib/sigra/organizations.ex (6 call sites: create/update/delete/member_add/member_remove/member_role_change) |
| T-13-13 (Info disclosure: soft-deleted org visibility) | All read queries include `is_nil(o.deleted_at)`; explicit not auto-scoped | get_organization!, get_organization_by_slug, list_organizations_for_user |

## Self-Check: PASSED

- FOUND: lib/sigra/organizations.ex
- FOUND: lib/sigra/organizations/callbacks.ex
- FOUND: test/sigra/organizations/context_test.exs
- FOUND: test/sigra/organizations/last_owner_test.exs
- FOUND: test/example/test/example/organizations/last_owner_test.exs
- FOUND: test/example/lib/example/accounts/organization.ex
- FOUND: test/example/lib/example/accounts/organization_membership.ex
- FOUND: test/example/lib/example/accounts/organization_invitation.ex
- FOUND: test/example/priv/repo/migrations/20260410125245_create_organizations.exs
- FOUND: commit 0801f1a (Task 1)
- FOUND: commit 343d307 (Task 2)
- `mix test` for targeted files: 17 tests, 0 failures
