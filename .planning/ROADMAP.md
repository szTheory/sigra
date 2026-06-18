# Roadmap: Sigra

**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Status:** v1.39 DS-COHERENCE ACTIVE (opened 2026-06-13) — admin/operator design-system fractal audit + hardening, phases 184-192. Defining requirements → roadmap. Previous: v1.38 BRAND-V2 shipped 2026-06-13 (`v1.1.0` on hex.pm).

## Milestones

- ◆ **v1.39 DS-COHERENCE** — Phases 184-192 (active, opened 2026-06-13)
- ✅ **v1.38 BRAND-V2** — Phases 178-183 (shipped 2026-06-13)
- ✅ **v1.37 AUTH-BRANDING-WHITELABEL** — Phases 173-177 (shipped 2026-06-07)
- ✅ **v1.36 ADMIN-BRAND-THEME-POLISH** — Phases 168-172 (shipped 2026-06-06)
- ✅ **v1.35 BRAND-SYSTEM-PRESSURE-TEST** — Phases 161-167 (shipped 2026-06-05)
- ✅ **v1.34 ADMIN-UI-COHERENCE** — Phases 154-160 (shipped 2026-06-05)
- ✅ **v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS** — Phases 150-153 (shipped 2026-06-02)

## Phases

### ◆ v1.39 DS-COHERENCE (Phases 184-192) — ACTIVE

**Milestone Goal:** Turn the strengthened v1.38 brand into a systematically audited, award-grade admin/operator design system — evaluated *fractally* (components → groups → pages → flows) and shipped to real adopters by closing the admin-CSS distribution gap, governed by a re-runnable quality ledger so re-runs only move quality forward.

**Approved plan:** `~/.claude/plans/design-system-stress-test-serialized-candy.md`
**Idempotency:** quality-tier ledger (Drift/Ratified/Award-grade) + merge-blocking monotonic guard + canary/allowlist/axe/byte-golden harness + deterministic fractal scorecard (D1–D11 + level add-ons).
**Methodology (every phase):** subagent research (best practices, anti-patterns, footguns, user loved/hated) → adversarial judge → synthesis, per GSD research→plan→execute→verify. Phase 186 is the ONLY phase allowed to change token *values* (blast-radius control).

- [x] **Phase 184: Distribution & Parity** — Extract canonical admin `sg-*` CSS into a shipped installer asset (`priv/templates/sigra.install/admin/sigra_admin.css`); link it in the generated admin layout; example consumes the same file; merge-blocking example≡template parity; styled generated-host proof. Requirements: DIST-01..06. (completed 2026-06-14)
  - Success: installer ships `sigra_admin.css`; admin layout links it; parity test green; generated host renders styled admin; existing canary stays green (no visual delta).
- [x] **Phase 185: Audit Infrastructure** — Build the example-only `/admin/_design` gallery (renders every component + group in every state, imports real `Sigra.Admin.Components`, never templated to installer); `admin-design-{chromium,mobile,dark}` board snapshot lane + empty `snapshot-allowlist-design` + gallery canary + axe; quality ledger + monotonic guard; ratified fractal scorecard rubric. Requirements: INFRA-01..06. (completed 2026-06-14)
  - Success: gallery + snapshot lane green with axe; ledger + `quality-ledger-monotonic.sh` merge-blocking; rubric committed.
- [x] **Phase 186: Token Foundation (L0)** — Adversarially audit + ratify the `:root` token layer (color/type/space/radius/shadow/control/elev/focus/z) in Light/Dark/System vs brand parity; validate motion-budget tokens against emilkowal.ski; preserve three-surface ember parity (auth stays coherent). Requirements: TOKEN-01..04, THEME-01. (completed 2026-06-14)
  - Success: every token has rationale + brand ref; all color pairs pass AA light+dark; motion tokens ratified; auth coherence preserved; token deltas declared in allowlists.
- [ ] **Phase 187: Individual Components (L1)** — Each of 13 components × full scorecard: emilkowal.ski micro-interactions, complete states, responsive 320–1440, a11y, local microcopy. Requirements: COMP-01..06.
  - Success: every component ≥ Ratified (target Award-grade) light/dark/mobile; byte-goldens updated only for intended markup; per-component axe clean; reduced-motion verified; ledger raised.
