# Roadmap: Sigra

**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Status:** v1.41 ADMIN-UX-ELEVATION in progress (phases 199-204). Hex: `v1.1.0`.

## Milestones

- 🔨 **v1.41 ADMIN-UX-ELEVATION** — Phases 199-204 (in progress)
- ✅ **v1.40 CI-PERF** — Phases 193-198 (shipped 2026-06-21)
- ✅ **v1.39 DS-COHERENCE** — Phases 184-192 (shipped 2026-06-19)
- ✅ **v1.38 BRAND-V2** — Phases 178-183 (shipped 2026-06-13)
- ✅ **v1.37 AUTH-BRANDING-WHITELABEL** — Phases 173-177 (shipped 2026-06-07)
- ✅ **v1.36 ADMIN-BRAND-THEME-POLISH** — Phases 168-172 (shipped 2026-06-06)
- ✅ **v1.35 BRAND-SYSTEM-PRESSURE-TEST** — Phases 161-167 (shipped 2026-06-05)
- ✅ **v1.34 ADMIN-UI-COHERENCE** — Phases 154-160 (shipped 2026-06-05)
- ✅ **v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS** — Phases 150-153 (shipped 2026-06-02)

## Phases

### v1.41 ADMIN-UX-ELEVATION (Phases 199-204)

**Milestone Goal:** Streamline the highest-impact generated admin/operator pages to award-grade (Tier-2) quality — deliberate, JTBD-first, internally coherent, mobile-first, accessible (WCAG 2.2 AA), on-brand in light/dark/system — and ratchet them forward-only via the existing quality-ledger monotonic guard so quality can only ever increase.

- [x] **Phase 199: Foundation — Tier-2 Scorecard & Stress Fixtures** — Define objective Tier-2 proxies, extend quality ledger + fractal scorecard + monotonic guard to make Tier 2 earnable and guarded; stress-fixture demo seed data (≥25-event persona, list-scale users, overflow strings, multi-session/org). Covers LEDGER-01, LEDGER-02, FIXT-01, FIXT-02. (completed 2026-06-25)
- [x] **Phase 200: User Detail Elevation** — Award-grade pass on `user_show_live.ex`: calm identity header, JTBD-first restructuring of the 9-panel stack with progressive disclosure, safe confirmed destructive flow, proven across the full viewport/theme/state matrix. Covers DETAIL-01, DETAIL-02, DETAIL-03, DETAIL-04. (completed 2026-06-26)
- [ ] **Phase 201: Users Index Elevation** — Award-grade pass on `users_index_live.ex`: consolidated filter panel, demoted metric strip, DRY desktop/mobile presentation, honest pagination, stress-proven against list-scale fixtures. Covers INDEX-01, INDEX-02, INDEX-03, INDEX-04.
- [x] **Phase 202: Audit Surfaces Elevation** — Award-grade pass on `audit_index_live.ex` + `audit_user_live.ex`: unified filter form with advanced-disclosure, reduced column density, mobile-first stacking, Export surfaced, pagination proven on ≥25-event fixture. Covers AUDIT-01, AUDIT-02, AUDIT-03. (completed 2026-06-26)
- [x] **Phase 203: Consistency Propagation** — Roll the elevated bar to Overviews, Branding workbench, and design gallery/MG-1..11; update design contract + UI principles docs for any evolved archetypes; same-job → same-component, no net-new surfaces. Covers PROP-01, PROP-02. (completed 2026-06-26)
- [ ] **Phase 204: Terminal Ratification** — Recapture all baselines through the gate with allowlists reset to empty; monotonic guard green; full-surface axe clean including overlays-open; generated-host parity proven; adversarial milestone review; Tier-2 cells locked. Covers RATIFY-01, RATIFY-02.

## Phase Details

### Phase 199: Foundation — Tier-2 Scorecard & Stress Fixtures

**Goal**: Tier-2 "Award-grade" is objectively earnable — the quality ledger, fractal scorecard, and monotonic guard are extended with measurable proxies — and the demo seed data stress-tests every admin surface with realistic, ugly fixture data.
**Depends on**: Nothing (first phase of milestone)
**Requirements**: LEDGER-01, LEDGER-02, FIXT-01, FIXT-02
**Success Criteria** (what must be TRUE):

  1. The quality ledger and fractal scorecard define concrete, machine-checkable Tier-2 proxies (motion-token conformance / no `transition: all`, overlay-open axe-clean, desktop↔mobile content-equivalence, focus-trap/restore APG gates, glossary-clean microcopy, density/whitespace rhythm, target-size minimum) so a maintainer can declare Tier 2 on objective evidence, not a subjective verdict.
  2. The monotonic guard script enforces the Tier-2 ratchet — once a cell reaches Tier 2 no future PR may decrease it — and it remains merge-blocking against `origin/main`.
  3. A deterministic demo persona carries ≥25 audit events so MG-5/MG-6 pagination renders in the design gallery and desktop↔mobile content-equivalence is testable (closes the tracked `admin-design-mg5-6-content-equivalence-data-dependent` todo).
  4. The demo seed data includes list-scale users, long display names / emails / UUIDs / identifiers, multi-session and multi-org breadth, and varied audit outcomes/severities — all under the `MIX_ENV=test` raise guard with idempotent upserts.

