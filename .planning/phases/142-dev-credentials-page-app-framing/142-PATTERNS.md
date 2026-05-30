# Phase 142: dev-credentials-page-app-framing - Pattern Map

**Mapped:** 2026-05-30
**Files analyzed:** 6 (2 new, 4 edited)
**Analogs found:** 6 / 6

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `test/example/lib/example_web/live/demo/credentials_live.ex` | LiveView (read-only) | request-response | `test/example/lib/example_web/live/organization_settings_live.ex` | exact |
| `test/example/test/example_web/live/demo/credentials_live_test.exs` | test | request-response | `test/example/test/example_web/live/admin_user_index_live_test.exs` | exact |
| `test/example/lib/example_web/router.ex` (edit `:172-177`) | router | request-response | self — existing `/dev/mailbox` block at `:172-177` | exact |
| `test/example/lib/example_web/components/layouts.ex` (edit `:48-52`, `:60-72`) | layout component | request-response | self — existing brand `<a>` and nav `<ul>` | exact |
| `test/example/lib/example_web/components/layouts/root.html.heex` (edit `:7`) | layout template | request-response | self — existing `<.live_title>` at `:7` | exact |
| `test/example/lib/example/demo/seeds.ex` (edit `run/0`) | data utility | batch | self — existing `Personas.all()` iteration at `:63` | exact |

---

## Pattern Assignments

### `test/example/lib/example_web/live/demo/credentials_live.ex` (LiveView, request-response)

**Analog:** `test/example/lib/example_web/live/organization_settings_live.ex`

**Imports pattern** (lines 26-28):
```elixir
use ExampleWeb, :live_view

alias Example.Demo.Personas
```
No `import Phoenix.LiveViewTest` — that belongs in the test file only. The `:live_view` macro (confirmed `example_web.ex:51-57`) calls `use Phoenix.LiveView` and `html_helpers()` but sets NO default layout — explicit wrap is mandatory.

**Mount pattern** (lines 31-51, adapted for CredentialsLive):
```elixir
@impl true
def mount(_params, _session, socket) do
  credentials =
    Personas.all()
    |> Enum.map(fn p ->
      local = p.email |> String.split("@") |> hd()
      Map.merge(p, %{local: local, feature: feature_map()[local]})
    end)

  {:ok, assign(socket, page_title: "Demo Credentials", credentials: credentials)}
end
```
Note: `organization_settings_live.ex` assigns `page_title` via `assign(:page_title, ...)` individually. CredentialsLive uses a single `assign/2` call with keyword list — both are idiomatic. No auth assigns needed (`current_scope` will be nil for unauthenticated route; `Layouts.app` defaults `current_scope: nil`).

**Explicit layout wrap pattern** (lines 55-61 — the critical reference):
```elixir
@impl true
def render(assigns) do
  ~H"""
  <Layouts.app
    flash={@flash}
    current_scope={@current_scope}
    user_organizations={@user_organizations}
  >
```
For CredentialsLive the `current_scope` and `user_organizations` optional attrs MAY be omitted (both have safe defaults in `layouts.ex`: `default: nil` and `default: []`). The `flash={@flash}` is **required** — `layouts.ex:32` declares `attr :flash, :map, required: true`. Omitting it raises a compile-time `Phoenix.Component` error.

Minimal correct form for CredentialsLive:
```elixir
<Layouts.app flash={@flash}>
```

**Inner layout wrapper pattern** (lines 62-63):
```elixir
<div class="mx-auto max-w-2xl">
  <.header>
```
Note: `Layouts.app` already wraps `<main class="px-4 py-20 sm:px-6 lg:px-8"><div class="mx-auto max-w-2xl space-y-4">` (layouts.ex:78-80). The `organization_settings_live.ex:62` adds a redundant `max-w-2xl` inside — for CredentialsLive omit the inner wrapper div and put content directly since the outer `main` already provides it.

**Header component pattern** (lines 63-66):
```elixir
<.header>
  Organization settings
  <:subtitle>{@org.name}</:subtitle>
</.header>
```
For CredentialsLive, reuse `<.header>` (no subtitle needed). The header CoreComponent renders `text-lg font-semibold leading-8` (core_components.ex:317). Place the DEV ONLY badge in the `:actions` slot or adjacent to the heading text.