- [x] **Phase 188: Meta-Components / Groups (L2)** — The MG-1..MG-11 group catalog × meta scorecard: intra-group rhythm, no nesting, right-component-for-job, zero/loading/error states, desktop-table↔mobile-card swap integrity, cross-page byte-coherence. Requirements: GROUP-01..04. (completed 2026-06-15)
  - Success: each group passes; desktop/mobile content-equivalent at swap breakpoint; reused groups render byte-coherently; ledger raised.
- [x] **Phase 189: Page Compositions (L3)** — 3 archetypes (Overview/List/Detail) + non-archetypal Branding customizer + Audit explorer × page scorecard: GOV.UK IA, least-surprise, overlay/modal + scroll/sticky + pagination correctness, page-level a11y + responsive. Requirements: PAGE-01..05. (completed 2026-06-17)
  - Success: each page passes; 8 checkpoints × 3 projects ratified; IA hierarchy verifiable; non-archetypal pages explicitly scored.
- [x] **Phase 190: Flows & Fixture Data (L4)** — Persona JTBD journeys (platform admin / support investigator / org admin) across happy/error/boundary; deterministic seed/persona enrichment; scope/return continuity; keyboard + reduced-motion full traversal; theme persistence. Requirements: FLOW-01..03, DATA-01. (completed 2026-06-17)
  - Success: each persona flow passes happy + main-error + boundary with a deterministic fixture; scope/return context preserved; flow specs green.
- [x] **Phase 191: Microcopy & IA Sweep** — System-wide voice pass vs brand book; GOV.UK plain-language; one-term-per-concept glossary; error/empty/success tone consistency across all admin surfaces. Requirements: COPY-01..03. (completed 2026-06-18)
  - Success: glossary committed; every string passes voice + plain-language rubric; no synonym drift; ledger raised.
- [ ] **Phase 192: Ratification & Baseline Lock** — Terminal idempotency gate: re-run every scorecard; deliberately recapture all baselines (checkpoints + gallery) via the recapture gate; reset both allowlists to empty; prove generated-host parity (`RUN_PARITY=1`); full-surface axe; byte-goldens; commit final ledger. Requirements: GATE-01..03.
  - Success: all baselines ratified + both canaries green; allowlists empty; generated-host parity proven; final ledger records achieved tier per item; monotonic guard green vs origin/main.
  - **Plans:** 4 plans
    - [x] 192-01-PLAN.md — Widen axe tags to WCAG 2.1/2.2 AA in both Playwright helpers (D-07)
    - [x] 192-02-PLAN.md — Executable quarantine: known_failure tags, test.fail(), self-healing contract test, 2 tracking todos (D-11/D-12)
    - [x] 192-03-PLAN.md — Reword GATE-01 in REQUIREMENTS.md to remove force-recapture contradiction (D-04)
    - [x] 192-04-PLAN.md — Gate proof: compare-mode zero-drift, CI parity citation, monotonic guard, ledger terminal ratification (D-01/D-03/D-05/D-10/D-13)

**Requirement coverage:** DIST (184), INFRA (185), TOKEN/THEME (186), COMP (187), GROUP (188), PAGE (189), FLOW/DATA (190), COPY (191), GATE (192) — every v1.39 requirement maps to exactly one phase.

---

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

## Phase Details

### Phase 184: Distribution & Parity

