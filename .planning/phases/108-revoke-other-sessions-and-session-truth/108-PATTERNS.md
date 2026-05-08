# Phase 108: Revoke Other Sessions and Session Truth - Pattern Map

**Mapped:** 2026-05-07
**Authoritative scope:** `.planning/phases/108-revoke-other-sessions-and-session-truth/108-CONTEXT.md`
**Files classified:** 14
**Analogs found:** 12 / 14

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/auth.ex` | service | request-response | `lib/sigra/auth.ex:1498-1573` | exact |
| `lib/sigra/session_stores/ecto.ex` | service | CRUD | `lib/sigra/session_stores/ecto.ex:123-158` | exact |
| `lib/sigra/session.ex` | model | transform | `lib/sigra/session.ex:20-45` | exact |
| `lib/sigra/admin/users/actions.ex` | service | request-response | `lib/sigra/admin/users/actions.ex:9-33` | exact |
| `lib/sigra/admin/users/detail.ex` | service | transform | `lib/sigra/admin/users/detail.ex:23-57` | exact |
| `lib/sigra/admin/live/user_show_live.ex` | component | request-response | `lib/sigra/admin/live/user_show_live.ex:38-79,107-149,337-367` | role-match |
| `test/example/lib/example/accounts.ex` | service | request-response | `test/example/lib/example/accounts.ex:783-805,1714-1717` | exact |
| `test/example/lib/example_web/user_auth.ex` | middleware | request-response | `test/example/lib/example_web/user_auth.ex:174-180,183-245,488-492` | exact |
| `test/example/lib/example_web/live/auth/session_live.ex` | component | request-response | `test/example/lib/example_web/live/auth/session_live.ex:19-29,40-122,149-156` | exact |
| `priv/templates/sigra.install/core/auth.ex` | config/template | request-response | `priv/templates/sigra.install/core/auth.ex:597-613,1110-1113` | exact |
| `priv/templates/sigra.install/core/user_auth.ex` | config/template | request-response | `priv/templates/sigra.install/core/user_auth.ex:164-170,173-243,471-475` | exact |
| `priv/templates/sigra.install/core/session_live.ex` | config/template | request-response | `priv/templates/sigra.install/core/session_live.ex:19-28,39-120,148-155` | exact |
| `test/sigra/templates/session_templates_test.exs` | test | transform | `test/sigra/templates/session_templates_test.exs:104-144,250-276` | role-match |
| `guides/flows/login-and-logout.md`, `guides/flows/account-lifecycle.md` | config/docs | request-response | `guides/flows/login-and-logout.md:97-110`, `guides/flows/account-lifecycle.md:77-107` | exact |

## Pattern Assignments

### `lib/sigra/auth.ex`

**Reuse target:** `delete_all_sessions/3` is the kernel for the new preserve-current primitive.

**Analog:** `lib/sigra/auth.ex:1498-1547`

```elixir
def delete_all_sessions(config, user_id, opts \\ []) do
  {session_store, store_opts} = session_store_and_opts(config, opts)
  sessions = session_store.list_by_user(user_id, store_opts)
  except_token = Keyword.get(opts, :except_token)

  delete_opts =
    if except_token,
      do: Keyword.put(store_opts, :except_token, except_token),
      else: store_opts

  {count, _} = session_store.delete_all_for_user(user_id, delete_opts)

  if pubsub = Keyword.get(opts, :pubsub) do
    sessions
    |> Enum.reject(fn s -> except_token && s.hashed_token == except_token end)
    |> Enum.each(fn session ->
      live_socket_id = "users_sessions:#{Base.url_encode64(session.hashed_token)}"
      Phoenix.PubSub.broadcast(pubsub, live_socket_id, :disconnect)
    end)
  end

  Sigra.Audit.log_safe("session.revoke_all", scope, metadata: %{count: count})
  {count, nil}
