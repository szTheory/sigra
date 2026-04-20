---
phase: 14
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/sigra/scope/hydration.ex
  - lib/sigra/organizations.ex
  - lib/sigra/session_store.ex
  - lib/sigra/session_stores/ecto.ex
  - lib/sigra/plug/error_handler.ex
  - test/sigra/scope/hydration_test.exs
  - test/sigra/organizations_test.exs
  - test/sigra/session_stores/ecto_test.exs
autonomous: true
requirements:
  - ORG-SCOPE-03
  - ORG-SCOPE-06
must_haves:
  truths:
    - "Calling Sigra.Scope.Hydration.hydrate/3 with a nil active_organization_id returns {:ok, scope} unchanged"
    - "Calling hydrate/3 with a valid session + live membership returns {:ok, scope} with active_organization and membership populated"
    - "Calling hydrate/3 with a stale pointer (revoked membership) returns {:error, :not_a_member} without raising"
    - "Calling hydrate/3 with a deleted org returns {:error, :org_not_found} without raising"
    - "Sigra.Organizations.select_active_organization/3 returns {:none, :zero_orgs} for a user with no memberships"
    - "select_active_organization/3 returns {:ok, org} for a user with exactly one membership"
    - "select_active_organization/3 with :previous_active_organization_id matching one of 2+ memberships returns {:ok, resumed_org}"
    - "select_active_organization/3 with 2+ memberships and no resume pointer returns {:multiple, orgs}"
    - "SessionStore.update_active_organization/3 writes the column and returns the refreshed %Sigra.Session{}"
    - "ErrorHandler behaviour typespec includes :no_active_org and :insufficient_role"
  artifacts:
    - path: "lib/sigra/scope/hydration.ex"
      provides: "Sigra.Scope.Hydration.hydrate/3 — pure scope hydration contract"
      contains: "defmodule Sigra.Scope.Hydration"
    - path: "lib/sigra/organizations.ex"
      provides: "select_active_organization/3 pure selector"
      contains: "def select_active_organization"
    - path: "lib/sigra/session_store.ex"
      provides: "update_active_organization/3 behaviour callback"
      contains: "@callback update_active_organization"
    - path: "lib/sigra/session_stores/ecto.ex"
      provides: "ecto impl of update_active_organization/3"
      contains: "def update_active_organization"
    - path: "lib/sigra/plug/error_handler.ex"
      provides: "behaviour with :no_active_org and :insufficient_role types"
      contains: ":no_active_org"
  key_links:
    - from: "lib/sigra/scope/hydration.ex"
      to: "Sigra.Organizations.get_membership/3"
      via: "direct module call"
      pattern: "Organizations\\.get_membership"
    - from: "lib/sigra/organizations.ex select_active_organization/3"
      to: "Sigra.Organizations.list_organizations_for_user/2"
      via: "direct function call"
      pattern: "list_organizations_for_user"
---

<objective>
Land the pure, side-effect-free primitives Phase 14's plugs will orchestrate:
Sigra.Scope.Hydration.hydrate/3, Sigra.Organizations.select_active_organization/3,
the SessionStore.update_active_organization/3 behaviour callback + ecto impl, and
the two new ErrorHandler error types (:no_active_org, :insufficient_role).

Purpose: Every downstream plug and generated-template edit in Plans 02 and 03 calls
INTO these primitives. Getting them right, unit-tested, and dialyzer-clean in Wave 1
collapses the SC-3 parity matrix (D-23) into a single hydrator unit test and unlocks
parallel wiring in Wave 2.

Output: One new library module (Sigra.Scope.Hydration), one new pure function on
Sigra.Organizations, one new behaviour callback with its ecto impl, and an
additive behaviour-typespec extension to Sigra.Plug.ErrorHandler — all covered by
ExUnit tests that MUST exist before or as part of each task per Wave 0 requirements.
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
@.planning/phases/14-org-plugs-scope-hydration/14-VALIDATION.md