**Goal**: The canonical admin `sg-*` design system ships from the installer to generated hosts and the example app consumes that exact same stylesheet, so the admin-CSS distribution gap is closed and a freshly generated host renders a styled admin UI — proven by a merge-blocking byte-parity test and a generated-host smoke lane.
**Depends on**: Phase 183 (v1.38 shipped)
**Requirements**: DIST-01, DIST-02, DIST-03, DIST-04, DIST-05, DIST-06
**Success Criteria** (what must be TRUE):

  1. The admin `sg-*` design system is extracted into a single canonical installer template `priv/templates/sigra.install/admin/sigra_admin.css`, with the example-only `vt-*`/Vaultr brand layer left out of the extraction.
  2. The installer ships the admin stylesheet to generated hosts via `lib/sigra/install/features/admin.ex` `files/1` → host `priv/static/assets/sigra_admin.css` (analog of `core/sigra_auth.css`), and the generated admin layout links it via a `<link rel="stylesheet">` in `def admin/1` of `priv/templates/sigra.install/admin/layouts_admin_injection.ex`.
  3. The example app consumes the same canonical CSS (no divergent copy), so Playwright/axe run against the shipped stylesheet.
  4. A merge-blocking parity test proves the example admin CSS is byte-identical to the installer template (mirroring the existing `sigra_auth.css` install-golden parity).
  5. A freshly generated host renders a styled admin UI, proven by the `generated_admin_playwright_smoke` lane (`RUN_PARITY=1`), and the existing snapshot canary stays green (no visual delta).

**Plans**: 3 plans
Plans:
**Wave 1**

- [x] 184-01-PLAN.md — Extract canonical sigra_admin.css template from app.css (selective sg-* extraction, D-03 dependency audit)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 184-02-PLAN.md — Ship via admin.ex files/1 (DIST-02) + layout link (DIST-03) + example copy + golden fixture + DIST-05 parity tests

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 184-03-PLAN.md — DIST-06 styled Playwright assertion + D-11 snapshot canary verification

**UI hint**: yes

### Phase 185: Audit Infrastructure

**Goal**: An example-only `/admin/_design` gallery renders every component and group in every state from the real `Sigra.Admin.Components`, backed by a board-snapshot lane + axe, an empty design allowlist + gallery canary, a quality-tier ledger with a merge-blocking monotonic guard, and a ratified fractal scorecard rubric — the re-runnable instrument the rest of the milestone is graded against.
**Depends on**: Phase 184
**Requirements**: INFRA-01, INFRA-02, INFRA-03, INFRA-04, INFRA-05, INFRA-06
**Success Criteria** (what must be TRUE):

  1. An example-only `/admin/_design` gallery LiveView renders every component and meta-component group in every state, importing the real `Sigra.Admin.Components` (never bespoke markup), living only under `test/example/` and contract-guarded against ever being templated into `priv/templates/sigra.install/`.
  2. A Playwright project trio `admin-design-{chromium,mobile,dark}` captures one composite state-matrix board PNG per component/group (element-scoped to stable ids) with paired axe (`wcag2a`+`wcag2aa`, 0 violations).
  3. A second empty `snapshot-allowlist-design` plus a designated gallery canary board enforce the empty-allowlist discipline, and `scripts/ci/snapshot-canary-guard.sh` recognizes the `-admin-design-*` slug pattern.
  4. A quality-tier ledger `guides/reference/admin-quality-ledger.md` records the achieved tier (0/1/2) + evidence link per fractal-level item, and a merge-blocking `scripts/ci/quality-ledger-monotonic.sh` fails CI if any cell's tier decreased versus the base ref.
  5. The fractal scorecard rubric (shared D1–D11 + component/group/page/flow add-ons) is committed as the ratified re-evaluation instrument.

**Plans**: 3 plans

**Wave 1** (parallel)

- [x] 185-01-PLAN.md — Gallery LiveView scaffold (all 13 component boards + MG-1..MG-5 groups), dev-gated router entry, D-04 contract guard, quality ledger, fractal scorecard rubric
- [x] 185-02-PLAN.md — quality-ledger-monotonic.sh guard script + CI job (quality_ledger_monotonic) + ci-gate registration

**Wave 2** (blocked on Wave 1)

- [x] 185-03-PLAN.md — admin-design Playwright spec + 3 projects in playwright.config.ts + snapshot-allowlist-design + canary guard extension + recapture gate extension + CI design board run + initial baseline capture

**UI hint**: yes

### Phase 186: Token Foundation (L0)