**Plans**: 4 plans
**Wave 1**

- [x] 199-01-PLAN.md — Tier-2 Award-grade scorecard add-on block + ledger assertion convention & prose reconciliation (LEDGER-01)
- [x] 199-02-PLAN.md — Monotonic guard 2→1 self-test + merge-blocking CI wiring (LEDGER-02)
- [x] 199-03-PLAN.md — Seed fixtures: admin ≥25 self-tied events + list-scale "ugly" bulk cohort, idempotent & raise-guarded (FIXT-01, FIXT-02)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 199-04-PLAN.md — Un-skip content-equivalence test + empirical recapture + allowlist reset + close tracked todo (FIXT-01)

**UI hint**: yes

### Phase 200: User Detail Elevation

**Goal**: `user_show_live.ex` is an award-grade operator page — a calm, scannable, JTBD-first composition that makes the primary identity, priority alert, key actions, and bounded drill-downs immediately legible across every viewport, theme, and state.
**Depends on**: Phase 199 (stress fixtures available for matrix verification; Tier-2 proxies defined)
**Requirements**: DETAIL-01, DETAIL-02, DETAIL-03, DETAIL-04
**Success Criteria** (what must be TRUE):

  1. The identity header presents primary identity, one priority alert, and key metrics in a single calm bar — no stacked 4-fact `<dl>` under 3 pills + alert; an operator can orient in under two seconds.
  2. The 9-panel stack is restructured into a JTBD-first composition with grouped sections and progressive disclosure; unbounded sub-lists (Sessions, Organizations, Recent audit) are link-outs rather than inline stacks; host-injected extra-section seams are preserved and the design contract updated.
  3. The session revoke / revoke-all destructive flow uses an APG-compliant dialog (focus trap + restore, Escape, click-outside dismiss, no scrim-hidden modal state) so destructive actions require deliberate confirmation and cannot be triggered by accident.
  4. The page is award-grade across the full matrix (viewports 320–1440px, light/dark/system, empty/loading/error/permission-denied/long-content/keyboard/reduced-motion); the `user-show-live` ledger cell is ratcheted to Tier 2 with proxy evidence.

**Plans**: 3 plans
**Wave 1**

- [x] 200-01-PLAN.md — New lib-owned UserSessionsLive + /admin/users/:id/sessions route (3-file lockstep) + APG confirm move + glossary scope (DETAIL-02, DETAIL-03)

**Wave 2** *(blocked on Wave 1)*

- [x] 200-02-PLAN.md — Recompose user_show_live.ex: calm identity bar + JTBD previews/link-outs + remove session flow + preserve host seam (DETAIL-01, DETAIL-02)

**Wave 3** *(blocked on Waves 1-2)*

- [x] 200-03-PLAN.md — Checkpoints (user-sessions + user-detail) + recapture + ledger Tier-2 ratchet + design-contract update (DETAIL-03, DETAIL-04)

**UI hint**: yes

### Phase 201: Users Index Elevation

**Goal**: `users_index_live.ex` is an award-grade operator list — one coherent filter/search experience, a non-blocking metric strip, content-equivalent desktop and mobile presentations, and honest pagination — stress-proven against list-scale fixtures.
**Depends on**: Phase 199 (list-scale fixtures; Tier-2 proxies defined), Phase 200 (shared component patterns established)
**Requirements**: INDEX-01, INDEX-02, INDEX-03, INDEX-04
**Success Criteria** (what must be TRUE):

  1. All filter controls (search, quick toggles, advanced filters, applied-filter state) appear in one coherent panel rather than three separate blocks; an operator can build and clear a filter set without hunting across the page.
  2. The user-health metric strip never obscures or delays access to search — it is demoted or slimmed so search is the dominant first affordance; per-row status pills are reduced to only the ones that carry decision value.
  3. The desktop-table and mobile-card presentations are content-equivalent and share markup/components (DRY); inline row actions are clear; pagination affordances are absent when there is nothing to paginate.
  4. The page is award-grade across the full matrix including list-scale fixtures; the `users-index-live` ledger cell is ratcheted to Tier 2 with proxy evidence.

