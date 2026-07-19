---
quick_id: 260718-ssq
title: "Unify the demo bar into one shared component (login + sudo + authed app)"
status: ready
---

# Unify 3 demo-bar variants → one `demo_bar/1` component. Example-only, dev-gated.

ALL example-only (test/example/). NO priv/templates/, NO test/fixtures/. Commit in logical parts.

## Task 1 — shared component + Personas API
NEW `test/example/lib/example_web/components/demo_bar.ex` — module `ExampleWeb.Components.DemoBar`,
`use ExampleWeb, :html`, one `demo_bar/1` function. Attrs: `persona` (:map, default nil — enriched
`%{key, display_name, email, password, feature}`), `personas` (:list, default []), `fill` (:boolean,
default false), `centered` (:boolean, default false). Markup:
```heex
<div class={["vt-demo-switch", @centered && "vt-demo-switch--login"]} data-testid="demo-bar">
  <span class="vt-status-pill" title="Disposable demo accounts — never use in production">DEMO</span>
  <span :if={@persona} class="vt-demo-switch__identity">
    <strong class="vt-demo-switch__name">{@persona.display_name}</strong>
    <span :if={@persona.feature} class="vt-demo-switch__desc">{@persona.feature}</span>
    <code class="vt-code vt-code--copy">{@persona.email}</code>
  </span>
  <span :if={is_nil(@persona)} class="vt-demo-switch__label">Demo personas — never use in production</span>
  <button :if={@fill && @persona} type="button" class="vt-btn vt-btn--ghost"
          data-demo-fill-password data-demo-password={@persona.password}>Fill password</button>
  <select class="vt-demo-switch__select" data-demo-persona-switch aria-label="Switch demo persona">
    <option value="" disabled selected={is_nil(@persona)}>Switch persona…</option>
    <option :for={p <- @personas} value={p.key} selected={@persona && @persona.key == p.key}>{p.display_name}</option>
  </select>
</div>
```
`test/example/lib/example/demo/personas.ex` — add public helpers (reuse existing `all/0`,
`feature_map/0`, `email/1`):
- `by_key/1` — `all() |> Enum.find(&(&1.email |> String.split("@") |> hd() == key)) |> enrich()`
- `by_email/1` — `all() |> Enum.find(&(&1.email == email)) |> enrich()`
- `options/0` — `Enum.map(all(), fn p -> %{key: p.email |> String.split("@") |> hd(), display_name: p.display_name} end)`
- `defp enrich(nil), do: nil` ; `defp enrich(p) do local = p.email |> String.split("@") |> hd(); Map.merge(p, %{key: local, feature: feature_map()[local]}) end`
Add `@doc`/`@spec` to match module style.

## Task 2 — wire the 3 call sites
`test/example/lib/example_web/components/layouts.ex`: `import ExampleWeb.Components.DemoBar` (near the
other imports). Rewrite `demo_persona_switch/1` body to:
`persona = Example.Demo.Personas.by_email(assigns.current_scope.user.email)` then assign + render
`<.demo_bar persona={@persona} personas={Example.Demo.Personas.options()} fill={false} centered={false} />`.
Keep the `app/1` call-site gate `:if={@dev_routes? && @current_scope}` unchanged.

`test/example/lib/example_web/controllers/session_controller.ex`: keep the dev-gate pattern. Replace
`demo_persona_hint/1` internals to return `Example.Demo.Personas.by_key(params["demo"])` (enriched)
under dev / `nil` otherwise; keep `demo_persona_options/0` but return `Example.Demo.Personas.options()`
under dev / `[]` otherwise. Pass assigns `demo_persona:` (enriched, was demo_persona_hint) +
`demo_personas:`. (The email-prefill logic that reads `demo_persona.email` still works — `by_key`
returns a superset map. Keep `demo_persona_lookup/1` for the always-on email prefill OR reuse by_key
for the email; ensure the always-active email prefill is unchanged and NOT dev-gated.)
`test/example/lib/example_web/controllers/session_html.ex`: `import ExampleWeb.Components.DemoBar`;
replace the `data-testid="demo-login-hint"` block (lines ~33-69) with
`<.demo_bar :if={@demo_personas != []} persona={@demo_persona} personas={@demo_personas} fill={true} centered={true} />`.

`test/example/lib/example_web/controllers/auth/sudo_controller.ex`: change `demo_persona_for/1` to
return `Example.Demo.Personas.by_email(user.email)` (enriched) under dev / nil otherwise; ADD a
dev-gated `demo_persona_options/0` (→ `Personas.options()` / `[]`); pass `demo_personas:` on BOTH
render paths (new/2 + create/2 failure) alongside `demo_persona:`.
`test/example/lib/example_web/controllers/auth/sudo_html.ex`: `import ExampleWeb.Components.DemoBar`;
replace the `data-testid="demo-sudo-hint"` block with
`<.demo_bar :if={@demo_personas != []} persona={@demo_persona} personas={@demo_personas} fill={true} centered={true} />`.

## Task 3 — JS switch target + CSS
`test/example/assets/js/admin_hooks.js` AND `test/example/priv/static/assets/js/app.js`: in
`installDemoPersonaSwitch()`, change the navigation from
`"/users/log_in?demo=" + encodeURIComponent(sel.value)` → `"/demo/use/" + encodeURIComponent(sel.value)`.
(installDemoPasswordFill unchanged — already matches user[password] + sudo[password].)
`test/example/priv/static/assets/css/app.css`: add near `.vt-demo-switch` rules:
```css
.vt-demo-switch__identity { display: inline-flex; flex-wrap: wrap; align-items: baseline; gap: var(--sg-space-2); }
.vt-demo-switch__name { font-weight: var(--sg-weight-bold); color: var(--vt-color-ink); }
.vt-demo-switch__desc { color: var(--vt-color-muted); font-size: var(--sg-text-2xs); }
```

## Task 4 — tests (collapse to unified `demo-bar` testid; keep dev-gating)
- `test/example/test/example_web/controllers/session_controller_test.exs` (~117-123): keep the
  `value="admin@demo.tasklane.test"` prefill assert; replace the three refutes with refute
  `~s(data-testid="demo-bar")`, `data-demo-fill-password`, `data-demo-persona-switch`. Keep the
  `/demo/use/:persona` 404 env-guard test.
- `test/example/test/example_web/controllers/auth/sudo_controller_test.exs` (~15-19): same three
  refutes against `demo-bar`.
- `test/example/test/example_web/live/app_live_test.exs` (~28): refute `~s(data-testid="demo-bar")`
  (was `demo-persona-switch`).
- Leave `page_controller_test.exs:35` ("Demo personas") alone.

## Verification (executor, browser-free)
- `cd test/example && mix compile --warnings-as-errors` clean.
- `git diff --stat`: only test/example/ (incl. NEW demo_bar.ex). No priv/templates, no test/fixtures.
- `cd test/example && mix test test/example_web/controllers/session_controller_test.exs test/example_web/controllers/auth/sudo_controller_test.exs test/example_web/live/app_live_test.exs --include example_app` green. (If DB down: scripts/db/up.sh && source tmp/db.env if present, else note SKIPPED.)
- Commit in parts (component+API / wiring / JS+CSS / tests, or grouped). Code only — NOT docs.
- Live browser verification (login/sudo/authed identity + dropdown + /demo/use switch) is the orchestrator's job.
