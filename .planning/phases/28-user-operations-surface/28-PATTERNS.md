# Phase 28: User Operations Surface - Pattern Map

**Mapped:** 2026-04-16
**Files analyzed:** 17
**Analogs found:** 17 / 17

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `mix.exs` | config | request-response | `mix.exs` | exact |
| `lib/sigra/admin/users/query.ex` | service | CRUD | `lib/sigra/audit/query.ex` | exact |
| `lib/sigra/admin/users/detail.ex` | service | request-response | `test/example/lib/example/accounts.ex` | role-match |
| `lib/sigra/admin/users/actions.ex` | service | event-driven | `lib/sigra/organizations.ex` | role-match |
| `lib/sigra/admin/users/hooks.ex` | hook | transform | `lib/sigra/hooks.ex` | role-match |
| `lib/sigra/admin/live/users_index_live.ex` | component | request-response | `test/example/lib/example_web/live/organization_members_live.ex` | exact |
| `lib/sigra/admin/live/user_show_live.ex` | component | request-response | `test/example/lib/example_web/live/auth/session_live.ex` | role-match |
| `lib/sigra/admin/live/index_live.ex` | component | request-response | `lib/sigra/admin/live/index_live.ex` | exact |
| `lib/sigra/admin/live/organization_live.ex` | component | request-response | `lib/sigra/admin/live/organization_live.ex` | exact |
| `test/example/lib/example_web/router.ex` | route | request-response | `test/example/lib/example_web/router.ex` | exact |
| `test/example/lib/example_web/components/admin_shell.ex` | component | request-response | `test/example/lib/example_web/components/admin_shell.ex` | exact |
| `test/sigra/admin/users_query_test.exs` | test | CRUD | `test/example/test/example_web/live/organization_members_live_test.exs` | partial |
| `test/sigra/admin/users_actions_test.exs` | test | event-driven | `test/example/test/example_web/live/passkey_settings_live_test.exs` | partial |
| `test/example/test/example_web/live/admin_user_index_live_test.exs` | test | request-response | `test/example/test/example_web/live/organization_members_live_test.exs` | exact |
| `test/example/test/example_web/live/admin_user_filters_live_test.exs` | test | request-response | `test/example/test/example_web/live/organization_members_live_test.exs` | role-match |
| `test/example/test/example_web/live/admin_user_show_live_test.exs` | test | request-response | `test/example/test/example_web/live/passkey_settings_live_test.exs` | role-match |
| `test/example/priv/playwright/tests/admin-user-operations.spec.ts` | test | request-response | `test/example/priv/playwright/tests/organizations.spec.ts` | exact |

## Pattern Assignments

### `mix.exs` (config, request-response)

**Analog:** `mix.exs`

**Dependency layout pattern** (`mix.exs:78-109`):
```elixir
defp deps do
  [
    {:phoenix, "~> 1.8"},
    {:phoenix_live_view, "~> 1.1"},
    {:ecto, "~> 3.12"},
    {:ecto_sql, "~> 3.12"},
    {:nimble_options, "~> 1.1"},
    ...
    {:postgrex, "~> 0.17", only: :test}
  ]
end
```

**Use for Phase 28:** add `{:flop, ...}` and `{:flop_phoenix, ...}` in the main deps list near other runtime web/query deps, not under dev/test-only entries.

---

### `lib/sigra/admin/users/query.ex` (service, CRUD)

**Analog:** `lib/sigra/audit/query.ex`

**Imports + whitelist pattern** (`lib/sigra/audit/query.ex:18-40`):
```elixir
import Ecto.Query

@allowed_filters [
  :actor_id,
  :action,
  :action_prefix,
  ...
]

def allowed_filters, do: @allowed_filters
```

