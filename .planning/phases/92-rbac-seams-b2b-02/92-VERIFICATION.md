---
phase: 92-rbac-seams-b2b-02
verified: 2026-04-30T15:02:07Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
---

# Phase 92: RBAC Seams (B2B-02) Verification Report

**Phase Goal:** Hosts can implement opinionated RBAC without reverse-engineering Sigra; Sigra ships zero opinionated roles. After this phase, the path from "I want owner / admin / member" to working enforcement is one schema field plus one `Sigra.Authz` impl plus a documented recipe — and the library remains role-agnostic.

**Verified:** 2026-04-30T15:02:07Z
**Status:** passed
**Re-verification:** No — initial verification (prior run was interrupted before producing an artifact; restart from scratch)

## Goal Achievement

### Observable Truths (ROADMAP success criteria + plan must-haves)

| #   | Truth   | Status     | Evidence       |
| --- | ------- | ---------- | -------------- |
| SC1 | Fresh `mix sigra.install` host gets nullable `role :string` on memberships, a generated `Authz` module implementing `Sigra.Authz` with no-op `can?/3 -> true`, wired through generated config | VERIFIED | `priv/templates/sigra.install/organizations/migration.exs:43,158` (`add :role, :string` plain, no `null: false`, no default). `priv/templates/sigra.install/core/sigra_authz.ex:1-53` defines `<%= app_module %>.SigraAuthz` with `@behaviour Sigra.Authz` and `def can?(action, subject, scope), do: ... true`. Registered in `lib/sigra/install/features/core.ex:193`. Generated `priv/templates/sigra.install/organizations/organizations.ex:33-45` emits explicit `roles: [:owner, :admin, :member], owner_role: :owner, invitation_admin_roles: [:owner, :admin]` in the host wrapper (host-owned, edit-to-customize). |
| SC2 | `current_scope.role` populated when scope is org-active w/ role; nil on no-membership-role / no-org / nil-user / stale-pointer / clear branches | VERIFIED | `lib/sigra/scope/hydration.ex:99-117` — happy path writes `Map.get(membership, :role)`. `:81-83` no-active-org returns scope unchanged. `:85-92` nil-user returns scope unchanged. `:101` `:not_a_member` returns error tuple (no scope mutation). `:120-122` `:org_not_found` returns error tuple. `lib/sigra/plug/put_active_organization.ex:96-104` clear path explicitly sets `:role` to nil; `:130-138` set path writes role from membership. `lib/sigra/plug/fetch_session.ex` and `fetch_bearer.ex` do NOT touch `:role` (verified via grep: zero matches). |
| SC3 | RBAC recipe walks adopter from generated allow-all stub to host-owned `owner/admin/member` deny-by-default; ships in published docs; mix docs warnings-as-errors clean | VERIFIED | `guides/recipes/role-based-access-control.md` exists (252 lines). Section headers `# Role-Based Access Control`, `## What Sigra ships`, `## The generated allow-all starter`, `## Replace the starter with deny-by-default`, `## Calling can?/3 from controllers and LiveViews`, `## How the scope role gets populated`, `## Testing your policy`, `## Customizing the role taxonomy`. Registered in `mix.exs:204` under `extras:`. `test/sigra/guides_dx02_test.exs` passes (verified — 14/14 tests green in spot-check run incl. golden_diff). |
| SC4 | `golden_diff_test.exs` is stable against the extended `Authz` template; `authz_test.exs` exercises the behaviour contract role-agnostically | VERIFIED | Spot-check run: `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs test/sigra/guides_dx02_test.exs` → 14/14 pass in 60.4s. Golden snapshot `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/sigra_authz.ex` matches template (allow-all `can?/3`). Golden membership snapshot at `accounts/organization_membership.ex:45` has `field :role, Sigra.Ecto.Types.RoleAtom`. Golden migration `priv/repo/migrations/TIMESTAMP_create_organizations.exs:43,63` has plain `add :role, :string`. `test/sigra/authz_test.exs` exists and passed in spot-check (43/43 in core suite). |
| SC5 | Library ships no opinionated roles — no `:owner / :admin / :member` constants in `lib/sigra/`; recipe is the only place those names appear, illustratively | VERIFIED | `grep -rn ':owner\|:admin\|:member' lib/sigra/` reviewed line-by-line: every match is one of (a) module-attribute key for an unrelated namespace (`:admin_token`, `:admin_session`, `:admin_org_ids`, `:membership` field, `:admin_must_enroll_first` error), (b) historical-reference docstring naming `:owner` only to explain that the library "no longer defaults to it" (`organizations.ex:85`, `:269-287`), or (c) a doc-comment example in `lib/sigra/ecto/types/role_atom.ex:10` showing `[:owner, :admin]` as illustrative call-site shape. Zero default values: `grep -rn 'default:.*\[:owner\|default:.*:owner\|default:.*:admin\|default:.*:member' lib/sigra/` returns no matches. Zero residual module attributes: `grep -n '@default_admin_roles\|@default_role_universe\|@auth_roles' lib/sigra/{admin/policy,organizations,organizations/invitations,plug/require_membership}.ex` returns no matches. `Sigra.Organizations.__config_schema__/0` declares `roles` and `owner_role` as `required: true` with no `default:` (`lib/sigra/organizations.ex:68-88`). |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `lib/sigra/authz.ex` | Behaviour module with single `can?/3` callback, no built-in policy helpers | VERIFIED | 102 lines. `@callback can?(action, subject, scope) :: boolean()` at :101. No allow-all/deny-all defaults. Moduledoc explicitly states "library does not ship a default `can?/3` implementation" / "library does not ship `allow?/3`, `deny?/3`, or any other pre-baked policy helper". |
| `lib/sigra/admin/policy.ex` | Explicit-only `admin_org_ids_from_memberships/2` requiring `:roles` opt; KeyError on missing | VERIFIED | `:54-101` reads `roles = fetch_roles!(opts)`, `fetch_roles!/1` (`:76-101`) raises `KeyError` with actionable message when `:roles` is omitted, `ArgumentError` when malformed. No fallback role list anywhere. |
| `lib/sigra/organizations.ex` | `roles` and `owner_role` are `required: true`; no library defaults; `assert_role_in_universe!/3` and `validate_role_in_universe/2` enforce host-supplied universe at consumer call sites | VERIFIED | `:68-88` both options `required: true`, no `default:`. `__validate_config__!/1` (`:269-287`) enforces `:owner_role ∈ :roles` invariant at compile time. `assert_role_in_universe!/3` (CR-2-01 + WR-3 review) wired into `add_member/5` and `change_role/4`. |
| `lib/sigra/plug/require_membership.ex` | No canonical fallback role universe; reads from host's `__sigra_org_config__/0`; raises actionable `ArgumentError` when `:organizations` missing while `:roles` non-empty | VERIFIED | `:103-133` `resolve_role_universe!/1` requires `:organizations` option whenever `:roles` non-empty. No `@default_role_universe` constant (verified via grep). |
| `lib/sigra/organizations/invitations.ex` | Uses host-supplied `:invitation_admin_roles`; non-raising `validate_role_in_universe/2` matching `@spec`; ordering `authorize → role-validate` to close info-disclosure path | VERIFIED | `:96-100`: `with :ok <- authorize_create(...) :ok <- validate_role_in_universe(attrs.role, config) ...`. CR-2-01 fix landed in commit `3250f14`. `:131-141` `fetch_invitation_admin_roles!/1` reads from config with actionable raise when missing. |
| `lib/sigra/scope.ex` | `build/3`, `from_opts/2`, `from_config/2` accept additive `:role` and `:actor_type`; struct/2 reflection keeps it backward-compatible | VERIFIED | `:42-55` `build/3` passes both fields via `Keyword.get/2`. `:81-93` `from_opts/2` threads them. `:108-123` `from_config/2` threads them. Worker-scope warnings retained (`:9-13`, `:34-37`). |
| `lib/sigra/scope/hydration.ex` | Happy-path org hydration writes `membership.role` to `scope.role`; nil/stale/missing branches don't propagate role | VERIFIED | `:111-117` happy path writes role. `:81-83` no-active-org returns `{:ok, scope}` (role untouched). `:85-92` nil-user returns `{:ok, scope}`. Error tuples never carry a role. |
| `lib/sigra/plug/put_active_organization.ex` | Single authoritative library write seam for `:role` on active-org transitions; clear → nil; set → membership.role | VERIFIED | `:88-112` clear path: `Map.put(:role, nil)` after host scope_module callback. `:114-147` set path: `Map.put(:role, Map.get(membership, :role))` after host scope_module callback + membership re-validation. |
| `priv/templates/sigra.install/core/sigra_authz.ex` | Host-owned generated stub implementing `Sigra.Authz` with `can?/3 -> true` | VERIFIED | 53 lines. `:42 @behaviour Sigra.Authz`. `:44-52 def can?(action, subject, scope), do: ... true` (allow-all starter). Moduledoc explicitly frames it as host-owned with TODO directing to Plan 92-04 recipe. |
| `priv/templates/sigra.install/core/scope.ex` | `:role` and `:actor_type` reserved on the scope struct (both `nil` by default); `@type` declares both `atom() | nil` | VERIFIED | `:40-45` `defstruct ... role: nil, actor_type: nil`. `:47-59` `@type t :: %__MODULE__{... role: atom() | nil, actor_type: atom() | nil}`. Comment block explicitly marks `:actor_type` as Phase 93 prep, must stay nil under Phase 92. |
| `priv/templates/sigra.install/organizations/organization_membership.ex` | Nullable role field via `Sigra.Ecto.Types.RoleAtom`; no `Ecto.Enum` literal | VERIFIED | `:45 field :role, Sigra.Ecto.Types.RoleAtom`. Plan moduledoc explicitly notes "the generator no longer hard-codes `:owner / :admin / :member` as the role taxonomy". Changeset (`:62-69`) does NOT validate inclusion (host adds it if desired); only FK fields required. |
| `priv/templates/sigra.install/organizations/organization_invitation.ex` | Mirrors membership template — `RoleAtom` field, no `Ecto.Enum` | VERIFIED | `:44 field :role, Sigra.Ecto.Types.RoleAtom`. Mirrors membership shape per CR-02 fix. |
| `priv/templates/sigra.install/organizations/migration.exs` | Both Postgres and MySQL/SQLite branches: `add :role, :string` plain, no `null: false`, no `default: "member"` | VERIFIED | `:43` Postgres membership: `add :role, :string`. `:63` Postgres invitation: same. `:158` MySQL/SQLite membership: same. `:174` MySQL/SQLite invitation: same. CR-03 fix verified. |
| `priv/templates/sigra.install/organizations/organizations.ex` | Generated wrapper passes explicit `roles:`, `owner_role:`, `invitation_admin_roles:` to `use Sigra.Organizations` | VERIFIED | `:33-45` `use Sigra.Organizations, ... roles: [:owner, :admin, :member], owner_role: :owner, invitation_admin_roles: [:owner, :admin], audit_schema: ...`. Comment block at `:27-32` explicitly frames the values as host-owned starter, edit-to-customize. |
| `priv/templates/sigra.install/core/user_auth.ex` | Plug + LiveView paths both flow through `Sigra.Scope.Hydration.hydrate/3` for parity | VERIFIED | `:235 |> hydrate_scope(session)`. `:246-250 defp hydrate_scope(scope, session) do ... case Sigra.Scope.Hydration.hydrate(scope, org_config, session)`. Same shared seam used in plug + on_mount. |
| `priv/templates/sigra.install/organizations/live/organization_members_live.ex` | Taxonomy-agnostic — reads roles/admin-roles from `__sigra_org_config__()`, validates form input via `String.to_existing_atom/1` against `available_roles`, success-path form reset uses configured default | VERIFIED | `:49-52` reads config. `:710-723` `safe_role_atom/2` and `:673-678` `safe_invite_role/2` validate against `available_roles`. `:221` success-path reset: `default_role = List.last(available_roles) |> to_string()` (WR-3-06 fix, commit `01a52d8`). `:660-665` `can_manage_members?/2` reads from `invitation_admin_roles`. Role-badge styling clauses (`:735-737`) hardcode `:owner/:admin/:member` BUT (a) they're in generated host code (not lib/sigra/), (b) explicit comment instructs hosts to "Edit these clauses to match your `roles:` taxonomy", (c) safe fallback `defp role_badge_class(_other), do: "badge-ghost"` keeps unknown atoms rendering — taxonomy-agnostic at the structural/functional level. |
| `guides/recipes/role-based-access-control.md` | Published recipe walking allow-all → deny-by-default | VERIFIED | 252 lines, structured. Sections demonstrate the path. Concrete role atoms `:owner / :admin / :member` framed explicitly as host-owned examples (per 92-04-SUMMARY decision record). |
| `mix.exs` | Recipe registered under ExDoc extras Recipes group | VERIFIED | `:204 "guides/recipes/role-based-access-control.md"`. `:213 Recipes: ~r{guides/recipes/.?}`. |
| `test/sigra/authz_test.exs` | Behaviour contract regression coverage role-agnostic | VERIFIED | File exists. Included in spot-check run — passed (43 tests across the bundle, zero failures). |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/sigra_authz.ex` | Golden snapshot matching template | VERIFIED | Snapshot present, `@behaviour Sigra.Authz` at `:42`, `def can?/3` returning `true`. Regenerated by commit `a70acca`. |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/organization_membership.ex` | Golden snapshot for nullable role storage via `RoleAtom` | VERIFIED | `:45 field :role, Sigra.Ecto.Types.RoleAtom`. Snapshot in lockstep with template. |
| `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_organizations.exs` | Golden migration — plain `add :role, :string` for both memberships and invitations | VERIFIED | `:43` and `:63` both `add :role, :string`. |

