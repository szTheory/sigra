# Phase 29: Secure Impersonation - Pattern Map

**Mapped:** 2026-04-16
**Files analyzed:** 11
**Analogs found:** 11 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/admin/controllers/impersonation_controller.ex` | controller | request-response | `test/example/lib/example_web/controllers/auth/sudo_controller.ex` | exact |
| `lib/sigra/plug/require_not_impersonating.ex` | middleware | request-response | `lib/sigra/plug/require_sudo.ex` | role-match |
| `lib/sigra/auth.ex` | service | CRUD | `lib/sigra/auth.ex` | exact |
| `lib/sigra/scope.ex` | model | transform | `lib/sigra/scope.ex` | exact |
| `lib/sigra/scope/hydration.ex` | service | transform | `lib/sigra/scope/hydration.ex` | exact |
| `lib/sigra/audit.ex` | service | transform | `lib/sigra/audit.ex` | exact |
| `lib/sigra/admin/live/user_show_live.ex` | component | request-response | `lib/sigra/admin/live/user_show_live.ex` | exact |
| `lib/sigra/admin/users/actions.ex` | service | request-response | `lib/sigra/admin/users/actions.ex` | exact |
| `lib/sigra/admin/users/detail.ex` | service | CRUD | `lib/sigra/admin/users/detail.ex` | exact |
| `test/example/lib/example_web/components/admin_shell.ex` | component | request-response | `test/example/lib/example_web/components/admin_shell.ex` | exact |
| `test/example/lib/example_web/router.ex` | route | request-response | `test/example/lib/example_web/router.ex` | exact |

## Pattern Assignments

### `lib/sigra/admin/controllers/impersonation_controller.ex` (controller, request-response)

**Primary analog:** `test/example/lib/example_web/controllers/auth/sudo_controller.ex`

Use a plain controller-owned POST flow for start/stop, not a LiveView event. The sudo controller is the strongest local precedent for a security-sensitive handoff that validates local `return_to`, mutates server-side session state, flashes, then redirects.

**Controller-owned security flow** ([test/example/lib/example_web/controllers/auth/sudo_controller.ex](/Users/jon/projects/sigra/test/example/lib/example_web/controllers/auth/sudo_controller.ex#L19)):
```elixir
def new(conn, _params) do
  form = Phoenix.Component.to_form(%{"password" => ""}, as: "sudo")
  render(conn, :new, return_to: conn.params["return_to"] || ~p"/", form: form)
end

def create(conn, %{"sudo" => %{"password" => password, "return_to" => return_to}}) do
  user = conn.assigns.current_scope.user
```

**Safe local-path redirect handling** ([test/example/lib/example_web/controllers/auth/sudo_controller.ex](/Users/jon/projects/sigra/test/example/lib/example_web/controllers/auth/sudo_controller.ex#L27)):
```elixir
case Sigra.Crypto.verify_password(password, user.hashed_password) do
  true ->
    session = conn.private[:sigra_session]
    Example.Accounts.confirm_sudo(session.hashed_token)

    safe_return_to =
      if return_to && String.starts_with?(return_to, "/") &&
           !String.starts_with?(return_to, "//") do
        return_to
      else
        ~p"/"
      end

    conn
    |> put_flash(:info, "Password confirmed.")
    |> redirect(to: safe_return_to)
```

**Token swap pattern to reuse inside controller** ([test/example/lib/example_web/controllers/session_controller.ex](/Users/jon/projects/sigra/test/example/lib/example_web/controllers/session_controller.ex#L237)):
```elixir
return_to = get_session(conn, :mfa_return_to) || ~p"/"
remember_me = get_session(conn, :mfa_remember_me) == true
user = conn.assigns.current_scope.user
old_session = conn.private[:sigra_session]

with true <- get_session(conn, :mfa_pending) == true,
     %{type: :mfa_pending} <- old_session,
     {:ok, %{session: upgraded_session}} <-
       Auth.complete_mfa_verification(user, old_session, remember_me: remember_me) do
  conn
  |> UserAuth.put_user_session_token(upgraded_session.token)
  |> delete_session(:mfa_pending)
  |> delete_session(:mfa_return_to)
  |> delete_session(:mfa_remember_me)
  |> put_flash(:info, "Two-factor authentication verified.")
  |> redirect(to: return_to)
