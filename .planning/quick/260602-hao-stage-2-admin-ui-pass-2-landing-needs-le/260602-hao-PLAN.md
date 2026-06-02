---
phase: 260602-hao
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/sigra/admin/live/index_live.ex
  - lib/sigra/admin/live/organization_live.ex
  - test/example/priv/static/assets/css/app.css
autonomous: true
requirements: [STAGE2-LANDING-IA]
must_haves:
  truths:
    - "On the GLOBAL landing, the three job cards render ABOVE the metrics"
    - "On the ORG landing, the two job cards render ABOVE the metrics"
    - "Metrics are demoted to a compact posture strip but every count is still a live entry point (filter hrefs preserved)"
    - "Both landings show a foregrounded 'N accounts need review' risk line (needs_review = locked + deleted) linking to /admin/users?locked=true (org-scoped equivalent on the org landing)"
    - "The GLOBAL landing has an evaluator capability surface ('What Sigra can do') at the bottom, subordinate to the jobs"
    - "GLOBAL landing still contains the substring 'What do you need to do?'"
    - "ORG landing still contains the substring 'Work inside this organization scope'"
    - "mix compile --warnings-as-errors is clean (no unused private fns left behind)"
  artifacts:
    - path: "lib/sigra/admin/live/index_live.ex"
      provides: "Jobs-first GLOBAL landing: 3 job cards, posture strip with risk line, capability surface"
      contains: "What do you need to do?"
    - path: "lib/sigra/admin/live/organization_live.ex"
      provides: "Jobs-first ORG landing: 2 job cards, tightened Scoped attention posture, posture strip with risk line"
      contains: "Work inside this organization scope"
    - path: "test/example/priv/static/assets/css/app.css"
      provides: "Additive sg-posture-strip + sg-capability primitives (only if reuse insufficient)"
  key_links:
    - from: "lib/sigra/admin/live/index_live.ex"
      to: "/admin/users?locked=true"
      via: "risk-line href"
      pattern: "locked=true"
    - from: "lib/sigra/admin/live/index_live.ex"
      to: "/admin/users (+?confirmed/mfa/passkeys/locked/deleted=true) and /admin/audit"
      via: "preserved metric + job-card hrefs"
      pattern: "/admin/(users|audit)"
---

<objective>
Stage 2 of the approved admin-UI Pass 2 plan: reshape BOTH admin landing surfaces into a
needs-led launcher. Jobs go first (the visual centerpiece), metrics are demoted to a compact
posture strip with a foregrounded "needs review" risk line, and the GLOBAL landing gains an
evaluator capability surface. The ORG landing mirrors the same visual grammar, bounded to the org.

Purpose: Make "what you came to do" obvious on arrival (GOV.UK needs-led IA), keep every metric a
live entry point (demote visually, never delete the affordance), and orient evaluators (Dana) with
a glanceable capability inventory.

Output: Reshaped `index_live.ex` and `organization_live.ex`, plus (only if a reuse primitive does
not fit) minimal additive token-driven CSS in `app.css`.

SCOPE GUARDS (bake in, do not violate):
- These are LIBRARY-OWNED LiveViews (`lib/sigra/admin/live/`). Editing them changes ALL host apps.
  The example app consumes them via a path dep that is NOT hot-reloaded — changes are invisible
  until the server restarts. The ORCHESTRATOR handles the restart + screenshots; do not attempt it.
- Markup + minimal CSS ONLY. NO new queries, NO data-layer/seed changes, NO JS. The mount already
  loads `Query.summary_counts/2` returning `%{total, confirmed, mfa, passkeys, locked, deleted}` —
  stay within these counts. You MAY compute derived values (needs_review = locked + deleted) in the
  template/helpers; you may NOT add a new query. (Roster/invitations/org data is Stage 6.)
- Two pinned test substrings MUST survive (admin_shell_test.exs): GLOBAL "What do you need to do?"
  (the h1 — keep verbatim) and ORG "Work inside this organization scope" (keep; may sit inside a
  longer sentence). No other landing copy is pinned — reshape freely.
- Do NOT add a "Browse organizations" card on the GLOBAL landing: no global organizations-index
  route exists. Global destinations are only `/admin/users` (+`?confirmed/mfa/passkeys/locked/deleted=true`)
  and `/admin/audit`. Org scope is reached via the topbar scope switcher, not a landing card.
- Stage 8 (not this plan) refreshes any landing screenshots; landing baselines are not pinned.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@./CLAUDE.md

