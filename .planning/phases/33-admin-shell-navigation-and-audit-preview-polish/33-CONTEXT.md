# Phase 33: Admin Shell Navigation and Audit Preview Polish - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Close two cross-phase integration gaps surfaced by the v1.2 milestone audit:

- **INT-04 (WARNING):** The generated admin shell template at
  `priv/templates/sigra.install/admin/components/admin_shell.ex` renders "Users"
  as dead `<span>` text. Port the `users_link/1` helper, the top-bar
  scope-switch entry, the desktop sidebar link, and the mobile bottom-nav entry
  from the example-app counterpart so a freshly installed host exposes a live
  path from the admin shell to `/admin/users` (and to the org-scoped variant).

- **INT-05 (INFO):** The Phase 28 recent-audit preview on the user-detail page
  bypasses Phase 30's `Sigra.Admin.Audit.Presenter.present/2`, so impersonation
  rows show `admin.impersonation.start` raw instead of the "Impersonation" badge
  + actor-summary label that Phase 30's explorer already renders. Pipe the
  preview through the shared Presenter so both surfaces agree on row rendering.

**Not in scope (explicit):**
- Retroactive `28-VERIFICATION.md` and generated-host E2E coverage for user
  operations, impersonation, and audit export (→ Phase 34).
- Generalized dead-text detector, axe-core baselines, visual regression, and
  milestone-verification CI gate (→ Phase 35).
- Any change to Phase 30's full explorer, its URL scheme, its filter surface,
  or its CSV export.
- New admin LiveView surfaces or new host configuration hooks — Phase 28's
  extension seams are unchanged.

</domain>

<decisions>
## Implementation Decisions

### INT-05 — Presenter integration seam

- **D-01:** `Sigra.Admin.Users.Detail.recent_audit_preview/3` owns both the
  query AND the Presenter call. The function returns Presenter-shaped rows
  (`[map()]`), mirroring how `Sigra.Admin.Audit.Explorer.list/4` already owns
  load + present together. Upholds the invariant "audit rows are always
  Presenter-shaped before leaving the Sigra admin layer."
- **D-02:** Before flipping the return contract from `[struct()]` to `[map()]`,
  the planner MUST grep `lib/`, `test/`, `priv/templates/`, and
  `test/example/` for every caller of `Detail.recent_audit_preview/`. If any
  caller outside `Detail.load!/3` and its tests exists, fall back to adding a
  new `recent_audit_preview_presented/3` helper instead of flipping the
  contract in place.
- **D-03:** The `@spec` and function doc on the flipped function must state
  explicitly that rows are Presenter-shaped (see `Sigra.Admin.Audit.Presenter`),
  and must name the guaranteed row keys (`:action_label`, `:action_badge`,
  `:actor_summary`, `:inserted_at`, `:id`) so generator-emitted LiveViews can
  rely on them.
