---
phase: 13-organizations-schemas-context
plan: 01
subsystem: organizations
tags: [schemas, migration, feature-manifest, templates]
dependency_graph:
  requires: [11-generator-feature-system, 12-scope-session-foundation]
  provides: [organization-schemas, organization-migration, feature-organizations]
  affects: [13-02, 13-03, 14-plugs, 17-invitations, 18-generator-wiring]
tech_stack:
  added: []
  patterns: [feature-behaviour, adapter-branched-migration, ecto-enum-roles]
key_files:
  created:
    - lib/sigra/install/features/organizations.ex
    - priv/templates/sigra.install/organizations/migration.exs
    - priv/templates/sigra.install/organizations/organization.ex
    - priv/templates/sigra.install/organizations/organization_membership.ex
    - priv/templates/sigra.install/organizations/organization_invitation.ex
    - test/sigra/install/features/organizations_test.exs
    - test/sigra/organizations/schema_test.exs
  modified:
    - priv/templates/sigra.install/core/scope.ex
decisions:
  - "Features.Organizations returns empty lists for files/injections/post_instructions (Phase 18 fills these)"
  - "Ecto.Enum role validation tested via changeset round-trip rather than internal struct inspection"
metrics:
  duration_seconds: 318
  completed: "2026-04-12T16:15:00Z"
  tasks_completed: 2
  tasks_total: 2
  test_count: 23
  files_created: 7
  files_modified: 1
---

# Phase 13 Plan 01: Organization Schemas, Migration, and Feature Manifest Summary

Feature behaviour implementation for organizations with adapter-branched migration template creating 3 tables (organizations, memberships, invitations) and Ecto schema templates with Enum-constrained roles

## What Was Built

### Features.Organizations Module
- Implements all 5 `Sigra.Install.Feature` callbacks
- `enabled?/1` checks `organizations` option (default: true)
- `migrations/1` returns one slot: `{:organizations, "organizations/migration.exs", "create_organizations.exs"}`
- `files/1`, `injections/1`, `post_instructions/2` return empty lists (Phase 18 fills these)
- Zero references to `Features.Core` (Pitfall X-3 isolation verified by test)

### Migration Template
- Single migration file with FK-ordered table creation: organizations -> memberships -> invitations
- PostgreSQL branch: citext for slug/email, partial unique indexes for soft-delete slug reclamation and pending invite deduplication
- MySQL/SQLite branch: string types with size limits, plain/composite unique indexes as fallback
- Correct FK cascades: `on_delete: :delete_all` for memberships/invitations, `on_delete: :nilify_all` for invited_by_id/accepted_by_id

### Schema Templates
- **Organization**: name, slug, deleted_at, has_many memberships/invitations, changeset with slug format validation
- **OrganizationMembership**: role as `Ecto.Enum` with `[:owner, :admin, :member]`, belongs_to organization/user
- **OrganizationInvitation**: email, role, hashed_token, timestamp-based status (accepted_at/revoked_at), belongs_to organization/invited_by/accepted_by

### Scope Template Update
- Typespecs tightened from `struct() | nil` to `%Organization{} | nil` and `%OrganizationMembership{} | nil`
- Added aliases for Organization and OrganizationMembership

## Commits

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Schema templates + migration + Features.Organizations | 4d222aa | 6 new files + scope.ex update |
| 2 | Schema changeset unit tests | 61306fa | test/sigra/organizations/schema_test.exs |

## Deviations from Plan

None - plan executed exactly as written.

## Verification

- `mix compile --warnings-as-errors` exits 0
- `mix test test/sigra/install/features/organizations_test.exs` -- 10 tests, 0 failures
- `mix test test/sigra/organizations/schema_test.exs` -- 13 tests, 0 failures
- All 4 template files exist under `priv/templates/sigra.install/organizations/`
- Scope template contains real typespecs

## Self-Check: PASSED

All 7 created files verified on disk. Both commits verified in git log.