end
```

**Reuse strategy**
- Keep session-store delete semantics, PubSub disconnect fanout, and `count` aligned to the actually revoked set.
- Build the new Phase 108 primitive as a thin wrapper around this path rather than re-implementing delete/broadcast logic in LiveView or generated code.
- Preserve the current session by passing an authoritative hashed token, not a UI-computed “other sessions” list.

**Important mismatch**
- Existing audit naming is only `"session.revoke_all"` (`lib/sigra/auth.ex:1528-1545`).
- Phase 108 context requires a distinct semantic if preserve-current becomes a first-class action. Do not reuse `"session.revoke_all"` if the preserved-current path is exposed as its own contract.

**Secondary analog:** `lib/sigra/auth.ex:1454-1484,1571-1573`

```elixir
def revoke_session(config, hashed_token, opts \\ []) do
  delete_session(config, hashed_token, opts)
end
```

Use this naming pattern for thin semantic wrappers over session deletion.

**Related invariant analog:** `lib/sigra/auth.ex:2278-2296`

```elixir
def change_password(config, user, current_password, attrs, opts \\ []) do
  ...
  Sigra.Account.change_password(repo, user, current_password, attrs, merged_opts)
end
```

This is the precedent for “keep current session, kill siblings” already documented in the guides; Phase 108 should expose that same invariant as a direct session-management primitive.

### `lib/sigra/session_stores/ecto.ex`

**Analog:** `lib/sigra/session_stores/ecto.ex:123-158`

```elixir
def list_by_user(user_id, opts) do
  query =
    from(s in schema,
      where: s.user_id == ^user_id,
      order_by: [desc: s.inserted_at]
    )

  repo.all(query)
  |> Enum.map(fn record ->
    session = to_session(record)
    parsed_ua = Sigra.UAParser.parse(record.user_agent)
    %{session | parsed_ua: parsed_ua}
  end)
end

def delete_all_for_user(user_id, opts) do
  except_token = Keyword.get(opts, :except_token)
  query = from(s in schema, where: s.user_id == ^user_id)

  query =
    if except_token do
      from(s in query, where: s.hashed_token != ^except_token)
    else
      query
    end

  repo.delete_all(query)
end
```

**Reuse strategy**
- Keep `:except_token` filtering in the store layer; do not filter sessions in memory and then issue multiple deletes.
- Keep `list_by_user/2` as the source of parsed UA enrichment and ordering for both user and admin surfaces.

**Important mismatch**
- No dedicated store method exists for “revoke others.” The closest pattern is still `delete_all_for_user/2` with `:except_token`.

### `lib/sigra/session.ex`

**Analog:** `lib/sigra/session.ex:20-45,49-86`

```elixir
- `:type` - Session type: `:standard`, `:remember_me`, or `:mfa_pending`
- `:last_active_at` - Last activity timestamp (throttled updates)
- `:sudo_at` - When sudo mode was last activated
- `:active_organization_id` - Active organization the session is currently scoped to.
```

**Reuse strategy**
- Truthful labeling in Phase 108 should only use fields already owned by `Sigra.Session`.
- Safe candidates already present: current session, session type, last activity, sudo freshness, active organization.

**Important mismatch**
- No first-class fields for timeout countdown, device trust, or “security posture” beyond the existing timestamps/types. Phase 108 should use coarse labels or omit unsupported precision.

### `lib/sigra/admin/users/actions.ex`

**Analog:** `lib/sigra/admin/users/actions.ex:9-33`

```elixir
Sigra.Auth.revoke_session(config, hashed_token,
  user_id: user.id,
  actor_id: admin_scope.scope.user.id,
  target_id: user.id,
  effective_user_id: user.id,
  audit_scope: audit_scope(admin_scope)
)

