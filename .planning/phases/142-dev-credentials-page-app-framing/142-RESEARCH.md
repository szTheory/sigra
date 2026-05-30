# Phase 142: dev-credentials-page-app-framing - Research

**Researched:** 2026-05-30
**Domain:** Phoenix LiveView dev-only route, testid assertions, daisyUI table markup, branding
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Feature copy lives as a hardcoded mapping joined to personas by email local part (not a persona map field).
- **D-02:** The feature-text mapping is the SINGLE source for both the credentials page and the seeds stdout block. Define once, consume twice.
- **D-03:** `demo-persona-row-{local}` derives `{local}` by splitting `persona.email` on `"@"`. Do NOT use `display_name`.
- **D-04:** `CredentialsLive` must explicitly wrap its render in `<Layouts.app flash={@flash}>`. `flash` is `required: true`. Reference pattern: `organization_settings_live.ex:57-61`. `current_scope`/`user_organizations` may be omitted (default to `nil`/`[]`).
- **D-05:** Persona table is HAND-ROLLED `<table>` markup using daisyUI `table table-zebra` classes — NOT `<.table>` CoreComponent. `<.table>` has no `data-testid` passthrough on the table root or per-row `<tr>`.
- **D-06:** Required testids: `demo-credentials-table` (table root), `demo-persona-row-{local}` (each row), `demo-dev-only-badge` (DEV ONLY badge), `app-name` (header brand).
- **D-07:** Page carries `badge badge-warning badge-sm` "DEV ONLY" signal (DEMO-01 contract). Password cells use `<code>`/`font-mono`. No JS copy-to-clipboard.
- **D-08:** "Vaultr" branding: `root.html.heex:7` → `default="Vaultr" suffix=" · Vaultr"`. `layouts.ex:48-52` → replace Phoenix version span with "Vaultr" text + `data-testid="app-name"`.
- **D-09:** `layouts.ex` edits scoped to brand span and static nav `<ul>` (`:60-72`). Do not touch org-switcher / impersonation rows.
- **D-10:** Nav-link treatment — branch on `@current_scope` to render "Sign In →" when unauthenticated, leave authenticated affordances untouched. Fallback: minimal rebrand removing Phoenix-fixture links.
- **D-11:** Print `=== Demo Credentials ===` block from `Example.Demo.Seeds.run/0` after seeding; NOT from `seeds.exs`. Reuse in-scope persona data and D-02 feature map. Format: one line per persona `[persona]  email  password  (feature)`.
- **D-12:** SC#2 env-guard verification is NET-NEW. Mirror `router.ex:172-177` compile-env gate. Route is compiled OUT in test — assertion is **route-absent / 404 for `/demo/credentials`**. Do NOT try to assert route-present from within the test env.

### Claude's Discretion

- Exact markup nesting, class ordering, and `<.header>` reuse for section heading.
- Module/function naming inside `CredentialsLive`, the feature-map module location, and test file naming/shape.
- Whether the feature-text map lives in `CredentialsLive`, `Personas`, or a small shared helper — provided D-02 holds.

### Deferred Ideas (OUT OF SCOPE)

- DEMO-03 (in-app per-persona explainer banner) — Future Requirement.
- JS copy-to-clipboard widget.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEMO-01 | Dev-only credentials cheat-sheet at `/demo/credentials`; route present in dev, absent in test/prod | LiveView wiring pattern + compile-env gate + 404 assertion pattern |
| DEMO-02 | Example app presents realistic SaaS framing ("Vaultr") rather than bare scaffold | Branding edits to `root.html.heex` + `layouts.ex` |
</phase_requirements>

---

## Summary

Phase 142 delivers two things: (1) a new LiveView at `/demo/credentials` gated behind the existing `compile_env(:example, :dev_routes)` guard, and (2) "Vaultr" branding in the example app layout. Both are confined to `test/example/`. The code surface is small and all decisions are locked; the research value is precise wiring patterns, landmine identification, and the Validation Architecture.

The key technical facts confirmed by codebase inspection:

