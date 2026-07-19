---
phase: quick-260718-i1m
plan: 01
subsystem: ui
tags: [demo, front-door, elixir, phoenix, heex, playwright, css, javascript]

requires: []
provides:
  - "vt-code decoupled: base .vt-code is pure formatting, opt-in .vt-code--copy carries click-to-copy"
  - "Home page re-sequenced: orient -> get-started (5-persona picker) -> showcase -> reference"
  - "Real login prefill via ?demo={key} (any build) + dev-only password-hint/Fill affordance + /demo/use/:persona fast-switch"
  - "SEED-008 planted: generated-host first-run admin-bootstrap gap"
affects: [demo-example-app, installer-dx-future-milestone]

tech-stack:
  added: []
  patterns:
    - "Compile-time dev_routes gate captured as a module attribute (@dev_routes?) and explicitly assigned into assigns before a ~H template — Application.compile_env/2-3 cannot be called inside a function body, including inside a ~H template's enclosing function"
    - "Single source of truth (Personas.featured_keys/0) shared by two independently-gated call sites (always-on home picker, dev-only switch bar)"

key-files:
  created:
    - .planning/seeds/SEED-008-generated-host-first-run-admin-bootstrap.md
  modified:
    - test/example/assets/js/admin_hooks.js
    - test/example/priv/static/assets/js/app.js
    - test/example/priv/static/assets/css/app.css
    - test/example/lib/example_web/controllers/page_html/home.html.heex
    - test/example/lib/example_web/controllers/page_controller.ex
    - test/example/lib/example_web/live/demo/credentials_live.ex
    - test/example/lib/example/demo/personas.ex
    - test/example/lib/example_web/controllers/session_controller.ex
    - test/example/lib/example_web/controllers/session_html.ex
    - test/example/lib/example_web/router.ex
    - test/example/lib/example_web/components/layouts.ex
    - test/example/lib/example_web/user_auth.ex
    - test/example/priv/playwright/tests/demo-showcase.spec.ts
    - test/example/test/example_web/controllers/page_controller_test.exs
    - test/example/test/example/demo/personas_test.exs
    - test/example/test/example_web/controllers/session_controller_test.exs
    - test/example/test/example_web/live/app_live_test.exs

key-decisions:
  - "Application.compile_env cannot be called inside a ~H template's enclosing function body — fixed by capturing the dev_routes gate as a module attribute (@dev_routes?) at layouts.ex module-body scope and explicitly assigning it into assigns before the template, per the harness's own PITFALL note about @dev_routes reading assigns not an attribute"
  - "Sign-in button label uses persona display_name (e.g. 'Sign in as Admin (operator)') rather than a shorter alias, since display_name is the existing single source of truth and no separate short-name field exists"

requirements-completed: [FRONTDOOR-01, FRONTDOOR-02, FRONTDOOR-03, FRONTDOOR-04]

coverage:
  - id: D1
    description: "Copy-scope fix: base .vt-code is pure formatting; only .vt-code--copy carries click-to-copy, mirrored identically in admin_hooks.js and served app.js; route chips are real <a class=vt-link> links"
    requirement: "FRONTDOOR-01"
    verification:
      - kind: unit
        ref: "grep-based plan verify block (Task 1) — cursor:copy absent from base .vt-code, present in .vt-code--copy, both JS files require --copy suffix in delegate + label selectors"
        status: pass
      - kind: automated_ui
        ref: "test/example/priv/playwright/tests/demo-showcase.spec.ts:850 (cursor assertion retargeted to code.vt-code--copy) — NOT run by executor, see Orchestrator Must Run Post-Merge"
        status: unknown
    human_judgment: false
  - id: D2
    description: "Home page re-sequenced orient -> get-started (5-persona picker with working Sign in as buttons) -> showcase -> reference"
    requirement: "FRONTDOOR-02"
    verification:
      - kind: unit
        ref: "test/example/test/example_web/controllers/page_controller_test.exs#GET / (id=get-started, dave@demo.tasklane.test, demo=dave, Sign in as)"
        status: pass
      - kind: unit
        ref: "test/example/test/example/demo/personas_test.exs#featured_keys/0"
        status: pass
    human_judgment: false
  - id: D3
    description: "?demo={key} prefills the real login email in any build; login never auto-submits; no password ever appears in a URL"
    requirement: "FRONTDOOR-03"
    verification:
      - kind: unit
        ref: "test/example/test/example_web/controllers/session_controller_test.exs#GET /users/log_in?demo={key} (front-door persona prefill) prefills the email field... / does not crash and does not prefill for an unknown persona key"
        status: pass
      - kind: other
        ref: "git diff 3888420f..HEAD | grep -E 'password=.+@' — only match is the dev-gated data-demo-password attribute, never an href"
        status: pass
    human_judgment: false
  - id: D4
    description: "Dev-only password-hint/Fill affordance + /demo/use/:persona fast-switch + demo-persona-switch bar all exist under dev_routes=true and are provably absent under mix test"
    requirement: "FRONTDOOR-04"
    verification:
      - kind: unit
        ref: "test/example/test/example_web/controllers/session_controller_test.exs#under mix test (dev_routes=false), the password hint is compiled out even with a valid demo key / env-guard: GET /demo/use/:persona route returns 404"
        status: pass
      - kind: unit
        ref: "test/example/test/example_web/live/app_live_test.exs#greets a standard user and hides operator surfaces (refute html =~ demo-persona-switch)"
        status: pass
      - kind: automated_ui
        ref: "Live click-through of Fill password button + /demo/use/:persona round trip against a booted dev_routes=true server — NOT run by executor, see Orchestrator Must Run Post-Merge"
        status: unknown
    human_judgment: false
  - id: D5
    description: "SEED-008 planted documenting the generated-host first-run admin-bootstrap gap"
    verification:
      - kind: unit
        ref: "plan verify block (Task 4) — grep confirms sigra_admin_policy, CWE-798, sigra.gen.admin, and both key file paths present in the seed body"
        status: pass
    human_judgment: false