### Key Link Verification

| From | To  | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| `lib/sigra/install/features/core.ex` | `priv/templates/sigra.install/core/sigra_authz.ex` | `feature files/1` registration | WIRED | `core.ex:193 {:eex, "core/sigra_authz.ex", Path.join(["lib", otp_app, "sigra_authz.ex"])}` |
| `lib/sigra/scope/hydration.ex` | `priv/templates/sigra.install/core/user_auth.ex` | `Sigra.Scope.Hydration.hydrate/3` | WIRED | `user_auth.ex:249 case Sigra.Scope.Hydration.hydrate(scope, org_config, session)`. Plug + LiveView paths share the same seam (parity preserved). |
| `lib/sigra/plug/put_active_organization.ex` | host scope_module's `put_active_organization/3` + `:role` write | single authoritative write seam | WIRED | `put_active_organization.ex:101-104` (clear) and `:135-138` (set) call `scope_module.put_active_organization/3` then `Map.put(:role, ...)`. The host scope module remains role-agnostic — library applies the role write afterwards. |
| `lib/sigra/organizations.ex` | `lib/sigra/plug/require_membership.ex` | shared configured role universe via `__sigra_org_config__/0` | WIRED | `require_membership.ex:103-133` reads `module.__sigra_org_config__()` and threads `:roles` from there. No library-side default. |
| `mix.exs` | `guides/recipes/role-based-access-control.md` | docs extras | WIRED | `mix.exs:204` registers under extras list; `:213` groups under Recipes. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `lib/sigra/scope/hydration.ex` | `scope.role` | `Map.get(membership, :role)` from `Sigra.Organizations.get_membership/3` | YES — real DB read | FLOWING |
| `lib/sigra/plug/put_active_organization.ex` | `scope.role` | `Map.get(membership, :role)` after `Organizations.get_membership/3` re-validation | YES — real DB read with auth check | FLOWING |
| Generated `<App>.SigraAuthz.can?/3` | (passes through) returns `true` | starter literal | INTENTIONAL ALLOW-ALL — documented behavior matching ROADMAP SC1 | FLOWING (by-design) |
| `priv/templates/.../organization_members_live.ex` `available_roles` | `config.roles` | `Organizations.__sigra_org_config__()` at mount | YES — host wrapper compile-time data | FLOWING |

