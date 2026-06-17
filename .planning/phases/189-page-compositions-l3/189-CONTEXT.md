# Phase 189: Page Compositions (L3) - Context

**Gathered:** 2026-06-17 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

L3 of the fractal admin design-system program (L0 tokens → L1 components → L2 groups
→ **L3 pages** → L4 flows). Phase 189 grades whole admin *pages* against the existing
page scorecard: the 3 archetypes (Overview / List / Detail) plus the two explicitly
non-archetypal pages (Branding customizer, Audit explorer), covering GOV.UK information
architecture, principle-of-least-surprise, overlay/modal + scroll/sticky + pagination
correctness, and page-level a11y/responsive — ratified across the 8 admin checkpoints ×
3 projects.

In scope: page-level composition, IA ordering, the net-new modal focus-trap/dismiss/
scroll behavior, page vertical rhythm, page-level a11y, and ledger ratification of the 6
L3 rows. **Out of scope:** new token values (L0, locked), new/changed L1 components or
L2 groups (graded already), persona JTBD flows and fixture data (L4 → Phase 190), and the
system-wide microcopy/voice glossary sweep (Phase 191). Requirements PAGE-01..PAGE-05.
</domain>

<decisions>
## Implementation Decisions

### Page scorecard — reuse, do not author (PAGE-01, PAGE-02, PAGE-05)
- **D-01:** Reuse the **existing** L3 rubric in `guides/reference/admin-fractal-scorecard.md`
  (L3 Page Composition add-ons: archetype conformance, GOV.UK IA, principle-of-least-surprise,
  page vertical rhythm, landmark/heading order, focus management on navigate/patch — layered
  over shared D1–D11). Phase 189 **fills evidence into and ratifies** the 6 L3 ledger rows
  (`index-live`, `organization-live`, `users-index-live`, `user-show-live`, `audit-index-live`,
  `audit-user-live`) in `guides/reference/admin-quality-ledger.md`; it does **not** invent a new
  scorecard. Authoring a parallel rubric would collide with the value-locked grading anchor
  ("fixed grading anchor for phases 186–192") and risk monotonic-guard/ledger inconsistency.
- **D-02:** The GOV.UK IA checklist (PAGE-02) is grounded in canonical GDS principles —
  "start with user needs", inverted-pyramid "most important information first", "one thing per
  page", "be consistent, not uniform". The rubric's "tasks-first / posture-second /
  capabilities-last" phrasing is a **derived application** of those principles to an admin page,
  **not** a verbatim GDS quote — cite/score it as derived ordering logic (general→specific,
  most-common-need-first, reference/config last), not as a GDS rule.

### Archetype mapping (PAGE-01, PAGE-04)
- **D-03:** Archetype mapping is fixed as:
  - **Overview** = `lib/sigra/admin/live/index_live.ex` (posture notice + task-card grid +
    KPI summary-chip strip).
  - **List** = `lib/sigra/admin/live/users_index_live.ex` (filter + table/card + honest pagination).
  - **Detail** = `lib/sigra/admin/live/user_show_live.ex` (back link/breadcrumbs + scope ribbon +
    fact sections + recent-audit sub-feed).
- **D-04:** `lib/sigra/admin/live/organization_live.ex` is scored as the **org-scoped instance
  of the Overview archetype**, NOT a fourth archetype — preserving PAGE-01's "3 archetypes" framing.
- **D-05:** The non-archetypal PAGE-04 pages are the **Branding customizer**
  (`lib/sigra/admin/live/branding_live.ex`) and the **Audit explorer**
  (`lib/sigra/admin/live/audit_index_live.ex` + `audit_user_live.ex`). They are scored explicitly
  against the rubric on their own terms (bespoke filter/export/customizer IA), NOT forced into the
  List archetype (which would double-count PAGE-04 and mis-grade them against List pagination criteria).

### Modal/overlay focus-trap + scroll behavior — the one net-new slice (PAGE-03)
- **D-06:** Wire a **new shipped LiveView hook in `admin_hooks.js`** (modeled on the existing
  `CmdK` focus trap) onto the `sg-confirm-overlay`/`sg-confirm-dialog` confirm dialogs at
  `user_show_live.ex` and `branding_live.ex` — both are currently pure server-rendered markup with
  no `phx-hook`/keydown/outside-click wiring. CSS already centers the dialog; the gap is purely the
  JS behavior. (The earlier "user_show still uses a DaisyUI `<dialog class="modal">`" note is
  **stale** — it is already migrated to `sg-confirm-overlay`; no `<dialog>` remains.)
