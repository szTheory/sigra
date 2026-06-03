---
phase: quick-260602-gzc
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - priv/templates/sigra.install/admin/components/admin_shell.ex
  - test/example/lib/example_web/components/admin_shell.ex
  - test/example/priv/static/assets/css/app.css
  - test/example/test/example_web/admin_shell_test.exs
autonomous: true
requirements: [PASS2-STAGE1-SCOPE, PASS2-STAGE1-NOUNS, PASS2-STAGE1-TESTS]

must_haves:
  truths:
    - "Shell template and example copy remain byte-identical after web_module substitution (sed | diff is clean)"
    - "Desktop sidebar links read 'Users' and 'Audit' (matching mobile bottom-nav and breadcrumb/page titles)"
    - "Org-scope shell is visibly distinct from global (tenant-marked chip + data-scope chrome treatment) while still showing the org name substring; global still shows 'Global'"
    - "Org-scope chrome treatment passes axe AA in light and dark (uses existing tokens; no new contrast failures)"
    - "admin_shell_test.exs is 6/6 green against the reshaped+updated shell"
    - "No JS / app.js / hook changes in this stage"
  artifacts:
    - path: "priv/templates/sigra.install/admin/components/admin_shell.ex"
      provides: "Generated admin shell template with tenant-marked scope chip, data-scope attr, noun sidebar labels"
      contains: "data-scope"
    - path: "test/example/lib/example_web/components/admin_shell.ex"
      provides: "Byte-identical example copy of the shell"
      contains: "data-scope"
    - path: "test/example/priv/static/assets/css/app.css"
      provides: "Restrained on-brand [data-scope=organization] chrome treatment + tenant chip styling, token-driven, AA in light+dark"
      contains: "data-scope=\"organization\""
    - path: "test/example/test/example_web/admin_shell_test.exs"
      provides: "Shell scope-chrome contracts rewritten to the reshaped shell, 6/6 green"
      contains: "Users"
  key_links:
    - from: "priv/templates/sigra.install/admin/components/admin_shell.ex"
      to: "test/example/lib/example_web/components/admin_shell.ex"
      via: "hand-maintained byte-for-byte parity (web_module/ExampleWeb substitution only)"
      pattern: "data-scope"
    - from: "test/example/lib/example_web/components/admin_shell.ex"
      to: "test/example/priv/static/assets/css/app.css"
      via: "data-scope attribute consumed by [data-scope=\"organization\"] CSS selector"
      pattern: "data-scope"
---

<objective>
Stage 1 of the approved admin-UI Pass 2 plan: shell & IA chrome. Make tenant-vs-global scope
unmistakable (tenant-marked scope chip + restrained org-scope chrome recolor/badge), fix the
desktop↔mobile sidebar label mismatch by relabeling sidebar nouns to "Users"/"Audit", and rewrite
the stale/failing admin_shell_test.exs to 6/6 green against the reshaped shell.

Purpose: Morgan (org admin) must never confuse a tenant view for the global view; the sidebar must
read consistently across desktop and mobile; the shell test must protect the real, current markup.

Output: Updated shell template + byte-identical example copy, org-scope chrome CSS, and a green
admin_shell_test.exs. CSS + heex only — NO JS, NO app.js, NO hooks (Cmd-K is resequenced to Stage 7).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@./CLAUDE.md

<ground_truth_baked_in>
Verified by orchestrator — do NOT re-discover:

1. PARITY IS CURRENTLY BYTE-IDENTICAL between template and example copy after web_module
   substitution. Every shell change MUST be applied to BOTH files identically (only difference is
   `<%= web_module %>` in the template vs `ExampleWeb` in the example copy). There is NO build step;
   the example copy is hand-maintained in parallel. The parity diff is a verify gate on every task
   that touches the shell.

