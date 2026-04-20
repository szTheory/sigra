# Phase 30: Audit Exploration and Export - Pattern Map

**Mapped:** 2026-04-16
**Files analyzed:** 18
**Analogs found:** 9 / 9 inferred targets

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/admin/live/audit_index_live.ex` | component | request-response | `lib/sigra/admin/live/users_index_live.ex` | exact |
| `lib/sigra/admin/live/audit_user_live.ex` | component | request-response | `lib/sigra/admin/live/user_show_live.ex` | role-match |
| `lib/sigra/admin/audit/query.ex` | service | CRUD | `lib/sigra/admin/users/query.ex` + `lib/sigra/audit/query.ex` | exact |
| `lib/sigra/admin/audit/export.ex` | service | streaming / file-I/O | `lib/sigra/audit.ex` + `lib/sigra/data_export.ex` | role-match |
| `test/example/lib/example_web/router.ex` | route | request-response | `test/example/lib/example_web/router.ex` | exact |
| `priv/templates/sigra.install/admin/router_injection.ex` | route | request-response | `priv/templates/sigra.install/admin/router_injection.ex` | exact |
| `test/example/lib/example_web/components/admin_shell.ex` | component | request-response | `test/example/lib/example_web/components/admin_shell.ex` | exact |
| `test/example/test/example_web/live/admin_audit_*_test.exs` | test | request-response | `test/example/test/example_web/live/admin_user_index_live_test.exs` + `test/example/test/example_web/live/admin_user_show_live_test.exs` | exact |
| `test/example/priv/playwright/tests/admin-audit.spec.ts` | test | request-response | `test/example/priv/playwright/tests/impersonation.spec.ts` | role-match |

## Pattern Assignments

### `lib/sigra/admin/live/audit_index_live.ex`

**Primary analog:** `lib/sigra/admin/live/users_index_live.ex`

**Mount + `handle_params` ownership** (`lib/sigra/admin/live/users_index_live.ex:16-31`, `35-60`)
```elixir
def mount(_params, _session, socket) do
  config = runtime_config!()
  hooks = Hooks.resolve(config)

  {:ok,
   socket
   |> assign(:sigra_config, config)
   |> assign(:hooks_module, hooks)
   |> assign(:quick_filter_keys, @quick_filter_keys)
   |> assign(:more_filter_keys, @more_filter_keys)
   |> assign(:filters_open?, false)
   |> assign(:page_title, "Users")
   |> assign(:rows, [])
   |> assign(:summary_counts, %{})
   |> assign(:meta, nil)
   |> assign(:current_params, %{})}
end

def handle_params(params, _uri, socket) do
  admin_scope = socket.assigns.admin_scope
  config = socket.assigns.sigra_config
```

**What this buys the planner:** keep the audit index server-driven and URL-addressable. Query normalization, pagination, filter expansion, and error copy all stay in `handle_params/3`, which is the same contract Phase 28 already established for admin list pages.

**GET-form + normalized-param roundtrip** (`lib/sigra/admin/live/users_index_live.ex:88-167`)
```elixir
<form method="get" action={index_path(@admin_scope)} ...>
  ...
  <input type="hidden" name="page_size" value={param_value(@current_params, "page_size", "25")} />
  <input type="hidden" name="order_by" value={param_value(@current_params, "order_by", "inserted_at")} />
  <input type="hidden" name="order_direction" value={param_value(@current_params, "order_direction", "desc")} />
</form>
```

**What this buys the planner:** audit filters should remain shareable/bookmarkable and survive list navigation without custom JS state.

**Sort/page path helpers** (`lib/sigra/admin/live/users_index_live.ex:361-418`)
```elixir
defp sort_path(admin_scope, params, field) do
  next_direction =
    if Map.get(params, "order_by") == field and Map.get(params, "order_direction") == "asc",
      do: "desc",
      else: "asc"

  admin_scope
  |> index_path()
  |> append_query(
    params
    |> Map.put("order_by", field)
    |> Map.put("order_direction", next_direction)
    |> Map.put("page", "1")
  )
end

defp append_query(path, params) do
  cleaned =
    params
    |> Enum.reject(fn {_key, value} -> value in [nil, "", false] end)
    |> Enum.into(%{})
```

**What this buys the planner:** Phase 30 should not invent a second query-string builder. Reuse this exact “clean params, reset page on sort, keep everything else” shape for audit filters and export links.

---

### `lib/sigra/admin/live/audit_user_live.ex`

**Primary analog:** `lib/sigra/admin/live/user_show_live.ex`

**Return-to preservation + page reload contract** (`lib/sigra/admin/live/user_show_live.ex:23-35`, `264-287`)
```elixir
def handle_params(%{"id" => user_id} = params, _uri, socket) do
  admin_scope = socket.assigns.admin_scope
  detail = Detail.load!(socket.assigns.sigra_config, admin_scope, user_id)
  return_to = sanitize_return_to(Map.get(params, "return_to"), admin_scope)

  {:noreply,
   socket
   |> assign(:detail, detail)
   |> assign(:return_to, return_to)}