<!-- Existing primitives this plan consumes (Phase 12 + Phase 13) -->
@lib/sigra/session.ex
@lib/sigra/session_store.ex
@lib/sigra/session_stores/ecto.ex
@lib/sigra/organizations.ex
@lib/sigra/plug/error_handler.ex
@lib/sigra/plug/require_scopes.ex
@lib/sigra/audit.ex

<interfaces>
<!-- Contracts downstream plans will consume. Extracted from canonical refs in 14-CONTEXT.md §canonical_refs. -->

# Sigra.Scope.Hydration (NEW in this plan)
@spec hydrate(scope :: struct(), config :: Sigra.Config.t(), session :: Sigra.Session.t()) ::
        {:ok, struct()} | {:error, :not_a_member | :org_not_found}

# Sigra.Organizations (EXTENDED in this plan)
@spec select_active_organization(config :: Sigra.Config.t(), user :: struct(), opts :: keyword()) ::
        {:ok, org :: struct()} | {:none, :zero_orgs} | {:multiple, [struct()]}
# opts supported in v1.1: :previous_active_organization_id (binary_id | nil)

# Sigra.SessionStore (EXTENDED behaviour — NEW callback)
@callback update_active_organization(session :: Sigra.Session.t(), org_id :: binary() | nil) ::
        {:ok, Sigra.Session.t()} | {:error, term()}

