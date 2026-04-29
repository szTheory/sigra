---
phase: 92-rbac-seams-b2b-02
reviewed: 2026-04-29T17:00:00Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - lib/sigra/authz.ex
  - lib/sigra/admin/policy.ex
  - lib/sigra/organizations.ex
  - lib/sigra/organizations/invitations.ex
  - lib/sigra/plug/require_membership.ex
  - lib/sigra/install/features/core.ex
  - lib/sigra/scope.ex
  - lib/sigra/scope/hydration.ex
  - lib/sigra/plug/put_active_organization.ex
  - lib/sigra/plug/load_active_organization.ex
  - priv/templates/sigra.install/core/sigra_authz.ex
  - priv/templates/sigra.install/core/scope.ex
  - priv/templates/sigra.install/organizations/organization_membership.ex
  - priv/templates/sigra.install/organizations/migration.exs
  - priv/templates/sigra.install/organizations/organizations.ex
  - guides/recipes/role-based-access-control.md
  - mix.exs
findings:
  critical: 4
  warning: 7
  info: 3
  total: 14
status: issues_found
---

# Phase 92: Code Review Report

**Reviewed:** 2026-04-29T17:00:00Z
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found

## Summary

Phase 92 makes the library role-agnostic: `:roles`, `:owner_role`, and `:invitation_admin_roles` are required configuration; `Sigra.Authz` is a behaviour-only seam; the membership `:role` column is nullable and host-owned; and `:role` propagation through `Sigra.Scope.Hydration` and `Sigra.Plug.PutActiveOrganization` is wired correctly.

The seam itself is clean. The defects below cluster in the **template + injection layer**, where the role-removal claim is not actually delivered: the generator still hardcodes `:owner` in router pipeline content, the invitation schema still pins an `Ecto.Enum` to `[:owner, :admin, :member]`, the invitation-table migration still defaults `role` to `"member"`, and the new config schema does not enforce that `:owner_role` and `:invitation_admin_roles` are subsets of `:roles`. A host that runs `mix sigra.install` and edits `roles:` to a non-default taxonomy (the explicit Phase 92 contract) will get a router that fails `RequireMembership.init/1` validation at boot, an invitation schema that rejects their role atoms, and silent inconsistency between `:owner_role` / `:roles`.

The four BLOCKER findings should be fixed before this ships — they directly invalidate the Phase 92 promise that hosts own the role taxonomy.

## Critical Issues

### CR-01: Router injection hardcodes `:owner`, breaking custom-taxonomy hosts at boot

**File:** `lib/sigra/install/features/core.ex:466-474`
**Issue:** The `:require_org_owner` pipeline emitted by `mix sigra.install` reads:

```elixir
pipeline :require_org_owner do
  plug Sigra.Plug.RequireMembership,
    error_handler: #{web_module}.AuthErrorHandler,
    roles: [:owner]
end
```

This injection has two compounding defects under Phase 92:

1. It hardcodes `roles: [:owner]`. A host that customizes `MyApp.Organizations` to `roles: [:tenant_lead, :site_admin]` (the documented Phase 92 supported case — see `guides/recipes/role-based-access-control.md:206`) gets a router that gates on a role atom that is not in their taxonomy. Every request piped through `:require_org_owner` will halt with `:insufficient_role`, because no membership ever has `role == :owner`.
2. It omits `organizations:`. The new `Sigra.Plug.RequireMembership.init/1` (lib/sigra/plug/require_membership.ex:103-111) raises `ArgumentError` when `:roles` is non-empty without `:organizations`. Routers compile-time-evaluate plug `init/1` for the pipeline macro, so even a host that **keeps** `roles: [:owner, :admin, :member]` will see `mix phx.server` fail with: *":roles is non-empty but :organizations is missing."*

The router injection must thread the host's organizations module and either drop the hardcoded `[:owner]` (e.g., reuse `config.owner_role`) or omit the role gate entirely from the generated default.

