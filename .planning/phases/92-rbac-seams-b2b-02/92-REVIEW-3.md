---
phase: 92-rbac-seams-b2b-02
reviewed: 2026-04-29T22:30:00Z
depth: standard
files_reviewed: 19
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
  - priv/templates/sigra.install/organizations/live/organization_members_live.ex
  - guides/recipes/role-based-access-control.md
  - mix.exs
findings:
  blocker: 0
  warning: 6
  total: 6
status: issues_found
---

# Phase 92: Code Re-Review Report (round 3 — final pass)

**Reviewed:** 2026-04-29T22:30:00Z
**Depth:** standard
**Files Reviewed:** 19 (round-2 list + `priv/templates/.../live/organization_members_live.ex` now in scope)
**Status:** issues_found (no BLOCKERs; warnings are all carryover or minor follow-ups)

## Summary

The round-1 + round-2 BLOCKERs are all resolved cleanly. Phase 92 is shippable from a correctness/security standpoint.

**Round-1 BLOCKERs — VERIFIED FIXED:**

- **CR-01 (router pipeline):** `lib/sigra/install/features/core.ex:469-471` emits only `:require_org` (membership-presence-only). The dead `:require_org_owner` pipeline that hardcoded `[:owner]` and would have failed `RequireMembership.init/1` at boot for any custom-taxonomy host is gone. Comment block at lines 461-468 documents the rationale. ✓
- **CR-02 (invitation enum):** `priv/templates/sigra.install/organizations/organization_invitation.ex:44` now reads `field :role, Sigra.Ecto.Types.RoleAtom`, mirroring the membership template. The compile-time `Ecto.Enum, values: [:owner, :admin, :member]` literal is gone. ✓
- **CR-03 (invitation migration default):** Both Postgres branch (`migration.exs:63`) and MySQL/SQLite branch (`migration.exs:174`) emit plain `add :role, :string` — no `null: false`, no `default: "member"`. Mirrors the membership column shape. ✓
- **CR-04 (config invariants):** `Sigra.Organizations.__validate_config__!/1` now calls `validate_role_invariants!/1` after NimbleOptions validation (lines 256-308). Both `:owner_role ∈ :roles` and `:invitation_admin_roles ⊆ :roles` are enforced at `use Sigra.Organizations` compile time with actionable error messages. The empty-`roles: []` corner case is also caught because `owner_role in []` is false → the invariant raises. ✓

**Round-1 WARNING fixes — VERIFIED:**

- **WR-02 + WR-03:** `Sigra.Organizations.assert_role_in_universe!/3` (lib/sigra/organizations.ex:1346-1365) is wired into `add_member/5` (line 881) and `change_role/4` (line 1021). Refuses atoms outside `config.roles` with a programmer-error raise. Also defends against non-atom inputs via the second clause head. ✓

**Round-2 BLOCKER — VERIFIED FIXED:**

- **CR-2-01 (`Invitations.create/2` raise vs spec):** Lines 86-107 of `lib/sigra/organizations/invitations.ex` now use the non-raising `Sigra.Organizations.validate_role_in_universe/2` returning `{:error, :invalid_role}`, matching the documented `@spec` (line 77-85 includes `:invalid_role` in the error union). The role check is also positioned **after** `authorize_create/2` (line 96 → line 97), closing the 500-vs-401 information-disclosure window from round 2. The comment at lines 90-95 captures the rationale. ✓
- **WR-2-05 (LV taxonomy hardcoding — functional half):** `priv/templates/.../live/organization_members_live.ex` reads taxonomy from `Organizations.__sigra_org_config__()` at mount (lines 49-52). `safe_role_atom/2` (lines 708-721) and `safe_invite_role/2` (lines 671-676) accept the `available_roles` list and validate against it. `<select>` blocks in the invite (line 496) and change-role (line 565) modals iterate `@available_roles`. `humanize_role/1` (lines 743-749) is now a generic capitalizer that handles any host atom. The functional half of the WR-2-05 finding is closed. ✓

**`Sigra.Ecto.Types.RoleAtom` design — sound:**

`String.to_existing_atom/1` is the correct primitive here. Roles enter the BEAM atom table at compile time when the host's `use Sigra.Organizations, roles: [...]` macro runs — by the time a Repo query runs at runtime, every legitimate role atom exists. A row with a string that does not map to any existing atom is by definition a configuration drift event, and surfacing it as `Ecto.Type.LoadError` is the desired fail-closed behavior. The `cast/dump/load` symmetry is correct. The atom-and-not-nil guard on `cast/1` and `dump/1` handles nil round-trip cleanly for nullable columns. The test file `test/sigra/ecto/types/role_atom_test.exs` (verified to exist via REVIEW-2 scope notes) exercises atom round-trip, nil round-trip, and known-bad strings.