**feature_map/0 private function** — define as a private function in CredentialsLive, then expose as a public function that `Seeds.run/0` can call, OR define in a shared module. Either satisfies D-02 (single source). Recommended: define in `CredentialsLive` as a module-level private function and alias it from `Seeds.run/0` by calling `ExampleWeb.Demo.CredentialsLive.feature_map()` after making it `def` (not `defp`). Alternatively — cleaner — define in `Example.Demo.Personas` as `feature_map/0`.

Feature map content (verbatim from UI-SPEC copywriting table):
```elixir
defp feature_map do
  %{
    "admin" => "Admin — TOTP MFA, passkey display row, multi-org owner, rich audit trail",
    "alice" => "Standard confirmed user — happy path login, Acme Corp member",
    "bob"   => "TOTP MFA enrolled — org owner (Beta Labs)",
    "carol" => "OAuth identity — GitHub-linked login (carol@demo.sigra.dev)",
    "dave"  => "Locked account — failed login attempts exhausted, unconfirmed",
    "frank" => "Scheduled deletion — account marked for deletion"
  }
end
```

**Hand-rolled table pattern** (D-05 — confirmed: core_components.ex:361-388 has NO testid passthrough on `<table>` or `<tr>`):
```heex
<table class="table table-zebra" data-testid="demo-credentials-table">
  <thead>
    <tr>
      <th>Persona</th>
      <th>Email</th>
      <th>Password</th>
      <th>Auth Feature Demonstrated</th>
    </tr>
  </thead>
  <tbody>
    <tr :for={c <- @credentials} data-testid={"demo-persona-row-#{c.local}"}>
      <td>{c.display_name}</td>
      <td>{c.email}</td>
      <td><code class="font-mono text-sm">{c.password}</code></td>
      <td>{c.feature}</td>
    </tr>
  </tbody>
</table>
```
Local part derivation (D-03): `local = p.email |> String.split("@") |> hd()`. Personas: admin, alice, bob, carol, dave, frank — all single-word, safe for testid use.

**DEV ONLY badge pattern** (D-06, D-07):
```heex
<span class="badge badge-warning badge-sm" data-testid="demo-dev-only-badge">DEV ONLY</span>
```
daisyUI `badge badge-warning badge-sm` is the standard across `admin_shell.ex` and `core_components.ex`. Adjacent disclaimer text: `"This page is only available in development mode."` (UI-SPEC copywriting table).

**Full module skeleton:**
```elixir
defmodule ExampleWeb.Demo.CredentialsLive do
  use ExampleWeb, :live_view

  alias Example.Demo.Personas
  alias ExampleWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    credentials =
      Personas.all()
      |> Enum.map(fn p ->
        local = p.email |> String.split("@") |> hd()
        Map.merge(p, %{local: local, feature: feature_map()[local]})
      end)

    {:ok, assign(socket, page_title: "Demo Credentials", credentials: credentials)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Demo Credentials
        <:actions>
          <span class="badge badge-warning badge-sm" data-testid="demo-dev-only-badge">
            DEV ONLY
          </span>
        </:actions>
      </.header>
      <p class="text-sm text-base-content/60">
        This page is only available in development mode.
      </p>
      <table class="table table-zebra" data-testid="demo-credentials-table">
        <thead>
          <tr>
            <th>Persona</th>
            <th>Email</th>
            <th>Password</th>
            <th>Auth Feature Demonstrated</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={c <- @credentials} data-testid={"demo-persona-row-#{c.local}"}>
            <td>{c.display_name}</td>
            <td>{c.email}</td>
            <td><code class="font-mono text-sm">{c.password}</code></td>
            <td>{c.feature}</td>
          </tr>
        </tbody>
      </table>
      <p class="text-xs text-base-content/60">
        Passwords are public-by-design demo credentials. Never use in production.
      </p>
    </Layouts.app>
    """
  end

  @doc false
  def feature_map do
    %{
      "admin" => "Admin — TOTP MFA, passkey display row, multi-org owner, rich audit trail",
      "alice" => "Standard confirmed user — happy path login, Acme Corp member",
      "bob"   => "TOTP MFA enrolled — org owner (Beta Labs)",
      "carol" => "OAuth identity — GitHub-linked login (carol@demo.sigra.dev)",
      "dave"  => "Locked account — failed login attempts exhausted, unconfirmed",
      "frank" => "Scheduled deletion — account marked for deletion"
    }
  end
end
```
`feature_map/0` is `def` (public) so `Seeds.run/0` can call `ExampleWeb.Demo.CredentialsLive.feature_map()` — satisfying D-02 without a third shared module.

