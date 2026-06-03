# Phase 27: Admin Access Foundation - Pattern Map

**Mapped:** 2026-04-16
**Files analyzed:** 16
**Analogs found:** 16 / 16

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/mix/tasks/sigra.install.ex` | config | request-response | `lib/mix/tasks/sigra.install.ex` | exact |
| `lib/sigra/install/features/admin.ex` | config | file-I/O | `lib/sigra/install/features/organizations.ex` | exact |
| `priv/templates/sigra.install/admin/router_injection.ex` | route | request-response | `priv/templates/sigra.install/organizations/router_injection.ex` | exact |
| `priv/templates/sigra.install/admin/policy.ex` | config | request-response | `priv/templates/sigra.install/core/error_handler.ex` | role-match |
| `lib/sigra/admin/policy.ex` | utility | request-response | `lib/sigra/plug/error_handler.ex` | role-match |
| `lib/sigra/admin/scope.ex` | model | transform | `lib/sigra/scope.ex` | exact |
| `lib/sigra/plug/require_admin_access.ex` | middleware | request-response | `lib/sigra/plug/require_membership.ex` | exact |
| `lib/sigra/live_view/admin_scope.ex` | middleware | request-response | `lib/sigra/live_view/organization_scope.ex` | exact |
| `priv/templates/sigra.install/admin/components/admin_shell.ex` | component | request-response | `priv/templates/sigra.install/organizations/components/org_switcher.ex` | role-match |
| `test/example/lib/example_web/components/admin_shell.ex` | component | request-response | `test/example/lib/example_web/components/org_switcher.ex` | role-match |
| `test/example/lib/example_web/components/layouts.ex` | component | request-response | `test/example/lib/example_web/components/layouts.ex` | exact |
| `test/example/lib/example_web/router.ex` | route | request-response | `test/example/lib/example_web/router.ex` | exact |
| `test/sigra/install/features/admin_test.exs` | test | file-I/O | `test/sigra/install/features/organizations_test.exs` | exact |
| `test/sigra/plug/require_admin_access_test.exs` | test | request-response | `test/sigra/plug/require_membership_test.exs` | exact |
| `test/sigra/live_view/admin_scope_test.exs` | test | request-response | `test/sigra/live_view/organization_scope_test.exs` | exact |
| `test/example/test/example_web/integration/phase_27_integration_test.exs` | test | request-response | `test/example/test/example_web/integration/phase_16_integration_test.exs` | exact |

## Pattern Assignments

### `lib/mix/tasks/sigra.install.ex` (config, request-response)

**Analog:** `lib/mix/tasks/sigra.install.ex`

**Feature registration pattern** ([`lib/mix/tasks/sigra.install.ex:37`](/Users/jon/projects/sigra/lib/mix/tasks/sigra.install.ex#L37), [`lib/mix/tasks/sigra.install.ex:43`](/Users/jon/projects/sigra/lib/mix/tasks/sigra.install.ex#L43), [`lib/mix/tasks/sigra.install.ex:53`](/Users/jon/projects/sigra/lib/mix/tasks/sigra.install.ex#L53)):
```elixir
  @features [
    Sigra.Install.Features.Core,
    Sigra.Install.Features.Organizations,
    Sigra.Install.Features.Passkeys
  ]

  @switches [
    ...
    organizations: :boolean,
    passkeys: :boolean,
    yes: :boolean
  ]

  @default_opts [
    ...
    organizations: true,
    passkeys: true
  ]
```

**Binding hydration pattern** ([`lib/mix/tasks/sigra.install.ex:111`](/Users/jon/projects/sigra/lib/mix/tasks/sigra.install.ex#L111)):
```elixir
    [
      context_module: inspect(Module.concat([base, context_name])),
      ...
      organizations?: Keyword.get(opts, :organizations, true),
      passkeys?: Keyword.get(opts, :passkeys, true),
      ...
      opts: opts
    ]
