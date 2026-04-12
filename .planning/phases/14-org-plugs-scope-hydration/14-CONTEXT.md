# Phase 14: Org Plugs + Scope Hydration - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 14 delivers the runtime layer that makes organizations visible at every authenticated request boundary — Plug pipeline AND LiveView `on_mount` — with **byte-identical** `%Scope{}` hydration on both paths. It also lands the single authoritative write path for "set the active organization" (`put_active_organization/2`), the non-halting `LoadActiveOrganization` plug, the halting `RequireMembership` plug, and the pure `select_active_organization/3` helper that drives the 0/1/2+ login flow.

This is the first phase where Phase 12's data shape (`%Sigra.Session{active_organization_id}`, `user_sessions.active_organization_id` column, `%Scope{active_organization, membership}` fields) is **consumed** at request time, and the first phase where Phase 13's `Sigra.Organizations` context is called from the transport layer.

**In scope:**
- `Sigra.Scope.Hydration.hydrate/3` — pure library function consuming `(scope, config, %Sigra.Session{})` and returning `{:ok, scope}` or a fail-closed error. Single implementation shared by plug and `on_mount`.
- `Sigra.Plug.LoadActiveOrganization` — library plug; reads `conn.private[:sigra_session]`, calls the hydrator, handles stale pointers inline via `select_active_organization/3`, **never halts**.
- `Sigra.Plug.RequireMembership` — library plug; asserts `scope.active_organization` + optional role filter; delegates failures to host `AuthErrorHandler`; halts.
- `Sigra.Organizations.select_active_organization(config, user, opts)` — pure 0/1/2+ selector. Called from login (once) and from stale-pointer recovery. Returns `{:ok, org} | {:none, :zero_orgs} | {:multiple, [org]}`.
- `Sigra.Plug.put_active_organization(conn, org | nil)` — impure orchestrator. Single authoritative write site: DB column, `conn.private[:sigra_session]`, `conn.assigns[:current_scope]`. No Plug session cookie write. No session token rotation.
- `put_active_organization/3` pure function added to generated `Scope` template (matches Phoenix 1.8 scopes guide `put_organization/2` precedent).
- LiveView parity: generated `on_mount` switches to `get_user_and_session_by_token` so LV has the full `%Sigra.Session{}` and calls the shared hydrator.
- `Sigra.SessionStore` behaviour + ecto impl gain `update_active_organization/3`.
- `Sigra.Plug.ErrorHandler` behaviour gains two new error types: `:no_active_org` and `:insufficient_role`. Generated `AuthErrorHandler` gains matching clauses.
- Login-time 0/1/2+ selection: `Sigra.Auth.create_session/4` (or the equivalent login entry point) runs the selector once, writes the session row, leaves nil on 0-org and 2+-with-no-resume-pointer cases.
- Parity test (SC-3) covering login, post-switch, stale-pointer, revoked-membership.
- Stale-pointer regression test (SC-1).
- Role-filter regression test (SC-2).
- 0/1/2+ login-flow test (SC-4).
- Audit call site on stale transition via `Sigra.Audit.log_safe/2` (`"organization.active_auto_reassigned"`) — forward-compat with Phase 15.

**Out of scope (belongs in later phases):**
- POST org-switch controller + switcher UI — Phase 16.
- Create-first-org LiveView + no-org landing page UI — Phase 16.
- Multi-tab cross-request re-verification test — Phase 16 (LiveView-specific).
- `audit_events.organization_id` real column + `metadata_from_scope/2` — Phase 15.
- Invitation accept flow — Phase 17.
- `--no-organizations` generator conditionality — Phase 18.
- ETS membership cache / cross-request memoization — v1.2 if profiling shows pressure.
- Per-request rate limiting on stale recovery — out of scope; existing Hammer rate limiter is sufficient.
- `Sigra.Session.put_active_organization_id/2` named setter — remains deferred; `put_active_organization/2` is the API, and callers never touch `%Sigra.Session{}` directly.

</domain>

<decisions>
## Implementation Decisions

### Architecture: Plug↔LiveView Parity via Shared Hydrator

- **D-01:** **Shared library function `Sigra.Scope.Hydration.hydrate/3` is the single source of scope hydration.** Both `Sigra.Plug.LoadActiveOrganization` (plug path) and the generated `UserAuth.on_mount(:mount_current_scope, ...)` (LV path) call it with the same arguments: `(scope, config, %Sigra.Session{})`. The function is pure — it reads `session.active_organization_id`, calls `Sigra.Organizations.get_membership/3`, looks up the org, and returns a fully populated `%Scope{}` or a fail-closed error tuple. SC-3 byte-identical parity collapses to "both paths feed the same hydrator the same `%Sigra.Session{}`" — a single function-level test replaces an end-to-end parity harness.

  **Why:** Phoenix 1.8 scopes guide tolerates duplication (plug + `on_mount` both call the same context function); Sigra takes one step further and factors it into a library module because the hydrator owns the fail-closed contract for stale pointers and revoked memberships. That contract is security-sensitive and belongs in the library per the Phase 13 library-first model.