2. Current shell (verified): topbar = brand "Admin" + `<.scope_switcher>` + "Exit to global" ghost
   button. scope_switcher renders `<span class="sg-scope-pill">{scope_label}</span>` for ≤1 target,
   or `<details class="sg-scope-switch"><summary class="sg-scope-pill">{scope_label}</summary>…` for
   >1. `scope_label/1`: `:global` → "Global"; `:organization` with `%{name: name}` → name; with
   `organization_slug` → slug. Sidebar = sg-nav-card "Workspace" (links "Support users" → users_link,
   "Audit evidence" → audit_link) + "Overviews" (Global overview / Organization overview). Mobile
   sg-bottom-nav items already read "Users" / {scope_label} / "Audit". Breadcrumb = scope_label /
   page_title, hidden on overview pages via overview_active?.

3. INCONSISTENCY to fix: desktop sidebar says "Support users"/"Audit evidence" but mobile bottom-nav
   says "Users"/"Audit". Relabel the DESKTOP sidebar links to "Users" and "Audit" so both layouts
   match. Keep nav-card group titles "Workspace"/"Overviews".

4. admin_shell_test.exs is 2/6 FAILING on STALE assertions (pre-existing, references old pre-reshape
   shell). Specifically:
   - line 29: `assert html =~ "Operate Sigra with confidence"` — old landing copy; the current
     landing h1 is "What do you need to do?" with copy "Start with the job at hand…" (confirmed in
     lib/sigra/admin/live/index_live.ex).
   - `sidebar_operations_before_scope?/1` (lines 124-128) greps for
     `uppercase text-base-content/60">Operations</p>` and `">Scope</p>` — those strings/classes do
     not exist; current nav titles are `<p class="sg-nav-title">Workspace</p>` / `Overviews`.
   - `bottom_nav_users_before_home?/1` (lines 130-145) greps for `btm-nav-label">Users<` and
     `btm-nav-label">Home<` — current bottom nav uses `sg-bottom-nav__item` with `<span>Users</span>`,
     and there is NO "Home" (it is scope_label). Line 61 also `refute html =~ "btm-nav-label\">Home<"`.
   Rewrite these stale assertions + helpers to match the reshaped+updated shell so the file is 6/6
   green. Preserve each test's INTENT.

5. Only admin_shell_test.exs references the sidebar label strings (grep-confirmed). Playwright keys
   off "Admin" + scope label + "Exit to global" (all remain). admin-checkpoints baselines WILL shift
   from the org-scope recolor + sidebar relabel — intentional, deferred to Stage 8. Do NOT regenerate
   baselines here; just flag it in the SUMMARY.

CSS facts (verified in app.css):
- Tokens available: `--sg-color-brand` #c2410c, `--sg-color-brand-soft`, `--sg-color-brand-strong`,
  `--sg-color-info` / `--sg-color-info-soft`, `--sg-color-warn` / `--sg-color-warn-soft`,
  `--sg-color-line` / `--sg-color-line-strong`, `--sg-space-*`, `--sg-radius-full`, `--sg-pill-*`,
  `--sg-elev-inset`. All have dark-mode overrides under `@media (prefers-color-scheme: dark)`
  (block starts ~line 160), so any rule referencing these tokens adapts to dark automatically.
- `.sg-scope-pill` (line ~407): brand-soft bg, brand-strong text, inset brand ring.
- `.sg-admin-shell` (line ~266) and `.sg-admin-topbar` (line ~274) are the chrome surfaces.
- Cascade layers `@layer sg-base, sg-components, sg-overrides`; BEM; mobile-first; no new !important.
</ground_truth_baked_in>

<interfaces>
Shell helpers that MUST stay intact (do not regress):
  scope_label/1, scope_targets/1, scope_chip_class/1, show_global_link?/1, global_active?/1,
  organization_active?/1, overview_active?/1, users_active?/1, audit_active?/1, overview_link/1,
  organization_link/1, users_link/1, audit_link/1, impersonating?/1.

