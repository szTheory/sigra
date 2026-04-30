---
phase: 92-rbac-seams-b2b-02
reviewed: 2026-04-29T20:30:00Z
depth: standard
files_reviewed: 18
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
  - lib/sigra/ecto/types/role_atom.ex
  - priv/templates/sigra.install/core/sigra_authz.ex
  - priv/templates/sigra.install/core/scope.ex
  - priv/templates/sigra.install/organizations/organization_membership.ex
  - priv/templates/sigra.install/organizations/organization_invitation.ex
  - priv/templates/sigra.install/organizations/migration.exs
  - priv/templates/sigra.install/organizations/organizations.ex
  - guides/recipes/role-based-access-control.md
  - mix.exs
findings:
  blocker: 1
  warning: 5
  total: 6
status: issues_found
---

# Phase 92: Code Re-Review Report (round 2)

**Reviewed:** 2026-04-29T20:30:00Z
**Depth:** standard
**Files Reviewed:** 18 (1 added vs round 1: `lib/sigra/ecto/types/role_atom.ex`)
**Status:** issues_found

## Summary

The four original BLOCKERs are resolved cleanly:

- **CR-01 (router pipeline):** `:require_org_owner` removed from `core.ex`. Only `:require_org` (membership-presence-only) remains. Generator no longer leaks a hardcoded `:owner` taxonomy and no longer emits a router pipeline that would crash `RequireMembership.init/1` at boot. Verified.
- **CR-02 (invitation schema enum):** `priv/templates/.../organization_invitation.ex:44` now uses `field :role, Sigra.Ecto.Types.RoleAtom`, mirroring the membership template. Compile-time taxonomy literal is gone. Verified.
- **CR-03 (invitation migration default):** Both Postgres and MySQL/SQLite branches in `priv/templates/.../migration.exs` now emit plain `add :role, :string` (no `null: false`, no `default: "member"`). Mirrors the membership column shape per the Phase 92 contract. Verified.
- **CR-04 (config invariants):** `__validate_config__!/1` now calls `validate_role_invariants!/1` post-NimbleOptions validation. `:owner_role ∈ :roles` and `:invitation_admin_roles ⊆ :roles` are enforced at `use Sigra.Organizations` compile time with actionable error messages. Verified.
- **WR-02 + WR-03:** `Sigra.Organizations.assert_role_in_universe!/3` is wired into `add_member/5` (line 881), `change_role/4` (line 1021), and `Invitations.create/2` (line 88). Atoms outside the configured `:roles` universe are now refused. Verified.

