# Phase 14: Org Plugs + Scope Hydration - Research

**Researched:** 2026-04-12
**Domain:** Phoenix 1.8 scope hydration, Plug ↔ LiveView parity, library-first authorization plugs
**Confidence:** HIGH

## Summary

Phase 14 is an unusually well-defined phase: `14-CONTEXT.md` contains 26 numbered
implementation decisions (D-01..D-26) plus a complete canonical references map, and
the upstream Phase 12 + Phase 13 work has already landed the data shape
(`%Scope{active_organization, membership, impersonating_from}`,
`user_sessions.active_organization_id` column, `%Sigra.Session{}` struct carrying
the pointer, `Sigra.Organizations.get_membership/3` and `list_organizations_for_user/2`).

The research job therefore is not to discover new options — the user has already
chosen them — but to verify that every named code pointer actually exists in the
current codebase, surface any drift between the CONTEXT.md canonical-refs and what's
actually on disk, confirm Phoenix 1.8 / phx.gen.auth precedents, and give the
planner a single document that collapses the "where does each new module go / what
does it mimic / what does it call" mapping.

**Primary recommendation:** Plan Phase 14 as a strict consumer of Phase 12 and Phase 13
APIs. Every new library module has a direct structural sibling already in the
codebase (`RequireScopes` for `RequireMembership`, `fetch_current_scope` for
`LoadActiveOrganization`, `SessionStore` behaviour for the new
`update_active_organization/3` callback). The single net-new design surface is
`Sigra.Scope.Hydration.hydrate/3` — the pure function that both plug and on_mount
call to collapse SC-3 parity into a unit-testable contract.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

The full 26-entry decision table is in `14-CONTEXT.md`. Summarized here for planner use:

**Architecture (D-01..D-03)**
- **D-01** `Sigra.Scope.Hydration.hydrate/3` is the single source of scope hydration. Both plug and LV `on_mount` call it with `(scope, config, %Sigra.Session{})`. Pure, fail-closed on stale pointers, library-owned.
- **D-02** LiveView `mount_current_scope` switches from `get_user_by_session_token` to `get_user_and_session_by_token` so it has the full `%Sigra.Session{}` for the hydrator.
- **D-03** NO mirroring of `active_organization_id` into the Plug session cookie. DB row is sole authoritative storage. Cookie carries only `:user_token`.

**The Three Request-Time Plugs (D-04..D-07)**
- **D-04** `Sigra.Plug.LoadActiveOrganization` NEVER halts. On stale pointer: clear session row → invoke `select_active_organization/3` with `previous: nil` → write result → emit `log_safe` audit. On nil/success: assign scope and return.
- **D-05** `Sigra.Plug.RequireMembership` is the only new plug that halts. Structurally mimics `Sigra.Plug.RequireScopes` exactly. Validates `:roles` subset at `init/1` (raise `ArgumentError` on typo).
- **D-06** Set-membership role semantics, NOT hierarchical. `roles: [:owner, :admin]` means "role ∈ set."
- **D-07** Default when `:roles` omitted = any membership accepted.

**ErrorHandler (D-08..D-10)**
- **D-08** Extend `Sigra.Plug.ErrorHandler` behaviour with `:no_active_org` and `:insufficient_role` error types (additive).
- **D-09** Generator adds two new clauses to `priv/templates/sigra.install/core/error_handler.ex` (template is named `error_handler.ex`, not `auth_error_handler.ex` — noted drift below).
- **D-10** NO NimbleOptions config for `landing_path` / `access_denied_path`. Paths live in the generated error handler clauses.

**0/1/2+ Selection + Stale Recovery (D-11..D-14)**
- **D-11** `Sigra.Organizations.select_active_organization(config, user, opts)` is a pure helper. Returns `{:ok, org} | {:none, :zero_orgs} | {:multiple, [org]}`. Accepts `:previous_active_organization_id` and (reserved) `:strategy`.
- **D-12** Login (`Sigra.Auth.create_session/4`) calls selector exactly once inside session-creation transaction. Writes `active_organization_id` on `{:ok, org}`, leaves nil otherwise.
- **D-13** "Per-session, not per-user" falls out for free from the `user_sessions.active_organization_id` column.
- **D-14** Stale-pointer policy: hybrid (reset + immediate re-select via same helper). One `log_safe` audit event per transition.

**put_active_organization split (D-15..D-19)**
- **D-15** Pure `Scope.put_active_organization/3` on generated `Scope` template (two clauses: `(scope, %Organization{}, %OrganizationMembership{})` and `(scope, nil, nil)`).
- **D-16** Impure orchestrator `Sigra.Plug.put_active_organization(conn, org_or_nil)` is the single authoritative write site. Writes DB row + `conn.private[:sigra_session]` + `conn.assigns[:current_scope]`.
- **D-17** NO Plug session cookie write. Consistent with D-03.
- **D-18** NO session token rotation on org switch. Scope transition ≠ trust transition. `renew_session` stays scoped to login/logout.
- **D-19** Thin generated wrapper `MyOrgs.set_active_organization/2` (`defdelegate` to `Sigra.Plug.put_active_organization`).

**Session Store (D-20)**
- **D-20** `Sigra.SessionStore` behaviour gains `update_active_organization/3` callback. Default ecto impl does single indexed UPDATE with no-op-safe short-circuit.

**Memoization (D-21)**
- **D-21** Membership memoized in `scope.membership`. No ETS cache in v1.1.

**Library vs Generated (D-22)**
- **D-22** Every new module in Phase 14 is library-side. Generated edits limited to: `scope.ex` (add `put_active_organization/3`), `user_auth.ex` (LV switch), `error_handler.ex` (two new clauses), router (add plug + pipelines), new generated `organizations.ex` context wrapper (defdelegate).

**Verification (D-23..D-26)**
- **D-23** SC-3 parity test collapses to a `hydrate/3` unit test plus two thin wiring tests.
- **D-24** SC-1 stale-pointer regression test (revoke membership → next request → assert no 500, assert scope reset, assert audit emitted).
- **D-25** SC-2 role-filter regression + missing-org regression.
- **D-26** SC-4 0/1/2+ selector pure-unit test + one integration test for login path.

### Claude's Discretion