**Plans**: 4 plans
**Wave 1**

- [x] 201-01-PLAN.md — Recompose users_index_live.ex: consolidate filter panel + relocate applied chips (D-01/D-02), demote+slim metric strip (D-03), reduce pills (D-04), DRY shared row component + frozen column order (D-05/D-06), resolve sg-chevron (D-11)
- [x] 201-02-PLAN.md — Emit non-empty extra_list_badges/extra_list_columns from the example hook to exercise the host seam (D-07)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 201-03-PLAN.md — Real form-submit Playwright test (D-02) + frozen selector confirm (D-06), ratchet users-index-live ledger to Tier 2 (D-09), rewrite List Archetype design-contract block (D-12)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 201-04-PLAN.md — Prove honest pagination at list-scale + recapture global-user-index/mg-* through the recapture gate, canaries stable, allowlists empty (D-08/D-10)

**UI hint**: yes

### Phase 202: Audit Surfaces Elevation

**Goal**: Both audit surfaces (`audit_index_live.ex` and `audit_user_live.ex`) are award-grade — a single, unified filter experience with advanced-disclosure, reduced column density, mobile-first stacking, and pagination proven against the ≥25-event fixture — while staying byte-coherent with each other.
**Depends on**: Phase 199 (≥25-event persona fixture; Tier-2 proxies defined), Phase 200 (shared patterns), Phase 201 (filter-panel pattern established)
**Requirements**: AUDIT-01, AUDIT-02, AUDIT-03
**Success Criteria** (what must be TRUE):

  1. Both audit pages share a single filter form with an advanced-disclosure section (quick toggles folded in) rather than separate UI blocks; Export is surfaced to the filter action row, not buried near pagination.
  2. Audit row/column density is reduced (event codes deferred to a drill-down, not a primary column) and mobile-first stacked; pagination renders correctly against the ≥25-event persona fixture and the two audit pages remain byte-coherent in shared markup and components.
  3. Both audit surfaces are award-grade across the full matrix (320–1440px, light/dark/system, empty/loading/error/permission-denied/long-content/keyboard/reduced-motion); `audit-index-live` and `audit-user-live` ledger cells are ratcheted to Tier 2 with proxy evidence.

**Plans**: 5 plans
**Wave 1**

- [x] 202-01-PLAN.md — Extract shared public audit components (table-row + inline-code `<details>`, pagination nav, empty-state) into components.ex

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 202-02-PLAN.md — Per-user audit surgery: collapse 3 forms→1, add `<details>` disclosure, adopt shared components, preserve return_to
- [x] 202-03-PLAN.md — Global audit rewire: add `<details>` disclosure, adopt shared components, delete dup helpers

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 202-04-PLAN.md — Test lockstep: strengthen content-equivalence helper (strict 2-code guard, D-06) + deterministic ExUnit pagination test (D-10)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 202-05-PLAN.md — Ratchet 2 ledger cells to Tier 2, add Audit Explorer archetype, golden-diff + recapture

**Cross-cutting constraints:**

- The page renders its desktop table via the shared `audit_table_row/1`, pagination via `audit_pagination_nav/1`, and empty-state via `audit_empty_state/1`; the private `audit_tone/1` copy is deleted.

**UI hint**: yes

### Phase 203: Consistency Propagation

**Goal**: The elevated Tier-2 bar propagates consistently to the lean Overviews, the Branding workbench, and the design gallery — with no net-new surfaces, same-job → same-component discipline, and design contract + principles docs updated to document any evolved archetypes.
**Depends on**: Phases 200-202 (elevated deep pages establish the bar to propagate)
**Requirements**: PROP-01, PROP-02
**Success Criteria** (what must be TRUE):

  1. The Overviews (`index_live.ex`, `organization_live.ex`) and Branding workbench (`branding_live.ex`) use the same components for the same jobs as the elevated deep pages — no duplicate UI fragments, no divergent patterns — and the `/admin/_design` gallery + MG-1..MG-11 reflect the elevated compositions (gallery is the evidence surface, not a separate product).
  2. `guides/reference/admin-design-contract.md` and `admin-ui-principles.md` are updated to document any evolved archetypes or interaction patterns introduced during the elevation phases; the one-term-per-concept glossary remains drift-guarded; no archetype change is silent.

**Plans**: 5 plans
**Wave 1**