---

### `test/example/test/example_web/live/demo/credentials_live_test.exs` (test, request-response)

**Analog:** `test/example/test/example_web/live/admin_user_index_live_test.exs` and `test/example/test/example_web/admin_shell_test.exs`

**Module + use pattern** (admin_user_index_live_test.exs:1-8):
```elixir
defmodule ExampleWeb.Demo.CredentialsLiveTest do
  use ExampleWeb.ConnCase, async: false

  alias ExampleWeb.Demo.CredentialsLive
end
```
`async: false` is the convention across all example app tests (every existing test file uses `async: false`).

**404 env-guard assertion** (mirrors admin_shell_test.exs:179-183):
```elixir
describe "env-guard: /demo/credentials" do
  test "route returns 404 in test env (compile_env gate compiles route out)" do
    conn = build_conn() |> get("/demo/credentials")
    assert conn.status == 404
  end
end
```
`build_conn()` is available from `Phoenix.ConnTest`, which `ExampleWeb.ConnCase` imports. No login needed — this route requires no auth. `get/2` returns a Conn with `status: 404` because the router has no matching route in `MIX_ENV=test`. Do NOT use `live(conn, "/demo/credentials")` — it raises `Phoenix.Router.NoRouteError`, not a 404.

**Content/testid assertions pattern** — direct render approach (D-12 resolution):
```elixir
describe "rendered HTML contract" do
  test "contains required testids" do
    html =
      CredentialsLive.render(%{
        flash: %{},
        page_title: "Demo Credentials",
        credentials:
          Example.Demo.Personas.all()
          |> Enum.map(fn p ->
            local = p.email |> String.split("@") |> hd()
            Map.merge(p, %{local: local, feature: CredentialsLive.feature_map()[local]})
          end)
      })
      |> Phoenix.HTML.safe_to_string()

    assert html =~ ~s(data-testid="demo-credentials-table")
    assert html =~ ~s(data-testid="demo-persona-row-admin")
    assert html =~ ~s(data-testid="demo-persona-row-alice")
    assert html =~ ~s(data-testid="demo-dev-only-badge")
  end
end
```
Note: `CredentialsLive.render/1` returns a `%Phoenix.LiveView.Rendered{}` struct; `Phoenix.HTML.safe_to_string/1` converts it to a binary for string assertions. If `safe_to_string/1` does not accept the struct directly, pipe through `Phoenix.HTML.html_escape/1` first, or use `IO.iodata_to_binary(Phoenix.LiveView.Rendered.to_iodata(rendered))`. The executor should verify the exact conversion in the Phoenix 1.8 version present.

**testid string assertion idiom** (admin_user_index_live_test.exs:65-66 — confirmed pattern):
```elixir
assert html =~ ~s(data-testid="admin-users-desktop-results")
assert html =~ ~s(data-testid="admin-users-mobile-results")
```
Use `~s(...)` sigil (not string interpolation) — it produces a plain string with double-quoted attribute syntax, which matches the rendered HTML attribute format exactly.

**app-name testid assertion** (DEMO-02 contract):
```elixir
assert html =~ ~s(data-testid="app-name")
assert html =~ "Vaultr"
```
`app-name` testid lives in `layouts.ex:49` after the edit. Since `Layouts.app` is called inside `render/1`, it will appear in the rendered HTML string.

---

### `test/example/lib/example_web/router.ex` (edit, lines 172-177)

**Analog:** Self — the existing `if Application.compile_env(:example, :dev_routes)` block

**Current block** (lines 172-177 — read verbatim):
```elixir
if Application.compile_env(:example, :dev_routes) do
  scope "/dev" do
    pipe_through :browser
    forward "/mailbox", Plug.Swoosh.MailboxPreview
  end
end
```