**Validation-first filter application** (`lib/sigra/audit/query.ex:42-53`):
```elixir
def build(audit_schema, filters \\ []) do
  Enum.each(filters, fn {k, _} ->
    unless k in @allowed_filters do
      raise ArgumentError,
            "Sigra.Audit.Query: unknown filter key #{inspect(k)}. " <>
              "Allowed keys: #{inspect(@allowed_filters)}"
    end
  end)

  Enum.reduce(filters, from(e in audit_schema), &apply_filter/2)
end
```

**Pagination/order pattern** (`lib/sigra/audit/query.ex:102-123`):
```elixir
def paginate(query, nil, limit) do
  query
  |> order_by([e], desc: e.inserted_at, desc: e.id)
  |> limit(^(limit + 1))
end
```

**Scope-safe query composition to also copy** (`lib/sigra/admin/authorizer.ex:49-65`, `lib/sigra/organizations/query.ex:37-48`):
```elixir
def scope_query(queryable, %Scope{} = admin_scope) do
  query = Ecto.Queryable.to_query(queryable)

  cond do
    Scope.global?(admin_scope) -> query
    Scope.organization?(admin_scope) and is_binary(admin_scope.organization_id) ->
      Sigra.Organizations.Query.for_org(query, admin_scope.organization_id)
    true ->
      raise UnauthorizedError, reason: :not_found, message: "organization-scoped admin queries require a resolved organization"
  end
end
```

```elixir
def for_org(queryable, org_id) when is_binary(org_id) do
  query = Ecto.Queryable.to_query(queryable)
  ...
  where(query, [r], r.organization_id == ^org_id)
end
```

**Use for Phase 28:** keep one library-owned query module that validates params up front, scopes the base query before filters run, and returns rows shaped for both table and mobile-card renderers.

---

### `lib/sigra/admin/users/detail.ex` (service, request-response)

**Analog:** `test/example/lib/example/accounts.ex`

**Thin aggregation wrapper pattern** (`test/example/lib/example/accounts.ex:580-593`, `672-689`):
```elixir
def list_sessions(user) do
  Sigra.Auth.list_sessions(sigra_config(), user.id)
end

def revoke_all_sessions(user, opts \\ []) do
  Sigra.Auth.delete_all_sessions(sigra_config(), user.id, Keyword.put(opts, :pubsub, ExampleWeb.PubSub))
end

def mfa_status(user) do
  Sigra.MFA.status(sigra_config(), user,
    mfa_credential_schema: Example.Accounts.UserMFACredential,
    backup_code_schema: Example.Accounts.UserBackupCode
  )
end

def passkeys_for_user(user) do
  Sigra.Passkeys.list_for_user(sigra_config(), user, user_passkey_schema: UserPasskey)
end
```

**Scoped query assembly pattern** (`lib/sigra/organizations.ex:633-684`):
```elixir
query =
  from(m in membership_schema,
    where: m.organization_id == ^org.id,
    join: u in ^user_schema,
    on: u.id == m.user_id,
    ...
    preload: [user: u],
    select: {m, la.last_active_at}
  )

config.repo.all(query)
```

**Use for Phase 28:** build the detail module as a server-side assembler that pulls sessions, MFA/passkey state, memberships, and recent audit preview from existing Sigra APIs instead of computing that state in LiveView templates.

---

### `lib/sigra/admin/users/actions.ex` (service, event-driven)

**Analog:** `lib/sigra/organizations.ex`

**Multi-based mutation pattern** (`lib/sigra/organizations.ex:844-864`, `872-898`):
```elixir
result =
  Multi.new()
  |> guard_last_owner(membership.organization_id, membership.id, config)
  |> purge_org_sessions(membership, config)
  |> Multi.delete(:membership, membership)
  |> append_audit(config, "organization.member_remove", scope,
    metadata: %{user_id: membership.user_id}
  )
  |> config.repo.transaction()
  |> normalize_multi_result()
```

