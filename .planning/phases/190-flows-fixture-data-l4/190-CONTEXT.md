# Phase 190: Flows & Fixture Data (L4) - Context

**Gathered:** 2026-06-17 (assumptions mode + deep research)
**Status:** Ready for planning

<domain>
## Phase Boundary

L4 — the top level of the fractal admin design-system program (L0 tokens → L1 components
→ L2 groups → L3 pages → **L4 flows**). Phase 190 grades the three admin *operator JTBD
journeys* — **platform admin / support investigator / org admin** — against the existing
L4 Flow Add-ons in `guides/reference/admin-fractal-scorecard.md` (~lines 103–122): each flow
passes happy + main-error + boundary with scope and return-context preserved, is fully
keyboard-operable with visible focus, stays calm under `prefers-reduced-motion`, persists
Light/Dark/System across the whole flow and on reload, and is reproducible from a single
deterministic demo seed/persona fixture.

**This is a test-authoring + ledger-ratification phase over already-built admin UI** — not
feature construction. The admin LiveViews, the `Sigra.Impersonation` capability, the
client-side theme hook, the reduced-motion CSS guard, the URL-encoded list scope, the
breadcrumb/scope-ribbon continuity, and the 9-persona deterministic demo seed all already
exist. Phase 190 fills evidence into and ratifies new L4 ledger rows.

In scope: authoring deterministic Playwright flow specs for the 3 operator journeys;
verifying (and, only where a case is genuinely missing, enriching example-only) the demo
seed so each flow's happy/error/boundary case reproduces; asserting keyboard / reduced-motion
/ theme-persistence / return-context over existing behavior; and ratifying the 3 L4 ledger
rows. **Out of scope:** new token values (L0, locked), new/changed L1 components or L2 groups
(graded), page-archetype re-grading (L3 → Phase 189), the system-wide microcopy/voice glossary
sweep (Phase 191), terminal idempotency/baseline-lock (Phase 192), and any net-new
authorization model (a distinct least-privilege investigator role → deferred future milestone).
Requirements FLOW-01, FLOW-02, FLOW-03, DATA-01.
</domain>

<decisions>
## Implementation Decisions

### Persona model & investigator posture (FLOW-01, DATA-01)
- **D-01:** The three operator personas are taken verbatim from `admin-ui-principles.md:9-13`:
  **platform admin** (global, needs-led, launcher-first — starts at `/admin`), **support
  investigator** (subject/evidence-first — starts from a user or event, scope visible, safe
  next actions with clear return paths), **org admin** (tenant-bounded, no global noise).
  The **support investigator is the platform admin in an investigation *posture*, NOT a distinct
  authorization role** — per Sigra's own doctrine it is a named persona with no separate authz
  tier, distinguished only by entry point and need. The investigator flow is driven by the
  existing seeded admin operator (`admin@demo.vaultr.test`) acting *on* subject personas. No new
  seeded user and no new RBAC role are introduced in this phase.
- **D-02:** The canonical investigator journey mirrors the scorecard's L4 example
  (`admin-fractal-scorecard.md:105-106`): find the account → review per-user audit evidence
  (read) → impersonate (existing `lib/sigra/impersonation.ex`, already audited
  `admin.impersonation.start`/`stop`) → resolve → return to prior context. The flow spec asserts
  **journey-level** properties (continuity, keyboard, theme, scope/return); it does **not**
  re-test impersonation internals — those stay owned by `impersonation.spec.ts` (its D-06).

### Persona → flow case mapping & DATA-01 fixture (FLOW-01, DATA-01)
- **D-03:** Flow-driver mapping: **platform admin** = `admin@demo.vaultr.test` in global posture
  (overview → needs → users → audit → org pivot); **support investigator** = the same operator
  in subject-first posture (D-01/D-02); **org admin** = `morgan@demo.vaultr.test` (non-platform
  Acme admin, tenant-bounded console).
- **D-04:** Happy/error/boundary cases are driven by existing seeded subjects:
  **happy** = `alice` (standard confirmed Acme member); **main-error** = `dave`
  (locked/unconfirmed → `auth.login.failure` + `auth.lockout.start` audit) and, for the org-admin
  scope, a **permission-denied** out-of-tenant access; **boundary** = `frank`/`grace`
  (scheduled-deletion), the expired/pending invitation pair, and a true **empty/no-data** state.