- **CD-01** Exact file location of the `put_active_organization/2` orchestrator (standalone `Sigra.Plug.put_active_organization` module, method on existing plug, or nested under `Sigra.Organizations.Runtime`). Behavior fixed by D-16.
- **CD-02** Audit event name shape — singular vs plural namespace. Planner checks `lib/sigra/audit.ex` precedent.
- **CD-03** `Sigra.Scope.Hydration.hydrate/3` filepath: `lib/sigra/scope/hydration.ex` vs `lib/sigra/organizations/scope_hydration.ex`.
- **CD-04** `select_active_organization/3` sorting when `{:multiple, orgs}` — unsorted vs `inserted_at desc` stable ordering.
- **CD-05** Test file organization — new files under `test/sigra/scope/` and `test/sigra/plug/` vs additions to existing files.
- **CD-06** `SessionStore.update_active_organization/3` as new callback on behaviour vs impl-only extension (depends on impl count — verified below: only one impl exists, `Sigra.SessionStores.Ecto`, so a behaviour callback is cleanest).

### Deferred Ideas (OUT OF SCOPE)

- ETS cross-request membership cache (v1.2 if profiling shows pressure).
- Hierarchical roles (`:owner` implies `:admin`).
- `users.last_active_organization_id` cross-device resume pointer.
- `:strategy` option for `select_active_organization/3` implementation (field reserved; v1.1 uses default only).
- Session token rotation on org switch.
- `Sigra.Session.put_active_organization_id/2` named setter.
- Cookie-mirrored `active_organization_id`.
- LV `attach_hook`-based scope hydration.
- Stale-pointer Oban proactive cleanup job.
- Cross-tab scope drift detection (belongs in Phase 16).
- POST switch controller + switcher UI + no-org landing page (Phase 16).
- `audit_events.organization_id` real column + `metadata_from_scope/2` (Phase 15).
- `--no-organizations` generator conditionality (Phase 18).

</user_constraints>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ORG-SCOPE-03 | `Sigra.Plug.LoadActiveOrganization` hydrates scope; stale pointer resets instead of 500 | D-04 + D-14 + `Sigra.Organizations.get_membership/3` (Phase 13, verified present at `lib/sigra/organizations.ex:425`). `Sigra.Audit.log_safe/2` verified at `lib/sigra/audit.ex:112`. Stale recovery path is well-defined by CONTEXT. |
| ORG-SCOPE-04 | `Sigra.Plug.RequireMembership` + optional role filter | D-05..D-07. Structural mimic of `lib/sigra/plug/require_scopes.ex` (verified, 112 lines, includes `init/1` validation pattern and `error_handler.auth_error/3` delegation). |
| ORG-SCOPE-05 | LiveView `on_mount` hydrates scope identically to plug path | D-01..D-02. Generated `user_auth.ex` at `priv/templates/sigra.install/core/user_auth.ex` line 222-231 shows `mount_current_scope` currently calls `get_user_by_session_token`; line 132 already uses `get_user_and_session_by_token` in `fetch_current_scope`. One-function replacement. |
| ORG-SCOPE-06 | Zero / one / 2+ orgs login flow | D-11..D-13. `Sigra.Organizations` has `list_organizations_for_user/2` and `get_membership/3` already; `select_active_organization/3` is net-new but composes over those primitives. Login call site `Sigra.Auth.create_session/4` verified at `lib/sigra/auth.ex:984`. |

## Project Constraints (from CLAUDE.md)

- **Framework:** Phoenix 1.8+ / Ecto 3.x as blessed path. Phase 14 adheres: scope hydration follows Phoenix 1.8 scopes guide (`put_organization/2` precedent); plug+on_mount twin-callers pattern matches `phx.gen.auth 1.8.5`.
- **Database:** PostgreSQL primary, MySQL/SQLite via conditional migrations. Phase 14 touches no migrations directly — `active_organization_id` column shipped in Phase 12.
- **Security:** OWASP throughout, fail-closed on stale/revoked session pointers. Phase 14 satisfies via D-04 (LoadActiveOrganization never returns an invalid scope) and D-16 (orchestrator verifies membership before writing).
- **Dependencies:** Minimal transitive deps. Phase 14 adds ZERO new deps — pure internal wiring.
- **LiveView supported but optional:** Phase 14 keeps the LV path in the generated `user_auth.ex` and does not require LV for correctness. The hydrator is pure; it works the same whether called from plug or on_mount.
- **Testing:** AAA, flat, self-contained. Phase 14 tests are unit-style (hydrator, selector, plugs) + 1 integration test for login. D-23 collapses end-to-end parity harness into a unit test — aligned with CLAUDE.md testing philosophy.
- **GSD Workflow Enforcement:** All edits happen through the Phase 14 plan; no direct repo edits bypass GSD.

## Standard Stack

Phase 14 adds NO new dependencies. All work is internal wiring on top of Phase 12 + 13 primitives. The stack already in place:

### In-Repo Primitives (verified)

| Module | Purpose | Location (verified) |
|--------|---------|---------------------|
| `%Sigra.Session{}` struct with `:active_organization_id` field | Session pointer | `lib/sigra/session.ex` (Phase 12) [VERIFIED: file present] |
| `Sigra.SessionStore` behaviour (7 callbacks) | Session persistence contract | `lib/sigra/session_store.ex` (63 lines) [VERIFIED: read] |
| `Sigra.SessionStores.Ecto` | Only impl of behaviour | `lib/sigra/session_stores/ecto.ex` (only file in that dir) [VERIFIED: ls] |
| `Sigra.Organizations.get_membership/3` | Fetch user's membership in org | `lib/sigra/organizations.ex:425` [VERIFIED: grep] |
| `Sigra.Organizations.list_organizations_for_user/2` | List user's orgs | `lib/sigra/organizations.ex:405` [VERIFIED: grep] |
| `Sigra.Audit.log_safe/2` | No-op-safe audit emission | `lib/sigra/audit.ex:112` [VERIFIED: grep] |
| `Sigra.Plug.RequireScopes` | Structural precedent for `RequireMembership` | `lib/sigra/plug/require_scopes.ex` (112 lines) [VERIFIED: read] |
| `Sigra.Plug.ErrorHandler` behaviour | Behaviour to extend with 2 new error types | `lib/sigra/plug/error_handler.ex` (63 lines) [VERIFIED: read] |
| `Sigra.Auth.create_session/4` | Login entry point for D-12 selector call | `lib/sigra/auth.ex:984` [VERIFIED: grep + read] |
| Generated `Scope` template with Phase 12 fields | Target of D-15 pure function addition | `priv/templates/sigra.install/core/scope.ex` [VERIFIED: read — `active_organization`, `membership`, `impersonating_from` fields already defstructed] |
| Generated `user_auth.ex` template | Target of D-02 LV switch | `priv/templates/sigra.install/core/user_auth.ex` [VERIFIED: read — `fetch_current_scope` at line 128 uses `get_user_and_session_by_token` and stashes session at `conn.private[:sigra_session]`; `mount_current_scope` at line 222 uses the user-only variant] |