Allow-all `can?/3` is the SC1-mandated behavior — Plan 92-04 recipe shows the deny-by-default hardening path.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Library + scope behaviour contract tests pass | `MIX_ENV=test mix test test/sigra/authz_test.exs test/sigra/scope/build_test.exs test/sigra/scope/hydration_test.exs test/sigra/install/scope_template_fields_test.exs test/sigra/install/scope_template_invariants_test.exs` | 43 tests, 0 failures | PASS |
| Active-org transition + parity + require-membership | `MIX_ENV=test mix test test/sigra/plug/put_active_organization_test.exs test/sigra/scope/plug_liveview_parity_test.exs test/sigra/plug/require_membership_test.exs` | 30 tests, 0 failures | PASS |
| Golden diff + DX-02 guides parity | `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs test/sigra/guides_dx02_test.exs` | 14 tests, 0 failures (60.4s — golden regen + 17.9 min reading estimate computed) | PASS |
| No role-default residue in library RBAC seam files | `grep -n '@default_admin_roles\|@default_role_universe\|@auth_roles' lib/sigra/{admin/policy,organizations,organizations/invitations,plug/require_membership}.ex` | (no output) | PASS |
| No role-list / role-value defaults in `lib/sigra/` | `grep -rn 'default:.*\[:owner\|default:.*:owner\|default:.*:admin\|default:.*:member' lib/sigra/` | (no output) | PASS |
| Generator emits sigra_authz template | `grep -n sigra_authz lib/sigra/install/features/core.ex` | `:193 {:eex, "core/sigra_authz.ex", ...}` | PASS |
| Recipe registered with ExDoc | `grep -n role-based-access mix.exs` | `:204` matches | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| B2B-02 | 92-01, 92-02, 92-03, 92-04 | Generated host receives a `role` field on `OrganizationMembership`, a `Sigra.Authz` `can?/3` behaviour, scope-struct `:role` propagation, and a recipe doc demonstrating role-based policy implementation — without the library shipping any opinionated roles | SATISFIED | All four pillars verified across the artifacts above. Library ships only the `Sigra.Authz` seam (102 lines, single callback). Generated host gets nullable `:role` column (migration), `RoleAtom` field (membership + invitation schemas), `<App>.SigraAuthz` allow-all starter, reserved `:role`/`:actor_type` scope fields, and explicit `roles:`/`owner_role:`/`invitation_admin_roles:` wrapper config. Runtime propagation flows through `Sigra.Scope.Hydration.hydrate/3` and `Sigra.Plug.PutActiveOrganization` only — `FetchSession`/`FetchBearer` confirmed untouched. RBAC recipe published, registered, and walks adopters from allow-all → deny-by-default. |

