---
quick_id: 260718-sar
title: "Demo-chrome coherence + admin users reorder (3 parts)"
status: ready
---

# 3 parts, 3 atomic commits (A/B/C). Sequential on main.

Parts A/B example-only (dev-gated demo chrome). Part C is lib-owned admin + the design-gallery
twin. NO `priv/templates/`, NO `test/fixtures/`. Confirmed `installDemoPasswordFill` is absent from
priv/templates (example-only).

## Task A — demo-switch bar above the app header
`test/example/lib/example_web/components/layouts.ex` (`app/1` `~H`):
- MOVE the block (currently ~lines 98–101):
  `<.demo_persona_switch :if={@dev_routes? && @current_scope} current_scope={@current_scope} />`
  to be the FIRST element of the template, ABOVE `<header class="vt-app-header">` (~line 60).
- LEAVE `<.impersonation_banner …>` where it is (below the header).
`test/example/priv/static/assets/css/app.css`: update the stale comment above `.vt-demo-switch`
(~lines 204–206) from "slim strip below the app header" → "above the app header". No rule change.
Verify: `app_live_test.exs` still green (its `refute "demo-persona-switch"` is order-agnostic).

## Task B — sudo page demo Fill-password band
`test/example/lib/example_web/controllers/auth/sudo_controller.ex`:
- Add a dev-gated helper (mirror the `demo_persona_hint` gate in session_controller.ex):
  ```elixir
  if Application.compile_env(:example, :dev_routes) do
    defp demo_persona_for(user), do: Enum.find(Example.Demo.Personas.all(), &(&1.email == user.email))
  else
    defp demo_persona_for(_user), do: nil
  end
  ```
- Pass `demo_persona: demo_persona_for(conn.assigns.current_scope.user)` to `render(conn, :new, …)`
  on BOTH render paths: `new/2` AND the `create/2` failure re-render (~line 48).
- The failure re-render also omits `form:` today (latent crash on wrong password → `@form` KeyError).
  Add `form:` there too: `form: Phoenix.Component.to_form(%{"password" => ""}, as: "sudo")`.
`test/example/lib/example_web/controllers/auth/sudo_html.ex`: add a standalone band as the FIRST
element (sibling ABOVE `<section class="vt-auth" data-testid="sudo">`):
```heex
<div :if={@demo_persona} class="vt-demo-switch vt-demo-switch--login" data-testid="demo-sudo-hint">
  <span class="vt-status-pill">DEMO</span>
  <span class="vt-demo-switch__label">Disposable demo account — never use in production</span>
  <code class="vt-code vt-code--copy">{@demo_persona.email}</code>
  <button type="button" class="vt-btn vt-btn--ghost"
          data-demo-fill-password data-demo-password={@demo_persona.password}>Fill password</button>
</div>
```
(Reuses `vt-demo-switch--login` — no new CSS. Distinct testid `demo-sudo-hint`.)
`test/example/assets/js/admin_hooks.js` AND `test/example/priv/static/assets/js/app.js` (BOTH):
in `installDemoPasswordFill()`, broaden the target selector:
`document.querySelector('input[name="user[password]"]')` →
`document.querySelector('input[name="user[password]"], input[name="sudo[password]"]')`.
Test: add a sudo controller test (create `test/example/test/example_web/controllers/auth/sudo_controller_test.exs`
or extend an existing one) using `register_and_log_in_user` — under `mix test` (`dev_routes=false`),
`GET /users/sudo` must REFUTE: `"Disposable demo account"`, `data-demo-fill-password`,
`data-testid="demo-sudo-hint"`. (Dev-gated → compiled out.)

## Task C — admin users: User health above Find users
`lib/sigra/admin/live/users_index_live.ex` (`render/1`):
- MOVE the three `<% … %>` assign blocks (`total_users`/`locked_users`/`deletion_scheduled_users`,
  ~lines 179–181) TOGETHER WITH the `<section aria-labelledby="users-health-heading">` block
  (~lines 182–213) to ABOVE the `<section aria-labelledby="find-users-heading">` block (~lines 85–177).
  The `<% … %>` assigns MUST remain immediately above the User health `<section>` (used there).
  New order: page header → scope ribbon → User health → Find users → results. Spacing is the
  parent `sg-stack--6` symmetric gap → preserved automatically; DO NOT touch CSS/spacing.
`test/example/lib/example_web/live/admin/design_gallery_live.ex`: reorder the twin board
`board-cfg-users-list` (~lines 1238–1262) to match (User health above Find users).
Baselines: this shifts `global-user-index-*` (admin-checkpoints) + `board-cfg-users-list-*`
(admin-design) PNGs. DO NOT recapture locally (darwin pixel drift) — recapture is CI-native via the
recapture gate. Note it in SUMMARY as the one CI follow-through; do NOT modify any *.png baseline.
Verify: `admin_user_filters_live_test.exs` (presence, order-agnostic) stays green.

## Verification (executor, browser-free)
- `cd test/example && mix compile --warnings-as-errors` clean (lib compiles too).
- `git diff --stat`: Parts A/B under test/example/; Part C = lib/sigra/…/users_index_live.ex + example design_gallery_live.ex. NO priv/templates, NO test/fixtures, NO *.png changes.
- `cd test/example && mix test test/example_web/controllers/session_controller_test.exs test/example_web/controllers/auth/sudo_controller_test.exs test/example_web/live/admin/admin_user_filters_live_test.exs --include example_app` — green. (If DB down: `scripts/db/up.sh && source tmp/db.env` if present, else note SKIPPED — orchestrator runs + live-verifies.)
- Commit atomically per part (A, B, C). Code only — NOT docs. Live browser verification is the orchestrator's job.