Active-state logic note: users_active?/audit_active? key on page_title text, NOT on the link label
string. Relabeling "Support users" → "Users" / "Audit evidence" → "Audit" does NOT affect active
state. Verify by leaving those helpers unchanged.

scope_label/1 is reused by the breadcrumb, the bottom-nav, and scope_targets/1. Keep scope_label/1
returning the RAW org name (so breadcrumb and switcher menu stay clean). Add chip-specific tenant
formatting ONLY in the chip render path (a new chip-label helper or inline in scope_switcher), so the
org name substring is preserved everywhere tests assert it.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Shell markup — tenant-marked scope chip, data-scope attr, noun sidebar labels (BOTH files, parity-identical)</name>
  <files>priv/templates/sigra.install/admin/components/admin_shell.ex, test/example/lib/example_web/components/admin_shell.ex</files>
  <action>
Apply these changes IDENTICALLY to both shell files (template uses `<%= web_module %>`; example copy
uses `ExampleWeb` — that is the only permitted difference).

1) Scope chrome attribute: add `data-scope={scope_mode(@admin_scope)}` to the root
   `<section class="sg-admin-shell">` element. Add a private helper
   `scope_mode(%{mode: :organization}), do: "organization"` and `scope_mode(_), do: "global"`.
   This gives CSS a hook for the org-scope chrome treatment (Task 2) without touching any other logic.

2) Tenant-marked scope chip: make the org-scope chip read unmistakably as a tenant while PRESERVING
   the org-name substring (tests assert the org name is present) and keeping global as "Global".
   - Add a private helper `scope_chip_label(%{mode: :organization} = s), do: "Org · " <> scope_label(s)`
     and `scope_chip_label(s), do: scope_label(s)`. (Use the middle-dot "·" separator; the org name
     remains a clean substring of the chip text.)
   - In `scope_switcher/1`, render the chip via `scope_chip_label(@admin_scope)` in BOTH the
     `<summary>` (>1 target) and the `<span>` (≤1 target) branches, in place of the current
     `{scope_label(@admin_scope)}`.
   - Add a tenant glyph for the org branch only: inside the chip, before the label, add
     `<span :if={@admin_scope.mode == :organization} class="sg-scope-pill__tenant" aria-hidden="true">⌂</span>`
     (a small tenant marker; CSS in Task 2 styles it; keep it aria-hidden so screen readers read the
     "Org · <name>" text). Keep the chip class as the existing `scope_chip_class(@admin_scope)` →
     `"sg-scope-pill"`; do NOT change scope_chip_class (Task 2 styles via `[data-scope]` + the glyph).
   - Do NOT change `scope_label/1` itself, scope_targets/1 menu labels, or the breadcrumb — those keep
     the raw name.

3) Sidebar noun relabel (desktop): in the "Workspace" sg-nav-card, change the link text
   "Support users" → "Users" and "Audit evidence" → "Audit". Leave the `nav_item_class(...)`,
   hrefs (users_link/audit_link), and group title "Workspace" unchanged. Mobile bottom-nav already
   reads "Users"/"Audit" — leave it as-is; this makes desktop match mobile.

Do NOT: touch the impersonation banner, breadcrumb logic, scope_targets, routing/active helpers, or
add any JS/phx hooks. No new heex other than the glyph span and the data-scope attr.

After editing both files, the only diff between them (post web_module substitution) must be zero.
  </action>
  <verify>
    <automated>sed 's/<%= web_module %>/ExampleWeb/g' priv/templates/sigra.install/admin/components/admin_shell.ex | diff - test/example/lib/example_web/components/admin_shell.ex && echo PARITY-OK</automated>
    <automated>grep -c 'data-scope' test/example/lib/example_web/components/admin_shell.ex | grep -qx 1 && grep -q 'scope_chip_label' test/example/lib/example_web/components/admin_shell.ex && grep -q '>Users<\|>Users\b' test/example/lib/example_web/components/admin_shell.ex && echo MARKUP-OK</automated>
  </verify>
  <done>