- `Application.compile_env(:example, :dev_routes)` is set only in `dev.exs` (value `true`). It is absent from `test.exs`, `config.exs`, and `prod.exs`. The two-argument form returns `nil`/falsy when the key is absent (confirmed: the existing `/dev/mailbox` forward uses the identical guard and the suite compiles/runs fine without raising). This means the route is compiled out in `MIX_ENV=test`, making 404 the only assertable direction.
- `Layouts.app/1` declares `flash` as `required: true` (confirmed: `layouts.ex:32`). `current_scope` and `user_organizations` have safe defaults (`nil`/`[]`). The reference invocation in `organization_settings_live.ex:57-61` passes all three — CredentialsLive may omit the optional pair.
- `<.table>` CoreComponent (confirmed: `core_components.ex:354-390`) renders a plain `<table class="table table-zebra">` with no `data-testid` slot or passthrough attribute on the table element or on `<tr>` rows. D-05 (hand-roll) is mandatory for the required testids.
- The existing `data-testid` assertion pattern in the codebase is `assert html =~ ~s(data-testid="some-id")` on the raw HTML string returned by `html_response(conn, 200)` or the `html` return of `live/2`. This is the standard pattern across every test file in `test/example/test/`.

**Primary recommendation:** New file `test/example/lib/example_web/live/demo/credentials_live.ex`; route inside the existing `if Application.compile_env(:example, :dev_routes)` block as `live "/demo/credentials", Demo.CredentialsLive`; test at `test/example/test/example_web/live/demo/credentials_live_test.exs` (route-absent 404) plus a static HTML assertion test for the rendered page content executed in a different env configuration.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `/demo/credentials` route registration | Frontend Server (Phoenix Router) | — | Compile-env gate lives in router; LiveView mounts via router |
| Credentials page render | Frontend Server (LiveView) | — | Read-only render from `Personas.all/0`; no DB call needed |
| Feature-text mapping (D-02) | Example app module | — | Shared between LiveView and Seeds; pure data, no DB |
| Seeds stdout block | Example app (Seeds.run/0) | — | Printed after seeding, same feature map |
| Branding (title + header) | Frontend Server (layout templates) | — | `root.html.heex` + `layouts.ex` edits |
| testid presence contract | Frontend Server (LiveView HTML) | — | Phase 143 Playwright consumes these |

---

## Standard Stack

No new packages. This phase uses only what is already present in `test/example/`.

| Component | Source | Notes |
|-----------|--------|-------|
| `Phoenix.LiveView` | `use ExampleWeb, :live_view` | No default layout set in the `:live_view` macro; must wrap explicitly |
| `ExampleWeb.Layouts` | `layouts.ex` | `Layouts.app/1` with `flash` required |
| `Example.Demo.Personas` | `personas.ex` | `Personas.all/0` returns list of 6 maps; no `:feature` field exists |
| daisyUI | Tailwind plugin, already configured | `table table-zebra`, `badge badge-warning badge-sm`, `btn btn-ghost`, `btn btn-primary` |
| `Phoenix.ConnTest` + `Phoenix.LiveViewTest` | `ExampleWeb.ConnCase` | Already imported via `ConnCase` for conn tests; `import Phoenix.LiveViewTest` for live tests |

**Installation:** None required.

## Package Legitimacy Audit

Not applicable — no new packages installed in this phase.

---

## Architecture Patterns

### System Architecture Diagram

```
mix phx.server (MIX_ENV=dev)
       │
       ▼
router.ex
  if compile_env(:example, :dev_routes)   ←── true only in dev.exs
       │
       ▼
  scope "/demo" → pipe_through :browser
       │
       ▼
  live "/demo/credentials" → ExampleWeb.Demo.CredentialsLive
       │
       ▼
  CredentialsLive.mount/3
    assign :credentials  ←── Personas.all/0 + feature_map()  [D-02 single source]
    assign :page_title   ←── "Demo Credentials"
       │
       ▼
  CredentialsLive.render/1
    <Layouts.app flash={@flash}>         [D-04: explicit wrap, no default layout]
      <.header> + badge                   [badge badge-warning, data-testid="demo-dev-only-badge"]
      <table data-testid="demo-credentials-table">   [D-05: hand-rolled, not <.table>]
        <tr data-testid="demo-persona-row-{local}">  [D-03: local = email before @]
      </table>
    </Layouts.app>
       │
       ▼
  root.html.heex  →  <.live_title default="Vaultr" suffix=" · Vaultr">  [D-08]

layouts.ex  →  brand span = "Vaultr" + data-testid="app-name"            [D-08]
               nav ul: contextual "Sign In →" or remove Phoenix links    [D-10]

Seeds.run/0  →  after seeding, print "=== Demo Credentials ===" block   [D-11]
                using same feature_map/0 as CredentialsLive              [D-02]
```