The new `Sigra.Ecto.Types.RoleAtom` is well-designed — `String.to_existing_atom/1` is correct here because role atoms enter the BEAM at compile time via `use Sigra.Organizations` (verified: every `roles: [...]` literal in a host's compilation pre-loads its atoms). The cast/dump/load contract is sound and the test coverage in `test/sigra/ecto/types/role_atom_test.exs` exercises atom round-trip, nil round-trip, and known-bad inputs.

The fixes did, however, introduce one new BLOCKER and surface one previously-untouched template defect that breaks the same Phase 92 contract the round-1 fixes were meant to enforce.

The remaining round-1 WARNINGs and INFOs (WR-01, WR-04, WR-05, WR-06, WR-07, IN-01, IN-02, IN-03) are **all unaddressed** — confirmed not regressed but still open.

## Critical Issues

### CR-2-01: `Invitations.create/2` raises `ArgumentError` on out-of-universe role instead of returning `{:error, _}`, contradicting its `@spec`

**File:** `lib/sigra/organizations/invitations.ex:88`
**Issue:** The new role-universe guard is wired before the `with` chain:

```elixir
def create(config, %{actor: actor_scope} = attrs) do
  :ok = assert_secret_key_base!(config)
  :ok = Sigra.Organizations.__warn_long_invitation_ttl__(config)
  :ok = Sigra.Organizations.assert_role_in_universe!(attrs.role, config, :"Invitations.create")

  with :ok <- authorize_create(config, actor_scope),
       ...
```

Two compounding defects:

1. **Spec violation.** The `@spec create(map(), map()) :: {:ok, struct()} | {:error, ...}` (line 77-84) commits the function to a tagged-tuple return contract for every error case. `assert_role_in_universe!/3` raises `ArgumentError` on a non-universe role atom — there is no `{:error, :invalid_role}` shape in the spec, and existing callers (the generated `OrganizationMembersLive` and any host-written invitation controller) handle `{:error, ...}` returns, not exceptions. A controller that POSTs an invitation form with a role atom not in `config.roles` (a host that just demoted `:editor` from their `:roles` list, leaving stale form values in flight) will see a 500 instead of a clean changeset error.

2. **Authz ordering inversion.** The role-universe assert runs **before** `authorize_create/2`. An unauthenticated/unauthorized actor who passes a non-universe role string will trigger the raise (500) before the `{:error, :unauthorized}` path even gets a chance. This is a small information-disclosure window: 500 vs 401 lets a probe distinguish "unauthorized actor" from "authorized actor with bad role" without any credentials. Compare to `add_member/5` (line 881) and `change_role/4` (line 1021), where the `assert_role_in_universe!` call is correctly the first guard but those functions do NOT have a `@spec` committing to `{:error, _}` for the bad-role case (and are library-internal callers, not request handlers).

The two functions actually ship different contracts:
- `add_member/5` and `change_role/4` are programmer-error-on-typo APIs that rightfully raise.
- `Invitations.create/2` is a **request-handler-facing** API whose `@spec` documents tagged tuples.

`assert_role_in_universe!/3` was applied uniformly without distinguishing the two. The safer move for `Invitations.create/2` is to convert the universe check into a `{:error, :invalid_role}` (or fold it into the changeset as a `validate_inclusion`), preserving the documented return contract.

**Fix:**

Option A (smallest diff — match the existing return contract):

```elixir
def create(config, %{actor: actor_scope} = attrs) do
  :ok = assert_secret_key_base!(config)
  :ok = Sigra.Organizations.__warn_long_invitation_ttl__(config)

  with :ok <- assert_role_in_universe(attrs.role, config),
       :ok <- authorize_create(config, actor_scope),
       :ok <- check_user_rate_limit(config, attrs.invited_by_id),
       :ok <- check_org_rate_limit(config, attrs.organization_id),
       {:ok, result} <- do_create(config, attrs) do
    deliver_invitation_email_async(config, result)
    {:ok, result.invitation |> Map.put(:__encoded_token__, result.encoded_token)}
  end
end

defp assert_role_in_universe(role, %{roles: roles}) when is_atom(role) do
  if role in roles, do: :ok, else: {:error, :invalid_role}
end

defp assert_role_in_universe(_role, _config), do: {:error, :invalid_role}
```

Update `@spec` to add `:invalid_role` to the error union and document it in the docstring's error-case enumeration.

Option B (keep the bang helper but only call it from the truly-internal callers): leave `add_member/5` and `change_role/4` calling `assert_role_in_universe!/3` (they're library-internal and a typo IS a programmer error there), and replace the `Invitations.create/2` call with the soft-error variant above.

Either way the request-handler boundary should not raise on user-influenced inputs.

## Warnings

### WR-2-01: WR-01 (`RequireMembership.init/1` rescue swallows unrelated `UndefinedFunctionError`) — UNCHANGED

**File:** `lib/sigra/plug/require_membership.ex:113-131`
**Status:** Not addressed in the fix series. Original recommendation was to swap the `try/rescue UndefinedFunctionError` for an explicit `function_exported?/2` check so that crashes inside a host module's `__sigra_org_config__/0` body do not get misreported as "module does not export __sigra_org_config__/0." The current code still uses the broad rescue.

**Fix:** As recommended in round 1 — gate on `function_exported?(module, :__sigra_org_config__, 0)` (with `Code.ensure_loaded?/1` first to handle plug-init-time-before-module-loaded scenarios), then call the function unprotected.

---

### WR-2-02: WR-04 (`set_mfa_policy/5` `if not ... do ..., else:` one-liner) — UNCHANGED

**File:** `lib/sigra/organizations.ex:842`
**Status:** Not addressed. Line 842 still reads:

```elixir
if not mfa_check_fn.(scope.user), do: {:error, :admin_must_enroll_first}, else: do_set_mfa_policy(config, scope, org, value)
```

Cosmetic / Credo-style. Refactor to the explicit positive-case `if` form per round-1 recommendation.

---

### WR-2-03: WR-06 (`list_organizations_for_user/1` wrapper has misleading return type) — UNCHANGED

**File:** `lib/sigra/organizations.ex:388-389`
**Status:** Not addressed. The `__using__`-injected wrapper named `list_organizations_for_user/1` still delegates to `Sigra.Organizations.list_organizations_with_roles_for_user/2` — i.e., the wrapper returns `[{org, role}]` while the **library function with the matching name** at line 1086 returns `[org]`. This is the same name-shape mismatch flagged in round 1. The generated callers (`organization_switch_controller.ex:75-80`, `impersonation_controller.ex:106-107`, `live/organizations_live/index.ex:27`) do destructure `{org, role}` correctly, but a host author following the function-name-implies-shape convention will mis-call the wrapper.

**Fix:** Rename the injected wrapper to `list_organizations_with_roles_for_user/1` to match the library function it actually delegates to. Update the four template call sites (`organization_switch_controller.ex`, `impersonation_controller.ex`, `live/organizations_live/index.ex`, `core/user_auth.ex` and the `assign_user_organizations` on_mount) to call the new name.

---

### WR-2-04: WR-07 (`purge_org_sessions/3` ordering coupling) — UNCHANGED

**File:** `lib/sigra/organizations.ex:1462-1476`
**Status:** Not addressed. Robustness-only finding from round 1 — no behavior change here, but the `:purge_org_sessions` Multi step is still ordered-coupled to the `:membership` delete and reads `membership.user_id` / `membership.organization_id` from the in-memory struct rather than re-querying. Worth a regression test asserting the Multi build order; otherwise unchanged.

---

### WR-2-05: NEW — Generated `OrganizationMembersLive.safe_role_atom/1` hardcodes `[:owner | :admin | :member]`, breaking custom-taxonomy hosts

**File:** `priv/templates/sigra.install/organizations/live/organization_members_live.ex:668-682`
**Issue:** This file is **out of the explicit re-review file list** but is the same class of defect the round-1 CR-01 fix targeted, and it slipped through. The generated LiveView template hard-codes role atom decoding:

```elixir
defp safe_role_atom("owner"), do: {:ok, :owner}
defp safe_role_atom("admin"), do: {:ok, :admin}
defp safe_role_atom("member"), do: {:ok, :member}
defp safe_role_atom(_other), do: {:error, :invalid_role}

defp role_badge_class(:owner), do: "badge-primary"
defp role_badge_class(:admin), do: "badge-neutral"
defp role_badge_class(:member), do: "badge-ghost"
defp role_badge_class(_), do: "badge-ghost"

defp humanize_role(:owner), do: "Owner"
defp humanize_role(:admin), do: "Admin"
defp humanize_role(:member), do: "Member"
defp humanize_role(other), do: other |> to_string() |> String.capitalize()
```

This is the exact pattern Phase 92 deletes from the library: a generated host file pinning `[:owner, :admin, :member]` as if those were the canonical role atoms. A host that customizes `roles: [:tenant_lead, :reviewer]` (the Phase 92 contract — see `guides/recipes/role-based-access-control.md:206`) will see:

1. Every `phx-submit="change_role"` event return `{:error, :invalid_role}` from the LV handler because no `safe_role_atom("tenant_lead")` clause matches. Role changes are completely broken in the UI.
2. Role badges render as `"Tenant_lead"` (default `humanize_role(other)` clause) and use the `badge-ghost` fallback class — minor cosmetic regression.

The first effect is functional, not cosmetic: the generated members-management LiveView is broken for any host that exercises the Phase 92 contract.

This was not included in the round-1 review file list and is therefore not a "regression introduced by the fix" — but it's the same architectural defect class (generated code leaking the canonical taxonomy), and it directly contradicts the Phase 92 promise enforced by every other fix in this series. Surfacing as WARNING because (a) the file is not in the strict re-review scope, and (b) the LV template carries multiple display-formatter functions (`role_badge_class`, `humanize_role`) that are reasonable defaults for the starter `:owner|:admin|:member` taxonomy and only become functional bugs when the host customizes.

**Fix:** Two pieces:

1. **Functional (must fix):** Replace `safe_role_atom/1` with a host-config-driven validator. Either:
   - Use `Sigra.Ecto.Types.RoleAtom.cast/1` directly (the new type's contract is exactly this — string-to-existing-atom with rejection of unknown atoms), then cross-check against `MyApp.Organizations.__sigra_org_config__().roles`.
   - Or: at install time, codegen the `safe_role_atom/1` clauses from the host's configured `roles:` list (parallel to the way the migration emits the host-owned column shape).

2. **Cosmetic (should fix):** `role_badge_class/1` and `humanize_role/1` need a TODO comment pointing hosts at `guides/recipes/role-based-access-control.md` for taxonomy customization, OR factor a host-overridable `humanize_role/1` callback so the host edits it once.

## Carryover summary (round-1 findings status)

For traceability against the original review:

| Round-1 Finding | Status |
|---|---|
| CR-01 router `:require_org_owner` | **FIXED** (commit c9ed1e5) |
| CR-02 invitation enum literal | **FIXED** (commit 4f9ae66) |
| CR-03 invitation migration default | **FIXED** (commit 3589e70) |
| CR-04 config role invariants | **FIXED** (commit 1237276) |
| WR-01 `RequireMembership.init/1` rescue breadth | **OPEN** (see WR-2-01) |
| WR-02 membership changeset universe check | **FIXED** at library layer via `assert_role_in_universe!/3` (commit 1237276) |
| WR-03 `add_member/5` / `change_role/4` universe check | **FIXED** (commit 1237276) |
| WR-04 `set_mfa_policy/5` `unless..else` | **OPEN** (see WR-2-02) |
| WR-05 `accept_with_signup/3` audit step coupling | **OPEN** (no related diff in round 2) |
| WR-06 wrapper name vs delegate-target mismatch | **OPEN** (see WR-2-03) |
| WR-07 `purge_org_sessions/3` ordering | **OPEN** (see WR-2-04) |
| IN-01 mismatch branch telemetry | **OPEN** (no related diff) |
| IN-02 `require Logger` placement | **OPEN** (no related diff) |
| IN-03 `Sigra.Scope.from_config/2` doc accuracy | **OPEN** (no related diff) — note: `Sigra.Scope` does carry `:role` and `:actor_type` now via Plan 92-03; the related concern is now scoped only to `:actor_type` since `:role` is part of the public contract |

## Notes on the new `Sigra.Ecto.Types.RoleAtom` (no findings)

The new type is correctly constrained:

- `cast/1` for atoms accepts only non-nil atoms. Booleans (`true`, `false`) are atoms and pass cast — they are caught downstream by `assert_role_in_universe!/3` in the universe-aware functions, so this is safe in practice. Worth a docstring note that "any non-nil atom round-trips at the cast layer; the universe check is the privilege gate" so future maintainers don't move the universe check.
- `cast/1` for binaries uses `String.to_existing_atom/1` which is the right call: roles enter the BEAM at compile time via `use Sigra.Organizations, roles: [...]` (verified — the `@org_config_schema` validates the keyword list which forces atom literal evaluation). A string with no matching atom resolves to `:error`, blocking attacker-controlled atom-table exhaustion.
- `load/1` is symmetric with `cast/1` for binaries — `String.to_existing_atom/1` with `:error` on miss. The docstring's claim that "configuration drift surfaces as `Ecto.Type.LoadError`" is correct.
- `dump/1` rejects bare strings (won't accidentally double-dump). Good.
- The test file at `test/sigra/ecto/types/role_atom_test.exs` exercises atom round-trip, nil round-trip, and unknown-string rejection both at cast and load. Coverage is appropriate.

No findings on this type.

## Notes on example-app drift (informational, not a finding)

`test/example/priv/repo/migrations/20260410125245_create_organizations.exs:23,40` still has `add(:role, :string, null: false, default: "member")` for both `organization_memberships` and `organization_invitations`. This is a pre-existing fixture migration and was not regenerated alongside the CR-03 template fix. The example app is a snapshot of a generated host, not the template — re-running the install in `test/example/` would produce the new shape. This is consistent with how the example app has been versioned historically (pinned snapshot) and is not a bug per se, but if the install_golden fixture got regenerated (commit a70acca) and the example app didn't, that's a drift that warrants explicit reconciliation in a follow-up phase. Not a finding.

---

_Reviewed: 2026-04-29T20:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
