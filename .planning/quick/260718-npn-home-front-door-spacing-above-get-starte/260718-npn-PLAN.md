---
phase: quick-260718-npn
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - test/example/priv/static/assets/css/app.css
  - test/example/lib/example_web/controllers/page_html/home.html.heex
autonomous: true
requirements:
  - QUICK-260718-npn
must_haves:
  truths:
    - "A visible gap separates the hero from the '#get-started' panel (matches .vt-brand-lab rhythm)."
    - "The operator aside shows two one-click 'Sign in as' buttons routing through /users/log_in?demo=admin|morgan, not a prose code-chip list."
    - "page_controller_test.exs stays green — every asserted token survives unchanged."
  artifacts:
    - test/example/priv/static/assets/css/app.css
    - test/example/lib/example_web/controllers/page_html/home.html.heex
  key_links:
    - "Picker hrefs use ~p\"/users/log_in?#{%{demo: \"admin\"|\"morgan\"}}\" — the same real-login pattern as the evaluator cards."
    - "Kicker text 'One login, two jobs.' and testid home-shared-login-copy are preserved verbatim on the <aside>."
---

<objective>
Home front-door polish (example-only): add natural spacing above the "Get started"
section and convert the wordy "One login, two jobs" operator aside into two inline
one-click persona pickers that route through the real prefilled login.

Purpose: Reduce friction on the demo landing page — give the get-started panel
section rhythm, and let evaluators jump into an operator console in one click, mirroring
the low-friction "Sign in as X" pattern the evaluator cards already use.

Output: Edited `app.css` (two scoped rules) and `home.html.heex` (operator aside markup).
No installer template, golden fixture, JS, or persona/controller data changes.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@test/example/priv/static/assets/css/app.css
@test/example/lib/example_web/controllers/page_html/home.html.heex
@test/example/test/example_web/controllers/page_controller_test.exs

Design source of truth (already approved — formalized here, do not redesign):
@~/.claude/plans/whats-our-roadmap-gsd-indexed-narwhal.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: CSS — get-started top margin + operator-list-item grid layout</name>
  <files>test/example/priv/static/assets/css/app.css</files>
  <action>
Edit the build-free served stylesheet directly (no build step — live reload picks it up).

Change A — section rhythm above Get started. Add a new scoped rule near the other
section-rhythm rules (beside `.vt-brand-lab` at ~line 761, which already uses
`margin-top: var(--sg-space-5)`):
`#get-started { margin-top: var(--sg-space-5); }`
Use `var(--sg-space-5)` to match the existing `.vt-brand-lab` gap — coherent, not ad-hoc.
Do NOT touch `.vt-panel__title` (shared by 4 other headings).

Change B — operator picker layout. Extend the EXISTING rule at ~line 652,
`.vt-panel--operator .vt-operator-list li`, which is currently background-only. Add
`display: grid;` and `gap: var(--sg-space-2);` so each picker's name-block and its
full-width button stack cleanly in the narrow hero column. KEEP the existing
`background: color-mix(in oklab, var(--vt-color-panel-alt) 72%, transparent);` declaration
untouched. Do not create a new selector — extend the one that already exists.
  </action>
  <verify>
    <automated>cd test/example && grep -q '#get-started' priv/static/assets/css/app.css && grep -A3 '.vt-panel--operator .vt-operator-list li' priv/static/assets/css/app.css | grep -q 'display: grid'</automated>
  </verify>
  <done>app.css contains a `#get-started { margin-top: var(--sg-space-5); }` rule, and the existing `.vt-panel--operator .vt-operator-list li` rule now declares `display: grid;` + `gap: var(--sg-space-2);` while keeping its original `background: color-mix(...)` line.</done>
</task>

<task type="auto">
  <name>Task 2: HEEx — operator aside to two inline pickers</name>
  <files>test/example/lib/example_web/controllers/page_html/home.html.heex</files>
  <action>
Rework the operator aside at lines 81–103
(`<aside class="vt-panel vt-panel--operator" data-testid="home-shared-login-copy">`).

KEEP unchanged:
- `data-testid="home-shared-login-copy"` on the `<aside>`.
- The kicker `<p class="vt-kicker">One login, two jobs.</p>` VERBATIM (preserves the
  page_controller_test.exs:13 assertion).