Sigra.Auth.delete_all_sessions(config, user.id,
  user_id: user.id,
  actor_id: admin_scope.scope.user.id,
  target_id: user.id,
  effective_user_id: user.id,
  audit_scope: audit_scope(admin_scope)
)
```

**Reuse strategy**
- Add any admin-facing preserve-current wrapper here first.
- Keep admin audit attribution in this module; do not push actor/target wiring into LiveView handlers.

**Important mismatch**
- There is no admin wrapper for preserve-current revocation yet.

### `lib/sigra/admin/users/detail.ex`

**Analog:** `lib/sigra/admin/users/detail.ex:23-57`

```elixir
sessions = Sigra.Auth.list_sessions(config, user.id)

%{
  sessions: sessions,
  security: %{
    mfa_status: mfa_status,
    passkeys: passkeys,
    passkey_count: length(passkeys)
  },
  danger_zone: %{
    revoke_all_sessions?: sessions != [],
    impersonation_target_label: display_name || user.email
  }
}
```

**Reuse strategy**
- Extend the detail payload here for any admin-facing current-session or truthful state labels.
- Keep `user_show_live` as a renderer of prepared detail maps, not a query layer.

**Important mismatch**
- Current detail payload does not include current-session identity, sudo freshness labels, or timeout posture.

### `lib/sigra/admin/live/user_show_live.ex`

**Behavior analogs**

`lib/sigra/admin/live/user_show_live.ex:38-79`

```elixir
def handle_event("open_revoke_session", %{"token" => encoded_token}, socket) do
  assign(socket, :confirm_action, %{type: :revoke_session, ...})
end

def handle_event("confirm_action", _params, socket) do
  case socket.assigns.confirm_action do
    %{type: :revoke_session, token: token} ->
      :ok = Actions.revoke_session(config, admin_scope, detail.user.id, token)
      ...

    %{type: :revoke_all_sessions} ->
      {_count, nil} = Actions.revoke_all_sessions(config, admin_scope, detail.user.id)
      ...
  end
end
```

`lib/sigra/admin/live/user_show_live.ex:107-149`

```elixir
<button
  :if={@detail.sessions != []}
  type="button"
  phx-click="open_revoke_all_sessions"
>
  Revoke all sessions
</button>

<article :for={session <- @detail.sessions}>
  <p class="font-semibold">{session_label(session)}</p>
  <p>{session.ip || "Unknown IP"}</p>
  <p>{activity_label(session.last_active_at)}</p>
</article>
```

`lib/sigra/admin/live/user_show_live.ex:337-367`

```elixir
defp revoke_all_sessions_copy(detail) do
  "Revoke every active session for #{detail.user.email} in #{detail.scope_label}? This signs them out everywhere."
end

defp session_label(%{type: type}), do: "Session type: " <> to_string(type)
defp activity_label(%DateTime{} = at), do: "Last activity: " <> Calendar.strftime(at, "%Y-%m-%d %H:%M")
```

**Reuse strategy**
- Keep the existing modal-confirmation flow and `Actions` delegation.
- Reuse the helper-label pattern for new truthful badges/rows instead of embedding business logic into HEEx.

**Important mismatch**
- Current admin UI has no current-session badge and no preserve-current bulk action.
- It only exposes session type and last activity as truth labels today. That is the closest analog for new coarse labels such as sudo freshness if Phase 108 decides to render them.

### `test/example/lib/example/accounts.ex`

**Analog:** `test/example/lib/example/accounts.ex:783-805`

```elixir
def list_sessions(user) do
  Sigra.Auth.list_sessions(sigra_config(), user.id)
end

def revoke_session(hashed_token) do
  Sigra.Auth.revoke_session(sigra_config(), hashed_token)
end

def revoke_all_sessions(user, opts \\ []) do
  Sigra.Auth.delete_all_sessions(
    sigra_config(),
    user.id,
    Keyword.put(opts, :pubsub, ExampleWeb.PubSub)
  )
end

def confirm_sudo(hashed_token) do
  Sigra.Auth.confirm_sudo(sigra_config(), hashed_token)
