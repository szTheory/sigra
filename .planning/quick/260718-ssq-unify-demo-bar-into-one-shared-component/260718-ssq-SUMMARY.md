---
quick_id: 260718-ssq
title: "Unify the demo bar into one shared component (login + sudo + authed app)"
status: complete
---

# Phase quick 260718-ssq: Unify demo bar into one shared component — Summary

Collapsed three divergent inline `vt-demo-switch` bars (login, sudo, authed app)
into a single shared `ExampleWeb.Components.DemoBar.demo_bar/1` with a unified
`data-testid="demo-bar"`, centralized persona lookup in `Example.Demo.Personas`,
and repointed the JS persona switch at `/demo/use/`. Example-only, dev-gated.

## What changed

**Task 1 — shared component + Personas API**
- NEW `test/example/lib/example_web/components/demo_bar.ex` — `demo_bar/1` with
  attrs `persona`/`personas`/`fill`/`centered`, exact PLAN markup, `data-testid="demo-bar"`.
- `personas.ex` — added `by_key/1`, `by_email/1`, `options/0` + private `enrich/1`
  (adds `:key` local-part + `:feature` from `feature_map/0`).

**Task 2 — wire 3 call sites**
- `layouts.ex` — `import`ed DemoBar; `demo_persona_switch/1` now assigns
  `by_email(current_scope.user.email)` + `options()` and renders `<.demo_bar>`;
  `app/1` `:if={@dev_routes? && @current_scope}` gate unchanged.
- `session_controller.ex` — `demo_persona_hint/1` returns `by_key(params["demo"])`
  under dev / `nil` otherwise; `demo_persona_options/0` returns `options()` / `[]`;
  render now passes `demo_persona:` + `demo_personas:`. Non-gated always-on email
  prefill (`demo_persona_lookup/1`) untouched.
- `session_html.ex` — `import`ed DemoBar; replaced `demo-login-hint` block with
  `<.demo_bar :if={@demo_personas != []} … fill={true} centered={true} />`.
- `sudo_controller.ex` — `demo_persona_for/1` uses `by_email` (enriched) under dev;
  added dev-gated `demo_persona_options/0`; `demo_personas:` passed on both render
  paths (new + create-failure).
- `sudo_html.ex` — `import`ed DemoBar; replaced `demo-sudo-hint` block with `<.demo_bar>`.

**Task 3 — JS + CSS**
- `admin_hooks.js` + `priv/static/assets/js/app.js` — `installDemoPersonaSwitch`
  navigates to `/demo/use/<value>` (was `/users/log_in?demo=…`). `installDemoPasswordFill`
  unchanged.
- `app.css` — added `.vt-demo-switch__identity/__name/__desc` rules.

**Task 4 — tests**
- `session_controller_test.exs`, `sudo_controller_test.exs`, `app_live_test.exs`
  refutes collapsed to `data-testid="demo-bar"` (+ `data-demo-fill-password`,
  `data-demo-persona-switch`). Email-prefill assert + `/demo/use` 404 env-guard kept.

## Verification

- `cd test/example && mix compile --warnings-as-errors` — clean (pre-existing
  `/dev/mailbox` route warning from settings_live.ex under test env is unrelated).
- `git diff --stat` — scoped to `test/example/` only (incl. NEW demo_bar.ex). No
  `priv/templates/`, no `test/fixtures/`.
- `mix test session_controller_test sudo_controller_test app_live_test --include example_app`
  — 17 tests, 0 failures (DB up via tmp/db.env).

## Commits

- `7988e626` feat: shared demo_bar component + Personas lookup API
- `43219051` refactor: wire 3 demo-bar call sites to shared component
- `272a87ac` feat: point persona switch at /demo/use + demo-bar identity CSS
- `8f7d794c` test: refute unified demo-bar testid across 3 dev-gating tests

## Deviations from Plan

None — plan executed as written.

## Self-Check: PASSED
- FOUND: test/example/lib/example_web/components/demo_bar.ex
- FOUND commits: 7988e626, 43219051, 272a87ac, 8f7d794c