### Alternatives Considered

| Standard | Alternative | Tradeoff |
|----------|-------------|----------|
| `Sigra.SessionStore.update_active_organization/3` as new behaviour callback | Impl-only extension in `Sigra.SessionStores.Ecto` | Since there is exactly one impl (verified — only `session_stores/ecto.ex` exists), a behaviour callback is cleaner and matches the existing 7-callback pattern. Impl-only would drift against the "behaviour-first" convention already established. **Recommended: add as callback (resolves CD-06).** |
| `lib/sigra/scope/hydration.ex` | `lib/sigra/organizations/scope_hydration.ex` | First path reads better alongside the library's `lib/sigra/scope/` namespace; the second scopes it under the org namespace which is narrower. However, since Phase 12's `impersonating_from` field suggests the hydrator will grow multi-concern (v1.2 impersonation), a top-level `lib/sigra/scope/hydration.ex` location matches its role as the single hydration contract. **Recommended: `lib/sigra/scope/hydration.ex` (resolves CD-03).** Note: currently no `lib/sigra/scope/` directory exists — planner will create it. |
| `Sigra.Plug.put_active_organization/2` as a top-level function on a new module | Nest under `Sigra.Plug.LoadActiveOrganization.put/2` or `Sigra.Organizations.Runtime` | Top-level module `lib/sigra/plug/put_active_organization.ex` reads most naturally alongside existing `lib/sigra/plug/fetch_session.ex`, `fetch_bearer.ex`, etc. The Phase 14 CONTEXT uses `Sigra.Plug.put_active_organization/2` as a function-on-module name in D-16 and D-19 defdelegate. **Recommended: standalone `Sigra.Plug.PutActiveOrganization` module with the orchestrator function, then alias via `Sigra.Plug` shortcut if precedent exists. Alternatively: function on `Sigra.Plug.LoadActiveOrganization`, co-locating the "fetch" and "mutate" paths.** Planner picks. |

**No new `mix.exs` additions needed.** Verify after planning:
```bash
# Phase 14 should NOT add any lines to mix.exs deps/0.
git diff mix.exs  # expected empty after Phase 14 code lands
```

## Architecture Patterns

### Project Structure (after Phase 14)

```
lib/sigra/
├── plug/
│   ├── error_handler.ex                    # EXTENDED: 2 new error types
│   ├── fetch_session.ex                    # UNCHANGED
│   ├── load_active_organization.ex         # NEW (D-04)
│   ├── put_active_organization.ex          # NEW (D-16)        [or nested — CD-01]
│   ├── require_authenticated.ex            # UNCHANGED
│   ├── require_membership.ex               # NEW (D-05..D-07)
│   ├── require_scopes.ex                   # UNCHANGED (structural precedent)
│   └── require_sudo.ex                     # UNCHANGED
├── scope/
│   └── hydration.ex                        # NEW (D-01)         [or under organizations/ — CD-03]
├── session_store.ex                        # EXTENDED: new callback
├── session_stores/
│   └── ecto.ex                             # EXTENDED: implement update_active_organization/3
├── organizations.ex                        # EXTENDED: select_active_organization/3
└── auth.ex                                 # EXTENDED: create_session/4 calls selector (one-line insert)

priv/templates/sigra.install/
├── core/
│   ├── error_handler.ex                    # EXTENDED: 2 new clauses
│   ├── scope.ex                            # EXTENDED: put_active_organization/3 pure function
│   └── user_auth.ex                        # EXTENDED: mount_current_scope switched, on_mount calls hydrator
└── organizations/
    └── organizations.ex                    # NEW TEMPLATE: generated context wrapper with set_active_organization/2 defdelegate

test/sigra/
├── scope/
│   └── hydration_test.exs                  # NEW (D-23)
├── plug/
│   ├── load_active_organization_test.exs   # NEW (D-24)
│   └── require_membership_test.exs         # NEW (D-25)
└── organizations_test.exs                  # EXTENDED: select_active_organization/3 cases (D-26)
```

**Note on generated organizations context wrapper:** Currently
`priv/templates/sigra.install/organizations/` contains ONLY
`migration.exs`, `organization.ex`, `organization_invitation.ex`,
`organization_membership.ex` [VERIFIED via `ls`]. There is NO generated
`organizations.ex` context wrapper. Phase 14 D-19 implies creating one —
planner must add `priv/templates/sigra.install/organizations/organizations.ex`
(or equivalent naming convention) and wire it into `Sigra.Install.Features.Organizations`
(Phase 13 work). This is a minor but load-bearing addition: ORG-SCOPE-06 depends on
a discoverable `MyOrgs.set_active_organization/2` entry point.

### Pattern 1: Shared Hydrator (Plug ↔ LiveView Parity)

**What:** One pure function, two thin callers. Collapses end-to-end parity matrix to unit test.

**Shape:**
```elixir
# lib/sigra/scope/hydration.ex
defmodule Sigra.Scope.Hydration do
  @moduledoc """
  Pure scope-hydration contract shared between Sigra.Plug.LoadActiveOrganization
  (plug path) and the generated UserAuth.on_mount (LiveView path).

  Given a (scope, config, session), returns a fully-populated %Scope{} or a
  fail-closed error tuple. This is the SINGLE place scope hydration lives; any
  future scope augmentation (impersonation, feature flags) extends this function.
  """

  alias Sigra.Organizations

  @spec hydrate(scope :: struct(), config :: Sigra.Config.t(), session :: Sigra.Session.t()) ::
          {:ok, struct()} | {:error, :not_a_member | :org_not_found}
  def hydrate(scope, _config, %Sigra.Session{active_organization_id: nil}) do
    # No active org pointer — return scope with nil active_organization/membership.
    {:ok, scope}
  end

  def hydrate(scope, config, %Sigra.Session{active_organization_id: org_id} = _session) do
    # 1. Resolve the org by id (uses Phase 13 Organizations.get_organization!/2 or a safer get_organization/2)
    # 2. Call Organizations.get_membership(config, scope.user, org) → may return nil
    # 3. If both present: return {:ok, scope with active_organization + membership}
    # 4. If membership nil: {:error, :not_a_member}   ← triggers stale-pointer path
    # 5. If org not found (deleted): {:error, :org_not_found}   ← triggers stale-pointer path
  end
end
```

**When to use:** Every time a pipeline (plug OR on_mount) needs to populate
`scope.active_organization`. Never duplicate this logic.

### Pattern 2: Fetch/Require Split (inherited from phx.gen.auth)

**Source:** `phx.gen.auth 1.8.5` — `fetch_current_scope_for_user` never halts;
`require_authenticated_user` halts with redirect. [CITED: hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Auth.html]