### Recommended Project Structure

```
test/example/lib/example_web/live/
└── demo/
    └── credentials_live.ex        # new: ExampleWeb.Demo.CredentialsLive

test/example/test/example_web/live/
└── demo/
    └── credentials_live_test.exs  # new: env-guard 404 + HTML contract tests
```

The feature map (D-02 single source) should live in `CredentialsLive` as a private `feature_map/0` function, OR as a module attribute, OR extracted to `Example.Demo.Personas` as a public function — any of these satisfies D-02 as long as `Seeds.run/0` calls the same function. The executor should pick the approach that minimizes distance between the two call sites. A private `Example.Demo.CredentialsFeatures` module is cleanest if the map needs to be imported by both files, but a single private function duplicated would violate D-02.

### Pattern 1: Dev-Only LiveView Route (mirrors `/dev/mailbox`)

**What:** Add a `live` route inside the existing `if Application.compile_env(:example, :dev_routes)` block.
**When to use:** Any dev-only page that needs the full LiveView stack.

```elixir
# router.ex — inside the existing if block
if Application.compile_env(:example, :dev_routes) do
  scope "/dev" do
    pipe_through :browser
    forward "/mailbox", Plug.Swoosh.MailboxPreview
  end

  scope "/demo" do                          # new scope
    pipe_through :browser
    live "/credentials", Demo.CredentialsLive
  end
end
```

**Note:** The `/demo` scope can share the same `if` block as `/dev`. A separate `scope "/demo"` is cleaner than putting it inside the `/dev` scope, but both work. [VERIFIED: codebase inspection]

### Pattern 2: LiveView with Explicit Layout Wrap (mirrors `organization_settings_live.ex:57-61`)

```elixir
# lib/example_web/live/demo/credentials_live.ex
defmodule ExampleWeb.Demo.CredentialsLive do
  use ExampleWeb, :live_view

  alias Example.Demo.Personas

  @impl true
  def mount(_params, _session, socket) do
    credentials =
      Personas.all()
      |> Enum.map(fn p ->
        local = p.email |> String.split("@") |> hd()
        Map.put(p, :local, local)
        |> Map.put(:feature, feature_map()[local])
      end)

    {:ok, assign(socket, page_title: "Demo Credentials", credentials: credentials)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      ...
    </Layouts.app>
    """
  end

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
end
```

Copy values are locked verbatim in `142-UI-SPEC.md` copywriting table — use exactly those strings. [VERIFIED: codebase inspection]

### Pattern 3: Hand-Rolled Table with Testids (D-05)

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

[VERIFIED: codebase inspection — `<.table>` source confirmed no testid slots]

### Pattern 4: testid Assertion in ExUnit

```elixir
# conn-based assertion (no auth needed for /demo/credentials in dev context)
assert html =~ ~s(data-testid="demo-credentials-table")
assert html =~ ~s(data-testid="demo-persona-row-admin")
assert html =~ ~s(data-testid="demo-dev-only-badge")
assert html =~ ~s(data-testid="app-name")
```

This is the idiomatic pattern used throughout `test/example/test/`. [VERIFIED: `admin_user_index_live_test.exs:65-66`]

### Pattern 5: 404 Env-Guard Assertion (D-12)

```elixir
# The route is compiled OUT in MIX_ENV=test
# Assert the absence direction only
test "credentials route is not available in test env" do
  conn = build_conn() |> get("/demo/credentials")
  assert conn.status == 404
end
```

The `build_conn()` helper is available via `Phoenix.ConnTest`, which is imported by `ExampleWeb.ConnCase`. [VERIFIED: `conn_case.ex` and `admin_shell_test.exs:180` pattern]