end
```

**Planner guidance:** Phase 29 start/stop should copy this controller shape exactly: fetch state from `conn.assigns` and `conn.private`, perform one server-side auth mutation, use `UserAuth.put_user_session_token/2` for fixation-safe swapping, clean up preserved session keys, then redirect.

---

### `lib/sigra/auth.ex` impersonation start/stop helpers (service, CRUD)

**Primary analog:** `lib/sigra/auth.ex`

The session lifecycle code already owns token creation, deletion, sudo updates, active-org assignment, and audit emission. New impersonation helpers should live beside these functions.

**Canonical session-create audit seam** ([lib/sigra/auth.ex](/Users/jon/projects/sigra/lib/sigra/auth.ex#L1084)):
```elixir
scope =
  case config.scope_module do
    nil -> nil
    mod -> Sigra.Scope.build(mod, user, active_organization: active_org)
  end

Sigra.Audit.log_safe("session.create", scope,
  Keyword.merge(audit_opts,
    actor_id: user.id,
    metadata: %{type: Map.get(metadata, :type, :standard), session_id: final_session.id}
  )
)
```

**Delete / revoke call-site pattern** ([lib/sigra/auth.ex](/Users/jon/projects/sigra/lib/sigra/auth.ex#L1182)):
```elixir
user_id = Keyword.get(opts, :user_id)
scope = user_id && Sigra.Scope.from_config(config, %{id: user_id})

Sigra.Audit.log_safe("session.delete", scope,
  Keyword.merge(audit_opts,
    actor_id: user_id,
    target_id: user_id,
    metadata: %{}
  )
)
```

**Bulk revoke pattern** ([lib/sigra/auth.ex](/Users/jon/projects/sigra/lib/sigra/auth.ex#L1222)):
```elixir
sessions = session_store.list_by_user(user_id, store_opts)
{count, _} = session_store.delete_all_for_user(user_id, delete_opts)

if pubsub do
  sessions
  |> Enum.reject(fn s -> except_token && s.hashed_token == except_token end)
  |> Enum.each(fn session ->
    live_socket_id = "users_sessions:#{Base.url_encode64(session.hashed_token)}"
    Phoenix.PubSub.broadcast(pubsub, live_socket_id, :disconnect)
  end)
end
```

**Outcome-based audit action selection** ([lib/sigra/auth.ex](/Users/jon/projects/sigra/lib/sigra/auth.ex#L1300)):
```elixir
action =
  case result do
    :ok -> "session.sudo_enter"
    {:ok, _} -> "session.sudo_enter"
    _ -> "session.sudo_expire"
  end

Sigra.Audit.log_safe(action, scope,
  Keyword.merge(audit_opts,
    actor_id: user_id,
    target_id: user_id,
    outcome: outcome,
    metadata: %{}
  )
)
```

**Planner guidance:** Implement impersonation as additive session lifecycle helpers in `Sigra.Auth`, not as a new parallel subsystem. Follow the same return shape style, option-passing, and explicit audit call sites.

---

### Session rotation and token swapping in the web layer

**Primary analog:** `test/example/lib/example_web/user_auth.ex`

The planner should treat this module as the non-negotiable fixation-safe swap contract.

**Renew before writing token** ([test/example/lib/example_web/user_auth.ex](/Users/jon/projects/sigra/test/example/lib/example_web/user_auth.ex#L58)):
```elixir
conn
|> renew_session()
|> put_token_in_session(token)
|> maybe_write_remember_me_cookie(token, params)
|> redirect(to: user_return_to || signed_in_path(conn))
```

**Upgrade existing session token** ([test/example/lib/example_web/user_auth.ex](/Users/jon/projects/sigra/test/example/lib/example_web/user_auth.ex#L74)):
```elixir
def put_user_session_token(conn, token) when is_binary(token) do
  conn
  |> renew_session()
  |> put_token_in_session(token)