end
```

**Reuse strategy**
- Generated host helpers should stay as thin delegators into `Sigra.Auth`.
- If Phase 108 adds `revoke_other_sessions/2` or similar, mirror it here with the same PubSub injection pattern as `revoke_all_sessions/2`.

**Related precedent:** `test/example/lib/example/accounts.ex:1709-1717`

```elixir
@doc """
Change the user's password, verifying the current password.

All other sessions are invalidated on success.
"""
def change_password(user, current_password, attrs) do
  Sigra.Auth.change_password(sigra_config(), user, current_password, attrs,
    changeset_fn: &User.password_changeset/2
  )
end
```

This docstring is the strongest repo-local precedent for preserve-current semantics.

### `test/example/lib/example_web/user_auth.ex`

**Current-session plumbing analogs**

`test/example/lib/example_web/user_auth.ex:174-180,183-245`

```elixir
def fetch_current_scope(conn, _opts) do
  {user_token, conn} = ensure_user_token(conn)
  {conn, _user, session, scope} = load_current_scope(conn, user_token)

  conn
  |> put_private(:sigra_session, session)
  |> assign(:current_scope, scope)
end
```

`test/example/lib/example_web/user_auth.ex:488-492`

```elixir
defp put_token_in_session(conn, token) do
  conn
  |> put_session(:user_token, token)
  |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
end
```

`test/example/lib/example_web/user_auth.ex:156-167`

```elixir
def log_out_user(conn) do
  user_token = get_session(conn, :user_token)
  user_token && Example.Accounts.delete_user_session_token(user_token)

  if live_socket_id = get_session(conn, :live_socket_id) do
    ExampleWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
  end
  ...
end
```

**Reuse strategy**
- Keep the authoritative current-session token in server state, not LiveView-only assigns.
- Any generated “revoke others” UX that preserves the current session should continue to derive the current token from this auth layer.

**Important mismatch**
- The current helper exposes the current token to LiveView indirectly; there is no explicit generated helper yet for “revoke all except this session.”

### `test/example/lib/example_web/live/auth/session_live.ex`

**Analog:** `test/example/lib/example_web/live/auth/session_live.ex:19-29,40-122,149-156`

```elixir
def mount(_params, _session, socket) do
  user = socket.assigns.current_scope.user
  sessions = Auth.list_sessions(user)
  current_token = get_connect_params(socket)["_sigra_token"]
  {:ok, assign(socket, sessions: sessions, current_token: current_token, ...)}
end

<span :if={current_session?(session, @current_token)}>This device</span>

<%= if current_session?(session, @current_token) do %>
  <.button phx-click="revoke_current" ...>
<% else %>
  <.button phx-click="revoke" ...>
<% end %>

<.button
  :if={length(@sessions) > 1}
  phx-click="revoke_all"
  data-confirm="This will end all sessions including your current one. You will be logged out."
>
  Log out of all devices
</.button>
```

```elixir
defp current_session?(%{hashed_token: token}, current_token) when is_binary(current_token) do
  case Base.url_decode64(current_token) do
    {:ok, decoded} -> token == decoded
    :error -> false
  end
end
```

**Reuse strategy**
- Keep `current_session?/2` as the analog for current-session labeling.
- Replace the existing destructive bulk-action semantics with a dedicated preserve-current action rather than teaching the UI to compute siblings on its own.
- Keep the current special-case handling split: current-session action redirects/logout, sibling-session action refreshes the list.

**Important mismatch**
- Existing bulk control is explicitly “including your current one.”
- Existing truth labels stop at “This device” and relative activity. No sudo/timeout/security-posture labels are currently rendered here.

### `priv/templates/sigra.install/core/auth.ex`

**Analog:** `priv/templates/sigra.install/core/auth.ex:597-613,1110-1113`

```elixir
def revoke_all_sessions(user, opts \\ []) do
  Sigra.Auth.delete_all_sessions(sigra_config(), user.id, Keyword.put(opts, :pubsub, <%= web_module %>.PubSub))
end

def confirm_sudo(hashed_token) do
  Sigra.Auth.confirm_sudo(sigra_config(), hashed_token)