- **D-05:** DATA-01 is satisfied by the existing `Example.Demo.Seeds.run/0` fixture via
  `mix run priv/repo/seeds.exs`. The planner **verifies** each flow's three cases are reproducible
  and **enriches only the genuine gaps** (most likely the org-admin permission-denied path and/or
  a true empty/no-data boundary if not already reachable). Any enrichment seeds the **terminal
  state directly** (never browser-driven setup — no failed-login loops, no rate-limit timing),
  uses timestamps **relative to the pinned `@seed_reference_ts`**, idempotent upserts
  (`on_conflict`), the `MIX_ENV == :test` raise-guard, and the `demo.vaultr.test` segregation.

### Fixture scope — example-only, no parity duty (DATA-01)
- **D-06:** Any seed enrichment lands **only** in `test/example/lib/example/demo/{personas,seeds}.ex`
  driven by `priv/repo/seeds.exs`. It does **not** touch `priv/templates/sigra.install/` and carries
  **no byte-identical-mirror obligation** — the 187/189 three-surface parity rule governs shipped
  **CSS and JS only**, not demo seed data. No generator ships personas; there is no generated-host
  fixture obligation.

### Ledger shape & spec organization (FLOW-01..03, DATA-01)
- **D-07:** L4 adds **3 ledger rows** to `guides/reference/admin-quality-ledger.md` —
  `flow-platform-admin`, `flow-support-investigator`, `flow-org-admin` — at `Level = L4`,
  lowercase-item / single-integer-tier (monotonic-guard parseable, `^\| [a-z]`), appended below
  the 6 L3 rows. **One row per operator flow (surface), never per requirement** — requirements
  FLOW-01/02/03 + DATA-01 are scored *as criteria inside* each row, preserving the fractal
  anchor's per-surface invariant (L1=13, L2=11, L3=6 rows).
- **D-08:** Each flow's tier is **weakest-link bounded** (`min()` rollup, not average): it cannot
  exceed the lowest tier of its constituent L3 pages, and is further gated by its **flow-only
  criteria** (happy/error/boundary coverage, scope/return-context preserved, full keyboard
  operability, calm reduced-motion, theme persistence across flow + reload, deterministic-fixture
  reproduction). This is the documented scoring rationale; mechanically it remains 3 rows. Tier
  *demotion* stays a first-class, low-friction operation (forward-biased, not forward-locked).
- **D-09:** Authored as **3 per-persona flow specs** on the **`chromium` behavior-truth lane**
  (e.g. `admin-flow-platform-admin.spec.ts`, `admin-flow-support-investigator.spec.ts`,
  `admin-flow-org-admin.spec.ts`), sharing a new `helpers/adminFlows.ts` for login / navigation /
  theme / keyboard / LiveView-readiness utilities. Rationale: one persona = one journey = one file
  (blast-radius isolation, file-level parallelism, 1:1 mapping to the 3 ledger rows). Reuse the
  established `waitForLiveViewReady` (`[data-phx-session].phx-connected`), role-selector + stable
  testid conventions; **web-first auto-retrying assertions only, no sleeps** (deterministic against
  LiveView async morphdom). Behavior runs on `chromium`; mobile/dark stay capture-only
  (`playwright.config.ts:88-145`). Planner may consolidate into one `admin-flows.spec.ts` only if
  helper-sharing proves materially cleaner — default is per-persona files.

