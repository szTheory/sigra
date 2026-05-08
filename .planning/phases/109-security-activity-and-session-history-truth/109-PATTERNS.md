# Phase 109: Security activity and session history truth - Pattern Map

**Mapped:** 2026-05-08
**Authoritative scope:** `.planning/phases/109-security-activity-and-session-history-truth/109-CONTEXT.md`
**Files classified:** 11
**Analogs found:** 11 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/security_activity.ex` | service | transform | `lib/sigra/admin/users/detail.ex:64-105`, `lib/sigra/admin/audit/query.ex:17-37`, `lib/sigra/admin/audit/presenter.ex:6-48` | role-match |
| `lib/sigra/admin/audit/presenter.ex` | service | transform | `lib/sigra/admin/audit/presenter.ex:11-48` | exact |
| `lib/sigra/auth.ex` | service | request-response | `lib/sigra/auth.ex:1338-1378,1454-1588,1631-1665` | exact |
| `lib/sigra/suspicious_login.ex` | service | event-driven | `lib/sigra/suspicious_login.ex:31-91` | exact |
| `lib/sigra/admin/users/detail.ex` | service | transform | `lib/sigra/admin/users/detail.ex:15-61,64-105` | exact |
| `lib/sigra/admin/live/user_show_live.ex` | component | request-response | `lib/sigra/admin/live/user_show_live.ex:25-39,204-228` | exact |
| `test/example/lib/example/accounts.ex` | service | request-response | `test/example/lib/example/accounts.ex:783-821` | exact |
| `test/example/lib/example_web/live/auth/session_live.ex` | component | request-response | `test/example/lib/example_web/live/auth/session_live.ex:19-30,32-139` | exact |
| `priv/templates/sigra.install/core/auth.ex` | config/template | request-response | `priv/templates/sigra.install/core/auth.ex:596-630` | exact |
| `priv/templates/sigra.install/core/session_live.ex` | config/template | request-response | `priv/templates/sigra.install/core/session_live.ex:19-138` | exact |
| `test/sigra/templates/session_templates_test.exs`, `test/example/test/example_web/live/auth/session_live_test.exs`, `test/example/test/example_web/live/admin_user_show_live_test.exs`, `test/example/test/example_web/live/admin_audit_user_live_test.exs` | test | request-response | cited per section below | exact |

## Pattern Assignments

### `lib/sigra/security_activity.ex` (service, transform)

**Primary analogs:** `lib/sigra/admin/users/detail.ex:64-105`, `lib/sigra/admin/audit/query.ex:17-37`, `lib/sigra/admin/audit/presenter.ex:6-48`

**Query-builder reuse** (`lib/sigra/admin/users/detail.ex:85-103`, `lib/sigra/admin/audit/query.ex:17-37`):
```elixir
filters =
  [subject_user_id: user_id]
  |> maybe_put_audit_scope(admin_scope)

events =
  audit_schema
  |> Sigra.Admin.Audit.Query.build(filters)
  |> order_by([event], desc: event.inserted_at, desc: event.id)
  |> limit(^@audit_preview_limit)
  |> config.repo.all()
```

```elixir
def build(audit_schema, filters \\ []) do
  {subject_user_id, base_filters} = Keyword.pop(filters, @subject_filter)

  audit_schema
  |> AuditQuery.build(base_filters)
  |> maybe_filter_subject_user(subject_user_id)