```elixir
multi =
  Multi.new()
  |> maybe_guard_last_owner_on_demote(membership, new_role, config)
  |> Multi.update(:membership, role_changeset)
  |> append_audit(config, "organization.member_role_change", scope,
    metadata: %{old_role: to_string(membership.role), new_role: to_string(new_role)}
  )
```

**Canonical session revoke side effects** (`lib/sigra/auth.ex:1222-1265`, `1289-1292`):
```elixir
def delete_all_sessions(config, user_id, opts \\ []) do
  sessions = session_store.list_by_user(user_id, store_opts)
  ...
  {count, _} = session_store.delete_all_for_user(user_id, delete_opts)
  ...
  Phoenix.PubSub.broadcast(pubsub, live_socket_id, :disconnect)
  ...
  Sigra.Audit.log_safe("session.revoke_all", scope, ...)
  {count, nil}
end

def revoke_session(config, hashed_token, opts \\ []) do
  delete_session(config, hashed_token, opts)
end
```

**Use for Phase 28:** keep the admin action layer very thin. It should authorize, call the canonical `Sigra.Auth` revoke APIs, and surface scope/target-aware failures without reimplementing DB deletes, audit writes, or disconnect broadcasts.

---

### `lib/sigra/admin/users/hooks.ex` (hook, transform)

**Analog:** `lib/sigra/hooks.ex`

**Configured hook lookup pattern** (`lib/sigra/hooks.ex:52-80`, `92-102`):
```elixir
def maybe_run_hook(multi, operation, context_map, config) do
  hook = get_hook(config, operation)

  case hook do
    nil -> multi
    {mod, fun} ->
      Multi.run(multi, :"on_#{operation}_hook", fn repo, changes ->
        merged_context = Map.merge(context_map, %{changes: changes})
        ...
      end)
  end
end

def get_hook(%{hooks: hooks}, operation) when is_list(hooks) do
  Keyword.get(hooks, :"on_#{operation}")
end
```

**Use for Phase 28:** if Phase 28 adds narrow host customization seams, keep them explicit and callback/config driven, not macro-generated page copies.

---

### `lib/sigra/admin/live/users_index_live.ex` (component, request-response)

**Analog:** `test/example/lib/example_web/live/organization_members_live.ex`

**Mount + assign/stream setup** (`test/example/lib/example_web/live/organization_members_live.ex:41-64`):
```elixir
def mount(_params, _session, socket) do
  scope = socket.assigns.current_scope
  rows = Organizations.list_members_with_activity(scope, limit: @page_size, offset: 0)
  total = Organizations.count_members(scope)
  decorated = decorate_rows(rows)

  {:ok,
   socket
   |> stream(:members, decorated)
   |> assign(:total_count, total)
   |> assign(:offset, length(decorated))
   |> assign(:has_more, length(decorated) < total)
   |> assign(:pending_action, nil)}
end
```

**LiveView event/update pattern** (`test/example/lib/example_web/live/organization_members_live.ex:70-93`, `95-130`):
```elixir
def handle_event("load_more", _params, socket) do
  ...
  {:noreply,
   socket
   |> assign(:offset, new_offset)
   |> assign(:has_more, new_offset < socket.assigns.total_count)}
end

def handle_event("open_remove_modal", %{"id" => id}, socket) do
  ...
  {:noreply,
   socket
   |> assign(:pending_action, {:remove, member})
   |> push_event("open-modal", %{id: "confirm-remove-modal"})}
end
```

**Admin placeholder title/heading pattern to preserve** (`lib/sigra/admin/live/index_live.ex:13-24`):
```elixir
{:ok,
 socket
 |> assign(:admin_scope, admin_scope)
 |> assign(:page_title, "Admin")
 |> assign(:heading, "Global admin")}
```

**Use for Phase 28:** parse URL params in `handle_params/3`, keep list state server-owned, and reuse the modal/open/close event style already used for mobile-safe list actions.

---

### `lib/sigra/admin/live/user_show_live.ex` (component, request-response)

