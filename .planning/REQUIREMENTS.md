# Requirements: Sigra — v1.39 DS-COHERENCE

**Defined:** 2026-06-13
**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Milestone goal:** Turn the strengthened brand into a systematically audited, award-grade admin/operator design system — evaluated *fractally* at every level (individual components → repeatable component groups → page compositions → operator flows) for on-brand color/type/spacing/radius/shadow, correct Light/Dark/System, best-practice (emilkowal.ski-aligned) animation, complete interaction states, mobile-first responsive at every width, GOV.UK-style information architecture / principle of least surprise, and on-brand UX microcopy serving the JTBD — across happy paths, main error cases, and boundary conditions. The work ships to real adopters (CSS distribution gap closed) and is idempotent: re-runs only ever move quality forward, never regress.

**Approved plan:** `~/.claude/plans/design-system-stress-test-serialized-candy.md`

**Idempotency model (applies to all requirements):** a committed quality-tier ledger (Tier 0 Drift / Tier 1 Ratified / Tier 2 Award-grade) plus a merge-blocking monotonic guard make regression un-mergeable; the existing canary/allowlist/axe/byte-golden harness enforces visual idempotency. A deterministic per-level scorecard (D1–D11 + level add-ons) re-fills identically on each run.

**Scope boundary — generated auth UI (login/register/reset/MFA/sudo)** is NOT a target surface, but TOKEN-* changes must preserve three-surface ember parity (`brandbook/tokens.json` ↔ `--sg-color-*` admin ↔ `--sigra-auth-*` auth) so auth stays coherent.

## v1 Requirements

### Distribution & Parity (DIST) — Phase 184

- [x] **DIST-01**: The admin `sg-*` design system is extracted out of the example app into a single canonical installer template `priv/templates/sigra.install/admin/sigra_admin.css`; the example-only `vt-*`/Vaultr brand layer is NOT extracted.
- [x] **DIST-02**: The installer ships the admin stylesheet to generated hosts via `lib/sigra/install/features/admin.ex` `files/1` → host `priv/static/assets/sigra_admin.css` (analog of `core/sigra_auth.css`).
- [x] **DIST-03**: The generated admin layout links the stylesheet (a `<link rel="stylesheet">` added to `def admin/1` in `priv/templates/sigra.install/admin/layouts_admin_injection.ex`).
- [x] **DIST-04**: The example app consumes the same canonical CSS (no divergent copy), so Playwright/axe run against the shipped stylesheet.
- [x] **DIST-05**: A merge-blocking parity test proves the example admin CSS is byte-identical to the installer template (mirroring the existing `sigra_auth.css` install-golden parity).
- [x] **DIST-06**: A freshly generated host renders a *styled* admin UI, proven by the `generated_admin_playwright_smoke` lane (`RUN_PARITY=1`).

### Audit Infrastructure (INFRA) — Phase 185

- [x] **INFRA-01**: An example-only `/admin/_design` gallery LiveView renders every component and every meta-component group in every state, importing the real `Sigra.Admin.Components` (never bespoke markup); it lives only under `test/example/` and is never templated into `priv/templates/sigra.install/` (contract-guarded).
- [x] **INFRA-02**: A dedicated Playwright project trio `admin-design-{chromium,mobile,dark}` captures one composite state-matrix board PNG per component/group (element-scoped to stable ids), with axe (`wcag2a`+`wcag2aa`, 0 violations) paired to each board.
- [x] **INFRA-03**: A second empty `snapshot-allowlist-design` + a designated gallery canary board enforce the empty-allowlist discipline; `scripts/ci/snapshot-canary-guard.sh` recognizes the `-admin-design-*` slug pattern.
- [x] **INFRA-04**: A quality-tier ledger `guides/reference/admin-quality-ledger.md` records, per fractal-level item, the achieved tier (0/1/2) + evidence link.
- [x] **INFRA-05**: A merge-blocking `scripts/ci/quality-ledger-monotonic.sh` fails CI if any ledger cell's tier decreased versus the base ref.
- [x] **INFRA-06**: The fractal scorecard rubric (shared D1–D11 + component/group/page/flow add-ons) is committed as the ratified re-evaluation instrument.

### Token Foundation (TOKEN / THEME) — Phase 186

- [x] **TOKEN-01**: The `:root` token layer (color, type scale, spacing, radius, control heights, elevation/shadow, focus ring, z-index) is audited and ratified, each token carrying a documented rationale + brand reference.
- [x] **TOKEN-02**: Every color token pair passes WCAG AA in light AND dark (axe-verified), including text on brand-soft surfaces.
- [x] **TOKEN-03**: Motion-budget tokens (durations + easings) are validated against emilkowal.ski timing/easing guidance and ratified as the project motion budget.
- [x] **TOKEN-04**: Three-surface ember parity is preserved across any token change (`brandbook/tokens.json` ↔ admin `--sg-*` ↔ auth `--sigra-auth-*`); auth surfaces remain coherent.
- [x] **THEME-01**: Tokens render correctly across Light, Dark, and System (explicit `data-sg-admin-theme` + `prefers-color-scheme`) with no theme-ignoring hardcoded values; dark uses lightened brand-strong (`#fdba74`).

> Phase 186 is the **only** phase permitted to change token *values* (blast-radius control).

### Individual Components (COMP) — Phase 187

