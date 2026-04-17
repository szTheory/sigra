---
phase: 14
plan: 3
type: execute
wave: 3
depends_on: [1, 2]
files_modified:
  - lib/sigra/auth.ex
  - lib/sigra/config.ex
  - priv/templates/sigra.install/core/scope.ex
  - priv/templates/sigra.install/core/user_auth.ex
  - priv/templates/sigra.install/core/error_handler.ex
  - priv/templates/sigra.install/organizations/organizations.ex
  - lib/sigra/install/features/organizations.ex
  - test/sigra/auth_org_selection_test.exs
  - test/sigra/scope/plug_liveview_parity_test.exs
  - test/sigra/install/features/organizations_test.exs
autonomous: true
requirements:
  - ORG-SCOPE-03
  - ORG-SCOPE-04
  - ORG-SCOPE-05
  - ORG-SCOPE-06
must_haves:
  truths:
    - "Sigra.Auth.create_session/4 calls select_active_organization/3 exactly once inside the session-creation transaction"
    - "A user with 1 org who logs in lands with active_organization_id written on their new session row"
    - "A user with 0 orgs who logs in lands with nil active_organization_id (login still succeeds)"
    - "A user with 2+ orgs and no resume pointer logs in with nil active_organization_id (picker handled in Phase 16)"
    - "A user with 2+ orgs and a matching previous_active_organization_id logs in with that org resumed"
    - "Generated Scope template exposes put_active_organization/3 with (org, membership) and (nil, nil) clauses"
    - "Generated user_auth.ex on_mount calls Sigra.Scope.Hydration.hydrate/3 with the full %Sigra.Session{} — LV parity achieved"
    - "Generated error_handler.ex has :no_active_org (info flash + redirect to ~p\"/organizations\") and :insufficient_role (403 render) clauses"
    - "Generated organizations.ex context wrapper exposes set_active_organization/2 via defdelegate to Sigra.Plug.PutActiveOrganization.call/2"
    - "Wiring test proves the Plug pipeline (LoadActiveOrganization) and the LV on_mount call path feed Sigra.Scope.Hydration.hydrate/3 equivalent inputs"
    - "Sigra.Config exposes scope_module accessor so PutActiveOrganization can resolve the host's generated Scope module"
  artifacts:
    - path: "lib/sigra/auth.ex"
      provides: "create_session/4 runs the selector and writes active_organization_id"
      contains: "select_active_organization"
    - path: "lib/sigra/config.ex"
      provides: "scope_module field on Sigra.Config struct"
      contains: "scope_module"
    - path: "priv/templates/sigra.install/core/scope.ex"
      provides: "put_active_organization/3 pure function (two clauses)"
      contains: "def put_active_organization"
    - path: "priv/templates/sigra.install/core/user_auth.ex"
      provides: "on_mount calls Sigra.Scope.Hydration.hydrate/3"
      contains: "Sigra.Scope.Hydration.hydrate"
    - path: "priv/templates/sigra.install/core/error_handler.ex"
      provides: ":no_active_org and :insufficient_role auth_error/3 clauses"
      contains: ":no_active_org"
    - path: "priv/templates/sigra.install/organizations/organizations.ex"
      provides: "Generated context wrapper with set_active_organization/2 defdelegate"
      contains: "defdelegate set_active_organization"
    - path: "test/sigra/auth_org_selection_test.exs"
      provides: "Login-time 0/1/2+ selector integration tests"
      contains: "create_session"
    - path: "test/sigra/scope/plug_liveview_parity_test.exs"
      provides: "SC-3 wiring test proving plug + on_mount call the same hydrator"
      contains: "Sigra.Scope.Hydration"
  key_links:
    - from: "lib/sigra/auth.ex create_session/4"
      to: "Sigra.Organizations.select_active_organization/3"
      via: "single call inside Repo.transact/2 block"
      pattern: "select_active_organization"
    - from: "priv/templates/sigra.install/core/user_auth.ex on_mount"
      to: "Sigra.Scope.Hydration.hydrate/3"
      via: "direct call after get_user_and_session_by_token"
      pattern: "Sigra\\.Scope\\.Hydration\\.hydrate"
    - from: "priv/templates/sigra.install/organizations/organizations.ex"
      to: "Sigra.Plug.PutActiveOrganization.call/2"
      via: "defdelegate set_active_organization/2"
      pattern: "defdelegate set_active_organization"
    - from: "priv/templates/sigra.install/core/error_handler.ex :no_active_org"
      to: "~p\"/organizations\""
      via: "verified-route redirect"
      pattern: "~p\"/organizations\""
---

<objective>
Wire Plan 01 primitives and Plan 02 plugs into the three integration surfaces:
(1) `Sigra.Auth.create_session/4` login entry point for the 0/1/2+ selector call,
(2) the generated-template edits that land scope hydration at the host-app LiveView
`on_mount` layer + error handler clauses + Scope template's pure put function + the
new generated organizations.ex context wrapper + Sigra.Install.Features.Organizations
registration, and (3) the SC-3 parity test that proves the Plug and LiveView paths
call `Sigra.Scope.Hydration.hydrate/3` with equivalent inputs.

Purpose: This is the final wave that makes Phase 14 end-to-end observable — a real
logged-in user's request reaches both the Plug pipeline AND a mounted LiveView with
byte-identical `current_scope`, stale pointers are silently reset, non-member
requests against guarded routes get the right flash and redirect, and the 0/1/2+
login flow delivers users to the right post-login state per ORG-SCOPE-06.