**Analog:** `test/example/lib/example_web/live/auth/session_live.ex`

**Session list rendering pattern** (`test/example/lib/example_web/live/auth/session_live.ex:19-29`, `31-98`):
```elixir
def mount(_params, _session, socket) do
  user = socket.assigns.current_scope.user
  sessions = Auth.list_sessions(user)
  current_token = get_connect_params(socket)["_sigra_token"]

  {:ok, assign(socket, sessions: sessions, current_token: current_token, page_title: "Active Sessions")}
end
```

```elixir
<div :for={session <- @sessions} class="flex items-start justify-between ...">
  ...
  <.button phx-click="revoke" phx-value-token={Base.url_encode64(session.hashed_token)}>
    Revoke session
  </.button>
</div>
```

**Security summary section pattern** (`test/example/lib/example_web/live/mfa_settings_live.ex:25-55`, `247-260`):
```elixir
def mount(_params, _session, socket) do
  user = socket.assigns.current_scope.user
  mfa_status = Auth.mfa_status(user)
  passkeys = Auth.passkeys_for_user(user)
  passkey_count = Auth.passkey_count_for_user(user)
  ...
end
```

```elixir
<section id="passkeys" class="mt-8 bg-gray-50 p-4 rounded-lg border border-gray-200">
  <div class="flex items-start justify-between gap-4">
```

**Use for Phase 28:** server-load all detail sections in mount/handle_params, keep session revoke actions as explicit events, and use anchored section markup instead of tab-local hidden state.

---

### `lib/sigra/admin/live/index_live.ex` (component, request-response)

**Analog:** `lib/sigra/admin/live/index_live.ex`

**Minimal placeholder shape to preserve when repointing landing behavior** (`lib/sigra/admin/live/index_live.ex:13-24`, `27-43`):
```elixir
{:ok,
 socket
 |> assign(:admin_scope, admin_scope)
 |> assign(:page_title, "Admin")
 |> assign(:heading, "Global admin")
 |> assign(:body, "Open a global admin destination or intentionally enter an organization scope.")}
```

```elixir
<section class="space-y-4">
  <div class="space-y-2">
    <h1 class="text-2xl font-semibold">{@heading}</h1>
    <p class="text-sm text-base-content/70">{@body}</p>
  </div>
</section>
```

**Use for Phase 28:** if this LiveView remains, it should stay thin and likely redirect or delegate into the new users index rather than become a second admin shell with duplicated logic.

---

### `lib/sigra/admin/live/organization_live.ex` (component, request-response)

**Analog:** `lib/sigra/admin/live/organization_live.ex`

**Scope-aware heading/body pattern** (`lib/sigra/admin/live/organization_live.ex:13-25`, `28-49`):
```elixir
organization_name = admin_scope.organization && admin_scope.organization.name

{:ok,
 socket
 |> assign(:admin_scope, admin_scope)
 |> assign(:page_title, organization_name || "Organization admin")
 |> assign(:heading, organization_name || "Organization admin")}
```

**Use for Phase 28:** same guidance as the global page. Keep it as a scope-aware handoff into `/admin/organizations/:org/users`, not a second independently evolving admin surface.

---

### `test/example/lib/example_web/router.ex` (route, request-response)

**Analog:** `test/example/lib/example_web/router.ex`

**Admin `live_session` mount pattern** (`test/example/lib/example_web/router.ex:210-241`):
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
    live "/admin", Elixir.Sigra.Admin.Live.IndexLive, :index
  end
end
```

```elixir
scope "/admin/organizations/:org", alias: false do
  pipe_through [:browser, :require_authenticated, :admin_organization]
  ...
  live "/", Elixir.Sigra.Admin.Live.OrganizationLive, :show