# Sigra.Plug.ErrorHandler (EXTENDED type union — additive)
@type error_type :: :unauthenticated | :stale_sudo | :rate_limited
                  | :insufficient_scope | :token_expired | :token_revoked
                  | :mfa_required | :no_active_org | :insufficient_role
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Extend SessionStore behaviour + ecto impl with update_active_organization/3</name>
  <files>lib/sigra/session_store.ex, lib/sigra/session_stores/ecto.ex, test/sigra/session_stores/ecto_test.exs</files>
  <read_first>
    - lib/sigra/session_store.ex (full file — current 7 callbacks, typespecs)
    - lib/sigra/session_stores/ecto.ex (full file — existing update patterns, Repo usage)
    - lib/sigra/session.ex (struct field order, active_organization_id type :binary_id)
    - test/sigra/session_stores/ecto_test.exs (existing test conventions — AAA style)
    - .planning/phases/14-org-plugs-scope-hydration/14-CONTEXT.md §D-20, §D-22
  </read_first>
  <behavior>
    - Test: update_active_organization/3 with a valid session + org_id UUID writes the column and returns {:ok, %Sigra.Session{active_organization_id: ^org_id}}
    - Test: update_active_organization/3 with nil org_id clears the column and returns {:ok, %Sigra.Session{active_organization_id: nil}}
    - Test: update_active_organization/3 when org_id equals the current value is a no-op-safe short-circuit (no DB write, returns {:ok, session} unchanged) — D-20 optimization
    - Test: update_active_organization/3 on a session whose row has been deleted returns {:error, :not_found} (or the existing SessionStores.Ecto convention for missing rows — verify in current file and match)
  </behavior>
  <action>
    Step 1 — Extend the behaviour at `lib/sigra/session_store.ex`:

    Add a new `@callback update_active_organization/3` immediately after the existing mutation callbacks (mirror the style of existing callbacks — `@doc` block + `@callback` line). Exact signature:

        @doc """
        Updates the :active_organization_id column on the given session row.

        Returns the refreshed %Sigra.Session{}. Implementations SHOULD short-circuit
        when `org_id` equals the session's current value (no-op-safe write).
        """
        @callback update_active_organization(session :: Sigra.Session.t(), org_id :: binary() | nil) ::
                    {:ok, Sigra.Session.t()} | {:error, term()}

    Step 2 — Implement in `lib/sigra/session_stores/ecto.ex`:

        def update_active_organization(%Sigra.Session{active_organization_id: current} = session, org_id)
            when current == org_id do
          {:ok, session}
        end

        def update_active_organization(%Sigra.Session{id: id} = _session, org_id) do
          # Single indexed UPDATE ... RETURNING * on user_sessions
          # Use the existing Repo alias already in this module; mimic the update pattern used by the
          # other mutation functions in this file (follow whichever of Ecto.Query.from/update_all or
          # Repo.get + changeset + Repo.update is already established here — DO NOT invent a new pattern).
          # Map the updated user_session row back into a %Sigra.Session{} via the same mapper the
          # existing read callbacks use (`to_session/1` or equivalent — verify and reuse).
        end

    The :binary_id org_id column was shipped in Phase 12. Do NOT add a migration.

    Step 3 — Add tests to `test/sigra/session_stores/ecto_test.exs` covering the 4 behavior cases above. Use the existing test fixtures for session creation (search the file for `session_fixture` or equivalent). Use Ecto.UUID.generate/0 for synthetic org_ids (Phase 13 membership rows are not required for this test — the column is a bare binary_id with no FK check at write time).

    Do NOT touch any other SessionStore callback. Do NOT add NimbleOptions config. This is a purely additive extension per D-20.
  </action>
  <verify>
    <automated>mix test test/sigra/session_stores/ecto_test.exs test/sigra/session_store_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - `grep -n "update_active_organization" lib/sigra/session_store.ex` shows a `@callback` line with the exact signature above
    - `grep -n "def update_active_organization" lib/sigra/session_stores/ecto.ex` shows two clauses (no-op + real update)
    - `mix test test/sigra/session_stores/ecto_test.exs` passes with the 4 new assertions
    - `mix compile --warnings-as-errors` passes (no behaviour-not-implemented warning — confirms ecto impl satisfies the new callback)
    - `mix credo --strict lib/sigra/session_store.ex lib/sigra/session_stores/ecto.ex` passes
  </acceptance_criteria>
  <done>
    Behaviour callback added, ecto impl written with no-op short-circuit, 4 unit tests green, compile clean, credo clean.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Add select_active_organization/3 pure helper to Sigra.Organizations + extend ErrorHandler behaviour</name>
  <files>lib/sigra/organizations.ex, lib/sigra/plug/error_handler.ex, test/sigra/organizations_test.exs</files>
  <read_first>
    - lib/sigra/organizations.ex (read full file — specifically get_membership/3 at line ~425, list_organizations_for_user/2 at line ~405, module layout, doc conventions)
    - lib/sigra/plug/error_handler.ex (full 63 lines — current @type error_type union, doc conventions)
    - test/sigra/organizations_test.exs (existing test setup, fixtures, AAA style)
    - .planning/phases/14-org-plugs-scope-hydration/14-CONTEXT.md §D-08, §D-11, §D-26, §CD-04
    - .planning/phases/14-org-plugs-scope-hydration/14-RESEARCH.md Pattern 1 + §D-11 discussion
  </read_first>
  <behavior>
    - Test: select_active_organization/3 with user who has zero memberships returns {:none, :zero_orgs}
    - Test: select_active_organization/3 with user who has exactly one membership returns {:ok, org} (the sole org, loaded)
    - Test: select_active_organization/3 with 2+ memberships and opts[:previous_active_organization_id] matching one of them returns {:ok, resumed_org}
    - Test: select_active_organization/3 with 2+ memberships and opts[:previous_active_organization_id] set to a non-matching id returns {:multiple, orgs}
    - Test: select_active_organization/3 with 2+ memberships and opts[:previous_active_organization_id] = nil returns {:multiple, orgs}
    - Test: the returned `{:multiple, orgs}` list is sorted by `inserted_at desc` for stable ordering (per CD-04 planner choice — documented in @doc)
    - Test: passing an unknown opts key raises (NimbleOptions-style fast-fail) OR logs a warning — match whatever current Organizations.ex convention is for opts validation; if no convention, accept silently
  </behavior>
  <action>
    Step 1 — Add `select_active_organization/3` to `lib/sigra/organizations.ex`.

    Place it in the module alongside `list_organizations_for_user/2` and `get_membership/3` (keep related functions grouped per existing file convention). Full implementation:

        @doc """
        Pure selector that returns the active organization to land a user on.

        Called from login (`Sigra.Auth.create_session/4`) and from the stale-pointer
        recovery path in `Sigra.Plug.LoadActiveOrganization`. No side effects — no
        session writes, no audit, no DB writes beyond the reads required to list
        memberships.

        Options:

          * `:previous_active_organization_id` (binary_id | nil) — if the user has
            2+ orgs and one matches this pointer, return `{:ok, that_org}` (resume
            semantics). On stale recovery this is passed as nil — the stale pointer
            must NOT be resumed.

          * `:strategy` — reserved for v1.2, ignored in v1.1.

        Returns:

          * `{:ok, org}` — user has exactly one org, or resume pointer matched.
          * `{:none, :zero_orgs}` — user has no memberships.
          * `{:multiple, orgs}` — 2+ memberships, no resume pointer match. `orgs`
            is sorted by `inserted_at desc` for stable UI ordering.
        """
        @spec select_active_organization(Sigra.Config.t(), struct(), keyword()) ::
                {:ok, struct()} | {:none, :zero_orgs} | {:multiple, [struct()]}
        def select_active_organization(config, user, opts \\ []) do
          previous = Keyword.get(opts, :previous_active_organization_id)

          case list_organizations_for_user(config, user) do
            [] ->
              {:none, :zero_orgs}

            [only] ->
              {:ok, only}

            orgs when is_list(orgs) ->
              sorted = Enum.sort_by(orgs, & &1.inserted_at, {:desc, NaiveDateTime})

              case previous && Enum.find(sorted, &(&1.id == previous)) do
                nil -> {:multiple, sorted}
                resumed -> {:ok, resumed}
              end
          end
        end

    Verify the `list_organizations_for_user/2` return type in the current file — if it returns `{:ok, list}` instead of a bare list, adjust the pattern match. If `inserted_at` is `:utc_datetime` rather than `NaiveDateTime`, use `{:desc, DateTime}` instead. Planner requires the executor to verify the exact type before committing.

    Step 2 — Extend `lib/sigra/plug/error_handler.ex` behaviour typespec (additive):

    Locate the `@type error_type ::` union. Add two new atoms at the end of the union:

        @type error_type ::
                :unauthenticated
                | :stale_sudo
                | :rate_limited
                | :insufficient_scope
                | :token_expired
                | :token_revoked
                | :mfa_required
                | :no_active_org         # NEW — no active organization on scope
                | :insufficient_role     # NEW — membership role not in required list

    Update the `@moduledoc` block (or the `@callback auth_error/3` docstring) to briefly document the two new types — one sentence each referencing Phase 14 / D-08. Keep the existing callback signature unchanged.

    Do NOT modify any existing ErrorHandler implementation in this plan — generator template edits happen in Plan 03.

    Step 3 — Add tests to `test/sigra/organizations_test.exs` covering the 7 behavior cases. Use existing organization + membership fixtures (search for `organization_fixture` / `membership_fixture` / similar in the file). If fixtures for "user with N memberships" don't exist, add local helpers to this test module — do NOT modify shared fixture files.
  </action>
  <verify>
    <automated>mix test test/sigra/organizations_test.exs test/sigra/plug/error_handler_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - `grep -n "def select_active_organization" lib/sigra/organizations.ex` shows the function exists
    - `grep -n ":no_active_org" lib/sigra/plug/error_handler.ex` matches inside the `@type error_type` union
    - `grep -n ":insufficient_role" lib/sigra/plug/error_handler.ex` matches inside the `@type error_type` union
    - `mix test test/sigra/organizations_test.exs` includes and passes the 7 new select_active_organization test cases
    - `mix compile --warnings-as-errors` clean (no unused alias, no type warnings)
    - `mix dialyzer` — the new @spec resolves without warnings for Sigra.Organizations (OK if full PLT run is deferred to CI; local run on this module is sufficient)
    - Function is pure: grep `Repo.update\|Repo.insert\|Repo.delete` inside the `select_active_organization` function body returns nothing
  </acceptance_criteria>
  <done>
    select_active_organization/3 added with 7 passing tests, sorted {:multiple, ...} output, resume-pointer semantics work. ErrorHandler typespec extended with two new atoms, compile clean, dialyzer clean for this module.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Create Sigra.Scope.Hydration.hydrate/3 pure hydrator with full test coverage</name>
  <files>lib/sigra/scope/hydration.ex, test/sigra/scope/hydration_test.exs, lib/sigra/organizations.ex</files>
  <read_first>
    - lib/sigra/session.ex (the %Sigra.Session{} struct — active_organization_id field)
    - lib/sigra/organizations.ex (get_membership/3 signature + return shape — verify it returns nil-or-membership, not {:ok, _}|{:error, _})
    - priv/templates/sigra.install/core/scope.ex (current %Scope{} fields — active_organization, membership)
    - lib/sigra/config.ex (Sigra.Config.t() type — ensure it's the right module name)
    - .planning/phases/14-org-plugs-scope-hydration/14-CONTEXT.md §D-01, §D-23, §CD-03
    - .planning/phases/14-org-plugs-scope-hydration/14-RESEARCH.md Pattern 1 (Shared Hydrator)
  </read_first>
  <behavior>
    - Test: hydrate/3 called with a session whose active_organization_id is nil returns {:ok, scope} unchanged (scope.active_organization stays nil)
    - Test: hydrate/3 called with a valid session + live membership returns {:ok, scope} with scope.active_organization = the org and scope.membership = the membership (both fully loaded, not association stubs)
    - Test: hydrate/3 called with a session whose active_organization_id points at a real org the user was REMOVED from returns {:error, :not_a_member} (NO raise)
    - Test: hydrate/3 called with a session whose active_organization_id points at a DELETED (hard-gone) or soft-deleted org returns {:error, :org_not_found} (NO raise)
    - Test: hydrate/3 NEVER raises on any of the above inputs — wrapping in `assert_raise` MUST fail
    - Test: the returned scope on happy path satisfies `scope.active_organization.id == session.active_organization_id`
    - Test: the function has zero side effects — calling it twice yields byte-identical scopes (structural equality), and Repo.insert/update/delete is never invoked (verify via Ecto sandbox counters or explicit @moduledoc contract)
  </behavior>
  <action>
    Step 1 — Create `lib/sigra/scope/hydration.ex` (planner choice per CD-03 — top-level `Sigra.Scope` namespace, NOT under `Sigra.Organizations`). Create the `lib/sigra/scope/` directory if it does not exist.

    Full file:

        defmodule Sigra.Scope.Hydration do
          @moduledoc """
          Pure scope-hydration contract shared between `Sigra.Plug.LoadActiveOrganization`
          (Plug pipeline) and the generated `UserAuth.on_mount` callback (LiveView).

          Given a `(scope, config, session)`, returns a fully populated `%Scope{}`
          or a fail-closed error tuple. This module is the SINGLE place scope
          hydration lives. Any future scope augmentation — impersonation
          (v1.2), feature flags, passkey context — extends this function.

          Fail-closed contract: on stale pointer (`:not_a_member`) or deleted org
          (`:org_not_found`), callers MUST clear `session.active_organization_id`
          and re-run the selector. See `Sigra.Plug.LoadActiveOrganization` for
          the orchestration.

          Source of truth: Phase 14 CONTEXT.md D-01 / D-14 / D-23.
          """

          alias Sigra.Organizations

          @type hydrate_error :: :not_a_member | :org_not_found

          @spec hydrate(scope :: struct(), config :: Sigra.Config.t(), session :: Sigra.Session.t()) ::
                  {:ok, struct()} | {:error, hydrate_error()}

          def hydrate(scope, _config, %Sigra.Session{active_organization_id: nil}) do
            {:ok, scope}
          end

          def hydrate(scope, config, %Sigra.Session{active_organization_id: org_id}) do
            user = scope.user

            case Organizations.fetch_organization(config, org_id) do
              {:ok, org} ->
                case Organizations.get_membership(config, user, org) do
                  nil ->
                    {:error, :not_a_member}

                  membership ->
                    {:ok, %{scope | active_organization: org, membership: membership}}
                end

              {:error, :not_found} ->
                {:error, :org_not_found}
            end
          end
        end

    **Verification before committing:** The hydrator references `Organizations.fetch_organization/2`. Read `lib/sigra/organizations.ex` and confirm a non-raising fetcher exists. Acceptable names: `fetch_organization/2`, `get_organization/2`, `get_organization_by_id/2`. If only the bang version (`get_organization!/2`) exists, add a sibling non-raising function `fetch_organization/2` returning `{:ok, org} | {:error, :not_found}` — use `Repo.get/2` + nil-to-error conversion, and respect Phase 13's soft-delete (filter out rows with `deleted_at != nil`). Do NOT use the bang variant in the hydrator — D-14 + research §Pitfall 2 explicitly reject bang-calls in the hydration path.

    Step 2 — Create `test/sigra/scope/hydration_test.exs` with the 7 behavior cases listed above. Test structure:

        defmodule Sigra.Scope.HydrationTest do
          use Sigra.DataCase, async: true

          alias Sigra.Scope.Hydration

          # Setup: create user, org, membership via existing fixtures. Get the config
          # via the standard Sigra.Config.from_env/0 or test helper used in
          # test/sigra/organizations_test.exs.

          describe "hydrate/3" do
            test "nil active_organization_id returns scope unchanged" do ... end
            test "valid session + live membership returns populated scope" do ... end
            test "revoked membership returns {:error, :not_a_member} without raising" do ... end
            test "deleted org returns {:error, :org_not_found} without raising" do ... end
            test "does not raise on any input" do ... end
            test "is pure — two calls yield structurally-equal scopes" do ... end
          end

    For the "does not raise" test, exercise all error paths with `refute_raise` idiom (or wrap in try/catch and assert no exception).

    Use the same scope-building helper as existing tests — check `test/support/` for a `scope_fixture` or equivalent. If none exists, construct a scope struct directly: `%Scope{user: user, active_organization: nil, membership: nil, impersonating_from: nil}`. The hydrator test asserts behavior on the field transitions, not on the full scope shape.

    Step 3 — DO NOT add the `Sigra.Plug.LoadActiveOrganization` plug in this task. That is Plan 02 Task 1. This task ships only the pure hydrator + its unit tests, per Wave 1 scope.
  </action>
  <verify>
    <automated>mix test test/sigra/scope/hydration_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - `ls lib/sigra/scope/hydration.ex` — file exists
    - `grep -n "defmodule Sigra.Scope.Hydration" lib/sigra/scope/hydration.ex` matches
    - `grep -n "def hydrate" lib/sigra/scope/hydration.ex` shows 2 clauses (nil + non-nil org_id)
    - `grep -c "get_organization!" lib/sigra/scope/hydration.ex` returns 0 — no bang calls in hydration path (Pitfall 2 guard)
    - `mix test test/sigra/scope/hydration_test.exs` passes with 6-7 test cases
    - `mix compile --warnings-as-errors` clean
    - `grep -n "Repo\\." lib/sigra/scope/hydration.ex` returns 0 — hydrator does NOT call Repo directly; goes through Organizations context
    - `mix credo --strict lib/sigra/scope/hydration.ex` passes
  </acceptance_criteria>
  <done>
    Sigra.Scope.Hydration created, all 6-7 unit tests green, fail-closed on stale pointer and deleted org, never raises, pure (no Repo calls in the module), dialyzer-clean.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Plug pipeline → hydrator | untrusted `session.active_organization_id` from DB row (could be stale or point at deleted org) |
| hydrator → Organizations context | validated config + user; hydrator is the only caller that handles :not_a_member / :org_not_found gracefully |
| SessionStore ecto impl → user_sessions table | trusted write path for active_organization_id column |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-14-01 | Tampering / Authz bypass | Sigra.Scope.Hydration.hydrate/3 | mitigate | Hydrator calls `get_membership/3` BEFORE trusting `session.active_organization_id`; membership miss returns `{:error, :not_a_member}` rather than a populated scope (fail-closed). Regression test asserts `{:error, :not_a_member}` on revoked-membership input (PITFALLS O-6, ORG-SCOPE-03). |
| T-14-02 | Denial of Service / Error path | hydrator on deleted org | mitigate | Hydrator uses non-raising `fetch_organization/2` (not `get_organization!/2`); returns `{:error, :org_not_found}` instead of propagating `Ecto.NoResultsError` → 500 (PITFALLS O-6). Test asserts `refute_raise`. |
| T-14-03 | Information Disclosure via cross-tenant leak | select_active_organization/3 | mitigate | Selector only calls `list_organizations_for_user/2` (Phase 13 tenant-scoped). Resume pointer `:previous_active_organization_id` is matched against the user's OWN membership list — a forged pointer cannot resume an org the user is not a member of. Regression test: pass a forged UUID as resume pointer, assert result is `{:multiple, orgs}` with only user's real orgs. |
| T-14-04 | Tampering | SessionStore.update_active_organization/3 | accept | This callback is a trusted internal write; caller (Plug.put_active_organization in Plan 02) is responsible for verifying membership BEFORE invoking. The callback itself does not enforce authz — documented in `@doc`. Acceptance rationale: layering authz into every mutation primitive creates N places to get it wrong; single choke point is in the orchestrator. |
| T-14-05 | Repudiation | stale-pointer transition | mitigate (partial) | Plan 02 emits `Sigra.Audit.log_safe("organization.active_auto_reassigned", ...)` on every transition. Plan 01 ensures the pure primitives surface the :not_a_member / :org_not_found signals so the orchestrator can audit them. No audit in this plan itself. |

All HIGH-severity threats (T-14-01, T-14-02, T-14-03) have `mitigate` disposition backed by concrete test assertions listed in the task acceptance criteria. No threat in this plan blocks on ASVS L1 requirements that are out of scope.
</threat_model>

<verification>
## Phase Checks

- [ ] `mix test test/sigra/scope/hydration_test.exs test/sigra/organizations_test.exs test/sigra/session_stores/ecto_test.exs` — all green
- [ ] `mix compile --warnings-as-errors` — clean (no behaviour-not-implemented warnings)
- [ ] `mix credo --strict lib/sigra/scope/hydration.ex lib/sigra/session_store.ex lib/sigra/session_stores/ecto.ex lib/sigra/plug/error_handler.ex lib/sigra/organizations.ex` — clean
- [ ] `git diff mix.exs` — empty (Phase 14 adds zero deps; Research §Standard Stack)
- [ ] `grep -rn "get_organization!" lib/sigra/scope/` — returns 0 matches (Pitfall 2 guard)
</verification>

<success_criteria>
All 3 primitives land pure, tested, and dialyzer-clean:

1. `Sigra.Scope.Hydration.hydrate/3` — fail-closed on stale pointer + deleted org, never raises, no Repo calls in the module body (goes through Organizations context).
2. `Sigra.Organizations.select_active_organization/3` — pure selector with correct 0/1/2+ + resume-pointer semantics, sorted {:multiple, orgs} output.
3. `Sigra.SessionStore` behaviour + ecto impl — update_active_organization/3 callback added, no-op-safe short-circuit, refreshed %Sigra.Session{} returned.
4. `Sigra.Plug.ErrorHandler` — `@type error_type` additively extended with `:no_active_org` and `:insufficient_role`.
5. Wave 0 test requirement met: `test/sigra/scope/hydration_test.exs` and `test/sigra/organizations_test.exs` (extended) exist BEFORE Plan 02 starts — satisfies VALIDATION.md §Wave 0.

Decisions covered: D-01, D-08 (partial — behaviour only), D-11, D-14 (fail-closed surface), D-20, D-21 (memoization surface), D-22 (library-side only), D-23 (hydrator unit test), D-26 (selector pure-unit test).

Requirements covered: ORG-SCOPE-03 (hydrator primitive), ORG-SCOPE-06 (selector primitive).
</success_criteria>

<output>
After completion, create `.planning/phases/14-org-plugs-scope-hydration/14-01-SUMMARY.md` per the standard template:
- Files created / modified
- Test cases added (names + count)
- Decisions delivered (D-01, D-11, D-20, D-08 partial, D-22)
- Requirements progress (ORG-SCOPE-03 primitive, ORG-SCOPE-06 primitive)
- Any drift from CONTEXT.md canonical refs discovered during execution
- Handoff notes for Plan 02 (LoadActiveOrganization, RequireMembership, PutActiveOrganization)
</output>