end
```

**Renew implementation** ([test/example/lib/example_web/user_auth.ex](/Users/jon/projects/sigra/test/example/lib/example_web/user_auth.ex#L95)):
```elixir
defp renew_session(conn) do
  delete_csrf_token()

  conn
  |> configure_session(renew: true)
  |> clear_session()
end
```

**Planner guidance:** Start and stop impersonation should never write session tokens directly with `put_session/3`; they should reuse `put_user_session_token/2`, then explicitly restore any preserved keys that need to survive the rotation.

---

### Plug + LiveView parity for auth and scope state

**Primary analogs:** `test/example/lib/example_web/user_auth.ex`, `lib/sigra/scope/hydration.ex`, `test/example/lib/example_web/router.ex`, `lib/sigra/plug/require_admin_access.ex`

The codebase already keeps Plug and LiveView in lockstep by hydrating `current_scope` once, then mounting LiveViews through `on_mount`.

**Plug-side current scope assignment** ([test/example/lib/example_web/user_auth.ex](/Users/jon/projects/sigra/test/example/lib/example_web/user_auth.ex#L150)):
```elixir
scope = user && Scope.for_user(user)

conn
|> put_private(:sigra_session, session)
|> assign(:current_scope, scope)
```

**LiveView-side current scope mount** ([test/example/lib/example_web/user_auth.ex](/Users/jon/projects/sigra/test/example/lib/example_web/user_auth.ex#L206)):
```elixir
def on_mount(:ensure_authenticated, _params, session, socket) do
  socket = mount_current_scope(socket, session)

  if socket.assigns.current_scope do
    {:cont, socket}
  else
    socket
    |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
    |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")
  end
end
```

**Single hydration seam** ([lib/sigra/scope/hydration.ex](/Users/jon/projects/sigra/lib/sigra/scope/hydration.ex#L1)):
```elixir
Pure scope-hydration contract shared between `Sigra.Plug.LoadActiveOrganization`
(Plug pipeline) and the generated `UserAuth.on_mount` callback (LiveView).

This module is the SINGLE place scope hydration lives. Any future scope
augmentation — impersonation (v1.2), feature flags, passkey context —
extends this function.
```

**Hydration implementation shape** ([lib/sigra/scope/hydration.ex](/Users/jon/projects/sigra/lib/sigra/scope/hydration.ex#L53)):
```elixir
def hydrate(scope, _config, %Sigra.Session{active_organization_id: nil}) do
  {:ok, scope}
end

def hydrate(scope, config, %Sigra.Session{active_organization_id: org_id}) do
  user = scope.user

  case Organizations.fetch_organization(config, org_id) do
    {:ok, org} ->
      case Organizations.get_membership(config, user, org) do
        nil -> {:error, :not_a_member}
        membership -> {:ok, %{scope | active_organization: org, membership: membership}}
      end
```

**Admin Plug / LiveView parity in router** ([test/example/lib/example_web/router.ex](/Users/jon/projects/sigra/test/example/lib/example_web/router.ex#L61)):
```elixir
pipeline :admin_global do
  plug Sigra.Plug.RequireAdminAccess,
    error_handler: ExampleWeb.AuthErrorHandler,
    policy: Example.SigraAdminPolicy,
    mode: :global
end

live_session :admin_global,
  layout: {ExampleWeb.Layouts, :admin},
  on_mount: [
    {ExampleWeb.UserAuth, :ensure_authenticated},
    {Sigra.LiveView.AdminScope,
     [mode: :global, policy: Example.SigraAdminPolicy, login_path: "/users/log_in"]}
  ] do
```

**Planner guidance:** Add impersonation fields by extending the existing scope construction + hydration path, not by introducing separate LiveView-only assigns or session decoding logic.

---

### `lib/sigra/scope.ex` (model, transform)

**Primary analog:** `lib/sigra/scope.ex`

The reserved-field contract already exists.

**Scope struct construction** ([lib/sigra/scope.ex](/Users/jon/projects/sigra/lib/sigra/scope.ex#L16)):
```elixir
struct(scope_module,
  user: user,
  active_organization: Keyword.get(opts, :active_organization),
  membership: Keyword.get(opts, :membership),
  impersonating_from: nil
)
```

**Minimal audit-only scope builder** ([lib/sigra/scope.ex](/Users/jon/projects/sigra/lib/sigra/scope.ex#L46)):
```elixir
def from_opts(opts, user) when is_list(opts) do
  case Keyword.get(opts, :scope_module) do
    nil -> nil
    mod when is_atom(mod) -> build(mod, user, active_organization: nil)
  end