end
```

**Use for Phase 28:** add `/admin/users`, `/admin/users/:id`, `/admin/organizations/:org/users`, and `/admin/organizations/:org/users/:id` inside these existing `live_session`s so Plug and LiveView scope enforcement stay in parity.

---

### `test/example/lib/example_web/components/admin_shell.ex` (component, request-response)

**Analog:** `test/example/lib/example_web/components/admin_shell.ex`

**Persistent scope chrome pattern** (`test/example/lib/example_web/components/admin_shell.ex:13-41`):
```elixir
<header class="sticky top-0 z-30 border-b border-base-300 bg-base-200/95 backdrop-blur">
  <div class="mx-auto flex max-w-7xl flex-wrap items-center justify-between ...">
    <div class="flex items-center gap-2">
      <span class="text-sm font-semibold">Admin</span>
      <span class={scope_chip_class(@admin_scope)}>{scope_label(@admin_scope)}</span>
```

**Sidebar + mobile bottom-nav pattern** (`test/example/lib/example_web/components/admin_shell.ex:45-98`):
```elixir
<aside class="hidden w-64 shrink-0 lg:block">
  <nav aria-label="Admin navigation" class="space-y-4">
    ...
    <div class="rounded-lg bg-base-200 p-3">
      <p class="mb-2 text-xs font-semibold uppercase text-base-content/60">Operations</p>
      <ul class="menu gap-1 p-0">
        <li><span class="text-base-content/60">Users</span></li>
        <li><span class="text-base-content/60">Audit</span></li>
      </ul>
    </div>
  </nav>
</aside>
```

**Use for Phase 28:** keep scope visible in shell chrome, promote `Users` from placeholder text to real links in both desktop and mobile nav, and do not introduce a separate scope picker/banner.

---

### `test/sigra/admin/users_query_test.exs` (test, CRUD)

**Analog:** `test/example/test/example_web/live/organization_members_live_test.exs`

**Fixture-heavy integration style** (`test/example/test/example_web/live/organization_members_live_test.exs:16-80`):
```elixir
use ExampleWeb.ConnCase, async: false

defp create_org_with_role!(user, role, org_attrs) do
  ...
end
```

**Small focused test cases pattern** (`test/example/test/example_web/live/organization_members_live_test.exs:86-133`, `174-232`):
```elixir
test "T1: owner sees an enabled Invite member button ...", %{conn: conn, user: user} do
  ...
  assert html =~ "Invite member"
end
```

**Use for Phase 28:** keep users query tests flat and scenario-driven. Seed only the rows needed to prove scope filtering, search keys, quick filters, and pagination boundaries.

---

### `test/sigra/admin/users_actions_test.exs` (test, event-driven)

**Analog:** `test/example/test/example_web/live/passkey_settings_live_test.exs`

**LiveView/direct-path mixed testing pattern** (`test/example/test/example_web/live/passkey_settings_live_test.exs:15-45`, `46-105`, `171-190`):
```elixir
use ExampleWeb.ConnCase, async: false
import Phoenix.LiveViewTest

test "stale sudo rejects enrollment options and completion without changing passkeys", %{conn: conn} do
  ...
  assert redirected_to(conn) == ~p"/users/log_in"
end
```

**State assertion after action pattern** (`test/example/test/example_web/live/passkey_settings_live_test.exs:97-105`, `188-190`):
```elixir
assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Passkey added."
assert Accounts.passkey_count_for_user(user) == before_count + 1
```

**Use for Phase 28:** assert revoke-one and revoke-all through the admin action layer, then verify session count changes, audit side effects, and scope failures explicitly.

---

### `test/example/test/example_web/live/admin_user_index_live_test.exs` (test, request-response)

**Analog:** `test/example/test/example_web/live/organization_members_live_test.exs`

**Conn-driven page assertions** (`test/example/test/example_web/live/organization_members_live_test.exs:142-167`, `177-206`):
```elixir
conn = get(conn, ~p"/organizations/#{org.slug}/members")
html = html_response(conn, 200)

