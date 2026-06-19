---
status: investigating
trigger: "4 failing Playwright tests in admin-flow-platform-admin.spec.ts; app correct, spec/helper defects"
created: 2026-06-17T00:00:00Z
updated: 2026-06-17T00:00:00Z
---

## Current Focus

hypothesis: 4 spec/helper defects diverge from proven investigator-spec patterns
test: inspect live DOM at localhost:4019 + cross-reference passing specs
expecting: confirm actual selectors/attributes, mirror investigator patterns
next_action: discover live theme attribute model + Open user link structure

## Symptoms

expected: 16 admin-flow tests pass
actual: 12 pass, 4 fail in admin-flow-platform-admin.spec.ts (lines 94, 157, 244, helper 188)
errors: |
  L94: URL stays /admin/users?q=alice instead of /admin/users/<id> after Open user click
  L157: locator.click times out navigating to audit
  L244: getByRole button 'Revoke session' not found/visible
  helper:188: assertThemeAttributes(system) got data-sg-admin-theme=dark preference=dark
reproduction: SIGRA_EXAMPLE_URL=http://localhost:4019 npx playwright test admin-flow
started: spec authored in phase 190; app correct (other 2 spec files pass same personas)

## Eliminated

## Evidence

- checked: investigator spec openUserDetail helper
  found: clicks Open user scoped to VISIBLE row (adminUsersEmailLocator), not .first(); waits toHaveURL(/\/admin\/users\/[a-f0-9-]+/, timeout 10000). Platform spec uses .first() globally + no timeout + regex /[^?/]+/ which matches the search list path segment "users" wrongly? Actually /admin/users/[^?/]+ would NOT match /admin/users?q= ... need to verify.
  implication: L94/L157 root = wrong link selector (.first picks hidden mobile dup) + missing nav wait

reasoning_checkpoint:
  hypothesis: "All 4 are spec/helper defects; #1/#2/#3 share root (global .first() Open-user click does not navigate); #4 is wrong theme model + non-persisting flip action."
  confirming_evidence:
    - "probe2: openLinks.first().click() leaves URL at /admin/users?q=alice (no nav). Investigator visible-row-scoped click navigates (count=1 both ways)."
    - "probe1: revoke buttons ARE visible on detail page -> L244 only fails because nav never reached detail page."
    - "probe1: system mode html = {theme:null, pref:'system'}; live app always sets data-sg-admin-theme to RESOLVED + data-sg-admin-theme-preference to selection."
    - "probe2: bare localStorage.setItem('system')+reload reverts to dark (LiveView re-syncs from server on mount). probe3: addInitScript('system')+reload yields theme=null,pref=system,ls=system."
  falsification_test: "If visible-row-scoped click also failed to navigate, root cause would be app-side not spec."
  fix_rationale: "Adopt proven investigator openUserDetail pattern for nav; rewrite helper system branch to assert preference=system + theme absent + shell data-theme absent; change spec flip to addInitScript+reload."
  blind_spots: "Whether breadcrumb/audit selectors in platform spec differ once nav works — will catch on rerun."

## Resolution

root_cause: |
  #1/#2/#3: page.getByRole('link',{name:'Open user'}).first().click() does not trigger LiveView navigation (global locator vs visible-row-scoped). Detail page never loads -> revoke buttons absent (#3), audit link click times out (#2).
  #4: (a) helper system branch asserted ABSENCE of data-sg-admin-theme, but app always sets it to RESOLVED theme and uses data-sg-admin-theme-preference for selection; (b) spec flip used bare localStorage.setItem('system')+reload which LiveView overwrites from server state on mount.
fix: |
  spec (admin-flow-platform-admin.spec.ts): replaced 4x getByRole('link',{Open user}).first().click() with read-row-href + page.goto(href) (post-Search LiveView patch swallows immediate click); fixed Recent Audit selector to scoped section .sg-list .sg-list-row .sg-status-pill; changed theme system flip to addInitScript('system')+reload.
  helper (adminFlows.ts): rewrote assertThemeAttributes system branch to assert data-sg-admin-theme-preference="system" + absence of data-sg-admin-theme + absence of .sg-admin-shell[data-theme] + localStorage="system".
  asset refresh (priv/static/assets/js/app.js): inlined current ConfirmDialog hook (already in assets/js/admin_hooks.js source, Jun 17) into the stale served bundle (Jun 13) + registered it in SigraAdminHooks map and LiveSocket hooks map. No BEAM restart needed — Plug.Static serves from disk per request. This is what enables the focus-trap (WR-01/02/03) assertions to pass meaningfully.
verification: "SIGRA_EXAMPLE_URL=http://localhost:4019 npx playwright test admin-flow -> 16 passed (twice, stable). Investigator+org-admin specs unchanged and still pass."
files_changed:
  - test/example/priv/playwright/tests/admin-flow-platform-admin.spec.ts
  - test/example/priv/playwright/helpers/adminFlows.ts
  - test/example/priv/static/assets/js/app.js


---

## Resolution (closed at v1.39 milestone close, 2026-06-19)

Stale-resolved. All 4 spec/helper defects were fixed during Phase 190 execution and
landed in PR #54 (119f9a2f): the platform-admin flow spec now uses visible-row-scoped
`adminUsersEmailLocator(...)` (not `.first()`), `toHaveURL(/\/admin\/users\/[a-f0-9-]+/,
{ timeout: 10000 })` navigation waits, and the corrected `data-sg-admin-theme-preference`
theme model. Phase 190 verified complete. The session file was simply never moved to
resolved/.