Both shell files updated identically (parity diff clean). Root section carries
`data-scope="organization|global"`. Org-scope chip renders "Org · <name>" with a tenant glyph;
global chip renders "Global". Desktop sidebar reads "Users"/"Audit". No JS added. All shell helpers
(scope_label, scope_targets, active?, links) unchanged in behavior.
  </done>
</task>

<task type="auto">
  <name>Task 2: Org-scope chrome CSS — restrained, on-brand, AA in light+dark</name>
  <files>test/example/priv/static/assets/css/app.css</files>
  <action>
Add a RESTRAINED, brand-consistent org-scope treatment in app.css, token-driven, BEM, mobile-first,
no new `!important`. Place rules in the appropriate `@layer` (alongside the existing
`.sg-admin-shell` / `.sg-admin-topbar` / `.sg-scope-pill` rules, i.e. the sg-components layer).
Because all referenced tokens already have dark-mode overrides under
`@media (prefers-color-scheme: dark)`, these rules adapt to dark automatically — do NOT add a
separate dark block unless a specific value needs it.

1) Tenant glyph styling: `.sg-scope-pill__tenant { font-size: var(--sg-text-xs); line-height: 1; }`
   (inherits the pill's color; the existing `--sg-pill-gap` already spaces it from the label since
   the glyph is the first inline child). Keep it tiny and unobtrusive.

2) Org-scope chip emphasis: under `[data-scope="organization"]`, give the scope pill a distinct
   tenant tint that is clearly different from the global brand-soft chip but still on-brand and AA.
   Use the existing `--sg-color-info` / `--sg-color-info-soft` family (a restrained secondary accent)
   OR a stronger brand ring — pick whichever reads as clearly "tenant" while passing AA on the pill
   text. Example shape (tune to AA):
   `[data-scope="organization"] .sg-scope-pill { background: var(--sg-color-info-soft);
   color: var(--sg-color-info); box-shadow: inset 0 0 0 1px color-mix(in oklab, var(--sg-color-info) 28%, transparent); }`
   Verify the chosen fg/bg pair clears AA (≥4.5:1 for the small pill text) in BOTH light and dark
   token sets — `--sg-color-info` is #1d4ed8 (light) / #9db8f5 (dark) on the respective soft bg.
   If the dark pair is borderline, prefer the brand-ring-only approach (keep brand-soft bg, add a
   thicker/stronger ring + the glyph as the differentiator) rather than introducing a new token.

3) Whole-shell tenant signal (subtle): under `[data-scope="organization"]`, add a restrained marker
   to the topbar so the entire shell signals "inside a tenant" — e.g. a thin accent top border:
   `[data-scope="organization"] .sg-admin-topbar { border-top: 2px solid color-mix(in oklab, var(--sg-color-info) 55%, transparent); }`
   Keep it subtle (2px, token-derived), NOT a full-color repaint. Reuse the chosen accent from step 2
   so the chip and the border read as one system. Do NOT alter the global (`[data-scope="global"]`)
   appearance — global stays exactly as today.

Introduce a new token ONLY if none of the existing tokens (info / brand / warn families) gives an
AA-clean, on-brand result; if you must, add it to the `:root` token block AND a matching dark-mode
override, and note it in the SUMMARY.