<interfaces>
<!-- Data available at mount (do NOT add queries). From Sigra.Admin.Users.Query.summary_counts/2 -->
@summary_counts is a map: %{total: int, confirmed: int, mfa: int, passkeys: int, locked: int, deleted: int}
Access defensively with Map.get(@summary_counts, :key, 0) (existing pattern in both files).
Derived (compute in-template/helper, no query): needs_review = locked + deleted.

GLOBAL landing valid hrefs (index_live.ex):
  /admin/users
  /admin/users?confirmed=true | ?mfa=true | ?passkeys=true | ?locked=true | ?deleted=true
  /admin/audit
ORG landing valid hrefs (organization_live.ex) use the existing helpers:
  users_path(@admin_scope)  -> "/admin/organizations/#{slug}/users"  (append "?locked=true" etc.)
  audit_path(@admin_scope)  -> "/admin/organizations/#{slug}/audit"

Existing local function components in BOTH files (reuse, do not duplicate logic): tile/1, task_card/1, status_label/1.
organization_live.ex also has: organization_name/1, locked_summary/1.
</interfaces>

<reusable_css>
<!-- Prefer these existing sg-* primitives over new classes -->
Layout:   sg-stack (+--1/2/3/5/6), sg-grid (+--2/--3), sg-cluster (+--between/--end/--start/--3), sg-section
Surfaces: sg-card, sg-card-hover, sg-metric-grid, sg-metric (+__label/__value), sg-tile (+__pill), sg-list, sg-list-row (data-tone)
Type:     sg-page-header, sg-page-kicker, sg-page-title, sg-page-copy, sg-section-heading, sg-section-copy, sg-meta-label, sg-meta-value
Status:   sg-status-pill (data-tone="ok|warn|risk|info"; auto icon via ::before; +text required for WCAG 1.4.1)
Buttons:  sg-btn, sg-btn--primary (+--secondary/--ghost/--sm)
Tokens:   --sg-space-1..12, --sg-text-xs/sm/lg, --sg-radius-md, --sg-color-panel/-alt/-line/-muted/-ink, --sg-elev-1, --sg-weight-bold, --sg-tracking-wide (all have dark-mode overrides)
</reusable_css>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Reshape GLOBAL landing (index_live.ex) — jobs first, posture strip, capability surface</name>
  <files>lib/sigra/admin/live/index_live.ex</files>
  <action>
Reorder and relabel the render/1 template into the needs-led IA. New top-to-bottom order inside the
outer `<section class="sg-stack sg-stack--6">`:

1. KEEP the existing `<header class="sg-page-header">` exactly: kicker "Admin overview", h1
   "What do you need to do?" (PINNED — do not alter the h1 text), and the copy paragraph. You may
   lightly tighten the copy but it must still describe starting from the job at hand and that the
   counts are live entry points. Do NOT remove the h1 substring.

2. JOBS FIRST (move the existing `<div class="sg-grid sg-grid--3">` of task_cards to be the FIRST
   thing after the header — above the metrics). Keep `sg-grid sg-grid--3` and `task_card/1`
   (sg-card sg-card-hover). Relabel the three cards to crisp needs-led verbs, ordered
   Sam → Riley → triage (highest-traffic support path first):
     - title "Find a user", href "/admin/users", action "Find a user",
       body: search by email or ID, inspect security state, revoke sessions, and start support actions.
     - title "Investigate an event", href "/admin/audit", action "Investigate audit",
       body: filter security events, distinguish actor from effective user, and export CSV evidence.
     - title "Review risky accounts", href "/admin/users?locked=true", action "Review locked",
       body: jump straight to locked or deletion-scheduled accounts before they surprise support.

