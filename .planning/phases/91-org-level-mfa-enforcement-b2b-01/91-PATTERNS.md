# Phase 91: Org-level MFA enforcement (B2B-01) — Pattern Map

**Mapped:** 2026-04-29
**Files analyzed:** 17 (3 new lib, 6 modified templates, 5 new tests, 3 modified planning artifacts)
**Analogs found:** 14 / 17 (3 are minor planning-doc edits with no code analog)

> **Source-of-truth pointer.** RESEARCH.md is exhaustive on the eight discretion gaps and
> structural twins. This file does not re-derive those choices — it pins the *concrete*
> excerpts the planner copies from. Where RESEARCH.md and this file disagree, RESEARCH.md
> wins (it has the verified line numbers).

---

## File Classification

### Library code

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/plug/require_org_mfa.ex` (NEW, ~80–120 lines) | plug (request guard) | request-response (halt-via-error-handler) | `lib/sigra/plug/require_membership.ex` (148 lines) | exact (structural twin) |
| `lib/sigra/live_view/require_org_mfa.ex` (NEW, ~50–70 lines) | LiveView on_mount (mount guard) | request-response (halt-via-bridge-assign) | `lib/sigra/live_view/organization_scope.ex` (89 lines) | exact (structural twin) |
| `lib/sigra/organizations.ex` (MODIFIED) — `set_mfa_policy/4` + `set_mfa_policy_changeset/2` + `normalize_multi_result_for_mfa_policy/1` + `__using__/1` delegator | service / orchestrator | CRUD + atomic-audit (Multi + transact) | `update_organization/4` (line 434–449), `rename_organization/4` (line 517–543), `update_slug/4` (line 568–612) | exact (three sibling orchestrators in same file) |

### Generator templates

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `priv/templates/sigra.upgrade/alter_add_enforce_mfa_for_members.exs` (NEW) | migration template | DDL (idempotent additive) | `priv/templates/sigra.upgrade/alter_add_personal.exs` (35 lines) | exact (structural twin) |
| `priv/templates/sigra.install/organizations/migration.exs` (MODIFIED) | migration template | DDL (greenfield) | self (extend in place; new field shape mirrors `personal` field) | self |
| `priv/templates/sigra.install/organizations/organization.ex` (MODIFIED) | schema | schema definition | self (mirror line 23 `personal` field — library-managed, NOT in `cast/3`) | self |
| `priv/templates/sigra.install/organizations/router_injection.ex` (MODIFIED) | router pipeline / live_session | request routing | self (extend `:org_scoped` pipeline at lines 16–20 + `live_session :organization_scoped` at lines 43–48) | self |
| `priv/templates/sigra.install/organizations/live/organization_settings_live.ex` (MODIFIED) | LiveView | event-driven (form submit) | self (Slug section at lines 66–112 is the visual+mechanism twin for the new Security section) | self |
| `priv/templates/sigra.install/core/error_handler.ex` (MODIFIED) | host module | request-response (auth_error clause) | self (extend after `:insufficient_role` clause at lines 60–68) | self |

### Tests

| New File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `test/sigra/plug/require_org_mfa_test.exs` (NEW) | unit test | request-response (Plug.Test) | `test/sigra/plug/require_membership_test.exs` | exact |
| `test/sigra/live_view/require_org_mfa_test.exs` (NEW) | unit test | LiveView on_mount (no LV deps) | `test/sigra/live_view/organization_scope_test.exs` | exact |
| `test/sigra/organizations_mfa_policy_audit_atomicity_test.exs` (NEW) | atomicity test | Postgres CHECK fault injection + telemetry | `test/sigra/jwt_refresh_audit_cofate_test.exs` (330 lines) | exact (Phase 82 fault-injection canon) |
| `test/sigra/organizations/set_mfa_policy_test.exs` (NEW, or fold into `context_test.exs`) | unit test | CRUD orchestrator | existing `test/sigra/organizations/context_test.exs` (per RESEARCH §Wave 0) | role-match |
| `test/example/test/example_web/integration/org_mfa_enforcement_test.exs` (NEW) | integration test | full Phoenix conn round-trip | `test/example/test/example_web/integration/phase_16_integration_test.exs` | role-match |

### Planning / docs (no code analog — minor surgical edits)

| Modified File | Edit |
|---|---|
| `.planning/ROADMAP.md` | one-line: `organization.mfa_policy_changed` → `organization.mfa_policy_change` (D-91-12) |
| `CHANGELOG.md` | append B2B-01 trace bullet under `[Unreleased]` at phase commit |
| `.planning/phases/91-org-level-mfa-enforcement-b2b-01/91-VERIFICATION.md` | authored at phase close per success criterion #5 |

---

## Pattern Assignments

### `lib/sigra/plug/require_org_mfa.ex` (NEW — plug, request-response)

**Analog:** `lib/sigra/plug/require_membership.ex` (148 lines) — structural twin.

**Imports / module skeleton pattern** (lines 1–60 of analog):

```elixir
defmodule Sigra.Plug.RequireMembership do
  @moduledoc """
  Halts the pipeline unless `conn.assigns[:current_scope]` has a non-nil
  `active_organization` and (optionally) a membership role in the configured
  `:roles` list.

  Structural twin of `Sigra.Plug.RequireScopes` — same `init/1` validation
  pattern, same `error_handler` delegation, same halt shape. Any divergence
  from RequireScopes is a bug. Phase 14 D-05 / D-06 / D-07 / D-21.
  """

  @behaviour Plug
  # ...
end
```

**`init/1` pattern (raw Keyword + ArgumentError, NOT NimbleOptions)** — analog lines 71–95:

```elixir
@impl Plug
def init(opts) do
  error_handler = Keyword.fetch!(opts, :error_handler)
  required_roles = Keyword.get(opts, :roles, [])
  role_universe = resolve_role_universe(opts)

  unless is_list(required_roles) and Enum.all?(required_roles, &is_atom/1) do
    raise ArgumentError,
          "Sigra.Plug.RequireMembership :roles must be a list of atoms, got: " <>
            inspect(required_roles)
  end

  invalid = required_roles -- role_universe

  unless invalid == [] do
    raise ArgumentError,
          "Sigra.Plug.RequireMembership :roles contains unknown atoms: " <>
            inspect(invalid) <>
            ". Valid roles: " <> inspect(role_universe)
  end

  opts
  |> Keyword.put(:error_handler, error_handler)
  |> Keyword.put(:roles, required_roles)