- **D-02:** **LiveView switches from `get_user_by_session_token` to `get_user_and_session_by_token` in the generated `mount_current_scope`.** Both functions already exist in the generated auth context (Phase 10). `fetch_current_scope` at line 132 of `user_auth.ex` already uses `get_user_and_session_by_token`; the LV path at line 226 is the lone caller of the user-only variant and gets upgraded in Phase 14. Cost: one JOIN on an already-fetched indexed row — marginal. Benefit: LV now has the full `%Sigra.Session{}` and can call the same hydrator as the plug path.

- **D-03:** **No mirroring of `active_organization_id` into the Plug session cookie.** The DB column `user_sessions.active_organization_id` is the sole authoritative storage; the Plug session cookie carries only `:user_token` (unchanged from v1.0). Mirroring would create a two-writer consistency hazard (pitfall O-5) and violate Phase 12's "DB row is source of truth" invariant. This decision explicitly overrides an earlier research suggestion to cookie-mirror the pointer.

  **Consequence:** `on_mount` does one DB query for `{user, %Sigra.Session{}}`, then calls `Hydration.hydrate/3`. No cookie state to keep in sync on login, switch, or stale recovery.

### The Three Request-Time Plugs

- **D-04:** **`Sigra.Plug.LoadActiveOrganization` never halts.** This matches the `phx.gen.auth` Fetch/Require split where Fetch plugs mutate assigns and Require plugs halt. The Load plug:
  1. Skips if `conn.assigns[:current_scope]` is nil (no authenticated user).
  2. Reads `session = conn.private[:sigra_session]`.
  3. If `session.active_organization_id` is nil, assigns `%Scope{active_organization: nil, membership: nil}` and returns.
  4. If set, calls `Sigra.Scope.Hydration.hydrate(scope, config, session)`. On `{:ok, scope}`, assigns the hydrated scope and returns.
  5. On `{:error, :not_a_member}` or `{:error, :org_not_found}` (stale-pointer), invokes `Sigra.Plug.put_active_organization(conn, nil)` → then `Sigra.Organizations.select_active_organization(config, user, previous: nil)` → if `{:ok, org}`, calls `put_active_organization(conn, org)` and returns. Otherwise leaves scope with nil active_organization. Emits `Sigra.Audit.log_safe("organization.active_auto_reassigned", %{from: stale_id, to: new_id_or_nil})`.

- **D-05:** **`Sigra.Plug.RequireMembership` is the only plug in this phase that halts.** Matches existing `Sigra.Plug.RequireScopes` structure verbatim:
  - `init/1` requires `:error_handler` (module implementing `Sigra.Plug.ErrorHandler`), accepts optional `:roles` list.
  - Validates `:roles` is a subset of the host's `@sigra_org_config[:roles]` at `init/1`. Raises `ArgumentError` with a helpful message on typos — fails at compile time, not at request time.
  - `call/2`: if `scope.active_organization == nil`, calls `error_handler.auth_error(conn, :no_active_org, opts) |> halt()`. If membership role not in the required set, calls `error_handler.auth_error(conn, :insufficient_role, Keyword.put(opts, :required_roles, required)) |> halt()`. Otherwise passes through.
  - Reads `scope.membership.role` from assigns — does NOT re-query the DB. The membership lookup was already done in `LoadActiveOrganization` and stashed on the scope struct.

- **D-06:** **Set-membership role semantics, not hierarchical.** `roles: [:owner, :admin]` means "role must be one of these atoms." Hierarchical ordering (`[:owner]` implies `:admin`) is a well-documented trap — every mature Elixir authz lib (Bodyguard, Canada, Phoenix 1.8 scopes) uses set membership for exactly this reason. The Phase 13 config's `roles` list is the *universe*; the plug's `:roles` option is a *subset filter*.

- **D-07:** **Default when `:roles` is omitted = any membership accepted.** Pundit/Bodyguard/Phoenix scopes all default to this. Forcing explicit role declarations would add boilerplate to the 80% path (any member can view the dashboard). Hosts who want owner-only routes write `roles: [:owner]` — short and obvious.

### ErrorHandler Extension

- **D-08:** **Extend the existing `Sigra.Plug.ErrorHandler` behaviour with two new error types: `:no_active_org` and `:insufficient_role`.** Matches the shape of existing `:unauthenticated | :stale_sudo | :rate_limited | :insufficient_scope | :token_expired | :token_revoked | :mfa_required`. The `@type error_type ::` union in `lib/sigra/plug/error_handler.ex` gets two additions. Host devs customize the landing page and 403 response by editing the **same file** they already edit for auth errors — one knob, one mental model, principle of least surprise.