- [x] 203-01-PLAN.md — Overview pill alignment (drop org Confirmed pill D-02, demote global coverage chip D-03) + glossary/CSS-untouched gate
- [x] 203-02-PLAN.md — Promote branding color_field/preview_pair/detail_input to components.ex (D-05) + CSS triple-copy lockstep gate (D-12)
- [x] 203-03-PLAN.md — Branding #restore-defaults-overlay modal-interaction test: 7 APG gates + axe-while-open (D-06) — prerequisite for branding Tier-2 evidence

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 203-04-PLAN.md — Docs: add Branding/Workbench archetype to contract (D-07) + UI-principles touch-up (D-11)
- [x] 203-05-PLAN.md — Ratchet index-live/organization-live/branding-live cells 1→2 + fold PAGE-04 (D-08/D-09) + idempotent global-overview/org-overview recapture (D-10)

**UI hint**: yes

### Phase 204: Terminal Ratification

**Goal**: The milestone closes honestly — all baselines recaptured through the gate with empty allowlists, monotonic guard green, full-surface axe clean, generated-host parity proven, and an adversarial review confirming no usability, contract, or accessibility regression.
**Depends on**: Phases 199-203 (all page elevation and propagation complete)
**Requirements**: RATIFY-01, RATIFY-02
**Success Criteria** (what must be TRUE):

  1. All Playwright baselines are recaptured through `snapshot-recapture-gate.sh` with both allowlists (checkpoints and design) reset to empty; the monotonic guard exits 0 vs `origin/main`; the full admin surface is axe-clean including all overlays in their open state; generated-host parity is proven (install-golden byte-diff green with phx_new 1.8.7 + admin-acceptance smoke renders the elevated, styled admin UI on a freshly generated host).
  2. A final adversarial milestone review confirms: no usability-for-aesthetics regression (pages work better for operators, not just look better); no generated-host-contract friction (host extension seams intact, contract doc updated); no broken dark/mobile/keyboard/reduced-motion paths; no screenshot-only quality (all interactions work, not just static captures); all ratcheted Tier-2 ledger cells are locked.

**Plans**: 5 plans

**Wave 1** *(independent — run in parallel)*

- [ ] 204-01-PLAN.md — Test hardening: per-user audit pagination boundary (WR-02/D-06) + Event-codes disclosure lock (WR-01/D-07)
- [ ] 204-02-PLAN.md — Clean `mix test`: delete stale Phase192 known-failure contract + reconcile Vaultr→Tasklane doc/test drift (D-08/D-09)

**Wave 2** *(blocked on Wave 1)*

- [ ] 204-03-PLAN.md — `.vt-status-pill` contrast fix + same-commit canary/audit recapture + zero-drift idempotency + monotonic guard (D-01..D-05/D-11)

**Wave 3** *(blocked on 204-03)*

- [ ] 204-04-PLAN.md — Generated-host parity: install-golden byte-diff (phx_new 1.8.7) + admin-acceptance-smoke styled-admin render (D-12)

**Wave 4** *(terminal — after all evidence)*

- [ ] 204-05-PLAN.md — Tier-2 lock verification + adversarial milestone review (v1.41-MILESTONE-AUDIT.md) + close housekeeping (D-10/D-11/D-13)

**UI hint**: yes

<details>
<summary>✅ v1.40 CI-PERF (Phases 193-198) — SHIPPED 2026-06-21</summary>

**Milestone Goal:** Cut PR CI wall-clock from ~22m toward well under ~12m on a fast PR path by attacking the three long poles (`example_playwright_smoke` 22.2m, `library_tests` 15.9m, `library_tests_dep_off` 13.9m) — **without** weakening coverage, determinism, or trust. A maintenance/trust (CI/DX) lane, not a feature milestone. Source of truth: `SEED-005` (grounded baseline + verbatim audit playbook) + `SEED-006` (design-gallery CI fragility).

**Outcome:** PR wall-clock 38.6m → 22.1m avg (**−43%**, n=3), 0 flakes introduced, 5 required-check names byte-stable. Hard GATE-01 bar met; aspirational `<12m` stretch not reached (binding floor is `example_playwright_smoke` ~22m; Playwright job sharding deferred). 18/18 requirements satisfied; audit `tech_debt` (no blockers).