**Applied to Phase 14:**
- `Sigra.Plug.LoadActiveOrganization` = Fetch plug. Mutates `assigns[:current_scope]` + `conn.private[:sigra_session]`. Never halts.
- `Sigra.Plug.RequireMembership` = Require plug. Halts via `error_handler.auth_error(conn, type, opts) |> halt()`.

This exact pattern is already in use by `Sigra.Plug.RequireAuthenticated`,
`Sigra.Plug.RequireScopes`, `Sigra.Plug.RequireSudo` — all verified in `lib/sigra/plug/`.

### Pattern 3: Library-Plug → Generated-ErrorHandler Delegation

**Source:** `lib/sigra/plug/require_scopes.ex:68-91` [VERIFIED: read]

```elixir
# Exact shape RequireMembership should mimic
error_handler = Keyword.fetch!(opts, :error_handler)
scope = conn.assigns[:current_scope]

cond do
  is_nil(scope) or is_nil(scope.active_organization) ->
    conn |> error_handler.auth_error(:no_active_org, opts) |> Plug.Conn.halt()

  required != [] and scope.membership.role not in required ->
    error_opts = Keyword.put(opts, :required_roles, required)
    conn |> error_handler.auth_error(:insufficient_role, error_opts) |> Plug.Conn.halt()

  true ->
    conn
end
```

### Pattern 4: Pure Struct-Update Functions on Generated Scope

**Source:** Phoenix 1.8 scopes guide — `put_organization/2` shape. [CITED: hexdocs.pm/phoenix/scopes.html]

```elixir
# Added to priv/templates/sigra.install/core/scope.ex (D-15)
@doc "Puts the given organization + membership on the scope."
def put_active_organization(%__MODULE__{} = scope, %<%= context_module %>.Organization{} = org,
                            %<%= context_module %>.OrganizationMembership{} = membership) do
  %{scope | active_organization: org, membership: membership}
end

def put_active_organization(%__MODULE__{} = scope, nil, nil) do
  %{scope | active_organization: nil, membership: nil}
end
```

Generated, app-owned, dialyzer-friendly. Phoenix 1.8 guide compliance is absolute.

### Anti-Patterns to Avoid

- **Do NOT copy `Sigra.Plug.RequireMFA`'s init-option path pattern** for `RequireMembership`. Legacy; explicitly rejected by D-10. Every path target lives in the error handler.
- **Do NOT call `put_session(:active_organization_id, id)`** anywhere. Two writers → pitfall O-5. D-03 / D-17 explicitly reject this.
- **Do NOT re-query membership in `RequireMembership`.** The load plug already did it; read `scope.membership.role`. D-21.
- **Do NOT rotate the session token on org switch.** Scope transition ≠ trust transition. D-18.
- **Do NOT build a combinatorial end-to-end parity test matrix** (login × switch × stale × revoked). D-23 collapses to one unit test on the hydrator plus two thin wiring tests.
- **Do NOT pattern-match on the `_auth_method` field of scope** inside `RequireMembership` — session users are the only consumers; API tokens don't carry active_organization. The scope struct bypass logic from `RequireScopes` (session passes through) does NOT apply here.
- **Do NOT introduce hierarchical role logic** (`[:owner]` implies `:admin`). Set membership only. D-06. [VERIFIED: Bodyguard, Canada, Phoenix 1.8 scopes all use set membership.]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Scope hydration from session | A duplicated `on_mount` version of the plug logic | `Sigra.Scope.Hydration.hydrate/3` single source (D-01) | Parity drift is the whole reason this phase exists; having two copies is the bug. |
| Membership lookup inside `RequireMembership` | Direct Ecto query / call to `Organizations.get_membership/3` at request time | Read `scope.membership` populated by `LoadActiveOrganization` | Extra DB roundtrip per request; membership was already fetched. |
| Stale-pointer detection via DB constraint | Foreign-key cascade + rescue 500 in router | `hydrate/3` fail-closed return + `LoadActiveOrganization` reset path (D-04 step 5) | Cascade triggers on every deletion; Phase 13 uses soft-delete; FK alone can't express "user was removed from org but org still exists." |
| 0/1/2+ login branching | Login controller with case statement | `Sigra.Organizations.select_active_organization/3` pure helper | Reused by login AND stale-recovery paths. One contract, two call sites. |
| Error handling redirect targets | NimbleOptions config for `:landing_path` + `:access_denied_path` | Generated error handler clauses (D-10) | Zero new config surface; matches every other Sigra library plug. |
| Audit of stale-pointer transitions | Direct `Sigra.Audit.log/2` (which raises) | `Sigra.Audit.log_safe/2` | `organization_id` column doesn't exist yet (Phase 15); `log_safe` is no-op-safe via telemetry fallback. |

**Key insight:** Phase 14 is 80% wiring between already-built primitives. The only
genuinely new design decision is the shape of `Sigra.Scope.Hydration.hydrate/3`,
and even that was resolved in CONTEXT (D-01). Guard against scope creep into
Phase 15 (audit column), Phase 16 (switcher UI), Phase 17 (invitations).

## Runtime State Inventory

Phase 14 is NOT a rename/refactor phase, but it does introduce a runtime state
discipline that future phases inherit, so the inventory is still worth documenting:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `user_sessions.active_organization_id` column (shipped in Phase 12). Phase 14 is its first request-time reader + writer. | No migration — column already exists. Plan verifies `SessionStore.update_active_organization/3` writes match the column type (`:binary_id`, nullable). |
| Live service config | None — Phase 14 touches no external services. | None. |
| OS-registered state | None. | None. |
| Secrets/env vars | None. | None. |
| Build artifacts | None. | None. |

**Single canonical write path:** After Phase 14, any future code that needs to
set `active_organization_id` on a session row MUST go through
`Sigra.Plug.put_active_organization/2` (D-16) or the generated
`MyOrgs.set_active_organization/2` delegate (D-19). Ad-hoc
`Repo.update(user_session, ...)` calls on the column are a maintenance hazard and
should fail code review.

## Common Pitfalls

### Pitfall 1: Plug ↔ LiveView Scope Drift (PITFALLS O-5)
**What goes wrong:** User switches orgs in one tab; another tab's LiveView still shows the old org for the rest of its lifetime. Or: plug pipeline sees `active_organization = org_A`, LV mount sees `nil` due to divergent hydration logic.
**Why it happens:** Two independent implementations of "hydrate scope from session" drift. Also: cookie state mirroring the DB state creates two writers.
**How to avoid:** D-01 single hydrator + D-03 no cookie mirror. The parity test (D-23) provides the mechanical guarantee.
**Warning signs:** Any code in `user_auth.ex` that reads session fields directly instead of calling `Sigra.Scope.Hydration.hydrate/3`. Any `put_session(:active_organization_id, ...)` call.
**Mitigation in this phase:** `hydrate/3` is the ONLY code path that populates `scope.active_organization`. Both callers (Load plug and on_mount) are tested to call it with equivalent inputs.

