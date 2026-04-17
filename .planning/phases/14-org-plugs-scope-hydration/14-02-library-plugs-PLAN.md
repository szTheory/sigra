---
phase: 14
plan: 2
type: execute
wave: 2
depends_on: [1]
files_modified:
  - lib/sigra/plug/load_active_organization.ex
  - lib/sigra/plug/require_membership.ex
  - lib/sigra/plug/put_active_organization.ex
  - test/sigra/plug/load_active_organization_test.exs
  - test/sigra/plug/require_membership_test.exs
  - test/sigra/plug/put_active_organization_test.exs
autonomous: true
requirements:
  - ORG-SCOPE-03
  - ORG-SCOPE-04
must_haves:
  truths:
    - "Sigra.Plug.LoadActiveOrganization assigns a hydrated scope when session.active_organization_id points at a live membership"
    - "Sigra.Plug.LoadActiveOrganization NEVER halts — plug pipeline continues on all success and all stale/invalid cases"
    - "Stale pointer (revoked membership) triggers session reset + select_active_organization/3 re-run + audit event emission"
    - "Sigra.Plug.RequireMembership halts with :no_active_org when scope.active_organization is nil"
    - "Sigra.Plug.RequireMembership halts with :insufficient_role when membership.role is not in the required role list"
    - "Sigra.Plug.RequireMembership passes through when roles is empty or membership role is in the required set"
    - "Sigra.Plug.RequireMembership init/1 raises ArgumentError when :roles contains an atom not in the host org config's role universe"
    - "Sigra.Plug.put_active_organization writes the session column, refreshes conn.private[:sigra_session], and assigns the new scope in one call"
    - "Sigra.Plug.put_active_organization returns {:error, :not_a_member} when the target user has no membership in the target org"
    - "No Plug session cookie write occurs in any Phase 14 plug — only conn.private and DB row"
  artifacts:
    - path: "lib/sigra/plug/load_active_organization.ex"
      provides: "Fetch plug that hydrates scope via Sigra.Scope.Hydration.hydrate/3 and handles stale recovery inline"
      contains: "defmodule Sigra.Plug.LoadActiveOrganization"
    - path: "lib/sigra/plug/require_membership.ex"
      provides: "Require plug that halts on missing org or insufficient role"
      contains: "defmodule Sigra.Plug.RequireMembership"
    - path: "lib/sigra/plug/put_active_organization.ex"
      provides: "Impure orchestrator — single authoritative write site for active_organization"
      contains: "defmodule Sigra.Plug.PutActiveOrganization"
  key_links:
    - from: "lib/sigra/plug/load_active_organization.ex"
      to: "Sigra.Scope.Hydration.hydrate/3"
      via: "direct module call"
      pattern: "Sigra\\.Scope\\.Hydration\\.hydrate"
    - from: "lib/sigra/plug/load_active_organization.ex"
      to: "Sigra.Organizations.select_active_organization/3"
      via: "stale-recovery path"
      pattern: "select_active_organization"
    - from: "lib/sigra/plug/put_active_organization.ex"
      to: "Sigra.SessionStore.update_active_organization/3"
      via: "session store callback via configured module"
      pattern: "update_active_organization"
    - from: "lib/sigra/plug/require_membership.ex"
      to: "error_handler.auth_error(conn, :no_active_org | :insufficient_role, opts)"
      via: "host-provided error handler module"
      pattern: "error_handler\\.auth_error"
---