end
```

**Presenter reuse** (`lib/sigra/admin/audit/presenter.ex:20-35`):
```elixir
%{
  id: event.id,
  inserted_at: event.inserted_at,
  action: event.action,
  action_label: action_label(event.action),
  action_badge: if(impersonation?, do: "Impersonation", else: nil),
  actor_label: user_label(actor, event.actor_id),
  effective_user_label: user_label(effective_user, event.effective_user_id),
  actor_summary:
    if(impersonation?,
      do:
        "#{user_label(actor, event.actor_id)} acting as #{user_label(effective_user, event.effective_user_id)}",
      else: user_label(actor, event.actor_id)
    ),
  outcome: event.outcome || "success"
}
```

**Pattern to copy**
- Keep Phase 109’s new seam library-owned and query/presenter-based.
- Return prepared rows to hosts; do not let LiveViews or generated `Accounts` query raw audit rows directly.
- Preserve deterministic ordering with `desc: inserted_at, desc: id`.

**Important seam**
- `Sigra.Admin.Audit.Presenter.action_label/1` currently falls back to generic title-casing (`lib/sigra/admin/audit/presenter.ex:43-48`). If Phase 109 needs stable user-facing labels for `session.revoke_others`, `security.suspicious_login`, or future lifecycle events, add explicit presenter clauses instead of relying on fallback formatting.

### `lib/sigra/admin/audit/presenter.ex` (service, transform)

**Analog:** `lib/sigra/admin/audit/presenter.ex:11-48`

**Core mapping pattern:**
```elixir
impersonation? =
  String.starts_with?(event.action, "admin.impersonation.") or
    (is_binary(event.actor_id) and is_binary(event.effective_user_id) and
       event.actor_id != event.effective_user_id)
```

```elixir
defp action_label("admin.impersonation.start"), do: "Impersonation started"
defp action_label("admin.impersonation.stop"), do: "Impersonation ended"
defp action_label("admin.impersonation.timeout"), do: "Impersonation timed out"
defp action_label("admin.impersonation.denied"), do: "Impersonation denied"
```

**Pattern to copy**
- Put normalization rules here first when admin preview and user security activity must stay aligned.
- Keep the row shape bounded; add fields centrally rather than per surface.

**Anti-pattern to avoid**
- Do not invent a second user-only presenter with different labels for the same raw actions unless the row schema is intentionally separate. The existing recent-audit preview contract in `Detail.recent_audit_preview/3` already forbids renderer-specific fields.

### `lib/sigra/auth.ex` (service, request-response)

**Analogs:** `lib/sigra/auth.ex:1338-1378`, `lib/sigra/auth.ex:1454-1588`, `lib/sigra/auth.ex:1631-1665`

**Session-create audit emission** (`lib/sigra/auth.ex:1357-1378`):
```elixir
scope =
  case config.scope_module do
    nil -> nil
    mod -> Sigra.Scope.build(mod, user, active_organization: active_org)
  end

Sigra.Audit.log_safe(
  "session.create",
  scope,
  Keyword.merge(audit_opts,
    actor_id: user.id,
    metadata: %{type: Map.get(metadata, :type, :standard), session_id: final_session.id}
  )
)
```

**Shared lifecycle writer** (`lib/sigra/auth.ex:1539-1588`):
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

Sigra.Audit.log_safe(
  Keyword.fetch!(runtime_opts, :audit_action),
  scope,
  Keyword.merge(audit_opts,
    actor_id: actor_id,
    target_id: target_id,
    effective_user_id: effective_user_id,
    metadata: %{count: count}
  )
)
```

**Sudo outcome split** (`lib/sigra/auth.ex:1639-1663`):
```elixir
action =
  case result do
    :ok -> "session.sudo_enter"
    {:ok, _} -> "session.sudo_enter"
    _ -> "session.sudo_expire"
  end
```

**Pattern to copy**
- If Phase 109 discovers missing persisted activity needed for an honest feed, emit it in `Sigra.Auth`, not in the UI layer.
- Follow the existing pattern: compute authoritative scope, write audit once, and keep metadata bounded to fields Sigra already owns.

### `lib/sigra/suspicious_login.ex` (service, event-driven)

**Analog:** `lib/sigra/suspicious_login.ex:45-91`

```elixir
details = %{
  ip: login_ip,
  geo_city: geo[:city],
  geo_country_code: geo[:country_code]
}

Sigra.Audit.log_safe(
  "security.suspicious_login",
  Sigra.Scope.from_config(config, %{id: user_id}),
  repo: config.repo,
  audit_schema: Keyword.get(audit_config, :audit_schema),
  actor_id: user_id,
  outcome: "failure",
  ip_address: login_ip,
  metadata: %{geo_city: geo[:city], geo_country_code: geo[:country_code]}
)
```