### Pitfall 2: Stale `active_organization_id` → 500 (PITFALLS O-6)
**What goes wrong:** User was removed from org X while logged in; next request includes session with `active_organization_id = X`; `Organizations.get_organization!/2` raises `Ecto.NoResultsError` → 500 → user locked out.
**Why it happens:** Fetching the org row without a membership check, then passing the bare org to a scope constructor.
**How to avoid:** `hydrate/3` calls `get_membership/3` FIRST; on miss returns `{:error, :not_a_member}` without raising. `LoadActiveOrganization` catches that error, clears the session column, and re-runs the selector. One audit event via `log_safe`. D-04 step 5 + D-14.
**Warning signs:** Any bang-function call (`get_organization!`) in the hydration path. Any code that reaches into `conn.private[:sigra_session]` without going through the hydrator.
**Regression test:** D-24 — create user + org + membership → log in → `Sigra.Organizations.remove_member/3` → next request → assert status 200 + audit event + scope reset or reassigned.

### Pitfall 3: Hierarchical Roles Creeping In
**What goes wrong:** Well-meaning `roles: [:owner]` check implicitly "also allows admin" because someone read it as seniority order.
**Why it happens:** Role names sound hierarchical; `[:owner, :admin, :member]` looks like a ladder.
**How to avoid:** D-06 locks set-membership semantics. `:roles` option is a subset filter.
**Warning signs:** Any sort/rank/compare operation on role atoms. Any `Enum.find_index/2` on the role list.
**Mitigation:** Init-time validation that the plug's `:roles` option is a subset of `@sigra_org_config[:roles]` raises `ArgumentError` on typo — catches the case of `roles: [:owners]` (plural typo) at compile time, not request time.

### Pitfall 4: Generator Touches Not-Yet-Existing Templates
**What goes wrong:** Phase 14 tries to edit a generated `organizations.ex` context wrapper that Phase 13 didn't ship.
**Why it happens:** D-19 says "generated organizations wrapper gains `set_active_organization/2` defdelegate" but
`priv/templates/sigra.install/organizations/` currently has NO context wrapper — only schemas. [VERIFIED via `ls`]
**How to avoid:** Planner must add a dedicated task to CREATE
`priv/templates/sigra.install/organizations/organizations.ex` (or equivalent), register it in
`Sigra.Install.Features.Organizations.files/1`, and add the `set_active_organization/2` defdelegate
as the FIRST content of that file. Do not assume the template already exists.
**Warning signs:** Any plan task that says "add X to generated organizations.ex" without an explicit predecessor that creates the file.

### Pitfall 5: Generated `error_handler.ex` Naming Drift
**What goes wrong:** CONTEXT.md D-09 references `priv/templates/sigra.install/core/auth_error_handler.ex` but the actual file is `priv/templates/sigra.install/core/error_handler.ex`. [VERIFIED via `ls`]
**Why it happens:** Naming convention for the generated file ("error_handler" on disk, "AuthErrorHandler" in-context) is inconsistent in the CONTEXT.
**How to avoid:** Planner uses the on-disk path `priv/templates/sigra.install/core/error_handler.ex` as the template target for the two new clauses. The in-app generated module name (which erb-templated as `<%= web_module %>.AuthErrorHandler`) is separate from the template filename.
**Warning signs:** Any task referencing `auth_error_handler.ex` as the filename.

### Pitfall 6: Extending `Sigra.Plug.ErrorHandler` Behaviour Breaks Existing Impls
**What goes wrong:** Adding `:no_active_org` and `:insufficient_role` to the `@type error_type :: ...` union makes existing host-app handlers incomplete — they don't have clauses for the new atoms.
**Why it happens:** Dialyzer will warn that the callback's type is larger than the implemented clauses.
**How to avoid:** The Elixir way: `@type` additions are additive and don't break pattern match behavior at runtime. Existing handlers will work; unmatched atoms fall through to the catch-all or raise `FunctionClauseError`. Phase 14 is the only caller of the new atoms, so the only handler that needs the new clauses is the freshly generated one via D-09. [VERIFIED: `lib/sigra/plug/error_handler.ex` is a behaviour with an open union of error types; existing error types were added in v1.0 without a compat shim.]
**Warning signs:** A Dialyzer error on hosts that installed Sigra v1.0 and upgrade to v1.1 without re-running the generator for the error handler. Mitigation: document in the v1.1 upgrade guide (Phase 23) that hosts need to add the two clauses manually OR re-run `mix sigra.install --yes` which is idempotent.

## Code Examples

Verified patterns from existing code:

### Library Plug → Error Handler Delegation
```elixir
# From lib/sigra/plug/require_scopes.ex:43-92 (VERIFIED: read)
def init(opts) do
  scopes = Keyword.fetch!(opts, :scopes)

  unless is_list(scopes) and scopes != [] do
    raise ArgumentError, "RequireScopes :scopes must be a non-empty list"
  end

  _ = Keyword.fetch!(opts, :error_handler)
  opts
end

def call(conn, opts) do
  required = Keyword.fetch!(opts, :scopes)
  error_handler = Keyword.fetch!(opts, :error_handler)
  scope = conn.assigns[:current_scope]

  cond do
    is_nil(scope) ->
      conn |> error_handler.auth_error(:unauthenticated, opts) |> Plug.Conn.halt()

    has_required_scopes?(scope, required, match_mode) ->
      conn

    true ->
      conn |> error_handler.auth_error(:insufficient_scope, error_opts) |> Plug.Conn.halt()
  end
end
```

**Phase 14 usage:** `Sigra.Plug.RequireMembership` mimics this structure. Init validates `:roles` subset; call reads `scope.active_organization` + `scope.membership.role`, delegates failures.

### Stashing Session on conn.private (existing Fetch pattern)
```elixir
# From priv/templates/sigra.install/core/user_auth.ex:128-142 (VERIFIED: read)
def fetch_current_scope(conn, _opts) do
  {user_token, conn} = ensure_user_token(conn)

  {user, session} =
    case user_token && <%= context_module %>.get_user_and_session_by_token(user_token) do
      {u, s} -> {u, s}
      _ -> {nil, nil}
    end

  scope = user && Scope.for_user(user)

  conn
  |> put_private(:sigra_session, session)   # ← Phase 14 reads from here
  |> assign(:current_scope, scope)
end
```