end

defp sanitize_return_to(path, admin_scope) when is_binary(path) do
  if String.starts_with?(path, ["/admin/users", "/admin/organizations/"]) do
    path
  else
    default_return_to(admin_scope)
  end
end
```

**What this buys the planner:** the audit detail page should accept only local admin paths, preserve list context, and fall back deterministically to the scoped audit index instead of reconstructing history from referers.

**Scoped pivot link pattern** (`lib/sigra/admin/live/user_show_live.ex:172-190`, `280-293`)
```elixir
<a
  :if={show_pivot_link?(@admin_scope, organization)}
  ...
  href={pivot_path(@admin_scope, @detail.user.id, organization, @return_to)}
>
```

**What this buys the planner:** if Phase 30 includes “open actor/target in scoped audit view” or “jump between global/org audit slices”, use explicit links that carry `return_to`, not hidden session state.

---

### `lib/sigra/admin/audit/query.ex`

**Primary analogs:** `lib/sigra/admin/users/query.ex`, `lib/sigra/audit/query.ex`, `lib/sigra/admin/users/detail.ex`

**Whitelist-first param normalization** (`lib/sigra/admin/users/query.ex:12-27`, `102-124`)
```elixir
@allowed_params ~w(...)

def normalize_params(params) do
  params
  |> stringify_map()
  |> Map.take(@allowed_params)
  |> Enum.reject(fn {_key, value} -> blank?(value) end)
  |> Map.new(fn
    {"q", value} -> {"q", String.trim(to_string(value))}
    ...
  end)
  |> then(fn normalized ->
    case Flop.validate(to_flop_params(normalized), for: Params) do
      {:ok, flop} -> {:ok, merge_flop_defaults(normalized, flop)}
      {:error, %Flop.Meta{} = meta} -> {:error, meta}
    end
  end)
end
```

**What this buys the planner:** the admin-facing audit query should own browser params and validation in one place. That keeps LiveView thin and avoids hand-parsing booleans, timestamps, and paging knobs in templates.

**Composable audit filter builder** (`lib/sigra/audit/query.ex:20-53`, `55-99`)
```elixir
@allowed_filters [
  :actor_id,
  :action,
  :action_prefix,
  :outcome,
  :from,
  :to,
  :target_id,
  :target_type,
  :organization_id,
  :effective_user_id,
  :organization_scope
]

def build(audit_schema, filters \\ []) do
  Enum.each(filters, fn {k, _} ->
    unless k in @allowed_filters do
      raise ArgumentError, ...
    end
  end)

  Enum.reduce(filters, from(e in audit_schema), &apply_filter/2)
end
```

**What this buys the planner:** Phase 30 should layer admin-specific normalization on top of the existing audit filter vocabulary, not fork the underlying semantics for action, actor, outcome, target, or org filters.

**Cursor pagination contract** (`lib/sigra/audit/query.ex:102-123`, `lib/sigra/audit/cursor.ex:10-29`, `lib/sigra/audit.ex:286-318`)
```elixir
def paginate(query, nil, limit) do
  query
  |> order_by([e], desc: e.inserted_at, desc: e.id)
  |> limit(^(limit + 1))
end

def paginate(query, {%DateTime{} = cursor_ts, cursor_id}, limit) do
  query
  |> where(
    [e],
    e.inserted_at < ^cursor_ts or
      (e.inserted_at == ^cursor_ts and e.id < ^cursor_id)
  )
  |> order_by([e], desc: e.inserted_at, desc: e.id)
  |> limit(^(limit + 1))
end
```

```elixir
def encode(%DateTime{} = dt, id) when is_binary(id) do
  ts = DateTime.to_unix(dt, :microsecond)
  Base.url_encode64("#{ts}|#{id}", padding: false)
end
```

```elixir
rows =
  filters
  |> query()
  |> Query.paginate(cursor_decoded, limit)
  |> repo.all()
```

**What this buys the planner:** keep audit exploration on the library’s existing keyset cursor. Do not introduce page-number pagination for audit rows; the cursor shape, ordering, and `limit + 1` fetch are already stable and DB-portable.

**Scope-safe audit narrowing** (`lib/sigra/audit/query.ex:87-95`, `lib/sigra/admin/users/detail.ex:58-75`, `173-178`)
```elixir
defp apply_filter({:organization_scope, {:only, org_id}}, q),
  do: where(q, [e], e.organization_id == ^org_id)