Output: Integration-level tests proving SC-1 through SC-4, plus all generated
templates the installer needs to emit for Phase 14 behavior to survive from library
to host app.
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
@.planning/phases/14-org-plugs-scope-hydration/14-UI-SPEC.md
@.planning/phases/14-org-plugs-scope-hydration/14-VALIDATION.md

<!-- Plan 01 + Plan 02 outputs this plan consumes -->
@lib/sigra/scope/hydration.ex
@lib/sigra/organizations.ex
@lib/sigra/plug/load_active_organization.ex
@lib/sigra/plug/require_membership.ex
@lib/sigra/plug/put_active_organization.ex
@lib/sigra/session_store.ex

<!-- Integration targets -->
@lib/sigra/auth.ex
@lib/sigra/config.ex
@priv/templates/sigra.install/core/scope.ex
@priv/templates/sigra.install/core/user_auth.ex
@priv/templates/sigra.install/core/error_handler.ex
@lib/sigra/install/features/organizations.ex
@priv/templates/sigra.install/organizations/

<interfaces>
<!-- Key contracts this plan produces -->

# Generated Scope template — new pure function
def put_active_organization(%__MODULE__{} = scope, %Organization{} = org, %OrganizationMembership{} = membership)
def put_active_organization(%__MODULE__{} = scope, nil, nil)

# Generated user_auth.ex — changed internal helper (line ~222 per CONTEXT canonical-refs)
# Before: mount_current_scope calls get_user_by_session_token
# After: mount_current_scope calls get_user_and_session_by_token + Sigra.Scope.Hydration.hydrate/3

# Generated error_handler.ex — two new clauses
def auth_error(conn, :no_active_org, _opts), do: ...   # info flash + redirect ~p"/organizations"
def auth_error(conn, :insufficient_role, _opts), do: ... # error flash + 403 render + halt

# Generated organizations.ex (NEW TEMPLATE)
defdelegate set_active_organization(conn, org), to: Sigra.Plug.PutActiveOrganization, as: :call