No orphaned requirements: REQUIREMENTS.md maps only B2B-02 to Phase 92, and all four plans declare it.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `priv/templates/sigra.install/organizations/live/organization_members_live.ex` | 735-737 | Generated host LV hardcodes role-badge styling for `:owner / :admin / :member` | INFO | Lives in generated host code, not `lib/sigra/`. Explicit comment block (`:725-734`) instructs hosts to edit clauses to match their taxonomy. Safe fallback `defp role_badge_class(_other), do: "badge-ghost"` keeps unknown atoms rendering. ROADMAP SC5 prohibits literals in `lib/sigra/` only — this file is `priv/templates/`. Functional taxonomy-agnosticism is preserved (verified by inspection of the surrounding helpers). Acceptable as a styling starter that the recipe customizes. |
| `lib/sigra/organizations.ex` | 1346-1365 (carried) / 842 (carried) | WR-3-02 `set_mfa_policy/5` `if not ... do ..., else:` one-liner; WR-3-04 `list_organizations_for_user/1` wrapper return-type mismatch with same-named library function | INFO | Both are carryover advisory WARNINGs from REVIEW-3, correctly classified as non-blocking robustness/cosmetic items. Not Phase 92 regressions. |
| `lib/sigra/plug/require_membership.ex` | 113-131 (carried) | WR-3-01 `init/1` `try/rescue UndefinedFunctionError` may mask exceptions inside host's `__sigra_org_config__/0` body | INFO | Carryover advisory WARNING from REVIEW-1 → 2 → 3. Non-blocking — failure mode is operator diagnostic clarity, not security/correctness. |
| `lib/sigra/organizations/invitations.ex` | 638 (carried) | WR-3-03 `accept_with_signup/3` audit step coupling — register_opts does not thread `:audit_schema` to keep accept-flow audit single-evented | INFO | Documented carryover from REVIEW-1, correctly preserves Phase 17 contract. |
| `lib/sigra/organizations.ex` | 1475-1489 (carried) | WR-3-05 `purge_org_sessions/3` Multi-step ordering coupling | INFO | Carryover; robustness-only finding with no functional regression. |