Do NOT change `.sg-bottom-nav`, `.sg-admin-sidebar`, breadcrumb, or any global-scope rule.
  </action>
  <verify>
    <automated>grep -q 'data-scope="organization"' test/example/priv/static/assets/css/app.css && grep -q 'sg-scope-pill__tenant' test/example/priv/static/assets/css/app.css && echo CSS-OK</automated>
    <automated>grep -c '!important' test/example/priv/static/assets/css/app.css</automated>
    <human-check>axe AA passes in light + dark for the org-scope shell (run admin-checkpoints axe locally per the plan's Verification section, or eyeball contrast of the chosen info pair). Baselines WILL shift — do NOT regenerate here; defer to Stage 8.</human-check>
  </verify>
  <done>
app.css has a restrained `[data-scope="organization"]` treatment (distinct tenant-tinted scope pill +
subtle topbar accent border) plus `.sg-scope-pill__tenant` glyph styling, all token-driven, no new
!important, dark-mode handled via existing token overrides. Global scope appearance unchanged.
Chosen accent pair clears AA in light and dark.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Rewrite admin_shell_test.exs stale assertions → 6/6 green</name>
  <files>test/example/test/example_web/admin_shell_test.exs</files>
  <behavior>
    - Global shell test: html contains "Admin", "Global", desktop sidebar "Users" + href "/admin/users",
      "Audit" + href "/admin/audit", the CURRENT landing copy ("What do you need to do?"), and the
      sidebar Workspace group precedes the Overviews group, and bottom-nav "Users" precedes the
      scope/overview item.
    - Org shell test: html contains "Admin", the org name ("Acme Ops"), "Organization overview",
      sidebar "Users" + scoped users href, "Audit" + scoped audit href, the org landing copy
      ("Work inside this organization scope"), Workspace group precedes Overviews group, and the chip
      reads as a tenant ("Org · Acme Ops") — org name substring still present.
    - Impersonation tests (both): unchanged intent — Impersonating/Signed in as/End impersonation/
      action="/impersonation"/method/_method/delete present; no Special session / Dismiss / Hide banner.
    - Denied-state tests: unchanged (403 "Access denied", 404 "organization admin scope").
  </behavior>
  <action>
Rewrite ONLY the stale parts; keep every assertion that already passes (Admin, Global, org name,
href values, "Work inside this organization scope", impersonation strings, denied-state tests).

1) Sidebar label assertions: change `assert html =~ "Support users"` → `assert html =~ "Users"` and
   `assert html =~ "Audit evidence"` → `assert html =~ "Audit"` at lines ~25/27 (global test) and
   ~55/57 (org test). Keep the href assertions exactly.

2) Stale landing copy (line ~29): replace `assert html =~ "Operate Sigra with confidence"` with
   `assert html =~ "What do you need to do?"` (the current landing h1, confirmed in index_live.ex).

3) Rewrite `sidebar_operations_before_scope?/1` (lines ~124-128) to assert the CURRENT nav structure:
   the "Workspace" sg-nav-card precedes the "Overviews" sg-nav-card. Match the real markup, e.g.
   compare `html_offset(html, "sg-nav-title\">Workspace<")` < `html_offset(html, "sg-nav-title\">Overviews<")`.
   Rename the helper to reflect intent (e.g. `sidebar_workspace_before_overviews?/1`) and update both
   call sites (global + org tests). Keep the `html_offset/2` helper as-is.

4) Rewrite `bottom_nav_users_before_home?/1` (lines ~130-145): the current bottom nav uses
   `sg-bottom-nav__item` with `<span>Users</span>` and there is NO "Home" (the middle item is
   scope_label). Reshape the helper to assert "Users" precedes the scope/overview item WITHIN the
   `aria-label="Admin bottom nav"` fragment — e.g. within that fragment, offset of `<span>Users</span>`
   < offset of `<span>Global</span>` (global test) / the scope-label span. Rename appropriately
   (e.g. `bottom_nav_users_first?/1`). Update the global-test call site (line ~31).

5) Org test line ~61 `refute html =~ "btm-nav-label\">Home<"`: that class no longer exists, so the
   refute is trivially true but meaningless. Replace it with a meaningful current-shell assertion:
   `refute html =~ "btm-nav-label"` (the old bottom-nav class is fully gone), OR drop it and instead
   assert the tenant chip is present (`assert html =~ "Org · Acme Ops"`). Prefer adding the tenant-chip
   assertion (ties the test to the new scope-legibility behavior) and removing the dead refute.