**Fix:**
```elixir
# Either reference the host's owner_role via the organizations module:
pipeline :require_org_owner do
  plug Sigra.Plug.RequireMembership,
    error_handler: #{web_module}.AuthErrorHandler,
    organizations: #{context_module}.Organizations,
    roles: [:owner]   # only valid if the host keeps the starter taxonomy
end

# Or omit the owner-only pipeline from the default injection and document
# it as a recipe addition. The starter taxonomy is host-owned now.
```
The simplest correct emission is to omit the `:require_org_owner` pipeline entirely from `core.ex` and let hosts wire it explicitly per the RBAC recipe — that matches the Phase 92 "library ships no role taxonomy" contract.

---

### CR-02: Invitation schema template still hardcodes `Ecto.Enum, values: [:owner, :admin, :member]`

**File:** `priv/templates/sigra.install/organizations/organization_invitation.ex:27`
**Issue:** While `OrganizationMembership` was correctly migrated to `field :role, :string` (Plan 92-02), the sibling `OrganizationInvitation` schema was missed:

```elixir
field :role, Ecto.Enum, values: [:owner, :admin, :member]
```

Consequences:
- A host that customizes `roles: [:tenant_lead, :reviewer]` per the Phase 92 contract will see `Sigra.Organizations.Invitations.create/2` raise `Ecto.ChangeError` (or surface a changeset error) because `Ecto.Enum.cast(:tenant_lead)` returns `:error`. Invitation creation is broken from the first day for any non-default-taxonomy host.
- Inconsistency with the membership schema (string + nullable + host-customizable) breaks the Phase 92 invariant that the role column is host-owned.

**Fix:**
```elixir
# Phase 92 / Plan 92-02 parity: role storage is host-owned. Match the
# OrganizationMembership shape — plain string, no library-pinned enum.
field :role, :string
```
Add a docstring note matching the membership template's "add Ecto.Enum here if you want strict validation" guidance.

---

### CR-03: Invitations migration hardcodes `default: "member"`

**File:** `priv/templates/sigra.install/organizations/migration.exs:57` (Postgres branch) and `priv/templates/sigra.install/organizations/migration.exs:166` (MySQL/SQLite branch)
**Issue:** Both adapter branches still emit:

```elixir
add :role, :string, null: false, default: "member"
```

This is the inverse of the Phase 92 Plan 92-02 change to memberships (which became `role :string` nullable with no default). For a host with `roles: [:tenant_lead, :reviewer]`:

1. `null: false, default: "member"` writes the literal string `"member"` into every invitation row that does not explicitly set role.
2. The host's authorization checks against `attrs.role` (an atom) compare against a string `"member"` that is never in their taxonomy.
3. Even if the host's app code always sets role explicitly, the migration encodes a library opinion (`"member"` is the default role name) the rest of Phase 92 explicitly removed.

The migration is a generated artifact, but it runs on `mix ecto.migrate` in fresh installs — by the time the host edits, the column constraint is already in the database.

**Fix:**
```elixir
# Postgres branch (line 57)
add :role, :string

# MySQL/SQLite branch (line 166)
add :role, :string
```
Remove `null: false` and `default: "member"`. If the host wants strictness they can add it via a follow-up migration, matching the Plan 92-02 shape that already ships for memberships.

---

### CR-04: Config schema does not enforce documented `:owner_role` / `:invitation_admin_roles` subset invariants

**File:** `lib/sigra/organizations.ex:79-88, 134-145`
**Issue:** The `:owner_role` doc says "The atom must be a member of `:roles`" (line 86) and `:invitation_admin_roles` doc says "Atoms here must be a subset of `:roles`" (line 143). Neither invariant is validated. A host can write:

```elixir
use Sigra.Organizations,
  roles: [:tenant_lead, :reviewer],
  owner_role: :owner,                       # NOT in :roles
  invitation_admin_roles: [:admin, :owner]  # NOT in :roles
```