assert html =~ "Pending invitations (2)"
assert html =~ "alpha@t5.example"
```

**Use for Phase 28:** keep the admin index test readable: route request, assert rendered search/filter affordances, then prove scoped rows are present/absent without overusing DOM traversal helpers.

---

### `test/example/test/example_web/live/admin_user_filters_live_test.exs` (test, request-response)

**Analog:** `test/example/test/example_web/live/organization_members_live_test.exs`

**Named scenario style** (`test/example/test/example_web/live/organization_members_live_test.exs:139-168`, `174-232`):
```elixir
describe "Phase 17 — pending invitations list rendering" do
  ...
  test "T5: populated list renders ..." do
    ...
  end
end
```

**Use for Phase 28:** separate filter-contract cases by behavior group: quick chips, more-filters drawer params, URL persistence, and org-scoped restrictions.

---

### `test/example/test/example_web/live/admin_user_show_live_test.exs` (test, request-response)

**Analog:** `test/example/test/example_web/live/passkey_settings_live_test.exs`

**Real LiveView interaction pattern** (`test/example/test/example_web/live/passkey_settings_live_test.exs:193-220`):
```elixir
{:ok, view, _html} =
  conn
  |> log_in_user(user)
  |> live("/users/settings/mfa")

assert render_click(view, "open_passkey_rename", %{"id" => passkey.credential_id}) =~ "Old name"
```

**Use for Phase 28:** use `live/2`, `render_click/3`, and `render_submit/3` for detail-page interactions like opening confirmations and revoking sessions, while still asserting final DB state directly.

---

### `test/example/priv/playwright/tests/admin-user-operations.spec.ts` (test, request-response)

**Analog:** `test/example/priv/playwright/tests/organizations.spec.ts`

**Spec structure + helpers pattern** (`test/example/priv/playwright/tests/organizations.spec.ts:15-35`, `36-79`):
```typescript
import { test, expect } from '@playwright/test';

const EXAMPLE_BASE_URL = process.env.SIGRA_EXAMPLE_URL ?? 'http://localhost:4000';

async function waitForLiveViewReady(page) {
  await page.waitForSelector('[data-phx-session].phx-connected', { state: 'attached' });
}
```

**Journey-style browser test pattern** (`test/example/priv/playwright/tests/organizations.spec.ts:153-220`):
```typescript
test('phase 16 organizations UX: register -> ...', async ({ page }) => {
  await page.goto('/users/register');
  await waitForLiveViewReady(page);
  ...
  await expect(page).toHaveURL(/\/organizations$/);
});
```

**Use for Phase 28:** write one operator journey that covers mobile-safe search -> filtered list -> open detail -> confirm revoke session, with explicit URL and visible-copy assertions after each transition.

## Shared Patterns

### Authentication + LiveView Scope Enforcement
**Source:** `test/example/lib/example_web/router.ex:210-241`, `lib/sigra/live_view/admin_scope.ex:15-32`
**Apply to:** All admin LiveViews and all admin example-app route mounts
```elixir
live_session :admin_global,
  layout: {ExampleWeb.Layouts, :admin},
  on_mount: [
    {ExampleWeb.UserAuth, :ensure_authenticated},
    {Sigra.LiveView.AdminScope,
     [mode: :global, policy: Example.SigraAdminPolicy, login_path: "/users/log_in"]}
  ] do
  ...
end
```

```elixir
case resolve_requested_scope(scope, params, opts) do
  {:ok, admin_scope} -> {:cont, put_in(socket.assigns[assign_key], admin_scope)}
  {:error, :unauthenticated} -> {:halt, put_in(socket.assigns[:sigra_redirect_to], login_path)}
  {:error, :forbidden} -> {:halt, put_in(socket.assigns[:sigra_admin_forbidden], true)}
  {:error, :not_found} -> {:halt, put_in(socket.assigns[:sigra_not_found], true)}
