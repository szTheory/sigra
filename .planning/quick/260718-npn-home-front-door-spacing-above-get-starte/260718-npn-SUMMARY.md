---
phase: quick-260718-npn
plan: 01
subsystem: example-demo-home
tags: [example, home, css, heex, operator-login]
requires: []
provides:
  - Home get-started section rhythm (top margin)
  - Operator aside two one-click login pickers
affects:
  - test/example/priv/static/assets/css/app.css
  - test/example/lib/example_web/controllers/page_html/home.html.heex
key-files:
  created: []
  modified:
    - test/example/priv/static/assets/css/app.css
    - test/example/lib/example_web/controllers/page_html/home.html.heex
decisions:
  - "Route hints use vt-code (non-copyable) not vt-code--copy — they are destinations, not credentials."
  - "Pickers route through the real /users/log_in?demo=admin|morgan prefilled login (mirrors evaluator cards); never auto-submit."
metrics:
  duration: ~4m
  completed: 2026-07-18
status: complete
---

# Quick 260718-npn: Home front-door spacing above Get started + operator pickers Summary

Example-only home polish: added section rhythm above `#get-started` and converted the
wordy "One login, two jobs" operator aside into two inline one-click "Sign in as"
persona pickers routing through the real prefilled `/users/log_in?demo=…` login.

## Tasks Completed

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | CSS — get-started top margin + operator-list grid | e2ed4439 | test/example/priv/static/assets/css/app.css |
| 2 | HEEx — operator aside to two inline pickers | a5796600 | test/example/lib/example_web/controllers/page_html/home.html.heex |

## What Changed

**Task 1 (app.css):**
- Added `#get-started { margin-top: var(--sg-space-5); }` beside `.vt-brand-lab` (matching its rhythm).
- Extended existing `.vt-panel--operator .vt-operator-list li` rule with `display: grid;` + `gap: var(--sg-space-2);`, keeping the original `background: color-mix(...)` declaration.
- `.vt-panel__title` untouched.

**Task 2 (home.html.heex):**
- Kept `data-testid="home-shared-login-copy"` and the `<p class="vt-kicker">One login, two jobs.</p>` verbatim.
- Tightened title to `Sign in as an operator.` + single context line "Same Tasklane login as customers — operator personas continue into Sigra admin."
- Removed the old prose `<p class="vt-copy">` shared-login sentence.
- Replaced the two prose/code-chip `<li>`s with two picker `<li>`s: name-block `<div>` (`<strong>` + `.vt-copy` destination hint in non-copyable `<code class="vt-code">`) plus full-width `vt-btn vt-btn--primary vt-btn--block` button routing through `~p"/users/log_in?#{%{demo: "admin"|"morgan"}}"`.

## Deviations from Plan

None - plan executed exactly as written.

## Verification

- `cd test/example && mix compile --warnings-as-errors` — clean (the `/dev/mailbox` warning originates from pre-existing `settings_live.ex`, not this task's files).
- `git diff` — only the two target files changed; no JS/test/installer/golden fixture touched.
- `cd test/example && mix test test/example_web/controllers/page_controller_test.exs --include example_app` — **RAN, GREEN, UNCHANGED**: 3 tests, 0 failures (local Postgres on :5432 available; tmp/db.env sourced). No assertion weakened.
- Live browser verification is left to the orchestrator.

## Self-Check: PASSED

- FOUND: test/example/priv/static/assets/css/app.css (commit e2ed4439)
- FOUND: test/example/lib/example_web/controllers/page_html/home.html.heex (commit a5796600)
- FOUND commit e2ed4439
- FOUND commit a5796600