**Phase 14 usage:** `LoadActiveOrganization.call/2` reads `conn.private[:sigra_session]`, calls `hydrate/3`, then `assign(:current_scope, hydrated_scope)` if different.

### Current LiveView Mount (target of D-02 change)
```elixir
# From priv/templates/sigra.install/core/user_auth.ex:222-231 (VERIFIED: read)
defp mount_current_scope(socket, session) do
  Phoenix.Component.assign_new(socket, :current_scope, fn ->
    user =
      if user_token = session["user_token"] do
        <%= context_module %>.get_user_by_session_token(user_token)   # ← BEFORE
      end

    user && Scope.for_user(user)
  end)
end
```

**After Phase 14 (D-02):**
```elixir
defp mount_current_scope(socket, session) do
  Phoenix.Component.assign_new(socket, :current_scope, fn ->
    case session["user_token"] do
      nil ->
        nil

      user_token ->
        case <%= context_module %>.get_user_and_session_by_token(user_token) do
          {user, %Sigra.Session{} = sigra_session} ->
            scope = Scope.for_user(user)
            case Sigra.Scope.Hydration.hydrate(scope, <%= context_module %>.sigra_config(), sigra_session) do
              {:ok, hydrated} -> hydrated
              {:error, _} -> scope  # fail-closed: return unaugmented scope on stale/miss
            end

          _ ->
            nil
        end
    end
  end)
end
```

**Note:** The LV path cannot execute the stale-pointer re-selection + DB write
(Phase 14 only writes to session row via the plug pipeline on subsequent HTTP
requests). LV's responsibility is limited to safely presenting a nil
`active_organization` until the next HTTP round-trip touches the plug pipeline.
The integration test (D-26) should cover this LV-first case explicitly.

### Phase 13 Context Functions Already Present
```elixir
# lib/sigra/organizations.ex (VERIFIED via grep)
def list_organizations_for_user(config, user) do   # line 405
  # Returns list of orgs user is member of
end

def get_membership(config, user, org) do            # line 425
  # Returns %OrganizationMembership{} or nil
end
```

Phase 14's `select_active_organization/3` composes over these:
```elixir
def select_active_organization(config, user, opts \\ []) do
  previous_id = Keyword.get(opts, :previous_active_organization_id)

  case list_organizations_for_user(config, user) do
    [] ->
      {:none, :zero_orgs}

    [org] ->
      {:ok, org}

    orgs when is_list(orgs) ->
      case previous_id && Enum.find(orgs, fn o -> o.id == previous_id end) do
        %{} = resumed -> {:ok, resumed}
        _ -> {:multiple, orgs}
      end
  end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Pow`'s macro-injection of session fields | Phoenix 1.8 `%Scope{}` struct with explicit fields | Phoenix 1.8 (Aug 2025) | "Own your code" — scope struct is visible; extending it is purely additive. |
| `phx.gen.auth 1.7` single `fetch_current_user` plug | `phx.gen.auth 1.8.5` Fetch/Require split | Phoenix 1.8.x | Clean separation of assign-and-pass vs halt-with-redirect; Phase 14 RequireMembership fits naturally. |
| Cookie-stored active org (Jetstream PHP precedent) | DB column on sessions table | Sigra v1.1 | Eliminates two-writer hazard; survives cross-device login cleanly. |
| Hierarchical role comparison (`:role >= :admin`) | Set-membership check (`role in [:owner, :admin]`) | Long-established in Bodyguard, Canada, Phoenix 1.8 scopes | No hidden precedence; role additions are non-breaking; test expectations are explicit. |
| Session token rotation on every scope change | Rotation scoped to trust transitions only (login/logout/sudo) | OWASP Session Management Cheat Sheet | Avoids dropping LV connections on every org switch; matches Jetstream/Clerk/acts_as_tenant precedent. |

**Deprecated/outdated (in Sigra's context):**
- Any plug pattern that does `put_session(:active_organization_id, ...)` — replaced by `Sigra.Plug.put_active_organization/2`.
- `get_user_by_session_token` in the LV path — D-02 replaces with `get_user_and_session_by_token`. The user-only variant stays available for non-session-needing callers.

## Environment Availability

Phase 14 is pure in-repo Elixir code — no new external dependencies, no external
services, no new CLI tools. All build-time and runtime dependencies are already
available from prior phases.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Compilation | ✓ | ~> 1.18 (mix.exs line 11) | — |
| Phoenix 1.8 | Scope precedent + plug pipeline | ✓ | ~> 1.8 (already in deps) | — |
| Ecto 3.x | SessionStore.Ecto UPDATE | ✓ | ~> 3.12+ (already in deps) | — |
| PostgreSQL | user_sessions table | ✓ | Test + dev envs already configured | — |
| `Sigra.Session` struct | Hydrator input | ✓ | Shipped in Phase 12 | — |
| `Sigra.Organizations.get_membership/3` | Hydrator uses | ✓ | Shipped in Phase 13 | — |
| `Sigra.Audit.log_safe/2` | Stale-transition audit | ✓ | Shipped in v1.0 (lib/sigra/audit.ex:112) | — |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir stdlib) + Mox for behaviour mocks |
| Config file | `test/test_helper.exs` (existing) |
| Quick run command | `mix test test/sigra/scope/hydration_test.exs test/sigra/plug/load_active_organization_test.exs test/sigra/plug/require_membership_test.exs --max-failures 1` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ORG-SCOPE-03 | `LoadActiveOrganization` hydrates from session, handles stale pointer without 500 | unit | `mix test test/sigra/plug/load_active_organization_test.exs` | ❌ Wave 0 |
| ORG-SCOPE-03 | `hydrate/3` returns `{:error, :not_a_member}` on revoked membership | unit | `mix test test/sigra/scope/hydration_test.exs` | ❌ Wave 0 |
| ORG-SCOPE-03 | Stale-pointer end-to-end regression: revoke → next request → 200 + audit | integration | `mix test test/sigra/plug/load_active_organization_test.exs:{stale_line}` | ❌ Wave 0 |
| ORG-SCOPE-04 | `RequireMembership` with no active org → `:no_active_org` + halt | unit | `mix test test/sigra/plug/require_membership_test.exs` | ❌ Wave 0 |
| ORG-SCOPE-04 | `RequireMembership, roles: [:owner]` on `:member` → `:insufficient_role` + halt | unit | same file | ❌ Wave 0 |
| ORG-SCOPE-04 | `RequireMembership` init-time validation raises on unknown role atom | unit | same file | ❌ Wave 0 |
| ORG-SCOPE-05 | Plug path and on_mount both call `hydrate/3` with equivalent inputs | unit (wiring) | `mix test test/sigra/plug/load_active_organization_test.exs` + generated `user_auth_test.exs` | ❌ Wave 0 + generated test exists for existing on_mount |
| ORG-SCOPE-05 | Hydrator contract exhaustively tested | unit | `mix test test/sigra/scope/hydration_test.exs` | ❌ Wave 0 |
| ORG-SCOPE-06 | `select_active_organization/3` pure cases (0, 1, 2+ with resume, 2+ without) | unit | `mix test test/sigra/organizations_test.exs` | ✅ (extend) |
| ORG-SCOPE-06 | `Sigra.Auth.create_session/4` writes correct `active_organization_id` for each case | integration | `mix test test/sigra/auth_test.exs` | ✅ (extend) |