duration: 30min
completed: 2026-07-18
status: complete
---

# Quick Task 260718-i1m: Demo front-door get-started affordance Summary

**Decoupled the demo's click-to-copy affordance from route chips (opt-in `vt-code--copy` marker), rebuilt the Tasklane home page around a curated 5-persona get-started picker that drives a real prefilled `/users/log_in?demo={key}`, and added a dev-only password-hint/Fill button plus a `/demo/use/:persona` fast-switch — all routed through Sigra's real auth with zero credentials ever leaking into a URL.**

## Performance

- **Duration:** ~30 min
- **Tasks:** 4/4 completed
- **Files modified:** 17 modified + 1 created (SEED-008.md) = 18, matching the plan's `files_modified` frontmatter exactly (verified via `git diff --name-only <merge-base>..HEAD`)

## Accomplishments

- Base `.vt-code` is now pure inline-code formatting (no `cursor: copy`); the new opt-in `.vt-code--copy` class is the sole click-to-copy affordance, mirrored identically in `admin_hooks.js` (source) and the served `priv/static/assets/js/app.js` — both the delegate selector and the label/hint selector require the `--copy` suffix.
- Route-shaped code chips touched by this plan (`/users/log_in`, `/admin`, `/admin/organizations/acme-corp`) are now real `<a class="vt-link">` links, not copy-styled `<code>`.
- Home page IA re-sequenced: hero (single clear primary CTA anchoring to `#get-started`) → new `#get-started` section (5-persona picker: admin, morgan, alice, pat, dave — each with a working "Sign in as {persona}" button targeting `/users/log_in?demo={key}`) → `vt-brand-lab` showcase (moved down, internals unchanged) → standalone "Seeded evidence" panel (unwrapped from the old shared `vt-card-grid`, which it and the old "Start with these accounts" panel used to share — that panel is now fully replaced by the get-started section).
- `Example.Demo.Personas.featured_keys/0` is the single source of truth for the curated 5-persona set, consumed by both the home-page picker (`page_controller.ex`) and the logged-in fast-switch bar (`layouts.ex`).
- `/users/log_in?demo={key}` prefills the real email field in **any** build (never dev-gated — it's a non-secret convenience). A second, dev_routes-gated hint block shows the persona's password behind a gesture-only "Fill password" button (`type="button"`, never auto-fills on page load).
- New dev-only `GET /demo/use/:persona` route (`SessionController.demo_switch/2`) logs out and redirects straight into a prefilled login for the new persona. Implemented by extending `UserAuth.log_out_user/1` to `log_out_user/2` with an optional `:to` redirect target (backward compatible — both pre-existing zero-arg call sites still work).
- New `Layouts.demo_persona_switch/1` component renders a "Demo personas" switch bar in the authenticated app header — deliberately a separate module/CSS-namespace (`vt-demo-switch`) from Sigra's `impersonation_banner`, and never says "impersonate". Gated by a module-attribute-captured `Application.compile_env(:example, :dev_routes)` check (see Deviations — the plan's inline `:if={Application.compile_env(...)}` guidance didn't actually compile).
- SEED-008 planted at `.planning/seeds/` documenting the generated-host first-run admin-bootstrap gap (stub `sigra_admin_policy.ex` always denies; no generated path to create + promote the first operator) for a future installer-DX milestone.

## Task Commits

Each task was committed atomically:

1. **Task 1: Copy-scope decouple** — `d4f872c1` (fix)
2. **Task 2: Front-door IA re-sequence** — `20c877ab` (feat)
3. **Task 3: Prefilled real login + dev-only fast switch** — `29cc5c3d` (feat)
4. **Task 4: Plant SEED-008** — `bd113afb` (docs)

**Plan metadata:** committed by the orchestrator after this SUMMARY (per harness contract — quick-task executor does not commit docs).

## Files Created/Modified

- `test/example/priv/static/assets/css/app.css` — `.vt-code`/`.vt-code--copy` split, `.vt-demo-hint`, `.vt-demo-switch` + `.vt-demo-switch__label`
- `test/example/assets/js/admin_hooks.js` / `test/example/priv/static/assets/js/app.js` — copy-delegate selectors retargeted to `--copy`; new `installDemoPasswordFill()` delegated handler, booted alongside `installCopyDelegate()`
- `test/example/lib/example_web/controllers/page_html/home.html.heex` — full IA re-sequence, operator-panel + seed-evidence route/credential chip conversion
- `test/example/lib/example_web/controllers/page_controller.ex` — `featured_credentials` now filters through `Personas.featured_keys/0`
- `test/example/lib/example/demo/personas.ex` — new `featured_keys/0`
- `test/example/lib/example_web/live/demo/credentials_live.ex` — email/password chips marked `vt-code--copy`
- `test/example/lib/example_web/controllers/session_controller.ex` — `new/2` email prefill via `demo_persona_lookup/1` (always-on) + `demo_persona_hint/1` (dev-gated); new `demo_switch/2`
- `test/example/lib/example_web/controllers/session_html.ex` — dev-gated `demo-login-hint` block with gesture-only Fill button
- `test/example/lib/example_web/router.ex` — dev_routes-gated `GET /demo/use/:persona`
- `test/example/lib/example_web/components/layouts.ex` — new `demo_persona_switch/1` component + compile-time gate wiring
- `test/example/lib/example_web/user_auth.ex` — `log_out_user/1` → `log_out_user/2` with optional `:to`
- `test/example/priv/playwright/tests/demo-showcase.spec.ts` — cursor assertion retargeted to `code.vt-code--copy`
- `test/example/test/example_web/controllers/page_controller_test.exs`, `test/example/test/example/demo/personas_test.exs`, `test/example/test/example_web/controllers/session_controller_test.exs`, `test/example/test/example_web/live/app_live_test.exs` — new/updated assertions
- `.planning/seeds/SEED-008-generated-host-first-run-admin-bootstrap.md` — new seed

## Decisions Made

- **`Application.compile_env` cannot be called inside a `~H` template's enclosing function body.** The plan's discovery/PITFALL note directed calling `Application.compile_env(:example, :dev_routes)` directly inside the `:if={...}` guard at the `app/1` call site. This fails to compile: `** (RuntimeError) Application.compile_env/3 cannot be called inside functions, only in the module body` — because `~H` compiles as part of the enclosing `def app(assigns) do ... end` function, which is still "inside a function" even though the macro call textually sits inside a template. Fixed by capturing the gate as a module attribute (`@dev_routes? Application.compile_env(:example, :dev_routes, false)`, legal at module-body scope) and explicitly assigning it into `assigns` (`assigns = assign(assigns, :dev_routes?, @dev_routes?)`) before the `~H` block, so the template's `@dev_routes?` correctly reads `assigns.dev_routes?` — consistent with the plan's own guidance that `@name` inside `~H` always reads assigns, never a module attribute directly.
- **`mix test` excludes `@moduletag :example_app` by default** (`test/test_helper.exs: ExUnit.start(exclude: [:example_app])`). `session_controller_test.exs` carries this tag, so the plan's literal verify command (`mix test test/example_web/controllers/session_controller_test.exs ...`) silently ran 0 of those tests. Ran with `--include example_app` locally to actually execute and confirm the new assertions pass — flagging this for the orchestrator in case its own re-run of the verify command needs the same flag.
- Sign-in button copy uses each persona's `display_name` (e.g., "Sign in as Admin (operator)") rather than inventing a separate short-name field — `display_name` is the existing single source of truth in `Personas.all/0`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed non-compiling `Application.compile_env` call inside a `~H` template**
- **Found during:** Task 3 (`mix compile --warnings-as-errors` failed with `RuntimeError: Application.compile_env/3 cannot be called inside functions, only in the module body`)
- **Issue:** The plan's own PITFALL guidance for `layouts.ex` directed writing `:if={Application.compile_env(:example, :dev_routes) && @current_scope}` directly inside the `app/1` component's `~H` template. This is illegal — `~H` templates compile as part of their enclosing `def`, and `Application.compile_env` can only be called at module-body scope.
- **Fix:** Captured the gate as a module attribute `@dev_routes? Application.compile_env(:example, :dev_routes, false)` at the top of `layouts.ex` (module-body scope, legal), then explicitly assigned it into `assigns` inside `app/1` before the template (`assigns = assign(assigns, :dev_routes?, @dev_routes?)`), and referenced `@dev_routes?` in the `:if` guard (which now correctly reads `assigns.dev_routes?`).
- **Files modified:** `test/example/lib/example_web/components/layouts.ex`
- **Verification:** `mix compile --warnings-as-errors` clean; `test/example_web/live/app_live_test.exs` asserts the switch bar is absent under `mix test` (dev_routes=false).
- **Committed in:** `29cc5c3d` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — compile-time bug in the plan's own guidance)
**Impact on plan:** Necessary for correctness — the plan as literally written would not compile. No scope creep; the fix preserves the plan's intended behavior (dev_routes-gated switch bar, correct `assigns` semantics) exactly.

## Issues Encountered

- `mix` / Hex / Rebar were not yet installed in this fresh worktree's toolchain state; ran `mix local.hex --force`, `mix local.rebar --force`, and `mix deps.get` once at the start of Task 1 to unblock compilation. Not a plan deviation — standard one-time worktree bootstrap.
- No live Postgres was assumed reachable per the harness's SOFT GATE guidance, but a live Postgres **was** reachable on `localhost:5432` with a pre-existing `example_test` database in this worktree, so all `mix test` runs (including the full suite) executed against a real database rather than falling back to compile-only verification.

## ORCHESTRATOR MUST RUN POST-MERGE

Per the plan's own scope boundary, these require a booted `dev_routes=true` server and were NOT run by this executor:

1. **Click-to-copy + toast behavior** — click a `vt-code--copy` chip, confirm clipboard write + `.sg-toast` "Copied" message; confirm non-`--copy` chips (route links, domain/local-origin strips, email preview address) do NOT carry `cursor: copy` and are NOT click-to-copy.
2. **Persona picker click-through** — from `/`, click a "Sign in as {persona}" button in `#get-started`, confirm arrival at `/users/log_in?demo={key}` with the email field pre-filled and the form NOT auto-submitted.
3. **Fill-password button DOM effect** — on the login page with `?demo={key}`, confirm the dev-only hint renders, click "Fill password", confirm `#user_password` is populated (bubbling `input` event fires, no page reload, no auto-submit).
4. **`/demo/use/:persona` round trip** — while logged in, confirm the "Demo personas" switch bar renders (distinct from any impersonation banner), click a persona link, confirm log-out + redirect into a prefilled login for the new persona (never both logs-out-and-in in one hop, never bypasses the real login form).
5. **`demo-showcase.spec.ts` full run** — the `code.vt-code--copy` selector retarget (Task 1) is a source-only static edit; run the full Playwright spec against the booted demo to confirm no other assertion regressed from the IA re-sequence (metric-grid section-spacing selector, "Open Sigra Admin" link accessible-name/href, featured-personas testid).
6. **`mix test --include example_app`** — this worktree ran the full suite with `--include example_app` since `session_controller_test.exs` is tagged and excluded by default (`test/test_helper.exs`). Confirm the orchestrator's own CI/verify path either already includes this tag globally or re-runs with `--include example_app` so the new assertions in this file are not silently skipped.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Front-door affordance is complete and self-consistent (grep + `mix test` proven); ready for live Playwright verification post-merge per the items above.
- SEED-008 is planted and ready to be picked up in a future installer-DX milestone — no action required now.
- No blockers.

---
*Quick task: 260718-i1m*
*Completed: 2026-07-18*

## Self-Check: PASSED

All 4 task commits (d4f872c1, 20c877ab, 29cc5c3d, bd113afb) confirmed in git log.
All 18 files listed in the plan's `files_modified` frontmatter confirmed present on disk,
and `git diff --name-only <merge-base 3888420f>..HEAD` matches that list exactly (no
unintended files touched). No missing items.