**After edit** — add a second scope inside the same `if` block:
```elixir
if Application.compile_env(:example, :dev_routes) do
  scope "/dev" do
    pipe_through :browser
    forward "/mailbox", Plug.Swoosh.MailboxPreview
  end

  scope "/demo" do
    pipe_through :browser
    live "/credentials", Demo.CredentialsLive
  end
end
```
The `Demo.CredentialsLive` module reference resolves to `ExampleWeb.Demo.CredentialsLive` because the router module is `ExampleWeb.Router` and Phoenix LiveView routes are resolved relative to the web module namespace. Confirm by checking existing live route declarations in the router — they use unqualified names like `SettingsLive`, not `ExampleWeb.SettingsLive`.

Key: `Application.compile_env(:example, :dev_routes)` (2-argument form, no default). Returns `nil` in test/prod — the `if` block evaluates false and the routes are excluded from the compiled router. `dev.exs:68` sets `config :example, dev_routes: true`.

---

### `test/example/lib/example_web/components/layouts.ex` (edit, lines 46-72)

**Analog:** Self

**Current brand `<a>` block** (lines 46-51 — read verbatim):
```heex
<a href="/" class="flex-1 flex w-fit items-center gap-2">
  <img src={~p"/images/logo.svg"} width="36" alt="" />
  <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
</a>
```

**After edit** (D-08 — replace version span with Vaultr + testid):
```heex
<a href="/" class="flex-1 flex w-fit items-center gap-2">
  <img src={~p"/images/logo.svg"} width="36" alt="" />
  <span class="text-sm font-semibold" data-testid="app-name">Vaultr</span>
</a>
```
Keep the `<img>` slot unchanged. Replace only the `<span>` content and add `data-testid="app-name"`.

**Current nav `<ul>` block** (lines 60-72 — read verbatim):
```heex
<ul class="flex flex-column px-1 space-x-4 items-center">
  <li>
    <a href="https://phoenixframework.org/" class="btn btn-ghost">Website</a>
  </li>
  <li>
    <a href="https://github.com/phoenixframework/phoenix" class="btn btn-ghost">GitHub</a>
  </li>
  <li>
    <a href="https://hexdocs.pm/phoenix/overview.html" class="btn btn-primary">
      Get Started <span aria-hidden="true">&rarr;</span>
    </a>
  </li>
</ul>
```

**After edit** (D-10 — replace Phoenix fixture links with contextual Sign In):
```heex
<ul class="flex flex-column px-1 space-x-4 items-center">
  <li :if={is_nil(@current_scope)}>
    <a href={~p"/users/log_in"} class="btn btn-primary">
      Sign In <span aria-hidden="true">&rarr;</span>
    </a>
  </li>
</ul>
```
Sign-in path confirmed as `/users/log_in` (router.ex:106: `get "/log_in", SessionController, :new` under `scope "/users"`).

Guard `is_nil(@current_scope)` is safe — `current_scope` has `default: nil` (layouts.ex:34-36). The org-switcher row at `:54-59` already guards with `:if={@current_scope && @current_scope.active_organization}` and must NOT be touched (D-09).

D-10 fallback: if the conditional logic is deemed risky, the minimal rebrand (just remove the Phoenix links, leave empty `<ul>`) is acceptable per CONTEXT.md D-10 guardrail.

**Do NOT touch:**
- `:54-59` — `<.org_switcher :if={...}>` block
- `:76` — `<.impersonation_banner :if={...}>` line
- `:78-84` — `<main>` and `<.flash_group>` lines

---

### `test/example/lib/example_web/components/layouts/root.html.heex` (edit, line 7)

**Analog:** Self

**Current line 7** (read verbatim):
```heex
<.live_title default="Example" suffix=" · Phoenix Framework">
```

**After edit** (D-08):
```heex
<.live_title default="Vaultr" suffix=" · Vaultr">
```
Line 8 (`{assigns[:page_title]}`) and all surrounding lines are unchanged. This is a single-attribute-value swap on two attributes of one tag.

---

### `test/example/lib/example/demo/seeds.ex` (edit, `run/0` return)

**Analog:** Self — the existing `Personas.all()` iteration at `seeds.ex:63`