3. POSTURE STRIP (demote the metrics — they currently sit in `sg-metric-grid` with big `tile/1`
   tiles ABOVE; move them BELOW the jobs and make them visually secondary). Render a single
   `<section class="sg-card sg-posture-strip sg-stack sg-stack--3">` containing:
     a. A foregrounded RISK LINE as the first row: compute needs_review = locked + deleted. Render an
        `<a href="/admin/users?locked=true" ...>` wrapping an `sg-status-pill` with
        data-tone={if needs_review > 0, do: "risk", else: "ok"} and text
        "#{needs_review} accounts need review" when >0 else "All clear". Keep it prominent (it is the
        one thing on the strip that must pop). The pill already gets an icon via CSS ::before (WCAG-safe).
     b. The six counts as SMALL clickable entry points (preserve every existing filter href). Replace
        the big `sg-metric-grid`+`tile/1` presentation with a compact `sg-cluster sg-cluster--3`
        (or `sg-metric-grid` if it reads cleaner) of small links — each an `<a class="sg-metric-link">`
        (new minimal class, Task 3) showing label + value. Preserve hrefs: Total→/admin/users,
        Confirmed→?confirmed=true, MFA→?mfa=true, Passkeys→?passkeys=true (ADD passkeys — it is in the
        counts map and was not surfaced before), Locked→?locked=true, Deleted→?deleted=true. Counts must
        stay live entry points — demote visually, do not delete the affordance.
   Decide whether to keep `tile/1` for any remaining use. If `tile/1` and/or `status_label/1` become
   unused after the reshape, REMOVE them (warnings-as-errors will fail on unused private fns). If you
   keep small metric links via a new local component, define it here.

4. CAPABILITY SURFACE at the BOTTOM (Dana, secondary/subordinate). Add a "What Sigra can do" section:
   `<section class="sg-stack sg-stack--3">` with an `<h2 class="sg-section-heading">What Sigra can do</h2>`
   + one-line `sg-section-copy` ("This admin console surfaces:") then a labeled set rendered via a new
   local `capability/1` component inside `sg-grid sg-grid--3` (or `sg-capability` grid from Task 3).
   Each item: a short label + a one-line static descriptor. Use STATIC text only (no data). Items —
   describe only what the admin UI actually surfaces, do not overstate:
     - "Sessions" — view and revoke active sessions per user.
     - "MFA (TOTP)" — see TOTP enrollment and backup-code state.
     - "Passkeys" — inspect registered WebAuthn credentials.
     - "OAuth identities" — view linked social/OIDC identities.
     - "Audit evidence" — filter security events and export CSV.
     - "Impersonation" — start scoped sudo sessions with an audit trail.
     - "Organization scoping" — operate bounded to a single tenant.
   Keep this section clearly subordinate to the jobs (smaller cards/muted surface; it is orientation,
   not a daily-use surface).

Keep mount/1, runtime_config!/0 and all aliases untouched. Use `Map.get/3` defensively for all counts
(existing pattern). No new assigns, no new queries.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/sigra && mix compile --warnings-as-errors 2>&1 | tail -5</automated>
    Also: grep -q "What do you need to do?" lib/sigra/admin/live/index_live.ex && grep -q "locked=true" lib/sigra/admin/live/index_live.ex && grep -q "passkeys=true" lib/sigra/admin/live/index_live.ex && grep -q "What Sigra can do" lib/sigra/admin/live/index_live.ex
  </verify>
  <done>
GLOBAL landing renders job cards above the metrics; metrics demoted to a posture strip with a
foregrounded needs_review risk line linking to /admin/users?locked=true; all six counts (incl. new
passkeys) are still live filtered-list links; a "What Sigra can do" capability surface sits at the
bottom; "What do you need to do?" substring preserved; compile clean with no unused private fns.
  </done>
</task>

<task type="auto">
  <name>Task 2: Reshape ORG landing (organization_live.ex) — mirror structure, bounded to org</name>
  <files>lib/sigra/admin/live/organization_live.ex</files>
  <action>
Mirror Task 1's grammar/ordering, bounded to the organization. New order inside the outer
`<section class="sg-stack sg-stack--6">`:

1. KEEP the `<header class="sg-page-header">`: kicker "Organization overview", h1 {@organization_name},
   and the copy paragraph containing the PINNED substring "Work inside this organization scope"
   (keep it verbatim within the sentence — do not drop it).

2. JOBS FIRST: move the existing `<div class="sg-grid sg-grid--2">` of two task_cards to be the FIRST
   block after the header (above the metrics and above the Scoped attention card). Keep `sg-grid sg-grid--2`
   and `task_card/1`. Relabel to needs-led verbs, bounded to org:
     - title "Support members", href users_path(@admin_scope), action "Open members",
       body: search org members, open account detail, and pivot through session, security, and membership state.
     - title "Investigate org events", href audit_path(@admin_scope), action "Open audit",
       body: filter audit evidence scoped to this organization and export only its events.

3. KEEP and TIGHTEN the existing "Scoped attention" `sg-card` (it is already posture-shaped and good).
   Place it after the jobs. Keep the posture pill (Healthy/Needs review driven by locked>0) and the
   `sg-list` rows (Risk queue / Evidence boundary). Tighten copy if helpful; do not rebuild.