- [x] **Phase 193: Baseline, Observability & One-Line Wins** — capture the before-state baseline + Elixir diagnostics, add CI job-summary observability, then bank the two cheapest wins (drop the gratuitous `needs` edge; fix the rgb flake). Covers BASE-01, BASE-02, BASE-03, CRIT-01, FLAKE-01. (completed 2026-06-20)
- [x] **Phase 194: Caching Correctness & Micro-Job Consolidation** — precise cache keys, no stale `_build` reuse across incompatible combos, separated deps/PLT caches, documented busting; fold the trivial guard jobs into one cheap "fast checks" job. Covers CACHE-01, CACHE-02. (completed 2026-06-20)
- [x] **Phase 195: Test-Suite Performance (partition / async / dep-off slim)** — partition `library_tests` across DB-isolated shards, audit/convert `async: true`, slim the dep-off full rerun to a targeted subset, apply larger runners selectively only if measurement justifies. Covers TEST-01, TEST-02, TEST-03, CACHE-03. (completed 2026-06-20)
- [x] **Phase 196: PR-Fast vs Nightly-Broad Trigger Model** — move exhaustive/low-probability coverage (install matrix ×4, upgrade smoke, broad galleries) off the every-PR path to a `schedule:`/main lane, keep a fast representative PR gate, never strand a correctness-critical test on nightly — all under a single stable `ci-gate` required check with stable child-check names. Covers CRIT-02, CRIT-03. (completed 2026-06-20)
- [x] **Phase 197: Playwright Lanes & Design-Gallery Re-Gate** — reduce the Playwright critical path (boot-sharing/sharding so an early-step failure no longer masks later steps), make readiness deterministic (no `Process.sleep`), and re-gate the `continue-on-error` admin-design gallery by fixing the systemic font-reflow height delta (deterministic CI webfont + in-CI baseline recapture) — folding in SEED-006. Covers PW-01, PW-02, PW-03. (completed 2026-06-20)
- [x] **Phase 198: Contributor DX & Acceptance Gate** — ship a documented local CI equivalent (`mix ci`) in CONTRIBUTING, then prove the milestone-level acceptance: measured before/after PR wall-clock + p95 meaningfully faster with equal-or-greater quality signal, no flake introduced, no correctness-critical coverage dropped, required-check names stable. Covers DX-01, GATE-01, GATE-02. (completed 2026-06-21)

Archive:

- [v1.40 Roadmap](milestones/v1.40-ROADMAP.md)
- [v1.40 Requirements](milestones/v1.40-REQUIREMENTS.md)
- [v1.40 Milestone Audit](milestones/v1.40-MILESTONE-AUDIT.md)

</details>

<details>
<summary>✅ v1.39 DS-COHERENCE (Phases 184-192) — SHIPPED 2026-06-19</summary>

**Milestone Goal:** Turn the strengthened v1.38 brand into a systematically audited, award-grade admin/operator design system — evaluated *fractally* (components → groups → pages → flows) and shipped to real adopters by closing the admin-CSS distribution gap, governed by a re-runnable quality ledger so re-runs only move quality forward.

- [x] **Phase 184: Distribution & Parity** (3/3 plans) — canonical `sg-*` CSS extracted into shipped `sigra_admin.css`, linked in generated admin layout, byte-parity test + styled generated-host proof. (completed 2026-06-14)
- [x] **Phase 185: Audit Infrastructure** (3/3 plans) — example-only `/admin/_design` gallery, `admin-design-{chromium,mobile,dark}` snapshot+axe lane, quality ledger + monotonic guard, fractal scorecard rubric. (completed 2026-06-14)
- [x] **Phase 186: Token Foundation (L0)** (4/4 plans) — `:root` token layer audited + ratified across Light/Dark/System, all color pairs AA, motion budget validated, three-surface ember parity preserved. (completed 2026-06-14)
- [x] **Phase 187: Individual Components (L1)** (6/6 plans) — all 13 components pass the per-component scorecard at ≥ Ratified with complete states, responsive, per-component axe. (completed 2026-06-15)
- [x] **Phase 188: Meta-Components / Groups (L2)** (6/6 plans) — MG-1..MG-11 group catalog passes the meta scorecard with content-equivalent desktop↔mobile swaps and byte-coherent reuse. (completed 2026-06-15)
- [x] **Phase 189: Page Compositions (L3)** (3/3 plans) — 3 archetypes + Branding customizer + Audit explorer pass the page scorecard; 8 checkpoints × 3 projects ratified. (completed 2026-06-17)
- [x] **Phase 190: Flows & Fixture Data (L4)** (5/5 plans) — 3 persona JTBD journeys pass happy/error/boundary with scope/return continuity, keyboard, reduced-motion, theme persistence from deterministic fixtures. (completed 2026-06-17)
- [x] **Phase 191: Microcopy & IA Sweep** (4/4 plans) — committed one-term-per-concept glossary enforced by ExUnit drift guard; system-wide voice + plain-language pass. (completed 2026-06-18)
- [x] **Phase 192: Ratification & Baseline Lock** (4/4 plans) — terminal idempotency gate: all baselines recaptured, both allowlists empty, generated-host parity proven, ~35 ledger cells locked Tier 1, monotonic guard green vs origin/main. (completed 2026-06-18)

Archive:

- [v1.39 Roadmap](milestones/v1.39-ROADMAP.md)
- [v1.39 Requirements](milestones/v1.39-REQUIREMENTS.md)