- **D-09:** **Generator adds two new clauses to `priv/templates/sigra.install/core/auth_error_handler.ex`** (or equivalent). Default behaviors:
  - `auth_error(conn, :no_active_org, _opts)` → `put_flash(:info, "Pick or create an organization to continue.") |> redirect(to: ~p"/organizations")`.
  - `auth_error(conn, :insufficient_role, opts)` → `put_flash(:error, "You don't have permission...") |> put_status(:forbidden) |> put_view(ErrorHTML) |> render(:"403") |> halt()`.
  Phase 18 (`--no-organizations`) makes these clauses conditional on the feature flag.

- **D-10:** **No NimbleOptions config for `landing_path` / `access_denied_path`.** The paths live in the generated error handler clauses above. This is consistent with how every existing Sigra plug handles redirect targets — none of them accept init-time paths; they all delegate to the error handler. Zero new configuration surface for Phase 14.

### 0/1/2+ Selection + Stale Recovery

- **D-11:** **`Sigra.Organizations.select_active_organization(config, user, opts)` is a pure helper.** No side effects, no session writes, no audit. Returns `{:ok, org} | {:none, :zero_orgs} | {:multiple, [org]}`. Accepts `opts`:
  - `:previous_active_organization_id` — if the user has 2+ orgs and one matches this pointer, return `{:ok, that_org}` (resume semantics). On stale recovery this is passed as nil — the stale pointer must not be resumed.
  - `:strategy` (reserved for v1.2, default `:most_recent`) — how to pick among multiple when no resume pointer matches. v1.1 default: `{:multiple, orgs}` returned as-is; caller decides.

- **D-12:** **Login calls the selector exactly once, inside the session-creation transaction.** `Sigra.Auth.create_session/4` (or equivalent login entry point; planner verifies the exact name in `lib/sigra/auth.ex`) inserts the session row, calls `select_active_organization/3`, and on `{:ok, org}` writes `active_organization_id` to the row in the same `Repo.transact/2`. On `{:none, :zero_orgs}` or `{:multiple, _}`, leaves the column nil. Login always succeeds; it never redirects to a picker or landing itself — those are RequireMembership's job on the next request.

- **D-13:** **"Per-session, not per-user" falls out for free** because the pointer lives on `user_sessions.active_organization_id`. Device 1 and device 2 each have their own session row, so tab-A-on-org-X and tab-B-on-org-Y coexist naturally. Phase 14 does not add any "last active org" field on the `users` table — ROADMAP SC-4's "per-session, not per-user" is an architectural property inherited from Phase 12.

- **D-14:** **Stale-pointer policy: hybrid (reset + immediate re-select via the same helper).** `LoadActiveOrganization`'s stale-recovery path (D-04 step 5) clears the session row, invokes `select_active_organization/3` with `previous: nil`, and writes whatever the selector returns. This reconciles the apparent conflict between ROADMAP SC-1 ("silently reset to nil") and PITFALLS O-6 ("pick first remaining, audit the transition"): SC-1 describes the *observable end state when nothing remains to pick* (0-org case); O-6 describes the *mechanism* when something does remain. Both are satisfied by running the same selector used at login. One audit event (`organization.active_auto_reassigned`) on any transition, via `log_safe/2` — no-op-safe until Phase 15 lands the real `organization_id` column.

### put_active_organization: Pure + Impure Split

- **D-15:** **Pure function `Scope.put_active_organization/3` lives on the generated `Scope` template.** Exact shape (matches Phoenix 1.8 scopes guide `put_organization/2`):

  ```elixir
  def put_active_organization(%__MODULE__{} = scope, %Organization{} = org, %OrganizationMembership{} = membership) do
    %{scope | active_organization: org, membership: membership}
  end

  def put_active_organization(%__MODULE__{} = scope, nil, nil) do
    %{scope | active_organization: nil, membership: nil}
  end
  ```

  Generated, app-owned, dialyzer-friendly, trivially unit-testable. Phoenix 1.8 guide compliance is absolute here — D-08 of Phase 12 locked this shape.

- **D-16:** **Impure orchestrator `Sigra.Plug.put_active_organization(conn, org_or_nil)` lives in the library.** Single authoritative write site for "set the active org." It:
  1. Reads `session = conn.private[:sigra_session]`.
  2. For `org != nil`: calls `Sigra.Organizations.get_membership(config, user, org)`. On miss, returns `{:error, :not_a_member}`.
  3. Calls `Sigra.SessionStore.update_active_organization(session, org_id_or_nil)` — the single DB write. Returns refreshed `%Sigra.Session{}`.
  4. Calls the host's `Scope.put_active_organization/3` (module name resolved via `config.scope_module`) to produce an updated `%Scope{}`.
  5. Puts the refreshed session back on `conn.private[:sigra_session]` and assigns the new scope on `conn.assigns[:current_scope]`.
  6. Returns `{:ok, conn}`.

  Returns `{:error, reason}` on failure; the caller (login, switch controller, stale recovery) decides how to surface it.

