# Roadmap: Sigra

**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Status:** v1.42 ADMIN-DS-ELEVATION in progress (phases 205-211). Hex: `v1.1.0`.

## Milestones

- 🚧 **v1.42 ADMIN-DS-ELEVATION** — Phases 205-211 (in progress)
- ✅ **v1.41 ADMIN-UX-ELEVATION** — Phases 199-204 (shipped 2026-06-27)
- ✅ **v1.40 CI-PERF** — Phases 193-198 (shipped 2026-06-21)
- ✅ **v1.39 DS-COHERENCE** — Phases 184-192 (shipped 2026-06-19)
- ✅ **v1.38 BRAND-V2** — Phases 178-183 (shipped 2026-06-13)
- ✅ **v1.37 AUTH-BRANDING-WHITELABEL** — Phases 173-177 (shipped 2026-06-07)
- ✅ **v1.36 ADMIN-BRAND-THEME-POLISH** — Phases 168-172 (shipped 2026-06-06)
- ✅ **v1.35 BRAND-SYSTEM-PRESSURE-TEST** — Phases 161-167 (shipped 2026-06-05)
- ✅ **v1.34 ADMIN-UI-COHERENCE** — Phases 154-160 (shipped 2026-06-05)
- ✅ **v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS** — Phases 150-153 (shipped 2026-06-02)

## Phases

- [ ] **Phase 205: Foundation** - Adversarial judge instrument, real-configuration gallery, and stress fixtures
- [ ] **Phase 206: L1 Component Elevation Wave A** - Elevate 8 highest-reuse L1 components to Tier-2
- [ ] **Phase 207: L1 Component Elevation Wave B + L0 Token Layer** - Elevate 5 remaining L1 components and token layer to Tier-2
- [ ] **Phase 208: L2 Meta-Component Group Elevation** - Elevate all 11 meta-component groups (MG-1…MG-11) to Tier-2
- [ ] **Phase 209: Judgment-Level Page Pass** - Adversarial persona panel over all 8 pages; apply remediations under monotonic guard
- [ ] **Phase 210: Remaining Cell Elevation** - Elevate user-sessions page and 3 persona flows to Tier-2
- [ ] **Phase 211: Terminal Ratification** - Every ledger cell reads 2, baselines recaptured, generated-host parity proven

<details>
<summary>✅ v1.41 ADMIN-UX-ELEVATION (Phases 199-204) — SHIPPED 2026-06-27 · full detail in milestones/v1.41-ROADMAP.md</summary>

- [x] **Phase 200: User Detail Elevation** — Award-grade pass on `user_show_live.ex`: calm identity header, JTBD-first restructuring of the 9-panel stack with progressive disclosure, safe confirmed destructive flow, proven across the full viewport/theme/state matrix. Covers DETAIL-01, DETAIL-02, DETAIL-03, DETAIL-04. (completed 2026-06-26)
- [x] **Phase 201: Users Index Elevation** — Award-grade pass on `users_index_live.ex`: consolidated filter panel, demoted metric strip, DRY desktop/mobile presentation, honest pagination, stress-proven against list-scale fixtures. Covers INDEX-01, INDEX-02, INDEX-03, INDEX-04. (completed 2026-06-26)
- [x] **Phase 202: Audit Surfaces Elevation** — Award-grade pass on `audit_index_live.ex` + `audit_user_live.ex`: unified filter form with advanced-disclosure, reduced column density, mobile-first stacking, Export surfaced, pagination proven on ≥25-event fixture. Covers AUDIT-01, AUDIT-02, AUDIT-03. (completed 2026-06-26)
- [x] **Phase 203: Consistency Propagation** — Roll the elevated bar to Overviews, Branding workbench, and design gallery/MG-1..11; update design contract + UI principles docs for any evolved archetypes; same-job → same-component, no net-new surfaces. Covers PROP-01, PROP-02. (completed 2026-06-26)
- [x] **Phase 204: Terminal Ratification** — Recapture all baselines through the gate with allowlists reset to empty; monotonic guard green; full-surface axe clean including overlays-open; generated-host parity proven; adversarial milestone review; Tier-2 cells locked. Covers RATIFY-01, RATIFY-02. (completed 2026-06-27)

</details>

## Phase Details

### Phase 205: Foundation