end
```

**Planner guidance:** Keep `impersonating_from` as an additive field on the same scope struct. Do not create an impersonation-only scope type.

---

### `lib/sigra/audit.ex` (service, transform)

**Primary analog:** `lib/sigra/audit.ex`

Phase 29 should extend the existing `scope_fields/1` seam instead of inventing a second actor/effective-user path.

**Canonical scope-to-columns seam** ([lib/sigra/audit.ex](/Users/jon/projects/sigra/lib/sigra/audit.ex#L116)):
```elixir
def log_safe(action, scope, opts) when is_binary(action) and is_list(opts) do
  scope_opts = scope_fields(scope)
  merged = Keyword.merge(scope_opts, opts)
  do_log_safe(action, merged)
end
```

**Exact diff point for impersonation** ([lib/sigra/audit.ex](/Users/jon/projects/sigra/lib/sigra/audit.ex#L146)):
```elixir
defp scope_fields(%{user: user} = scope) do
  org = Map.get(scope, :active_organization)
  # D-04: v1.2 impersonation diff is a single conditional added on this line.
  [
    organization_id: org && org.id,
    effective_user_id: user && user.id,
    actor_id: user && user.id
  ]
end
```

**Planner guidance:** Make the impersonation audit diff here: `actor_id` should resolve from `scope.impersonating_from`, `effective_user_id` should stay on `scope.user`, and lifecycle event names should stay explicit at each call site.

---

### `lib/sigra/admin/live/user_show_live.ex` (component, request-response)

**Primary analog:** `lib/sigra/admin/live/user_show_live.ex`

This is the strongest precedent for URL-driven admin detail pages, explicit `return_to`, and security-sensitive actions living on detail rather than list rows.

**Detail-page state + `return_to` parsing** ([lib/sigra/admin/live/user_show_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/user_show_live.ex#L23)):
```elixir
def handle_params(%{"id" => user_id} = params, _uri, socket) do
  admin_scope = socket.assigns.admin_scope
  detail = Detail.load!(socket.assigns.sigra_config, admin_scope, user_id)
  return_to = sanitize_return_to(Map.get(params, "return_to"), admin_scope)

  {:noreply,
   socket
   |> assign(:detail, detail)
   |> assign(:return_to, return_to)
   |> assign(:confirm_action, nil)}
end
```

**High-risk action confirmation shape** ([lib/sigra/admin/live/user_show_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/user_show_live.ex#L59)):
```elixir
case socket.assigns.confirm_action do
  %{type: :revoke_session, token: token} ->
    :ok = Actions.revoke_session(config, admin_scope, detail.user.id, token)

    {:noreply,
     socket
     |> reload_detail(detail.user.id)
     |> put_flash(:info, "Session revoked.")}
```

**URL-driven `return_to` guard** ([lib/sigra/admin/live/user_show_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/user_show_live.ex#L243)):
```elixir
defp sanitize_return_to(path, admin_scope) when is_binary(path) do
  if String.starts_with?(path, ["/admin/users", "/admin/organizations/"]) do
    path
  else
    default_return_to(admin_scope)
  end
end
```

**Preserve context when pivoting paths** ([lib/sigra/admin/live/user_show_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/user_show_live.ex#L259)):
```elixir
defp pivot_path(_admin_scope, user_id, organization, return_to) do
  path = "/admin/organizations/#{organization.organization_slug}/users/#{user_id}"

  if is_binary(return_to) and return_to != "" do
    path <> "?return_to=" <> URI.encode_www_form(return_to)
  else
    path
  end