**Pattern to copy**
- Reuse the existing suspicious-login audit row as user-visible activity truth.
- Preserve the current semantics: it is a detection outcome with bounded geo/IP metadata, not a new fraud-scoring model.

### `lib/sigra/admin/users/detail.ex` (service, transform)

**Analog:** `lib/sigra/admin/users/detail.ex:15-61,64-105,251-259`

**Prepared-detail pattern:**
```elixir
raw_sessions = Sigra.Auth.list_sessions(config, user.id)
current_session_hashed_token = current_session_hashed_token(user, admin_scope, raw_sessions, opts)
sessions = Enum.map(raw_sessions, &present_session(&1, current_session_hashed_token))
recent_audit = recent_audit_preview(config, admin_scope, user.id)
```

**Preview contract:**
```elixir
Preview renderers MUST NOT introduce fields outside this set ...
If a new preview field is needed, add it to
`Sigra.Admin.Audit.Presenter` first so the preview and the full explorer stay
coherent.
```

**Session presentation pattern** (`lib/sigra/admin/users/detail.ex:251-259`):
```elixir
%{
  id: session.id,
  hashed_token: session.hashed_token,
  ip: session.ip,
  current?: is_binary(current_session_hashed_token) and session.hashed_token == current_session_hashed_token,
  type_label: "Session type: #{session.type}",
  last_activity_label: activity_label(session.last_active_at),
  sudo_label: sudo_label(session.sudo_at)
}
```

**Pattern to copy**
- Keep `Detail`-style modules as loaders/presenters that hand LiveViews fully shaped data.
- A new user-facing security-activity loader should follow this structure: load raw truth, normalize centrally, return render-ready rows.

### `lib/sigra/admin/live/user_show_live.ex` (component, request-response)

**Analog:** `lib/sigra/admin/live/user_show_live.ex:25-39,204-228`

```elixir
detail =
  Detail.load!(socket.assigns.sigra_config, admin_scope, user_id,
    current_user_token: socket.assigns.current_user_token
  )
```

```heex
<section class="rounded-lg border border-base-300 bg-base-100 p-5">
  <div class="flex flex-wrap items-start justify-between gap-3">
    <div>
      <h2 class="text-xl font-semibold">Recent Audit</h2>
      <p class="mt-1 text-sm text-base-content/70">
        Recent activity stays aligned with the full scoped audit history for this user.
      </p>
    </div>

    <a class="btn btn-outline min-h-11" href={full_audit_path(@admin_scope, @detail.user.id, @return_to)}>
      View full audit
    </a>
  </div>

  <div class="mt-4 space-y-2 text-sm">
    <div :for={row <- @detail.recent_audit} class="rounded-md border border-base-300 bg-base-200 p-3">
      <span :if={row.action_badge} class="badge badge-warning badge-sm">{row.action_badge}</span>
      <p class="font-semibold">{row.action_label}</p>
      <p class="text-sm text-base-content/70">{row.actor_summary}</p>
      <p class="text-xs text-base-content/60">{Calendar.strftime(row.inserted_at, "%Y-%m-%d %H:%M")}</p>
    </div>
  </div>
</section>
```

**Pattern to copy**
- Keep LiveView thin: load prepared data in `handle_params/3`, render row fields directly, link to a deeper scoped surface where needed.
- For Phase 109’s user-facing feed, copy the section structure and row rendering discipline, not the admin-specific copy or route.

### `test/example/lib/example/accounts.ex` (service, request-response)

**Analog:** `test/example/lib/example/accounts.ex:783-821`

```elixir
def list_sessions(user) do
  Sigra.Auth.list_sessions(sigra_config(), user.id)
end

def revoke_other_sessions(user, current_hashed_token, opts \\ []) do
  Sigra.Auth.revoke_other_sessions(
    sigra_config(),
    user.id,
    opts
    |> Keyword.put(:current_hashed_token, current_hashed_token)
    |> Keyword.put(:pubsub, ExampleWeb.PubSub)
  )
end
```