```

Use this exact additive switch style for `admin: :boolean`, `admin: true`, and `admin?: ...`.

---

### `lib/sigra/install/features/admin.ex` (config, file-I/O)

**Analog:** `lib/sigra/install/features/organizations.ex`

**Feature contract pattern** ([`lib/sigra/install/features/organizations.ex:32`](/Users/jon/projects/sigra/lib/sigra/install/features/organizations.ex#L32), [`lib/sigra/install/features/organizations.ex:37`](/Users/jon/projects/sigra/lib/sigra/install/features/organizations.ex#L37)):
```elixir
  @behaviour Sigra.Install.Feature

  alias Sigra.Install.Injection

  @impl true
  def enabled?(opts), do: Keyword.get(opts, :organizations, true)
```

**Files/injections/migrations split** ([`lib/sigra/install/features/organizations.ex:40`](/Users/jon/projects/sigra/lib/sigra/install/features/organizations.ex#L40), [`lib/sigra/install/features/organizations.ex:148`](/Users/jon/projects/sigra/lib/sigra/install/features/organizations.ex#L148), [`lib/sigra/install/features/organizations.ex:165`](/Users/jon/projects/sigra/lib/sigra/install/features/organizations.ex#L165)):
```elixir
  def files(binding) do
    ...
    [
      {:eex, "organizations/organizations.ex", ...},
      {:eex, "organizations/components/org_switcher.ex", ...},
      {:eex, "organizations/controllers/organization_switch_controller.ex", ...}
    ]
  end

  def injections(binding) do
    ...
    [router_injection(otp_app, binding)]
  end

  def migrations(_binding) do
    [
      {:organizations, "organizations/migration.exs", "create_organizations.exs"},
      {:audit_events_org_columns, "core/alter_audit_events_add_org_columns.exs",
       "alter_audit_events_add_org_columns.exs"}
    ]
  end
```

**Template-eval injection helper** ([`lib/sigra/install/features/organizations.ex:225`](/Users/jon/projects/sigra/lib/sigra/install/features/organizations.ex#L225)):
```elixir
  defp router_injection(otp_app, binding) do
    content = eval_template!("organizations/router_injection.ex", binding)

    %Injection{
      target: Path.join(["lib", "#{otp_app}_web", "router.ex"]),
      marker: "# Sigra organizations",
      anchor: :before_last_end,
      content: content
    }
  end
```

Copy this module shape directly for `Features.Admin`; keep all admin-owned files isolated under `admin/`.

---

### `priv/templates/sigra.install/admin/router_injection.ex` and `test/example/lib/example_web/router.ex` (route, request-response)

**Analogs:** `priv/templates/sigra.install/organizations/router_injection.ex`, `test/example/lib/example_web/router.ex`

**Router scope + pipeline pattern** ([`priv/templates/sigra.install/organizations/router_injection.ex:15`](/Users/jon/projects/sigra/priv/templates/sigra.install/organizations/router_injection.ex#L15), [`test/example/lib/example_web/router.ex:150`](/Users/jon/projects/sigra/test/example/lib/example_web/router.ex#L150)):
```elixir
  pipeline :org_scoped do
    plug Sigra.Plug.LoadOrganizationFromSlug,
      error_handler: ExampleWeb.AuthErrorHandler,
      organizations: Example.Organizations,
      session_store: Sigra.SessionStores.Ecto,
      session_store_opts: [repo: Example.Repo, session_schema: Example.Accounts.UserSession],
      scope_module: Example.Accounts.Scope

    plug Sigra.Plug.RequireMembership, error_handler: ExampleWeb.AuthErrorHandler
  end
```

**Plug/live_session parity pattern** ([`test/example/lib/example_web/router.ex:170`](/Users/jon/projects/sigra/test/example/lib/example_web/router.ex#L170)):
```elixir
    live_session :organization_scoped,
      on_mount: [
        {ExampleWeb.UserAuth, :ensure_authenticated},
        {ExampleWeb.UserAuth, :assign_user_organizations},
        {Sigra.LiveView.OrganizationScope,
         [organizations: Example.Organizations, scope_module: Example.Accounts.Scope]}
      ] do
      live "/settings", OrganizationSettingsLive, :edit
      live "/members", OrganizationMembersLive, :index
    end