end
```

**Planner guidance:** Put the start-impersonation entry point on this detail surface and preserve `return_to` exactly this way. The HTTP controller should receive the same sanitized URL value.

---

### `test/example/lib/example_web/components/admin_shell.ex` (component, request-response)

**Primary analog:** `test/example/lib/example_web/components/admin_shell.ex`

This is the banner seam for persistent impersonation state. The shell is host-owned, but the condition comes from library-owned scope state.

**Host-owned seam** ([test/example/lib/example_web/components/admin_shell.ex](/Users/jon/projects/sigra/test/example/lib/example_web/components/admin_shell.ex#L8)):
```elixir
attr :admin_scope, :map, required: true
attr :current_scope, :map, default: nil
slot :special_session
slot :inner_block, required: true
```

**Current special-session rendering point** ([test/example/lib/example_web/components/admin_shell.ex](/Users/jon/projects/sigra/test/example/lib/example_web/components/admin_shell.ex#L18)):
```elixir
<span class={scope_chip_class(@admin_scope)}>{scope_label(@admin_scope)}</span>
<%= if render_special_session?(@special_session, @current_scope) do %>
  <span class="badge badge-outline">{special_session_label(@current_scope)}</span>
<% end %>
```

**Current impersonation detection hook** ([test/example/lib/example_web/components/admin_shell.ex](/Users/jon/projects/sigra/test/example/lib/example_web/components/admin_shell.ex#L139)):
```elixir
defp render_special_session?([], current_scope),
  do: not is_nil(special_session_label(current_scope))