**Current `run/0` tail** (lines 46-57 — read verbatim):
```elixir
def run do
  users = seed_users()
  {acme, beta} = seed_organizations()
  seed_memberships(users, acme, beta)
  seed_invitation(acme)
  seed_mfa_credentials(users)
  seed_passkey(users)
  seed_enterprise_connection(acme)
  seed_user_identity(users)
  seed_audit_events(users)
  :ok
end
```

**After edit** (D-11 — add stdout block before `:ok`):
```elixir
def run do
  users = seed_users()
  {acme, beta} = seed_organizations()
  seed_memberships(users, acme, beta)
  seed_invitation(acme)
  seed_mfa_credentials(users)
  seed_passkey(users)
  seed_enterprise_connection(acme)
  seed_user_identity(users)
  seed_audit_events(users)
  print_credentials()
  :ok
end

defp print_credentials do
  IO.puts("\n=== Demo Credentials ===")

  Personas.all()
  |> Enum.each(fn p ->
    local = p.email |> String.split("@") |> hd()
    feature = ExampleWeb.Demo.CredentialsLive.feature_map()[local]
    IO.puts("[#{local}]  #{p.email}  #{p.password}  (#{feature})")
  end)
end
```
`Personas` is already aliased at `seeds.ex:33`. The call `ExampleWeb.Demo.CredentialsLive.feature_map()` satisfies D-02 (single source). Alternatively, if `feature_map/0` is moved to `Example.Demo.Personas`, call `Personas.feature_map()[local]` — either approach works.

Format per UI-SPEC copywriting table: `[persona]  email  password  (feature)` — two spaces between fields, feature wrapped in parens.

---

## Shared Patterns

### LiveView Explicit Layout Wrap
**Source:** `test/example/lib/example_web/live/organization_settings_live.ex` lines 55-61
**Apply to:** `CredentialsLive` render function
```elixir
<Layouts.app flash={@flash}>
  ...content...
</Layouts.app>
```
`flash={@flash}` is required. `current_scope` and `user_organizations` are optional (safe defaults). No `put_root_layout` call exists in the `:live_view` macro — every LiveView must wrap explicitly.

### testid String Assertion Idiom
**Source:** `test/example/test/example_web/live/admin_user_index_live_test.exs` lines 65-66
**Apply to:** `credentials_live_test.exs`
```elixir
assert html =~ ~s(data-testid="some-id")
```
Use `~s(...)` sigil, not string interpolation. Matches the double-quoted attribute format in rendered HTML exactly.

### ConnCase Test Module Header
**Source:** All test files in `test/example/test/example_web/`
**Apply to:** `credentials_live_test.exs`
```elixir
use ExampleWeb.ConnCase, async: false
```
`async: false` is the universal convention in this test suite.

### compile_env Dev-Routes Gate
**Source:** `test/example/lib/example_web/router.ex` lines 172-177
**Apply to:** Router edit
```elixir
if Application.compile_env(:example, :dev_routes) do
  # scopes here
end
```
Two-argument form (no default) — returns nil when key is absent. Route compiles out in test/prod. Do NOT use `compile_env!` (bang raises on absent key).

### daisyUI Class Vocabulary
**Source:** `test/example/lib/example_web/components/core_components.ex`, `layouts.ex`, `admin_shell.ex`
**Apply to:** `CredentialsLive` template
| Token | Class | Example Usage |
|-------|-------|--------------|
| Table | `table table-zebra` | Table element |
| Badge warning | `badge badge-warning badge-sm` | DEV ONLY badge |
| Button primary | `btn btn-primary` | Sign In nav link |
| Button ghost | `btn btn-ghost` | Secondary nav links |
| Muted text | `text-base-content/60` | Disclaimer copy |
| Monospace | `font-mono text-sm` | Password `<code>` cells |

---

## No Analog Found

All six files have direct analogs in the codebase. No files require falling back to RESEARCH.md patterns exclusively.

---

## Metadata

**Analog search scope:**
- `test/example/lib/example_web/live/` — LiveView analogs
- `test/example/test/example_web/live/` — test analogs
- `test/example/lib/example_web/components/` — component/layout analogs
- `test/example/lib/example/demo/` — data utility analogs
- `test/example/lib/example_web/router.ex` — router analog (self)

**Files read:** 11
**Pattern extraction date:** 2026-05-30