**Goal**: The `:root` token layer is adversarially audited and ratified across Light/Dark/System with documented rationale and brand references, every color pair passes AA, motion-budget tokens are validated against emilkowal.ski guidance, and three-surface ember parity is preserved so auth stays coherent. This is the only phase permitted to change token values.
**Depends on**: Phase 185
**Requirements**: TOKEN-01, TOKEN-02, TOKEN-03, TOKEN-04, THEME-01
**Success Criteria** (what must be TRUE):

  1. The `:root` token layer (color, type scale, spacing, radius, control heights, elevation/shadow, focus ring, z-index) is audited and ratified, each token carrying a documented rationale + brand reference.
  2. Every color token pair passes WCAG AA in light AND dark (axe-verified), including text on brand-soft surfaces.
  3. Motion-budget tokens (durations + easings) are validated against emilkowal.ski timing/easing guidance and ratified as the project motion budget.
  4. Three-surface ember parity is preserved across any token change (`brandbook/tokens.json` ↔ admin `--sg-*` ↔ auth `--sigra-auth-*`); auth surfaces remain coherent and any token deltas are declared in the allowlists.
  5. Tokens render correctly across Light, Dark, and System (explicit `data-sg-admin-theme` + `prefers-color-scheme`) with no theme-ignoring hardcoded values; dark uses lightened brand-strong (`#fdba74`).

**Plans**: 4 plans

**Wave 1** (parallel)

- [x] 186-01-PLAN.md — Token reference doc (admin-token-reference.md) + quality ledger L0 row
- [x] 186-02-PLAN.md — D-11 ExUnit dark-block parity assertion (admin_test.exs)
- [x] 186-03-PLAN.md — contrastRatio() tone-soft extension (admin-theme.spec.ts)

**Wave 2** (blocked on Wave 1)

- [x] 186-04-PLAN.md — Adversarial axe audit + conditional value-change gate + phase close

**UI hint**: yes

### Phase 187: Individual Components (L1)

**Goal**: Each of the 13 canonical components passes the full per-component scorecard — emilkowal.ski micro-interactions, complete visually-distinct states, responsive 320–1440, per-component axe, and on-brand microcopy — at ≥ Ratified (target Award-grade) in light/dark/mobile, with the gallery exhaustively rendering each component's states.
**Depends on**: Phase 186
**Requirements**: COMP-01, COMP-02, COMP-03, COMP-04, COMP-05, COMP-06
**Success Criteria** (what must be TRUE):

  1. All 13 canonical components pass the per-component scorecard (D1–D11) in light/dark/mobile at ≥ Ratified (target Award-grade), with the gallery state-matrix exhaustively rendering each component's states.
  2. Each component's micro-interactions are emilkowal.ski-aligned (exact-property transitions never `transition:all`, pointer-gated hover, keyboard-frequent paths not animated, reduced-motion strips movement, interruptible).
  3. Each component exposes complete, visually-distinct interaction states (default/hover/focus-visible/active/disabled/loading/empty/error as applicable); disabled looks disabled and is inert.
  4. Per-component axe is clean (light+dark), ARIA is correct per contract, and byte-golden ExUnit goldens are updated only for intended markup changes.
  5. Each component reflows correctly with no overflow/clip/squish at 320/375/768/1024/1440, and component-level microcopy (empty_state, notice, field_help) is on-brand and serves the JTBD; the ledger is raised.

**Plans**: 6 plans
Plans:
**Wave 1** (parallel)

- [x] 188-01-PLAN.md — Folded D-11 token/theme harness hardening
- [x] 188-02-PLAN.md — L2 group CSS migration into canonical shipped sigra_admin.css and mirrors

**Wave 2** (blocked on Wave 1 where noted)

- [x] 188-03-PLAN.md — MG-1..MG-11 design gallery catalog and state boards
- [x] 188-04-PLAN.md — MG-11 production confirmation standardization in UserShowLive

**Wave 3** (blocked on Wave 2)

- [x] 188-05-PLAN.md — Playwright L2 catalog, responsive, equivalence, coherence, axe, and snapshot evidence

**Wave 4** (blocked on Wave 3)

- [x] 188-06-PLAN.md — L2 scorecard, quality ledger, and validation ratification

**UI hint**: yes

### Phase 188: Meta-Components / Groups (L2)