### Sampling Rate
- **Per task commit:** Quick run command (four targeted test files).
- **Per wave merge:** `mix test` (full suite) + `mix credo --strict` + `mix dialyzer`.
- **Phase gate:** Full suite green + `mix docs --warnings-as-errors` clean before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `test/sigra/scope/hydration_test.exs` — covers ORG-SCOPE-03 + ORG-SCOPE-05 hydrator contract.
- [ ] `test/sigra/plug/load_active_organization_test.exs` — covers ORG-SCOPE-03 + stale regression.
- [ ] `test/sigra/plug/require_membership_test.exs` — covers ORG-SCOPE-04.
- [ ] Extend `test/sigra/organizations_test.exs` with `select_active_organization/3` cases — covers ORG-SCOPE-06 pure path.
- [ ] Extend `test/sigra/auth_test.exs` with `create_session/4` selector integration — covers ORG-SCOPE-06 integration path.
- [ ] (Optional) Parity wiring test on generated `user_auth.ex` — if an existing generated test asserts LV on_mount behavior, extend it; otherwise skip in favor of the hydrator unit test.

**Wave 0 framework setup: NONE required.** ExUnit and Mox are already in place from v1.0.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (Phase 14 is post-auth authz) | — |
| V3 Session Management | yes | Single-writer to session row (D-03/D-17); no rotation on scope change (D-18); fail-closed on stale pointer (D-04) |
| V4 Access Control | yes | `RequireMembership` with set-membership role check (D-05/D-06); init-time role validation (D-05); fail-closed when scope lacks active org (D-05) |
| V5 Input Validation | yes | Init-time keyword validation (`:roles` is list, subset of configured roles); `Keyword.fetch!` on required opts |
| V6 Cryptography | no (Phase 14 touches no hashing/crypto) | — |

