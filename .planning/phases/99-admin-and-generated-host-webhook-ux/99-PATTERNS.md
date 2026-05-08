# Phase 99: Admin and generated-host webhook UX - Pattern Map

**Mapped:** 2026-05-06
**Files analyzed:** 16 likely files/modules
**Analogs found:** 15 / 16

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/admin/live/webhook_subscriptions_index_live.ex` | liveview/component | request-response | `lib/sigra/admin/live/users_index_live.ex` | exact |
| `lib/sigra/admin/live/webhook_subscription_show_live.ex` | liveview/component | request-response | `lib/sigra/admin/live/user_show_live.ex` | exact |
| `lib/sigra/admin/live/webhook_delivery_failures_live.ex` | liveview/component | request-response | `lib/sigra/admin/live/audit_index_live.ex` | exact |
| `lib/sigra/admin/live/webhook_delivery_show_live.ex` | liveview/component | request-response | `lib/sigra/admin/live/audit_user_live.ex` | role-match |
| `lib/sigra/admin/webhooks/query.ex` | query/service | CRUD + request-response | `lib/sigra/admin/users/query.ex` | exact |
| `lib/sigra/admin/webhooks/detail.ex` | query/service | CRUD + request-response | `lib/sigra/admin/users/detail.ex` | exact |
| `lib/sigra/admin/webhooks/actions.ex` | service | CRUD + request-response | `lib/sigra/admin/users/actions.ex` | role-match |
| `lib/sigra/admin/webhooks/failures.ex` | query/service | CRUD + request-response | `lib/sigra/admin/audit/query.ex` | role-match |
| `lib/sigra/webhooks.ex` | service | CRUD + request-response | `lib/sigra/webhooks.ex` | exact |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex` | generated wrapper/context | request-response | `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex` webhook wrappers | exact |
| `test/example/lib/example_web/components/admin_shell.ex` | component | request-response | `test/example/lib/example_web/components/admin_shell.ex` | exact |
| `test/example/lib/example_web/router.ex` | route/config | request-response | `test/example/lib/example_web/router.ex` admin scopes | exact |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/components/admin_shell.ex` | generated component | request-response | `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/components/admin_shell.ex` | exact |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex` | generated route/config | request-response | `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex` admin scopes | exact |
| `priv/templates/sigra.install/admin/router_injection.ex` + `lib/sigra/install/features/admin.ex` | generator/config | request-response | existing admin installer files | exact |
| `guides/flows/webhooks.md` and generated receiver-setup docs/template seam | docs/template | request-response | `guides/flows/webhooks.md` + `guides/recipes/webhook-verification.md` | partial |

## Pattern Assignments

### `lib/sigra/admin/live/webhook_subscriptions_index_live.ex` (liveview, request-response)

**Analog:** [lib/sigra/admin/live/users_index_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/users_index_live.ex:1)

**Mount + `handle_params/3` pattern** ([lines 15-31](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/live\/users_index_live.ex:15), [35-60](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/live\/users_index_live.ex:35)):
```elixir
def mount(_params, _session, socket) do
  config = runtime_config!()
  hooks = Hooks.resolve(config)

  {:ok,
   socket
   |> assign(:sigra_config, config)
   |> assign(:filters_open?, false)
   |> assign(:page_title, "Users")
   |> assign(:rows, [])
   |> assign(:meta, nil)
   |> assign(:current_params, %{})}
end

def handle_params(params, _uri, socket) do
  admin_scope = socket.assigns.admin_scope
  config = socket.assigns.sigra_config

  with {:ok, {rows, meta, normalized}} <- Query.list_users(config, admin_scope, params) do
    {:noreply,
     socket
     |> assign(:rows, rows)
     |> assign(:meta, meta)
     |> assign(:current_params, normalized)
     |> assign(:filters_open?, filters_open?(normalized))}
  end
end
```

**List/form layout pattern** ([lines 71-109](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/live\/users_index_live.ex:71), [169-257](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/live\/users_index_live.ex:169)):
```elixir
<header class="space-y-3">
  <div class="space-y-1">
    <h1 class="text-2xl font-semibold">{page_heading(@admin_scope)}</h1>
    <p class="text-sm text-base-content/70">{scope_copy(@admin_scope)}</p>
  </div>
  <div class="flex flex-wrap gap-2">
    <.summary_chip label="Total" value={Map.get(@summary_counts, :total, 0)} />
  </div>
</header>

<form method="get" action={index_path(@admin_scope)} class="space-y-4 rounded-lg border border-base-300 bg-base-200 p-4">
  ...
</form>

<table class="table w-full">...</table>
<article :for={row <- @rows} class="rounded-lg border border-base-300 bg-base-200 p-4">...</article>
```