All findings are advisory-class and explicitly documented in REVIEW-3 carryover. None block the Phase 92 goal.

### Human Verification Required

None. The phase goal is realized via taxonomy-agnostic code paths that are fully exercised by the existing automated suites:

- `test/sigra/authz_test.exs` exercises the `Sigra.Authz` behaviour contract role-agnostically.
- `test/sigra/scope/hydration_test.exs` and `test/sigra/scope/plug_liveview_parity_test.exs` exercise `current_scope.role` propagation across happy/clear/stale/nil-user branches and assert plug ↔ on_mount parity.
- `test/sigra/plug/put_active_organization_test.exs` exercises set/clear role-write semantics.
- `test/sigra/install/golden_diff_test.exs` byte-locks the regenerated install fixture (sigra_authz.ex, accounts/organization_membership.ex, scope.ex, migration role columns).
- `test/sigra/guides_dx02_test.exs` enforces structural existence + Sigra-API reference accuracy in the new recipe.
- `mix docs --warnings-as-errors` enforces recipe doc quality (Plan 92-04 verification gate).

The Phase 92 contract is verifiable end-to-end without human spot checks; visual / UX behavior of the generated `OrganizationMembersLive` (badge styling, form ergonomics) is host-customizable starter material, not a Phase 92 contract surface.