end
```

```elixir
def change_password(user, current_password, attrs) do
  Sigra.Auth.change_password(sigra_config(), user, current_password, attrs,
    changeset_fn: &<%= schema_alias %>.password_changeset/3
  )
end
```

**Reuse strategy**
- Mirror any new example-app session helper here with the same thin delegation shape.
- Keep generator/template parity exact; Phase 108 should not update example code without updating this file.

### `priv/templates/sigra.install/core/user_auth.ex`

**Analog:** `priv/templates/sigra.install/core/user_auth.ex:164-170,173-229,471-475`

```elixir
def fetch_current_scope(conn, _opts) do
  {user_token, conn} = ensure_user_token(conn)
  {conn, _user, session, scope} = load_current_scope(conn, user_token)

  conn
  |> put_private(:sigra_session, session)
  |> assign(:current_scope, scope)
end

defp put_token_in_session(conn, token) do
  conn
  |> put_session(:user_token, token)
  |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
end
```

**Reuse strategy**
- Keep this in lockstep with the example app whenever session-token plumbing changes.

### `priv/templates/sigra.install/core/session_live.ex`

**Analog:** `priv/templates/sigra.install/core/session_live.ex:19-28,39-120,148-155`

This file is the template parity copy of the example LiveView. Phase 108 changes to the user session UI should be authored against the example file, then mirrored here line-for-line in template form.

**Important mismatch**
- Same destructive bulk action wording as the example file; this is the exact template surface that must change when the preserve-current action is introduced.

### `test/sigra/templates/session_templates_test.exs`

**Analog:** `test/sigra/templates/session_templates_test.exs:104-144,250-276`

```elixir
test "contains revoke_all_sessions function", %{content: content} do
  assert content =~ "def revoke_all_sessions("
end

test "delegates to Sigra.Auth library functions", %{content: content} do
  assert content =~ "Sigra.Auth.list_sessions"
  assert content =~ "Sigra.Auth.revoke_session"
  assert content =~ "Sigra.Auth.delete_all_sessions"
  assert content =~ "Sigra.Auth.confirm_sudo"
end
```

**Reuse strategy**
- Extend template tests by asserting the new helper/action names and any updated user-facing strings in the template files.
- Keep these tests at the raw-template level; they are the existing parity guard.

**Important mismatch**
- There is no current template test coverage for `session_live.ex` action copy or current-session badges. If Phase 108 changes those strings, add assertions here.

### `guides/flows/login-and-logout.md` and `guides/flows/account-lifecycle.md`

**Analogs**

`guides/flows/login-and-logout.md:97-110`

```markdown
## Log out everywhere
...
Accounts.delete_all_user_session_tokens(user)
...
`delete_all_user_session_tokens/1` issues a single `delete_all` ...
Every session — on every device — is invalidated.
```

`guides/flows/account-lifecycle.md:77-107`

```markdown
`change_password/5` uses `Ecto.Multi` to atomically update the password and delete every session **except the current one**.
The user stays logged in on the current device but is logged out everywhere else.
...
The session row's `sudo_at` field is set to `DateTime.utc_now()`
```

**Reuse strategy**
- Update docs by contrasting “log out everywhere” with the new preserve-current control.
- Reuse the account-lifecycle wording as the truthful description for Phase 108 semantics.

## Shared Patterns

### Preserve-current revocation kernel

**Sources:** `lib/sigra/auth.ex:1502-1524`, `lib/sigra/session_stores/ecto.ex:143-157`

```elixir
sessions = session_store.list_by_user(user_id, store_opts)
except_token = Keyword.get(opts, :except_token)
{count, _} = session_store.delete_all_for_user(user_id, delete_opts)