defp special_session_label(%{impersonating_from: %_{}}), do: "Special session"
```

**Layout ownership seam** ([test/example/lib/example_web/components/layouts.ex](/Users/jon/projects/sigra/test/example/lib/example_web/components/layouts.ex#L91)):
```elixir
def admin(assigns) do
  ~H"""
  <.admin_shell admin_scope={@admin_scope} current_scope={@current_scope}>
    {@inner_content}
  </.admin_shell>
```

**Planner guidance:** Replace the generic badge with a dedicated impersonation indicator/banner via this seam. Keep the display host-owned, but make the visibility derive from `current_scope.impersonating_from`.

---

### Direct-path authorization and scoped queries

**Primary analogs:** `lib/sigra/admin/authorizer.ex`, `lib/sigra/admin/users/detail.ex`, `lib/sigra/admin/users/actions.ex`

Phase 29 should rely on the already-established direct-path admin authorization boundary, not re-check scope only in LiveView.

**Global/org authorization helpers** ([lib/sigra/admin/authorizer.ex](/Users/jon/projects/sigra/lib/sigra/admin/authorizer.ex#L15)):
```elixir
def authorize_global!(%Scope{} = admin_scope) do
  if Scope.global?(admin_scope) do
    :ok
  else
    raise UnauthorizedError,
      reason: :forbidden,
      message: "global admin access is required for this operation"
  end
end
```

**Scoped query helper** ([lib/sigra/admin/authorizer.ex](/Users/jon/projects/sigra/lib/sigra/admin/authorizer.ex#L49)):
```elixir
def scope_query(queryable, %Scope{} = admin_scope) do
  query = Ecto.Queryable.to_query(queryable)

  cond do
    Scope.global?(admin_scope) ->
      query

    Scope.organization?(admin_scope) and is_binary(admin_scope.organization_id) ->
      Sigra.Organizations.Query.for_org(query, admin_scope.organization_id)
```

**Direct-path load before mutate** ([lib/sigra/admin/users/actions.ex](/Users/jon/projects/sigra/lib/sigra/admin/users/actions.ex#L9)):
```elixir
def revoke_session(config, %Scope{} = admin_scope, user_id, hashed_token)
    when is_binary(user_id) and is_binary(hashed_token) do
  user = Detail.load_user!(config, admin_scope, user_id)
  Sigra.Auth.revoke_session(config, hashed_token, user_id: user.id)
end
```

**Scoped detail query** ([lib/sigra/admin/users/detail.ex](/Users/jon/projects/sigra/lib/sigra/admin/users/detail.ex#L96)):
```elixir
query =
  case admin_scope do
    %Scope{mode: :global} ->
      Authorizer.scope_query(user_schema, admin_scope)

    %Scope{mode: :organization, organization_id: org_id} ->
      Authorizer.authorize_organization!(admin_scope, org_id)

      from(user in user_schema,
        where: user.id in subquery(membership_user_ids_query(helpers.membership_schema, org_id))
      )
  end
```

**Planner guidance:** Starting impersonation should load the target user through these scoped helpers first. Org-admin impersonation must be structurally limited by the same query boundary used for detail and mutations.

---

### `lib/sigra/plug/require_not_impersonating.ex` (middleware, request-response)

**Primary analog:** `lib/sigra/plug/require_sudo.ex`

There is no exact existing impersonation gate, so copy the guard-plug shape from `RequireSudo`.

**Guard plug shape** ([lib/sigra/plug/require_sudo.ex](/Users/jon/projects/sigra/lib/sigra/plug/require_sudo.ex#L57)):
```elixir
def call(conn, opts) do
  error_handler = Keyword.fetch!(opts, :error_handler)
  sudo_window = Keyword.fetch!(opts, :sudo_window)

  cond do
    is_nil(conn.assigns[:current_scope]) ->
      conn
      |> error_handler.auth_error(:unauthenticated, opts)
      |> Plug.Conn.halt()

    sudo_fresh?(conn, sudo_window) ->
      conn

    true ->
      conn
      |> error_handler.auth_error(:stale_sudo, opts)
      |> Plug.Conn.halt()
  end
end
```

**Planner guidance:** Build the new impersonation-blocking plug with this exact contract shape: read `current_scope`, fail closed with `error_handler.auth_error(...)`, halt, and make it reusable across controller endpoints and any non-LiveView boundary.

---

### Router wiring for controller-owned flows and parity

**Primary analog:** `test/example/lib/example_web/router.ex`

**Existing sudo boundary** ([test/example/lib/example_web/router.ex](/Users/jon/projects/sigra/test/example/lib/example_web/router.ex#L124)):
```elixir
scope "/users", ExampleWeb do
  pipe_through [:browser, :require_authenticated]

  get "/sudo", Auth.SudoController, :new
  post "/sudo", Auth.SudoController, :create
```

**Admin route split** ([test/example/lib/example_web/router.ex](/Users/jon/projects/sigra/test/example/lib/example_web/router.ex#L210)):
```elixir
scope "/", alias: false do
  pipe_through [:browser, :require_authenticated, :admin_global]

  live "/admin/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show
end

scope "/admin/organizations/:org", alias: false do
  pipe_through [:browser, :require_authenticated, :admin_organization]

  live "/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show
end
```

**Planner guidance:** Add controller POST routes for impersonation under the same admin path split. Starting impersonation should live behind `:require_authenticated`, admin-scope enforcement, and fresh sudo. Ending impersonation should remain controller-owned as well.

## Shared Patterns

### 1. Controller-owned security-sensitive flows
**Sources:** [test/example/lib/example_web/controllers/auth/sudo_controller.ex](/Users/jon/projects/sigra/test/example/lib/example_web/controllers/auth/sudo_controller.ex#L19), [test/example/lib/example_web/controllers/session_controller.ex](/Users/jon/projects/sigra/test/example/lib/example_web/controllers/session_controller.ex#L237)
```elixir
session = conn.private[:sigra_session]
...
conn
|> UserAuth.put_user_session_token(upgraded_session.token)
|> put_flash(:info, ...)
|> redirect(to: return_to)
```
Apply to start/stop impersonation controllers.

### 2. Session rotation and token swapping
**Source:** [test/example/lib/example_web/user_auth.ex](/Users/jon/projects/sigra/test/example/lib/example_web/user_auth.ex#L74)
```elixir
def put_user_session_token(conn, token) when is_binary(token) do
  conn
  |> renew_session()
  |> put_token_in_session(token)
end
```
Use for both impersonation start and restoration.

### 3. Plug + LiveView auth/scope parity
**Sources:** [test/example/lib/example_web/user_auth.ex](/Users/jon/projects/sigra/test/example/lib/example_web/user_auth.ex#L150), [lib/sigra/scope/hydration.ex](/Users/jon/projects/sigra/lib/sigra/scope/hydration.ex#L1), [test/example/lib/example_web/router.ex](/Users/jon/projects/sigra/test/example/lib/example_web/router.ex#L214)
```elixir
conn
|> put_private(:sigra_session, session)
|> assign(:current_scope, scope)
```
Keep impersonation state flowing through the same scope + hydration path on both sides.

### 4. Persistent shell/banner seam
**Sources:** [test/example/lib/example_web/components/admin_shell.ex](/Users/jon/projects/sigra/test/example/lib/example_web/components/admin_shell.ex#L18), [test/example/lib/example_web/components/layouts.ex](/Users/jon/projects/sigra/test/example/lib/example_web/components/layouts.ex#L91)
```elixir
<%= if render_special_session?(@special_session, @current_scope) do %>
  <span class="badge badge-outline">{special_session_label(@current_scope)}</span>
<% end %>
```
Use this seam for a non-dismissable impersonation banner.

### 5. URL-driven `return_to` handling
**Sources:** [lib/sigra/admin/live/user_show_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/user_show_live.ex#L243), [test/example/lib/example_web/controllers/auth/sudo_controller.ex](/Users/jon/projects/sigra/test/example/lib/example_web/controllers/auth/sudo_controller.ex#L32), [test/example/lib/example_web/user_auth.ex](/Users/jon/projects/sigra/test/example/lib/example_web/user_auth.ex#L388)
```elixir
if String.starts_with?(path, ["/admin/users", "/admin/organizations/"]) do
  path
else
  default_return_to(admin_scope)
end
```
Sanitize early, preserve through controller redirects, and fall back to scope-appropriate defaults.

### 6. Direct-path authorization and scoped queries
**Sources:** [lib/sigra/admin/authorizer.ex](/Users/jon/projects/sigra/lib/sigra/admin/authorizer.ex#L49), [lib/sigra/admin/users/detail.ex](/Users/jon/projects/sigra/lib/sigra/admin/users/detail.ex#L96), [lib/sigra/admin/users/actions.ex](/Users/jon/projects/sigra/lib/sigra/admin/users/actions.ex#L9)
```elixir
user = Detail.load_user!(config, admin_scope, user_id)
```
Authorize and scope the target before the impersonation mutation, not after.

### 7. Audit logging call-site patterns
**Sources:** [lib/sigra/auth.ex](/Users/jon/projects/sigra/lib/sigra/auth.ex#L1106), [lib/sigra/auth.ex](/Users/jon/projects/sigra/lib/sigra/auth.ex#L1325), [lib/sigra/audit.ex](/Users/jon/projects/sigra/lib/sigra/audit.ex#L135)
```elixir
Sigra.Audit.log_safe(action, scope,
  Keyword.merge(audit_opts,
    actor_id: user_id,
    target_id: user_id,
    outcome: outcome,
    metadata: %{}
  )
)
```
Emit impersonation `start`, `stop`, `timeout_expire`, and `denied` at the concrete call sites in `Sigra.Auth` and any blocking plug/controller.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| None | - | - | All major Phase 29 seams already have strong local precedents. The only missing exact analog is a dedicated "blocked while impersonating" plug, which should copy `RequireSudo`'s structure. |

## Metadata

**Analog search scope:** `lib/sigra/**`, `test/example/lib/example_web/**`, `.planning/phases/27-*`, `.planning/phases/28-*`, `.planning/phases/29-*`

**Files scanned:** 18

**Key patterns identified:**
- Security-sensitive session changes are controller-owned HTTP POST flows.
- Session token upgrades always rotate the Plug session before writing a new token.
- `current_scope` and `sigra_session` are the shared state contract across Plug and LiveView.
- Admin shell special-session UI is host-owned, but derives from `current_scope`.
- Admin actions authorize by resolved admin scope and structurally scoped queries.
- Audit attribution is centralized through `Sigra.Audit.log_safe/3` and `scope_fields/1`.