end
```

### Scope-Safe Queries
**Source:** `lib/sigra/admin/authorizer.ex:49-65`, `lib/sigra/organizations/query.ex:37-48`
**Apply to:** `lib/sigra/admin/users/query.ex`, `lib/sigra/admin/users/detail.ex`, `lib/sigra/admin/users/actions.ex`
```elixir
def scope_query(queryable, %Scope{} = admin_scope) do
  query = Ecto.Queryable.to_query(queryable)

  cond do
    Scope.global?(admin_scope) -> query
    Scope.organization?(admin_scope) and is_binary(admin_scope.organization_id) ->
      Sigra.Organizations.Query.for_org(query, admin_scope.organization_id)
    true ->
      raise UnauthorizedError, reason: :not_found, message: "organization-scoped admin queries require a resolved organization"
  end
end
```

### Guarded Actions + Audit/Disconnect Side Effects
**Source:** `lib/sigra/auth.ex:1222-1265`, `lib/sigra/organizations.ex:844-864`
**Apply to:** `lib/sigra/admin/users/actions.ex`, detail LiveView session-revoke flows
```elixir
{count, _} = session_store.delete_all_for_user(user_id, delete_opts)

if pubsub do
  sessions
  |> Enum.reject(fn s -> except_token && s.hashed_token == except_token end)
  |> Enum.each(fn session ->
    live_socket_id = "users_sessions:#{Base.url_encode64(session.hashed_token)}"
    Phoenix.PubSub.broadcast(pubsub, live_socket_id, :disconnect)
  end)
end

Sigra.Audit.log_safe("session.revoke_all", scope, ...)
```

### Modal Confirmation UX
**Source:** `test/example/lib/example_web/live/organization_members_live.ex:95-130`, `133-170`
**Apply to:** `lib/sigra/admin/live/users_index_live.ex`, `lib/sigra/admin/live/user_show_live.ex`
```elixir
{:noreply,
 socket
 |> assign(:pending_action, {:remove, member})
 |> assign(:remove_modal_error, nil)
 |> push_event("open-modal", %{id: "confirm-remove-modal"})}
```

```elixir
{:noreply,
 socket
 |> assign(:pending_action, nil)
 |> assign(:role_modal_error, nil)
 |> assign(:remove_modal_error, nil)
 |> push_event("close-modal", %{id: "confirm-role-modal"})
 |> push_event("close-modal", %{id: "confirm-remove-modal"})}
```

### Shell Navigation + Visible Scope
**Source:** `test/example/lib/example_web/components/admin_shell.ex:15-98`
**Apply to:** `test/example/lib/example_web/components/admin_shell.ex`, any new admin UI copy/navigation
```elixir
<span class="text-sm font-semibold">Admin</span>
<span class={scope_chip_class(@admin_scope)}>{scope_label(@admin_scope)}</span>
...
<p class="mb-2 text-xs font-semibold uppercase text-base-content/60">Operations</p>
```

## No Analog Found

Files with no strong same-role + same-data-flow analog (planner should adapt the nearest role-match and keep scope enforcement centralized):

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/sigra/admin/users/detail.ex` | service | request-response | No existing library module assembles one admin-facing user detail payload across sessions, MFA, passkeys, organizations, and audit preview. |
| `lib/sigra/admin/users/hooks.ex` | hook | transform | `Sigra.Hooks` is generic transaction-hook infrastructure, but there is no current presentation-focused admin hook seam. |
| `test/sigra/admin/users_query_test.exs` | test | CRUD | Root library tests do not yet have an admin-query-specific pattern; copy the flat fixture/test style from example-app integration tests. |

## Metadata

**Analog search scope:** `lib/`, `test/example/lib/`, `test/example/test/`, `test/example/priv/playwright/`, phase artifacts under `.planning/phases/28-user-operations-surface/`
**Files scanned:** 581 listed source/test files plus the phase context artifacts
**Pattern extraction date:** 2026-04-16