**Use in Phase 99**
- Keep the index URL-driven with GET filters and sortable/paginated rows.
- Use desktop table + mobile card dual rendering again.
- Model quick create/light edit as list-preserving UI state layered on top of this list contract, not a separate route-first CRUD page.

---

### `lib/sigra/admin/live/webhook_subscription_show_live.ex` (liveview, request-response)

**Analog:** [lib/sigra/admin/live/user_show_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/user_show_live.ex:1)

**Detail load + `return_to` pattern** ([lines 23-35](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/live\/user_show_live.ex:23)):
```elixir
def handle_params(%{"id" => user_id} = params, _uri, socket) do
  admin_scope = socket.assigns.admin_scope
  detail = Detail.load!(socket.assigns.sigra_config, admin_scope, user_id)
  return_to = sanitize_return_to(Map.get(params, "return_to"), admin_scope)

  {:noreply,
   socket
   |> assign(:detail, detail)
   |> assign(:return_to, return_to)
   |> assign(:confirm_action, nil)
   |> assign(:page_title, detail.display_name || detail.user.email)}
end
```

**Explicit confirmation action pattern** ([lines 37-84](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/live\/user_show_live.ex:37)):
```elixir
def handle_event("open_revoke_all_sessions", _params, socket) do
  {:noreply,
   assign(socket, :confirm_action, %{
     type: :revoke_all_sessions,
     copy: revoke_all_sessions_copy(socket.assigns.detail)
   })}
end

def handle_event("confirm_action", _params, socket) do
  case socket.assigns.confirm_action do
    %{type: :revoke_all_sessions} ->
      {_count, nil} = Actions.revoke_all_sessions(config, admin_scope, detail.user.id)
      {:noreply, socket |> reload_detail(detail.user.id) |> put_flash(:info, "All active sessions revoked.")}
  end
end
```

**Section-stacked detail page pattern** ([lines 89-254](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/live\/user_show_live.ex:89)):
```elixir
<section :if={@detail} class="space-y-6">
  <div class="flex flex-wrap items-center justify-between gap-3">
    <a class="btn btn-ghost min-h-11" href={@return_to}>Back to users</a>
    <span class="text-sm text-base-content/70">{scope_copy(@admin_scope)}</span>
  </div>

  <section class="rounded-lg border border-base-300 bg-base-100 p-5">...</section>
  <section class="rounded-lg border border-base-300 bg-base-100 p-5">...</section>
  <section class="rounded-lg border border-base-300 bg-base-100 p-5">...</section>
</section>
```

**Use in Phase 99**
- Put setup, signing secret reveal/copy, rotation confirmation, recent deliveries, and delivery-history links in stacked dedicated sections.
- Keep secret reveal/rotation as explicit LiveView events with confirmation copy, then reload detail after mutation.

---

### `lib/sigra/admin/live/webhook_delivery_failures_live.ex` (liveview, request-response)

**Analog:** [lib/sigra/admin/live/audit_index_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/audit_index_live.ex:1)

**Explorer-style filter surface** ([lines 22-43](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/live\/audit_index_live.ex:22), [55-89](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/live\/audit_index_live.ex:55)):
```elixir
def handle_params(params, _uri, socket) do
  case Explorer.list_events(socket.assigns.sigra_config, socket.assigns.admin_scope, params) do
    {:ok, {rows, meta, current_params}} ->
      {:noreply, socket |> assign(:rows, rows) |> assign(:meta, meta) |> assign(:current_params, current_params)}
    {:error, _reason} ->
      {:noreply, socket |> put_flash(:error, "We couldn't load this audit view. Refresh the page, then try again.")}
  end
end

<form method="get" action={index_path(@admin_scope)} class="space-y-4 rounded-lg border border-base-300 bg-base-200 p-4">
  <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-4">...</div>
  <div class="flex flex-wrap gap-2">
    <button type="submit" class="btn btn-primary min-h-11">Apply filters</button>
    <a href={index_path(@admin_scope)} class="btn btn-ghost min-h-11">Clear</a>
  </div>
</form>
```