**Pattern to copy**
- Add the generated-host security-activity API here as a thin delegation layer over the Sigra library seam.
- Do not duplicate query logic, presenter logic, or audit semantics in the generated app context.

### `test/example/lib/example_web/live/auth/session_live.ex` (component, request-response)

**Analog:** `test/example/lib/example_web/live/auth/session_live.ex:19-30,32-139`

**Mount + assign pattern:**
```elixir
user = socket.assigns.current_scope.user
sessions = Auth.list_sessions(user)
current_hashed_token = current_session_hashed_token(session)

{:ok,
 assign(socket,
   sessions: sessions,
   current_hashed_token: current_hashed_token,
   page_title: "Active Sessions"
 )}
```

**Event-refresh pattern:**
```elixir
case Auth.revoke_other_sessions(user, socket.assigns.current_hashed_token) do
  {:ok, count} ->
    sessions = Auth.list_sessions(user)
    {:noreply, socket |> put_flash(:info, message) |> assign(sessions: sessions)}
```

**Pattern to copy**
- Extend this page with a second prepared collection such as `security_activity`, loaded through `Accounts`, then refreshed after relevant actions.
- Keep the host page presentational and event-driven; no direct audit queries, no raw action-string interpretation.

### `priv/templates/sigra.install/core/auth.ex` and `priv/templates/sigra.install/core/session_live.ex` (config/template, request-response)

**Analogs:** `priv/templates/sigra.install/core/auth.ex:596-630`, `priv/templates/sigra.install/core/session_live.ex:19-138`

```elixir
def revoke_other_sessions(user, current_hashed_token, opts \\ []) do
  Sigra.Auth.revoke_other_sessions(
    sigra_config(),
    user.id,
    opts
    |> Keyword.put(:current_hashed_token, current_hashed_token)
    |> Keyword.put(:pubsub, <%= web_module %>.PubSub)
  )
end
```

```elixir
def mount(_params, session, socket) do
  user = socket.assigns.current_scope.user
  sessions = Auth.list_sessions(user)
  current_hashed_token = current_session_hashed_token(session)

  {:ok, assign(socket,
    sessions: sessions,
    current_hashed_token: current_hashed_token,
    page_title: "Active Sessions"
  )}
end
```

**Pattern to copy**
- Any new generated-host API or UI for security activity must be added to both example code and install templates in the same shape.
- Preserve the generator’s thin-wrapper contract: templates call Sigra library functions, not raw repo/audit code.

### Tests (test, request-response)

**Parity enforcement analogs**

`test/sigra/templates/session_templates_test.exs:104-147`
```elixir
test "contains revoke_other_sessions function", %{content: content} do
  assert content =~ "def revoke_other_sessions("
end

test "delegates to Sigra.Auth library functions", %{content: content} do
  assert content =~ "Sigra.Auth.list_sessions"
  assert content =~ "Sigra.Auth.revoke_session"
  assert content =~ "Sigra.Auth.revoke_other_sessions"
  assert content =~ "Sigra.Auth.confirm_sudo"
end
```

`test/example/test/example_web/live/auth/session_live_test.exs:21-64`
```elixir
{:ok, view, html} = live(conn, "/users/sessions")
assert html =~ "This device"
assert html =~ "Log out of other devices"
html = render_click(view, :revoke_others, %{})
assert html =~ "Logged out of 1 other session."
```

`test/example/test/example_web/live/admin_user_show_live_test.exs:190-268`
```elixir
assert html =~ "Recent Audit"
assert html =~ "Session Create"
assert html =~ "Session Revoke_all"
refute html =~ ~r/<p class="font-semibold">session\.(create|revoke_all)</
assert html =~ "View full audit"
```

`test/example/test/example_web/live/admin_audit_user_live_test.exs:32-90`
```elixir
html =
  conn
  |> log_in_user(platform_admin)
  |> get("/admin/users/#{subject.id}/audit?action_prefix=session&page_size=1...")
  |> html_response(200)

assert html =~ "session.create"
assert html =~ "session.revoke_all"
```

