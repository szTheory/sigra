# Phase 154: Design Contract + sg-notice - Context

**Gathered:** 2026-06-03 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Commit the design decisions that constrain all subsequent v1.34 ADMIN-UI-COHERENCE phases (155–160) **as artifacts only** — no code behavior changes. Two deliverables:

1. A committed "Job → Component" mapping doc + 3 page archetypes (Overview / List / Detail) covering all 10 canonical admin components (`stat_link`, `stat`, `task_card`, `summary_chip`, `applied_chip`, `empty_state`, `page_back`, `scope_ribbon`, `notice`, `skeleton`) — each with winning CSS, ARIA roles, motion spec (including explicit "not animated" entries), and when-NOT-to-use guidance.
2. ~15 lines of new `sg-notice` component CSS inside the existing `@layer sg-components`, using **existing tokens only**.

**Hard constraints (locked):** No LiveView files modified. No Playwright baselines change. `admin-generated` installer-parity lane stays green. All new styles inside `@layer sg-components` — no unlayered rules, no new `!important`, no new tokens/motion primitives. No new Hex deps, no Tailwind, no Alpine.
</domain>

<decisions>
## Implementation Decisions

### Design-contract artifact location & format
- **D-01:** The Job→Component mapping + 3 page archetypes ship as a single committed Markdown governance doc at **`guides/reference/admin-design-contract.md`** — a peer of the existing `guides/reference/generator-options.md`. It is NOT placed under `.planning/`.
- **D-02:** The doc is registered in the `mix.exs` ExDoc `extras:` list (lines ~186–230) so it renders in hexdocs alongside the other reference guides. This satisfies Phase 160 SC#4 ("committed and referenced from the repo") and gives downstream phases 155–158 a durable, citable authority. (Confidence: Likely — confirmed by user.)
- **D-03:** The doc must cover all 10 canonical components with: the job each does, winning CSS/markup, ARIA role(s), motion spec **including explicit "not animated" entries**, and when-NOT-to-use guidance. The 3 archetypes (Overview / List / Detail) are documented as explicit component compositions so any future screen assembles from the mapping without bespoke design.

### sg-notice CSS — single tree, existing tokens
- **D-04:** `sg-notice` CSS is added in exactly ONE place: **`test/example/priv/static/assets/css/app.css`**, inside the existing `@layer sg-components` block (adjacent to the `.sg-list-row[data-tone]` tone rules, ~lines 945–967). There is no lib-owned or template copy of `app.css` — `git ls-files` shows this as the sole tracked copy, and the installer emits no CSS.
- **D-05:** No mirrored CSS copy is needed for parity. The `admin-generated` lane (`scripts/ci/admin-acceptance-smoke.sh` → `admin-generated.spec.ts`) probes routes/markup, **never diffs `app.css`** — so adding CSS there cannot affect that lane.
- **D-06:** `sg-notice` reuses the existing `[data-tone]` token set already used by `.sg-list-row[data-tone]`: `--sg-color-{ok,warn,risk,info}-soft`, `--sg-color-{ok,warn,risk,info}`, `--sg-radius-sm`, `--sg-space-4`, `--sg-color-panel`, `--sg-transition-tone`, `--sg-elev-inset`. It reproduces the current ad-hoc contextual-alert treatment (today rendered as `sg-list-row data-tone`) so it is a behavior-preserving consolidation target for Phase 156 (COHR-05). No new token or motion primitive.

