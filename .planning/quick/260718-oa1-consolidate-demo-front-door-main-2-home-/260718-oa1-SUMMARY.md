---
phase: 260718-oa1
plan: 01
subsystem: example-demo-front-door
tags: [demo, example-only, dev-gated, front-door, login-switcher]
requires: []
provides: [DEMO-FRONTDOOR]
affects:
  - test/example/lib/example_web/controllers/page_html/home.html.heex
  - test/example/lib/example_web/live/demo/credentials_live.ex
  - test/example/lib/example_web/controllers/session_html.ex
key-files:
  created: []
  modified:
    - test/example/lib/example_web/controllers/page_html/home.html.heex
    - test/example/lib/example_web/controllers/page_controller.ex
    - test/example/test/example_web/controllers/page_controller_test.exs
    - test/example/priv/static/assets/css/app.css
    - test/example/lib/example_web/live/demo/credentials_live.ex
    - test/example/test/example_web/live/demo/credentials_live_test.exs
    - test/example/lib/example_web/controllers/session_controller.ex
    - test/example/lib/example_web/controllers/session_html.ex
    - test/example/assets/js/admin_hooks.js
    - test/example/priv/static/assets/js/app.js
decisions:
  - "Kept the seeded-evidence morgan@ email assert in page_controller_test — Morgan's email survives in the seeded-evidence org-admin hint (not deleted by design), so the assert still matches rendered reality and coverage is not weakened."
metrics:
  duration: ~15m
  completed: 2026-07-18
  tasks: 3
  files: 10
  commits: 3
status: complete
---

# Phase 260718-oa1 Plan 01: Consolidate Demo Front-Door Summary

Consolidated the example demo front-door across three surfaces (home, /demo/credentials, /users/log_in) so the fast path is two operator pickers and the full 10-persona roster is one low-friction click away — every path routes through the REAL prefilled login (`?demo=<key>`), no bypass/auto-submit. All changes example-only; no installer template or golden fixture touched.

## What was built

### Task 1 — Home (commit `afd09736`)
- Deleted the entire `<section id="get-started">` evaluator-persona card (the `.vt-panel` that dumped raw email/password chips per featured persona).
- Moved `id="get-started"` onto the operator `<aside>` (keeps `data-testid="home-shared-login-copy"`) so the hero CTA anchor `href="#get-started"` still lands on the picker.
- Added `<a href="/demo/credentials" class="vt-btn vt-btn--ghost vt-btn--block">View all 10 personas →</a>` above `<ul class="vt-operator-list">` (count confirmed = 10 via `Personas.all()`).
- Removed the `featured_credentials` computation + assign (and the now-unused `feature_map` fetch) from `PageController.home/2`.
- Updated `page_controller_test.exs` to the new IA: dropped asserts for deleted content (`data-testid="home-featured-personas"`, `admin@…`/`pat@…`/`dave@…` emails, `demo=dave`), added `demo=admin` + `href="/demo/credentials"`, kept `id="get-started"` / `/admin/organizations/acme-corp` / `Sign in as` / `>10<` / seeded `morgan@…`.
- Removed the dead `#get-started { margin-top: … }` CSS rule.

### Task 2 — /demo/credentials (commit `f9ac8c50`)
- Replaced the **Email** + **Password** columns in `<table class="vt-table">` with a single action column: `<a href={~p"/users/log_in?#{%{demo: c.local}}"} class="vt-btn vt-btn--primary">Sign in as {c.display_name}</a>`. New layout: `Persona | Auth feature demonstrated | Sign in`.
- Preserved per-row `data-testid="demo-persona-row-#{c.local}"`, `data-testid="demo-credentials-table"`, `data-testid="demo-dev-only-badge"`, and the header `.vt-panel` copy (admin@/morgan@/acme-corp).
- Reworded the footer note to note the password is filled at login; kept "Never use in production."
- Added a `Sign in as` / `demo=admin` button assertion to `credentials_live_test.exs`.

