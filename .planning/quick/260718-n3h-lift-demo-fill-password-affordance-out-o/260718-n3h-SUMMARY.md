---
phase: 260718-n3h
plan: 01
subsystem: example-demo-chrome
tags: [demo, css, example, ui]
requires: []
provides:
  - Relocated demo "Fill password" band as a full-width top strip in the example login page
affects:
  - test/example/lib/example_web/controllers/session_html.ex
  - test/example/priv/static/assets/css/app.css
tech-stack:
  added: []
  patterns:
    - "Reuse .vt-demo-switch band (authed-layout precedent) for the login demo band"
key-files:
  created: []
  modified:
    - test/example/lib/example_web/controllers/session_html.ex
    - test/example/priv/static/assets/css/app.css
decisions:
  - "Emit demo band as a sibling <div> above <section class=vt-auth> using HEEx multi-root, mirroring layouts.ex:138"
  - "Added minimal .vt-demo-switch--login { justify-content: center } modifier; base .vt-demo-switch and .vt-auth centering unchanged"
metrics:
  duration: ~10m
  completed: 2026-07-18
status: complete
---

# Phase 260718-n3h Plan 01: Lift Demo Fill-Password Affordance Out of Login Card Summary

Relocated the dev-only demo "Fill password" affordance out of the login card (`.vt-auth__panel`) and rendered it as a distinct full-width `.vt-demo-switch vt-demo-switch--login` band above the centered auth section, mirroring the authenticated app's top demo band — an example-only, dev-gated demo-chrome relocation with zero JS or test changes.

## What Was Built

### Task 1 — session_html.ex relocation (commit f616942c)
- Removed the `vt-demo-hint` block that sat inside `.vt-auth__panel` between the primary login form and the passkey form.
- Emitted the band as the FIRST element in `new/1`, a sibling `<div>` above `<section class="vt-auth vt-auth--login" …>` using HEEx multi-root output.
- Band uses class `vt-demo-switch vt-demo-switch--login`, gated by `:if={@demo_persona_hint}`.
- Preserved verbatim: `data-testid="demo-login-hint"`, `data-demo-fill-password`, `data-demo-password`, the `code.vt-code.vt-code--copy` email chip, and the copy "Disposable demo account — never use in production".
- Band contents in order: `span.vt-status-pill` (DEMO), `span.vt-demo-switch__label` (disposable-account copy), `code.vt-code.vt-code--copy` (email), ghost button (Fill password).

### Task 2 — app.css cleanup (commit 1a77a9ee)
- Deleted the dead `.vt-demo-hint` rules and their block comment (`.vt-demo-hint`, `.vt-demo-hint .vt-kicker`, `.vt-demo-hint .vt-copy`).
- Added a minimal `.vt-demo-switch--login { justify-content: center; }` modifier adjacent to the base `.vt-demo-switch` rules.
- Base `.vt-demo-switch` and `.vt-auth` centering left unchanged.

## Verification

- `cd test/example && mix compile --warnings-as-errors` — clean (no new warnings; the pre-existing `settings_live.ex:129` compile warning is unrelated to this change).
- `grep -c 'vt-demo-hint' …/app.css …/session_html.ex` — returns 0 for BOTH files.
- `git diff` confirms only the two target files changed; `admin_hooks.js`, `app.js`, and all test files are untouched (clean `git status`).
- `cd test/example && mix test test/example_web/controllers/session_controller_test.exs --include example_app` — **13 tests, 0 failures**. The refute test (dev_routes=false) passes UNCHANGED, proving the dev gate holds and the preserved tokens compile out. Note: these tests carry the `:example_app` tag and are excluded by default; `--include example_app` is required to run them.
- DB-gated test **RAN** (green). The stale `tmp/db.env` pointed at a dead port; re-booted the ephemeral test Postgres via `scripts/db/up.sh` (assigned port 53988), sourced the fresh env, and the suite passed.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- Files exist:
  - FOUND: test/example/lib/example_web/controllers/session_html.ex
  - FOUND: test/example/priv/static/assets/css/app.css
- Commits exist:
  - FOUND: f616942c (Task 1)
  - FOUND: 1a77a9ee (Task 2)