defp apply_filter({:organization_scope, {:including_global, org_id}}, q),
  do: where(q, [e], e.organization_id == ^org_id or is_nil(e.organization_id))
```

```elixir
filters =
  [target_id: user_id]
  |> maybe_put_audit_scope(admin_scope)
```

**What this buys the planner:** organization-admin per-user audit pages should reuse `{:including_global, org_id}` when they need both org-local and globally-originated support actions for that same user. Keep the org-wide explorer on `{:only, org_id}`.

---

### `lib/sigra/admin/audit/export.ex`

**Primary analogs:** `lib/sigra/audit.ex`, `lib/sigra/data_export.ex`

**Streaming gate for large exports** (`lib/sigra/audit.ex:321-341`)
```elixir
def stream(filters, opts) when is_list(filters) and is_list(opts) do
  repo = Keyword.fetch!(opts, :repo)
  q = query(filters)

  if function_exported?(repo, :stream, 1) do
    repo.stream(q)
  else
    raise ArgumentError,
          "Sigra.Audit.stream/2 requires #{inspect(repo)} to implement stream/1. " <>
            "Use Sigra.Audit.list/2 for cursor pagination on repos without streaming support."
  end
end
```

**What this buys the planner:** full audit export should be designed as a transaction-bound streaming path when possible. This avoids loading the whole audit table into memory and gives the plan a clean “stream if supported, otherwise fail or fall back explicitly” decision.

**Small-map extraction seam** (`lib/sigra/data_export.ex:45-72`)
```elixir
def export_auth_data(repo, user, opts \\ []) do
  import Ecto.Query

  session_schema = Keyword.get(opts, :session_schema)
  identity_schema = Keyword.get(opts, :identity_schema)

  data = %{
    user: %{id: user.id, email: user.email, confirmed_at: Map.get(user, :confirmed_at), inserted_at: user.inserted_at},
    sessions: if(session_schema, do: repo.all(from(s in session_schema, where: s.user_id == ^user.id)), else: []),
    identities: if(identity_schema, do: repo.all(from(i in identity_schema, where: i.user_id == ^user.id)), else: [])
  }

  {:ok, data}
end
```

**What this buys the planner:** there is no existing audit CSV/NDJSON writer. The nearest local precedent is a narrow service seam that returns a stable map and lets the caller choose formatting. Plan Phase 30 export around a similarly small extraction boundary plus a separate HTTP/file wrapper.

**Gap to note:** no existing module formats streamed audit rows into CSV or JSON download responses. The planner should treat formatting and delivery as new work, while reusing query/stream selection from `Sigra.Audit`.

---

### Route and shell integration

**Primary analogs:** `test/example/lib/example_web/router.ex`, `priv/templates/sigra.install/admin/router_injection.ex`, `test/example/lib/example_web/components/admin_shell.ex`

**Global + org admin route duplication pattern** (`test/example/lib/example_web/router.ex:216-265`, `priv/templates/sigra.install/admin/router_injection.ex:16-66`)
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
    live "/admin/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index
    live "/admin/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show
  end
end

scope "/admin/organizations/:org", alias: false do
  pipe_through [:browser, :require_authenticated, :admin_organization]
  ...
end
```

**What this buys the planner:** audit routes should land in both admin scopes with the same LiveView/layout/on_mount structure as users. Avoid mixing global and org routes into one dynamic LiveView route tree.

**Admin shell nav seam** (`test/example/lib/example_web/components/admin_shell.ex:47-80`, `89-112`)
```elixir
<ul class="menu gap-1 p-0">
  <li>
    <a class={nav_item_class(users_active?(@admin_scope))} href={users_link(@admin_scope)}>
      Users
    </a>
  </li>
  <li><span class="text-base-content/60">Audit</span></li>
</ul>
```

**What this buys the planner:** the shell already reserves the Audit nav slot. Phase 30 should upgrade this placeholder into real scoped links instead of reworking shell layout or chrome hierarchy.

**Impersonation-aware persistent chrome** (`test/example/lib/example_web/components/admin_shell.ex:119-139`)
```elixir
def impersonation_banner(assigns) do
  ~H"""
  <section class="border-t border-base-300 bg-warning/15 text-warning-content">
    ...
    <form method="post" action={~p"/impersonation"}>
      <input type="hidden" name="_method" value="delete" />
```

**What this buys the planner:** admin audit surfaces inherit the existing impersonation banner automatically through the admin layout. No phase-30-specific banner logic is needed; tests should assert compatibility, not add new chrome.

---

### Browser and test patterns

**Primary analogs:** `test/example/test/example_web/live/admin_user_index_live_test.exs`, `test/example/test/example_web/live/admin_user_show_live_test.exs`, `test/example/test/example_web/controllers/impersonation_controller_test.exs`, `test/example/priv/playwright/tests/impersonation.spec.ts`