</details>

<details>
<summary>✅ v1.38 BRAND-V2 (Phases 178-183) — SHIPPED 2026-06-13</summary>

**Milestone Goal:** Pressure-test the v1.35 brand system against a fresh 14-section critical audit and elevate the Sigra identity with a redesigned, fully integrated logo system — ratified by the maintainer — propagated coherently everywhere the existing logo already lives.

- [x] **Phase 178: Brand v2 Pressure-Test Audit** — 14-section KEEP/TIGHTEN/REWORK/ADD/REMOVE audit, szTheory suite brand architecture, logo v2 design brief. (completed 2026-06-12)
- [x] **Phase 179: Outlining Toolchain + Logo Concept Exploration** — Committed opentype.js glyph-outlining script; 7 candidates with 4 integrated typemarks; Playwright render-critique loop; round-3 gallery. (completed 2026-06-12)
- [x] **Phase 180: Human Logo Ratification Gate** — Maintainer ratified D4 Linked Rail (round-4 refinement of A1 Rail-i, Space Grotesk 700); one round-4 loop used; decision recorded in round-3 README. (completed 2026-06-12)
- [x] **Phase 181: Ratified Logo System Buildout** — 8 D4 Linked Rail SVGs built + render-verified (16px favicon kill test passed); clearspace/min-size/6 misuse examples documented; 6 v1 assets archived. (completed 2026-06-12)
- [x] **Phase 182: Brand Book v2 + Tokens** — index.html v2 (expanded logo-system + szTheory suite sections); tokens 1.0.1 + change policy; stale specimens fixed; axe zero violations. (completed 2026-06-13)
- [x] **Phase 183: Propagation, Parity + Verification** — D4 logo propagated to installer+example (byte-identical, filenames unchanged); token parity verified unchanged; 21 Playwright baselines recaptured, canary intact, allowlist reset; hygiene green. (completed 2026-06-13)

Archive:

- [v1.38 Roadmap](milestones/v1.38-ROADMAP.md)
- [v1.38 Requirements](milestones/v1.38-REQUIREMENTS.md)
- [v1.38 Phase Artifacts](milestones/v1.38-phases/)

</details>

<details>
<summary>✅ v1.37 AUTH-BRANDING-WHITELABEL (Phases 173-177) — SHIPPED 2026-06-07</summary>

**Milestone Goal:** Make Sigra's generated authentication forms and emails production-ready by default, while giving adopters a low-friction white-label path, an admin/operator customizer, a code/config path, and a full-control escape hatch.

- [x] Phase 173: Auth Branding Contract + Token Model (1/1 plan) — completed 2026-06-07
- [x] Phase 174: Generated Auth Shell + Light/Dark/System CSS (1/1 plan) — completed 2026-06-07
- [x] Phase 175: Admin Customizer + Email Branding (1/1 plan) — completed 2026-06-07
- [x] Phase 176: Generated Host, Example, Docs, and Golden Parity (1/1 plan) — completed 2026-06-07
- [x] Phase 177: Verification, Generated-Host Smoke, and Audit Closure (1/1 plan) — completed 2026-06-07

Archive:

- [v1.37 Roadmap](milestones/v1.37-ROADMAP.md)
- [v1.37 Requirements](milestones/v1.37-REQUIREMENTS.md)
- [v1.37 Milestone Audit](milestones/v1.37-MILESTONE-AUDIT.md)
- [v1.37 Phase Artifacts](milestones/v1.37-phases/)

</details>

<details>
<summary>✅ v1.36 ADMIN-BRAND-THEME-POLISH (Phases 168-172) — SHIPPED 2026-06-06</summary>

**Milestone Goal:** Align the admin UI with the ratified Rail Accent brand system, add explicit Light/Dark/System theme support, and tighten the design-system guidance/tests without reopening the broad v1.34 admin redesign.

- [x] Phase 168: Admin Brand + Theme Audit (1/1 plan) — completed 2026-06-06
- [x] Phase 169: Durable UI Principles + Design Contract Update (1/1 plan) — completed 2026-06-06
- [x] Phase 170: Rail Accent Shell + Theme Control (1/1 plan) — completed 2026-06-06
- [x] Phase 171: Design-System Touchpoint Polish (1/1 plan) — completed 2026-06-06
- [x] Phase 172: Tests, Evidence, and Baseline Ratification (1/1 plan) — completed 2026-06-06

Archive:

- [v1.36 Roadmap](milestones/v1.36-ROADMAP.md)
- [v1.36 Requirements](milestones/v1.36-REQUIREMENTS.md)
- [v1.36 Milestone Audit](milestones/v1.36-MILESTONE-AUDIT.md)