**Goal**: The judge instrument, gallery configurations, and stress fixtures are in place — every downstream phase can run the rubric and render realistic states
**Depends on**: Nothing (first phase of milestone; continues from Phase 204)
**Requirements**: INSTR-01, INSTR-02, INSTR-03, FIXT-01
**Success Criteria** (what must be TRUE):

  1. `guides/reference/admin-persona-jtbd-rubric.md` exists, defines the 3 lenses (platform admin / support investigator / org admin), the 3 fixed verdict questions, an ordinal keep/tighten/kill scale, and a fixed output schema — cross-referenced from the fractal scorecard and quality ledger
  2. The `/admin/_design` gallery renders all meta-component groups in `board-cfg-*` real-page composite configurations (not just isolated boards), and `admin-design.spec.ts` snapshots those composites clean across chromium/mobile/dark
  3. `.planning/v1.42-IA-DIAGNOSTIC.md` is committed with a persona panel reading across all 8 admin pages and a prioritized disposition list for the component/group/page work
  4. Demo seed/persona data for the `@demo.tasklane.test` cohort covers error/boundary/edge states (empty, long-string/UUID overflow, ≥25-event actor, failed/warning status, permission-denied) with `loadtest-` marker — `mix test` CI fixture is unmodified

**Plans**: 2/4 plans executed
Plans:
**Wave 1**

- [x] 205-01-PLAN.md — Author admin-persona-jtbd-rubric.md + bidirectional cross-refs into scorecard/ledger + IN-04 Terminal-Ratification prose fix (INSTR-01)
- [x] 205-02-PLAN.md — FIXT-01 seed fixtures: zoe persona, ghost-org, i18n/RTL loadtest user, Seeds.bulk_cohort_size/0, @seconds_per_day, IN-01/02/03/05 hardening (FIXT-01)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 205-03-PLAN.md — board-cfg-* real-page composites in design_gallery_live.ex + CONFIG_BOARDS in admin-design.spec.ts + baseline captures (INSTR-02)
- [x] 205-04-PLAN.md — .planning/v1.42-IA-DIAGNOSTIC.md: 8-page inventory + persona-panel pass + prioritized disposition list for 206-210 (INSTR-03)

**UI hint**: yes

### Phase 206: L1 Component Elevation Wave A

**Goal**: The 8 highest-reuse L1 components are award-grade — every interactive state, motion-token conformant, light/dark/system correct, accessible, and axe-clean across all 3 Playwright projects
**Depends on**: Phase 205
**Requirements**: COMP-01
**Success Criteria** (what must be TRUE):

  1. Each of the 8 components (`notice`, `notice_link`, `stat`, `stat_link`, `summary_chip`, `task_card`, `applied_chip`, `audit_row`) passes per-component axe-clean across chromium/mobile/dark Playwright projects (0 violations)
  2. No component uses `transition: all`; all component-level transitions are wrapped in `@media (prefers-reduced-motion: reduce)` that strips movement — verified by code review or automated check
  3. All 8 components render correctly in light/dark/system with no raw hex values outside `--sg-*` token vars; documented target-size is cited
  4. All 8 L1 ledger rows are flipped to bare `2` with evidence citations and `scripts/ci/quality-ledger-monotonic.sh --base origin/main` exits 0

**Plans**: 4/4 plans complete

Plans:
**Wave 1** *(parallel)*

- [x] 206-01-PLAN.md — Build admin-css-conformance.sh CI guard + self-test (D-05)
- [x] 206-02-PLAN.md — Audit 8 L1 components; fix raw hex gap in sigra_admin.css; byte-coherence propagation (D-02, D-03, D-06)

**Wave 2** *(depends on Wave 1)*

- [x] 206-03-PLAN.md — Scorecard token-name fix (D-07); snapshot-recapture gate for affected boards (D-09)
- [x] 206-04-PLAN.md — Flip all 8 L1 ledger rows to bare tier 2 with rich evidence; monotonic guard green (D-08)

**UI hint**: yes

### Phase 207: L1 Component Elevation Wave B + L0 Token Layer

**Goal**: The remaining 5 L1 components and the L0 token layer reach Tier-2, completing the full 13-component + token-layer elevation
**Depends on**: Phase 206
**Requirements**: COMP-02, COMP-03
**Success Criteria** (what must be TRUE):

  1. Each of the 5 remaining components (`empty_state`, `page_back`, `scope_ribbon`, `field_help`, `skeleton`) passes axe-clean across chromium/mobile/dark and has no `transition: all` / motion violating `prefers-reduced-motion`
  2. The L0 token layer has documented brand-token conformance (no raw hex/px outside `--sg-*` tokens; light/dark/system parity) and `admin-token-reference.md` is refreshed to cite the conformance evidence
  3. All 5 component ledger rows and the `token-layer` ledger row are flipped to bare `2` with evidence; monotonic guard exits 0
  4. All 13 L1 ledger cells and the L0 cell now read `2` — the entire component + token layer is Tier-2

**Plans**: 4/4 plans complete