### Task 3 — /users/log_in persona switcher (commit `5cef2d6d`)
- Added dev-gated `demo_persona_options/0` in `SessionController` (mirrors the `demo_persona_hint/1` `compile_env(:example, :dev_routes)` gate; returns `[]` in non-dev/test). Passed `demo_personas: demo_persona_options()` into `render(conn, :new, …)`.
- Flipped the demo band gate in `session_html.ex` from `:if={@demo_persona_hint}` to `:if={@demo_personas != []}`; made the credential label / `<code>` email / `data-demo-fill-password` button each `:if={@demo_persona_hint}`; added a fallback "Demo personas — never use in production" label and a low-noise `<select class="vt-demo-switch__select" data-demo-persona-switch …>` with a disabled placeholder + one option per persona (current persona pre-selected). Preserved verbatim `data-testid="demo-login-hint"`, `data-demo-fill-password`, and "Disposable demo account".
- Added idempotent, delegated `installDemoPersonaSwitch()` (change listener → `window.location.assign("/users/log_in?demo=" + encodeURIComponent(value))`) to BOTH `assets/js/admin_hooks.js` and the served `priv/static/assets/js/app.js` mirror, each with a registration line beside `installDemoPasswordFill();`.
- Added a minimal, theme-token `.vt-demo-switch__select` CSS rule.

## Deviations from Plan

**1. [Rule 1 — coverage fidelity] Kept the seeded-evidence `morgan@…` email assert.**
- **Found during:** Task 1
- **Issue:** The orchestrator/plan constraint listed the `morgan@…` email assert among asserts to drop, on the premise Morgan survives "only as `demo=morgan`, not as an email." In reality `morgan@demo.tasklane.test` is still rendered in the untouched seeded-evidence org-admin hint (`home.html.heex`).
- **Fix:** Kept the assert (it still passes and matches rendered reality). The plan's overriding directive — "only drop asserts whose content is deleted by design; run the test and make it match rendered reality" — governs. Coverage is preserved rather than gratuitously weakened.
- **Files:** `test/example/test/example_web/controllers/page_controller_test.exs`
- **Commit:** `afd09736`

No other deviations. No auth gates. No architectural changes.

## Verification

- `cd test/example && mix compile --warnings-as-errors` — clean (the `/dev/mailbox` warning only appears under `MIX_ENV=test` from the untouched `settings_live.ex` where dev_routes compile out; pre-existing, out of scope).
- `cd test/example && mix test test/example_web/controllers/page_controller_test.exs test/example_web/live/demo/credentials_live_test.exs test/example_web/controllers/session_controller_test.exs --include example_app` — **18 tests, 0 failures** (ran against the ephemeral test Postgres from `tmp/db.env`, port 53988). Non-dev session refutes (`demo-login-hint`, `data-demo-fill-password`, "Disposable demo account") stay green because `demo_persona_options()` returns `[]` under `mix test`.
- `git diff --stat` (committed range) touches ONLY `test/example/` files — no `priv/templates/`, no `test/fixtures/`.
- `grep -rl installDemoPasswordFill/installDemoPersonaSwitch/data-demo-persona-switch priv/templates/` — ABSENT (demo JS confirmed not in installer templates).

## Commits
- `afd09736` — feat(260718-oa1): consolidate demo home front-door
- `f9ac8c50` — feat(260718-oa1): replace /demo/credentials columns with per-persona sign-in buttons
- `5cef2d6d` — feat(260718-oa1): add dev-only persona switcher to the login band

## Self-Check: PASSED
- All three commits exist in `git log`.
- All 10 modified files present and changed.
- 18/18 targeted tests green; compile clean; diff scoped to `test/example/`.

## Notes for orchestrator
Live browser verification (home main-2 layout, /demo/credentials buttons, login switcher navigation + pre-selection) is deferred to the orchestrator against the running demo — the executor did not drive a browser.