- **D-17:** **No Plug session cookie write in `put_active_organization`.** Consistent with D-03. The active org is NOT persisted in the signed session cookie — only `:user_token` lives there. Writing `put_session(:active_organization_id, id)` would create two writers to the same logical state; that is exactly pitfall O-5.

- **D-18:** **No session token rotation on org switch.** Scope transition ≠ trust transition. Rotating `:user_token` on every org switch would drop LiveView connections, flicker every open tab, and buy zero security benefit (CSRF tokens + per-request membership re-verification already close the relevant threat windows). Every reference implementation (Jetstream `switchTeam`, Clerk, acts_as_tenant) skips rotation. `renew_session` stays scoped to `log_in_user` / `log_out_user`.

- **D-19:** **Thin generated wrapper `MyOrgs.set_active_organization/2` in the generated organizations context** for discoverability:

  ```elixir
  defdelegate set_active_organization(conn, org), to: Sigra.Plug, as: :put_active_organization
  ```

  Host devs writing the switch controller call `MyOrgs.set_active_organization(conn, org)` — one obvious entry point, parallel to `create_organization/update_organization`. All security-sensitive work happens inside the library.

### Session Store API

- **D-20:** **`Sigra.SessionStore` behaviour gains `update_active_organization/3`.** Signature: `update_active_organization(session, org_id_or_nil)` returning `{:ok, %Sigra.Session{}}` or `{:error, term()}`. Default ecto impl does a single indexed `UPDATE user_sessions SET active_organization_id = $1 WHERE id = $2 RETURNING *`. No-op-safe when `org_id` equals the current value (skip the write) — cheap optimization.

### Per-Conn Membership Memoization

- **D-21:** **Membership is memoized in `scope.membership` — no separate cache.** `LoadActiveOrganization` fetches membership once, stashes it on the scope struct (a Phase 12 field), and downstream plugs (`RequireMembership`) read from assigns. Zero extra DB queries per request beyond the one Load already does. Cross-request ETS caching is explicitly deferred to v1.2 if profiling shows real pressure — the invalidation surface (must fire on `remove_member`, `change_role`, `soft_delete_organization`) is not worth the surface area for v1.1.

### Library vs Generated Boundary (Phase 14 Edition)

- **D-22:** **Every new module created in Phase 14 lives in the library.** `lib/sigra/scope/hydration.ex`, `lib/sigra/plug/load_active_organization.ex`, `lib/sigra/plug/require_membership.ex`, `lib/sigra/plug/put_active_organization.ex` (or a function on `Sigra.Plug`). The only generated edits are:
  - `priv/templates/sigra.install/core/scope.ex` — add `put_active_organization/3` pure function (D-15).
  - `priv/templates/sigra.install/core/user_auth.ex` — switch LV `on_mount` to use `get_user_and_session_by_token` and call the shared hydrator (D-02).
  - `priv/templates/sigra.install/core/auth_error_handler.ex` — add two new clauses (D-09).
  - Generated router pipelines gain `plug Sigra.Plug.LoadActiveOrganization` after `fetch_current_scope` in the `:browser_authenticated` pipeline (or equivalent).
  - Generated `organizations.ex` wrapper gains the `set_active_organization/2` defdelegate (D-19).

  This is the tightest possible generated surface — consistent with the Phase 13 library-first philosophy.

### Verification

- **D-23:** **SC-3 parity test collapses to a `Sigra.Scope.Hydration.hydrate/3` unit test.** Both paths (plug + on_mount) are verified to call the hydrator with equivalent inputs via two thin wiring tests; the hydrator's behavior is the real contract under test. Eliminates the combinatorial "login × switch × stale × revoked" end-to-end test matrix.

- **D-24:** **SC-1 stale-pointer regression test**: create user + org + membership → log in → revoke membership → next request → assert `scope.active_organization == nil` (on 0-orgs case) or asserted reassigned org (on ≥1-remaining case) + assert no 500 + assert audit event emitted via `log_safe`.

- **D-25:** **SC-2 role-filter regression test**: user with `:member` role hits `RequireMembership, roles: [:owner]` → assert `error_handler.auth_error(conn, :insufficient_role, required_roles: [:owner])` called + halted. Companion test for missing org → `:no_active_org`.

- **D-26:** **SC-4 0/1/2+ login-flow test** for `select_active_organization/3` as a pure unit test: 0 memberships → `{:none, :zero_orgs}`; 1 membership → `{:ok, org}`; 2+ with matching resume pointer → `{:ok, resumed_org}`; 2+ without resume pointer → `{:multiple, orgs}`. Plus one integration test asserting `Sigra.Auth.create_session/4` writes the correct `active_organization_id` for each case.