end
```

**RequireOrgMfa adaptation:** required keys `:error_handler` (atom module, validated `is_atom/1` and not nil) and `:organizations` (the host's `use Sigra.Organizations` module — pattern from `lib/sigra/plug/load_active_organization.ex:65`). Optional `:enrollment_path` defaulting to `"/users/settings/mfa"` (RESEARCH gap 4 verbatim copy). Skip NimbleOptions per RESEARCH gap 1 — the entire `Sigra.Plug.*` family uses raw Keyword + ArgumentError.

**`call/2` pattern (cond-laddered halt)** — analog lines 126–147:

```elixir
@impl Plug
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
```

**RequireOrgMfa adaptation — cond order (per RESEARCH §Twin 1):**

1. `is_nil(scope) or is_nil(scope.user) or is_nil(scope.active_organization)` → fall through `conn` (let `RequireMembership` handle this case earlier in pipeline; defensive only).
2. `scope.active_organization.enforce_mfa_for_members == false` → fall through `conn` (no enforcement).
3. `Sigra.MFA.enabled?(config, scope.user) == true` → fall through `conn` (already enrolled).
4. else: store the current path on session via `Plug.Conn.put_session(conn, :user_return_to, current_path(conn))` (per RESEARCH gap 7 — reuse, not new key) **after** validating it starts with `/` and not `//` (RESEARCH §Security Domain V3), then `error_handler.auth_error(:org_mfa_required, opts) |> Plug.Conn.halt()`.

**Config access (RESEARCH §Twin 1 "subtle issue"):** read `organizations.__sigra_org_config__()` at `call/2` time (NOT cache at init/1 — `LoadActiveOrganization` does the same at lines 83–84). Pass that config into `Sigra.MFA.enabled?/2`.

**Sibling-plug disambiguation (D-91-04):** moduledoc must distinguish from `Sigra.Plug.RequireMFAEnrolled` (54 lines, `lib/sigra/plug/require_mfa_enrolled.ex`) — that plug enforces "any user must MFA on this route" (admin routes), reads `scope.user`, takes `:mfa_check_fn`. RequireOrgMfa enforces "all members of the active org must MFA", reads `scope.active_organization.enforce_mfa_for_members`. **Do NOT modify `RequireMFAEnrolled`.**

**Phoenix 1.8 / Ecto 3.13 specifics:** none for the plug — `Plug.Conn`, `put_session/3`, `current_path/1` are all Plug stdlib. `Phoenix.Controller.current_path/1` is Phoenix 1.8 stable.

---

### `lib/sigra/live_view/require_org_mfa.ex` (NEW — on_mount, request-response)

**Analog:** `lib/sigra/live_view/organization_scope.ex` (89 lines) — structural twin.