**Goal**: The MG-1..MG-11 group catalog passes the meta scorecard — intra-group rhythm, no card-in-card nesting, right-component-for-job composition, zero/loading/error states, content-equivalent desktop-table↔mobile-card swaps, and byte-coherent reuse across pages.
**Depends on**: Phase 187
**Requirements**: GROUP-01, GROUP-02, GROUP-03, GROUP-04
**Success Criteria** (what must be TRUE):

  1. All meta-component groups (MG-1..MG-11) pass the meta scorecard, including intra-group rhythm, no card-in-card nesting, and right-component-for-job composition.
  2. Each group defines its zero, loading, and error states.
  3. Desktop-table ↔ mobile-card swaps are content-equivalent at the breakpoint, with graceful overflow (wrap/scroll-contain/truncate) and no squished columns.
  4. Groups reused across ≥2 pages render byte-coherently, and the ledger is raised.

**Plans**: Not yet planned
**UI hint**: yes

### Phase 189: Page Compositions (L3)

**Goal**: The 3 page archetypes (Overview/List/Detail) plus the non-archetypal Branding customizer and Audit explorer pass the page scorecard — GOV.UK information architecture, principle of least surprise, correct overlay/modal + scroll/sticky + pagination behavior, and page-level a11y/responsive — with the 8 admin checkpoints × 3 projects ratified.
**Depends on**: Phase 188
**Requirements**: PAGE-01, PAGE-02, PAGE-03, PAGE-04, PAGE-05
**Success Criteria** (what must be TRUE):

  1. The 3 archetypes (Overview/List/Detail) pass the page scorecard, including archetype conformance and consistent page vertical rhythm (no flush sections / no double gaps).
  2. GOV.UK information architecture is verifiable (general→specific; tasks-first / posture-second / capabilities-last) and the principle-of-least-surprise checklist passes.
  3. Overlays/modals center correctly, trap focus, dismiss on Escape/outside-click/cancel, and restore scroll; sticky/scroll behavior causes no layout shift; pagination is honest (no phantom affordances).
  4. The non-archetypal pages (Branding customizer, Audit explorer) are explicitly scored against the rubric.
  5. Page-level a11y (landmark/heading order, focus management on navigate/patch) passes, and the 8 admin checkpoints × 3 projects are ratified.

**Plans**: 3 plans

**Wave 1** (parallel — no file overlap)

- [x] 189-01-PLAN.md — ConfirmDialog APG modal hook (JS ×2) + scroll-lock CSS (×3 parity) + phx-hook wiring on user_show_live & branding_live (PAGE-03)
- [x] 189-02-PLAN.md — IA / vertical-rhythm / landmark-heading / honest-pagination audit on index, organization, users_index, audit_index, audit_user (PAGE-01/02/04/05)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 189-03-PLAN.md — Dedicated modal-interaction spec + axe-while-open + 8×3 checkpoint ratification + 6 L3 ledger rows ratified (PAGE-03/05)

**UI hint**: yes

### Phase 190: Flows & Fixture Data (L4)

**Goal**: Each persona JTBD journey (platform admin / support investigator / org admin) passes happy + main-error + boundary with scope and return-context preserved, full keyboard operability, calm reduced-motion behavior, and persistent theme — each reproducible from a deterministic seed/persona fixture.
**Depends on**: Phase 189
**Requirements**: FLOW-01, FLOW-02, FLOW-03, DATA-01
**Success Criteria** (what must be TRUE):

  1. Each persona JTBD journey (platform admin / support investigator / org admin) passes happy + main-error + boundary, with scope and return-context preserved across navigation.
  2. Each flow is fully keyboard-operable with visible focus and remains calm under `prefers-reduced-motion`.
  3. The Light/Dark/System choice persists across the whole flow and on reload (no server state).
  4. Deterministic seed/persona enrichment provides a fixture reproducing each flow's happy, error, and boundary case.

**Plans**: 5 plans

**Wave 1** (parallel)

- [x] 190-01-PLAN.md — WR-01/02/03 admin_hooks.js ConfirmDialog hardening (data-sg-confirm-cancel, body-sentinel focus fallback, Escape stopImmediatePropagation) + data-sg-confirm-cancel attribute in user_show_live/branding_live + WR-04 Ecto.Changeset error mapping
- [x] 190-02-PLAN.md — playwright.config.ts ADMIN_BEHAVIOR_SPECS regex fix (add admin-flow) + helpers/adminFlows.ts shared flow utilities (login, readiness, scope, theme, reduced-motion)