### Claude's Discretion

- **CD-01:** **Exact location of the `put_active_organization/2` orchestrator** — whether `Sigra.Plug.put_active_organization/2` as a standalone module function, `Sigra.Plug.LoadActiveOrganization.put/2`, or `Sigra.Organizations.Runtime.put_active_organization/2`. Planner picks based on where it reads best alongside existing `lib/sigra/plug/*.ex` modules. The behavior is fixed by D-16.
- **CD-02:** **Audit event name** — `"organization.active_auto_reassigned"` vs `"organizations.active_auto_reassigned"` vs other shapes. Planner picks the form consistent with existing Sigra audit action naming (check `lib/sigra/audit.ex` for precedent).
- **CD-03:** **Whether `Sigra.Scope.Hydration.hydrate/3` lives at `lib/sigra/scope/hydration.ex` or `lib/sigra/organizations/scope_hydration.ex`.** Behavior is fixed by D-01; exact filepath is a style call.
- **CD-04:** **`select_active_organization/3` implementation details** — how "most recent" is defined if multiple memberships exist without a resume pointer. v1.1 default returns `{:multiple, orgs}` unsorted; the planner may choose to sort by `inserted_at desc` for stable ordering.
- **CD-05:** **Test file organization** — which new tests go in existing files vs new files under `test/sigra/plug/` and `test/sigra/scope/`. Planner picks based on conventions in adjacent test files.
- **CD-06:** **Whether `SessionStore.update_active_organization/3` is a new callback on the behaviour or an extension function in the ecto impl alone.** If all existing `SessionStore` impls need the capability (likely, since there's only one), a new callback is clearer. Planner verifies the impl count.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` line 31 — **ORG-SCOPE-03**: `Sigra.Plug.LoadActiveOrganization` contract, stale-pointer reset. Source of D-04, D-14.
- `.planning/REQUIREMENTS.md` line 32 — **ORG-SCOPE-04**: `Sigra.Plug.RequireMembership` + optional role filter. Source of D-05, D-06, D-07.
- `.planning/REQUIREMENTS.md` line 33 — **ORG-SCOPE-05**: LV `on_mount` parity with plug path. Source of D-01, D-02, D-23.
- `.planning/REQUIREMENTS.md` line 34 — **ORG-SCOPE-06**: 0/1/2+ login-flow handling. Source of D-11, D-12, D-13.
- `.planning/ROADMAP.md` Phase 14 entry — goal, success criteria, depends-on Phases 12 and 13, pitfalls O-5 + O-6.

### Prior Phase Context
- `.planning/phases/12-scope-session-foundation/12-CONTEXT.md` D-04 — `%Sigra.Session{active_organization_id}` first-class field. Phase 14 consumes this.
- `.planning/phases/12-scope-session-foundation/12-CONTEXT.md` D-05 — named setter deferred to Phase 14 (now D-16/D-19).
- `.planning/phases/12-scope-session-foundation/12-CONTEXT.md` D-08 — `%Scope{}` defstruct shape; Phoenix 1.8 `put_organization/2` precedent locked. Source of D-15.
- `.planning/phases/13-organizations-schemas-context/13-CONTEXT.md` §downstream "Phase 14" — plugs are library modules, not generated. Source of D-22.
- `.planning/phases/13-organizations-schemas-context/13-CONTEXT.md` D-01/D-02 — library-first philosophy; thin generated wrapper. Source of D-19, D-22.
- `.planning/phases/13-organizations-schemas-context/13-CONTEXT.md` D-13 — `for_org/2` tenant scoping (Phase 14 doesn't alter this; mentioned for context).
- `.planning/phases/13-organizations-schemas-context/13-CONTEXT.md` D-20 — `log_safe/2` usage pattern. Source of D-14 audit decision.

### Pitfalls
- `.planning/research/PITFALLS.md` §O-5 (cross-org session confusion) — mitigated by D-03 (single writer), D-05 (per-request re-verification), D-17 (no cookie mirror).
- `.planning/research/PITFALLS.md` §O-6 (stale `active_organization_id`) — mitigated by D-04 step 5 + D-14 (hybrid reset + re-select).

### Phoenix 1.8 Precedent
- [Phoenix 1.8 Scopes guide — augmenting scopes with organizations](https://hexdocs.pm/phoenix/scopes.html) — authoritative source for `put_organization/2` shape (D-15) and the plug + on_mount twin-callers pattern (D-01).
- [`mix phx.gen.auth` v1.8.5](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Auth.html) — Fetch/Require split precedent. `fetch_current_scope_for_user` never halts; `require_authenticated_user` does. Source of D-04/D-05 separation.

### Elixir / Authz Library Precedent
- [Bodyguard](https://github.com/schrockwell/bodyguard), [Canada](https://github.com/jarednorman/canada), [Phoenix 1.8 scopes](https://hexdocs.pm/phoenix/scopes.html) — all use set-membership role matching. Source of D-06.
- [Pundit](https://github.com/varvet/pundit) (Ruby) — "authenticated is enough by default" semantics. Source of D-07.

### Security / Session Rotation
- [OWASP Session Management Cheat Sheet — session rotation](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) — rotation guidance for trust transitions, not scope transitions. Source of D-18.

### Existing Sigra Code (precedent + modification targets)
- `lib/sigra/plug/require_authenticated.ex` — library-plug shape; error_handler delegation pattern. Source of D-05 structure.
- `lib/sigra/plug/require_scopes.ex` — closest structural match for `RequireMembership` (multi-failure, opts validation, error_handler delegation). **Mimic this file's structure exactly** for Phase 14's `RequireMembership`.
- `lib/sigra/plug/error_handler.ex` — behaviour to extend in D-08. Read this before planning the new error types.
- `lib/sigra/plug/require_mfa.ex` — **do NOT copy this pattern** for `RequireMembership`. Uses plug-init path options; legacy pattern; D-10 explicitly rejects this for RequireMembership.
- `lib/sigra/plug/fetch_session.ex` — likely location of the `fetch_current_scope` plug counterpart; read to confirm where `conn.private[:sigra_session]` gets stashed.
- `lib/sigra/session.ex` — `%Sigra.Session{}` struct with `:active_organization_id` field (Phase 12).
- `lib/sigra/session_store.ex` — behaviour to extend with `update_active_organization/3` (D-20).
- `lib/sigra/session_stores/*.ex` — impls that must implement the new callback.
- `lib/sigra/organizations.ex` — add `select_active_organization/3` (D-11).
- `lib/sigra/organizations/query.ex` — existing `get_membership/3` and `list_organizations_for_user/2` that `select_active_organization/3` composes over.
- `lib/sigra/audit.ex` — `log_safe/2` for D-14 audit emission.
- `lib/sigra/auth.ex` — login entry point (`create_session/4` or equivalent) that runs the selector at login time per D-12. Planner verifies the exact function name.

### Generated Templates to Modify
- `priv/templates/sigra.install/core/scope.ex` — add `put_active_organization/3` pure functions (D-15).
- `priv/templates/sigra.install/core/user_auth.ex` — switch `mount_current_scope` to use `get_user_and_session_by_token`; call `Sigra.Scope.Hydration.hydrate/3` from both the plug pipeline and the on_mount callback (D-01, D-02). Line references: plug `fetch_current_scope` at line 128; `on_mount(:mount_current_scope, ...)` at line 193; `mount_current_scope` helper at line 222.
- `priv/templates/sigra.install/core/auth_error_handler.ex` — add `:no_active_org` and `:insufficient_role` clauses (D-09).
- Generated `organizations.ex` wrapper (template location TBD — check `priv/templates/sigra.install/organizations/` or equivalent) — add `set_active_organization/2` defdelegate (D-19).
- Generated router template — add `plug Sigra.Plug.LoadActiveOrganization` after `fetch_current_scope`; add new pipelines `:require_org` and `:require_org_owner` using `RequireMembership` with the app's error handler (D-09, D-22).

### Files to Create (library side)
- `lib/sigra/scope/hydration.ex` — D-01, D-23.
- `lib/sigra/plug/load_active_organization.ex` — D-04.
- `lib/sigra/plug/require_membership.ex` — D-05 through D-07.
- `lib/sigra/plug/put_active_organization.ex` (or equivalent, per CD-01) — D-16 through D-19.
- `test/sigra/scope/hydration_test.exs` — D-23.
- `test/sigra/plug/load_active_organization_test.exs` — D-24.
- `test/sigra/plug/require_membership_test.exs` — D-25.
- `test/sigra/organizations_test.exs` additions — D-26 (select_active_organization cases).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`fetch_current_scope` already stashes `%Sigra.Session{}` on `conn.private[:sigra_session]`** (line 140 of `user_auth.ex`). Phase 14's plugs consume this directly — no new instrumentation needed.
- **`get_user_and_session_by_token` already exists** as a generated context function (used by `fetch_current_scope` at line 132). Phase 14 switches the LV path to use the same function, achieving parity.
- **`Sigra.Plug.RequireScopes`** is the closest structural precedent for `RequireMembership` — same multi-failure-mode shape, same error_handler delegation, same init-time option validation. Phase 14's `RequireMembership` should mirror its file layout.
- **`Sigra.Plug.ErrorHandler` behaviour** already supports multiple error types via an open union. Adding `:no_active_org` and `:insufficient_role` is a pure additive change — existing handler implementations don't break.
- **`Sigra.Organizations.get_membership/3` and `list_organizations_for_user/2`** (Phase 13) are the primitives `hydrate/3` and `select_active_organization/3` compose over.
- **`Sigra.Audit.log_safe/2`** is no-op-safe when the `audit_events.organization_id` column doesn't yet exist (Phase 13 WR-04/WR-05 fail-closed pattern + telemetry on changeset error). Phase 14 can emit the stale-pointer audit event today; it auto-lights-up when Phase 15 ships the real column.
- **`Sigra.Session` struct field ordering** (Phase 12) already positions `active_organization_id` between `:sudo_at` and `:inserted_at` — the hydrator reads it directly.

### Established Patterns
- **Library plug → error handler delegation** — every recent library plug (`RequireAuthenticated`, `RequireScopes`, `RequireSudo`) calls the host's `error_handler.auth_error(conn, type, opts)` then halts. `RequireMembership` MUST follow this pattern exactly; do not invent new init-option paths.
- **Fetch/Require split** (inherited from `phx.gen.auth`) — Fetch plugs mutate assigns and return; Require plugs halt with redirect. `LoadActiveOrganization` is a Fetch plug; `RequireMembership` is a Require plug.
- **Pure struct functions on generated Scope** — Phoenix 1.8 `put_organization/2` precedent (locked in Phase 12 D-08). `Scope.put_active_organization/3` is a two-line struct update, nothing more.
- **`log_safe/2` at context-function call sites** (Phase 13 D-20) — Phase 14 emits exactly one audit event via this helper, on stale-pointer transition only. Login and normal requests emit no Phase-14-owned audit events (existing login audit is Phase 10; membership-change audits are Phase 13).
- **Plug init-time validation** (`lib/sigra/plug/require_scopes.ex`) — raise `ArgumentError` with a clear message when config is malformed. D-05 applies this to role-subset validation.

### Integration Points
- **`lib/sigra/plug/fetch_session.ex`** (or wherever `fetch_current_scope` logic lives) — Phase 14's `LoadActiveOrganization` runs immediately after this in the `:browser_authenticated` pipeline.
- **`lib/sigra/auth.ex`** login entry point — one call site added to invoke `select_active_organization/3` and write the initial `active_organization_id` on login.
- **Generated router pipelines** — `:browser_authenticated` gains `plug Sigra.Plug.LoadActiveOrganization`; new `:require_org` and `:require_org_owner` pipelines get added.
- **Generated `user_auth.ex` `on_mount` callback** (lines 193-220) — one internal function (`mount_current_scope`) gets replaced; the three public `on_mount` clauses keep their signatures.
- **Generated `AuthErrorHandler`** — two new clauses; existing clauses unchanged.

### Creative Options
- **`Sigra.Scope.Hydration.hydrate/3` could become the single entry point for all future scope augmentation** (passkeys scope, impersonation scope, feature-flag scope). Phase 14 establishes the pattern; later phases add fields to the scope and extend the hydrator. Worth keeping the API narrow now so extension is additive.
- **`select_active_organization/3` with `:strategy` option** leaves room for v1.2 "most recently active" semantics driven by an `active_organizations` table or a `last_active_at` column on memberships. v1.1 uses the default strategy only.

</code_context>

<specifics>
## Specific Ideas

- **The cookie-mirror debate was resolved in favor of "no mirror."** Earlier research suggested mirroring `active_organization_id` into the signed Plug session cookie so `on_mount` could read it without a DB query. This was rejected after considering pitfall O-5 (cross-org session confusion): two writers to the same logical state is exactly the hazard we're trying to avoid. LiveView pays one additional JOIN on an already-fetched row — marginal cost, and it preserves Phase 12's "DB row is source of truth" invariant.

- **The hydrator is the real contract under test.** Phase 14's SC-3 parity test does not need to be a combinatorial end-to-end matrix. The contract is "both entry points call `Sigra.Scope.Hydration.hydrate/3` with equivalent inputs," so the parity test becomes two thin wiring tests plus a rich unit test on the hydrator. This is the kind of refactor-for-testability that pays back on every future phase that extends the scope.

- **Phase 14 is also the shakedown cruise for library-first plugs + Phase 13's context.** `Sigra.Organizations.get_membership/3` and `list_organizations_for_user/2` are consumed at request time for the first time. If any API shape is wrong, Phase 14 is the last cheap time to fix it before Phase 16's LiveViews bake in assumptions.

- **`select_active_organization/3` is deliberately dumb in v1.1.** It doesn't try to be smart about "which org was the user looking at most recently" or "which org has unread notifications" or any other product signal. Just: 0 → none, 1 → auto, 2+ with resume → resume, 2+ without resume → list. Every product-side refinement lives in a host-app override or a v1.2 strategy function. Keep the v1.1 contract narrow.

- **`put_active_organization/2` is the single write path.** Every Phase 14+ call site that needs to set, clear, or change the active org goes through `Sigra.Plug.put_active_organization/2`. No ad-hoc `put_session` calls, no direct `update_all` on `user_sessions`, no shortcuts. Phase 16's switcher controller, Phase 17's invitation accept flow, Phase 18's backfill upgrade — all funnel through this helper.

- **Per-session, not per-user, is an architectural inheritance, not a Phase 14 invention.** The `active_organization_id` column lives on `user_sessions`, not on `users`. Phase 14 adds no new state that would need "last active org" tracking at the user level. If a future phase wants cross-device "pick up where you left off" semantics, it adds a separate `users.last_active_organization_id` column — but that's a product decision and v1.1 explicitly does not make it.

</specifics>

<deferred>
## Deferred Ideas

- **ETS cross-request membership cache** — v1.2 if profiling shows pressure. Requires invalidation on `remove_member`, `change_role`, `soft_delete_organization`. Not worth the surface area for v1.1 (D-21).

- **Hierarchical roles (`[:owner]` implies `:admin`)** — not in Sigra's future. Set-membership is the long-term answer (D-06).

- **`users.last_active_organization_id` cross-device resume pointer** — product decision; not in v1.1. Current "per-session" semantics are intentional (D-13).

- **`:strategy` option for `select_active_organization/3`** — reserved for v1.2 or later. v1.1 uses the default (CD-04, D-11).

- **Session token rotation on org switch** — explicitly rejected for Sigra (D-18). Reconsider only if a real threat emerges.

- **`Sigra.Session.put_active_organization_id/2` named setter** (Phase 12 D-05) — stays deferred. Callers use `put_active_organization/2` (the orchestrator) or the thin `MyOrgs.set_active_organization/2` wrapper; nobody should be touching `%Sigra.Session{}` directly to set this field.

- **Cookie-mirrored `active_organization_id`** — rejected (D-03, D-17). Revisit only if a compelling perf argument emerges with benchmarks.

- **LV attach_hook-based scope hydration** — rejected as architecture; does not actually solve parity (the hook still runs in the LV process with only the session map). Phase 14's shared hydrator approach is simpler and correct.

- **Stale-pointer Oban job to invalidate sessions after membership removal** (PITFALLS O-6 bullet 3) — "optional but safer." Phase 14's request-time recovery handles the correctness case (no 500, no wrong org); an Oban-based proactive cleanup is a v1.2+ polish item. Capture as backlog.

- **Cross-tab scope drift detection** (PITFALLS O-5 LV `handle_params` re-check) — lives in Phase 16's LiveView work, not Phase 14's plug layer. Phase 14 ships the data guarantees; Phase 16 ships the LV UX for forcing a push_navigate on drift.

</deferred>

<downstream>
## Downstream Phase Implications

### Phase 15 (Audit Integration)
- The `"organization.active_auto_reassigned"` audit event (D-14) lands with `log_safe/2`. Phase 15 upgrades it to use `metadata_from_scope/2` and adds `organization_id` to the payload.
- `LoadActiveOrganization` already has a hydrated scope at emission time — Phase 15's `metadata_from_scope/2` just consumes it.

### Phase 16 (Org LiveViews + Switcher)
- `OrganizationSwitchController.update/2` calls `MyOrgs.set_active_organization(conn, org)` (D-19) — no new library surface needed.
- Switch is a POST (matches D-29 from v1.0); the controller is thin because `put_active_organization/2` owns all writes.
- No-org landing page and 0-org registration flow are UI work — Phase 14 leaves `scope.active_organization = nil` and `RequireMembership` redirects to the configured path; Phase 16 builds that page.
- Multi-tab scope drift detection (PITFALLS O-5) lands as LV `handle_params` re-check.

### Phase 17 (Invitations)
- Invitation accept flow calls `Sigra.Organizations.add_member/4` (Phase 13) then `MyOrgs.set_active_organization(conn, new_org)` to land the user in the new org. No new Phase 14 surface.

### Phase 18 (Generator Wiring)
- `--no-organizations` gates the router pipelines, `AuthErrorHandler` clauses, Scope template fields, `on_mount` wiring, and the `set_active_organization/2` defdelegate. All of these are the generated surface Phase 14 added — conditional removal is purely additive.
- The library modules (`LoadActiveOrganization`, `RequireMembership`, `Hydration`, `put_active_organization`) always compile — they're inert when no organizations table exists.

### v1.2 (Impersonation)
- `scope.impersonating_from` (Phase 12 reserved field) gets populated via the same `put_active_organization/2` orchestrator path — v1.2 adds a `put_impersonation/3` sibling that's structurally identical.
- `Sigra.Scope.Hydration.hydrate/3` gets extended to also hydrate `impersonating_from` from the session (or wherever v1.2 stores the impersonator pointer). Phase 14's contract stays unchanged.

</downstream>

---

*Phase: 14-org-plugs-scope-hydration*
*Context gathered: 2026-04-12*