# Sigra.Config (library-side — EXTENDED struct)
# Adds `scope_module` field so PutActiveOrganization can resolve host's Scope module.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Login-time selector wiring + Sigra.Config.scope_module + integration tests</name>
  <files>lib/sigra/auth.ex, lib/sigra/config.ex, test/sigra/auth_org_selection_test.exs, test/sigra/config_test.exs</files>
  <read_first>
    - lib/sigra/auth.ex (FULL file — specifically create_session/4 at line ~984 per RESEARCH verification; read the full function including any Repo.transact/2 block it opens, understand how it writes the session row)
    - lib/sigra/config.ex (FULL file — current struct fields, how the config is constructed, whether defaults are in a `new/1` or a defstruct block)
    - lib/sigra/organizations.ex (Plan 01 Task 2 added select_active_organization/3 — confirm the signature)
    - lib/sigra/session_store.ex + lib/sigra/session_stores/ecto.ex (confirm update_active_organization/3 callback + impl from Plan 01 Task 1)
    - test/sigra/auth_test.exs (existing conventions for testing create_session)
    - .planning/phases/14-org-plugs-scope-hydration/14-CONTEXT.md §D-12, §D-13, §D-26
  </read_first>
  <behavior>
    - Test: Sigra.Config struct has a `:scope_module` field (nullable, default nil); `Sigra.Config.new/1` accepts and round-trips it
    - Test: create_session/4 for a user with zero memberships returns {:ok, session} with session.active_organization_id == nil (login still succeeds)
    - Test: create_session/4 for a user with exactly one membership returns a session with active_organization_id == that_org.id, written atomically with the session row
    - Test: create_session/4 for a user with 2+ memberships and no resume pointer returns a session with active_organization_id == nil (user sees picker on next request)
    - Test: create_session/4 for a user with 2+ memberships and a previous_active_organization_id (passed via opts) returns a session with that_org resumed
    - Test: create_session/4 calls select_active_organization/3 exactly once per login (assert via telemetry or a spy around Organizations)
    - Test: create_session/4 leaves login audit / lockout / rate-limit behavior IDENTICAL to pre-Phase-14 (regression test — existing create_session tests must still pass)
    - Test: if select_active_organization/3 raises (corrupted Organizations data), create_session/4 must still return {:ok, session} with active_organization_id == nil — login MUST NOT fail on selector failure (fail-open on selector; fail-closed is the hydrator's job per D-01)
  </behavior>
  <action>
    Step 1 — Extend `Sigra.Config`:

    In `lib/sigra/config.ex`, add a `:scope_module` field to the struct. Default value: nil (legacy installs without organizations). Add it in the defstruct list, add it to the typespec, and ensure whatever constructor function the file uses (likely `Sigra.Config.new/1` or `Sigra.Config.from_env/0` or a keyword merge) accepts and propagates it. If there is an Application.get_env pattern, add the key read alongside existing reads — mimic exact shape. Do NOT add NimbleOptions validation for this single field unless the existing pattern already uses NimbleOptions for every field.

    Regenerate any @type t() declarations to include the new field.

    Step 2 — Wire the selector into `Sigra.Auth.create_session/4`:

    Locate `create_session/4` in `lib/sigra/auth.ex` (~line 984 per RESEARCH). Read the function end-to-end. It likely uses `Repo.transact/2` or `Ecto.Multi` to atomically insert the session row. Add the selector call BEFORE the session row insert (so the result is available as a field on the insert), OR immediately AFTER the session row insert with an `update_active_organization/3` call — pick whichever composes cleanly with the existing transaction structure. Preferred shape (D-12):

        def create_session(config, user, ip, user_agent, opts \\ []) do
          previous = Keyword.get(opts, :previous_active_organization_id)

          Repo.transact(fn ->
            # ... existing session row insert ...
            with {:ok, session} <- SessionStore.insert(...) do
              active_org_id =
                try do
                  case Organizations.select_active_organization(config, user, previous_active_organization_id: previous) do
                    {:ok, org} -> org.id
                    _ -> nil
                  end
                rescue
                  _ -> nil  # fail-open on selector (see behavior test 8)
                end

              case active_org_id do
                nil -> {:ok, session}
                id -> SessionStore.update_active_organization(session, id)
              end
            end
          end)
        end

    **Executor verifications before committing:**
    - Read the actual function body — the existing signature may differ (`opts` may not exist as a 5th arg). If the existing shape is 4-arity with no opts, add a 5-arity overload that accepts opts and has the 4-arity call into it with `opts = []`. Maintain backwards compat.
    - Confirm `Repo.transact/2` vs `Ecto.Multi` vs plain `Repo.insert` — match the existing atomicity pattern.
    - The selector call must be inside the transaction so a failure rolls the whole login back (atomic write of session + active_organization_id).

    Step 3 — Create `test/sigra/auth_org_selection_test.exs` with all 8 behavior cases from above. Use the SAME fixtures existing `test/sigra/auth_test.exs` uses for `create_session` — do NOT duplicate setup. Add a test context helper that creates N memberships for a user.

    Step 4 — Run the existing auth test suite to confirm ZERO regressions:

        mix test test/sigra/auth_test.exs

    If any existing create_session test fails, the wiring introduced a regression — fix before the new tests land.
  </action>
  <verify>
    <automated>mix test test/sigra/auth_test.exs test/sigra/auth_org_selection_test.exs test/sigra/config_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - `grep -n ":scope_module" lib/sigra/config.ex` shows the field added to the struct AND the typespec
    - `grep -n "select_active_organization" lib/sigra/auth.ex` shows exactly 1 call site inside create_session (or its transaction block)
    - `grep -c "select_active_organization" lib/sigra/auth.ex` returns 1 — not 0, not 2+
    - `mix test test/sigra/auth_test.exs` — 100% of existing tests still pass (zero regressions)
    - `mix test test/sigra/auth_org_selection_test.exs` — all 8 new test cases green
    - `mix compile --warnings-as-errors` clean
    - The selector-failure fail-open test proves login does not die if `select_active_organization/3` raises — explicit rescue in place
    - `mix credo --strict lib/sigra/auth.ex lib/sigra/config.ex` clean
  </acceptance_criteria>
  <done>
    Sigra.Config has a scope_module field. create_session/4 runs the selector once, writes active_organization_id atomically, fails open on selector errors (login succeeds), and all 8 integration cases + zero regressions on existing auth tests.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Generated-template edits (scope.ex, user_auth.ex on_mount parity, error_handler.ex, organizations.ex wrapper) + Features.Organizations registration</name>
  <files>priv/templates/sigra.install/core/scope.ex, priv/templates/sigra.install/core/user_auth.ex, priv/templates/sigra.install/core/error_handler.ex, priv/templates/sigra.install/organizations/organizations.ex, lib/sigra/install/features/organizations.ex, test/sigra/install/features/organizations_test.exs</files>
  <read_first>
    - priv/templates/sigra.install/core/scope.ex (FULL file — current %Scope{} fields, existing put_* functions if any)
    - priv/templates/sigra.install/core/user_auth.ex (FULL file — specifically fetch_current_scope at line ~128, on_mount(:mount_current_scope, ...) at line ~193, mount_current_scope helper at line ~222)
    - priv/templates/sigra.install/core/error_handler.ex (FULL file — existing auth_error/3 clauses, flash + redirect pattern)
    - priv/templates/sigra.install/organizations/ directory listing — verify organization.ex / organization_membership.ex / organization_invitation.ex / migration.exs exist; confirm organizations.ex context wrapper does NOT yet exist (per RESEARCH §Project Structure "Note on generated organizations context wrapper")
    - lib/sigra/install/features/organizations.ex (FULL file — current feature registration; this is where the new organizations.ex template gets added to files/1 or injections/1)
    - lib/sigra/install/feature.ex (behaviour — verify files/1 + injections/1 callback shapes)
    - priv/templates/sigra.install/core/login_html.ex (design system reference — DaisyUI, Heroicons, btn-primary per UI-SPEC §upstream sources)
    - .planning/phases/14-org-plugs-scope-hydration/14-CONTEXT.md §D-02, §D-09, §D-15, §D-19, §D-22
    - .planning/phases/14-org-plugs-scope-hydration/14-UI-SPEC.md §Copywriting Contract (EXACT copy strings for both error clauses — non-negotiable)
  </read_first>
  <behavior>
    - The edited generated scope.ex compiles when rendered to a target app (verified via golden-diff harness from Phase 11, or at minimum `mix sigra.install` in a smoke app)
    - Rendering scope.ex adds exactly 2 new function clauses for put_active_organization/3; existing scope fields/functions are unchanged
    - Rendering user_auth.ex swaps `get_user_by_session_token` → `get_user_and_session_by_token` inside `mount_current_scope` (line ~222) AND adds a `Sigra.Scope.Hydration.hydrate/3` call; the `fetch_current_scope` plug at line ~128 is UNTOUCHED (it already uses the right function)
    - Rendering error_handler.ex adds `auth_error(conn, :no_active_org, _opts)` and `auth_error(conn, :insufficient_role, _opts)` clauses with the EXACT copy from UI-SPEC §Copywriting Contract (non-blaming, second-person, no role-name leak)
    - New generated template `priv/templates/sigra.install/organizations/organizations.ex` exists and contains a `defdelegate set_active_organization(conn, org), to: Sigra.Plug.PutActiveOrganization, as: :call` line
    - `Sigra.Install.Features.Organizations.files/1` returns the new organizations.ex template in its file list
    - Golden-diff harness (Phase 11) passes — mechanical additions only, no unrelated drift
  </behavior>
  <action>
    Step 1 — Extend `priv/templates/sigra.install/core/scope.ex`:

    Add two new function clauses for `put_active_organization/3` exactly as specified in CONTEXT.md §D-15. Place them alongside any existing `put_*` functions (there is a Phoenix 1.8 `put_organization/2` precedent — read the file to see if similar functions already exist; if yes, place the new ones adjacent for locality). Exact template shape (EEx interpolation for host module name):

        @doc "Puts the given organization and membership on the scope."
        def put_active_organization(%__MODULE__{} = scope, %<%= inspect(organization_module) %>{} = org,
                                    %<%= inspect(membership_module) %>{} = membership) do
          %{scope | active_organization: org, membership: membership}
        end

        @doc "Clears the active organization and membership from the scope."
        def put_active_organization(%__MODULE__{} = scope, nil, nil) do
          %{scope | active_organization: nil, membership: nil}
        end

    Verify the EEx interpolation variables (`organization_module`, `membership_module`) match what `Sigra.Install.Features.Organizations` already passes to the template rendering step. Read `lib/sigra/install/features/organizations.ex` to confirm, OR reuse whatever aliases / module names the existing Scope template already references for these types.

    Step 2 — Extend `priv/templates/sigra.install/core/user_auth.ex`:

    At line ~222 (`mount_current_scope` helper), swap:

        # BEFORE
        def mount_current_scope(socket, session) do
          user = ... get_user_by_session_token(token) ...
          scope = %Scope{user: user, ...}
          Phoenix.Component.assign(socket, :current_scope, scope)
        end

        # AFTER
        def mount_current_scope(socket, session) do
          {user, sigra_session} = ... get_user_and_session_by_token(token) ...
          scope = %Scope{user: user, active_organization: nil, membership: nil, impersonating_from: nil}

          case Sigra.Scope.Hydration.hydrate(scope, Sigra.Config.from_env(), sigra_session) do
            {:ok, hydrated} -> Phoenix.Component.assign(socket, :current_scope, hydrated)
            {:error, _reason} -> Phoenix.Component.assign(socket, :current_scope, scope)
            # NOTE: LV path cannot trigger stale-pointer DB writes (no conn); graceful degradation.
            # Next Plug request (LoadActiveOrganization) handles recovery. Phase 16 adds LV handle_params re-check.
          end
        end

    **Executor must read the actual current shape at line 222 before editing.** The template file may use `<%= web_module %>.UserAuth` or other EEx interpolations — preserve those. The exact function name may differ (`mount_current_scope` vs an inline assign in `on_mount/4`). CONTEXT.md canonical-refs says it's at line 222. If drift is found, adapt but preserve the net-net behavior: after the edit, `on_mount(:mount_current_scope, ...)` MUST result in a scope whose active_organization is hydrated from the session via `Sigra.Scope.Hydration.hydrate/3`.

    Do NOT touch `fetch_current_scope` at line 128 — it already uses `get_user_and_session_by_token`. That plug is extended at the router level (Task 3).

    Step 3 — Extend `priv/templates/sigra.install/core/error_handler.ex`:

    Add two new `auth_error/3` clauses. Copy is EXACTLY from UI-SPEC §Copywriting Contract — non-negotiable:

        @doc """
        Clauses for :no_active_org and :insufficient_role are generated by Sigra
        for organization-aware routes. Edit the redirect target or message to
        match your product's tone.
        """
        def auth_error(conn, :no_active_org, _opts) do
          conn
          |> Phoenix.Controller.put_flash(:info, "Pick or create an organization to continue.")
          |> Phoenix.Controller.redirect(to: ~p"/organizations")
        end

        def auth_error(conn, :insufficient_role, _opts) do
          conn
          |> Phoenix.Controller.put_flash(:error, "You don't have permission to access this page in the current organization.")
          |> Plug.Conn.put_status(:forbidden)
          |> Phoenix.Controller.put_view(<%= inspect(web_module) %>.ErrorHTML)
          |> Phoenix.Controller.render(:"403")
        end

    Copy rules (UI-SPEC §Copy Rules — also non-negotiable):
    - `:no_active_org` uses `:info` NOT `:error` (non-blaming)
    - `:insufficient_role` does NOT name the required role in the message (no role-name leak)
    - No technical vocabulary ("membership", "scope", "pointer" etc.) in user-visible copy
    - Action-forward phrasing

    Step 4 — Create NEW template `priv/templates/sigra.install/organizations/organizations.ex`:

    This file does not yet exist (verified in RESEARCH §Project Structure note). Create it — the generated context wrapper that the host app will customize. Minimum contents for Phase 14:

        defmodule <%= inspect(app_web_module) %>.Organizations do
          @moduledoc """
          Host-app organizations context wrapper.

          Delegates sensitive operations to the Sigra library while exposing a
          stable, discoverable API for controllers and LiveViews. Edit freely —
          this file is your code.
          """

          @doc """
          Sets the active organization for the current request. Single
          authoritative write path; updates the session row, in-process session
          struct, and the assigned scope atomically.

          Returns `{:ok, conn}` on success, `{:error, :not_a_member}` if the user
          has no membership in the target org.
          """
          defdelegate set_active_organization(conn, org),
            to: Sigra.Plug.PutActiveOrganization,
            as: :call
        end

    Verify the EEx variable name for the app's context module (likely `inspect(context_module)` or `inspect(app_module).Organizations`) by reading how other generated context templates (e.g. `priv/templates/sigra.install/core/accounts.ex` if it exists) name themselves. Reuse EXACTLY; do not invent.

    Step 5 — Register the new template in `lib/sigra/install/features/organizations.ex`:

    Add the new `organizations/organizations.ex` template to whatever `files/1` callback the feature module exposes. Follow the pattern used for the existing `organization.ex`, `organization_membership.ex`, etc. entries. The target render path in the host app should be `lib/<app_name>/organizations.ex` (mimic how `core` features render `accounts.ex` or whatever the existing convention is).

    Also register the scope + user_auth + error_handler template edits — but note these files are ALREADY in the Core feature. Phase 14's edits mean the Core feature's templates change content, NOT the file list. So for scope.ex/user_auth.ex/error_handler.ex there is NO new files/1 entry — just the file CONTENTS change and the golden-diff harness picks up the diff.

    Step 6 — Run the golden-diff harness (from Phase 11) if available:

        mix test test/sigra/install/golden_diff_test.exs

    If Phase 11 has not yet landed this harness, skip this step and rely on `mix sigra.install` smoke — generate a fresh app, run install, confirm it compiles. If neither is available, at minimum run:

        mix compile --warnings-as-errors
        mix test test/sigra/install/features/organizations_test.exs

    Step 7 — Add a test `test/sigra/install/features/organizations_test.exs` (or extend if exists) asserting:
    - The files/1 callback includes the new organizations.ex entry
    - Rendering the scope.ex template with mock assigns produces output containing `put_active_organization`
    - Rendering the error_handler.ex template produces output containing the exact UI-SPEC copy strings
  </action>
  <verify>
    <automated>mix test test/sigra/install/features/organizations_test.exs && mix compile --warnings-as-errors</automated>
  </verify>
  <acceptance_criteria>
    - `grep -n "def put_active_organization" priv/templates/sigra.install/core/scope.ex` shows 2 function clauses
    - `grep -n "Sigra.Scope.Hydration.hydrate" priv/templates/sigra.install/core/user_auth.ex` shows exactly 1 match (inside mount_current_scope — LV path)
    - `grep -n "get_user_by_session_token" priv/templates/sigra.install/core/user_auth.ex` shows 0 matches inside mount_current_scope function body (only get_user_and_session_by_token remains)
    - `grep -n ":no_active_org" priv/templates/sigra.install/core/error_handler.ex` matches the new clause
    - `grep -n ":insufficient_role" priv/templates/sigra.install/core/error_handler.ex` matches the new clause
    - `grep -n "Pick or create an organization to continue" priv/templates/sigra.install/core/error_handler.ex` — exact UI-SPEC copy present
    - `grep -n "You don't have permission to access this page in the current organization" priv/templates/sigra.install/core/error_handler.ex` — exact UI-SPEC copy present
    - `grep -c "This page requires the" priv/templates/sigra.install/core/error_handler.ex` returns 0 — no role name leak (UI-SPEC non-negotiable rule)
    - `ls priv/templates/sigra.install/organizations/organizations.ex` — new file exists
    - `grep -n "defdelegate set_active_organization" priv/templates/sigra.install/organizations/organizations.ex` — defdelegate line present
    - `grep -n "Sigra.Plug.PutActiveOrganization" priv/templates/sigra.install/organizations/organizations.ex` — correct delegate target
    - `grep -n "organizations.ex" lib/sigra/install/features/organizations.ex` shows the new file registered in files/1
    - `mix test test/sigra/install/features/organizations_test.exs` green
    - `mix compile --warnings-as-errors` clean
    - If golden-diff harness exists: `mix test test/sigra/install/golden_diff_test.exs` green (mechanical diff only)
    - `mix credo --strict priv/templates/sigra.install/core/error_handler.ex lib/sigra/install/features/organizations.ex` clean
  </acceptance_criteria>
  <done>
    All 4 generated template edits land: scope.ex has the pure put function, user_auth.ex mount_current_scope calls the hydrator, error_handler.ex has the 2 new clauses with exact UI-SPEC copy, new organizations.ex context wrapper with defdelegate exists, Features.Organizations registers it, all template tests green, compile clean.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Plug ↔ LiveView parity test + stale-pointer regression test + 0/1/2+ login-flow end-to-end test + router pipeline additions</name>
  <files>priv/templates/sigra.install/core/router.ex, test/sigra/scope/plug_liveview_parity_test.exs, test/sigra/plug/load_active_organization_test.exs, test/sigra/auth_org_selection_test.exs, .planning/phases/14-org-plugs-scope-hydration/14-VALIDATION.md</files>
  <read_first>
    - lib/sigra/scope/hydration.ex (Plan 01 Task 3)
    - lib/sigra/plug/load_active_organization.ex (Plan 02 Task 1)
    - priv/templates/sigra.install/core/user_auth.ex (Task 2 above — LV mount_current_scope AFTER edit)
    - priv/templates/sigra.install/core/router.ex (the generated router template — this is where the new plug gets wired into the browser_authenticated pipeline)
    - .planning/phases/14-org-plugs-scope-hydration/14-CONTEXT.md §D-22 (last bullet — router pipeline additions), §D-23, §D-24
    - test/support/conn_case.ex or test/support/data_case.ex — existing test infrastructure
  </read_first>
  <behavior>
    - Parity test: a single `%Sigra.Session{}` fixture fed to (a) Sigra.Scope.Hydration.hydrate/3 directly (as the on_mount path would) and (b) a conn pushed through Sigra.Plug.LoadActiveOrganization (as the plug path would) produces structurally equivalent resulting scopes — same active_organization, same membership, same shape. D-23.
    - Parity test — stale-pointer case: both paths observe the stale pointer; the plug path recovers via LoadActiveOrganization.recover_from_stale_pointer; the LV path returns the non-hydrated scope (no recovery in LV per Task 2 comment). The parity assertion is: "same INPUT session produces the same hydration OUTCOME up to the recovery boundary" — both call Hydration.hydrate/3 with the same args. Assertion style: capture hydrate/3 inputs via telemetry or Mox and compare.
    - Stale-pointer regression test (SC-1): build user + org + membership → log in (create_session) → revoke membership via Sigra.Organizations.remove_member/3 → simulate next request by running LoadActiveOrganization → assert conn.status is NOT 500 → assert scope.active_organization is nil (zero-org case) OR reassigned to a remaining org → assert one audit event was emitted via log_safe.
    - 0/1/2+ login-flow end-to-end test (SC-4): four sub-cases asserted end-to-end via create_session/4 + LoadActiveOrganization + RequireMembership:
      - 0 orgs: login → next request → LoadActiveOrganization → RequireMembership → error_handler invoked with :no_active_org (conn halted + flash + redirect target ~p"/organizations" visible in the response)
      - 1 org: login → active_organization_id written → next request → RequireMembership passes through
      - 2+ orgs with resume pointer: login with opts[:previous_active_organization_id] → resumed org written → RequireMembership passes through
      - 2+ orgs without resume pointer: login → active_organization_id is nil → next request → RequireMembership calls error_handler :no_active_org → redirect to picker
    - Role-filter regression test (SC-2 augmented): user with :member role → RequireMembership with `roles: [:owner]` → error_handler called with :insufficient_role → conn halted with 403 response (asserted against the test-generated error_handler from Task 2).
    - Router pipeline test: the generated router.ex template has `plug Sigra.Plug.LoadActiveOrganization` in the `:browser_authenticated` (or equivalent) pipeline immediately after `fetch_current_scope`; and two new pipelines `:require_org` and `:require_org_owner` use RequireMembership with the correct options.
  </behavior>
  <action>
    Step 1 — Add `plug Sigra.Plug.LoadActiveOrganization` to the generated router template.

    Locate `priv/templates/sigra.install/core/router.ex`. Find the pipeline that runs after `fetch_current_scope` (likely named `:browser_authenticated`, `:fetch_current_user`, or embedded in `:browser` — read the file). Add:

        plug Sigra.Plug.LoadActiveOrganization

    IMMEDIATELY after `plug Sigra.Plug.FetchSession` (or whatever the fetch_current_scope line is). Do NOT insert it before FetchSession — LoadActiveOrganization requires `conn.private[:sigra_session]` which FetchSession populates.

    Then add two NEW pipelines (placed after the existing authenticated pipeline):

        pipeline :require_org do
          plug Sigra.Plug.RequireMembership, error_handler: <%= inspect(web_module) %>.AuthErrorHandler
        end

        pipeline :require_org_owner do
          plug Sigra.Plug.RequireMembership,
            error_handler: <%= inspect(web_module) %>.AuthErrorHandler,
            roles: [:owner]
        end

    Do NOT wire these pipelines into any scope — they are opt-in scaffolding for host apps. Phase 16 will use them on the switcher + settings routes.

    Step 2 — Create `test/sigra/scope/plug_liveview_parity_test.exs`:

        defmodule Sigra.Scope.PlugLiveViewParityTest do
          use Sigra.DataCase, async: true

          alias Sigra.Scope.Hydration

          describe "plug + on_mount parity (D-23)" do
            test "both paths call hydrate/3 with equivalent inputs on happy path" do
              # Setup: user + org + membership, create a %Sigra.Session{} with active_organization_id.
              # Build a minimal scope struct.
              # Call Hydration.hydrate(scope, config, session) directly (the LV on_mount does this).
              # Build a conn, assign scope, put_private sigra_session, run LoadActiveOrganization.call(conn, []).
              # Compare: result_lv_scope == result_plug_scope structurally
            end

            test "both paths observe the same stale-pointer signal" do
              # Setup, then remove_member/3 to stale the pointer.
              # Assert: Hydration.hydrate/3 directly returns {:error, :not_a_member}.
              # Assert: LoadActiveOrganization (plug path) catches it and recovers (conn.assigns[:current_scope] has active_organization = nil and conn.halted == false).
              # The parity is at the HYDRATE CALL LAYER, not at the post-recovery layer (LV has no conn to recover via).
            end

            test "both paths produce structurally equal scopes for 'no active org' session" do
              # Session with active_organization_id == nil.
              # Both paths return scope with nil active_organization + membership.
            end
          end
        end

    Step 3 — Create or extend `test/sigra/plug/load_active_organization_test.exs` (may already exist from Plan 02) with a new `describe "SC-1 stale-pointer regression"` block that is an integration test, not a plug unit test. Sequence:

        1. Create user + org_A + membership_A.
        2. Call create_session/4 to log the user in (exercises the Task 1 wiring).
        3. Assert the session row has active_organization_id == org_A.id.
        4. Call Organizations.remove_member(config, org_A, user).
        5. Build a fresh conn using the same session token (simulating the next request).
        6. Run the plug chain: FetchSession → LoadActiveOrganization.
        7. Assert conn.halted == false AND conn.status does NOT equal 500.
        8. Assert conn.assigns[:current_scope].active_organization == nil (zero remaining orgs).
        9. Assert an audit event was emitted — use telemetry listener or a test-only Audit.log_safe spy.

    Also add a parallel test: "stale pointer with 1 remaining org — reassigns". Setup is the same but create an extra org_B + membership_B before the remove_member call. Assert the plug reassigns active_organization to org_B after recovery (the selector's first pick).

    Step 4 — Create `test/sigra/auth_org_selection_test.exs` end-to-end additions (or extend the Task 1 test file with a new describe block) covering the 4 sub-cases of SC-4:

        describe "0/1/2+ orgs login flow end-to-end (SC-4)" do
          test "0 orgs — login succeeds, RequireMembership redirects to :no_active_org" do ... end
          test "1 org — login writes active_organization_id, RequireMembership passes through" do ... end
          test "2+ orgs with resume pointer — resumed org written, RequireMembership passes through" do ... end
          test "2+ orgs without resume pointer — nil written, RequireMembership redirects" do ... end
        end

    Use the test-generated AuthErrorHandler (Task 2's template output) as the error_handler. Because the template is generated, the test either: (a) renders the template into a test module at setup time (cleanest — use `Code.eval_string/1` on the rendered template output), or (b) defines a hand-written test clone of the template's clauses exercised against Sigra.Plug.RequireMembership. Pick (b) — it's simpler and directly tests the plug integration without dragging in the full generator pipeline.

    Step 5 — Verify VALIDATION.md's Wave 0 checklist is now satisfied:

        - [x] test/sigra/plug/load_active_organization_test.exs (Plan 02 + this task extended)
        - [x] test/sigra/plug/require_membership_test.exs (Plan 02)
        - [x] test/sigra/scope/hydration_test.exs (Plan 01 — note file name: hydrator_test.exs vs hydration_test.exs is cosmetic; match VALIDATION.md OR update VALIDATION.md to match — planner picks hydration_test.exs)
        - [x] test/sigra/auth_org_selection_test.exs (Task 1 + this task extended)
        - [x] Parity test file (this task — plug_liveview_parity_test.exs)

    If VALIDATION.md uses a different filename (e.g. `hydrator_test.exs`), this task must either update VALIDATION.md's Wave 0 list OR rename the file to match. Prefer updating VALIDATION.md; use `hydration_test.exs` (matches the module name Sigra.Scope.Hydration).
  </action>
  <verify>
    <automated>mix test test/sigra/scope/plug_liveview_parity_test.exs test/sigra/plug/load_active_organization_test.exs test/sigra/auth_org_selection_test.exs && mix compile --warnings-as-errors</automated>
  </verify>
  <acceptance_criteria>
    - `ls test/sigra/scope/plug_liveview_parity_test.exs` — exists
    - `grep -n "Sigra.Plug.LoadActiveOrganization" priv/templates/sigra.install/core/router.ex` — plug added after FetchSession
    - `grep -n "pipeline :require_org" priv/templates/sigra.install/core/router.ex` — new pipeline exists
    - `grep -n "pipeline :require_org_owner" priv/templates/sigra.install/core/router.ex` — new pipeline exists
    - `grep -n "roles: \\[:owner\\]" priv/templates/sigra.install/core/router.ex` — :require_org_owner pipeline has role filter
    - `mix test test/sigra/scope/plug_liveview_parity_test.exs` — 3 parity tests green (D-23)
    - `mix test test/sigra/plug/load_active_organization_test.exs` — stale-pointer regression describe block green (D-24 / SC-1)
    - `mix test test/sigra/auth_org_selection_test.exs` — both Task 1 tests AND the 4 SC-4 end-to-end cases green
    - `mix compile --warnings-as-errors` clean
    - `mix test` — FULL suite green (integration gate for Phase 14)
    - VALIDATION.md §Wave 0 Requirements checklist fully ticked (update the file to reflect; set `wave_0_complete: true` and `nyquist_compliant: true` in frontmatter)
    - `grep -rn "get_organization!" lib/sigra/scope lib/sigra/plug` returns 0 — Pitfall 2 guard (no bang calls in any Phase 14 hydration/plug code)
  </acceptance_criteria>
  <done>
    SC-1 stale-pointer regression test green, SC-2 role-filter test green, SC-3 plug↔LV parity test green via hydrate/3 call-site equivalence, SC-4 0/1/2+ login-flow end-to-end test green with all 4 sub-cases, router template has LoadActiveOrganization plug + 2 new pipelines, VALIDATION.md Wave 0 fully satisfied, full test suite green.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| login request → Sigra.Auth.create_session/4 | user-provided credentials validated upstream; post-auth the selector operates on the validated user |
| generated template rendering → host app | EEx interpolation vars trusted; template contents baked at generator time |
| router pipeline → LoadActiveOrganization | trust boundary established by FetchSession; LoadActiveOrganization inherits it |
| RequireMembership → error_handler → redirect target | redirect target is a compile-time verified route (~p"/organizations"), NOT user input |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-14-13 | Denial of Service | create_session/4 selector failure | mitigate | Task 1 wraps `select_active_organization/3` in a try/rescue; selector failure does NOT fail login (active_organization_id stays nil, user sees picker on next request). Test case 8 in Task 1 explicitly asserts this. |
| T-14-14 | Open redirect | :no_active_org error_handler redirect | mitigate | UI-SPEC §Copywriting Contract locks the redirect target to the verified route `~p"/organizations"`. Verified routes are compile-time checked by Phoenix — no runtime composition, no user input. Acceptance criterion: grep for exact string present. |
| T-14-15 | Information disclosure via role-name leak | :insufficient_role error_handler | mitigate | UI-SPEC copy rule: message must NOT name the required role. Acceptance criterion: `grep -c "This page requires the"` returns 0. The 403 page body is sufficient signal without enumerating role atoms. |
| T-14-16 | Broken access control via LiveView on_mount drift | Generated user_auth.ex on_mount | mitigate | Task 2 swaps the LV path to call `Sigra.Scope.Hydration.hydrate/3` — the SAME function the plug path calls via LoadActiveOrganization. Task 3 parity test asserts both paths produce structurally-equal scopes. D-01/D-23. |
| T-14-17 | Repudiation of stale-pointer transitions | LoadActiveOrganization recovery path | mitigate | Task 3 integration test asserts exactly one `Sigra.Audit.log_safe/2` call per stale transition. log_safe is no-op-safe until Phase 15 lands the real organization_id column — future-compat. |
| T-14-18 | Authorization bypass via router misconfiguration | router.ex template | mitigate | Task 3 adds LoadActiveOrganization AFTER FetchSession (ordering invariant). New :require_org pipelines reference the HOST's AuthErrorHandler (not a library default), forcing host apps to implement the error_handler contract — compile error on missing impl. |
| T-14-19 | LiveView stale-pointer race | on_mount with stale session (LV path) | accept | LV cannot write to the DB from on_mount (no conn). Task 2 accepts the non-hydrated scope on stale-pointer error; user's next Plug request recovers. Phase 16 adds LV `handle_params` re-check to close the LV-only gap. CONTEXT.md §downstream Phase 16. |

HIGH-severity threats (T-14-14, T-14-15, T-14-16, T-14-18) all have `mitigate` dispositions with grep-based or test-based acceptance criteria.
</threat_model>

<verification>
## Phase Checks (integration gate)

- [ ] `mix test` — FULL suite green, including every new test file across all 3 Phase 14 plans
- [ ] `mix compile --warnings-as-errors` — clean
- [ ] `mix credo --strict` — clean on all modified files
- [ ] `mix dialyzer` — clean (or no new warnings beyond baseline)
- [ ] `git diff mix.exs` — empty (Phase 14 adds zero deps)
- [ ] `grep -rn "put_session.*:active_organization" lib/ priv/` — returns 0 (D-03 / D-17 enforcement, global)
- [ ] `grep -rn "get_organization!" lib/sigra/scope/ lib/sigra/plug/load_active_organization.ex` — returns 0 (Pitfall 2 guard)
- [ ] VALIDATION.md frontmatter updated: `wave_0_complete: true`, `nyquist_compliant: true`
- [ ] All 4 REQ-IDs (ORG-SCOPE-03, 04, 05, 06) demonstrably satisfied by at least one test case per requirement (per-task verification map in VALIDATION.md §Per-Task Verification Map must be populated — planner adds entries)
- [ ] If golden-diff harness from Phase 11 exists: golden-diff passes (mechanical additions only, no unrelated drift to Core templates)
- [ ] Manual-only verification (from VALIDATION.md): reserved for `/gsd-verify-work` — run `mix sigra.install` in a throwaway Phoenix app, log in, confirm no 500 on a stale-pointer-simulated request
</verification>

<success_criteria>
Phase 14 end-to-end observable behavior:

1. **SC-1 (stale-pointer silent recovery):** A user whose session `active_organization_id` points at an org they were removed from gets a 200 response on their next request, with `scope.active_organization` either nil (0 remaining orgs) or reassigned to a remaining org — never a 500. Audit event emitted. Test: `test/sigra/plug/load_active_organization_test.exs` SC-1 describe block.

2. **SC-2 (role filter + no-active-org redirect):** A user hitting a `RequireMembership` route without an active org is redirected to `~p"/organizations"` with the `:info` flash "Pick or create an organization to continue." A user with the wrong role gets a 403 with the `:error` flash (no role name leak). Tests: Plan 02 require_membership_test + Task 3 integration tests.

3. **SC-3 (plug ↔ LV parity):** The Plug pipeline and LiveView `on_mount` paths produce byte-identical `current_scope` values for the same session state. Parity test proves both paths call `Sigra.Scope.Hydration.hydrate/3` with equivalent inputs. Test: `test/sigra/scope/plug_liveview_parity_test.exs`.

4. **SC-4 (0/1/2+ login):** Zero-org user → nil active_organization on login, sees picker on first RequireMembership; one-org user → auto-selected on login; 2+ with resume pointer → resumed; 2+ without → nil until picker. Test: `test/sigra/auth_org_selection_test.exs` SC-4 describe block.

Decisions covered: D-02, D-09, D-12, D-15, D-19 (defdelegate), D-22 (generated surface), D-23 (parity test), D-24 (stale regression), D-25 (role filter regression), D-26 (login flow end-to-end).

Requirements fully satisfied: ORG-SCOPE-03 (hydration + plug + recovery path), ORG-SCOPE-04 (RequireMembership with role filter — wired), ORG-SCOPE-05 (LV on_mount parity), ORG-SCOPE-06 (0/1/2+ login flow).
</success_criteria>

<output>
After completion, create `.planning/phases/14-org-plugs-scope-hydration/14-03-SUMMARY.md`:
- Integration wiring landed (Sigra.Auth.create_session/4, Sigra.Config.scope_module)
- Generated templates edited (scope.ex, user_auth.ex, error_handler.ex, organizations.ex NEW, router.ex)
- Features.Organizations updated
- All 4 success criteria tests green (SC-1 through SC-4)
- Full test suite passing
- VALIDATION.md Wave 0 closed
- Requirements mapping table: each ORG-SCOPE-0X → implementing test file
- Any drift discovered during execution
- Phase 14 complete; handoff to Phase 15 (Audit Integration) — the `log_safe` audit call in LoadActiveOrganization is ready to consume `metadata_from_scope/2` once Phase 15 lands
</output>