`NimbleOptions.validate!` accepts this silently. Downstream:
- `do_create_organization/4` (line 435) inserts a membership with `role: :owner` even though the configured `:roles` universe is `[:tenant_lead, :reviewer]`. The host's membership row now carries an unenforceable role atom that no app code recognizes.
- `guard_last_owner/4` (line 1296) compares `m.role == :owner`, which never matches the host's actual rows. The last-owner guard is **silently disabled** — owners can be removed/demoted unsafely.
- `authorize_create/2` for invitations (line 111) checks `role in invitation_admin_roles`. With `:admin` not in the host's universe, an admin can invite but their `change_role` writes are operating against a different atom set.

This is the highest-impact silent failure in the phase: a misconfigured deployment loses its last-owner safety guard and the privilege model becomes incoherent without surfacing any error.

**Fix:** Add post-validation in `__validate_config__!/1`:

```elixir
def __validate_config__!(opts) do
  validated = NimbleOptions.validate!(opts, @org_config_schema)
  validated = validated |> Map.new() |> Map.update!(:schemas, &Map.new/1)

  validate_role_invariants!(validated)
  validated
end

defp validate_role_invariants!(%{roles: roles, owner_role: owner_role,
                                  invitation_admin_roles: invitation_admin_roles}) do
  unless owner_role in roles do
    raise ArgumentError,
          "Sigra.Organizations :owner_role #{inspect(owner_role)} is not in :roles " <>
            "#{inspect(roles)}. The owner role must be a member of the configured " <>
            "role universe."
  end

  invalid = invitation_admin_roles -- roles

  unless invalid == [] do
    raise ArgumentError,
          "Sigra.Organizations :invitation_admin_roles contains atoms not in :roles: " <>
            "#{inspect(invalid)}. Configured :roles: #{inspect(roles)}."
  end
end
```
Failing fast at `use Sigra.Organizations` is the same posture the rest of Phase 92 takes (the `RequireMembership` plug, the `Admin.Policy` helper, the `Invitations.fetch_invitation_admin_roles!` helper).

## Warnings

### WR-01: `RequireMembership.init/1` rescue swallows unrelated `UndefinedFunctionError`

**File:** `lib/sigra/plug/require_membership.ex:113-131`
**Issue:** The `try/rescue UndefinedFunctionError` block is narrow in intent — catching the case where the host module does not export `__sigra_org_config__/0`. But `rescue UndefinedFunctionError` catches the exception from anywhere in the call chain, including transitively from inside a custom host module override of `__sigra_org_config__/0` that itself crashes due to an unrelated typo. The result is a misleading `ArgumentError` claiming the host module "does not export __sigra_org_config__/0" when in reality it does, but its body raised.

**Fix:**
```elixir
defp resolve_role_universe!(opts) do
  case Keyword.get(opts, :organizations) do
    nil -> raise ArgumentError, "..."

    module when is_atom(module) ->
      unless function_exported?(module, :__sigra_org_config__, 0) do
        raise ArgumentError,
              "Sigra.Plug.RequireMembership :organizations module " <>
                "#{inspect(module)} does not export __sigra_org_config__/0..."
      end

      case module.__sigra_org_config__() do
        %{roles: roles} when is_list(roles) and roles != [] -> roles
        _ -> raise ArgumentError, "..."
      end
  end
end
```
`Code.ensure_loaded?/1` may also be needed if the module hasn't been loaded yet at plug init time.

---

### WR-02: `OrganizationMembership.changeset` does not reject unknown role atoms

**File:** `priv/templates/sigra.install/organizations/organization_membership.ex:51-58`
**Issue:** The membership changeset only does `cast([:role, :user_id, :organization_id])` and does not validate that the role is a member of the host's configured universe. A controller that accepts an attacker-supplied role attr (`%{"role" => "superuser"}`) inserts a membership row with a role atom no policy recognizes — then `RequireMembership` admits the request because that role passes the `not in [:owner, :admin, :member]` check from a different code path, OR the privilege model silently drops it.

The schema docstring (line 18) acknowledges this: *"If your app needs strict role validation, edit the changeset below to pin the role atom against your host taxonomy."* Recommending edit-after-the-fact is a footgun for the privilege contract.