**Wave 2** *(parallel, blocked on Wave 1)*

- [x] 190-03-PLAN.md — Platform admin JTBD flow spec: happy (alice) + main-error (dave locked) + boundary (frank + empty filter) + keyboard + reduced-motion + theme persistence + reload
- [x] 190-04-PLAN.md — Support investigator + org admin JTBD flow specs: impersonation journey + banner continuity; 403 permission-denied + empty audit boundary (morgan zero events)

**Wave 3** *(blocked on Wave 2)*

- [x] 190-05-PLAN.md — Quality ledger 3 L4 rows ratification + VALIDATION.md population + seed idempotency verification

**UI hint**: yes

### Phase 191: Microcopy & IA Sweep

**Goal**: A system-wide voice pass aligns all admin microcopy with the brand book and GOV.UK plain-language standards, producing a committed one-term-per-concept glossary with no synonym drift and consistent error/empty/success/warning tone across every admin surface.
**Depends on**: Phase 190
**Requirements**: COPY-01, COPY-02, COPY-03
**Success Criteria** (what must be TRUE):

  1. A system-wide voice pass aligns all admin microcopy with the brand book (precise/honest/useful/calm/maintainer-grade); errors state what failed + why it matters + the next action.
  2. A GOV.UK plain-language pass yields a committed one-term-per-concept glossary with no synonym drift across pages.
  3. Empty-state, success, and warning copy is consistent across all admin surfaces, and the ledger is raised.

**Plans**: 3/4 plans executed

**Wave 1**

- [x] 191-01-PLAN.md — Glossary document (guides/reference/admin-glossary.md) + ExUnit drift guard (test/sigra/admin/glossary_test.exs)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 191-02-PLAN.md — Apply all copy violations across 5 affected LiveViews + components_test.exs golden update

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 191-03-PLAN.md — Quality ledger: add branding-live L3 row + D9/D10 axis re-scores

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 191-04-PLAN.md — Snapshot recapture for 5 affected slugs + canary restore + allowlist reset

**UI hint**: yes

### Phase 192: Ratification & Baseline Lock

**Goal**: The terminal idempotency gate re-runs every scorecard, deliberately recaptures all baselines via the recapture gate, resets both allowlists to empty, proves generated-host parity, runs full-surface axe and byte-goldens, and commits the final ledger — so a re-run starts from "current = ratified" and the monotonic guard proves forward-only.
**Depends on**: Phase 191
**Requirements**: GATE-01, GATE-02, GATE-03
**Success Criteria** (what must be TRUE):

  1. All baselines (admin checkpoints + gallery boards) are deliberately recaptured via the recapture gate; both allowlists are reset to empty; both canaries are green.
  2. Generated-host parity is proven (`RUN_PARITY=1`), full-surface axe is clean, and the byte-golden component suite is green.
  3. The final quality ledger records the achieved tier per item, and the monotonic guard is green versus `origin/main` (forward-only proven so a re-run starts from "current = ratified").

**Plans**: 4/4 plans complete
**UI hint**: yes

### Phase 178: Brand v2 Pressure-Test Audit

**Goal**: The v1.35 brandbook has been re-examined section-by-section with evidence-backed verdicts, the szTheory suite brand architecture is documented, and a logo v2 design brief encodes all hard constraints for the exploration phase.
**Depends on**: Phase 177 (v1.37 shipped)
**Requirements**: BRAND2-01, BRAND2-02, BRAND2-03
**Success Criteria** (what must be TRUE):

  1. `brandbook/pressure-test-audit-v2.md` exists with all 14 sections populated and every REWORK verdict accompanied by evidence; KEEP sections carry no unsupported claims.
  2. The audit includes a named szTheory suite brand-architecture section covering shared vs per-library identity elements for all seven libraries, informed by documented competitor/ecosystem visual research.
  3. A logo v2 design brief is committed that explicitly encodes: no rectangular container, boundary-breaking allowed, tight logotype proximity, subtitle-free main lockup, integrated-typemark candidates required, ember-anchored tunable palette, OFL typeface freedom.
  4. The audit's action plan section contains a prioritized list that directly drives the scope of Phases 179–183.