4. POSTURE STRIP (demote the 4-tile `sg-metric-grid`): replace it with a compact strip consistent with
   the global landing. Render the foregrounded RISK LINE first — needs_review = locked + deleted (org
   counts) as an `<a href={users_path(@admin_scope) <> "?locked=true"}>` wrapping an `sg-status-pill`
   (data-tone risk if needs_review>0 else ok) reading "#{needs_review} accounts need review" / "All clear".
   Then the counts as small clickable links via the shared `sg-metric-link` style (Task 3): Users→
   users_path, Confirmed→"?confirmed=true", MFA→"?mfa=true", Passkeys→"?passkeys=true" (ADD passkeys),
   Locked→"?locked=true". Preserve every href through the existing users_path/1 helper. You may fold the
   risk line into the Scoped attention card if it reads cleaner — but it must appear once and be
   prominent. Counts stay live entry points.

   NOTE the duplicated "needs review" affordance: the Scoped attention pill and the strip risk line both
   key off locked. That is acceptable (posture summary vs metric drill-down), but keep wording distinct
   and do not double-count — the strip risk line uses needs_review (locked+deleted), the Scoped pill may
   stay locked-only as today.

5. Optionally add ONE short capability LINE bounded to org scope (e.g. a single `sg-section-copy`
   under the strip: "Bounded to this org: members, audit evidence, impersonation, scoping."). Keep it
   lean — the full capability surface is the global evaluator concern, NOT repeated here.

If `tile/1` and/or `status_label/1` become unused after demoting the metric grid, REMOVE them
(warnings-as-errors). Keep mount/1, organization_name/1, users_path/1, audit_path/1, locked_summary/1,
runtime_config!/0 and aliases. Use `Map.get/3` defensively. No new assigns or queries.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/sigra && mix compile --warnings-as-errors 2>&1 | tail -5</automated>
    Also: grep -q "Work inside this organization scope" lib/sigra/admin/live/organization_live.ex && grep -q "?locked=true" lib/sigra/admin/live/organization_live.ex && grep -q "?passkeys=true" lib/sigra/admin/live/organization_live.ex
  </verify>
  <done>
ORG landing renders two needs-led job cards above the metrics; Scoped attention card retained/tightened;
4-tile grid demoted to a posture strip with a foregrounded needs_review risk line linking to the
org-scoped ?locked=true list; counts (incl. new passkeys) remain live org-scoped links; "Work inside
this organization scope" substring preserved; compile clean with no unused private fns.
  </done>
</task>

<task type="auto">
  <name>Task 3: Add minimal shared posture/capability CSS (only what reuse cannot cover)</name>
  <files>test/example/priv/static/assets/css/app.css</files>
  <action>
Add ONLY the small additive classes the reshape needs that existing primitives do not cover. Prefer
reusing sg-card / sg-cluster / sg-metric / sg-status-pill / sg-grid — add a new class only where the
markup in Tasks 1–2 references one. Place additions inside the existing `@layer sg-components` block,
near the metric/tile rules (~line 1078). BEM names, mobile-first, every value references a token, NO
new `!important`, and ensure dark-mode works by using tokens that already have dark overrides
(--sg-color-panel-alt, --sg-color-line, --sg-color-muted, --sg-color-ink).

Add (only those actually referenced by your markup):

1. `.sg-posture-strip` — a compact, visually SECONDARY container modifier used on the demoted-metrics
   `sg-card`. Make it read as secondary vs the job cards: e.g. background var(--sg-color-panel-alt),
   reduced padding (var(--sg-space-3)), and a subtle 1px inset line (box-shadow var(--sg-elev-inset))
   instead of full elevation. Do not let it compete with the job cards above it.

2. `.sg-metric-link` — a small clickable count entry point (replaces the big sg-tile on the strip).
   Inline-ish, compact: display flex column or row, gap var(--sg-space-1), padding var(--sg-space-2),
   border-radius var(--sg-radius-sm), text-decoration none, color inherit. A muted uppercase label
   (reuse sg-metric__label sizing tokens: var(--sg-text-xs), var(--sg-color-muted),
   var(--sg-tracking-wide)) and a tabular-nums value (var(--sg-text-sm) or --sg-text-lg, not the big
   metric value). Hover: subtle box-shadow var(--sg-elev-1) under @media (hover: hover) and (pointer: fine);
   focus-visible: box-shadow var(--sg-focus-ring). Keep it clearly smaller than sg-tile.