### Anti-Patterns to Avoid

- **Using `<.table>` for the credentials table:** `<.table>` has no `data-testid` passthrough on `<table>` or `<tr>` — testids would be missing. Use hand-rolled markup (D-05).
- **Omitting `flash={@flash}` from `<Layouts.app>`:** `flash` is `required: true` in `Layouts.app/1`. Omitting it raises a compile-time component error.
- **Passing `current_scope` as required:** It has `default: nil` — safe to omit for this unauthenticated route.
- **Defining the feature map in two places:** Violates D-02. Seeds stdout and the page must share one source.
- **Asserting route-present from the test env:** `compile_env(:example, :dev_routes)` resolves at compile time. Test env cannot see the route. Do not attempt `live(conn, "/demo/credentials")` in positive assertions — it will raise `Phoenix.Router.NoRouteError`.
- **Using `display_name` for testid local part:** `display_name` is "Admin (operator)" — contains parens and spaces. D-03 specifies splitting `email` on `"@"`.
- **Touching the org-switcher / impersonation rows in layouts.ex:** D-09 explicitly forbids it. Limit edits to the brand `<span>` (`:48-52`) and the nav `<ul>` (`:60-72`).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Per-row testid derivation | Custom ID generator | `String.split(email, "@") \|> hd()` inline in template | One line; stable key already guaranteed by `@demo.sigra.dev` domain |
| Layout chrome | Custom layout | `<Layouts.app flash={@flash}>` | Shared app chrome, handles flash, impersonation banner, org switcher |
| DEV ONLY badge | Custom CSS warning | `badge badge-warning badge-sm` daisyUI class | Consistent with daisyUI vocabulary already in use |

---

## Common Pitfalls

### Pitfall 1: `flash` Required Attribute
**What goes wrong:** `Layouts.app/1` declares `attr :flash, :map, required: true`. If a LiveView omits `flash={@flash}`, Phoenix raises a compile-time `Phoenix.Component` error: "missing required attribute".
**Why it happens:** The `:live_view` macro in `example_web.ex` does NOT set a default layout — no implicit layout injection happens. Every LiveView that uses `Layouts.app` must pass all required attrs explicitly.
**How to avoid:** Always include `flash={@flash}` as the first attribute. Reference: `organization_settings_live.ex:57-59`.
**Warning signs:** `** (ArgumentError) missing required attribute flash` at compile time.

### Pitfall 2: `compile_env/2` Raises if Key Has Never Been Set Anywhere
**What goes wrong:** `Application.compile_env(:example, :dev_routes)` (2-arg form) returns `nil`/falsy when the key is absent from the current env's config — but ONLY if the key has never been configured in *any* Mix config file. If the key does not exist at all (not even as `nil`), Elixir 1.18 emits a warning but does not raise during compilation when the `if` block evaluates it. The existing `/dev/mailbox` gate proves this: `test.exs` has no `dev_routes` setting, yet the suite compiles cleanly.
**Why it happens:** `compile_env/2` tracks the config key for recompilation purposes; the `if` evaluates to `nil` (falsy) and the block is discarded at compile time.
**How to avoid:** Mirror the existing gate exactly — use `Application.compile_env(:example, :dev_routes)` (2-arg, no default) inside an `if` block. The route will compile out in test and prod automatically.
**Warning signs:** If you accidentally use `compile_env!` (bang), it raises when key is absent.

### Pitfall 3: `Phoenix.Router.NoRouteError` in Positive LiveView Tests
**What goes wrong:** If a test file in `test/example/test/` tries `live(conn, "/demo/credentials")`, it raises `Phoenix.Router.NoRouteError` (not a 404 response) because the route was compiled out.
**Why it happens:** `Phoenix.LiveViewTest.live/2` calls the router at test time; the router has no `/demo/credentials` entry because `compile_env` evaluated to `nil`.
**How to avoid:** The only assertable direction in tests is the 404 path via `get/2` (which returns a Conn with `status: 404`). The content/testid assertions for the rendered page should live in a dedicated test that is either tagged or skipped in CI, or confirmed via a different mechanism (Playwright in Phase 143).
**Warning signs:** `** (Phoenix.Router.NoRouteError)` in test output.