- [ ] **COMP-01**: All 13 canonical components pass the per-component scorecard (D1–D11) in light/dark/mobile at ≥ Ratified (target Award-grade), with the gallery state-matrix exhaustively rendering each component's states.
- [ ] **COMP-02**: Each component's micro-interactions are emilkowal.ski-aligned (exact-property transitions never `transition:all`, pointer-gated hover, keyboard-frequent paths not animated, reduced-motion strips movement, interruptible).
- [ ] **COMP-03**: Each component exposes complete, visually-distinct interaction states (default/hover/focus-visible/active/disabled/loading/empty/error as applicable); disabled looks disabled and is inert.
- [ ] **COMP-04**: Per-component axe clean (light+dark), ARIA correct per contract; byte-golden ExUnit goldens updated only for intended markup changes.
- [ ] **COMP-05**: Each component reflows correctly with no overflow/clip/squish at 320/375/768/1024/1440.
- [ ] **COMP-06**: Component-level microcopy (empty_state, notice, field_help) is on-brand and serves the JTBD.

### Meta-Components / Groups (GROUP) — Phase 188

- [x] **GROUP-01**: All meta-component groups (MG-1..MG-11) pass the meta scorecard, including intra-group rhythm, no card-in-card nesting, and right-component-for-job composition.
- [x] **GROUP-02**: Each group defines its zero, loading, and error states.
- [x] **GROUP-03**: Desktop-table ↔ mobile-card swaps are content-equivalent at the breakpoint, with graceful overflow (wrap/scroll-contain/truncate) and no squished columns.
- [x] **GROUP-04**: Groups reused across ≥2 pages render byte-coherently.

### Page Compositions (PAGE) — Phase 189

- [x] **PAGE-01**: The 3 archetypes (Overview/List/Detail) pass the page scorecard, including archetype conformance and consistent page vertical rhythm (no flush sections / no double gaps).
- [x] **PAGE-02**: GOV.UK information architecture is verifiable (general→specific; tasks-first / posture-second / capabilities-last) and the principle-of-least-surprise checklist passes.
- [x] **PAGE-03**: Overlays/modals center correctly, trap focus, dismiss on Escape/outside-click/cancel, and restore scroll; sticky/scroll behavior causes no layout shift; pagination is honest (no phantom affordances).
- [x] **PAGE-04**: The non-archetypal pages (Branding customizer, Audit explorer) are explicitly scored against the rubric.
- [x] **PAGE-05**: Page-level a11y (landmark/heading order, focus management on navigate/patch) passes; the 8 admin checkpoints × 3 projects are ratified.

### Flows & Fixture Data (FLOW / DATA) — Phase 190

- [ ] **FLOW-01**: Each persona JTBD journey (platform admin / support investigator / org admin) passes happy + main-error + boundary, with scope and return-context preserved across navigation.
- [ ] **FLOW-02**: Each flow is fully keyboard-operable with visible focus and remains calm under `prefers-reduced-motion`.
- [ ] **FLOW-03**: The Light/Dark/System choice persists across the whole flow and on reload (no server state).
- [ ] **DATA-01**: Deterministic seed/persona enrichment provides a fixture reproducing each flow's happy, error, and boundary case.

### Microcopy & IA Sweep (COPY) — Phase 191

- [ ] **COPY-01**: A system-wide voice pass aligns all admin microcopy with the brand book (precise/honest/useful/calm/maintainer-grade); errors state what failed + why it matters + the next action.
- [ ] **COPY-02**: A GOV.UK plain-language pass yields a committed one-term-per-concept glossary with no synonym drift across pages.
- [ ] **COPY-03**: Empty-state, success, and warning copy is consistent across all admin surfaces.

### Ratification & Baseline Lock (GATE) — Phase 192

- [ ] **GATE-01**: All baselines (admin checkpoints + gallery boards) are deliberately recaptured via the recapture gate; both allowlists are reset to empty; both canaries are green.
- [ ] **GATE-02**: Generated-host parity is proven (`RUN_PARITY=1`), full-surface axe is clean, and the byte-golden component suite is green.
- [ ] **GATE-03**: The final quality ledger records the achieved tier per item, and the monotonic guard is green versus `origin/main` (forward-only proven so a re-run starts from "current = ratified").

## Future Requirements (deferred)

- Generated auth-UI (login/register/reset/MFA/sudo) design-system audit — deferred; this milestone preserves auth token coherence only.
- Per-organization admin branding / themeable admin palettes — deferred (no concrete adopter demand).
- PNG/raster baseline exports and a published component-gallery site — deferred until a distribution need exists.
- Adopting `phx_storybook` — rejected for this milestone (build-free / minimal-deps ethos); revisit only if the hand-rolled gallery proves insufficient.

## Out of Scope (explicit exclusions)

- Re-litigating "same job → same component" winners — ratified in v1.34; this milestone raises quality *within* winners, it does not re-pick them.
- Brand-book / logo rework — completed in v1.38 (D4 Linked Rail); the brand book is the value *reference*, not under audit.
- Adopting Tailwind as the admin source of truth — the hand-authored `sg-*` cascade-layer system stays canonical.
- New admin features, screens, or navigation restructure — quality/coherence only, no net-new surfaces.
- README / GitHub social-preview adoption — separate `/gsd-quick` fast-follow.

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DIST-01..06 | 184 | pending |
| INFRA-01..06 | 185 | pending |
| TOKEN-01..04, THEME-01 | 186 | pending |
| COMP-01..06 | 187 | pending |
| GROUP-01..04 | 188 | complete |
| PAGE-01..05 | 189 | pending |
| FLOW-01..03, DATA-01 | 190 | pending |
| COPY-01..03 | 191 | pending |
| GATE-01..03 | 192 | pending |