**Paginator + empty-state pattern** ([lines 131-162](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/live\/audit_index_live.ex:131)):
```elixir
<div :if={@rows == []} class="rounded-lg border border-dashed border-base-300 bg-base-100 p-6 text-sm text-base-content/70">
  <p class="font-semibold">No audit events match this view</p>
  <p class="mt-1">Try a different filter or clear one or more params to widen the result set.</p>
</div>

<nav :if={@meta} class="flex items-center justify-between gap-3">...</nav>
```

**Use in Phase 99**
- Reuse this page shape for the global `Retrying` / `Dead lettered` inbox.
- Keep the failures view secondary to subscriptions, but still URL-driven and summary-row-backed.

---

### `lib/sigra/admin/live/webhook_delivery_show_live.ex` (liveview, request-response)

**Analog:** [lib/sigra/admin/live/audit_user_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/audit_user_live.ex:1)

**Scoped drill-down + preserved back link pattern** ([lines 26-55](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/live\/audit_user_live.ex:26)):
```elixir
def handle_params(%{"id" => user_id} = params, _uri, socket) do
  admin_scope = socket.assigns.admin_scope
  config = socket.assigns.sigra_config
  detail = Detail.load!(config, admin_scope, user_id)
  return_to = sanitize_return_to(Map.get(params, "return_to"), admin_scope, user_id)

  case Explorer.list_subject_events(config, admin_scope, user_id, params) do
    {:ok, {rows, meta, current_params}} ->
      {:noreply,
       socket
       |> assign(:detail, detail)
       |> assign(:rows, rows)
       |> assign(:meta, meta)
       |> assign(:return_to, return_to)}
  end
end
```

**Header + table detail pattern** ([lines 61-108](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/live\/audit_user_live.ex:61), [110-181](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/live\/audit_user_live.ex:110)):
```elixir
<section :if={@detail} class="space-y-6">
  <div class="flex flex-wrap items-center justify-between gap-3">
    <a class="btn btn-ghost min-h-11" href={@return_to}>Back to user</a>
    <span class="text-sm text-base-content/70">{scope_copy(@admin_scope)}</span>
  </div>

  <header class="space-y-1 rounded-lg border border-base-300 bg-base-100 p-5">...</header>
  <form method="get" action={index_path(@admin_scope, @detail.user.id)} ...>...</form>
  <table class="table w-full">...</table>
</section>
```

**Use in Phase 99**
- Keep one shared delivery-detail surface reachable from both subscription history and global failures.
- Preserve `return_to` so the page can render `Back to subscription` or `Back to failures` without separate LiveViews.

---

### `lib/sigra/admin/webhooks/query.ex` (query/service, CRUD + request-response)

**Analog:** [lib/sigra/admin/users/query.ex](/Users/jon/projects/sigra/lib/sigra/admin/users/query.ex:1)

**Param-normalization + Flop schema pattern** ([lines 12-27](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/users\/query.ex:12), [42-88](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/users\/query.ex:42), [102-149](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/users\/query.ex:102)):
```elixir
@allowed_params ~w(q organization page page_size order_by order_direction ...)

defmodule Params do
  use Ecto.Schema
  @primary_key false

  @derive {Flop.Schema,
    filterable: [...],
    sortable: [...],
    default_limit: 25,
    max_limit: 100,
    default_order: %{order_by: [:inserted_at], order_directions: [:desc]}}

  embedded_schema do
    field :q, :string
    field :inserted_at, :utc_datetime
  end
end

def normalize_params(params) do
  params
  |> stringify_map()
  |> Map.take(@allowed_params)
  |> Enum.reject(fn {_key, value} -> blank?(value) end)
  |> Map.new(...)
  |> then(fn normalized ->
    case Flop.validate(to_flop_params(normalized), for: Params) do
      {:ok, flop} -> {:ok, merge_flop_defaults(normalized, flop)}
      {:error, %Flop.Meta{} = meta} -> {:error, meta}
    end
  end)
end
```