The only nuance — covered by REVIEW-2 and worth re-stating for the record — is that `cast(true)` and `cast(false)` succeed at the type layer (both are atoms) and rely on `assert_role_in_universe!/3` / `validate_role_in_universe/2` as the privilege gate. This is intentional and documented in the round-2 review's "Notes on the new `Sigra.Ecto.Types.RoleAtom`" section. No new finding here.

**`assert_role_in_universe!/3` (raising) vs `validate_role_in_universe/2` (tagged-tuple) split — correctly applied:**

| Call site | Variant | Rationale |
|---|---|---|
| `Sigra.Organizations.add_member/5` (line 881) | `assert_role_in_universe!/3` | Library-internal; non-universe atom is a programmer error (typo, stale taxonomy). Raise is appropriate. |
| `Sigra.Organizations.change_role/4` (line 1021) | `assert_role_in_universe!/3` | Same as above — library-internal API, no `@spec` committing to tagged-tuple errors for the bad-role case. |
| `Sigra.Organizations.Invitations.create/2` (line 97) | `validate_role_in_universe/2` | Request-handler-facing entry point. `@spec` documents `{:error, :invalid_role}`. Raising would 500 a controller for user-influenced inputs. |

The split matches the documented contract at each boundary. No new finding.

**One new minor regression-class finding (WR-3-06):** the LV form-reset in `handle_event("invite_member", ...)` still hardcodes `"role" => "member"` (line 228). Functionally inert (the `<select>` re-iterates `@available_roles` so the unmatched value falls through to the browser default) but inconsistent with the rest of the WR-2-05 fix and surfaces as a small follow-up.

The round-1 carryover WARNINGs (WR-01, WR-04, WR-05, WR-06, WR-07) and INFOs (IN-01, IN-02, IN-03) remain **unaddressed** but are still correctly classified as warnings — none have escalated to BLOCKER status. They are recorded below as WR-3-01..WR-3-05 for traceability.

Phase 92 ships with no BLOCKERs.

## Critical Issues

None.

## Warnings

### WR-3-01: `RequireMembership.init/1` rescue swallows unrelated `UndefinedFunctionError` — UNCHANGED (carries WR-01 / WR-2-01)

**File:** `lib/sigra/plug/require_membership.ex:113-131`
**Status:** Not addressed across rounds 1, 2, or 3.

The `try/rescue UndefinedFunctionError` block can mask exceptions raised from inside a host module's `__sigra_org_config__/0` body. A typo or an exception inside the host's overridden config function gets misreported as "module does not export __sigra_org_config__/0" — a confusing diagnostic for operators.

**Fix:** Gate on `function_exported?/2` (with `Code.ensure_loaded?/1` first) and call the function unprotected so genuine exceptions inside the host module surface with their real stack trace. Round-1 recommendation stands verbatim.

---

### WR-3-02: `set_mfa_policy/5` `if not ... do ..., else:` one-liner — UNCHANGED (carries WR-04 / WR-2-02)

**File:** `lib/sigra/organizations.ex:842`
**Status:** Not addressed.

```elixir
if not mfa_check_fn.(scope.user), do: {:error, :admin_must_enroll_first}, else: do_set_mfa_policy(config, scope, org, value)
```

Cosmetic / Credo-style. Refactor to the explicit positive-case `if/else` block. Same recommendation as rounds 1 and 2.

---

### WR-3-03: `accept_with_signup/3` audit step coupling — UNCHANGED (carries WR-05)

**File:** `lib/sigra/organizations/invitations.ex:638`
**Status:** Not addressed.

`register_opts = [changeset_fn: config.user_registration_changeset_fn]` does not thread `:audit_schema`, so `register_user_multi/2` does not append the `auth.register.success` audit step inside the accept-with-signup flow — preserving the Phase 17 contract that `organization.invitation.accepted` is the authoritative event. The brittle coupling remains: a future maintainer adding `audit_schema:` to `register_opts` would silently double-emit audit rows. The original recommendation (explicit comment + factor a `register_user_multi_no_audit/2`) still stands.

---