### Scope of the mapping: document reality + locked winners, don't invent
- **D-07:** Phase 154 **documents current reality and names already-locked winners** — it makes no new contested design calls. The header winner is already locked by COHR-02: the open `<header class="sg-page-header">` beats the boxed `sg-card` header (the `user_show_live.ex` boxed-header outlier is reconciled in Phase 156, not redesigned here). The filter winner is the users-index idiom (AUDX-02).
- **D-08:** The "3 stat variants" and the `summary_chip`/`applied_chip` chips are documented as **markup-consolidation targets** (there is no `.sg-stat` CSS class — "stat" is rendered inline via `sg-status-pill` + ad-hoc spans). The canonical executable form is realized as the `Sigra.Admin.Components` API in **Phase 155 (COMP-01)**, with call-site migration in **Phase 156 (COHR-01)** — not chosen anew in 154. Inventing new winners here would exceed the "artifacts only, no behavior change" boundary (SC#4) and risk baseline churn that Phase 155's `render_component` markup-equality gate forbids.

### Claude's Discretion
- Exact section ordering, table layout, and prose of `admin-design-contract.md` (within the D-03 coverage requirement).
- Exact ExDoc group/placement of the new extra in `mix.exs` (alongside existing reference guides).
- Exact CSS property values for `sg-notice` within D-06's token set (~15 lines, behavior-preserving vs. the current `sg-list-row data-tone` rendering).

### Folded Todos
None — no pending todos matched this phase.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- **app.css (sole tracked copy):** `test/example/priv/static/assets/css/app.css` — `:root` tokens (lines 20–188); `@layer` order declared line 15; `@layer sg-components` block (lines 203–1422); `.sg-list-row[data-tone]` tone pattern / sg-notice precedent (lines 945–967); `.sg-empty-state` (990–1000); `.sg-page-header` (653); `.sg-card` (756); `.sg-skeleton` (1395–1421); `prefers-reduced-motion` block / only `!important` (1433–1446).
- **Admin LiveViews (lib-owned):** `lib/sigra/admin/live/` — `users_index_live.ex` (List archetype, open `sg-page-header` @72), `user_show_live.ex` (Detail, boxed `sg-card` headers @97/136/229; ad-hoc summary alert `sg-list-row` @131), `audit_index_live.ex`, `audit_user_live.ex`, `index_live.ex` (global Overview), `organization_live.ex` (org Overview; ad-hoc alert `sg-list-row` @71).
- **Layout linking app.css:** `test/example/lib/example_web/components/layouts/root.html.heex:11`.
- **Governance/doc precedent:** `guides/reference/generator-options.md`; ExDoc `extras:` registry in `mix.exs` (lines ~186–230); per-phase UI specs at `.planning/phases/148-.../148-UI-SPEC.md`, `.planning/milestones/v1.2-phases/27|28-.../NN-UI-SPEC.md` (for format reference, not the publish target).
- **Installer template + example admin trees:** `priv/templates/sigra.install/admin/` (no CSS emitted); `test/example/lib/example_web/controllers/admin/`; golden fixture `test/fixtures/install_golden/tree/.../controllers/admin/`.
- **`admin-generated` parity lane:** `scripts/ci/admin-acceptance-smoke.sh` + `test/example/priv/playwright/tests/admin-generated.spec.ts` (route/markup probes; does NOT diff CSS).
- **Playwright admin checkpoints + baselines:** `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` and `...-snapshots/` (5 slugs ×3 projects: `global-user-index`, `user-detail`, `audit-explorer`, `org-scoped-admin`, `impersonation-banner`); `admin-audit.spec.ts`; `demo-showcase.spec.ts`.
- **Planning sources:** `.planning/ROADMAP.md` (phases 154–160), `.planning/REQUIREMENTS.md` (COMP/COHR/LAND/AUDX-* lines 13–97), `.planning/STATE.md` (CSS-boundary lock line 41).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The `[data-tone]` inset-bar pattern (`app.css` 945–967) is the direct template for `sg-notice` — same tokens, same tone treatment, behavior-preserving.
- The `:root` token layer (color tones, spacing, radii, motion/easing, `--sg-elev-inset`) is mature and complete for this work — no new tokens required.
- `guides/reference/generator-options.md` + `mix.exs` `extras:` give a ready home and wiring pattern for the new governance doc.

### Established Patterns
- `app.css` keeps all component styles inside `@layer sg-components`; the only `!important` is the `prefers-reduced-motion` exception (1433–1446). The new CSS must respect this boundary.
- "stat" is a markup pattern, not a CSS class (`sg-status-pill` + spans across all 5 LiveViews) — the contract documents the canonical markup, deferring the executable component to Phase 155.
- Header anatomy splits boxed (`sg-card`, `user_show_live.ex`) vs open (`sg-page-header`, `users_index_live.ex`); COHR-02 already locks open as the winner.

### Integration Points
- The new doc plugs into ExDoc via `mix.exs extras:` and becomes the cited authority for phases 155–160.
- `sg-notice` CSS plugs into `@layer sg-components` in the single `test/example` app.css; it is consumed (rendered) only later, in Phase 156's `<.notice>` adoption — this phase only defines the style.
- The `admin-generated` parity lane is CSS-agnostic, so the CSS edit and doc addition are both safe against that gate this phase.
</code_context>

<specifics>
## Specific Ideas

- `sg-notice` should be a behavior-preserving consolidation of the current `sg-list-row data-tone` contextual-alert rendering (so Phase 156 can swap call sites to `<.notice>` without a visual delta beyond intended re-records).
- The mapping doc must include explicit "not animated" motion entries (keyboard-frequent interactions stay still) — this seeds the Phase 159 motion usage audit (GATE-03).
</specifics>

<deferred>
## Deferred Ideas

- Building the executable `Sigra.Admin.Components` module and the 10 component functions → Phase 155 (COMP-01/COMP-02).
- Migrating LiveView call sites to the shared components and re-recording intended baseline deltas → Phase 156 (COHR-01..06).
- Any net-new admin surfaces, nav restructure, or new token/motion primitives → out of milestone scope per PROJECT.md / STATE.md.

### Reviewed Todos (not folded)
None — no pending todos matched this phase.
</deferred>