**Base-query + filtered-query pattern** ([lines 126-149](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/users\/query.ex:126), [199-226](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/users\/query.ex:199)):
```elixir
def list_users(config, %Scope{} = admin_scope, params \\ %{}) do
  with {:ok, normalized} <- normalize_params(params),
       {:ok, %Flop{} = flop} <- Flop.validate(to_flop_params(normalized), for: Params) do
    helpers = helpers(config, hooks, admin_scope)
    base_query = base_query(config, admin_scope, helpers)
    filtered_query = apply_filters(base_query, flop.filters || [], helpers)
    pagination_flop = %Flop{flop | filters: []}

    meta = Flop.meta(filtered_query, pagination_flop, for: Params, repo: config.repo)

    rows =
      filtered_query
      |> Flop.query(pagination_flop, for: Params)
      |> select_row(helpers)
      |> config.repo.all()

    {:ok, {rows, meta, normalized}}
  end
end
```

**Use in Phase 99**
- Build subscription and failure lists with one canonical query contract each.
- Use `webhook_deliveries` summary columns for list rows; reserve `webhook_delivery_attempts` joins/preloads for detail loaders only.

---

### `lib/sigra/admin/webhooks/detail.ex` (query/service, CRUD + request-response)

**Analog:** [lib/sigra/admin/users/detail.ex](/Users/jon/projects/sigra/lib/sigra/admin/users/detail.ex:1)

**Single `load!/3` detail aggregator pattern** ([lines 14-59](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/users\/detail.ex:14)):
```elixir
def load!(config, %Scope{} = admin_scope, user_id) when is_binary(user_id) do
  hooks = Hooks.resolve(config)
  helpers = helpers(config)
  user = load_user!(config, admin_scope, user_id, helpers)

  organizations = list_organizations(config, admin_scope, user, helpers)
  sessions = Sigra.Auth.list_sessions(config, user.id)
  recent_audit = recent_audit_preview(config, admin_scope, user.id)

  %{
    user: user,
    display_name: display_name,
    sessions: sessions,
    organizations: organizations,
    recent_audit: recent_audit,
    danger_zone: %{revoke_all_sessions?: sessions != []}
  }
end
```

**Preview-subset pattern** ([lines 61-102](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/users\/detail.ex:61)):
```elixir
@audit_preview_limit 5

def recent_audit_preview(config, %Scope{} = admin_scope, user_id) when is_binary(user_id) do
  filters =
    [subject_user_id: user_id]
    |> maybe_put_audit_scope(admin_scope)

  events =
    audit_schema
    |> Sigra.Admin.Audit.Query.build(filters)
    |> order_by([event], desc: event.inserted_at, desc: event.id)
    |> limit(^@audit_preview_limit)
    |> config.repo.all()
end
```

**Use in Phase 99**
- Build one subscription detail map containing subscription summary, setup copy, revealable secret state, recent deliveries, and attempt preview counts.
- Build one delivery detail loader that combines the parent summary row with newest-first attempt timeline rows.

---

### `lib/sigra/admin/webhooks/actions.ex` (service, CRUD + request-response)

**Analog:** [lib/sigra/admin/users/actions.ex](/Users/jon/projects/sigra/lib/sigra/admin/users/actions.ex:1)

**Scope-aware mutation wrapper pattern** ([lines 9-33](\/Users\/jon\/projects\/sigra\/lib\/sigra\/admin\/users\/actions.ex:9)):
```elixir
def revoke_session(config, %Scope{} = admin_scope, user_id, hashed_token)
    when is_binary(user_id) and is_binary(hashed_token) do
  user = Detail.load_user!(config, admin_scope, user_id)

  Sigra.Auth.revoke_session(config, hashed_token,
    user_id: user.id,
    actor_id: admin_scope.scope.user.id,
    target_id: user.id,
    effective_user_id: user.id,
    audit_scope: audit_scope(admin_scope)
  )
end
```

**Use in Phase 99**
- Keep reveal/rotate/enable/disable mutations behind admin action modules that first authorize/load the record, then call `Sigra.Webhooks`.
- If secret reveal is modeled as a read action rather than a persistent mutation, still keep it in this seam so the LiveView never reaches into raw repo code.

---

### `lib/sigra/webhooks.ex` (service, CRUD + request-response)

**Analog:** [lib/sigra/webhooks.ex](/Users/jon/projects/sigra/lib/sigra/webhooks.ex:1)