### Known Threat Patterns for Phoenix 1.8 / Elixir Auth

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-org session confusion (O-5) | Information Disclosure / Tampering | Single writer to `user_sessions.active_organization_id`; no cookie mirror (D-03/D-17) |
| Stale pointer → 500 → account lockout (O-6) | Denial of Service / Availability | Fail-closed `hydrate/3` + `LoadActiveOrganization` reset path (D-04/D-14) |
| Role-escalation via hierarchical comparison | Elevation of Privilege | Set-membership only, init-time validation (D-06 + RequireMembership `init/1`) |
| Scope-transition session rotation gap | Information Disclosure | Deliberately NOT rotated — scope change is not a trust change. CSRF + per-request re-verification close the window. (D-18, OWASP Session Management Cheat Sheet) |
| Audit gap on stale recovery | Repudiation | `log_safe/2` emits `organization.active_auto_reassigned` on every stale transition (D-14). Forward-compat with Phase 15. |
| Authorization bypass via direct `put_session` | Tampering | Explicitly forbidden (D-03, D-17); single write path through `Sigra.Plug.put_active_organization/2` (D-16). |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Sigra.Organizations.get_organization/2` (non-bang variant) exists or will be added in Phase 14 for the hydrator's fail-closed org lookup | Code Examples → hydrator sketch | LOW — if only `get_organization!/2` exists, planner adds a rescue wrapper in `hydrate/3` or adds a non-bang helper as part of the phase. Verified: `lib/sigra/organizations.ex:379` shows `get_organization!/2`; a non-bang version is not confirmed present. [ASSUMED] |
| A2 | Generated `organizations.ex` context wrapper template does not yet exist and must be created by Phase 14 | Architecture Patterns / Pitfall 4 | LOW — `ls` on `priv/templates/sigra.install/organizations/` [VERIFIED] confirms only schema templates. If a wrapper exists elsewhere (e.g., generated at install time without a template), planner adapts. |
| A3 | `Sigra.Plug.ErrorHandler` behaviour is an open union and existing host impls won't break from adding new error atoms | Pitfall 6 | LOW-MEDIUM — Elixir type specs are not enforced at runtime; runtime behavior depends on existing impls having `def auth_error(conn, _other, _opts)` catch-all clauses or not. Planner should verify the generated `error_handler.ex` template has a catch-all or Phase 23 upgrade docs explicitly require re-running the generator. |
| A4 | `Sigra.SessionStores.Ecto` is the only impl of `Sigra.SessionStore` behaviour | Alternatives Considered (CD-06 resolution) | LOW — `ls lib/sigra/session_stores/` [VERIFIED] returns only `ecto.ex`. If a Redis/ETS impl exists in an unchecked location, the callback addition breaks it. Mitigation: grep for `@behaviour Sigra.SessionStore` during planning. |
| A5 | `Sigra.Auth.create_session/4` is the sole login entry point and there are no other call sites that insert `user_sessions` rows | D-12 applicability | LOW — login via OAuth (Phase 5) may call a different path. `lib/sigra/auth.ex:1191` shows `login_oauth/4` exists [VERIFIED via grep]. Planner verifies whether `login_oauth` also creates sessions through `create_session/4` or inline; if inline, the selector-at-login logic must be added there too, OR better, factored into `create_session/4` and called by both. |
| A6 | The `%Sigra.Session{}` struct exposes `id` or a similar primary key for `update_active_organization/3`'s UPDATE-WHERE clause | D-20 | LOW — Phase 12 shipped the struct and the column; the update path requires a stable row identifier. Planner reads `lib/sigra/session.ex` to confirm. |
| A7 | `Sigra.Config` struct has a `:scope_module` field or equivalent so `put_active_organization/2` orchestrator can resolve the host's Scope module for calling the pure `put_active_organization/3` | D-16 step 4 | MEDIUM — if no such field exists, planner either adds it to `Sigra.Config` (outside the strict Phase 14 scope) or passes the module as an opt at call site. Verified: `lib/sigra/config.ex` not read in this research pass. |

**Recommended planner verification pass:** Before writing tasks, run:
```bash
grep -n "def get_organization" lib/sigra/organizations.ex
grep -rn "@behaviour Sigra.SessionStore" lib/
grep -n "defstruct\|:scope_module\|:scope" lib/sigra/config.ex
grep -n "create_session\|user_sessions" lib/sigra/auth.ex
grep -n "auth_error(conn, _" priv/templates/sigra.install/core/error_handler.ex
```
These five greps resolve A1, A4, A5, A6, A7, and A3 respectively.

## Open Questions

1. **Does `Sigra.Config` carry a `scope_module` field?**
   - What we know: Scope is a generated host module (`<%= context_module %>.Scope`); the library orchestrator in D-16 needs to call `YourApp.Accounts.Scope.put_active_organization/3` to get the updated scope.
   - What's unclear: Whether that resolution is via `config.scope_module` (cleanest) or via naming convention (`config.context_module |> Module.concat(Scope)`).
   - Recommendation: Planner reads `lib/sigra/config.ex` first. If `scope_module` exists, use it. If not, prefer naming convention and avoid bloating `Sigra.Config` in Phase 14; note the deviation from CONTEXT D-16's "resolved via `config.scope_module`" phrasing as Claude's discretion.

2. **Does OAuth login (`Sigra.Auth.login_oauth/4`) go through `create_session/4`?**
   - What we know: Login entry points exist for both password login and OAuth (`lib/sigra/auth.ex:58 log_in_user`, line 984 `create_session`, line 1191 `login_oauth`).
   - What's unclear: Whether OAuth inserts session rows via `create_session/4` or directly; D-12 says "call the selector once inside session-creation transaction" — if there are two session-creation paths, the selector lives in `create_session/4` only if that's the unified path.
   - Recommendation: Planner adds a task to read `login_oauth/4` end-to-end before choosing where the selector call goes. If OAuth inlines session creation, factor it through `create_session/4` first (may expand scope slightly) OR add the selector call to both paths (acceptable dup).

3. **Generated `organizations.ex` context wrapper — exact file path and how Phase 13's `Sigra.Install.Features.Organizations` registers it?**
   - What we know: Phase 13 shipped schemas into `priv/templates/sigra.install/organizations/` and a `Features.Organizations` module; no context wrapper template exists yet.
   - What's unclear: The naming convention — `organizations.ex` generated into host app at `lib/{app}/organizations.ex`? Or `lib/{app}/accounts/organizations.ex`?
   - Recommendation: Planner reads `lib/sigra/install/features/organizations.ex` to see how the schemas are emitted and mirrors that pattern for the new wrapper. Match the host-app's existing `lib/{app}/accounts.ex` context placement for consistency.

4. **Should `Sigra.Plug.LoadActiveOrganization` run for `auth_method: :api_token` requests?**
   - What we know: API tokens don't set `active_organization` on the scope (they carry scope strings instead); the LoadActiveOrganization plug's assign-a-scope-field-that-doesn't-exist-for-API-tokens is a no-op at best and confusing at worst.
   - What's unclear: Whether `LoadActiveOrganization` should short-circuit on `scope.auth_method == :api_token`, or run harmlessly because `session` will be nil in that path.
   - Recommendation: Planner adds an explicit short-circuit `if scope.auth_method == :api_token, do: conn` at the top of `call/2`. Mirrors the `RequireScopes` session-bypass pattern (`lib/sigra/plug/require_scopes.ex:72`) but inverted. Easier to reason about and eliminates a class of "why is this querying the org on an API request?" bugs.

## Sources

### Primary (HIGH confidence) — Verified in codebase
- `.planning/phases/14-org-plugs-scope-hydration/14-CONTEXT.md` (lines 1–350) — full 26-decision lock.
- `.planning/REQUIREMENTS.md` lines 27–35 — ORG-SCOPE-01..06 authoritative text.
- `.planning/ROADMAP.md` lines 103–115 — Phase 14 goal + success criteria.
- `.planning/STATE.md` — confirms Phase 12 complete (2026-04-12), Phase 13 complete (2026-04-12).
- `lib/sigra/plug/require_scopes.ex` (112 lines) — structural precedent, read in full.
- `lib/sigra/plug/error_handler.ex` (63 lines) — behaviour to extend, read in full.
- `lib/sigra/session_store.ex` (63 lines) — behaviour to extend, read in full.
- `priv/templates/sigra.install/core/scope.ex` — D-15 target, read in full.
- `priv/templates/sigra.install/core/user_auth.ex:120–231` — D-02 target range, read.
- `lib/sigra/auth.ex:978–1012` (`create_session/4`) — D-12 call site, read.
- `lib/sigra/organizations.ex` — grep confirms `get_membership/3`, `list_organizations_for_user/2`, absence of `select_active_organization/3`.
- `lib/sigra/audit.ex` — grep confirms `log_safe/2` at line 112.
- `ls` of `lib/sigra/plug/`, `lib/sigra/session_stores/`, `lib/sigra/organizations/`, `priv/templates/sigra.install/core/`, `priv/templates/sigra.install/organizations/` — structural verification.

### Secondary (MEDIUM confidence) — Cited from established docs, not session-verified
- [Phoenix 1.8 Scopes guide — augmenting scopes with organizations](https://hexdocs.pm/phoenix/scopes.html) — `put_organization/2` shape + plug/on_mount twin-callers pattern. [CITED: canonical_refs in CONTEXT]
- [`mix phx.gen.auth` 1.8.5 docs](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Auth.html) — Fetch/Require split precedent. [CITED]
- [OWASP Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) — session rotation on trust transitions, not scope transitions. [CITED]
- [Bodyguard](https://github.com/schrockwell/bodyguard), [Canada](https://github.com/jarednorman/canada), [Pundit](https://github.com/varvet/pundit) — set-membership role precedent. [CITED]

### Tertiary (LOW confidence)
None — Phase 14 is bounded by existing infrastructure; no speculative findings were needed.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps, all primitives verified in-repo.
- Architecture: HIGH — 26 decisions locked in CONTEXT, patterns verified against `RequireScopes` and `user_auth.ex`.
- Pitfalls: HIGH — drawn from `.planning/research/PITFALLS.md` O-5 + O-6 and the CONTEXT decisions that resolve each.
- Generator targets: MEDIUM — drift noted between CONTEXT's `auth_error_handler.ex` and actual `error_handler.ex`; generated org context wrapper does not yet exist.
- Integration points: MEDIUM — OAuth login path not verified to route through `create_session/4`; `Sigra.Config.scope_module` not verified present.

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (30 days; stable phase within an active milestone)