```

Admin routing should copy this structure exactly: one admin pipeline plus one matching `live_session`; do not use `forward`.

---

### `priv/templates/sigra.install/admin/policy.ex` and `lib/sigra/admin/policy.ex` (config/utility, request-response)

**Analogs:** `priv/templates/sigra.install/core/error_handler.ex`, `lib/sigra/plug/error_handler.ex`

**Small host-owned behaviour seam** ([`lib/sigra/plug/error_handler.ex:53`](/Users/jon/projects/sigra/lib/sigra/plug/error_handler.ex#L53)):
```elixir
  @type error_type ::
          :unauthenticated
          | :stale_sudo
          | :rate_limited
          | :insufficient_scope
          | :token_expired
          | :token_revoked
          | :mfa_required
          | :no_active_org
          | :insufficient_role
          | :not_found

  @callback auth_error(Plug.Conn.t(), error_type(), keyword()) :: Plug.Conn.t()
```

**Generated host boundary style** ([`priv/templates/sigra.install/core/error_handler.ex:1`](/Users/jon/projects/sigra/priv/templates/sigra.install/core/error_handler.ex#L1)):
```elixir
defmodule <%= web_module %>.AuthErrorHandler do
  @behaviour Sigra.Plug.ErrorHandler
  use <%= web_module %>, :verified_routes
  ...
end
```

Model the admin policy the same way: a tiny library behaviour plus one generated host module implementing it. Keep only explicit callbacks such as `platform_admin?/1` and `admin_org_ids/1`.

---

### `lib/sigra/admin/scope.ex` (model, transform)

**Analog:** `lib/sigra/scope.ex`

**Derived-scope constructor pattern** ([`lib/sigra/scope.ex:16`](/Users/jon/projects/sigra/lib/sigra/scope.ex#L16)):
```elixir
  @spec build(scope_module :: module(), user :: struct() | map() | nil, opts :: keyword()) ::
          struct()
  def build(scope_module, user, opts \\ []) when is_atom(scope_module) and is_list(opts) do
    struct(scope_module,
      user: user,
      active_organization: Keyword.get(opts, :active_organization),
      membership: Keyword.get(opts, :membership),
      impersonating_from: nil
    )
  end
```

The admin scope module should follow the same pattern: derived from `current_scope`, built with explicit fields, and not mutating the host `%Scope{}` struct.

---

### `lib/sigra/plug/require_admin_access.ex` (middleware, request-response)

**Analog:** `lib/sigra/plug/require_membership.ex`

**Init validation pattern** ([`lib/sigra/plug/require_membership.ex:72`](/Users/jon/projects/sigra/lib/sigra/plug/require_membership.ex#L72)):
```elixir
  def init(opts) do
    error_handler = Keyword.fetch!(opts, :error_handler)
    required_roles = Keyword.get(opts, :roles, [])
    ...

    opts
    |> Keyword.put(:error_handler, error_handler)
    |> Keyword.put(:roles, required_roles)
  end
```

**Single choke-point enforcement pattern** ([`lib/sigra/plug/require_membership.ex:126`](/Users/jon/projects/sigra/lib/sigra/plug/require_membership.ex#L126)):
```elixir
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

Reuse this shape for admin access: compute/expect a resolved admin scope and halt through the configured handler. Keep authorization in the plug, not in route helpers or components.

---

### `lib/sigra/live_view/admin_scope.ex` (middleware, request-response)

**Analog:** `lib/sigra/live_view/organization_scope.ex`