**Existing CRUD wrapper seam to extend** ([lines 90-150](\/Users\/jon\/projects\/sigra\/lib\/sigra\/webhooks.ex:90)):
```elixir
def create_subscription(%Sigra.Config{} = config, attrs) do
  schema = subscription_schema!(config)
  changeset = subscription_changeset(config, struct(schema), attrs)

  Multi.new()
  |> Multi.insert(:subscription, changeset)
  |> config.repo.transaction()
  |> normalize_multi_result(:subscription)
end

def list_subscriptions(%Sigra.Config{} = config) do
  config.repo.all(subscription_schema!(config))
end

def enable_subscription(%Sigra.Config{} = config, subscription) do
  update_subscription(config, subscription, %{enabled: true})
end
```

**Use in Phase 99**
- Extend this module for library-owned detail/history/rotation/reveal helpers only when the operation belongs to the stable public webhook service.
- Keep generated hosts on thin wrapper calls into this module; do not move operational query logic into host templates or host contexts.

---

### `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex` (generated wrapper/context, request-response)

**Analog:** [test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex:587)

**Thin pass-through wrapper pattern** ([lines 587-615](\/Users\/jon\/projects\/sigra\/test\/fixtures\/install_golden\/tree\/lib\/sigra_install_golden_tmp\/accounts.ex:587)):
```elixir
@doc "List the explicit webhook event catalog."
def webhook_event_types do
  Sigra.Webhooks.public_event_types()
end

@doc "List configured webhook subscriptions."
def list_webhook_subscriptions do
  Sigra.Webhooks.list_subscriptions(sigra_config())
end

@doc "Create a webhook subscription."
def create_webhook_subscription(attrs) do
  Sigra.Webhooks.create_subscription(sigra_config(), attrs)
end
```

**Use in Phase 99**
- Add any new subscription-detail, failure-inbox, delivery-detail, reveal-secret, or rotate-secret wrapper functions in this same terse style.
- Keep docs short and action-shaped; no local query logic, no `Repo` calls.

---

### `test/example/lib/example_web/components/admin_shell.ex` and generated twin (component, request-response)

**Analogs:** [test/example/lib/example_web/components/admin_shell.ex](/Users/jon/projects/sigra/test/example/lib/example_web/components/admin_shell.ex:13), [test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/components/admin_shell.ex](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/components/admin_shell.ex:13)

**Desktop + mobile nav pattern** ([example lines 47-116](\/Users\/jon\/projects\/sigra\/test\/example\/lib\/example_web\/components\/admin_shell.ex:47)):
```elixir
<aside class="hidden w-64 shrink-0 lg:block">
  <nav aria-label="Admin navigation" class="space-y-4">
    <div class="rounded-lg bg-base-200 p-3">
      <p class="mb-2 text-xs font-semibold uppercase text-base-content/60">Operations</p>
      <ul class="menu gap-1 p-0">
        <li><a class={nav_item_class(users_active?(@admin_scope))} href={users_link(@admin_scope)}>Users</a></li>
        <li><a class={nav_item_class(false)} href={audit_link(@admin_scope)}>Audit</a></li>
      </ul>
    </div>
  </nav>
</aside>

<nav aria-label="Admin bottom nav" class="btm-nav border-t border-base-300 bg-base-200 lg:hidden">
  ...
</nav>
```

**Use in Phase 99**
- Add `Webhooks` and a secondary failures entry in the same `Operations` group.
- Update both example and install-golden shells in lockstep.

---

### `test/example/lib/example_web/router.ex` and generated twin (route/config, request-response)

**Analogs:** [test/example/lib/example_web/router.ex](/Users/jon/projects/sigra/test/example/lib/example_web/router.ex:267), [test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex:233), [priv/templates/sigra.install/admin/router_injection.ex](/Users/jon/projects/sigra/priv/templates/sigra.install/admin/router_injection.ex:16)

**Admin `live_session` mount pattern** ([example lines 267-325](\/Users\/jon\/projects\/sigra\/test\/example\/lib\/example_web\/router.ex:267)):
```elixir
scope "/", alias: false do
  pipe_through [:browser, :require_authenticated, :admin_global]

  live_session :admin_global,
    layout: {ExampleWeb.Layouts, :admin},
    on_mount: [
      {ExampleWeb.UserAuth, :ensure_authenticated},
      {Sigra.LiveView.AdminScope,
       [mode: :global, policy: Example.SigraAdminPolicy, login_path: "/users/log_in"]}
    ] do
    live "/admin/audit", Elixir.Sigra.Admin.Live.AuditIndexLive, :index
    live "/admin/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index
  end
end
```