- **D-07:** Score PAGE-03 on **WAI-ARIA APG "Dialog (Modal)" behavior**, not technique:
  initial focus moves into the dialog (first focusable, or Cancel for a destructive confirm);
  focus **returns to the triggering element** on close; **Escape closes**; `role="dialog"` +
  `aria-modal="true"` + `aria-labelledby`/`aria-label` present; focus is **contained/wrapped**
  (JS focus-wrap is APG-conformant; `inert` on background is the stronger mechanism — score the
  behavior "background non-interactive + focus contained", not the technique).
- **D-08:** **Outside-click dismissal is an optional enhancement, NOT an APG requirement, and is
  not a hard-fail gate.** **Background scroll-lock / scroll-restore is convention, not APG** — keep
  it (the rubric names it) but do not gate ratification on scroll-lock technique. Escape + an
  explicit cancel/close control remain the required dismissal paths.
- **D-09:** Pagination stays **honest** (PAGE-03): no phantom affordances — reuse the existing
  `show_pagination?`-style guards in `users_index_live.ex`. Sticky/scroll behavior must cause **no
  layout shift**.

### Where page-level CSS/JS lands — parity surfaces carried forward (L1/L2 rule)
- **D-10:** Any net-new page CSS (scrim refinement, `body` scroll-lock class, sticky no-shift,
  focus-management styling) lands in canonical
  `priv/templates/sigra.install/admin/sigra_admin.css` inside `@layer sg-components`, depending
  only on `var(--sg-*)`, with **byte-identical mirrors** in
  `test/example/priv/static/assets/sigra_admin.css` and
  `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css`. `app.css` keeps only
  `vt-*` glue. New JS behavior lands in the shipped `admin_hooks.js` template **and** its example
  mirror (`test/example/assets/js/admin_hooks.js`). Do not re-tune any Phase 186 token value.
- **D-11:** Leaving required overlay/scroll CSS or modal JS example-only reproduces the exact
  Phase 187/188 failure mode (example looks correct, generated host ships a broken/unstyled or
  dead modal) — a DIST-05 byte-parity failure and a **generated-host honesty regression**
  (escalation-worthy under METHODOLOGY because it changes generated-host output). The parity
  surfaces move together on every edit.

### Ratification & evidence (PAGE-05)
- **D-12:** Ratification = the existing `test/example/priv/playwright/tests/admin-checkpoints.spec.ts`
  (8 checkpoints × 3 projects: chromium / mobile / dark) passing with committed `toHaveScreenshot`
  baselines under `admin-checkpoints.spec.ts-snapshots/`, paired with the per-checkpoint axe
  `wcag2a`/`wcag2aa` gate. New PAGE-03/PAGE-05 behavior gets **added assertions**, not a new spec
  lane; intended visual deltas get a deliberate **canary-guarded recapture** (snapshot
  allowlist + monotonic guard under `scripts/ci/`), never an accidental diff.
- **D-13:** PAGE-03 modal **interaction** steps (open → Escape/cancel → focus-return, focus
  containment) may warrant a **small dedicated interaction test** rather than bloating the
  capture-only checkpoint journey — the planner decides whether to extend the checkpoint spec or
  add a focused interaction spec. Keep evidence deterministic: stable testids, role selectors,
  LiveView readiness gates, no sleeps (per 188 D-09, zero-human UAT).

### Claude's Discretion (planner resolves — below escalation threshold)
- Whether PAGE-03 lands as one slice or splits hook-JS vs page-CSS vs IA-evidence slices.
- Exact `admin_hooks.js` hook name/shape and whether to generalize vs duplicate the `CmdK` trap
  (avoid risk to the ratified CmdK behavior).
- Exact IA-checklist item wording and which pages need IA reordering vs already-conformant.
- Whether to extend `admin-checkpoints.spec.ts` with interaction steps or add a dedicated modal
  interaction spec.
- Per-page L3 ledger tier achieved after evidence (monotonic guard is the floor).
- Page vertical-rhythm fixes (flush sections / double gaps) per page as the audit surfaces them.