### WR-3-04: `list_organizations_for_user/1` wrapper return-type mismatch — UNCHANGED (carries WR-06 / WR-2-03)

**File:** `lib/sigra/organizations.ex:388-389`
**Status:** Not addressed.

The injected wrapper at lines 388-389:

```elixir
def list_organizations_for_user(user),
  do: Sigra.Organizations.list_organizations_with_roles_for_user(@sigra_org_config, user)
```

returns `[{org, role}]` while the same-named library function at line 1086 returns `[org]`. Same name, different shape. A host author following the function-name-implies-shape convention will mis-call the wrapper. Generated callers in the install templates already destructure `{org, role}`, so existing call sites work, but the trap remains for hosts that audit by reading the library function signatures.

**Fix:** Rename the injected wrapper to `list_organizations_with_roles_for_user/1` to match its delegate target. Update template call sites accordingly.

---

### WR-3-05: `purge_org_sessions/3` ordering coupling — UNCHANGED (carries WR-07 / WR-2-04)

**File:** `lib/sigra/organizations.ex:1475-1489`
**Status:** Not addressed (robustness-only finding from round 1; no behavior change in round 3).

The `:purge_org_sessions` Multi step is order-coupled to the `:membership` delete and reads `membership.user_id` / `membership.organization_id` from the in-memory struct. A future Multi refactor that re-orders these steps could expose a real ordering bug. Worth a regression test asserting the build order.

---

### WR-3-06: NEW — Invite-form reset in `OrganizationMembersLive` still hardcodes `"role" => "member"`

**File:** `priv/templates/sigra.install/organizations/live/organization_members_live.ex:228`
**Issue:** The WR-2-05 fix correctly removed hardcoded role atoms from `safe_role_atom/2`, `humanize_role/1`, role-iteration in the `<select>` blocks, and the form's initial mount value. But the success-path form reset inside `handle_event("invite_member", ...)` still hardcodes the literal string `"member"`:

```elixir
{:ok, invitation} ->
  {:noreply,
   socket
   |> put_flash(:info, "Invitation sent to #{invitation.email}.")
   |> stream_insert(:pending_invitations, invitation, at: 0)
   |> update(:pending_count, &(&1 + 1))
   |> assign(
     :invite_form,
     to_form(%{"email" => "", "role" => "member"}, as: :invitation)  # <- hardcoded
   )
   |> push_event("close-modal", %{id: "invite-member-modal"})}
```

For a host that customizes `roles: [:tenant_lead, :reviewer]`, after a successful invitation:

1. The form resets with `"role" => "member"` (a string not in the host's taxonomy).
2. The `<select>` re-renders iterating `@available_roles` — no `<option>` matches `"member"`.
3. The browser silently falls back to the first option (`:tenant_lead`).

Functional impact is **inert** — invitation submission still works because `safe_invite_role/2` falls back to `List.last(available_roles)` for unknown role strings. So this is **not a BLOCKER**. But it's inconsistent with the rest of the WR-2-05 fix (the mount path uses `default_invite_role = List.last(available_roles) |> to_string()` for exactly this reason) and a host doing UAT will see the form reset to a different default than the initial mount.

**Fix:** Reuse the same expression the mount path uses. Either inline:

```elixir
default_invite_role = List.last(socket.assigns.available_roles) |> to_string()
# ...
to_form(%{"email" => "", "role" => default_invite_role}, as: :invitation)
```

or factor a private helper:

```elixir
defp blank_invite_form(available_roles) do
  default_role = List.last(available_roles) |> to_string()
  to_form(%{"email" => "", "role" => default_role}, as: :invitation)
end
```

and call it from both the mount path (line 73) and the success-path reset (line 228). Same pattern is already in use at the `open_invite_modal` event (line 191) — so this is a one-line oversight, not a structural issue.

## Carryover summary

For traceability across all three review rounds:

| Finding | Round 1 | Round 2 | Round 3 |
|---|---|---|---|
| CR-01 router `:require_org_owner` | OPEN | FIXED | VERIFIED |
| CR-02 invitation enum literal | OPEN | FIXED | VERIFIED |
| CR-03 invitation migration default | OPEN | FIXED | VERIFIED |
| CR-04 config role invariants | OPEN | FIXED | VERIFIED |
| CR-2-01 `Invitations.create/2` raise vs spec | n/a | OPEN (new BLOCKER) | FIXED + VERIFIED |
| WR-01 `RequireMembership.init/1` rescue | OPEN | OPEN (WR-2-01) | OPEN (WR-3-01) |
| WR-02 membership changeset universe check | OPEN | FIXED at library layer | VERIFIED |
| WR-03 `add_member/5` / `change_role/4` universe check | OPEN | FIXED | VERIFIED |
| WR-04 `set_mfa_policy/5` `unless..else` | OPEN | OPEN (WR-2-02) | OPEN (WR-3-02) |
| WR-05 `accept_with_signup/3` audit step coupling | OPEN | OPEN | OPEN (WR-3-03) |
| WR-06 wrapper name vs delegate-target mismatch | OPEN | OPEN (WR-2-03) | OPEN (WR-3-04) |
| WR-07 `purge_org_sessions/3` ordering | OPEN | OPEN (WR-2-04) | OPEN (WR-3-05) |
| WR-2-05 LV taxonomy hardcoding (functional half) | n/a | OPEN (new) | FIXED + VERIFIED |
| WR-2-05 LV form-reset literal `"member"` | n/a | (subsumed) | OPEN (WR-3-06) |
| IN-01 mismatch branch telemetry | OPEN | OPEN | OPEN |
| IN-02 `require Logger` placement | OPEN | OPEN | OPEN |
| IN-03 `Sigra.Scope.from_config/2` doc accuracy | OPEN | partially scoped | OPEN |

## Notes on `Sigra.Ecto.Types.RoleAtom` (no findings, re-verified)

- `cast/1` for atoms accepts any non-nil atom and returns it unchanged. Booleans (`true`/`false`) are atoms and would pass the cast — they are caught downstream by `assert_role_in_universe!/3` / `validate_role_in_universe/2` in the universe-aware functions. The privilege gate is correctly placed at the call sites that need it, not at the type layer.
- `cast/1` for binaries uses `String.to_existing_atom/1`, which is correct given that legitimate role atoms are pre-loaded by `use Sigra.Organizations, roles: [...]`. Strings with no matching atom resolve to `:error`, blocking attacker-controlled atom-table exhaustion via untrusted form params.
- `load/1` is symmetric with `cast/1` for binaries — `String.to_existing_atom/1` with `:error` on miss. The docstring's claim that "configuration drift surfaces as `Ecto.Type.LoadError`" is correct.
- `dump/1` rejects bare strings (won't accidentally double-dump), only accepting atom or nil. Correct.

## Notes on the raising/tagged-tuple split (no findings, re-verified)

The split between `assert_role_in_universe!/3` and `validate_role_in_universe/2` is correctly applied:

- **`add_member/5` and `change_role/4`** are library-internal APIs whose `@spec` documents `{:error, term()}` for changeset / business-rule errors only. A non-universe role atom at these call sites is a **programmer error** (typo, stale taxonomy, attacker-controlled param that bypassed the controller's own check) — raising `ArgumentError` is the right posture. The first guard head accepts atoms; the second clause head catches non-atoms with a clear error.
- **`Invitations.create/2`** is a **request-handler-facing** entry point whose `@spec` (lines 77-85) explicitly documents `{:error, :invalid_role}` in the error union. Using `validate_role_in_universe/2` (returning `{:error, :invalid_role}`) preserves this contract so a controller passing user-influenced role params gets a clean changeset-style error response, not a 500.

The order in `Invitations.create/2` is also correct: `authorize_create/2` runs **before** `validate_role_in_universe/2`, so an unauthorized actor passing a non-universe role gets `{:error, :unauthorized}` (not a 500 distinguishing "unauthorized actor" from "authorized actor with bad role"). This closes the round-2 information-disclosure path.

## Notes on round-1 carryover findings (no behavior change)

WR-01, WR-04, WR-05, WR-06, WR-07, IN-01, IN-02, IN-03 are unchanged across all three review rounds. All remain correctly classified as warnings/info — none have escalated to BLOCKER status. They represent latent quality / robustness concerns that should be addressed in a follow-up phase but do not block Phase 92 from shipping.

## Notes on example-app drift (informational, not a finding)

`test/example/priv/repo/migrations/20260410125245_create_organizations.exs` may still carry the legacy `add(:role, :string, null: false, default: "member")` shape. The example app is a snapshot of a generated host, not the template — re-running `mix sigra.install` in `test/example/` would produce the new shape. This was flagged as informational in REVIEW-2 and remains the same: not a finding for Phase 92, but a candidate cleanup task for a follow-up phase to keep the example app in sync with the regenerated install_golden fixture.

---

_Reviewed: 2026-04-29T22:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