**Installer template seam** ([template lines 16-40](\/Users\/jon\/projects\/sigra\/priv\/templates\/sigra.install\/admin\/router_injection.ex:16)):
```elixir
# Sigra admin
scope "/", alias: false do
  pipe_through [:browser, :require_authenticated, :admin_global]
  ...
  live "/admin", Elixir.Sigra.Admin.Live.IndexLive, :index
  live "/admin/audit", Elixir.Sigra.Admin.Live.AuditIndexLive, :index
  live "/admin/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index
end
```

**Use in Phase 99**
- Mount webhook routes inside the existing global admin lane by default.
- Keep organization admin routes untouched unless the planner deliberately adds scoped semantics later; current webhook rows are global.

---

### `priv/templates/sigra.install/admin/router_injection.ex` + `lib/sigra/install/features/admin.ex` (generator/config, request-response)

**Analogs:** [priv/templates/sigra.install/admin/router_injection.ex](/Users/jon/projects/sigra/priv/templates/sigra.install/admin/router_injection.ex:1), [lib/sigra/install/features/admin.ex](/Users/jon/projects/sigra/lib/sigra/install/features/admin.ex:22)

**Installer ownership pattern** ([`admin.ex` lines 22-52](\/Users\/jon\/projects\/sigra\/lib\/sigra\/install\/features\/admin.ex:22)):
```elixir
def files(binding) do
  [
    {:eex, "admin/policy.ex", ...},
    {:eex, "admin/components/admin_shell.ex", ...},
    {:eex, "admin/impersonation_controller.ex", ...},
    {:eex, "admin/audit_export_controller.ex", ...}
  ]
end

def injections(binding) do
  [
    router_injection(otp_app, binding),
    layouts_import_injection(otp_app, web_module),
    layouts_admin_injection(otp_app),
    error_handler_injection(otp_app, web_module, app_module)
  ]
end
```

**Use in Phase 99**
- Route and shell changes belong in the existing admin installer feature.
- If receiver-setup docs are emitted by the installer, keep them under this host-facing generator seam rather than hard-coding path assumptions into the library LiveViews.

---

### `guides/flows/webhooks.md` and `guides/recipes/webhook-verification.md` (docs/template, request-response)

**Analogs:** [guides/flows/webhooks.md](/Users/jon/projects/sigra/guides/flows/webhooks.md:9), [guides/recipes/webhook-verification.md](/Users/jon/projects/sigra/guides/recipes/webhook-verification.md:23)

**Boundary-copy source** (`guides/flows/webhooks.md` lines 11-15, 124-152):
```markdown
| Library | Sigra | `Sigra.Webhooks`, `Sigra.Webhooks.Signature`, the curated public event catalog, atomic event/delivery persistence, and the async delivery worker. |
| Generated host | You | `webhook_subscriptions`, `webhook_events`, `webhook_deliveries`, and `webhook_delivery_attempts` tables plus thin wrapper functions on your generated accounts context. |

1. Your auth or identity mutation succeeds locally.
2. Sigra writes one `webhook_events` row.
3. Sigra writes one `webhook_deliveries` row per matching enabled subscription.
...
- `webhook_deliveries` is the cheap current-state summary row.
- `webhook_delivery_attempts` is the append-only, authoritative attempt timeline.
```

**Receiver recipe source** (`webhook-verification.md` lines 23-35, 65-93, 104-140):
```elixir
pipeline :webhooks do
  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason,
    body_reader: {MyAppWeb.WebhookBodyReader, :read_body, []}
end

with {:ok, %{delivery_id: delivery_id, timestamp: timestamp}} <-
       Signature.verify(conn.req_headers, raw_body, secret, tolerance: 300) do
  payload = Jason.decode!(raw_body)
  :ok = MyApp.Webhooks.process(delivery_id, payload, timestamp)
end
```

**Use in Phase 99**
- Reuse this exact host-boundary split in setup cards and generated docs.
- Inline copy should stay short; the full `body_reader`, raw-body verification, dedupe, and rotation notes belong in guides/templates.

