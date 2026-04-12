---
status: issues_found
phase: 13-organizations-schemas-context
depth: standard
reviewed: 2026-04-12
files_reviewed: 22
findings:
  critical: 3
  warning: 8
  info: 10
  total: 21
---

# Phase 13: Code Review Report

**Reviewed:** 2026-04-12
**Depth:** standard
**Files Reviewed:** 22
**Status:** issues_found

## Summary

Phase 13 delivers the Organizations schemas, context module, slug/query helpers, installer feature stub, and test coverage. Overall the code is well-structured and demonstrates a clear library-first architecture with hooks, atomic `Ecto.Multi` transactions, a real-DB last-owner concurrency test, and a defensive `prepare_query/3` tenant enforcement path.

Findings worth addressing before moving on: a subtle last-owner race where the current membership row is not locked; a membership changeset schema mismatch that only casts `:role` (silently dropping FK fields if host apps use the generated changeset directly); a generated invitation schema whose `changeset/2` cannot produce a successful insert because FKs are not cast; and a unique_constraint name mismatch against the partial index. No critical security issues were found.

## Critical Issues

### CR-01: `guard_last_owner` does not lock the membership row being acted on

**File:** `lib/sigra/organizations.ex:487-505`

`guard_last_owner/4` locks *other* owner rows via `FOR UPDATE` (excluding `membership_id`). In concurrent-removal scenarios, two owners being removed simultaneously can each see the *other* as the "surviving" owner — both return `:safe`, then both proceed. Integration tests pass because `Multi.delete`'s implicit row lock serializes the second deleter after the first commits, but the guard itself does not guarantee correctness.

**Fix:** Lock ALL owner rows for the org (including the current one) with `FOR UPDATE`, then check `others != []`:
```elixir
owner_ids =
  from(m in config.schemas.membership,
    where: m.organization_id == ^org_id,
    where: m.role == ^owner_role,
    select: m.id,
    lock: "FOR UPDATE"
  )
  |> repo.all()

others = Enum.reject(owner_ids, &(&1 == membership_id))
if others != [], do: {:ok, :safe}, else: {:error, :last_owner}
```

### CR-02: `OrganizationMembership.changeset/2` casts only `:role`, silently drops FK fields

**File:** `priv/templates/sigra.install/organizations/organization_membership.ex:19-26` (mirror in `test/example/lib/example/accounts/organization_membership.ex`)

Library's `build_membership_changeset` uses `put_change(:organization_id, ...)` which masks the issue, but any host code that invokes `MyApp.Accounts.OrganizationMembership.changeset(%{}, %{role: :owner, user_id: x, organization_id: y})` will silently drop the FKs.

**Fix:** Cast FK fields in the generated template:
```elixir
def changeset(membership, attrs) do
  membership
  |> cast(attrs, [:role, :user_id, :organization_id])
  |> validate_required([:role, :user_id, :organization_id])
  |> assoc_constraint(:user)
  |> assoc_constraint(:organization)
  |> unique_constraint([:user_id, :organization_id])
end
```

### CR-03: Generated `OrganizationInvitation.changeset/2` cannot successfully insert

**File:** `priv/templates/sigra.install/organizations/organization_invitation.ex:47-52` (mirror in example app)

Migration marks `organization_id` as `null: false`. The generated changeset casts `[:email, :role, :expires_at, :hashed_token, :accepted_at, :revoked_at]` but not `:organization_id`/`:invited_by_id`. Host-app flows built on the generated `changeset/2` fail at insert time with a NOT NULL violation.

**Fix:**
```elixir
def changeset(invitation, attrs) do
  invitation
  |> cast(attrs, [:email, :role, :expires_at, :hashed_token,
                  :accepted_at, :revoked_at, :organization_id,
                  :invited_by_id, :accepted_by_id])
  |> validate_required([:email, :role, :expires_at, :organization_id])
  |> assoc_constraint(:organization)
  |> unique_constraint([:organization_id, :email],
       name: :organization_invitations_pending_index)
end
```

## Warnings

### WR-01: Missing test coverage for hooks returning `{:error, reason}`

**File:** `lib/sigra/organizations.ex:259-277` (and `add_member`/`change_role` equivalents)

The `with :ok <- run_before_hook(...)` pattern propagates `{:error, reason}` correctly, but there is no test locking in the behavior. Recommend adding a test where a hook returns `{:error, :aborted}` and the context function returns it verbatim.

### WR-02: `change_role` race is the same root cause as CR-01

**File:** `lib/sigra/organizations.ex:344-371`

Fixing CR-01 resolves this.

### WR-03: `maybe_generate_slug` silently overwrites slug on update when name changes

**File:** `lib/sigra/organizations.ex:447-467`