**Fix:** Either:
1. Generator-time: have the installer write `validate_inclusion(:role, roles)` into the changeset using the host's configured `roles:` list, OR
2. Library-time: have `Sigra.Organizations.add_member/5` (and `change_role/4`) refuse a role atom not in `config.roles`, regardless of the changeset shape.

The library-side guard is the safer pattern because it cannot be bypassed by edits to the host changeset.

---

### WR-03: `add_member/5` and `change_role/4` accept arbitrary role atoms not in `config.roles`

**File:** `lib/sigra/organizations.ex:833-851, 971-998`
**Issue:** Continuation of WR-02 — even if the host changeset adds `validate_inclusion`, the library API itself does not enforce that `role in config.roles`. `add_member(config, scope, org, user, :superuser)` and `change_role(config, scope, membership, :ghost)` proceed to build a changeset and insert. The role atom passes through to the DB column; nothing rejects it.

This is the same class of silent privilege drift as CR-04 but at the per-call rather than the per-config level.

**Fix:** Add an early guard in both functions:
```elixir
def add_member(config, scope, org, user, role) do
  unless role in config.roles do
    raise ArgumentError,
          "add_member/5 received role #{inspect(role)} not in configured " <>
            ":roles #{inspect(config.roles)}"
  end
  # ... existing logic
end
```
Same for `change_role/4`. Use a raise (programming error) rather than `{:error, _}` because a controller passing an unconfigured role is an internal bug, not a user-facing failure mode.

---

### WR-04: `set_mfa_policy/5` uses `unless ... else` (Credo style violation; obscures control flow)

**File:** `lib/sigra/organizations.ex:791-796`
**Issue:**
```elixir
unless is_function(mfa_check_fn, 1) do
  raise ArgumentError, "..."
end

if not mfa_check_fn.(scope.user), do: {:error, :admin_must_enroll_first}, else: do_set_mfa_policy(config, scope, org, value)
```

Two readability problems on the same code path. The `if not ... do ... else` form is a Credo `Credo.Check.Refactor.UnlessWithElse` cousin and obscures the happy path. This file is otherwise idiomatic; this stands out.

**Fix:**
```elixir
if mfa_check_fn.(scope.user) do
  do_set_mfa_policy(config, scope, org, value)
else
  {:error, :admin_must_enroll_first}
end
```

---

### WR-05: `accept_with_signup/3` audit step lands twice when register_user_multi audit_schema is wired

**File:** `lib/sigra/organizations/invitations.ex:638-660`
**Issue:** `register_user_multi/2` (lib/sigra/auth.ex:228-247) appends an `auth.register.success` audit step when `:audit_schema` is in opts. The `accept_with_signup` flow calls it with only `[changeset_fn: ...]` — no audit_schema — so today the audit step does NOT get appended, which is the desired behavior for Phase 17 (the `organization.invitation.accepted` audit is sufficient). But this is a brittle coupling: a maintainer who later adds `audit_schema:` to `register_opts` (as a logical thing to do) would silently double-emit audit rows for the registration leg of an invitation accept-with-signup. There is no test guarding against the double-write.

**Fix:** Make the suppression explicit:
```elixir
# Plan 17 contract: the org.invitation.accepted audit row is the authoritative
# event for the accept-with-signup flow; we deliberately do NOT thread
# :audit_schema into register_user_multi to avoid a double-write.
register_opts = [changeset_fn: config.user_registration_changeset_fn]
```
Or, better, factor a `register_user_multi_no_audit/2` that documents the no-audit guarantee at the type level.

---

### WR-06: `list_organizations_for_user/1` wrapper has misleading return type

**File:** `lib/sigra/organizations.ex:342-343`
**Issue:** The `__using__` macro injects:
```elixir
def list_organizations_for_user(user),
  do: Sigra.Organizations.list_organizations_with_roles_for_user(@sigra_org_config, user)
```

The wrapper is named `list_organizations_for_user` but delegates to `list_organizations_*with_roles*_for_user`, which returns `[{org, role}]` tuples. The library function with the matching name (line 1036) returns `[org]`. Two functions with the same name (`list_organizations_for_user`) returning different shapes is a maintainability trap. A controller author auditing the library would (correctly) expect `wrapper.list_organizations_for_user(user)` to match the library function of the same name; instead the wrapper silently changes the return type.