### Pitfall 4: `<.table>` Testid Gap
**What goes wrong:** The `<.table>` CoreComponent (`core_components.ex:354-390`) renders `<table class="table table-zebra">` with no `id`, `data-testid`, or additional attribute passthrough on the `<table>` element. The `<tr>` elements use `id={@row_id && @row_id.(row)}` — not `data-testid`. Using `<.table>` would silently omit D-06 testids.
**Why it happens:** `<.table>` was designed for application data tables; testid attributes were not part of its contract.
**How to avoid:** Hand-roll the `<table>` markup per D-05.

### Pitfall 5: Seeds Feature Map Drift (D-02)
**What goes wrong:** If the feature-text map is defined in `CredentialsLive` AND separately in `Seeds.run/0`, the two can silently diverge.
**Why it happens:** Copy-paste during implementation without establishing a single source.
**How to avoid:** The feature map MUST be defined once and called from both `CredentialsLive` and the seeds stdout block. Options: (a) a module attribute `@feature_map` in a shared `Example.Demo.CredentialsFeatures` module imported by both; (b) a public `Example.Demo.Personas.feature_map/0` function; (c) in `CredentialsLive` as a public function that `Seeds.run/0` calls directly. The executor chooses; any of these satisfies D-02.
**Warning signs:** The seeds stdout and the credentials page show different copy for the same persona.

### Pitfall 6: Nav Link `@current_scope` Guard
**What goes wrong:** The `/demo/credentials` route requires NO authentication. `@current_scope` will be `nil` for an unauthenticated visitor. If `layouts.ex` renders any nav element that unconditionally calls into `@current_scope` attributes, it will raise `KeyError` or `NilMatchError`.
**Why it happens:** The existing nav links are static Phoenix links (Website / GitHub / Get Started) — they do not reference `@current_scope`. The risk only arises if D-10 adds a new `current_scope`-dependent branch improperly.
**How to avoid:** Per D-10, branch on `@current_scope` explicitly with `:if={is_nil(@current_scope)}` or `<%= if @current_scope == nil do %>`. Do not access fields on `@current_scope` without a nil guard.

---

## Code Examples

### Branding: `root.html.heex` line 7

Before:
```heex
<.live_title default="Example" suffix=" · Phoenix Framework">
```

After:
```heex
<.live_title default="Vaultr" suffix=" · Vaultr">
```

[VERIFIED: `root.html.heex:7` codebase inspection]

### Branding: `layouts.ex` brand span (lines 48-52)

Before:
```heex
<a href="/" class="flex-1 flex w-fit items-center gap-2">
  <img src={~p"/images/logo.svg"} width="36" alt="" />
  <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
</a>
```

After:
```heex
<a href="/" class="flex-1 flex w-fit items-center gap-2">
  <img src={~p"/images/logo.svg"} width="36" alt="" />
  <span class="text-sm font-semibold" data-testid="app-name">Vaultr</span>
</a>
```

[VERIFIED: `layouts.ex:46-52` codebase inspection]

### Nav links: contextual Sign In (D-10)

```heex
<ul class="flex flex-column px-1 space-x-4 items-center">
  <li :if={is_nil(@current_scope)}>
    <a href={~p"/users/log_in"} class="btn btn-primary">
      Sign In <span aria-hidden="true">&rarr;</span>
    </a>
  </li>
</ul>
```

The existing three Phoenix links (Website / GitHub / Get Started) are replaced. The authenticated state already has org-switcher and other affordances above this `<ul>`; no additional authenticated nav is added here. [ASSUMED — executor may choose minimal rebrand fallback per D-10 guardrail]

### Seeds stdout (D-11)

```elixir
# At the end of Seeds.run/0, after :ok
IO.puts("\n=== Demo Credentials ===")

Personas.all()
|> Enum.each(fn p ->
  local = p.email |> String.split("@") |> hd()
  feature = feature_map()[local]
  IO.puts("[#{local}]  #{p.email}  #{p.password}  (#{feature})")
end)
```

Where `feature_map/0` is the same single-source function used by `CredentialsLive`. [VERIFIED: `seeds.ex` structure; format from `142-UI-SPEC.md` copywriting table]