### Keyboard / reduced-motion / theme persistence (FLOW-02, FLOW-03)
- **D-10:** No net-new CSS/JS is expected — assertion over already-built behavior. Concrete strategy:
  - **Keyboard:** `Tab`/`Enter`/`Space`/`Esc`; auto-retrying `toBeFocused()`; assert focus **returns
    to the trigger** after a confirm dialog closes and is **contained** while open (assert the
    invariant "focus still inside the dialog", not the exact element after a fixed Tab count); assert
    the visible focus ring **only after a keyboard Tab, never after a click** (a click suppresses
    `:focus-visible` → false negative).
  - **Reduced-motion:** set `reducedMotion: 'reduce'` at the **context/config level**, not per-page
    after `goto` (Firefox drops the latter — playwright#31328); assert the **collapsed effect**
    (`transition`/`animation-duration` → `0s`) over the existing `@media (prefers-reduced-motion:
    reduce)` guard (`sigra_admin.css:1467`), not merely `matchMedia().matches`.
  - **Theme:** assert the **`data-sg-admin-theme` (root) / `data-theme` (shell) attribute +
    `localStorage['sigra.admin.theme']`** — **never computed colors** (keep at most one `toHaveCSS`
    smoke to prove tokens wire through). Cover persistence across LiveView navigation **and an
    explicit `page.reload()`** **and** a System (`prefers-color-scheme`) flip without reload.
    No-flash is asserted as an **initial-state assertion** (seed the stored choice via
    `addInitScript` *before* `goto`, assert the attribute is already correct on first paint) **plus**
    a static check that the head `applyTheme` script (`admin_hooks.js:83`) is present and **not**
    `async`/`defer`.
- **D-11:** **Boundary / escalation:** the default is pure test authoring. *If* a flow surfaces a
  real keyboard trap, a missed reduced-motion transition, or a theme-flash-on-reload, the fix
  becomes a **shipped CSS/JS slice** that **does** trip the three-surface byte-parity rule (D-10/D-11
  carried from 187/189) — a generated-host change, escalation-worthy under METHODOLOGY. Flag it; do
  not silently absorb it as test-only.

### Return-context continuity (FLOW-01)
- **D-12:** "Scope/return-context preserved" is asserted against **existing shipped continuity**
  (deferred here from 189 — `189-CONTEXT.md:185`): **URL-encoded list scope** (`?q=`/`order_by`)
  reconstructed on return; breadcrumb **back-to-filtered-list**; persistent **scope ribbon** + the
  **impersonation banner** across the journey; filter + pagination (+ scroll) restored **as one
  coherent set**, never partially. If a return path actually drops state, that is a small LiveView
  state-preservation fix in `lib/sigra/admin/live/` (a scoped expansion the planner flags), not a
  test-only change.

### Microcopy / brand voice — flow-local only (FLOW-01)
- **D-13:** Flow tests **assert existing copy** in flow states against ratified brand strings
  (`brand-book.md:245-249`: expired-link error, audit empty-state, "Session revoked…" success) and
  brand-voice rules (errors = what failed + why + next action; severity-honest color — red only for
  business-harm, neutral for routine session-expired/empty states; status-not-blame; name both
  parties during impersonation; empty ≠ broken; **uniform/generic message at the auth boundary** for
  anti-enumeration). The **system-wide voice glossary sweep is Phase 191** — Phase 190 stays
  flow-local: route any copy gaps found to 191, do not author a glossary here.

### Folded Todos
- **D-14:** Fold `2026-06-17-phase-189-review-deferred` (189-REVIEW WR-01..04):
  - **WR-01** — target an explicit `[data-sg-confirm-cancel]` element instead of positional
    `focusables[0]`; **WR-02** — focus-return `<body>`-sentinel fallback when the trigger blurs;
    **WR-03** — Escape handler `stopImmediatePropagation` so co-resident document listeners don't
    also fire. These harden the ConfirmDialog focus/keyboard behavior that **FLOW-02's keyboard
    traversal exercises**, so they are coherent in-scope work. They touch shipped
    `admin_hooks.js` → **byte-identical mirror obligation applies** (both
    `priv/templates/sigra.install/admin/admin_hooks.js` and `test/example/assets/js/admin_hooks.js`).
  - **WR-04** — `branding_live` `error_message/1` maps known error structs (e.g. `%Ecto.Changeset{}`)
    to human copy instead of leaking a raw `inspect/1`; coherent with **FLOW-01's org-admin branding
    error case** and the D-13 brand-voice error rule.
  - Re-run the example admin browser/behavior tests after. Sequencing relative to the flow specs is
    planner discretion.

### Claude's Discretion (planner resolves — below escalation threshold)
- Per-persona spec files (default) vs a single consolidated `admin-flows.spec.ts`.
- The exact seed-enrichment gaps after verification (most likely org-admin permission-denied and/or
  empty/no-data boundary), and whether any new subject persona vs reusing existing seeded subjects.
- Whether to introduce `storageState`-per-persona Playwright projects (optimization) vs the current
  inline/helper login pattern — default to a shared login helper, no new project infra.
- Exact L4 tier achieved per flow after evidence (the monotonic guard is the floor).
- Sequencing of the folded ConfirmDialog/branding hardening relative to the flow specs.
- Whether keyboard-frequent paths need any reduced-motion CSS tightening (only if a real violation
  surfaces → then D-11 escalation applies).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `guides/reference/admin-fractal-scorecard.md` — the fixed L0–L4 grading anchor; **L4 Flow
  Add-ons at ~lines 103–122** (the canonical operator-flow example and the 6 L4 criteria). Do not
  author a parallel rubric.
- `guides/reference/admin-quality-ledger.md` — the machine-parseable monotonic-guard ledger; the
  3 new L4 rows are appended here below the 6 L3 rows.
- `guides/reference/admin-ui-principles.md` — **Primary personas (lines 9–13)**: the source of
  the platform admin / support investigator / org admin definitions and the
  scope-visible / return-context expectations; also theme + focus + motion doctrine.
- `guides/reference/admin-design-contract.md` — sg-* design-system contract: scope ribbon /
  breadcrumb / `page_back` continuity, `sg-confirm-overlay` (never generic `.modal[open]`),
  theme attributes, same-job-same-component.
- `brandbook/brand-book.md` — **current v2** brand voice (precise/honest/useful/calm/maintainer-grade)
  and the ratified microcopy strings (lines ~186–211, 245–249) the flow tests assert against.
- `prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md` — JTBD failure-mode
  catalog feeding the happy/error/boundary case design (note: its A–E personas are *adopters/installers*,
  not the admin operators — the operator personas come from `admin-ui-principles.md`).
- `.planning/phases/187-individual-components-l1/187-CONTEXT.md` and
  `.planning/phases/189-page-compositions-l3/189-CONTEXT.md` — the three-surface byte-parity rule
  (187 D-01..04 → 189 D-10/D-11), snapshot/canary evidence conventions, honest-pagination + the
  explicit deferral of return-context continuity to Phase 190 (189 D-09, 189-CONTEXT.md:185).
- `lib/sigra/impersonation.ex` + `test/example/priv/playwright/tests/impersonation.spec.ts` — the
  shipped impersonation capability and its canonical mechanics spec (D-06 there); the investigator
  flow asserts journey-level behavior over these, not their internals.
- `test/example/lib/example/demo/personas.ex` + `seeds.ex` — the deterministic 9-persona demo
  fixture (`Example.Demo.Seeds.run/0`), the DATA-01 source of truth.
- External standards (validated, score on *behavior*): WAI-ARIA APG Dialog (Modal)
  (https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/); WCAG 2.4.7 focus-visible
  (https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html), 2.4.11 focus-not-obscured,
  2.1.2 no-keyboard-trap; WCAG 2.3.3 / `prefers-reduced-motion`
  (https://www.w3.org/WAI/WCAG21/Understanding/animation-from-interactions.html); `prefers-color-scheme`
  no-flash bootstrap (https://web.dev/articles/color-scheme).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Library-owned admin LiveViews** (`lib/sigra/admin/live/`): `index_live.ex`,
  `organization_live.ex`, `users_index_live.ex`, `user_show_live.ex`, `branding_live.ex`,
  `audit_index_live.ex`, `audit_user_live.ex` — each already renders its archetype shape with
  URL-encoded scope (`?q=`/`order_by`), breadcrumbs, scope ribbon, and honest pagination.
- **`Sigra.Impersonation`** (`lib/sigra/impersonation.ex`) — shipped, wired into `user_show_live.ex`,
  audited `admin.impersonation.start`/`stop`; persistent banner + stop→return proven in
  `impersonation.spec.ts:130-143`.
- **Deterministic demo fixture** — `personas.ex` (9 `@demo.vaultr.test` personas incl.
  `Admin (operator)` and `Morgan (org admin)`; pure data) + `seeds.ex` (`run/0`, idempotent,
  pinned `@seed_reference_ts ~U[2026-05-15 12:00:00Z]`, `MIX_ENV=test` raise-guard; seeds orgs,
  memberships, expired/pending invitations, TOTP/passkeys, sessions, SSO, ≥30 audit rows).
- **Theme hook** — `admin_hooks.js` (localStorage key `sigra.admin.theme`, `applyTheme` head script
  at load preventing flash, `data-sg-admin-theme`/`data-theme` attributes); cross-nav persistence +
  axe gate already asserted in `admin-theme.spec.ts:396-485` (missing only `reload()` + full-flow span).
- **Reduced-motion CSS guard** — `@media (prefers-reduced-motion: reduce)` block at
  `sigra_admin.css:1467`. `emulateMedia({reducedMotion})` already used in design/theme/showcase specs;
  `keyboard.press('Tab')` + focus assertions already used in `admin-modal-interaction.spec.ts`.
- **Behavior lane** — `chromium` project (behavior truth); mobile/dark are capture-only
  (`playwright.config.ts:88-145`, `ADMIN_BEHAVIOR_SPECS` regex). `helpers/` dir already holds shared
  Playwright utilities; `waitForLiveViewReady` is the established readiness gate.

### Established Patterns
- Three-surface byte-parity for shipped CSS/JS (canonical template + example mirror + golden-fixture
  mirror) — applies to the WR-01/02/03 `admin_hooks.js` hardening, NOT to demo seed data.
- Value-locked L0 tokens + monotonic quality-ledger guard (merge-blocking) — never re-tune; tier is
  weakest-link, demotion is first-class.
- Zero-human UAT: deterministic Playwright + axe, role selectors, stable testids, LiveView readiness
  gates, web-first assertions, no sleeps. Seed terminal states directly; relative timestamps; idempotent.

### Integration Points
- New flow specs attach to existing LiveViews + the shipped impersonation/theme behavior via shared
  helpers; the 3 new L4 ledger rows reference these specs as evidence. Folded `admin_hooks.js`
  hardening propagates to both mirrors. Any seed enrichment stays inside the example app.
</code_context>

<specifics>
## Specific Ideas

- Investigator = admin-in-investigation-posture per Sigra doctrine (not a new authz role); drive it
  with the existing admin operator against subject personas.
- Assert keyboard/focus on **behavior** (focus-return-to-trigger, containment, focus-visible-after-Tab)
  per APG; reduced-motion at context level asserting the collapsed *effect*; theme via
  attribute + localStorage (never computed color), covering nav + reload + system-flip + no-flash.
- Return-context = URL-encoded scope restored as one coherent set + persistent scope/impersonation
  banner; breadcrumb back-to-filtered-list.
- Score each flow as a weakest-link rollup of its pages + flow-only criteria; 3 ledger rows, not
  per-requirement.
- Microcopy stays flow-local (assert ratified strings); glossary is Phase 191.
</specifics>

<deferred>
## Deferred Ideas

- **Distinct least-privilege "support investigator" RBAC role + break-glass impersonation
  hardening** — the best-in-class prior-art pattern (read-only viewer / help-desk / admin tiers;
  impersonation gated by mandatory reason, non-dismissable banner, ~60-min auto-expiry, dual-log
  actor-vs-subject with an RFC 8693 `act`-style claim, forced subject notification). This is a
  net-new authorization/security capability that changes the security model → **future authz/security
  milestone**, not L4. Sigra's current doctrine intentionally treats investigator as a posture.
- **System-wide microcopy/voice glossary + one-term-per-concept sweep** → **Phase 191**.
- **Terminal idempotency gate + baseline recapture + generated-host parity** → **Phase 192**.

### Reviewed Todos (not folded)
- `2026-06-17-page04-branding-explicit-scoring.md` (score 0.6) — maintainer-pinned `resolves_phase: 191`
  (explicit Branding-customizer L3 ledger row); not L4 flow work.
- `2026-06-14-phase-186-review-deferred.md` (score 0.6) — D-11 parity-extractor refactor + minor
  cleanups; test-extractor robustness, not flow-related; deferred to a focused pass.
</deferred>