## Shared Patterns

### Runtime config loading for admin LiveViews
**Source:** [lib/sigra/admin/live/audit_index_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/audit_index_live.ex:167)
**Apply to:** All new Sigra admin webhook LiveViews
```elixir
defp runtime_config! do
  otp_app = Application.get_env(:sigra, :otp_app) || raise ArgumentError, ...
  host_config = Application.get_env(otp_app, :sigra_config) || raise ArgumentError, ...

  host_config
  |> Keyword.put_new(:otp_app, otp_app)
  |> Sigra.Config.new!()
end
```

### URL-driven filters, sorting, and pagination
**Source:** [lib/sigra/admin/live/audit_index_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/audit_index_live.ex:198), [lib/sigra/admin/users/query.ex](/Users/jon/projects/sigra/lib/sigra/admin/users/query.ex:102)
**Apply to:** Subscription index and failures inbox
```elixir
defp sort_path(admin_scope, params, field) do
  next_direction =
    if Map.get(params, "order_by") == field and Map.get(params, "order_direction") == "desc",
      do: "asc",
      else: "desc"

  admin_scope
  |> index_path()
  |> append_query(params |> Map.put("order_by", field) |> Map.put("order_direction", next_direction) |> Map.delete("cursor"))
end
```

### Detail-page explicit confirmations
**Source:** [lib/sigra/admin/live/user_show_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/user_show_live.ex:37)
**Apply to:** Reveal-secret and rotate-secret flows
```elixir
{:noreply,
 assign(socket, :confirm_action, %{
   type: :revoke_all_sessions,
   copy: revoke_all_sessions_copy(socket.assigns.detail)
 })}
```

### Generated-host shell and route parity
**Source:** [test/example/lib/example_web/components/admin_shell.ex](/Users/jon/projects/sigra/test/example/lib/example_web/components/admin_shell.ex:47), [priv/templates/sigra.install/admin/router_injection.ex](/Users/jon/projects/sigra/priv/templates/sigra.install/admin/router_injection.ex:16)
**Apply to:** Example app, install-golden fixture, and installer template changes together
```elixir
<nav aria-label="Admin navigation" class="space-y-4">...</nav>
<nav aria-label="Admin bottom nav" class="btm-nav ...">...</nav>
```

### Thin generated wrapper functions
**Source:** [test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex:587)
**Apply to:** Any new generated host webhook helper
```elixir
def list_webhook_subscriptions do
  Sigra.Webhooks.list_subscriptions(sigra_config())
end
```

### Example ExUnit + Playwright verification split
**Source:** [test/example/test/example_web/live/admin_user_index_live_test.exs](/Users/jon/projects/sigra/test/example/test/example_web/live/admin_user_index_live_test.exs:9), [test/example/priv/playwright/tests/admin-generated.spec.ts](/Users/jon/projects/sigra/test/example/priv/playwright/tests/admin-generated.spec.ts:69), [test/example/priv/playwright/tests/admin-user-operations.spec.ts](/Users/jon/projects/sigra/test/example/priv/playwright/tests/admin-user-operations.spec.ts:69)
**Apply to:** New webhook list/detail contracts and generated-host parity smoke
```elixir
assert html =~ "Open user"
assert html =~ "/admin/users/#{target.id}?return_to=#{encoded}"
```

```ts
await page.goto("/admin/users");
await waitForLiveViewReady(page);
await expect(page.getByRole("heading", { name: "Users", exact: true })).toBeVisible();
```

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| generated receiver-setup docs template file under `priv/templates/sigra.install/...` | docs/template | request-response | The repo has webhook guides and admin installer templates, but no existing installer-emitted webhook receiver guide/template seam yet. Planner should combine the admin installer pattern with the current webhook guides. |

## Metadata

**Analog search scope:** `lib/sigra/admin/live/`, `lib/sigra/admin/users/`, `lib/sigra/admin/audit/`, `lib/sigra/install/features/`, `priv/templates/sigra.install/admin/`, `lib/sigra/webhooks.ex`, `test/example/lib/example_web/`, `test/fixtures/install_golden/tree/lib/`, `test/example/test/example_web/`, `test/example/priv/playwright/tests/`, `guides/flows/`, `guides/recipes/`

**Files scanned:** 22

**Pattern extraction date:** 2026-05-06