**Fix:** Either:
1. Rename the wrapper to `list_organizations_with_roles_for_user/1` to match the library function it delegates to, OR
2. Delegate to the matching-named library function and have callers that need roles call `list_organizations_with_roles_for_user/1` explicitly.

---

### WR-07: `purge_org_sessions/3` predicate races with the membership-delete it accompanies

**File:** `lib/sigra/organizations.ex:1380-1394`
**Issue:** This is a pre-Phase-92 latent issue but is in the diffed file. `remove_member/3` runs `purge_org_sessions` and `Multi.delete(:membership, ...)` in the same Multi. The session-purge predicate is `s.user_id == ^membership.user_id and s.active_organization_id == ^membership.organization_id`. On a host that performs the membership deletion outside of Sigra (Ecto.Repo.delete on the host's own schema), `purge_org_sessions` is bypassed entirely and stale `user_sessions.active_organization_id` rows survive — `LoadActiveOrganization`'s stale-pointer recovery is the only remaining backstop, and it relies on `:not_a_member` triggering, which it would.

This is a robustness comment rather than a bug — the recovery path catches it. But the predicate is sufficiently order-sensitive that the next refactor of the Multi (e.g., adding a guard step before `:purge_org_sessions`) could expose a real ordering bug. Worth a regression test.

**Fix:** Add a comment or test asserting `:purge_org_sessions` runs before the membership-row delete in the Multi build order, and that the membership row's `user_id`/`organization_id` are the values used (not a re-read after deletion).

## Info

### IN-01: `mismatch` branch in `accept/3` has no audit emission, but doc claim is partial

**File:** `lib/sigra/organizations/invitations.ex:551-557, 311`
**Issue:** Doc says *"All non-:ok branches skip audit emission for organization.invitation.accepted"* (line 313), which is correct. But there is no positive audit event for the **`:mismatch` branch** — a user attempting to accept an invitation bound to a different email is a security-relevant event (Jetstream #907 / CVE-2026-1529 defense) and downstream operators may want telemetry. Currently it returns `{:error, :mismatch}` with zero observable side effect. Consider emitting `[:sigra, :invitation, :accept_email_mismatch]` telemetry for parity with the email-skipped/email-failed events.

**Fix:** Optional — add telemetry emission for the mismatch branch in `assert_user_matches_invitation/2`.

---

### IN-02: Module-level `require Logger` placed mid-module in invitations.ex

**File:** `lib/sigra/organizations/invitations.ex:52`
**Issue:** Style — `require Logger` sits between aliases and the first function definition. Idiomatic Elixir places `require` calls in the same group as `alias`/`import`, just below `@moduledoc`. This is cosmetic.

**Fix:**
```elixir
import Ecto.Query
alias Ecto.Multi
alias Sigra.Token
require Logger
```

---

### IN-03: `Sigra.Scope.from_config/2` reads `:role` and `:actor_type` from a `Sigra.Config` struct — but the struct does not declare those fields

**File:** `lib/sigra/scope.ex:115-119`
**Issue:**
```elixir
build(mod, user,
  active_organization: nil,
  role: Map.get(config, :role),
  actor_type: Map.get(config, :actor_type)
)
```

This silently returns `nil` for both fields when `config` is a real `%Sigra.Config{}` struct that does not declare `:role` or `:actor_type` (the typical case — Phase 92 didn't add them to `Sigra.Config`). That's the desired behavior, but it means callers can never thread a role through `from_config/2` without dropping to a plain map. The doc says *"`:role` and `:actor_type` are passed through additively when present on the config map"* which is misleading — they're never present on the struct shape.

**Fix:** Either add `:role` and `:actor_type` to `Sigra.Config` (Phase 93 will likely need this anyway), or update the docstring to call out that the pass-through only applies to plain-map test configs.

---

_Reviewed: 2026-04-29T17:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