**Pattern to copy**
- Add example-app LiveView assertions for the new user-facing feed.
- Add template tests that prove the installer still emits the new API and page markup.
- Keep admin preview/explorer tests aligned if presenter labels change, because those surfaces are the canonical overlap check.

## Shared Patterns

### Audit Query Reuse
**Source:** `lib/sigra/admin/audit/query.ex:17-37`, `lib/sigra/audit/query.ex:102-123`
**Apply to:** Any new security-activity query module, admin preview, and future pagination
```elixir
audit_schema
|> AuditQuery.build(base_filters)
|> maybe_filter_subject_user(subject_user_id)
```

```elixir
query
|> order_by([e], desc: e.inserted_at, desc: e.id)
|> limit(^(limit + 1))
```

Use the existing `(inserted_at, id)` ordering discipline everywhere. Do not introduce a feed-specific ordering rule.

### Presenter-Owned Labels
**Source:** `lib/sigra/admin/audit/presenter.ex:20-48`
**Apply to:** Admin preview, full explorer, user-facing security activity
```elixir
action_label: action_label(event.action),
outcome: event.outcome || "success"
```

Normalize labels centrally. If the row copy must differ, add explicit presenter clauses instead of rendering raw actions or ad hoc string transforms in HEEx.

### Persisted Security Truth Only
**Source:** `lib/sigra/suspicious_login.ex:64-89`, `lib/sigra/auth.ex:1369-1375`, `lib/sigra/auth.ex:1577-1585`, `lib/sigra/auth.ex:1655-1663`
**Apply to:** New activity types surfaced in Phase 109
```elixir
Sigra.Audit.log_safe("security.suspicious_login", ...)
Sigra.Audit.log_safe("session.create", ...)
Sigra.Audit.log_safe(Keyword.fetch!(runtime_opts, :audit_action), ...)
Sigra.Audit.log_safe(action, ...)
```

If a user-visible event is not already persisted with enough fidelity, add the library audit emission first.

### Thin Generated Hosts
**Source:** `test/example/lib/example/accounts.ex:783-821`, `test/example/lib/example_web/live/auth/session_live.ex:19-30,117-138`
**Apply to:** Example app and install templates
```elixir
def list_sessions(user) do
  Sigra.Auth.list_sessions(sigra_config(), user.id)
end
```

```elixir
case Auth.revoke_other_sessions(user, socket.assigns.current_hashed_token) do
  {:ok, count} -> ...
end
```

Keep generated code as delegators plus renderers. No raw repo access, no duplicate interpretation layer.

## Important Seams And Anti-Patterns

- `Sigra.Admin.Users.Detail.recent_audit_preview/3` is the strongest exact analog for a bounded feed. Reuse its query + user preload + presenter pipeline before creating anything new.
- `Sigra.Admin.Audit.Presenter.action_label/1` fallback (`String.replace` + `String.capitalize`) is acceptable for internal admin labels but weak for a user-facing security feed. Prefer explicit clauses for overlapping security actions.
- `Sigra.Admin.Live.UserShowLive` proves the correct split: `Detail` prepares rows, LiveView only renders them. Do not move audit semantics into the generated `SessionLive`.
- `Example.Accounts` and template `auth.ex` must stay in lockstep. Any new helper added to one without the other is a generator parity regression.
- `ExampleWeb.Auth.SessionLive` currently reloads `sessions` after mutation but nothing else. If Phase 109 shows activity on the same page, refresh the activity collection in the same event handlers so the surface reflects newly written audit truth immediately.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| None | - | - | Phase 109 has strong partial and exact analogs already; the missing piece is composing them into a user-facing library seam. |

## Metadata

**Analog search scope:** `lib/sigra/admin/**`, `lib/sigra/**`, `test/example/lib/**`, `priv/templates/sigra.install/core/**`, `test/example/test/**`, `test/sigra/templates/**`
**Files scanned:** 16
**Pattern extraction date:** 2026-05-08