</details>

<details>
<summary>✅ v1.35 BRAND-SYSTEM-PRESSURE-TEST (Phases 161-167) — SHIPPED 2026-06-05</summary>

**Milestone Goal:** Pressure-test Sigra's brand posture and commit a self-contained brandbook that is useful for docs, READMEs, landing pages, UI/UX buildout, marketing copy, design tokens, SVG logos, and future collateral without causing repo churn or binary sprawl.

- [x] Phase 161: Brand Evidence Extraction + Pressure-Test Audit (1/1 plan) — completed 2026-06-05
- [x] Phase 162: Brand DNA + Voice System (1/1 plan) — completed 2026-06-05
- [x] Phase 163: Tokens + UI/UX Buildout Spec (1/1 plan) — completed 2026-06-05
- [x] Phase 164: Logo + SVG Asset System (1/1 plan) — completed 2026-06-05
- [x] Phase 165: Static HTML Brand Book (1/1 plan) — completed 2026-06-05
- [x] Phase 166: Verification + Repo Hygiene (1/1 plan) — completed 2026-06-05
- [x] Phase 167: Logo Options + Brand Direction Review (2/2 plans) — completed 2026-06-05

Archive:

- [v1.35 Roadmap](milestones/v1.35-ROADMAP.md)
- [v1.35 Requirements](milestones/v1.35-REQUIREMENTS.md)
- [v1.35 Milestone Audit](milestones/v1.35-MILESTONE-AUDIT.md)
- [v1.35 Phase Artifacts](milestones/v1.35-phases/)

</details>

<details>
<summary>✅ v1.34 ADMIN-UI-COHERENCE (Phases 154-160) — SHIPPED 2026-06-05</summary>

- [x] Phase 154: Design Contract + sg-notice (2/2 plans) — completed 2026-06-03
- [x] Phase 155: Shared Component Foundation (KEYSTONE) (3/3 plans) — completed 2026-06-04
- [x] Phase 156: Adopt Shared Components on Baselined Screens (6/6 plans) — completed 2026-06-04
- [x] Phase 157: Overview Landings (Highest Effort) (4/4 plans) — completed 2026-06-04
- [x] Phase 158: Audit Mobile + Per-User Audit (High Effort) (5/5 plans) — completed 2026-06-04
- [x] Phase 159: Cross-Journey Coherence Sweep + Seed Enrichment (5/5 plans) — completed 2026-06-05
- [x] Phase 160: Regression Hardening + Baseline Ratification (4/4 plans) — completed 2026-06-05

Archive:

- [v1.34 Roadmap](milestones/v1.34-ROADMAP.md)
- [v1.34 Requirements](milestones/v1.34-REQUIREMENTS.md)
- [v1.34 Milestone Audit](milestones/v1.34-MILESTONE-AUDIT.md)
- [v1.34 Phase Artifacts](milestones/v1.34-phases/)