- [x] 207-01-PLAN.md — COMP-03 token guards: build admin-token-completeness.sh + .test.sh (D-06); resolve D-07 raw-px (narrow CHECK 3 or D-07a fallback)
- [x] 207-02-PLAN.md — COMP-02 audit of the 5 L1 components on isolated boards; narrow CSS fix only if a real gap surfaces (expected: none), byte-coherent across 3 copies
- [x] 207-03-PLAN.md — Snapshot recapture of affected board-* PNGs (no-op if no CSS edit) + refresh admin-token-reference.md to cite conformance evidence; canaries stable, allowlists empty
- [x] 207-04-PLAN.md — Flip 6 ledger rows (token-layer L0 + 5 L1) to bare 2 with rich evidence; monotonic guard exits 0; full L0/L1 column Tier-2

**UI hint**: yes

### Phase 208: L2 Meta-Component Group Elevation

**Goal**: All 11 L2 meta-component groups are award-grade on both isolated boards and real-page configurations — every L0/L1/L2 building block is Tier-2, which is the precondition for the page judgment pass
**Depends on**: Phase 207
**Requirements**: GROUP-01, GROUP-02
**Success Criteria** (what must be TRUE):

  1. MG-1 through MG-11 each pass axe-clean on their isolated gallery boards across chromium/mobile/dark (0 violations); no card-in-card nesting, intra-group single-tier rhythm, right-component-for-job verified
  2. Every group's `board-cfg-*` real-page composite passes snapshot-clean across chromium/mobile/dark; MG-5 and MG-6 desktop↔mobile content-equivalence assertions are green (table+mobile-card swap proven)
  3. Zero/loading/error states are defined and rendered for each group that can enter those states; byte-coherent reuse verified across groups
  4. All 11 L2 ledger rows are flipped to bare `2` with evidence; monotonic guard exits 0; every L0/L1/L2 cell reads `2`

**Plans**: 2/3 plans executed
**Wave 1**

- [x] 208-01-PLAN.md — Audit 11 board-mg-* groups + 4 board-cfg-* composites vs L2 Tier-2 proxies; cite wired gates; narrow sg-* fix only if a real gap surfaces (D-02/D-04)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 208-02-PLAN.md — Capture 12 net-new board-cfg-* PNGs CI-native via admin_design_recapture (fold Phase-205 baseline debt); canaries stable; allowlists empty (D-05/D-10)

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 208-03-PLAN.md — Flip 11 mg-* L2 ledger rows to bare 2 with rich evidence; monotonic guard exits 0; full L0/L1/L2 column Tier-2 (D-06/D-07/D-08/D-09)

**UI hint**: yes

### Phase 208.1: v1.42 CI-Gate Remediation (INSERTED)

**Goal:** The required "Example Playwright smoke (full lifecycle)" CI check passes green on the v1.42 backlog — the ~15 real, never-CI-validated admin Playwright behavioral failures are fixed — so the backlog can ship through branch protection and Phase 208 can complete. Must run before the Phase 209 page pass (which assumes these gates are green).

**Depends on:** Phase 208
**Requirements**: 208.1-S1-env-independent-gallery-bugs, 208.1-S2-behavioral-spec-reconciliation, 208.1-S3-baseline-capture, 208.1-S4-cite-and-flip-revalidation, 208.1-S5-ci-arbiter-ship
**Evidence**: `.planning/v1.42-CI-GATE-REMEDIATION-FINDINGS.md` (full inventory + triage + root cause)
**Plans:** 4/4 plans complete

Scope (from findings):

1. Fix the 2 env-independent `admin_design` gallery bugs — `board-mg-1` `.sg-metric` count (6≠7) and `board-cfg-audit` `table.sg-table` 320px overflow.
2. Reconcile the redesign-broken behavioral specs (`admin_behavior`, `non_admin`, `demo_showcase`) — desktop+mobile dual-DOM strict-mode selector breakage, sudo heading, org empty-state, demo persona visibility.
3. Capture the 12 net-new `board-cfg-*` baselines CI-native (reuse `wip/recapture-trigger` once `admin-design` is green).
4. Re-validate the unsound "cite-and-flip" audits in 205/206/207/208 by actually running the specs (not re-reading code).
5. Use the real CI required check as the arbiter; then resume the one-PR backlog ship.

Plans:

- [x] 208.1-01-PLAN.md — Wave 1: fix 2 env-independent admin_design gallery bugs (board-mg-1 count→6, board-cfg-audit 320px responsive swap); design lane behaviorally green
- [x] 208.1-02-PLAN.md — Wave 2: reconcile admin_behavior dual-DOM strict-mode + stale sudo heading (incl. installer template + admin-generated spec) + audit disclosure selectors; no admin_checkpoints regression
- [x] 208.1-03-PLAN.md — Wave 3 (depends_on 02): reconcile non_admin (orgs, passkey-login) + demo_showcase persona visibility; cite-and-flip re-validation (RUN the 205/206/207/208 specs, escalate non-trivial new failures)
- [x] 208.1-04-PLAN.md — Wave 4 (depends_on 01/02/03): CI-native capture of 12 board-cfg baselines; drive required check green (automated gh assertion); delete wip/recapture-trigger guard-relax