<objective>
Land the three request-time library plugs that consume Plan 01's primitives:
Sigra.Plug.LoadActiveOrganization (Fetch — never halts), Sigra.Plug.RequireMembership
(Require — halts via error handler delegation), and the impure orchestrator
Sigra.Plug.PutActiveOrganization (single authoritative write site for "set the
active org").

Purpose: These plugs are the transport-layer cladding Phase 16's switcher controller,
Phase 17's invitation accept flow, and Plan 03's login wiring all consume. Getting
the Fetch/Require split right here makes downstream phases purely additive.

Output: Three new library plug modules in lib/sigra/plug/, each with a full test
file covering happy-path + stale-pointer + role-filter regression + orchestrator
authz check + "never halts" assertion + "no session cookie write" assertion.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/14-org-plugs-scope-hydration/14-CONTEXT.md
@.planning/phases/14-org-plugs-scope-hydration/14-RESEARCH.md

<!-- Plan 01 outputs — MUST be green before this plan starts -->
@lib/sigra/scope/hydration.ex
@lib/sigra/organizations.ex
@lib/sigra/session_store.ex
@lib/sigra/plug/error_handler.ex

<!-- Structural precedents — mimic these exactly -->
@lib/sigra/plug/require_scopes.ex
@lib/sigra/plug/require_authenticated.ex
@lib/sigra/plug/fetch_session.ex
@lib/sigra/audit.ex

<interfaces>
<!-- Contracts this plan produces for Plan 03 to consume -->

# Sigra.Plug.LoadActiveOrganization
@behaviour Plug
def init(opts), do: ...            # accepts no required opts; returns opts
def call(conn, _opts), do: conn    # NEVER halts

# Sigra.Plug.RequireMembership
@behaviour Plug
def init(opts) do
  # REQUIRED: :error_handler — module implementing Sigra.Plug.ErrorHandler
  # OPTIONAL: :roles — list of atoms; subset of @sigra_org_config[:roles]
  # Raises ArgumentError if :roles contains unknown atoms
end
def call(conn, opts), do: conn_or_halted

# Sigra.Plug.PutActiveOrganization
@spec call(conn :: Plug.Conn.t(), org_or_nil :: struct() | nil) ::
        {:ok, Plug.Conn.t()} | {:error, :not_a_member | term()}
# NOT a Plug.call/2 — it's a function-call contract from controllers + stale-recovery
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Sigra.Plug.LoadActiveOrganization (Fetch plug — never halts, handles stale recovery inline)</name>
  <files>lib/sigra/plug/load_active_organization.ex, test/sigra/plug/load_active_organization_test.exs</files>
  <read_first>
    - lib/sigra/plug/fetch_session.ex (FULL file — this is where fetch_current_scope stashes session at conn.private[:sigra_session]; LoadActiveOrganization runs immediately after)
    - lib/sigra/plug/require_authenticated.ex (for assign-not-halt pattern reference — though this one halts; used only to see the current_scope read pattern)
    - lib/sigra/scope/hydration.ex (Plan 01 output — this plug's primary callee)
    - lib/sigra/organizations.ex — select_active_organization/3 (Plan 01 output)
    - lib/sigra/audit.ex — log_safe/2 signature at ~line 112
    - .planning/phases/14-org-plugs-scope-hydration/14-CONTEXT.md §D-04, §D-14, §D-22, §CD-02
  </read_first>
  <behavior>
    - Test: call/2 with conn.assigns[:current_scope] == nil (unauthenticated) returns conn unchanged, no DB reads
    - Test: call/2 with authenticated user + session.active_organization_id == nil assigns a scope whose active_organization is nil (pass-through)
    - Test: call/2 with authenticated user + valid pointer + live membership assigns a fully hydrated scope (active_organization and membership populated from DB)
    - Test: call/2 with a stale pointer (user removed from org) DOES NOT raise, DOES NOT halt, resets session.active_organization_id to nil via SessionStore, re-runs select_active_organization/3 with previous: nil, and emits `Sigra.Audit.log_safe/2` with action atom matching CD-02 (planner picks singular form `"organization.active_auto_reassigned"` consistent with existing lib/sigra/audit.ex action naming)
    - Test: stale pointer case where user has 1+ remaining org — plug reassigns to the first org returned by the selector, scope ends with active_organization set to the reassigned org
    - Test: stale pointer case where user has 0 remaining orgs — scope ends with active_organization = nil, plug still does not halt
    - Test: stale pointer with deleted org (hydrate returns {:error, :org_not_found}) triggers the same recovery path
    - Test: call/2 does NOT call Plug.Conn.put_session/3 — assert `get_session(conn, :active_organization_id) == nil` before and after (D-03 / D-17 no-cookie-mirror invariant)
    - Test: call/2 does NOT call Plug.Conn.halt/1 — assert `conn.halted == false` on EVERY path
  </behavior>
  <action>
    Create `lib/sigra/plug/load_active_organization.ex`:

        defmodule Sigra.Plug.LoadActiveOrganization do
          @moduledoc """
          Hydrates `scope.active_organization` and `scope.membership` from the
          caller's `%Sigra.Session{}` (read from `conn.private[:sigra_session]`,
          stashed by `Sigra.Plug.FetchSession`).

          This is a **Fetch** plug in the `phx.gen.auth` sense: it mutates
          `conn.assigns[:current_scope]` and `conn.private[:sigra_session]`, but
          NEVER halts the pipeline. Missing/invalid/stale pointers resolve to a
          nil `active_organization` (or a reassigned one on hybrid recovery) and
          the request continues. Downstream `Sigra.Plug.RequireMembership` is
          responsible for halting when an active org is required.

          Stale-pointer recovery: on `{:error, :not_a_member}` or
          `{:error, :org_not_found}` from `Sigra.Scope.Hydration.hydrate/3`, the
          plug:
            1. Clears the session row's `active_organization_id` via
               `Sigra.SessionStore.update_active_organization/3`.
            2. Calls `Sigra.Organizations.select_active_organization/3` with
               `previous_active_organization_id: nil` (the stale pointer is NOT
               resumed).
            3. Writes the result (or nil) via the same store callback and
               assigns the final scope.
            4. Emits one audit event via `Sigra.Audit.log_safe/2`:
               `"organization.active_auto_reassigned"` with `%{from: stale_id, to: new_id_or_nil}`.

          No session cookie writes. No halts. Phase 14 D-03, D-04, D-14, D-17.
          """

          @behaviour Plug

          alias Sigra.Audit
          alias Sigra.Organizations
          alias Sigra.Scope.Hydration

          @impl true
          def init(opts), do: opts

          @impl true
          def call(%Plug.Conn{} = conn, _opts) do
            scope = conn.assigns[:current_scope]
            session = conn.private[:sigra_session]

            cond do
              is_nil(scope) ->
                conn

              is_nil(session) ->
                conn

              true ->
                hydrate_and_assign(conn, scope, session)
            end
          end

          defp hydrate_and_assign(conn, scope, session) do
            config = Sigra.Plug.FetchSession.config(conn)
            # If FetchSession does not expose a `config/1` accessor, read the config the same way
            # FetchSession does internally (likely `conn.private[:sigra_config]` or the
            # `Sigra.Config.from_env/0` fallback). Verify in lib/sigra/plug/fetch_session.ex
            # before committing — reuse the existing accessor; do not introduce a new one.

            case Hydration.hydrate(scope, config, session) do
              {:ok, hydrated_scope} ->
                Plug.Conn.assign(conn, :current_scope, hydrated_scope)

              {:error, reason} when reason in [:not_a_member, :org_not_found] ->
                recover_from_stale_pointer(conn, scope, session, config)
            end
          end

          defp recover_from_stale_pointer(conn, scope, session, config) do
            stale_id = session.active_organization_id

            # Step 1: clear the DB column
            {:ok, cleared_session} =
              Sigra.SessionStore.update_active_organization(session, nil)
            # Note: call the configured SessionStore module — match how FetchSession invokes the
            # behaviour. Likely `config.session_store.update_active_organization(...)` or a
            # thin delegate in `Sigra.SessionStore`. Mirror the existing call shape.

            # Step 2: re-run the selector with no resume pointer
            {new_session, new_scope} =
              case Organizations.select_active_organization(config, scope.user, previous_active_organization_id: nil) do
                {:ok, new_org} ->
                  {:ok, refreshed} =
                    Sigra.SessionStore.update_active_organization(cleared_session, new_org.id)

                  membership = Organizations.get_membership(config, scope.user, new_org)
                  updated_scope = %{scope | active_organization: new_org, membership: membership}
                  {refreshed, updated_scope}

                {:none, :zero_orgs} ->
                  {cleared_session, %{scope | active_organization: nil, membership: nil}}

                {:multiple, _orgs} ->
                  # v1.1: leave nil, user sees picker on next RequireMembership hit
                  {cleared_session, %{scope | active_organization: nil, membership: nil}}
              end

            # Step 3: emit audit (log_safe is no-op-safe until Phase 15 column lands)
            Audit.log_safe("organization.active_auto_reassigned", %{
              user_id: scope.user.id,
              from: stale_id,
              to: new_scope.active_organization && new_scope.active_organization.id
            })

            conn
            |> Plug.Conn.put_private(:sigra_session, new_session)
            |> Plug.Conn.assign(:current_scope, new_scope)
          end
        end

    **Before committing — verifications the executor MUST perform:**
    1. Read `lib/sigra/plug/fetch_session.ex` to confirm the config accessor shape. Use whatever pattern is already there (e.g., `conn.private[:sigra_config]`, explicit module attribute, or a config/1 helper). Do NOT invent a new accessor.
    2. Confirm `Sigra.SessionStore.update_active_organization/3` is invoked through whichever delegation pattern exists (direct call on `Sigra.SessionStore` delegate vs. calling the configured impl module directly). Match `Sigra.Plug.FetchSession`'s existing pattern.
    3. Confirm `Sigra.Audit.log_safe/2` accepts a string action + map metadata (verify signature at `lib/sigra/audit.ex:112`). Adjust the call shape if the signature is different. CD-02: action name is `"organization.active_auto_reassigned"` — lowercase dot-namespaced, singular, matching any existing Audit action precedent (search for existing action strings with `grep -n '"organization' lib/sigra/audit.ex test/sigra/audit_test.exs` to verify convention).

    Create `test/sigra/plug/load_active_organization_test.exs` with the 9 behavior cases. Use `Plug.Test` + `Sigra.DataCase` (async if other tests in test/sigra/plug/ are async). Use existing org/membership fixtures. Assert `conn.halted == false` and `get_session(conn, :active_organization_id) == nil` on every path.
  </action>
  <verify>
    <automated>mix test test/sigra/plug/load_active_organization_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - `ls lib/sigra/plug/load_active_organization.ex` — exists
    - `grep -c "Plug.Conn.halt" lib/sigra/plug/load_active_organization.ex` returns 0 — plug never halts (D-04)
    - `grep -c "put_session" lib/sigra/plug/load_active_organization.ex` returns 0 — no Plug session cookie write (D-03, D-17)
    - `grep -n "Sigra.Scope.Hydration.hydrate" lib/sigra/plug/load_active_organization.ex` shows exactly 1 call site
    - `grep -n "log_safe" lib/sigra/plug/load_active_organization.ex` shows exactly 1 call (stale-recovery only; no login audit)
    - `grep -n "select_active_organization" lib/sigra/plug/load_active_organization.ex` shows exactly 1 call (stale-recovery path)
    - `mix test test/sigra/plug/load_active_organization_test.exs` — all 9 test cases green
    - `mix compile --warnings-as-errors` clean
    - `mix credo --strict lib/sigra/plug/load_active_organization.ex` clean
  </acceptance_criteria>
  <done>
    LoadActiveOrganization ships as a Fetch plug: never halts, handles stale recovery inline with audit, no cookie writes, 9 tests green including the explicit "never halts" + "no put_session" assertions.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Sigra.Plug.RequireMembership (Require plug — halts via error_handler)</name>
  <files>lib/sigra/plug/require_membership.ex, test/sigra/plug/require_membership_test.exs</files>
  <read_first>
    - lib/sigra/plug/require_scopes.ex (FULL file — exact structural mimic target per D-05)
    - lib/sigra/plug/require_authenticated.ex (for init/1 validation + error_handler delegation precedent)
    - lib/sigra/plug/error_handler.ex (updated by Plan 01 — new error atoms available)
    - lib/sigra/organizations.ex (for the role universe — find `@sigra_org_config[:roles]` or equivalent constant)
    - .planning/phases/14-org-plugs-scope-hydration/14-CONTEXT.md §D-05, §D-06, §D-07, §D-09, §D-10, §D-21
    - .planning/phases/14-org-plugs-scope-hydration/14-RESEARCH.md Pattern 3 §Anti-Patterns
  </read_first>
  <behavior>
    - Test: init/1 without :error_handler raises KeyError (or ArgumentError — match RequireScopes exactly)
    - Test: init/1 with :roles containing an atom outside the host org role universe raises ArgumentError with a message naming the bad atom
    - Test: init/1 with :roles omitted validates and stores an empty list (default: any membership OK per D-07)
    - Test: init/1 with :roles being a valid subset [:owner, :admin] validates and stores it
    - Test: call/2 when scope is nil OR scope.active_organization is nil invokes error_handler.auth_error(conn, :no_active_org, opts) and halts (conn.halted == true after call)
    - Test: call/2 with valid membership whose role is in the required list returns conn unchanged (not halted)
    - Test: call/2 with valid membership whose role is NOT in the required list invokes error_handler.auth_error(conn, :insufficient_role, opts_with_required_roles) and halts
    - Test: call/2 with :roles == [] and a valid membership passes regardless of role (D-07)
    - Test: call/2 does NOT re-query the database — it reads scope.membership.role directly (D-21); assert with a Repo query counter OR explicit mock error_handler that fails if called with a conn whose assigns[:current_scope] was rebuilt from DB
  </behavior>
  <action>
    Create `lib/sigra/plug/require_membership.ex`, mimicking `lib/sigra/plug/require_scopes.ex` structure verbatim. Exact skeleton:

        defmodule Sigra.Plug.RequireMembership do
          @moduledoc """
          Halts the pipeline unless `conn.assigns[:current_scope]` has a non-nil
          `active_organization` and (optionally) a membership role in the
          configured `:roles` list.

          Structural twin of `Sigra.Plug.RequireScopes` — same init/1 validation,
          same error_handler delegation pattern, same halt shape. Any divergence
          from RequireScopes is a bug. Phase 14 D-05/D-06/D-07/D-21.

          Options:

            * `:error_handler` — required. Module implementing
              `Sigra.Plug.ErrorHandler`.

            * `:roles` — optional list of atoms. Must be a subset of the host's
              org role universe (typically `[:owner, :admin, :member]`).
              Validated at `init/1`; raises `ArgumentError` on typos.
              Default: `[]` (any active membership accepted — D-07).

          Reads `scope.membership.role` from assigns. NEVER re-queries the DB —
          the membership lookup was already done by
          `Sigra.Plug.LoadActiveOrganization` and stashed on the scope struct.
          """

          @behaviour Plug

          @role_universe [:owner, :admin, :member]
          # NOTE: verify role universe location. If lib/sigra/organizations.ex or
          # lib/sigra/config.ex exposes a canonical list (e.g.
          # `Sigra.Organizations.roles/0`), use it via compile-time module
          # attribute: `@role_universe Sigra.Organizations.roles()`. Executor
          # MUST search for the existing definition and reuse it — do NOT
          # hardcode if a canonical source exists.

          @impl true
          def init(opts) do
            error_handler = Keyword.fetch!(opts, :error_handler)
            required_roles = Keyword.get(opts, :roles, [])

            unless is_list(required_roles) and Enum.all?(required_roles, &is_atom/1) do
              raise ArgumentError,
                    "Sigra.Plug.RequireMembership :roles must be a list of atoms, got: #{inspect(required_roles)}"
            end

            invalid = required_roles -- @role_universe

            unless invalid == [] do
              raise ArgumentError,
                    "Sigra.Plug.RequireMembership :roles contains unknown atoms: #{inspect(invalid)}. " <>
                      "Valid roles: #{inspect(@role_universe)}"
            end

            opts
            |> Keyword.put(:error_handler, error_handler)
            |> Keyword.put(:roles, required_roles)
          end

          @impl true
          def call(%Plug.Conn{} = conn, opts) do
            error_handler = Keyword.fetch!(opts, :error_handler)
            required = Keyword.fetch!(opts, :roles)
            scope = conn.assigns[:current_scope]

            cond do
              is_nil(scope) or is_nil(scope.active_organization) ->
                conn
                |> error_handler.auth_error(:no_active_org, opts)
                |> Plug.Conn.halt()

              required != [] and scope.membership.role not in required ->
                error_opts = Keyword.put(opts, :required_roles, required)

                conn
                |> error_handler.auth_error(:insufficient_role, error_opts)
                |> Plug.Conn.halt()

              true ->
                conn
            end
          end
        end

    **DO NOT copy `Sigra.Plug.RequireMFA`**. RESEARCH §Anti-Patterns explicitly rejects the init-option path pattern; all redirect targets live in the host's error handler (D-10).

    Create `test/sigra/plug/require_membership_test.exs` covering all 9 behavior cases. Define a minimal test-local `FakeErrorHandler` module implementing `Sigra.Plug.ErrorHandler` that records calls to `auth_error/3` in the process dictionary (or an Agent) so tests can assert the exact `(conn, type, opts)` triple it was called with. The fake handler should return `Plug.Conn.resp(conn, 302, "")` so the subsequent `halt/1` works.

    For the "no DB re-query" assertion, either: (a) wrap the test in `Ecto.Adapters.SQL.Sandbox` manual mode and assert query count, OR (b) rely on the FakeErrorHandler + fixture setup where the membership on scope has a distinct role from the one stored in DB, then assert the plug uses the scope's role (not the DB's). Pick (b) — it's simpler and directly tests the invariant.
  </action>
  <verify>
    <automated>mix test test/sigra/plug/require_membership_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - `ls lib/sigra/plug/require_membership.ex` — exists
    - `grep -n "error_handler.auth_error(" lib/sigra/plug/require_membership.ex` shows exactly 2 call sites (:no_active_org and :insufficient_role)
    - `grep -n "Plug.Conn.halt" lib/sigra/plug/require_membership.ex` shows exactly 2 halt sites (mirrors RequireScopes pattern — on both error branches)
    - `grep -c "Repo\\." lib/sigra/plug/require_membership.ex` returns 0 — no direct Repo calls (D-21)
    - `grep -c "Organizations.get_membership" lib/sigra/plug/require_membership.ex` returns 0 — no membership re-fetch (D-21)
    - `grep -n "ArgumentError" lib/sigra/plug/require_membership.ex` shows at least 2 raise sites (invalid types + unknown atoms)
    - `mix test test/sigra/plug/require_membership_test.exs` — all 9 test cases green
    - `mix compile --warnings-as-errors` clean
    - `mix credo --strict lib/sigra/plug/require_membership.ex` clean
    - Structural diff check: `diff -u <(grep -E "^(\\s+)?(def |@|alias)" lib/sigra/plug/require_scopes.ex) <(grep -E "^(\\s+)?(def |@|alias)" lib/sigra/plug/require_membership.ex)` shows a recognizable structural mimic (same top-level shape: moduledoc, @behaviour Plug, @impl true def init, @impl true def call)
  </acceptance_criteria>
  <done>
    RequireMembership ships as a structural twin of RequireScopes, halts via error_handler on both failure modes, init-time role-subset validation raises on typos, never re-queries DB, 9 tests green.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Sigra.Plug.PutActiveOrganization (impure orchestrator — single write path)</name>
  <files>lib/sigra/plug/put_active_organization.ex, test/sigra/plug/put_active_organization_test.exs</files>
  <read_first>
    - lib/sigra/plug/load_active_organization.ex (just created — read it for config-accessor pattern + SessionStore call shape)
    - lib/sigra/organizations.ex — get_membership/3 signature (Phase 13)
    - priv/templates/sigra.install/core/scope.ex (current generated Scope template — Plan 03 adds put_active_organization/3 here; THIS plan's orchestrator calls into it via module name resolution from config)
    - lib/sigra/config.ex — look for `scope_module` or similar host-scope-module accessor
    - .planning/phases/14-org-plugs-scope-hydration/14-CONTEXT.md §D-15, §D-16, §D-17, §D-18, §D-19, §CD-01
  </read_first>
  <behavior>
    - Test: call/2 with conn + valid org where user has a membership writes session.active_organization_id via SessionStore.update_active_organization/3, assigns an updated scope, and returns {:ok, conn}
    - Test: call/2 with conn + org where user has NO membership returns {:error, :not_a_member} and does NOT write the DB column (SessionStore.update_active_organization NEVER called)
    - Test: call/2 with conn + nil clears the DB column via SessionStore.update_active_organization(session, nil), assigns scope with active_organization = nil + membership = nil, returns {:ok, conn}
    - Test: call/2 refreshes conn.private[:sigra_session] — after a successful write, `conn.private[:sigra_session].active_organization_id` reflects the new value
    - Test: call/2 does NOT call Plug.Conn.put_session/3 — grep and assertion (D-17)
    - Test: call/2 does NOT call Plug.Conn.configure_session(:renew) or any renew_session helper (D-18 — scope transition is NOT a trust transition)
    - Test: call/2 resolves the host Scope module via config (not a hardcoded Sigra.Scope) — the test passes a fake config with a test-specific Scope module implementing put_active_organization/3 and asserts THAT module's function got called
    - Test: docstring + @spec present and match the @interfaces block in this plan's context
  </behavior>
  <action>
    Create `lib/sigra/plug/put_active_organization.ex` (planner choice per CD-01 — standalone module in `lib/sigra/plug/` alongside `fetch_session.ex`):

        defmodule Sigra.Plug.PutActiveOrganization do
          @moduledoc """
          The SINGLE authoritative write site for "set the active organization."

          Every Phase 14+ call site that needs to set, clear, or change the active
          org funnels through this function: login (Plan 03), the switcher
          controller (Phase 16), invitation accept (Phase 17), stale-pointer
          recovery inside `Sigra.Plug.LoadActiveOrganization`, and the backfill
          upgrade (Phase 18). No ad-hoc `put_session` calls. No direct
          `Repo.update/2` on `user_sessions`. No shortcuts.

          This function is NOT a Plug.call/2 — it is a function-call contract
          invoked from controllers, other plugs, and the login entry point. It
          takes a `Plug.Conn` plus an `Organization` (or nil) and returns
          `{:ok, updated_conn}` or `{:error, reason}`.

          Writes performed:
            1. `user_sessions.active_organization_id` column (via the configured
               `Sigra.SessionStore`).
            2. `conn.private[:sigra_session]` (refreshed with the updated struct).
            3. `conn.assigns[:current_scope]` (host's `Scope.put_active_organization/3`).

          Writes explicitly NOT performed:
            * `Plug.Conn.put_session/3` — no Plug-session cookie mirror (D-03/D-17).
            * `Plug.Conn.configure_session(:renew)` or session token rotation —
              scope transition ≠ trust transition (D-18).

          Phase 14 D-16/D-17/D-18.
          """

          alias Sigra.Organizations

          @spec call(Plug.Conn.t(), struct() | nil) ::
                  {:ok, Plug.Conn.t()} | {:error, :not_a_member | term()}

          def call(%Plug.Conn{} = conn, nil) do
            scope = conn.assigns[:current_scope]
            session = conn.private[:sigra_session]

            with {:ok, refreshed} <- Sigra.SessionStore.update_active_organization(session, nil) do
              scope_module = scope_module!(conn)
              new_scope = scope_module.put_active_organization(scope, nil, nil)

              {:ok,
               conn
               |> Plug.Conn.put_private(:sigra_session, refreshed)
               |> Plug.Conn.assign(:current_scope, new_scope)}
            end
          end

          def call(%Plug.Conn{} = conn, org) when is_struct(org) do
            scope = conn.assigns[:current_scope]
            session = conn.private[:sigra_session]
            config = config!(conn)

            case Organizations.get_membership(config, scope.user, org) do
              nil ->
                {:error, :not_a_member}

              membership ->
                with {:ok, refreshed} <- Sigra.SessionStore.update_active_organization(session, org.id) do
                  scope_module = scope_module!(conn)
                  new_scope = scope_module.put_active_organization(scope, org, membership)

                  {:ok,
                   conn
                   |> Plug.Conn.put_private(:sigra_session, refreshed)
                   |> Plug.Conn.assign(:current_scope, new_scope)}
                end
            end
          end

          # Private helpers — config/scope module resolution.
          # Reuse whatever pattern Sigra.Plug.FetchSession + LoadActiveOrganization already use.
          # Do NOT duplicate. If FetchSession exposes `config/1`, delegate. If it reads from
          # `conn.private[:sigra_config]`, read from the same key here.
          defp config!(conn), do: Sigra.Plug.FetchSession.config(conn)
          defp scope_module!(conn), do: config!(conn).scope_module
          # Verify config.scope_module exists in lib/sigra/config.ex. If not, use
          # Application.fetch_env!/2 pattern consistent with other Sigra lib modules,
          # OR add a `scope_module` field to Sigra.Config in Plan 03's Task 1. If the
          # field does not yet exist, leave a `# TODO(plan-03)` comment and hardcode
          # the generated default name resolution for now — Plan 03 adds the field.
        end

    **Before committing — verifications:**
    1. Confirm `config.scope_module` (or the equivalent host-scope-module accessor) exists. Grep `lib/sigra/config.ex` for `scope_module`. If it does not exist, coordinate with Plan 03 Task 1 — that plan MUST add it before this plug is fully usable. For Plan 02, the tests can use a fake config that explicitly sets `scope_module: TestScope` where `TestScope` is a test-local module implementing `put_active_organization/3`.
    2. Confirm `Sigra.Organizations.get_membership/3` returns `nil | %OrganizationMembership{}` (not `{:ok, _} | {:error, _}`). Adjust pattern match if different.

    Create `test/sigra/plug/put_active_organization_test.exs` covering all 8 behavior cases. Define a test-local `TestScope` module with a two-clause `put_active_organization/3` mimicking D-15 (org + membership → updated struct; nil + nil → cleared struct). Use `Plug.Test.conn/2` + `Plug.Conn.put_private(:sigra_session, ...)` + `Plug.Conn.assign(:current_scope, ...)` to set up the input conn for each case.

    For "does NOT call put_session" assertion: use `get_session(conn, :active_organization_id)` before and after — both should be nil (the Plug session cookie is never touched). For "does NOT rotate token" assertion: assert the session cookie ID (or equivalent) is unchanged before and after.
  </action>
  <verify>
    <automated>mix test test/sigra/plug/put_active_organization_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - `ls lib/sigra/plug/put_active_organization.ex` — exists
    - `grep -c "Plug.Conn.put_session" lib/sigra/plug/put_active_organization.ex` returns 0 (D-17)
    - `grep -c "configure_session" lib/sigra/plug/put_active_organization.ex` returns 0 (D-18)
    - `grep -c "renew_session" lib/sigra/plug/put_active_organization.ex` returns 0 (D-18)
    - `grep -c "Repo\\." lib/sigra/plug/put_active_organization.ex` returns 0 — goes through SessionStore, never direct Repo
    - `grep -n "Sigra.SessionStore.update_active_organization" lib/sigra/plug/put_active_organization.ex` shows exactly 2 call sites (one per clause: nil + org)
    - `grep -n "Organizations.get_membership" lib/sigra/plug/put_active_organization.ex` shows exactly 1 call (membership verification before write)
    - `mix test test/sigra/plug/put_active_organization_test.exs` — all 8 test cases green
    - `mix compile --warnings-as-errors` clean
    - `mix credo --strict lib/sigra/plug/put_active_organization.ex` clean
    - The "not_a_member" test case confirms SessionStore.update_active_organization was NOT called (use a test-local session store Mox stub or track calls in process dict)
  </acceptance_criteria>
  <done>
    PutActiveOrganization ships as the single write path, verifies membership before writing, never touches the Plug session cookie, never rotates the session token, 8 tests green including the "no-write on not_a_member" invariant.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| incoming HTTP request → LoadActiveOrganization | `session.active_organization_id` from DB row (may be stale, revoked, or point at deleted org) |
| incoming HTTP request → RequireMembership | `scope.membership.role` from assigns (trusted: populated by LoadActiveOrganization which called Organizations.get_membership) |
| controller call → PutActiveOrganization | the `org` argument is untrusted (may be any Organization the caller can reference) — membership MUST be re-verified before writing |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-14-06 | Authorization bypass (IDOR) | PutActiveOrganization.call/2 with forged org id | mitigate | `call/2` invokes `Organizations.get_membership(config, scope.user, org)` FIRST; on nil returns `{:error, :not_a_member}` WITHOUT writing. Regression test asserts `SessionStore.update_active_organization` was never called on the error path. Satisfies ASVS L1 V4.1.3 (function-level authz). |
| T-14-07 | Tampering (stale session pointer) | LoadActiveOrganization on revoked-membership request | mitigate | Hydrator returns `{:error, :not_a_member}`; plug enters `recover_from_stale_pointer/4` which clears the DB column and re-runs the selector — NO 500, NO scope with a forged org. Regression test exercises the revoke path and asserts conn.halted == false + audit event emitted. Satisfies PITFALLS O-6. |
| T-14-08 | Tampering / Authz bypass | RequireMembership reading a tampered scope.membership.role | accept | Scope is populated by LoadActiveOrganization which reads membership from the Phase 13 tenant-scoped context. Attacking this requires tampering with Elixir process assigns — already inside the BEAM trust boundary. Rationale: cannot be mitigated at the plug level without re-querying (which D-21 rejects on perf grounds). |
| T-14-09 | Open redirect via :no_active_org landing target | RequireMembership → error_handler | mitigate | Redirect target lives in the generated `error_handler.ex` (D-09, D-10). Plan 03 emits the template with a hardcoded verified-route `~p"/organizations"` — compile-time path check prevents runtime-composed redirects. No user input influences the redirect target. |
| T-14-10 | Denial of Service via ceremony flood on stale recovery | LoadActiveOrganization | accept | Stale recovery runs the selector + 2 SessionStore writes per affected request. Attacker must first achieve a revoked membership — not cheap. Rate-limiting at the request layer (existing Hammer config) already throttles pathological traffic. No new rate limiter needed (CONTEXT.md §out of scope). |
| T-14-11 | Broken access control (hierarchical role confusion) | RequireMembership :roles option | mitigate | Set-membership semantics (D-06); `[:owner]` means "owner only", does NOT imply admin. Regression test: user with `:member` role hits `RequireMembership, roles: [:owner]` → error_handler called with `:insufficient_role`, halted. Additional test: user with `:admin` role hits same plug → also halted. |
| T-14-12 | Session cookie confusion (two writers) | PutActiveOrganization | mitigate | D-03/D-17 invariant: no `put_session` call in ANY Phase 14 plug. Acceptance criteria includes grep-based guards that fail the task on regression. |

HIGH-severity threats (T-14-06, T-14-07, T-14-11, T-14-12) all have `mitigate` dispositions backed by concrete test and grep-based acceptance criteria.
</threat_model>

<verification>
## Phase Checks

- [ ] `mix test test/sigra/plug/load_active_organization_test.exs test/sigra/plug/require_membership_test.exs test/sigra/plug/put_active_organization_test.exs` — all green
- [ ] `mix compile --warnings-as-errors` — clean
- [ ] `mix credo --strict lib/sigra/plug/load_active_organization.ex lib/sigra/plug/require_membership.ex lib/sigra/plug/put_active_organization.ex` — clean
- [ ] Invariant grep checks (all MUST return 0):
  - `grep -rn "put_session" lib/sigra/plug/load_active_organization.ex lib/sigra/plug/put_active_organization.ex`
  - `grep -rn "configure_session\\|renew_session" lib/sigra/plug/put_active_organization.ex`
  - `grep -rn "Plug.Conn.halt" lib/sigra/plug/load_active_organization.ex`
  - `grep -rn "Repo\\." lib/sigra/plug/require_membership.ex`
- [ ] `grep -n "Sigra.Scope.Hydration.hydrate" lib/sigra/plug/load_active_organization.ex` shows exactly 1 match (single source of truth)
</verification>

<success_criteria>
All 3 library plugs ship with invariants test-enforced:

1. **LoadActiveOrganization** — Fetch plug, never halts, delegates hydration to `Sigra.Scope.Hydration`, handles stale recovery via selector re-run + audit, no session cookie writes.
2. **RequireMembership** — Require plug, structural twin of `RequireScopes`, init-time role-subset validation raises ArgumentError on typos, set-membership semantics (D-06), reads `scope.membership.role` from assigns with ZERO DB re-query.
3. **PutActiveOrganization** — Impure orchestrator, verifies membership before every write, refreshes `conn.private[:sigra_session]` + `assigns[:current_scope]`, NEVER touches the Plug session cookie or rotates the session token.

Plan 01's primitives (Hydration, select_active_organization, SessionStore callback, ErrorHandler types) are all consumed exactly once per spec.

Decisions covered: D-03, D-04, D-05, D-06, D-07, D-14, D-16, D-17, D-18, D-21, D-22, D-24 (stale regression), D-25 (role-filter regression).
Requirements covered: ORG-SCOPE-03 (plug path complete), ORG-SCOPE-04 (RequireMembership complete).
</success_criteria>

<output>
After completion, create `.planning/phases/14-org-plugs-scope-hydration/14-02-SUMMARY.md`:
- 3 new files in lib/sigra/plug/
- 3 new test files in test/sigra/plug/
- Invariant grep results (all 0s)
- Decisions delivered
- Requirements progress (ORG-SCOPE-03 now has plug path AND primitives; ORG-SCOPE-04 complete)
- Handoff notes for Plan 03 (generated templates, login wiring, parity test)
- Any drift from CONTEXT.md or prior plan discovered during execution
</output>