`update_org_changeset/3` calls `maybe_generate_slug`. On update, `attrs.slug` is usually nil, so a new slug is generated from the new name — silently rewriting URLs. SaaS convention is explicit slug edits.

**Fix:** Do not auto-generate slug on update — require explicit slug change in `update_org_changeset/3`.

### WR-04: `has_org_id_filter?` can false-positive on SELECT/JOIN-side references

**File:** `lib/sigra/organizations/query.ex:127-148`

Accepts matches like `where: r.organization_id == r2.organization_id` (cross-tenant join) or `is_nil(r.organization_id)`. This is defense-in-depth, not primary security, but should be tightened to require equality against a pinned value.

### WR-05: `has_org_id_filter?` rescue clause fails OPEN

**File:** `lib/sigra/organizations/query.ex:127-139`

On rescue the function returns `true`, allowing the query through. This fails open on a security-critical path.

**Fix:** Return `false` on rescue (fail closed), log at `Logger.error`.

### WR-06: `unique_constraint(:slug)` does not reference the partial index name

**File:** `lib/sigra/organizations.ex:436-445`, migration lines 17-20

Postgres partial unique index is `organizations_slug_active_index`, but default `unique_constraint(:slug)` looks for `organizations_slug_index`. At collision time, Ecto raises a constraint-not-found error.

**Fix:** `unique_constraint(:slug, name: :organizations_slug_active_index)` — apply to create, update, and the generated Organization template.

### WR-07: No integration test for `list_organizations_for_user` excluding soft-deleted orgs

**File:** `lib/sigra/organizations.ex:405-417`

Unit test uses a mock repo; recommend adding a real-DB integration test in the example app that soft-deletes an org and verifies `list_organizations_for_user/2` excludes it.

### WR-08: Empty-string name edge case in `maybe_generate_slug`

**File:** `lib/sigra/organizations.ex:458-467`

`is_binary(name)` accepts `""`, which produces an empty slug that then fails validation. Not a bug, but cosmetic — optional cleanup: `is_binary(name) and name != ""`.

## Info

### IN-01: `context_test.exs` weak Multi assertion

**File:** `test/sigra/organizations/context_test.exs:122-138`

`assert %Ecto.Multi{} = multi` is weak. Consider using `Ecto.Multi.to_list/1` to introspect that `:organization` and `:membership` steps exist.

### IN-02: `schema_test.exs` test module definitions pollute global namespace

**File:** `test/sigra/organizations/schema_test.exs:11-83`

`MyApp.Accounts.Organization` defined at test load pollutes the module namespace. Namespace under test module to avoid redefinition warnings.

### IN-03: `get_in_scope/3` is not a generic accessor

**File:** `lib/sigra/organizations.ex:531-536`

Rename to `scope_user_id/1` or use `Kernel.get_in/2` with Access keys.

### IN-04: `__using__` delegators lose `@doc`

**File:** `lib/sigra/organizations.ex:131-190`

Generated delegators have no docs in host ExDoc output. Add `@doc "See `Sigra.Organizations.create_organization/3`."` before each def.

### IN-05: `OrganizationInvitation` timestamps are automatic (non-issue, noted)

### IN-06: Migration uses `utc_datetime` (second precision) — consistent with Phoenix 1.8

### IN-07: `@config` module attributes evaluate `Slug.default_reserved_slugs()` at compile time (works, noted)

### IN-08: EEx conditional `@primary_key` produces extra blank lines — `mix format` will clean

### IN-09: `MockRepo.Behaviour` lacks `prepare_query/3` — out of scope, add in Phase 14+

### IN-10: `last_owner_test.exs` alias usage — the alias is used via `@config`, actually fine

---

## Files reviewed (22)

- lib/sigra/install/features/organizations.ex
- lib/sigra/organizations.ex
- lib/sigra/organizations/callbacks.ex
- lib/sigra/organizations/query.ex
- lib/sigra/organizations/slug.ex
- priv/templates/sigra.install/core/scope.ex
- priv/templates/sigra.install/organizations/migration.exs
- priv/templates/sigra.install/organizations/organization.ex
- priv/templates/sigra.install/organizations/organization_invitation.ex
- priv/templates/sigra.install/organizations/organization_membership.ex
- test/example/lib/example/accounts/organization.ex
- test/example/lib/example/accounts/organization_invitation.ex
- test/example/lib/example/accounts/organization_membership.ex
- test/example/priv/repo/migrations/20260410125245_create_organizations.exs
- test/example/test/example/organizations/last_owner_test.exs
- test/sigra/install/features/organizations_test.exs
- test/sigra/organizations/context_test.exs
- test/sigra/organizations/last_owner_test.exs
- test/sigra/organizations/query_test.exs
- test/sigra/organizations/schema_test.exs
- test/sigra/organizations/slug_test.exs
- test/support/mock_repo_behaviour.ex