- **D-04:** The `users_by_id` lookup for the Presenter call lives inside
  `Detail`, not in the LiveView, and reuses the same pattern the Explorer uses
  for `load_users/2` (so both surfaces query users the same way and return the
  same fallback when an actor/effective user can't be loaded).

### INT-05 — Preview field surface rendered in `UserShowLive`

- **D-05:** The compact preview renders a strict subset of Presenter output:
  `action_badge` (only when present — it's `"Impersonation"` or `nil`),
  `action_label`, `actor_summary`, and a formatted timestamp. Nothing else.
- **D-06:** The preview does NOT render the raw `action` key, `outcome`, or
  the split `actor_label`/`effective_user_label` pair. Those belong to the full
  explorer; putting them in the preview collapses the "preview → full log"
  information scent that Stripe / Clerk / Okta / GitHub / Django Admin all
  rely on.
- **D-07:** The preview MUST NOT add any field not produced by
  `Sigra.Admin.Audit.Presenter.present/2`. If a new field is ever needed, it
  lands in the Presenter first so both surfaces stay coherent.
- **D-08:** The existing Presenter copy strings stay: `"Impersonation started"`,
  `"Impersonation ended"`, `"Impersonation timed out"`, `"Impersonation denied"`
  (see `lib/sigra/admin/audit/presenter.ex:38-41`). No new copy introduced in
  this phase.
- **D-09:** Preview row cap stays at `@audit_preview_limit 5`. The "View full
  audit" button continues to route to the Phase 30 per-user explorer with the
  scope-aware path (`full_audit_path/3` in `UserShowLive`).

### INT-04 — Generator admin-shell navigation port

- **D-10:** Port the Users navigation chrome from
  `test/example/lib/example_web/components/admin_shell.ex` into
  `priv/templates/sigra.install/admin/components/admin_shell.ex`:
  - `users_link/1` helper (global default `~p"/admin/users"`; org-scoped
    `~p"/admin/organizations/#{slug}/users"`).
  - Top-bar scope-switch `<.scope_switch_link href={users_link(@admin_scope)}>`
    entry added before the existing Global / Organization scope-switch links.
  - Desktop sidebar: the dead `<li><span class="text-base-content/60">Users
    </span></li>` becomes an active `<a class={nav_item_class(...)}
    href={users_link(@admin_scope)}>Users</a>` link, placed as the first entry
    in the existing "Operations" sidebar group.
  - Mobile bottom-nav: add `<a href={users_link(@admin_scope)} class={
    bottom_nav_class(users_active?(@admin_scope))}><span class="btm-nav-label"
    >Users</span></a>` as the first entry in the `.btm-nav` region.
  - `users_active?/1` helper ported verbatim from the example (currently
    `users_active?(_admin_scope), do: true`). If the heuristic is wrong in a
    future context, that's a separate phase — don't re-design it here.
- **D-11:** Sidebar section ordering inside the desktop nav is the example's
  ordering — **"Operations" before "Overview"** — because the example is the
  canonical reference and the Users link belongs in the first (most-used)
  group. The template's current `Overview → Operations` order is a drift bug
  to correct.
- **D-12:** Do NOT rewrite or "refactor" the `~p` vs. literal-string mix for
  `audit_link/1` or any other existing helper in this phase. The goal is a
  surgical port, not a shell redesign.
- **D-13:** The ported chrome inherits the already-parameterized shell. No
  new EEx bindings (`<%= web_module %>`) are introduced; no new assigns are
  required; no new `use <%= web_module %>` calls. The existing `:html` context
  in the template is sufficient.

### INT-04 — Regression guard

- **D-14:** Add a single fixture-pair entry to
  `test/sigra/templates/installer_drift_test.exs` (next to the existing
  `@fixtures` list) asserting the Users navigation chrome exists in both the
  generator template and the example file. Matches the Phase 32 "fix + guard"
  precedent.
- **D-15:** The fixture's `must_have` regex set is:
  1. `users_link(` helper defined on both sides (`~r/defp users_link\(/`).
  2. At least one `href={users_link(@admin_scope)}` usage on both sides.
  3. `btm-nav-label">Users<` appears on both sides (mobile bottom-nav).
- **D-16:** The fixture's `must_not` regex set is a single anchor on the
  dead-text regression: `~r/<li>\s*<span[^>]*>Users<\/span>\s*<\/li>/`
  (forbidden in both template and example).
- **D-17:** Do NOT build a template render harness in Phase 33. That
  infrastructure (EEx bindings stub + `~p`-sigil resolution +
  `Phoenix.VerifiedRoutes` router stub) is Phase 35's
  `generator_emission_audit_test.exs` scope. Shipping it now would duplicate
  Phase 35 work and increase the blast radius of an otherwise surgical phase.
- **D-18:** The generated-host browser and smoke coverage for the Users nav
  is explicitly Phase 34's scope (extends `admin-generated.spec.ts` and
  `admin-acceptance-smoke.sh`). Phase 33's test hardening is limited to the
  drift fixture plus whatever minimal LiveView test update naturally falls out
  of the `UserShowLive` preview-rendering change.

### Claude's Discretion

- Exact phrasing of the Presenter's `@spec`/`@doc` update in `Detail`.
- Exact test names and arrangement for any Phase 33 `UserShowLive` render
  update; follow the existing `test/sigra/admin/live/user_show_live_test.exs`
  conventions if such a file exists (or introduce it minimally if not).
- Whether to extract a small `format_preview_row/1` helper in `UserShowLive`
  or inline the subset rendering; planner picks whichever keeps the template
  readable.
- The precise labeled name for the drift-fixture `:id` string (suggest
  `"fix — admin_shell users nav + mobile bottom-nav"` but the planner may
  refine it).
- Whether the existing example-app `ExampleWeb.AdminShellTest` gets one extra
  assertion that the rendered shell exposes `href={users_link(...)}` (not just
  the word "Users"). Trivial; planner decides.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase + milestone anchors
- `.planning/ROADMAP.md` — Phase 33 goal, dependencies, success criteria, and
  adjacent Phase 34 / Phase 35 scope that this phase must NOT swallow.
- `.planning/v1.2-MILESTONE-AUDIT.md` § INT-04 (lines 84-89, 204-209, 222) and
  § INT-05 (lines 90-95, 211-216) — the authoritative defect descriptions.
- `.planning/REQUIREMENTS.md` — USER-01, USER-03, USER-05, AUD-03, ADMIN-05.
- `.planning/PROJECT.md` — hybrid lib+generator architecture, "generated host
  must ship a functional admin surface" invariant.

### Prior phase context that pins Phase 33's posture
- `.planning/phases/27-admin-access-foundation/27-CONTEXT.md` — admin shell
  seam ownership and scope chrome invariants.
- `.planning/phases/28-user-operations-surface/28-CONTEXT.md` — D-08 "scope
  visible in persistent shell chrome"; D-11 "mobile parity, same data different
  presentation"; D-24 "Recent audit is summary/preview only"; D-33 "Phase 28
  primitives reusable by Phase 29/30."
- `.planning/phases/29-secure-impersonation/29-CONTEXT.md` — impersonation
  visibility requirements (D-02/D-11 "visible state always").
- `.planning/phases/32-generated-installer-admin-surface-parity/32-01-PLAN.md`
  and `32-02-PLAN.md` — "fix + guard" precedent this phase follows.

### Target files for INT-04 port (verbatim-source + destination)
- `test/example/lib/example_web/components/admin_shell.ex` — verbatim source
  for `users_link/1`, top-bar scope-switch Users entry, desktop sidebar Users
  link, and mobile bottom-nav Users entry (lines 23-41, 52-60, 96-102, 191-194).
- `priv/templates/sigra.install/admin/components/admin_shell.ex` — destination
  template currently missing the Users link (dead `<span>` at line 67).
- `test/example/test/example_web/admin_shell_test.exs` — existing shell
  coverage the port must not regress (and may optionally extend).

### Target files for INT-05 Presenter integration
- `lib/sigra/admin/audit/presenter.ex` — canonical Presenter module; row shape
  that must be honored (`:action_label`, `:action_badge`, `:actor_summary`,
  `:actor_label`, `:effective_user_label`, `:outcome`, `:inserted_at`, `:id`,
  `:action`).
- `lib/sigra/admin/audit/explorer.ex:115-158` — precedent for load + present
  ownership inside a single module, plus the `load_users/2` pattern that
  `Detail` should mirror.
- `lib/sigra/admin/users/detail.ex:58-75` — current
  `recent_audit_preview/3` that returns raw `[struct()]` and must flip to
  `[map()]` (or gain a paired `_presented/3` helper per D-02).
- `lib/sigra/admin/live/user_show_live.ex:193-214` — preview section in the
  template; consumes `@detail.recent_audit`.
- `lib/sigra/admin/live/audit_user_live.ex:115-148` — reference rendering of
  Presenter rows in the per-user explorer, to stay coherent with.

### Regression-guard harness
- `test/sigra/templates/installer_drift_test.exs` — fixture-pair drift test
  to extend with the Users nav fixture (lines 29-70 for the existing pattern).

### Audit schema + query plumbing (read-only reference)
- `lib/sigra/admin/audit/query.ex` — filter build surface used by
  `recent_audit_preview/3`; do not modify in this phase.
- `lib/sigra/admin/audit/query_params.ex` — scope resolver; not directly
  touched but informs the `maybe_put_audit_scope/2` call site.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`Sigra.Admin.Audit.Presenter.present/2`** — already produces the exact row
  shape the preview needs. Pure functional module; no changes required.
- **`Sigra.Admin.Audit.Explorer` `load_users/2` helper** — already does the
  `users_by_id` lookup for Presenter input. Detail should either call this
  helper directly (if it's public-enough in practice) or mirror the pattern
  locally.
- **`Sigra.Admin.Audit.Query.build/2`** — already powers the preview's query;
  no changes required, no duplication needed.
- **`test/sigra/templates/installer_drift_test.exs`** — declarative fixture
  harness purpose-built for "fix landed on one side only" regressions. Append
  one `@fixtures` entry; nothing else.
- **`ExampleWeb.Components.AdminShell`** — authoritative source for the
  generator-template port. Already covered by
  `test/example/test/example_web/admin_shell_test.exs` so parity is testable.

### Established Patterns

- **Library owns long-lived runtime, host owns narrow seams.** The admin shell
  is host-owned (generator-emitted). The Presenter is library-owned. Phase 33
  sits cleanly on both sides of that seam.
- **Load + present ownership co-located in the admin query module.** Explorer
  already uses this pattern; Detail should adopt it.
- **Phase 32 "fix + guard" discipline.** Every fix landed in Phase 32 came
  with a generator test that regresses if the fix erodes. Phase 33 continues
  the pattern with the drift fixture.
- **Subset rendering in previews, full rendering in explorers.** Preview rows
  may render fewer Presenter fields than the explorer, but never more and
  never different — keeps information scent intact.

### Integration Points

- `priv/templates/sigra.install/admin/components/admin_shell.ex` — the ported
  Users nav chrome lands here; generator emission list does not need updating
  (the template file is already in `Sigra.Install.Features.Admin.files/1`).
- `lib/sigra/admin/users/detail.ex` — `recent_audit_preview/3` contract change
  lands here; `load!/3` calls it and will transparently surface the new shape.
- `lib/sigra/admin/live/user_show_live.ex` — preview rendering at lines
  207-213 must consume the new row keys (`row.action_badge`, `row.action_label`,
  `row.actor_summary`); today it consumes `event.action` raw.
- `test/sigra/templates/installer_drift_test.exs` — one new `@fixtures` entry.

</code_context>

<specifics>
## Specific Ideas

- Treat Phase 33 as a discipline test: every line of production change should
  map back to INT-04 or INT-05. Anything that doesn't is scope creep.
- Phase 30's Presenter is the single authority for audit row rendering across
  the admin surface. If the Phase 33 preview forces a field to exist on
  Presenter output that the explorer doesn't already show, stop and reconsider
  — the Presenter should lead, not trail.
- The drift fixture should read like the other fixtures in
  `installer_drift_test.exs`. Match its comment style, its regex verbosity,
  and its `must_have`/`must_not` rhythm — don't invent a new shape.
- Keep the port verbatim. If the template and example disagree on existing
  code outside the Users nav (e.g., `audit_link/1` uses a string path, other
  links use `~p`), that's a separate, later cleanup — not a Phase 33 change.
- The research agents concurred that this phase's seam choices should not
  introduce new Phoenix patterns. Every decision reuses something already
  shipped in v1.2.

</specifics>

<deferred>
## Deferred Ideas

- Generalized dead-text-as-nav detector in `installer_drift_test.exs`
  (WCAG SC 1.3.1 class). → Phase 35.
- EEx template render harness (evaluate `<%= web_module %>` bindings +
  `~p`-sigil resolution + verified-routes stub). → Phase 35's
  `generator_emission_audit_test.exs`.
- axe-core accessibility baselines and Playwright `toHaveScreenshot()`
  baselines for admin checkpoints. → Phase 35.
- `admin-generated.spec.ts` coverage for `/admin/users` on the freshly
  generated host. → Phase 34.
- `admin-acceptance-smoke.sh --test audit-export` and
  `--test impersonation-controller`. → Phase 34.
- Retroactive `28-VERIFICATION.md`. → Phase 34.
- Unifying the `audit_link/1` literal-string path with the `~p` sigil used
  elsewhere in the shell — minor code hygiene, separate phase.
- Refactoring `users_active?/1` from its current always-true stub to a
  path-aware predicate. Not a Phase 33 change; would require shell-wide
  active-state logic and is not a shipped defect.
- Adding LiveView-level telemetry for preview renders. Phase 30 already
  instruments audit reads; no new telemetry warranted here.
- CHANGELOG / upgrade-guide entry for the `Detail.recent_audit_preview/3`
  return-type flip. Only relevant if the planner's grep (per D-02) finds an
  external caller; otherwise this is v1.2-internal churn.

</deferred>

---

*Phase: 33-admin-shell-navigation-and-audit-preview-polish*
*Context gathered: 2026-04-17*
