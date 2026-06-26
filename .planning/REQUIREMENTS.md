# Requirements: v1.41 ADMIN-UX-ELEVATION

**Milestone goal:** Streamline the highest-impact generated admin/operator pages to award-grade (Tier-2) quality — deliberate, JTBD-first, internally coherent, mobile-first, accessible (WCAG 2.2 AA), on-brand in light/dark/system — and ratchet them forward-only via the existing quality-ledger monotonic guard so quality can only ever increase.

**Scope (locked):** Top-3 deep (User Detail, Users Index, Audit index + per-user) + consistency propagation to Overviews/Branding/gallery. Real IA/interaction restructuring allowed **within** documented generated-host extension seams and the Detail/List/Overview archetypes. Forward-only enforced by extending the existing quality ledger + monotonic guard with objective Tier-2 proxies.

**"User" in these requirements** means the admin/operator personas (platform admin, org admin, support investigator, SRE, security reviewer) for the page surfaces, and the library maintainer for the design-system machinery.

---

## v1.41 Requirements

### Foundation — Tier-2 ratchet & stress fixtures

- [x] **LEDGER-01**: Maintainer can ratchet a surface from Tier 1 → Tier 2 on **objective evidence** — the quality ledger + fractal scorecard define measurable Tier-2 proxies (motion-token conformance / no `transition: all`, overlay-open axe-clean, desktop↔mobile content-equivalence, focus-trap/restore APG gates, glossary-clean microcopy, density/whitespace rhythm), not a subjective verdict.
- [x] **LEDGER-02**: The monotonic guard enforces the Tier-2 ratchet **forward-only** — once a cell reaches Tier 2 no future PR may decrease it; the guard stays merge-blocking vs `origin/main`.
- [x] **FIXT-01**: A deterministic demo persona carries **≥25 audit events** so pagination (MG-5 / MG-6) renders and desktop↔mobile content-equivalence is testable (closes the tracked `admin-design-mg5-6-content-equivalence-data-dependent` todo).
- [x] **FIXT-02**: The demo seed data stress-tests the admin surfaces with realistic ugly data — list-scale users, long display names / emails / UUIDs / identifiers, multi-session and multi-org breadth, and varied audit outcomes/severities — under the `MIX_ENV=test` raise guard with idempotent upserts.

### User Detail elevation (`user_show_live.ex`)

- [ ] **DETAIL-01**: User sees a calm, scannable identity header (primary identity + one priority alert + key metrics) instead of stacked pills + a 4-fact `<dl>` + alert.
- [x] **DETAIL-02**: The 9-panel stack is restructured into a deliberate JTBD-first composition (grouped sections / progressive disclosure / link-outs for unbounded Sessions · Organizations · Recent-audit) **while preserving the documented host-injected extra-section seams**.
- [x] **DETAIL-03**: The session revoke / revoke-all destructive flow is clearly separated and safely confirmed (APG dialog: focus trap + restore, Escape, click-outside, no scrim-hidden modal).
- [ ] **DETAIL-04**: User Detail is award-grade across the full matrix (320–1440px, light/dark/system, empty/loading/error/permission-denied/long-content, keyboard, reduced-motion); `user-show-live` ledger cell ratcheted to Tier 2.

### Users Index elevation (`users_index_live.ex`)

- [ ] **INDEX-01**: User filters through **one coherent panel** (search + quick toggles + advanced + applied state) instead of three separate blocks.
- [ ] **INDEX-02**: The user-health metric strip is demoted/slimmed so it never delays access to search, and per-row status pills are reduced to the ones that carry decision value.
- [ ] **INDEX-03**: The desktop-table ⇄ mobile-card presentation is content-equivalent and DRY, with clear inline row actions and honest pagination (no pagination affordance when there is nothing to paginate).
- [ ] **INDEX-04**: Users Index is award-grade across the full matrix (including list-scale fixtures); `users-index-live` ledger cell ratcheted to Tier 2.

### Audit surfaces elevation (`audit_index_live.ex` + `audit_user_live.ex`)