### Phase 209: Judgment-Level Page Pass

**Goal**: All 8 admin pages have received an adversarial persona/JTBD review and every actionable verdict is resolved — info-dump, redundancy, and verbosity are remediated under the monotonic guard
**Depends on**: Phase 208
**Requirements**: PAGE-01, PAGE-02
**Success Criteria** (what must be TRUE):

  1. A scored review doc (`.planning/uat-evidence/v1.42-persona-jtbd/<surface>.md`) exists for each of the 8 admin pages with 3-persona verdicts and a per-surface disposition (`clean`/`actionable`/`blocked`); a roll-up index (`.planning/v1.42-PERSONA-JTBD-PANEL.md`) links all 8 docs
  2. Every `actionable` verdict from the panel has either a committed remediation diff or an explicit written waiver with rationale — no unresolved actionable verdicts remain
  3. No Tier-2 page regresses — `scripts/ci/quality-ledger-monotonic.sh --base origin/main` exits 0 after all remediations land
  4. Page Playwright baselines are recaptured under allowlist-then-clear discipline; both allowlists are empty at phase close and the canary is byte-stable

**Plans**: TBD
**UI hint**: yes

### Phase 210: Remaining Cell Elevation

**Goal**: The `user-sessions` page and 3 persona flows reach Tier-2, completing the elevation of every remaining ledger cell
**Depends on**: Phase 209
**Requirements**: PAGE-03, FLOW-01
**Success Criteria** (what must be TRUE):

  1. The `user-sessions` page passes: overlay axe-clean, all 7 APG focus-trap/restore gates (it owns the confirm dialog), glossary-clean microcopy, motion/density/target-size satisfied — each cited in the ledger evidence cell; `user-sessions` ledger row reads bare `2`
  2. Each of the 3 persona flows (`flow-platform-admin`, `flow-support-investigator`, `flow-org-admin`) proves happy/error/boundary/edge paths, scope/return-context continuity, full keyboard operability, calm reduced-motion, and theme persistence in Playwright
  3. Each flow cites its persona review doc (from Phase 209) as evidence and has a ledger row flipped to bare `2`
  4. The monotonic guard exits 0; every ledger cell is now Tier-2 — the whole fractal is complete

**Plans**: TBD
**UI hint**: yes

### Phase 211: Terminal Ratification

**Goal**: The milestone is closed and auditable — every ledger cell reads 2, all automated gates are green, and generated-host parity is proven end-to-end
**Depends on**: Phase 210
**Requirements**: GATE-01, GATE-02
**Success Criteria** (what must be TRUE):

  1. Every cell in `guides/reference/admin-quality-ledger.md` reads bare `2` (no decorators); `scripts/ci/quality-ledger-monotonic.sh --base origin/main` exits 0
  2. All admin Playwright baselines are recaptured with both allowlists (checkpoint + design-gallery) empty and both canaries byte-stable; compare-mode re-render shows zero PNG drift (idempotency proven)
  3. Installer↔example byte-parity and golden fixture stay green; a fresh `phx.new` + `mix sigra.install` + admin-acceptance smoke renders the elevated styled admin with no regressions
  4. An adversarial milestone audit doc is committed, recording the persona-JTBD verdicts as Tier-2 evidence and confirming no critical blockers remain

**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
| --- | --- | --- | --- | --- |
| 205. Foundation | v1.42 | 4/4 | Complete    | 2026-06-28 |
| 206. L1 Component Elevation Wave A | v1.42 | 4/4 | Complete    | 2026-06-28 |
| 207. L1 Component Elevation Wave B + L0 Token Layer | v1.42 | 4/4 | Complete    | 2026-06-28 |
| 208. L2 Meta-Component Group Elevation | v1.42 | 2/3 | In Progress|  |
| 209. Judgment-Level Page Pass | v1.42 | 0/? | Not started | - |
| 210. Remaining Cell Elevation | v1.42 | 0/? | Not started | - |
| 211. Terminal Ratification | v1.42 | 0/? | Not started | - |
| 199. Foundation — Tier-2 Scorecard & Stress Fixtures | v1.41 | 4/4 | Complete    | 2026-06-25 |
| 200. User Detail Elevation | v1.41 | 3/3 | Complete    | 2026-06-26 |
| 201. Users Index Elevation | v1.41 | 4/4 | Complete    | 2026-06-26 |
| 202. Audit Surfaces Elevation | v1.41 | 5/5 | Complete    | 2026-06-26 |
| 203. Consistency Propagation | v1.41 | 5/5 | Complete    | 2026-06-26 |
| 204. Terminal Ratification | v1.41 | 5/5 | Complete    | 2026-06-27 |
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