**Bridge pattern (LANDMINE — RESEARCH §Twin 2 + §Landmines #1):** the on_mount MUST NOT call `Phoenix.LiveView.redirect/2`. Assign `:sigra_redirect_to` on the socket and return `{:halt, socket}`. The host's root LV layout consumes the assign and triggers the actual redirect. **Calling LV directly will pull `phoenix_live_view` into the library's hard test deps and break the existing test pattern.**

**`on_mount/4` pattern** — analog lines 40–77:

```elixir
def on_mount(opts, params, _session, socket) when is_list(opts) do
  organizations = Keyword.fetch!(opts, :organizations)
  scope_module = Keyword.fetch!(opts, :scope_module)
  login_path = Keyword.get(opts, :login_path, "/users/log_in")
  config = organizations.__sigra_org_config__()

  scope = socket.assigns[:current_scope]

  cond do
    is_nil(scope) or is_nil(scope.user) ->
      # Return a tagged tuple the caller bridges to Phoenix.LiveView.redirect.
      # Kept as data (not a direct LV call) so this module is unit-testable
      # without pulling phoenix_live_view into Sigra's test deps.
      {:halt, assign_redirect(socket, login_path)}

    true ->
      slug = params["org"] || params[:org]

      case resolve(config, scope, slug) do
        {:ok, org, membership} ->
          new_scope = scope_module.put_active_organization(scope, org, membership)
          {:cont, put_in(socket.assigns[:current_scope], new_scope)}

        :not_found ->
          {:halt, put_in(socket.assigns[:sigra_not_found], true)}
      end
  end
end

defp assign_redirect(socket, path) do
  put_in(socket.assigns[:sigra_redirect_to], path)
end
```

**RequireOrgMfa on_mount adaptation:**
- Required opts: `:organizations` (for `__sigra_org_config__/0` access). Optional: `:enrollment_path` (default `"/users/settings/mfa"`).
- `cond` ladder mirrors the plug:
  1. nil scope/user/active_organization → `{:cont, socket}` (defer to plug-layer redirect path).
  2. `scope.active_organization.enforce_mfa_for_members == false` → `{:cont, socket}`.
  3. `Sigra.MFA.enabled?(config, scope.user) == true` → `{:cont, socket}`.
  4. else: `{:halt, assign_redirect(socket, enrollment_path)}` — bridges via `:sigra_redirect_to` assign exactly like analog line 75.

**No `put_session` from on_mount** (analog moduledoc lines 7–10): "the on_mount path is READ-ONLY with respect to the Plug session — it never calls `put_session/2` (it has no `Plug.Conn`). The plug counterpart owns all session writes." Since `:user_return_to` is a session key, **the on_mount cannot store it**. The HTTP plug catches the same user on next full nav and writes `:user_return_to` then. This is by design (D-91-03 catches mid-session policy flips on next `live_redirect`; full nav re-runs the pipeline).

**Test analog pattern** — `test/sigra/live_view/organization_scope_test.exs` lines 125–172 — assert `halted.assigns[:sigra_redirect_to]` exists (no LV needed):

```elixir
assert {:halt, halted} =
         OrganizationScope.on_mount(default_opts(), %{"org" => "acme"}, %{}, socket)

assert halted.assigns[:sigra_redirect_to] == "/users/log_in"
```

---

### `lib/sigra/organizations.ex` (MODIFIED — orchestrator + delegator)

**Analog:** `update_organization/4` (lines 434–449), `rename_organization/4` (lines 517–543), `update_slug/4` (lines 568–612). All three are sibling orchestrators in the same file using identical Multi + append_audit + transaction shape.

**Cleanest twin — `update_organization/4` lines 434–449:**

```elixir
@spec update_organization(map(), map(), struct(), map()) :: {:ok, struct()} | {:error, term()}
def update_organization(config, scope, org, attrs) do
  changeset = update_org_changeset(org, attrs, config)

  result =
    Multi.new()
    |> Multi.update(:organization, changeset)
    |> append_audit(config, "organization.update", scope)
    |> config.repo.transaction()
    |> normalize_multi_result()

  case result do
    {:ok, %{organization: org}} -> {:ok, org}
    error -> error
  end
end
```

**Audit-with-metadata twin — `rename_organization/4` lines 526–542:**

```elixir
if changeset.valid? do
  result =
    Multi.new()
    |> Multi.update(:organization, changeset)
    |> append_audit(config, "organization.rename", scope,
      metadata: %{old_name: org.name, new_name: Map.get(params, :name)}
    )
    |> config.repo.transaction()
    |> normalize_multi_result()

  case result do
    {:ok, %{organization: updated}} -> {:ok, updated}
    error -> error
  end
else
  {:error, %{changeset | action: :update}}
end
```

**`set_mfa_policy/4` recommended shape (per RESEARCH §Twin 3):**

```elixir
@spec set_mfa_policy(map(), map(), struct(), boolean()) ::
        {:ok, struct()}
        | {:error, :admin_must_enroll_first}
        | {:error, :mfa_policy_aborted}
        | {:error, Ecto.Changeset.t()}
def set_mfa_policy(config, scope, org, value) when is_boolean(value) do
  changeset = set_mfa_policy_changeset(org, value)

  cond do
    # D-91-14: no-op short-circuit BEFORE Multi opens (LANDMINE #6 — Multi.update
    # does NOT short-circuit; only Repo.update does. Caller-side check is mandatory).
    changeset.changes == %{} ->
      {:ok, org}

    # D-91-09: admin pre-flight refuse on enable
    value == true and not Sigra.MFA.enabled?(config, scope.user) ->
      {:error, :admin_must_enroll_first}

    true ->
      result =
        Multi.new()
        |> Multi.update(:organization, changeset)
        |> append_audit(config, "organization.mfa_policy_change", scope,
          metadata: %{old_value: org.enforce_mfa_for_members, new_value: value}
        )
        |> config.repo.transact()  # NOTE: transact/1, NOT transaction/1 (RESEARCH gap 5)
        |> normalize_multi_result_for_mfa_policy()

      case result do
        {:ok, %{organization: updated}} -> {:ok, updated}
        {:error, %Ecto.Changeset{}} = err -> err
        {:error, _other} -> {:error, :mfa_policy_aborted}
      end
  end
end

defp set_mfa_policy_changeset(org, value) do
  # LANDMINE #8: use change/2, NOT cast/3. The field is NOT in the schema's
  # cast/3 allowlist (D-91-05 — library-writes-only).
  Ecto.Changeset.change(org, %{enforce_mfa_for_members: value})
end
```

**Reusable private helpers (lines 1305–1322 — reuse VERBATIM, no edit):**

```elixir
defp normalize_multi_result({:ok, changes}), do: {:ok, changes}

defp normalize_multi_result({:error, :guard_last_owner, :last_owner, _}),
  do: {:error, :last_owner}

defp normalize_multi_result({:error, _step, %Ecto.Changeset{} = cs, _}), do: {:error, cs}
defp normalize_multi_result({:error, _step, reason, _}), do: {:error, reason}

defp append_audit(multi, config, action, scope, extra \\ []) do
  audit_opts = [
    repo: config.repo,
    audit_schema: config[:audit_schema],
    actor_id: get_in_scope(scope, :user, :id),
    metadata: Keyword.get(extra, :metadata, %{})
  ]

  Audit.log_multi_safe(multi, action, audit_opts)
end
```

**New private helper — `normalize_multi_result_for_mfa_policy/1`:** maps `{:error, :audit, _changeset, _}` (audit insert failure under fault injection — Ecto.Multi shape) to `{:error, :mfa_policy_aborted}` per Phase 82/85 precedent. Phase 82 D-82-02 sets the family naming. Pattern:

```elixir
defp normalize_multi_result_for_mfa_policy({:ok, changes}), do: {:ok, changes}
defp normalize_multi_result_for_mfa_policy({:error, _step, %Ecto.Changeset{} = cs, _}),
  do: {:error, cs}
defp normalize_multi_result_for_mfa_policy({:error, _step, _reason, _}),
  do: {:error, :mfa_policy_aborted}
```

**`__using__/1` macro delegator** — analog lines 280–311 (existing 2-arity delegators):

```elixir
def update_organization(scope, org, attrs),
  do: Sigra.Organizations.update_organization(@sigra_org_config, scope, org, attrs)

def rename_organization(scope, org, params),
  do: Sigra.Organizations.rename_organization(@sigra_org_config, scope, org, params)
```

**Add this delegator (per RESEARCH open-question #1, recommended shape):**

```elixir
def set_mfa_policy(scope, value),
  do:
    Sigra.Organizations.set_mfa_policy(
      @sigra_org_config,
      scope,
      scope.active_organization,
      value
    )
```

The 2-arity delegator hides `org` from the host LV (which always operates on `scope.active_organization`). Host LV calls `Organizations.set_mfa_policy(scope, value)`.

**Phoenix 1.8 / Ecto 3.13 specifics:**
- **`config.repo.transact/1`** (NOT `transaction/1`) — Ecto 3.13's idiom; `lib/sigra/passkeys.ex:114, 195, 227, 396, 407, 426` is the verified in-codebase precedent. **Do not refactor existing `update_organization/4`, `rename_organization/4`, etc. to use `transact/1`** (RESEARCH gap 5: "surgical edits only").
- `Ecto.Changeset.change/2` (not `cast/3`) for the changeset — the field is library-managed.

---

### `priv/templates/sigra.upgrade/alter_add_enforce_mfa_for_members.exs` (NEW — migration template, DDL)

**Analog:** `priv/templates/sigra.upgrade/alter_add_personal.exs` (35 lines) — structural twin (idempotent additive).

**Full analog — copy and adapt:**

```elixir
defmodule <%= repo_module %>.Migrations.AddPersonalToOrganizations do
  @moduledoc """
  Phase 18 D-01: add `personal` column + partial unique index
  enforcing at-most-one-personal-org-per-user.

  Runs AFTER `AddOwnerUserIdToOrganizations` — the partial unique
  index references `owner_user_id`, so the column must exist first.

  Uses `add_if_not_exists` / `create_if_not_exists` so a re-run on a
  schema that already has the column is a safe no-op.
  """

  use Ecto.Migration

  def up do
    alter table(:organizations) do
      add_if_not_exists :personal, :boolean, null: false, default: false
    end

    create_if_not_exists unique_index(:organizations, [:owner_user_id],
                           where: "personal = true",
                           name: :organizations_personal_owner_uidx
                         )
  end

  def down do
    drop_if_exists index(:organizations, [:owner_user_id],
                     name: :organizations_personal_owner_uidx
                   )

    alter table(:organizations) do
      remove_if_exists :personal, :boolean
    end
  end
end
```

**Adaptation for Phase 91:**
- Module name: `<%= repo_module %>.Migrations.AddEnforceMfaForMembersToOrganizations`.
- Moduledoc: "Phase 91 B2B-01: add `enforce_mfa_for_members` column for org-level MFA enforcement. Idempotent additive — re-run safely no-ops."
- `up`: `add_if_not_exists :enforce_mfa_for_members, :boolean, null: false, default: false`. NO partial index (boolean column has no associated index per D-91-05).
- `down`: `remove_if_exists :enforce_mfa_for_members, :boolean`.

**Idempotency requirement (LANDMINE #10):** both `up` and `down` MUST use `add_if_not_exists` / `remove_if_exists`. An upgrade-then-downgrade-then-upgrade cycle on a host that previously installed Phase 91 must succeed without error.

---

### `priv/templates/sigra.install/organizations/migration.exs` (MODIFIED — DDL extension)

**Analog (self):** existing `personal` field at line 14 (Postgres branch) and line 123 (MySQL/SQLite branch).

**Postgres branch excerpt (lines 13–14):**

```elixir
# D-01: personal-workspace flag (added Phase 18). Sticky origin, NOT current state — a personal org stays `personal: true` even after inviting others.
add :personal, :boolean, null: false, default: false
```

**Add immediately after, in BOTH adapter branches** (line 14 Postgres + line 123 MySQL/SQLite):

```elixir
# Phase 91 B2B-01: org-level MFA enforcement. Library-managed via
# Sigra.Organizations.set_mfa_policy/4; NEVER exposed via cast/3.
add :enforce_mfa_for_members, :boolean, null: false, default: false
```

**Phoenix 1.8 / Ecto 3.13 specifics:** plain boolean — no Postgres-specific features. MySQL/SQLite branch gets identical syntax (assumption A4 — RESEARCH). Phase 94 will remove the MySQL/SQLite branch entirely; don't fight it now.

---

### `priv/templates/sigra.install/organizations/organization.ex` (MODIFIED — schema field)

**Analog (self):** existing `personal` library-managed field at line 23 — exact precedent for the new field shape (NOT in `cast/3`).

**Excerpt (lines 18–33):**

```elixir
schema "organizations" do
  field :name, :string
  field :slug, :string
  field :deleted_at, :utc_datetime
  # D-01: personal-workspace flag (Phase 18). Library-managed, NOT exposed via cast/3.
  field :personal, :boolean, default: false

  # D-00: sticky origin owner (Phase 18). Library sets via put_change/3 in
  # Sigra.Organizations.create_organization/3; NEVER exposed via cast/3.
  belongs_to :owner, <%= context_module %>.<%= schema_alias %>, foreign_key: :owner_user_id

  has_many :memberships, <%= context_module %>.OrganizationMembership
  has_many :invitations, <%= context_module %>.OrganizationInvitation

  timestamps(type: :utc_datetime)
end
```

**Add (after line 23):**

```elixir
# Phase 91 B2B-01: org-level MFA enforcement. Library-managed via
# Sigra.Organizations.set_mfa_policy/4; NOT exposed via cast/3.
field :enforce_mfa_for_members, :boolean, default: false
```

**Existing `changeset/2` (lines 41–49) must NOT be modified** — D-91-05 + Landmine #8: keep `enforce_mfa_for_members` out of the `cast/3` allowlist so host code cannot accidentally write it. The library uses `Ecto.Changeset.change/2` (NOT cast) to set the field via `set_mfa_policy_changeset/2`.

---

### `priv/templates/sigra.install/organizations/router_injection.ex` (MODIFIED — pipeline + on_mount)

**Analog (self):** existing `:org_scoped` pipeline lines 16–20 + `live_session :organization_scoped` lines 43–48.

**Current `:org_scoped` excerpt (lines 16–20):**

```elixir
# Sigra organizations
pipeline :org_scoped do
  plug Sigra.Plug.LoadOrganizationFromSlug
  plug Sigra.Plug.RequireMembership,
    error_handler: <%= web_module %>.AuthErrorHandler
end
```

**Extend to (per D-91-01 + RESEARCH §Twin 1 — ordered AFTER RequireMembership):**

```elixir
# Sigra organizations
pipeline :org_scoped do
  plug Sigra.Plug.LoadOrganizationFromSlug
  plug Sigra.Plug.RequireMembership,
    error_handler: <%= web_module %>.AuthErrorHandler
  # Phase 91 B2B-01: org-level MFA enforcement.
  plug Sigra.Plug.RequireOrgMfa,
    error_handler: <%= web_module %>.AuthErrorHandler,
    organizations: <%= app_module %>.Organizations
end
```

**Current `live_session :organization_scoped` excerpt (lines 43–48):**

```elixir
live_session :organization_scoped,
  on_mount: [
    {<%= web_module %>.UserAuth, :ensure_authenticated},
    {<%= web_module %>.UserAuth, :assign_user_organizations},
    {Sigra.LiveView.OrganizationScope, []}
  ] do
  live "/settings", OrganizationSettingsLive, :edit
  live "/members", OrganizationMembersLive, :index
end
```

**Extend to (per D-91-03 — pair the on_mount alongside OrganizationScope):**

```elixir
live_session :organization_scoped,
  on_mount: [
    {<%= web_module %>.UserAuth, :ensure_authenticated},
    {<%= web_module %>.UserAuth, :assign_user_organizations},
    {Sigra.LiveView.OrganizationScope, []},
    # Phase 91 B2B-01: org-level MFA enforcement. Catches mid-session policy
    # flips on next live_redirect within this live_session. Full nav re-runs
    # the HTTP pipeline (plug Sigra.Plug.RequireOrgMfa above).
    {Sigra.LiveView.RequireOrgMfa, [organizations: <%= app_module %>.Organizations]}
  ] do
  live "/settings", OrganizationSettingsLive, :edit
  live "/members", OrganizationMembersLive, :index
end
```

**RESEARCH correction (§Phase Scope Verification):** CONTEXT canonical_refs lists `priv/templates/sigra.install/core/auth_hooks.ex` as the on_mount registration site — **that is incorrect**. `auth_hooks.ex` hosts application-domain hooks (`on_register`, `on_email_change`). The on_mount list lives in `router_injection.ex` (this file) lines 43–48. The planner should ignore the CONTEXT auth_hooks.ex reference for this purpose.

**Phoenix 1.8 specifics:** `live_session` boundary is sticky — cross-`live_session` navigation severs the LV connection and re-runs the destination pipeline + on_mounts from scratch (Landmine #4). No special handling needed.

---

### `priv/templates/sigra.install/organizations/live/organization_settings_live.ex` (MODIFIED — Security section)

**Analog (self):** Slug section at lines 66–112 — visual + mechanism twin for the new Security section's progressive-disclosure shape (toggle reveal → form open → submit/dismiss).

**Slug section excerpt (lines 66–112) — visual template:**

```heex
<%%= # Slug (progressive disclosure + sudo + typed-confirm + 7-day alias) — D-11, D-12 %>
<section class="bg-base-200 p-6 rounded-lg mt-8">
  <h2 class="text-lg font-semibold">Slug</h2>
  <p class="text-sm text-base-content/70 mt-1">
    Current: <code>{@org.slug}</code>
  </p>

  <%%= if @slug_form_open? do %>
    <.form for={@slug_form} phx-submit="update_slug" class="mt-4 space-y-3">
      <.input field={@slug_form[:slug]} label="New slug" required />
      <.input field={@slug_form[:password]} type="password" label="Current password"
              autocomplete="current-password" required />
      <.input field={@slug_form[:confirm_slug]}
              label={"Type " <> @org.slug <> " to confirm"} required />

      <div role="alert" class="alert alert-warning alert-soft">
        <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
        <span>...impact preview copy...</span>
      </div>

      <div class="flex gap-2">
        <.button type="submit" class="btn btn-error" phx-disable-with="Updating...">
          Update slug
        </.button>
        <.button type="button" phx-click="close_slug_form" class="btn btn-ghost">
          Cancel
        </.button>
      </div>
    </.form>
  <%% else %>
    <.button phx-click="open_slug_form" class="mt-4">Change slug</.button>
  <%% end %>
</section>
```

**Existing `mount/3` pattern (lines 31–46) — twin for the assigns the new section needs:**

```elixir
def mount(_params, _session, socket) do
  scope = socket.assigns.current_scope
  org = scope.active_organization

  socket =
    socket
    |> assign(:page_title, "Organization settings")
    |> assign(:org, org)
    |> assign(:rename_form, to_form(%{"name" => org.name}, as: :organization))
    |> assign(:slug_form_open?, false)
    |> assign(:delete_form_open?, false)
    |> assign(:slug_form, blank_slug_form())
    |> assign(:delete_form, blank_delete_form())

  {:ok, socket}
end
```

**Existing event handler twin — `update_slug` (lines 190–211):**

```elixir
def handle_event("update_slug", %{"slug_change" => params}, socket) do
  case Organizations.update_slug(socket.assigns.current_scope, params) do
    {:ok, org} ->
      {:noreply,
       socket
       |> put_flash(:info, "Slug updated. The old slug redirects for 7 days.")
       |> redirect(to: ~p"/organizations/#{org.slug}/settings")}

    {:error, :invalid_password} ->
      {:noreply, assign(socket, :slug_form,
        params |> slug_form_with_errors([{:password, "That password is incorrect."}]))}

    {:error, %Ecto.Changeset{} = changeset} ->
      errors = remap_slug_errors(changeset, socket.assigns.org.slug)
      {:noreply, assign(socket, :slug_form, slug_form_with_errors(params, errors))}
  end
end
```

**New Security section adaptations (per UI-SPEC verbatim copy + RESEARCH gap 3):**
- Inserted **between** General (line 64) and Slug (line 66). Class: `bg-base-200 p-6 rounded-lg mt-8` (matches Slug section card).
- Heading: `<h2 class="text-lg font-semibold">Security</h2>`.
- New `mount/3` assigns: `:security_form_open?`, `:pending_value`, `:unenrolled_count`, `:total_count`, `:admin_mfa_enabled?`. Add a sync inline `Organizations.count_unenrolled_members(scope)` query (RESEARCH gap 3 — sync is fine for N≤10000; UI-SPEC §Empty/Loading row 2 leaves async at planner discretion).
- Toggle markup: **raw `<input type="checkbox" class="toggle toggle-primary" phx-click="toggle_mfa_policy" />`** — NOT `<.input type="checkbox">`. Phoenix 1.8 stock `<.input>` emits `class="checkbox"`, not `class="toggle"` (Landmine #3 + UI-SPEC §Component Inventory).
- Three new event handlers: `toggle_mfa_policy` (opens confirm form, sets `:pending_value`), `save_mfa_policy` (calls `Organizations.set_mfa_policy(scope, pending_value)`, branches on `{:ok, _}` / `{:error, :admin_must_enroll_first}` / `{:error, :mfa_policy_aborted}` / `{:error, %Ecto.Changeset{}}`), `dismiss_mfa_policy` (closes form, resets toggle).
- **Direction-specific dismiss labels (UI-SPEC §Confirm form CTAs):** when enabling, primary = "Require MFA for all members", secondary = "Don't require MFA". When disabling, primary = "Stop requiring MFA", secondary = "Keep MFA required". Never the literal word "Cancel".
- **Admin-pre-flight UI (D-91-09):** when `@admin_mfa_enabled? == false`, render toggle with `disabled` attribute + `<p class="text-error text-sm mt-2">` containing UI-SPEC verbatim copy `"Enable MFA on your account first. You'd be locked out of this organization otherwise."` + `<.link navigate={~p"/users/settings/mfa"} class="link link-primary text-sm">Set up MFA on your account →</.link>`. `aria-describedby` on the toggle points to the paragraph.
- **Impact preview row (D-91-10):** rendered ONLY when `@unenrolled_count > 0` and `@security_form_open? == true`. UI-SPEC verbatim copy: `"{N} of {M} members are not enrolled in MFA. They will be redirected to enroll on their next request to this organization."` Wrapped in `<div role="alert" class="alert alert-warning alert-soft">` with `hero-exclamation-triangle` icon (size-5).
- **Admin-only gate (RESEARCH Assumption A1 — VERIFY before planning):** UI-SPEC + CONTEXT both assume this LV is reachable only by `:admin`/`:owner` roles. If the existing `:org_scoped` pipeline does NOT restrict the settings LV to those roles, the planner adds `Sigra.Plug.RequireMembership, roles: [:admin, :owner]` either to a sub-pipeline scoped to `/organizations/:org/settings` or as an in-mount guard. Tier-correctness call.

**Phoenix 1.8 / DaisyUI specifics:**
- DaisyUI 5 utility classes: `bg-base-200`, `alert alert-warning alert-soft`, `btn btn-primary`, `btn btn-ghost`, `toggle toggle-primary`, `badge badge-success badge-soft`, `link link-primary`. All theme-aware (auto light/dark via Phoenix 1.8 default).
- Heroicon helper: `<.icon name="hero-exclamation-triangle" class="size-5" />` (existing core_components shape — sized via DaisyUI `size-5` (= 20px), NOT the older `w-5 h-5` Tailwind 3 idiom).
- No new components, no external CSS, no shadcn (UI-SPEC §Registry Safety: vacuously satisfied).

---

### `priv/templates/sigra.install/core/error_handler.ex` (MODIFIED — auth_error clause)

**Analog (self):** existing `:insufficient_role` clause (lines 60–68) is the closest twin for the new `:org_mfa_required` clause.

**Excerpt (lines 60–68):**

```elixir
@impl true
def auth_error(conn, :insufficient_role, _opts) do
  conn
  |> put_flash(:error, "You don't have permission to access this page in the current organization.")
  |> put_status(:forbidden)
  |> put_view(<%= web_module %>.ErrorHTML)
  |> render(:"403")
  |> halt()
end
```

**Add immediately after (per RESEARCH gap 2 — atom name `:org_mfa_required`):**

```elixir
@impl true
def auth_error(conn, :org_mfa_required, opts) do
  enrollment_path = Keyword.get(opts, :enrollment_path, ~p"/users/settings/mfa")

  conn
  |> put_flash(
    :warning,
    "Your organization requires two-factor authentication. Set up MFA below to continue."
  )
  |> redirect(to: enrollment_path)
  |> halt()
end
```

**Atom-name rationale (RESEARCH gap 2):** `:org_mfa_required` matches the existing `:no_active_org` / `:insufficient_role` / `:stale_sudo` / `:rate_limited` family of compound, specific atoms. `:mfa_required` would collide semantically with the sibling `Sigra.Plug.RequireMFAEnrolled` (account-level enforcement). Disambiguates D-91-04 sibling-plug stance.

**Note on `<%= if organizations? do %>`:** existing template wraps `:no_active_org` in this conditional for `--no-organizations` installs. **`:org_mfa_required` is org-only; wrap the new clause in the same `<%= if organizations? do %>` block** so the host compiles cleanly under `--no-organizations` (mirror lines 41–58 conditional shape).

---

### Tests — pattern assignments

#### `test/sigra/plug/require_org_mfa_test.exs` (NEW — plug unit)

**Analog:** `test/sigra/plug/require_membership_test.exs` (verified — lines 1–120 reviewed).

**Test scaffold pattern (analog lines 1–83):**

```elixir
defmodule Sigra.Plug.RequireMembershipTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias Sigra.Plug.RequireMembership

  defmodule TestScope do
    defstruct [:user, :active_organization, :membership, :impersonating_from]
  end

  defmodule TestOrg do
    defstruct [:id, :name]
  end

  defmodule TestMembership do
    defstruct [:id, :role]
  end

  defmodule TestUser do
    defstruct [:id]
  end

  defmodule FakeErrorHandler do
    @behaviour Sigra.Plug.ErrorHandler

    @impl true
    def auth_error(conn, type, opts) do
      calls = Process.get(:fake_handler_calls, [])
      Process.put(:fake_handler_calls, calls ++ [{type, opts}])

      conn
      |> Plug.Conn.put_resp_content_type("text/plain")
      |> Plug.Conn.send_resp(403, to_string(type))
    end
  end

  defmodule BombErrorHandler do
    @behaviour Sigra.Plug.ErrorHandler

    @impl true
    def auth_error(_conn, type, _opts) do
      raise "BombErrorHandler should NOT have been called; got #{inspect(type)}"
    end
  end

  setup do
    Process.delete(:fake_handler_calls)
    :ok
  end
```

**Adaptations:** add `enforce_mfa_for_members` to `TestOrg` defstruct. Stub `Sigra.MFA.enabled?/2` via a module-attribute test config or a Mox expectation (passkeys.ex pattern). Mirror the `init/1` validation tests (missing `:error_handler`, missing `:organizations`, defaults). Mirror the `call/2` cond-ladder tests: nil scope (fall through), no enforcement (fall through), enforcement + enrolled (fall through), enforcement + not enrolled (halt + `auth_error(:org_mfa_required, _)` + session has `:user_return_to`).

#### `test/sigra/live_view/require_org_mfa_test.exs` (NEW — on_mount unit)

**Analog:** `test/sigra/live_view/organization_scope_test.exs` lines 125–172 (assertions on `:sigra_redirect_to` and `:sigra_not_found` socket assigns — no LV deps needed).

**Assertion pattern (analog lines 125–134):**

```elixir
test "unauthenticated socket (scope.user == nil) halts with redirect flag" do
  scope = %TestScope{user: nil}
  socket = fake_socket(%{current_scope: scope})

  assert {:halt, halted} =
           OrganizationScope.on_mount(default_opts(), %{"org" => "acme"}, %{}, socket)

  assert halted.assigns[:sigra_redirect_to] == "/users/log_in"
end
```

**Adaptations:** test the four cond branches as data assertions on the returned tuple's `:cont`/`:halt` tag and the `:sigra_redirect_to` assign. Build `fake_socket/1` exactly like the analog (no LV deps). Stub `Sigra.MFA.enabled?/2` via a test-config indirection. **Do not** add `phoenix_live_view` to test deps.

#### `test/sigra/organizations_mfa_policy_audit_atomicity_test.exs` (NEW — Postgres atomicity)

**Analog:** `test/sigra/jwt_refresh_audit_cofate_test.exs` (330 lines — Phase 82 D-82-04 canon).

**Setup pattern (analog lines 51–129):**

```elixir
setup do
  start_supervised!({PostgresRepo, PostgresRepo.default_config()})
  repo = PostgresRepo

  Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

  for t <- ["jwt_refresh_cofate_user_tokens", "jwt_refresh_cofate_users"] do
    Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS #{t} CASCADE", [])
  end

  Ecto.Adapters.SQL.query!(repo, """
    CREATE TABLE jwt_refresh_cofate_users (
      id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
      email text,
      ...
    )
    """, [])

  Ecto.Adapters.SQL.query!(repo, """
    CREATE TABLE IF NOT EXISTS audit_events (
      id uuid PRIMARY KEY,
      occurred_at timestamp NOT NULL DEFAULT now(),
      action varchar(255) NOT NULL,
      outcome varchar(32) NOT NULL DEFAULT 'success',
      actor_id uuid, actor_type varchar(64) NOT NULL DEFAULT 'user',
      target_id uuid, target_type varchar(64),
      ip_address varchar(64), user_agent varchar(512),
      metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
      organization_id uuid, effective_user_id uuid,
      inserted_at timestamp NOT NULL DEFAULT now()
    )
    """, [])

  Ecto.Adapters.SQL.query!(repo, "TRUNCATE TABLE audit_events RESTART IDENTITY CASCADE", [])
  %{repo: repo}
end
```

**Fault-injection test pattern (analog lines 216–261) — load-bearing test #3:**

```elixir
test "happy path fault injection: audit CHECK rejects api.jwt_refresh → jwt_refresh_aborted, no partial rotation",
     %{repo: repo} do
  Ecto.Adapters.SQL.query!(repo, """
    ALTER TABLE audit_events
    ADD CONSTRAINT jwt_refresh_cofate_happy_guard CHECK (action <> 'api.jwt_refresh')
    """, [])

  try do
    user = insert_user!(repo)
    cfg = sigra_config(repo)
    {raw_refresh, _} = RefreshToken.create(cfg, user, ["profile:read"], opts)
    before_tokens = count(repo, "jwt_refresh_cofate_user_tokens")

    ref = :telemetry.attach(
      {__MODULE__, :jwt_cofate_happy_guard},
      [:sigra, :audit, :log_safe_error],
      &VerifyFailureTelemetryHandler.handle_event/4,
      self()
    )

    try do
      assert {:error, :jwt_refresh_aborted} = JWT.refresh(cfg, raw_refresh, opts)
      assert_receive {:telemetry, [:sigra, :audit, :log_safe_error], %{count: 1},
                      %{action: "api.jwt_refresh", reason: :constraint_violation}}
    after
      :telemetry.detach(ref)
    end

    assert count(repo, "jwt_refresh_cofate_user_tokens") == before_tokens
    assert count_where(repo, "audit_events", "action = 'api.jwt_refresh'") == 0
  after
    Ecto.Adapters.SQL.query!(repo,
      "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS jwt_refresh_cofate_happy_guard", [])
  end
end
```

**Adaptations (per RESEARCH §Atomic-Audit Fault-Injection Test Pattern):**
- Test-schema names: `mfa_policy_users`, `mfa_policy_orgs` (with `enforce_mfa_for_members boolean default false`), `mfa_policy_memberships`.
- CHECK constraint: `action <> 'organization.mfa_policy_change'`.
- Expected error atom: `{:error, :mfa_policy_aborted}` (matches RESEARCH gap 6 + Phase 82/85 family).
- Assert telemetry: `%{action: "organization.mfa_policy_change", reason: :constraint_violation}`.
- Assert no orphan write: `before_value == after_value` on `enforce_mfa_for_members`.
- **Five tests total:** (1) happy path, (2) audit off, (3) fault injection, (4) no-op short-circuit (D-91-14 — assert no audit row written when value already matches), (5) admin pre-flight refuse (D-91-09 — assert `{:error, :admin_must_enroll_first}` + no audit row).

**Telemetry handler analog (lines 18–23):**

```elixir
defmodule VerifyFailureTelemetryHandler do
  @moduledoc false
  def handle_event(event, measurements, metadata, parent) do
    send(parent, {:telemetry, event, measurements, metadata})
  end
end
```

**Helpers analog (lines 173–183 + 185–188):**

```elixir
defp count(repo, table) do
  %{rows: [[n]]} = Ecto.Adapters.SQL.query!(repo, "SELECT count(*)::bigint FROM #{table}", [])
  n
end

defp count_where(repo, table, where) do
  %{rows: [[n]]} =
    Ecto.Adapters.SQL.query!(repo, "SELECT count(*)::bigint FROM #{table} WHERE #{where}", [])
  n
end
```

#### `test/sigra/organizations/set_mfa_policy_test.exs` (NEW — library function unit)

**Analog:** existing `test/sigra/organizations/context_test.exs` (per RESEARCH §Wave 0 — `update_organization`/`rename_organization` unit tests live there). RESEARCH leaves the planner discretion: spawn a new file or extend `context_test.exs`. Recommendation: spawn a new file for B2B-01 discoverability; the file scope (no-op + admin pre-flight + happy + changeset error) justifies it.

#### `test/example/test/example_web/integration/org_mfa_enforcement_test.exs` (NEW — generator-host integration)

**Analog:** `test/example/test/example_web/integration/phase_16_integration_test.exs` (lines 1–100, per RESEARCH §Sources). Pattern: `use ExampleWeb.ConnCase, async: false`, `register_and_log_in_user`, `create_org!` helper, full Phoenix conn round-trip.

**Adaptations:** assert that an admin's `set_mfa_policy(scope, true)` call → a non-MFA member's GET to `/organizations/:slug/members` → returns 302 redirect to `/users/settings/mfa` with session `:user_return_to` set to the original path. After the member enrolls MFA, the next GET to the same path returns 200.

---

## Shared Patterns

### Atomic Multi + Audit (cross-cutting — applies to `Sigra.Organizations.set_mfa_policy/4`)

**Source:** `lib/sigra/organizations.ex` lines 434–449, 517–543, 568–612, 1305–1322.
**Apply to:** `set_mfa_policy/4` orchestrator.

**The Multi shape (verified across all org orchestrators):**

```elixir
Multi.new()
|> Multi.update(:organization, changeset)
|> append_audit(config, "organization.<action>", scope, metadata: %{...})
|> config.repo.transact()  # NEW code: transact/1 (passkeys.ex precedent). EXISTING code keeps transaction/1.
|> normalize_multi_result_for_<action>()
```

**Reuse `append_audit/5` private helper (line 1313) verbatim** — it already wires `repo`, `audit_schema`, `actor_id` from scope, and `metadata` from `extra`.

**Phase 82/85 stable error atom convention:** `<noun>_aborted` short form. Phase 91 = `:mfa_policy_aborted` (RESEARCH gap 6).

### Bridge-pattern on_mount (cross-cutting — applies to `Sigra.LiveView.RequireOrgMfa`)

**Source:** `lib/sigra/live_view/organization_scope.ex` line 75 + `lib/sigra/live_view/admin_scope.ex` line 25 (both verified).
**Apply to:** any new on_mount in this phase (only `RequireOrgMfa`).

**Pattern:**

```elixir
defp assign_redirect(socket, path) do
  put_in(socket.assigns[:sigra_redirect_to], path)
end

# In on_mount:
{:halt, assign_redirect(socket, login_path)}
```

**Why:** keeps `phoenix_live_view` out of the library's hard test deps. Tests assert `socket.assigns[:sigra_redirect_to] == path` instead of intercepting an LV redirect. Host's root layout reads the assign and triggers the actual redirect (responsibility lives in host generated code).

### Plug `init/1` validation (cross-cutting — applies to `Sigra.Plug.RequireOrgMfa`)

**Source:** `lib/sigra/plug/require_membership.ex:72–95`, `lib/sigra/plug/require_mfa_enrolled.ex:29`, `lib/sigra/plug/load_active_organization.ex:64–68`.
**Apply to:** the new plug.

**Pattern (raw Keyword + ArgumentError, NOT NimbleOptions):**

```elixir
@impl Plug
def init(opts) do
  error_handler = Keyword.fetch!(opts, :error_handler)
  _ = Keyword.fetch!(opts, :organizations)
  enrollment_path = Keyword.get(opts, :enrollment_path, "/users/settings/mfa")

  unless is_atom(error_handler) and not is_nil(error_handler) do
    raise ArgumentError,
          "Sigra.Plug.RequireOrgMfa :error_handler must be a module, got: " <>
            inspect(error_handler)
  end

  opts
  |> Keyword.put(:error_handler, error_handler)
  |> Keyword.put(:enrollment_path, enrollment_path)
end
```

**RESEARCH gap 1 / Landmine #9:** the entire `Sigra.Plug.*` family deliberately uses raw Keyword + ArgumentError. NimbleOptions is used elsewhere (`Sigra.Passkeys`, `Sigra.Account`, `Sigra.Organizations.__validate_config__!`) but never in plug `init/1`. Stay symmetric with the family.

### Idempotent migration template (cross-cutting — applies to upgrade migration)

**Source:** `priv/templates/sigra.upgrade/alter_add_personal.exs` (full file).
**Apply to:** `priv/templates/sigra.upgrade/alter_add_enforce_mfa_for_members.exs`.

**Pattern:** `add_if_not_exists` in `up/0`, `remove_if_exists` in `down/0`. Re-run safety + rollback safety (Landmine #10).

### Session key reuse — `:user_return_to` (cross-cutting — applies to plug)

**Source:** `priv/templates/sigra.install/core/user_auth.ex` lines 67–73, 478, 481 + `confirmation_controller.ex` line 57.
**Apply to:** `Sigra.Plug.RequireOrgMfa.call/2` session write.

**Pattern (existing `user_auth.ex` precedent — lines 67–73 read it back on login):**

```elixir
# Plug write site (NEW):
conn
|> Plug.Conn.put_session(:user_return_to, current_path(conn))
|> error_handler.auth_error(:org_mfa_required, opts)
|> Plug.Conn.halt()
```

**Why reuse, not new key:** RESEARCH gap 7 — `:user_return_to` is already restored by the existing login flow + post-MFA-enrollment success branch. Zero new code in `mfa_settings_live.ex` (assumption A2 — verify before relying). A new `:org_mfa_return_to` would require a new MFA-enrollment-success handler change.

**Path-validation requirement (D-91-08, OWASP V3):** before storing, validate the path starts with `/` and does NOT start with `//`. Reject crafted X-Forwarded-derived paths.

---

## No Analog Found

No phase-91 file lacks a close analog in the codebase. Every code file has a verified structural twin or extends an existing template in place. The three planning-doc edits (ROADMAP.md, CHANGELOG.md, VERIFICATION.md) are minor surgical edits and do not need a code analog.

---

## Cross-cutting Phoenix 1.8 / Ecto 3.13 / NimbleOptions / DaisyUI Specifics

| Tech | Specific the planner needs |
|---|---|
| **Phoenix 1.8** | `live_session` boundary is sticky (Landmine #4); `current_path/1` + `put_session/3` are the session-write primitives in plugs; on_mount runs on `live_redirect` within a session, full HTTP nav re-runs the pipeline. |
| **Phoenix 1.8 LiveView** | `<.input type="checkbox">` in stock `core_components.ex` emits `class="checkbox"`, NOT `class="toggle"`. Use raw `<input class="toggle toggle-primary">` (Landmine #3 + UI-SPEC §Component Inventory). |
| **Ecto 3.13** | `Repo.transact/1` (NEW code, passkeys.ex precedent) vs. `Repo.transaction/1` (legacy org orchestrators — keep as-is, do NOT refactor). `Multi.update` does NOT short-circuit on empty changesets; caller-side `changeset.changes == %{}` check is mandatory (Landmine #6 + D-91-14). Use `Ecto.Changeset.change/2` (NOT `cast/3`) for library-managed fields (Landmine #8 + D-91-05). |
| **NimbleOptions** | Already in `mix.exs` (`~> 1.1`). Used in `Sigra.Passkeys`, `Sigra.Account`, `Sigra.Organizations.__validate_config__!`. **Do NOT use** for `Sigra.Plug.RequireOrgMfa.init/1` — the entire `Sigra.Plug.*` family uses raw Keyword + ArgumentError (RESEARCH gap 1 + Landmine #9). |
| **DaisyUI 5** | All classes used in Phase 91 are theme-aware: `bg-base-200`, `alert alert-warning alert-soft`, `btn btn-primary`, `btn btn-ghost`, `toggle toggle-primary`, `badge badge-success badge-soft`, `link link-primary`, `text-error`, `text-base-content/70`. NO hex colors, NO custom CSS, NO shadcn (UI-SPEC §Registry Safety). |
| **Heroicons** | Use `<.icon name="hero-..." class="size-5" />` shape (already in core_components — `size-5` is the DaisyUI 5 / Tailwind 4 idiom; older `w-5 h-5` works but is less consistent with new code). |

---

## Metadata

**Analog search scope:**
- `lib/sigra/plug/` (entire directory — 8 files reviewed)
- `lib/sigra/live_view/` (entire directory)
- `lib/sigra/organizations.ex` (lines 280–348, 410–620, 1290–1350)
- `lib/sigra/passkeys.ex` (lines 95–230 — `Repo.transact/1` precedent)
- `lib/sigra/audit.ex` (lines 200–310 — `log_multi_safe/3` + telemetry)
- `lib/sigra/mfa.ex` (lines 915–950 — `enabled?/2`)
- `priv/templates/sigra.install/organizations/` (entire subdirectory)
- `priv/templates/sigra.install/core/error_handler.ex`, `user_auth.ex`, `confirmation_controller.ex`
- `priv/templates/sigra.upgrade/alter_add_personal.exs`
- `test/sigra/jwt_refresh_audit_cofate_test.exs` (full file — Phase 82 fault-injection canon)
- `test/sigra/plug/require_membership_test.exs` (lines 1–120)
- `test/sigra/live_view/organization_scope_test.exs` (lines 125–185)

**Files scanned:** ~25 (12 library, 8 templates, 5 tests).

**Pattern extraction date:** 2026-04-29.

**Verification:** All file paths, line numbers, and code excerpts in this document are verified against the working tree as of `chore/phase-88-uat-evidence` (`d7c152e`). Any drift means the file under analysis has been modified since 2026-04-29 and the planner should re-verify.