TIGHTEN the title: replace the wordy
`<h2 class="vt-panel__title">Use Tasklane login for both customer and operator personas.</h2>`
with a crisp line, e.g. `<h2 class="vt-panel__title">Sign in as an operator.</h2>`, followed
by ONE short context line, e.g.
`<p class="vt-copy">Same Tasklane login as customers — operator personas continue into Sigra admin.</p>`.
REMOVE the old standalone `<p class="vt-copy">…/users/log_in… is Tasklane's shared login…</p>`
prose sentence (lines 84–88).

REPLACE the descriptive `<ul class="vt-operator-list">` (the two prose `<li>` items with
`admin@…`/`morgan@…` `vt-code--copy` chips + "opens /admin" text) with two picker `<li>`s.
Each picker is a name-block `<div>` (a `<strong>` label + a `.vt-copy` destination hint whose
route is a NON-copyable `<code class="vt-code">` — note: `vt-code` WITHOUT `--copy`, since
these are destinations, not credentials) plus a full-width primary button that routes through
the real prefilled login. Use the exact structure:

  Picker 1 — label "Global Sigra Admin", hint "Platform-wide operator → /admin"
  (route in vt-code), button "Sign in as Admin" with
  `href={~p"/users/log_in?#{%{demo: "admin"}}"}` and classes `vt-btn vt-btn--primary vt-btn--block`.

  Picker 2 — label "Acme org admin", hint "Org-scoped operator →
  /admin/organizations/acme-corp" (route in vt-code), button "Sign in as Morgan" with
  `href={~p"/users/log_in?#{%{demo: "morgan"}}"}` and classes `vt-btn vt-btn--primary vt-btn--block`.

Mirror the evaluator-card href pattern already at ~line 122
(`href={~p"/users/log_in?#{%{demo: c.local}}"}`). `/users/log_in` is a normal, non-dev-gated
route so `~p` is safe. No controller change — the `?demo=` key carries the email, so the
aside displays no credentials. Never auto-submit. Do not touch the persona/controller data.
  </action>
  <verify>
    <automated>cd test/example && mix compile --warnings-as-errors 2>&1 | tail -5</automated>
  </verify>
  <done>`mix compile --warnings-as-errors` is clean. The operator aside keeps `data-testid="home-shared-login-copy"` and the "One login, two jobs." kicker, shows a tightened title + one context line, and renders two `vt-btn--block` "Sign in as Admin"/"Sign in as Morgan" buttons linking to `/users/log_in?demo=admin` and `/users/log_in?demo=morgan`; destination routes render as non-copyable `vt-code` (no `--copy`). The old prose sentence and the two prose/code-chip `<li>` descriptions are gone.</done>
</task>

</tasks>

<verification>
- `cd test/example && mix compile --warnings-as-errors` — clean, no warnings.
- `cd test/example && mix test test/example_web/controllers/page_controller_test.exs --include example_app`
  — GREEN, UNCHANGED. Every asserted token survives: "One login, two jobs." (kept kicker,
  L13), "/users/log_in" (picker + card hrefs, L14), "admin@demo.tasklane.test" (evaluator
  card below, L15), "morgan@demo.tasklane.test" (L39), "/admin/organizations/acme-corp"
  (picker hint + seeded evidence, L40), `id="get-started"` (L42), "Sign in as" (L45).
  These tests need a live test Postgres (see CLAUDE.md local-dev prereqs). If the DB is
  unavailable, record the run as SKIPPED (not failed) — the orchestrator will run it.
  Do NOT weaken any assertion to make it pass; fix the markup to preserve the token.
- Live browser verification is performed by the ORCHESTRATOR post-execution (spacing gap
  above Get started; operator aside shows two "Sign in as" buttons → /users/log_in?demo=admin|morgan
  with email prefilled and demo Fill-password bar; route hints non-copyable). The executor
  does NOT need to drive a browser.
</verification>

<success_criteria>
- app.css has `#get-started { margin-top: var(--sg-space-5); }` and the extended
  `.vt-panel--operator .vt-operator-list li` grid rule (background kept).
- Operator aside renders two inline "Sign in as" pickers routing through the real
  `/users/log_in?demo=…` login; kicker + testid preserved.
- `mix compile --warnings-as-errors` clean; page_controller_test.exs green/unchanged
  (or SKIPPED if no DB).
- No changes to installer templates, golden fixtures, JS, or persona/controller data.
</success_criteria>

<output>
Create `.planning/quick/260718-npn-home-front-door-spacing-above-get-starte/260718-npn-SUMMARY.md` when done.
</output>
</content>
</invoke>