**Server-rendered admin list assertions** (`test/example/test/example_web/live/admin_user_index_live_test.exs:9-45`)
```elixir
conn =
  conn
  |> log_in_user(platform_admin)
  |> get("/admin/users?q=alice-index&page=1&page_size=1&order_by=inserted_at&order_direction=asc")

html = html_response(conn, 200)
assert html =~ "/admin/users/#{target.id}?return_to=#{encoded}"
```

**What this buys the planner:** use plain GET assertions for URL-preservation and generated links. Not every admin list contract needs LiveView event testing.

**Detail-page structure assertions** (`test/example/test/example_web/live/admin_user_show_live_test.exs:10-46`, `113-158`)
```elixir
{:ok, _view, html} =
  conn
  |> log_in_user(platform_admin)
  |> live("/admin/users/#{target.id}?return_to=#{URI.encode_www_form("/admin/users?q=detail-order")}")
```

**What this buys the planner:** audit detail and export affordances should be tested through mounted LiveViews when ordering, conditional sections, or impersonation-aware visibility matter.

**Impersonation request-flow tests** (`test/example/test/example_web/controllers/impersonation_controller_test.exs:27-55`, `108-137`)
```elixir
assert get_session(conn, :impersonation_return_to) == "/admin/users?q=target"
...
assert redirected_to(conn) == "/admin/users?q=restore"
assert get_session(conn, :user_token) == admin_token
```

**What this buys the planner:** Phase 30 browser and controller tests should keep proving that impersonation does not break admin return paths. Export/download endpoints especially need this if they redirect back into audit pages.

**Browser-spec helper shape** (`test/example/priv/playwright/tests/impersonation.spec.ts:3-48`, `72-127`)
```ts
async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
}

async function openUserDetail(page: Page, targetEmail: string) {
  await page.goto(`/admin/users?q=${encodeURIComponent(targetEmail)}`);
  await waitForLiveViewReady(page);
  await page.getByRole('link', { name: 'Open user' }).first().click();
}
```

**What this buys the planner:** keep Playwright flows helper-driven and end-to-end across sudo, admin LiveView pages, and impersonation chrome. Phase 30 should extend this style for audit filters/export actions rather than introducing brittle selector-heavy scripts.

## Shared Patterns

### Admin LiveView organization
**Source:** `lib/sigra/admin/live/users_index_live.ex:16-60`, `lib/sigra/admin/live/user_show_live.ex:23-35`

Use `mount/3` for static assigns and config lookup, then reload from URL in `handle_params/3`. This is the existing admin contract for list/detail pages and keeps browser history authoritative.

### Return-to hygiene
**Source:** `lib/sigra/admin/live/users_index_live.ex:385-400`, `lib/sigra/admin/live/user_show_live.ex:264-287`, `test/example/lib/example_web/controllers/admin/impersonation_controller.ex:105-118`

Encode `return_to` from the current scoped index path, carry it explicitly in links/forms, and sanitize it to local admin paths on receipt. This prevents redirect drift and avoids referer dependence.

### Scope-safe audit filtering
**Source:** `lib/sigra/audit/query.ex:74-95`, `lib/sigra/admin/users/detail.ex:58-75`, `173-178`

Apply org-scope filters inside the query layer, not in LiveView templates or post-query filtering. The `organization_scope` filter already models the “org rows plus global support actions” distinction.

### Export boundary
**Source:** `lib/sigra/audit.ex:321-341`, `lib/sigra/data_export.ex:45-72`

Split export into two concerns: query/stream selection in the service layer, then formatting/delivery at the edge. The repo has no existing combined download abstraction.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/sigra/admin/audit/export_controller.ex` | controller | file-I/O | No existing download controller for admin data exports |
| `test/example/priv/playwright/tests/admin-audit-export.spec.ts` | test | file-I/O | No current browser download spec pattern in the example app |
| `lib/sigra/admin/live/audit_user_live.ex` event timeline UI | component | request-response | No existing admin event-detail renderer beyond user detail sections |

## Metadata

**Analog search scope:** `lib/sigra/admin/**`, `lib/sigra/audit*`, `lib/sigra/data_export.ex`, `lib/sigra/impersonation.ex`, `test/example/lib/example_web/**`, `test/example/test/example_web/**`, `test/example/priv/playwright/tests/**`, `.planning/phases/28-*`, `.planning/phases/29-*`

**Key patterns identified**
- Admin list/detail pages are URL-driven LiveViews with one query module owning normalization.
- Audit cursor pagination is already canonical and should remain keyset-based.
- Org-scoped per-user audit views should reuse `organization_scope: {:including_global, org_id}`; org-wide audit index views should stay on `{:only, org_id}`.
- Export currently has query/stream primitives but no delivery abstraction; Phase 30 should add only the missing wrapper.