---

## Validation Architecture

> `workflow.nyquist_validation` is `true` in `.planning/config.json`. Section required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir built-in) |
| Config file | `test/example/test/test_helper.exs` |
| Quick run command | `cd test/example && mix test test/example_web/live/demo/credentials_live_test.exs` |
| Full suite command | `cd test/example && mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEMO-01 | `/demo/credentials` returns 404 in test env (compile-env gate) | smoke / conn | `mix test test/example_web/live/demo/credentials_live_test.exs` | Wave 0 |
| DEMO-01 | Rendered HTML contains `data-testid="demo-credentials-table"` | structural / conn or LiveView | Same file | Wave 0 |
| DEMO-01 | Each persona row has `data-testid="demo-persona-row-{local}"` | structural | Same file | Wave 0 |
| DEMO-01 | DEV ONLY badge has `data-testid="demo-dev-only-badge"` | structural | Same file | Wave 0 |
| DEMO-02 | App name `data-testid="app-name"` present in layout | structural | Same file (layout carries testid) | Wave 0 |
| DEMO-02 | Browser `<title>` contains "Vaultr" | structural / conn | Same file | Wave 0 |

**Key constraint:** Positive HTML-content tests (asserting rendered page content) cannot use `live(conn, "/demo/credentials")` because the route is compiled out in `MIX_ENV=test`. The options for covering rendered content are:

**Option A (recommended):** Test the `CredentialsLive.render/1` function directly by calling it in a test with a minimal socket assigns map — this exercises the template without touching the router. Phoenix 1.8 LiveView exposes `render_component/2` or the executor can call `CredentialsLive.render(assigns)` directly and assert on the returned `%Phoenix.LiveView.Rendered{}` iodata.

**Option B:** Test content assertions via the router by doing `get(conn, "/demo/credentials")` in a `MIX_ENV=dev` equivalent config — not practical within the standard test suite.

**Option C (pragmatic):** Place content assertions in the same test file, using `Phoenix.LiveViewTest.render_component/2` or by building assigns manually and calling `render/1` as a unit test. This is the cleanest approach for a read-only LiveView that has no LiveView-specific interactivity.

The 404 test is straightforward:

```elixir
test "credentials route returns 404 in test env (compile-env gate)" do
  conn = build_conn() |> get("/demo/credentials")
  assert conn.status == 404
end
```

Content assertions can use `Phoenix.LiveViewTest.render_component/3`:

```elixir
import Phoenix.LiveViewTest

test "renders credentials table testids" do
  html = render_component(ExampleWeb.Demo.CredentialsLive, %{})
  assert html =~ ~s(data-testid="demo-credentials-table")
  assert html =~ ~s(data-testid="demo-persona-row-admin")
  assert html =~ ~s(data-testid="demo-dev-only-badge")
end
```

Note: `render_component/3` works for `Phoenix.LiveComponent` — for `Phoenix.LiveView`, the typical approach is to invoke the render function directly or test via the router. The executor should verify which approach works cleanly for a LiveView (not LiveComponent) in Phoenix 1.8 and pick the one that does not require routing. A simple `CredentialsLive.render(%{flash: %{}, credentials: ..., page_title: "..."})` and piping through `Phoenix.HTML.safe_to_string/1` is viable.

### Sampling Rate

- **Per task commit:** `cd test/example && mix test test/example_web/live/demo/credentials_live_test.exs`
- **Per wave merge:** `cd test/example && mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/example/test/example_web/live/demo/credentials_live_test.exs` — covers DEMO-01 (404 env guard) and DEMO-02 (content/testid assertions)
- [ ] `test/example/test/example_web/live/demo/` directory (new)

*(Existing test infrastructure — `ExampleWeb.ConnCase`, `Phoenix.ConnTest`, `Phoenix.LiveViewTest` — already present. No new framework installation needed.)*

---

## Environment Availability

This phase is confined to `test/example/` source edits. No external services, CLIs, or runtimes beyond what the existing test suite requires.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | LiveView compilation | Yes | 1.19.5 (from CLAUDE.md) | — |
| Phoenix LiveView | LiveView rendering | Yes | embedded in `test/example/deps` | — |
| daisyUI | Badge/table classes | Yes | already configured in tailwind | — |
| PostgreSQL | `mix test` (SQL Sandbox) | Per CLAUDE.md | 16-alpine Docker | `docker run -d --name sigra-test-postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16-alpine` |

**Missing dependencies with no fallback:** None.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Application.compile_env/2` returns nil (not raises) when key is absent in current env's config, causing the `if` block to evaluate false and compile out the route | Pitfall 2, Validation Architecture | If it raises at compile time, the test suite would break — but current `/dev/mailbox` gate proves this works safely |
| A2 | `Phoenix.LiveViewTest.render_component/3` (or direct render function call) is a viable approach to assert HTML content for a read-only LiveView without routing through the router | Validation Architecture | If not viable, content assertions would need to be deferred to Phase 143 Playwright |
| A3 | The contextual "Sign In →" nav link in D-10 uses `~p"/users/log_in"` as the sign-in path | Code Examples | The sign-in route could have a different path; executor should verify via `mix phx.routes` or router inspection |