**Plans**: 2 plans
Plans:

- [x] 192-01-PLAN.md
- [x] 192-02-PLAN.md
- [x] 192-03-PLAN.md
- [x] 192-04-PLAN.md

- [x] 178-01-PLAN.md — Write brandbook/pressure-test-audit-v2.md: full 14-section audit with KEEP/TIGHTEN/REWORK verdicts and szTheory suite brand-architecture section
- [x] 178-02-PLAN.md — Write brandbook/logo-v2-design-brief.md: standalone design brief encoding 7 hard constraints, OFL font shortlist, letterform anatomy, and render-critique rubric

**UI hint**: yes

### Phase 179: Outlining Toolchain + Logo Concept Exploration

**Goal**: A reproducible glyph-outlining toolchain is committed and working; 5–7 logo candidates including at least 2 fully integrated typemarks are pre-verified across all required scales and themes; a round-3 gallery is openable from disk.
**Depends on**: Phase 178
**Requirements**: BRAND2-04, BRAND2-05, BRAND2-06
**Success Criteria** (what must be TRUE):

  1. A committed script using opentype.js can be invoked to produce wordmark path source from OFL fonts stored at a gitignored path; font name, version, and download provenance are documented in the SVG `<desc>` element and `brandbook/README.md`; no font binary is committed.
  2. At least 5 and at most 7 logo candidate SVGs exist, with at least 2 candidates where the motif is worked into the letterforms (not icon-beside-text), and each candidate has been rendered at 16px, 32px, 54px, and hero scale in both light and dark before being included.
  3. `brandbook/logo-options/round-3/index.html` opens directly from disk (no server, CDN, or build step required), links `../../tokens.css`, shows every candidate at favicon scale in both themes, and a companion `README.md` rationale table documents the design decisions behind each option.

**Plans**: 2 plans
Plans:

- [x] 179-01-PLAN.md — Toolchain + harness: scripts/brand/package.json, outline-wordmark.mjs, critique-render.mjs, .gitignore entries, brandbook/README.md font provenance
- [x] 179-02-PLAN.md — Candidates + critique loop + gallery: 7 candidate SVG sets, brandbook/logo-options/round-3/index.html + README.md

**UI hint**: yes

### Phase 180: Human Logo Ratification Gate

**Goal**: The maintainer has selected the final logo direction, typemark treatment, typeface, and any palette tuning; the decision and rationale are recorded; the ratified direction is unambiguous and ready for full asset buildout.
**Depends on**: Phase 179
**Requirements**: BRAND2-07
**Success Criteria** (what must be TRUE):

  1. The round-3 (or round-4 after one budgeted refinement loop) gallery README records the maintainer's selection with the chosen direction name, typeface, and any palette tuning notes.
  2. If a refinement round was used, the round-4 output is committed and the selection is made from that refined set; no additional refinement rounds are opened.
  3. The recorded decision is specific enough that Phase 181 asset buildout can proceed without reopening the design question.

**Plans**: 1 plan
Plans:

- [x] 180-01-PLAN.md — Human logo ratification gate: round-4 D4 Linked Rail selected, decision recorded in round-3 README

**UI hint**: yes

### Phase 181: Ratified Logo System Buildout

**Goal**: The full ratified logo asset set is committed, every file is render-verified, and usage rules (clearspace, minimum sizes, misuse) are documented; prior v1 logo assets are archived.
**Depends on**: Phase 180
**Requirements**: BRAND2-08
**Success Criteria** (what must be TRUE):

  1. All seven required SVG assets exist under `brandbook/`: `logo-primary.svg`, `logo-primary-dark.svg`, `logo-primary-subtitle.svg`, `logo-mark.svg`, `logo-monochrome.svg`, `favicon.svg`, plus light and dark social card SVGs.
  2. Each asset has been visually verified at its intended display size (favicon verified at 16px and 32px; social cards at thumbnail scale; primary lockup at hero and inline scales) in both light and dark contexts with no rendering artifacts.
  3. Clearspace rules, minimum size requirements, and at least four documented misuse examples are committed in the brandbook (as part of `index.html` or a companion markdown file).
  4. Prior v1 logo assets are moved to an archive path or tagged with a deprecation note so the working asset set contains only ratified v2 files.