**LiveView mount parity pattern** ([`lib/sigra/live_view/organization_scope.ex:40`](/Users/jon/projects/sigra/lib/sigra/live_view/organization_scope.ex#L40)):
```elixir
  def on_mount(opts, params, _session, socket) when is_list(opts) do
    organizations = Keyword.fetch!(opts, :organizations)
    scope_module = Keyword.fetch!(opts, :scope_module)
    login_path = Keyword.get(opts, :login_path, "/users/log_in")
    config = organizations.__sigra_org_config__()

    scope = socket.assigns[:current_scope]

    cond do
      is_nil(scope) or is_nil(scope.user) ->
        {:halt, assign_redirect(socket, login_path)}

      true ->
        slug = params["org"] || params[:org]
        ...
    end
  end
```

**Denied/not-found signalling pattern** ([`lib/sigra/live_view/organization_scope.ex:63`](/Users/jon/projects/sigra/lib/sigra/live_view/organization_scope.ex#L63)):
```elixir
          :not_found ->
            {:halt, put_in(socket.assigns[:sigra_not_found], true)}
```

Admin `on_mount` should mirror the admin plug and return data-only halt signals (`:sigra_redirect_to`, `:sigra_not_found`, or equivalent) rather than embedding app-specific rendering.

---

### `priv/templates/sigra.install/admin/components/admin_shell.ex`, `test/example/lib/example_web/components/admin_shell.ex`, and `test/example/lib/example_web/components/layouts.ex` (component, request-response)

**Analogs:** `test/example/lib/example_web/components/org_switcher.ex`, `test/example/lib/example_web/components/layouts.ex`, `test/example/lib/example_web/components/core_components.ex`

**Generated host component style** ([`test/example/lib/example_web/components/org_switcher.ex:20`](/Users/jon/projects/sigra/test/example/lib/example_web/components/org_switcher.ex#L20)):
```elixir
  use ExampleWeb, :html

  alias Plug.CSRFProtection

  attr :current_scope, :any, required: true
  attr :user_organizations, :list, required: true
  attr :return_to, :string, default: "/"
```

**Layout hook pattern** ([`test/example/lib/example_web/components/layouts.ex:43`](/Users/jon/projects/sigra/test/example/lib/example_web/components/layouts.ex#L43)):
```elixir
  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8">
      ...
      <div class="flex-none">
        <.org_switcher
          :if={@current_scope && @current_scope.active_organization}
          current_scope={@current_scope}
          user_organizations={@user_organizations}
          return_to="/"
        />
```

**HEEx + Heroicons primitive pattern** ([`test/example/lib/example_web/components/org_switcher.ex:28`](/Users/jon/projects/sigra/test/example/lib/example_web/components/org_switcher.ex#L28), [`test/example/lib/example_web/components/core_components.ex:94`](/Users/jon/projects/sigra/test/example/lib/example_web/components/core_components.ex#L94)):
```elixir
  def org_switcher(assigns) do
    ~H"""
    <details class="dropdown dropdown-end" id="org-switcher">
      ...
      <.icon name="hero-chevron-down" class="w-4 h-4" />
```

Create the admin shell as a dedicated generated component and import it from `layouts.ex`. Keep the host layout edit small; keep the shell implementation localized in one component module.

---

### Test files

**`test/sigra/install/features/admin_test.exs`**  
Analog: `test/sigra/install/features/organizations_test.exs`

Copy the test structure around template existence, `enabled?/1`, `files/1`, and migration registration from [`test/sigra/install/features/organizations_test.exs:13`](/Users/jon/projects/sigra/test/sigra/install/features/organizations_test.exs#L13) and [`test/sigra/install/features/organizations_test.exs:39`](/Users/jon/projects/sigra/test/sigra/install/features/organizations_test.exs#L39).

**`test/sigra/plug/require_admin_access_test.exs`**  
Analog: `test/sigra/plug/require_membership_test.exs`

Copy the self-contained inline test structs, fake error handler, and `init/1` + `call/2` coverage shape from [`test/sigra/plug/require_membership_test.exs:7`](/Users/jon/projects/sigra/test/sigra/plug/require_membership_test.exs#L7) and [`test/sigra/plug/require_membership_test.exs:85`](/Users/jon/projects/sigra/test/sigra/plug/require_membership_test.exs#L85).

**`test/sigra/live_view/admin_scope_test.exs`**  
Analog: `test/sigra/live_view/organization_scope_test.exs`

Copy the fake socket approach, inline schemas, and halt-flag assertions from [`test/sigra/live_view/organization_scope_test.exs:97`](/Users/jon/projects/sigra/test/sigra/live_view/organization_scope_test.exs#L97) and [`test/sigra/live_view/organization_scope_test.exs:103`](/Users/jon/projects/sigra/test/sigra/live_view/organization_scope_test.exs#L103).

**`test/example/test/example_web/integration/phase_27_integration_test.exs`**  
Analog: `test/example/test/example_web/integration/phase_16_integration_test.exs`

Copy the phase-level integration style from [`test/example/test/example_web/integration/phase_16_integration_test.exs:1`](/Users/jon/projects/sigra/test/example/test/example_web/integration/phase_16_integration_test.exs#L1): one requirement per test, direct file assertions for generated host seams, and end-to-end GET/POST route checks through the example app.

## Shared Patterns

### Additive Installer Features
**Sources:** [`lib/sigra/install/feature.ex:28`](/Users/jon/projects/sigra/lib/sigra/install/feature.ex#L28), [`lib/sigra/install/runner.ex:52`](/Users/jon/projects/sigra/lib/sigra/install/runner.ex#L52)
**Apply to:** `lib/sigra/install/features/admin.ex`, `lib/mix/tasks/sigra.install.ex`
```elixir
  @callback enabled?(opts :: keyword()) :: boolean()
  @callback files(binding :: keyword()) :: [{:eex, source :: String.t(), target :: String.t()}]
  @callback injections(binding :: keyword()) :: [Sigra.Install.Injection.t()]
  @callback migrations(binding :: keyword()) ::
              [{slot_key :: atom(), template :: String.t(), target_basename :: String.t()}]

  def run(features, binding, opts) when is_list(features) and is_list(binding) do
    active = Enum.filter(features, fn f -> f.enabled?(opts) end)
    ...
  end
```

### URL-Owned Scope Resolution
**Sources:** [`lib/sigra/plug/load_organization_from_slug.ex:47`](/Users/jon/projects/sigra/lib/sigra/plug/load_organization_from_slug.ex#L47), [`lib/sigra/live_view/organization_scope.ex:56`](/Users/jon/projects/sigra/lib/sigra/live_view/organization_scope.ex#L56)
**Apply to:** `lib/sigra/plug/require_admin_access.ex`, `lib/sigra/live_view/admin_scope.ex`, admin router injection
```elixir
    scope = conn.assigns[:current_scope]
    slug = conn.params[scope_param] || conn.params[to_string(scope_param)]
    ...
    case resolve(config, scope, slug) do
      {:ok, org, membership} -> ...
      :not_found -> halt_not_found(conn, error_handler, opts)
    end
```

### Plug + LiveView Parity
**Sources:** [`test/example/lib/example_web/router.ex:151`](/Users/jon/projects/sigra/test/example/lib/example_web/router.ex#L151), [`test/example/lib/example_web/user_auth.ex:254`](/Users/jon/projects/sigra/test/example/lib/example_web/user_auth.ex#L254)
**Apply to:** admin router scope, admin `on_mount`, admin shell wiring
```elixir
  pipeline :org_scoped do
    plug Sigra.Plug.LoadOrganizationFromSlug, ...
    plug Sigra.Plug.RequireMembership, ...
  end

  live_session :organization_scoped,
    on_mount: [
      {ExampleWeb.UserAuth, :ensure_authenticated},
      ...
      {Sigra.LiveView.OrganizationScope, [...]}
    ] do
```

### Structural Org Scoping
**Source:** [`lib/sigra/organizations/query.ex:27`](/Users/jon/projects/sigra/lib/sigra/organizations/query.ex#L27)
**Apply to:** admin query/export/mutation layers when org-admin scope is active
```elixir
  def for_org(queryable, %{active_organization: %{id: org_id}}) when is_binary(org_id) do
    for_org(queryable, org_id)
  end

  def for_org(queryable, org_id) when is_binary(org_id) do
    ...
    where(query, [r], r.organization_id == ^org_id)
  end
```

### Host-Owned Thin Wrappers
**Source:** [`test/example/lib/example/organizations.ex:27`](/Users/jon/projects/sigra/test/example/lib/example/organizations.ex#L27)
**Apply to:** generated admin policy module and any host-level admin chrome hook
```elixir
  use Sigra.Organizations,
    repo: Example.Repo,
    schemas: [...],
    ...

  def set_active_organization(conn, org) do
    Sigra.Plug.PutActiveOrganization.call(conn, org, ...)
  end
```

## No Analog Found

None. The repo already has close analogs for installer features, plug/live parity, URL scope resolution, generated host boundary modules, and shell chrome hooks.

## Metadata

**Analog search scope:** `lib/sigra/install/*`, `lib/sigra/plug/*`, `lib/sigra/live_view/*`, `priv/templates/sigra.install/*`, `test/example/lib/example_web/*`, `test/sigra/*`, `test/example/test/example_web/*`
**Files scanned:** 20+ key analog files plus phase artifacts
**Pattern extraction date:** 2026-04-16