---

## Open Questions

1. **Render content testing strategy**
   - What we know: The route is compiled out in test env; `live/2` will raise `NoRouteError`.
   - What's unclear: Whether `Phoenix.LiveViewTest.render_component/3` works for a `Phoenix.LiveView` module (vs `Phoenix.LiveComponent`) in the project's current Phoenix version, or whether calling `render/1` directly is simpler.
   - Recommendation: Executor should test `CredentialsLive.render(%{flash: %{}, credentials: [], page_title: "Demo Credentials"})` directly and assert on the resulting iodata/HTML string. If that doesn't type-check cleanly, fall back to checking just the 404 case in automated tests and note content coverage will be Playwright-only (Phase 143).

---

## Sources

### Primary (HIGH confidence)

- Codebase inspection: `test/example/lib/example_web/components/layouts.ex:32-86` — `Layouts.app/1` attrs (`flash` required, `current_scope`/`user_organizations` optional)
- Codebase inspection: `test/example/lib/example_web/components/core_components.ex:354-390` — `<.table>` confirmed no testid passthrough
- Codebase inspection: `test/example/lib/example_web/router.ex:172-177` — `compile_env(:example, :dev_routes)` guard pattern
- Codebase inspection: `test/example/config/dev.exs:68` — `config :example, dev_routes: true`; absent from test.exs
- Codebase inspection: `test/example/lib/example/demo/personas.ex` — exact field set confirmed; no `:feature` field
- Codebase inspection: `test/example/lib/example/demo/seeds.ex` — `Seeds.run/0` structure; `Personas` alias in scope
- Codebase inspection: `test/example/lib/example_web/live/organization_settings_live.ex:57-61` — reference pattern for `<Layouts.app flash={@flash}>`
- Codebase inspection: `test/example/lib/example_web/components/layouts/root.html.heex:7` — current `<.live_title>` default/suffix
- Codebase inspection: `test/example/test/example_web/live/admin_user_index_live_test.exs:65-66` — `assert html =~ ~s(data-testid="...")` idiom
- Codebase inspection: `test/example/test/example_web/admin_shell_test.exs:180` — `assert conn.status == 404` idiom
- `142-CONTEXT.md` — locked decisions D-01 through D-12 [HIGH — authoritative]
- `142-UI-SPEC.md` — approved copywriting, testid contract, component inventory [HIGH — authoritative]

### Secondary (MEDIUM confidence)

- Phoenix 1.8 `Layouts.app` behavior: no implicit layout from `:live_view` macro — confirmed via `example_web.ex` (`:live_view` macro body has no `put_root_layout` call)

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all libraries already present in project; zero new deps
- Architecture: HIGH — all patterns confirmed by direct codebase inspection
- Pitfalls: HIGH — each pitfall is grounded in actual code (flash required attr, compile_env behavior, `<.table>` source)
- Validation architecture: MEDIUM — 404 test approach confirmed; content assertion approach has one open question (render_component vs direct render)

**Research date:** 2026-05-30
**Valid until:** Stable indefinitely (zero external dependencies; all findings grounded in local codebase)