</details>

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
| --- | --- | --- | --- | --- |
| 199. Foundation — Tier-2 Scorecard & Stress Fixtures | v1.41 | 4/4 | Complete    | 2026-06-25 |
| 200. User Detail Elevation | v1.41 | 3/3 | Complete    | 2026-06-26 |
| 201. Users Index Elevation | v1.41 | 4/4 | Complete    | 2026-06-26 |
| 202. Audit Surfaces Elevation | v1.41 | 5/5 | Complete    | 2026-06-26 |
| 203. Consistency Propagation | v1.41 | 5/5 | Complete    | 2026-06-26 |
| 204. Terminal Ratification | v1.41 | 0/TBD | Not started | - |
| 193. Baseline, Observability & One-Line Wins | v1.40 | 3/3 | Complete    | 2026-06-19 |
| 194. Caching Correctness & Micro-Job Consolidation | v1.40 | 2/2 | Complete    | 2026-06-20 |
| 195. Test-Suite Performance (partition / async / dep-off slim) | v1.40 | 3/3 | Complete    | 2026-06-20 |
| 196. PR-Fast vs Nightly-Broad Trigger Model | v1.40 | 4/4 | Complete    | 2026-06-20 |
| 197. Playwright Lanes & Design-Gallery Re-Gate | v1.40 | 5/5 | Complete   | 2026-06-20 |
| 198. Contributor DX & Acceptance Gate | v1.40 | 3/3 | Complete    | 2026-06-21 |
| 150. Issue Triage & Bugfix Cadence | v1.33 | 1/1 | Complete | 2026-06-01 |
| 151. Ecosystem Sync & Hex Dependency Management | v1.33 | 1/1 | Complete | 2026-06-01 |
| 152. Strategic Bet Evaluation Gate | v1.33 | 1/1 | Complete | 2026-06-01 |
| 153. Infrastructure Stability & CI Hardening | v1.33 | 1/1 | Complete | 2026-06-02 |
| 154. Design Contract + sg-notice | v1.34 | 2/2 | Complete | 2026-06-03 |
| 155. Shared Component Foundation (KEYSTONE) | v1.34 | 3/3 | Complete | 2026-06-04 |
| 156. Adopt Shared Components on Baselined Screens | v1.34 | 6/6 | Complete | 2026-06-04 |
| 157. Overview Landings (Highest Effort) | v1.34 | 4/4 | Complete | 2026-06-04 |
| 158. Audit Mobile + Per-User Audit (High Effort) | v1.34 | 5/5 | Complete | 2026-06-04 |
| 159. Cross-Journey Coherence Sweep + Seed Enrichment | v1.34 | 5/5 | Complete | 2026-06-05 |
| 160. Regression Hardening + Baseline Ratification | v1.34 | 4/4 | Complete | 2026-06-05 |
| 161. Brand Evidence Extraction + Pressure-Test Audit | v1.35 | 1/1 | Complete | 2026-06-05 |
| 162. Brand DNA + Voice System | v1.35 | 1/1 | Complete | 2026-06-05 |
| 163. Tokens + UI/UX Buildout Spec | v1.35 | 1/1 | Complete | 2026-06-05 |
| 164. Logo + SVG Asset System | v1.35 | 1/1 | Complete | 2026-06-05 |
| 165. Static HTML Brand Book | v1.35 | 1/1 | Complete | 2026-06-05 |
| 166. Verification + Repo Hygiene | v1.35 | 1/1 | Complete | 2026-06-05 |
| 167. Logo Options + Brand Direction Review | v1.35 | 2/2 | Complete | 2026-06-05 |
| 168. Admin Brand + Theme Audit | v1.36 | 1/1 | Complete | 2026-06-06 |
| 169. Durable UI Principles + Design Contract Update | v1.36 | 1/1 | Complete | 2026-06-06 |
| 170. Rail Accent Shell + Theme Control | v1.36 | 1/1 | Complete | 2026-06-06 |
| 171. Design-System Touchpoint Polish | v1.36 | 1/1 | Complete | 2026-06-06 |
| 172. Tests, Evidence, and Baseline Ratification | v1.36 | 1/1 | Complete | 2026-06-06 |
| 173. Auth Branding Contract + Token Model | v1.37 | 1/1 | Complete | 2026-06-07 |
| 174. Generated Auth Shell + Light/Dark/System CSS | v1.37 | 1/1 | Complete | 2026-06-07 |
| 175. Admin Customizer + Email Branding | v1.37 | 1/1 | Complete | 2026-06-07 |
| 176. Generated Host, Example, Docs, and Golden Parity | v1.37 | 1/1 | Complete | 2026-06-07 |
| 177. Verification, Generated-Host Smoke, and Audit Closure | v1.37 | 1/1 | Complete | 2026-06-07 |
| 178. Brand v2 Pressure-Test Audit | v1.38 | 2/2 | Complete   | 2026-06-12 |
| 179. Outlining Toolchain + Logo Concept Exploration | v1.38 | 2/2 | Complete   | 2026-06-12 |
| 180. Human Logo Ratification Gate | v1.38 | 1/1 | Complete   | 2026-06-12 |
| 181. Ratified Logo System Buildout | v1.38 | 2/2 | Complete   | 2026-06-13 |
| 182. Brand Book v2 + Tokens | v1.38 | 2/2 | Complete   | 2026-06-13 |
| 183. Propagation, Parity + Verification | v1.38 | 2/2 | Complete   | 2026-06-13 |
| 184. Distribution & Parity | v1.39 | 3/3 | Complete | 2026-06-14 |
| 185. Audit Infrastructure | v1.39 | 3/3 | Complete | 2026-06-14 |
| 186. Token Foundation (L0) | v1.39 | 4/4 | Complete | 2026-06-14 |
| 187. Individual Components (L1) | v1.39 | 6/6 | Complete | 2026-06-15 |
| 188. Meta-Components / Groups (L2) | v1.39 | 6/6 | Complete | 2026-06-15 |
| 189. Page Compositions (L3) | v1.39 | 3/3 | Complete | 2026-06-17 |
| 190. Flows & Fixture Data (L4) | v1.39 | 5/5 | Complete | 2026-06-17 |
| 191. Microcopy & IA Sweep | v1.39 | 4/4 | Complete | 2026-06-18 |
| 192. Ratification & Baseline Lock | v1.39 | 4/4 | Complete | 2026-06-18 |