3. `.sg-capability` + `.sg-capability__item` (+ `__label` / `__desc`) — the evaluator capability grid.
   `.sg-capability__item`: small subordinate card — background var(--sg-color-panel-alt), padding
   var(--sg-space-3), border-radius var(--sg-radius-md), box-shadow var(--sg-elev-inset).
   `__label`: var(--sg-weight-bold), var(--sg-text-sm), var(--sg-color-ink).
   `__desc`: var(--sg-text-xs), var(--sg-color-muted), line-height ~1.4.
   (If you render the capability items with plain sg-card inside sg-grid--3 and they already read as
   subordinate, you may SKIP sg-capability entirely — only add classes your markup uses.)

Do NOT touch tokens, do NOT modify existing class bodies, do NOT add a template-source copy (this CSS
lives only in test/example; there is no sigra.install landing-CSS template to keep in sync for these).
If Tasks 1–2 ended up needing zero new classes (full reuse), make this task a no-op and note it in the
SUMMARY — that is a valid outcome.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/sigra/test/example && grep -cE '!important' priv/static/assets/css/app.css; git -C /Users/jon/projects/sigra diff --stat test/example/priv/static/assets/css/app.css</automated>
    Confirm no NEW `!important` was introduced (count unchanged from before this task) and any added classes are referenced by index_live.ex / organization_live.ex (grep the class names in both .ex files).
  </verify>
  <done>
Any new CSS is additive, token-driven, BEM, mobile-first, dark-mode-safe, introduces no new
`!important`, lives only in test/example app.css, and every added class is referenced by the reshaped
LiveViews. If full reuse was achievable, no CSS was added and this is recorded as a no-op.
  </done>
</task>

</tasks>

<verification>
Phase-level checks (run from /Users/jon/projects/sigra unless noted):

1. Compile clean: `mix compile --warnings-as-errors` (catches unused private fns from removed
   tile/1 or status_label/1).
2. Pinned substrings preserved:
   - `grep -q "What do you need to do?" lib/sigra/admin/live/index_live.ex`
   - `grep -q "Work inside this organization scope" lib/sigra/admin/live/organization_live.ex`
3. Shell test still green (asserts both substrings):
   `cd test/example && mix test test/example_web/admin_shell_test.exs`
4. Metrics remain live entry points: grep both files for the preserved filter hrefs
   (`confirmed=true`, `mfa=true`, `passkeys=true`, `locked=true`, `deleted=true` on global;
   org equivalents via users_path).
5. Risk line present on both landings (grep `accounts need review`).
6. Capability surface present on global landing (grep `What Sigra can do`).
7. No new queries/JS introduced: `git diff lib/sigra/admin/live/*.ex` shows no new alias/Query call
   beyond the existing `Query.summary_counts`; no `.js` files changed.

VISUAL VERIFICATION IS DEFERRED TO THE ORCHESTRATOR: these are library-owned LiveViews behind a
non-hot-reloaded path dep — a server restart is required to see the reshape. The orchestrator
performs the restart + Playwright screenshots; Stage 8 refreshes any landing baselines. Do NOT
attempt the restart or screenshots in this plan.
</verification>

<success_criteria>
- GLOBAL and ORG landings both lead with needs-led job cards ABOVE the metrics.
- Metrics demoted to a compact posture strip; every count remains a clickable filtered-list entry
  point (including the newly-surfaced passkeys count); a foregrounded "N accounts need review"
  (needs_review = locked + deleted) risk line links to the (org-scoped) locked users list.
- GLOBAL landing carries an evaluator capability surface ("What Sigra can do") at the bottom,
  clearly subordinate to the jobs.
- Both pinned substrings preserved; admin_shell_test.exs green.
- `mix compile --warnings-as-errors` clean; no unused private functions.
- No new queries, no data-layer/seed changes, no JS. Any new CSS is additive, token-driven, BEM,
  dark-mode-safe, with no new `!important`.
- Both landings share the same visual grammar (cards → posture strip → capability), differing only
  in scope-boundedness.
</success_criteria>

<output>
Create `.planning/quick/260602-hao-stage-2-admin-ui-pass-2-landing-needs-le/260602-hao-SUMMARY.md` when done.
In the SUMMARY, explicitly flag: (1) these are LIBRARY-OWNED LiveViews — a server restart is required
to see changes (orchestrator handles it); (2) Stage 8 will capture/refresh any landing screenshots;
(3) whether Task 3 added CSS or was a no-op (full reuse).
</output>