6) Add ONE assertion proving the org-scope chrome attribute is wired: in the org test,
   `assert html =~ "data-scope=\"organization\""`; optionally in the global test
   `assert html =~ "data-scope=\"global\""`.

Remove any now-unused private helpers so `mix compile --warnings-as-errors` stays clean (e.g. if you
rename helpers, delete the old definitions; if `bottom_nav_*` no longer needs the 2500-byte window
logic, simplify but keep it correct).

Run the file; it must be 6/6 green.
  </action>
  <verify>
    <automated>cd test/example && mix test test/example_web/admin_shell_test.exs 2>&1 | grep -E '0 failures|[0-9]+ tests' | tail -1</automated>
    <automated>cd test/example && mix compile --warnings-as-errors 2>&1 | tail -3</automated>
  </verify>
  <done>
admin_shell_test.exs runs 6 tests, 0 failures. All stale assertions/helpers rewritten to the
reshaped+updated shell (Users/Audit labels, Workspace-before-Overviews, Users-first bottom nav,
current landing copy, tenant chip + data-scope wired). No unused helpers; warnings-as-errors clean.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none new) | This stage is presentational shell markup + CSS + a test rewrite. No new input handling, no new routes, no new data flow, no package installs, no JS. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-gzc-01 | Information disclosure | scope chip / chrome (Morgan tenant vs global confusion) | mitigate | Tenant-marked chip ("Org · <name>" + glyph) and `[data-scope="organization"]` chrome treatment make tenant context unmistakable; "Exit to global" + breadcrumbs retained. |
| T-gzc-02 | Tampering | admin_shell_test contract drift | mitigate | Rewrite stale assertions to pin the real current markup (labels, group order, scope attr) so future regressions are caught; parity diff gate keeps template ≡ example copy. |
</threat_model>

<verification>
Phase-level checks (run from repo root unless noted):

1. Parity gate (MUST pass):
   `sed 's/<%= web_module %>/ExampleWeb/g' priv/templates/sigra.install/admin/components/admin_shell.ex | diff - test/example/lib/example_web/components/admin_shell.ex` → no output.
2. Shell test (MUST be 6/6 green): from `test/example`,
   `mix test test/example_web/admin_shell_test.exs`.
3. `cd test/example && mix compile --warnings-as-errors` clean.
4. No JS touched: `git diff --name-only` shows NO `app.js` / `*_hooks.js` / `priv/playwright` changes.
5. axe AA (light + dark) for the org-scope shell — run admin-checkpoints axe locally per the approved
   plan's Verification section if convenient. NOTE: admin-checkpoints + demo-showcase PNG baselines
   WILL shift from the org-scope recolor + sidebar relabel. This is INTENTIONAL; do NOT regenerate
   baselines in this stage — Stage 8 owns baseline regeneration. Flag the shift in the SUMMARY.
</verification>

<success_criteria>
- Template and example shell are byte-identical after web_module substitution.
- Desktop sidebar reads "Users"/"Audit"; matches mobile bottom-nav and breadcrumb/page titles.
- Org scope is visibly distinct (tenant chip "Org · <name>" + glyph + restrained `[data-scope]`
  chrome) while still containing the org name substring; global still reads "Global".
- Org-scope chrome passes axe AA in light + dark using existing tokens (or one documented new token).
- admin_shell_test.exs is 6/6 green; `mix compile --warnings-as-errors` clean.
- Zero JS/app.js/hook changes; baseline shift flagged (deferred to Stage 8), not regenerated here.
</success_criteria>

<output>
Create `.planning/quick/260602-gzc-stage-1-admin-ui-pass-2-shell-ia-chrome-/260602-gzc-SUMMARY.md` when done.
In the SUMMARY, explicitly record: (a) the chosen org-scope accent (info family vs brand-ring) and
the AA result for light+dark, (b) any new token introduced, (c) that admin-checkpoints/demo-showcase
baselines will shift and are intentionally deferred to Stage 8.
</output>