### Gaps Summary

No goal-blocking gaps.

Phase 92 ships a clean RBAC seam:

1. **Library is taxonomy-agnostic.** `lib/sigra/authz.ex` exposes a single `can?/3` callback with no built-in policy. `Sigra.Admin.Policy.admin_org_ids_from_memberships/2` requires explicit `:roles` (KeyError on omit). `Sigra.Organizations.__config_schema__/0` declares `roles` and `owner_role` as `required: true` with no defaults. `Sigra.Plug.RequireMembership` reads role universes from `__sigra_org_config__/0` only — no canonical fallback. `Sigra.Organizations.Invitations.create/2` validates roles via tagged-tuple `validate_role_in_universe/2` matching its `@spec`, ordered after `authorize_create/2` to close the info-disclosure path. Module attributes `@default_admin_roles`, `@default_role_universe`, `@auth_roles` are gone. No `:owner / :admin / :member` literals as values in `lib/sigra/` — only documentation references and a single illustrative call-site example in `RoleAtom`'s moduledoc.

2. **Generator emits a clean RBAC contract.** The host gets `<App>.SigraAuthz` with `@behaviour Sigra.Authz` and an allow-all `can?/3` starter (matches ROADMAP SC1). Membership and invitation migrations emit nullable `add :role, :string` (no `null: false`, no `default: "member"`) on both Postgres and MySQL/SQLite branches. Membership and invitation schemas use `Sigra.Ecto.Types.RoleAtom` (atom round-trip without compile-time enum literal). The generated `organizations.ex` wrapper passes `roles: [:owner, :admin, :member]`, `owner_role: :owner`, `invitation_admin_roles: [:owner, :admin]` explicitly to `use Sigra.Organizations`, framed via comment as host-owned starter values. The dead `:require_org_owner` pipeline is gone.

3. **Runtime role propagation flows only through shared seams.** `Sigra.Scope.Hydration.hydrate/3` writes `scope.role` from `membership.role` only on successful org-active hydration; nil-user, no-active-org, `:not_a_member`, and `:org_not_found` branches leave `:role` nil (or never construct a scope). `Sigra.Plug.PutActiveOrganization` writes `:role` on set, nil on clear, after the host scope_module's role-agnostic callback runs. `Sigra.Plug.FetchSession` and `Sigra.Plug.FetchBearer` do not touch `:role` (verified via grep, zero hits). The generated `UserAuth.on_mount` callback flows through the same `Sigra.Scope.Hydration.hydrate/3` seam, preserving plug ↔ on_mount parity. `:actor_type` is reserved at `nil` for Phase 93 with no Phase 92 branching.

4. **Recipe + golden parity.** `guides/recipes/role-based-access-control.md` (252 lines) walks adopters from the allow-all starter to a host-owned `owner / admin / member` deny-by-default policy, with a "Customizing the role taxonomy" section showing alternative shapes (`:tenant_lead / :site_admin / :reviewer / :viewer`) so the concrete atoms read as illustrative. `mix.exs:204` registers the recipe under the Recipes ExDoc group. `test/fixtures/install_golden/` was regenerated post-fixes (commit `a70acca`); golden snapshots match templates byte-for-byte (verified via `golden_diff_test.exs` in spot-check).

**REVIEW-3 BLOCKER count: 0.** The three follow-up fix commits (`3250f14` CR-2-01 tagged-tuple validation, `5cf08ed` WR-2-05 LV taxonomy-agnostic, `01a52d8` WR-3-06 form-reset default role) all landed and verified. Six advisory WARNINGs (WR-3-01 … WR-3-06) remain correctly classified as non-blocking, documented for follow-up. One deferred item (`DEF-92-02-01` — `InvitationAcceptLive` Multi step-name collision, pre-existing bug from 2026-04-15) is correctly identified as not a Phase 92 regression and routed to a follow-up phase.

The phase goal is realized in the codebase. Sigra ships zero opinionated roles. Host RBAC is one schema field + one `Authz` impl + a documented recipe.

---

_Verified: 2026-04-30T15:02:07Z_
_Verifier: Claude (gsd-verifier)_