- [ ] **AUDIT-01**: The global and per-user audit filters are a **single form with an advanced-disclosure** (quick toggles folded in), with Export surfaced to the filter action row rather than buried in pagination.
- [ ] **AUDIT-02**: Audit row/column density is reduced (codes deferred to drill-down) and mobile-first stacked, with pagination proven on the ≥25-event fixture; the two audit pages stay byte-coherent.
- [ ] **AUDIT-03**: Both audit surfaces are award-grade across the full matrix; `audit-index-live` and `audit-user-live` ledger cells ratcheted to Tier 2.

### Consistency propagation

- [ ] **PROP-01**: The lean Overviews (`index_live.ex`, `organization_live.ex`) and the Branding workbench (`branding_live.ex`) match the elevated bar (same-job → same-component; no net-new surfaces), and the `/admin/_design` gallery + MG-1..MG-11 reflect the elevated compositions.
- [ ] **PROP-02**: The admin design contract + UI principles docs are updated to document any evolved archetypes/interaction patterns (forward, never silently); the one-term-per-concept glossary stays drift-guarded.

### Terminal ratification

- [ ] **RATIFY-01**: All baselines recaptured through the gate with both allowlists reset to empty; monotonic guard green vs `origin/main`; full-surface axe clean (including overlays-open); generated-host parity proven (install-golden byte-diff + admin-acceptance smoke).
- [ ] **RATIFY-02**: A final adversarial milestone review confirms no usability-for-aesthetics regression, no generated-host-contract friction, and no broken dark/mobile/keyboard/reduced-motion paths; Tier-2 cells locked.

---

## Future Requirements (deferred)

- Deep award-grade pass on the remaining surfaces beyond consistency-level (e.g. a full Branding-workbench redesign) — defer to a follow-up run of this milestone if propagation reveals it's warranted.
- Per-shard DB isolation to unlock true Playwright parallelism (tracked todo `playwright-parallelization-per-shard-db`) — orthogonal CI-perf work, not gated by this milestone.
- Tier-3 / motion-system expansion — only if Tier 2 proves insufficient as the ceiling.

## Out of Scope

- **No net-new admin surfaces**, no hosted-control-plane behavior, no generic authorization / compliance / SCIM expansion (post-1.0 posture).
- **No token-value redesign or brand re-theming** — compose existing ratified `:root --sg-*` tokens; preserve three-surface ember parity (`brandbook/tokens.json` ⇄ admin `--sg-color-brand` ⇄ auth accent). New tokens only as tokens (no one-off hex), parity preserved.
- **No PhoenixStorybook dependency** — extend the existing example-only `/admin/_design` gallery (DX/maintenance payoff not justified; avoids a new transitive dep).
- **No non-admin (auth / demo / Tasklane) screen redesign** except where a shared `sg-*` component change incidentally touches them.
- **No re-litigation of v1.34 component winners or the v1.38 brand/logo** — those contracts are inputs, not targets.

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| LEDGER-01 | Phase 199 | Complete |
| LEDGER-02 | Phase 199 | Complete |
| FIXT-01 | Phase 199 | Complete |
| FIXT-02 | Phase 199 | Complete |
| DETAIL-01 | Phase 200 | Pending |
| DETAIL-02 | Phase 200 | Complete |
| DETAIL-03 | Phase 200 | Complete |
| DETAIL-04 | Phase 200 | Pending |
| INDEX-01 | Phase 201 | Pending |
| INDEX-02 | Phase 201 | Pending |
| INDEX-03 | Phase 201 | Pending |
| INDEX-04 | Phase 201 | Pending |
| AUDIT-01 | Phase 202 | Pending |
| AUDIT-02 | Phase 202 | Pending |
| AUDIT-03 | Phase 202 | Pending |
| PROP-01 | Phase 203 | Pending |
| PROP-02 | Phase 203 | Pending |
| RATIFY-01 | Phase 204 | Pending |
| RATIFY-02 | Phase 204 | Pending |