### Folded Todos
None. The only phase-matched todo (`2026-06-14-phase-186-review-deferred.md`, score 0.6) was
already folded into and resolved in Phase 188 (188 D-15/D-16). Nothing to fold here.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `guides/reference/admin-fractal-scorecard.md` — the fixed L0–L4 grading anchor; L3 add-ons at
  lines ~81–102. Source of truth for the page scorecard. Do not author a parallel rubric.
- `guides/reference/admin-quality-ledger.md` — the 6 L3 rows + machine-parseable monotonic guard
  floor; ratification target.
- `guides/reference/admin-ui-principles.md` — admin UI direction (per CLAUDE.md).
- `guides/reference/admin-design-contract.md` — design-system contract (sg-* cascade-layer/BEM,
  per-component copy spec; Phase 191 owns the system-wide voice sweep — stay page-local here).
- `.planning/phases/187-individual-components-l1/187-CONTEXT.md` — L1 parity-surface rule
  (D-01..D-04) carried forward verbatim into D-10/D-11.
- `.planning/phases/188-meta-components-groups-l2/188-CONTEXT.md` — L2 groups + the explicit
  PAGE-03 deferral ("Escape/cancel behavior preserved for the page-level follow-up in Phase 189",
  188 D-13/D-14) and snapshot-evidence conventions (188 D-09).
- External standards (validated, score on behavior): GOV.UK Design Principles
  (https://www.gov.uk/guidance/government-design-principles), "One thing per page"
  (https://designnotes.blog.gov.uk/2015/07/03/one-thing-per-page/), WAI-ARIA APG Dialog (Modal)
  pattern (https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Library-owned admin LiveViews** (`lib/sigra/admin/live/`): `index_live.ex`,
  `organization_live.ex`, `users_index_live.ex`, `user_show_live.ex`, `branding_live.ex`,
  `audit_index_live.ex`, `audit_user_live.ex`. Each already renders its archetype shape.
- **Confirm dialog markup** already exists and is centered by CSS: `sg-confirm-overlay` /
  `sg-confirm-dialog` (`sigra_admin.css` ~637–675) used by `user_show_live.ex` and `branding_live.ex`.
- **A complete reference focus-trap** already exists in the shipped `admin_hooks.js` (`CmdK`
  palette: `trapFocus`, Escape handler, outside-click, focus-restore) — the model for the new
  confirm-dialog hook, though it builds its own DOM so it is not reusable as-is.
- **Honest pagination** guard pattern in `users_index_live.ex` (`show_pagination?`).
- **Ratification lane** `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` (8 × 3) with
  committed snapshots + axe `wcag2a`/`wcag2aa` gate; snapshot canary/monotonic guards in `scripts/ci/`.

### Established Patterns
- L1/L2 three-surface byte-parity rule for shipped CSS, and `admin_hooks.js` + example-mirror for
  shipped JS — carried into D-10.
- Value-locked L0 tokens + monotonic quality-ledger guard (merge-blocking) — never re-tune.
- Zero-human UAT: deterministic Playwright + axe evidence, stable testids, no sleeps.

### Integration Points
- New page CSS/JS connects via the canonical installer templates → byte-identical example +
  golden-fixture mirrors. The modal hook attaches to existing `sg-confirm-*` markup in two
  LiveViews. New assertions extend (or sit beside) the existing checkpoint spec.
</code_context>

<specifics>
## Specific Ideas

- Score the modal on WAI-ARIA APG *behavior* (focus-in, focus-return-to-trigger, Escape,
  role+aria-modal+label, focus containment) — not on whether `inert` vs JS-wrap is used.
- Treat outside-click dismissal and scroll-lock as enhancements/convention, not hard-fail gates.
- Cite the GOV.UK IA ordering as *derived from* GDS principles, not as a GDS quote.
</specifics>

<deferred>
## Deferred Ideas

- Persona JTBD flows, fixture/seed data, return-context continuity → **Phase 190 (L4)**.
- System-wide microcopy/voice glossary + one-term-per-concept sweep → **Phase 191**.
- Generalizing the `CmdK` trap into a single shared dialog helper — allowed at planner discretion
  but only if it does not risk the ratified CmdK behavior; otherwise duplicate-and-specialize.

### Reviewed Todos (not folded)
- `2026-06-14-phase-186-review-deferred.md` (score 0.6) — already folded into and resolved in
  Phase 188 (188 D-15/D-16); nothing left to fold into 189.
</deferred>
