# Roadmap: Sigra

**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Status:** Between milestones — v1.39 DS-COHERENCE shipped 2026-06-19 (phases 184-192). Ready for next milestone (`/gsd-new-milestone`). Hex: `v1.1.0`.

## Milestones

- ✅ **v1.39 DS-COHERENCE** — Phases 184-192 (shipped 2026-06-19)
- ✅ **v1.38 BRAND-V2** — Phases 178-183 (shipped 2026-06-13)
- ✅ **v1.37 AUTH-BRANDING-WHITELABEL** — Phases 173-177 (shipped 2026-06-07)
- ✅ **v1.36 ADMIN-BRAND-THEME-POLISH** — Phases 168-172 (shipped 2026-06-06)
- ✅ **v1.35 BRAND-SYSTEM-PRESSURE-TEST** — Phases 161-167 (shipped 2026-06-05)
- ✅ **v1.34 ADMIN-UI-COHERENCE** — Phases 154-160 (shipped 2026-06-05)
- ✅ **v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS** — Phases 150-153 (shipped 2026-06-02)

## Phases

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