sessions
|> Enum.reject(fn s -> except_token && s.hashed_token == except_token end)
|> Enum.each(fn session ->
  live_socket_id = "users_sessions:#{Base.url_encode64(session.hashed_token)}"
  Phoenix.PubSub.broadcast(pubsub, live_socket_id, :disconnect)
end)
```

Apply to:
- `lib/sigra/auth.ex`
- `test/example/lib/example/accounts.ex`
- `priv/templates/sigra.install/core/auth.ex`

Rule:
- Library computes revoked set from persisted sessions plus `except_token`.
- UI must not decide which rows count as “other sessions.”

### Current-session identification

**Sources:** `test/example/lib/example_web/user_auth.ex:488-492`, `test/example/lib/example_web/live/auth/session_live.ex:22,149-156`

```elixir
put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
current_token = get_connect_params(socket)["_sigra_token"]
```

Apply to:
- user-facing LiveView session controls
- any generated surface that needs to mark “This device”

Rule:
- Compare the authoritative current token against stored `hashed_token`.
- Reuse the existing base64 token transport pattern instead of inferring “current” from list order.

### Truthful state-labeling

**Sources:** `lib/sigra/admin/live/user_show_live.ex:350-367`, `lib/sigra/session.ex:33-45`, `lib/sigra/plug/require_sudo.ex:77-84`, `lib/sigra/plug/fetch_session.ex:137-159`

```elixir
defp session_label(%{type: type}), do: "Session type: " <> to_string(type)
defp activity_label(%DateTime{} = at), do: "Last activity: " <> ...
DateTime.diff(DateTime.utc_now(), sudo_at, :second) <= sudo_window
absolute_ok and idle_ok
```

Apply to:
- `lib/sigra/admin/users/detail.ex`
- `lib/sigra/admin/live/user_show_live.ex`
- `test/example/lib/example_web/live/auth/session_live.ex`
- `priv/templates/sigra.install/core/session_live.ex`

Rule:
- Only render labels backed by existing `Sigra.Session` fields or request-time rules already in library code.
- Prefer coarse labels like “Sudo active” / “Sudo expired” or “Remember me session” over fake timeout countdowns.

### Thin-host generated wrappers

**Sources:** `test/example/lib/example/accounts.ex:783-805`, `priv/templates/sigra.install/core/auth.ex:597-613`

Rule:
- Example and template auth contexts should delegate to `Sigra.Auth` with minimal shaping and PubSub injection.
- New preserve-current helpers belong here, not in LiveView event handlers.

### Template parity enforcement

**Sources:** `priv/templates/sigra.install/core/session_live.ex`, `priv/templates/sigra.install/core/user_auth.ex`, `priv/templates/sigra.install/core/auth.ex`, `test/sigra/templates/session_templates_test.exs:104-144,250-276`

Rule:
- Change example app first, then mirror the same semantics in template files, then extend raw-template tests.

## No Exact Analog Found

| File / Concern | Role | Data Flow | Reason |
|---|---|---|---|
| dedicated `Sigra.Auth` preserve-current action name and audit event | service | request-response | closest code is `delete_all_sessions/3` with `:except_token`, but there is no first-class “revoke others” API or audit action yet |
| admin current-session labeling source | component/service | request-response | user-facing surface has `_sigra_token` connect-param plumbing; admin detail surface has no equivalent authoritative token source today |

## Implementation Notes For Planner

- Prefer a new library-owned helper that wraps `delete_all_sessions/3` with `:except_token` and returns truthful outcome data, instead of teaching generated code to call `delete_all_sessions/3` directly with custom messaging.
- If Phase 108 renders sudo or timeout posture, anchor the labels to `session.sudo_at`, `session.type`, and existing timeout rules in `Sigra.Plug.FetchSession`; do not invent per-second countdowns.
- Preserve current-session continuity as an invariant across user-facing flows, docs, and audit semantics. The closest existing wording is the password-change flow in `guides/flows/account-lifecycle.md:77-107`.
- Keep repo-local parity tight: example app, install templates, template tests, and guides all need coordinated updates.

## Metadata

**Analog search scope:** `lib/sigra`, `test/example/lib/example`, `priv/templates/sigra.install/core`, `test/sigra/templates`, `guides/flows`
**Pattern extraction date:** 2026-05-07