**Plans**: 2 plans
Plans:

- [x] 181-01-PLAN.md — Typemark + mark + favicon: produce logo-primary.svg, logo-primary-dark.svg, logo-primary-subtitle.svg, logo-mark.svg, logo-monochrome.svg, favicon.svg from D4 source; render-verify all six
- [x] 181-02-PLAN.md — Social cards + archive + usage rules: social-card.svg and social-card-dark.svg, archive v1 assets atomically, update brandbook/README.md with clearspace/min-size/misuse documentation

**UI hint**: yes

### Phase 182: Brand Book v2 + Tokens

**Goal**: `brandbook/index.html` is a professional standalone v2 document reflecting all audit verdicts and the ratified logo; tokens are version-bumped with a change policy; all examples/ specimens show the new mark and pass axe.
**Depends on**: Phase 181
**Requirements**: BRAND2-09, BRAND2-10
**Success Criteria** (what must be TRUE):

  1. `brandbook/index.html` opens directly from disk with no build step, CDN, web font, or runtime dependency, displays the ratified v2 logo system, and reflects the audit verdicts from Phase 178.
  2. An automated axe accessibility check on `brandbook/index.html` returns zero violations.
  3. `brandbook/tokens.json` carries an incremented version field and `brandbook/tokens.css` is regenerated from it; a token change policy document (or section in `brandbook/README.md`) describes how token values are versioned and when consuming code should expect updates.
  4. Every specimen file in `brandbook/examples/` has been regenerated or verified to embed the ratified v2 mark (no stale v1 mark references remain).

**Plans**: 2 plans
Plans:

- [x] 182-01-PLAN.md — Token bump + brand-book.md + README Files-table + stale specimens: tokens.json v1.0.1, tokens.css provenance header, README refresh, brand-book.md suite/ember-parity content, two stale specimen SVGs updated to D4 geometry
- [x] 182-02-PLAN.md — index.html v2 expansion + axe harness + axe gate: #scorecard id, expanded #logo section with all 8 D4 assets, new #suite section, scripts/brand/axe-brandbook.mjs, zero-violation axe run

**UI hint**: yes

### Phase 183: Propagation, Parity + Verification

**Goal**: The ratified logo reaches every location the v1 logo already occupied under the same filenames; sg-* tokens are in sync with brandbook tokens; Playwright baselines are recaptured once; the repo is clean and all gates are green.
**Depends on**: Phase 182
**Requirements**: BRAND2-11, BRAND2-12, BRAND2-13, BRAND2-14
**Success Criteria** (what must be TRUE):

  1. `priv/templates/sigra.install/admin/` and `test/example/priv/static/images/` contain the ratified v2 logo under the same filenames as before; all installer and example parity tests pass without modification to test expectations.
  2. sg-* token values in the example app CSS, `sigra_auth.css` accent defaults, and the admin design contract are either updated to match any palette tuning from Phase 180 or explicitly verified unchanged when no palette change was made.
  3. `scripts/ci/snapshot-recapture-gate.sh` is run exactly once with all intended slugs declared and completes successfully; the snapshot canary guard returns to its expected empty steady state after the recapture.
  4. A final hygiene sweep confirms: all JSON/SVG/HTML files parse without errors, no committed binary files were introduced, `brandbook/` size delta is within acceptable bounds, `mix test` exits 0, and `git status` is clean.

**Plans**: 2 plans
Plans:

- [x] 183-01-PLAN.md — SVG propagation (D4 admin lockups + companion marks, installer==example byte-identical) + 2 guard test file updates + token parity verification + both mix test suites green
- [x] 183-02-PLAN.md — Playwright baseline recapture (allowlist +3, --update-snapshots=all on port 4011, canary restore, gate run, allowlist reset) + final hygiene sweep

**UI hint**: yes

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
| --- | --- | --- | --- | --- |
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
| 190. Flows & Fixture Data (L4) | v1.39 | 5/5 | Complete    | 2026-06-17 |
