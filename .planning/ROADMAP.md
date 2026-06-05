# Roadmap: Sigra

**Core Value**: Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Status**: Active — v1.34 ADMIN-UI-COHERENCE in progress

## Milestones

- ✅ **v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS** — Phases 150-153 (shipped 2026-06-02)
- 🚧 **v1.34 ADMIN-UI-COHERENCE** — Phases 154-160 (in progress)

## Phases

<details>
<summary>✅ v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS (Phases 150-153) — SHIPPED 2026-06-02</summary>

- [x] Phase 150: Issue Triage & Bugfix Cadence (1/1 plan) — completed 2026-06-01
- [x] Phase 151: Ecosystem Sync & Hex Dependency Management (1/1 plan) — completed 2026-06-01
- [x] Phase 152: Strategic Bet Evaluation Gate (1/1 plan) — completed 2026-06-01
- [x] Phase 153: Infrastructure Stability & CI Hardening (1/1 plan) — completed 2026-06-02

Archive:

- [v1.33 Roadmap](milestones/v1.33-ROADMAP.md)
- [v1.33 Requirements](milestones/v1.33-REQUIREMENTS.md)
- [v1.33 Milestone Audit](milestones/v1.33-MILESTONE-AUDIT.md)
- [v1.33 Phase Artifacts](milestones/v1.33-phases/)

</details>

### 🚧 v1.34 ADMIN-UI-COHERENCE (In Progress)

**Milestone Goal:** Take the admin UI from "each screen polished individually" to one coherent, needs-led journey — principle of least surprise everywhere, "same job → same component."

- [x] **Phase 154: Design Contract + sg-notice** — Job→Component mapping, 3 page archetypes, ARIA/motion specs; sg-notice CSS addition. No behavior change. (completed 2026-06-03)
- [x] **Phase 155: Shared Component Foundation (KEYSTONE)** — Build `Sigra.Admin.Components`; 5×3 baselines green with zero re-records; admin-generated parity green. (completed 2026-06-04)
- [x] **Phase 156: Adopt Shared Components on Baselined Screens** — All 5 baselined screens import shared components; visual seam coherence reconciled; baselines re-recorded deliberately. (completed 2026-06-04)
- [x] **Phase 157: Overview Landings (Highest Effort)** — Both Overview screens fully needs-led; new `global-overview` + `org-overview` checkpoints ×3 projects. (completed 2026-06-04)
- [x] **Phase 158: Audit Mobile + Per-User Audit (High Effort)** — `AuditIndexLive` mobile card layout; `AuditUserLive` reconciled; new `user-audit` checkpoint ×3 projects. (completed 2026-06-04)
- [x] **Phase 159: Cross-Journey Coherence Sweep + Seed Enrichment** — End-to-end journey seams fixed; seed gaps closed; motion usage audit. (verification passed 6/6 2026-06-05 — GATE-03 closed via gap-closure plan 159-05) (completed 2026-06-05)
- [ ] **Phase 160: Regression Hardening + Baseline Ratification** — All baselines ratified; all gates closed; milestone proof bundle.

## Phase Details

### Phase 154: Design Contract + sg-notice

**Goal**: The design decisions that constrain all subsequent phases are committed as artifacts — no code behavior changes in this phase.
**Depends on**: Phase 153
**Requirements**: COMP-03, COMP-04
**Success Criteria** (what must be TRUE):

  1. A committed Job→Component mapping table documents all 10 canonical component jobs with their winning CSS, ARIA roles, motion spec (including explicit "not animated" entries), and when-NOT-to-use guidance.
  2. Three page archetypes (Overview, List, Detail) are documented as explicit component compositions, so any future screen can be assembled from the mapping without bespoke design.
  3. The `sg-notice` component style (~15 lines) is added inside `@layer sg-components` in `app.css` using only existing tokens — no unlayered rules, no new `!important`.
  4. No Playwright baselines change; no LiveView files are modified; the `admin-generated` parity lane stays green.

**Plans**: 2 plans
Plans:

- [x] 154-01-PLAN.md — Design contract governance doc + ExDoc registration (COMP-03)
- [x] 154-02-PLAN.md — sg-notice CSS inside @layer sg-components (COMP-04)

**Cross-cutting constraints:**

- No Playwright baseline snapshots are changed

**UI hint**: yes

### Phase 155: Shared Component Foundation (KEYSTONE)

**Goal**: `Sigra.Admin.Components` exists with all 10 canonical components, proven to be behavior-preserving by zero baseline re-records across all 5×3 existing checkpoints.
**Depends on**: Phase 154
**Requirements**: COMP-01, COMP-02
**Success Criteria** (what must be TRUE):

  1. `lib/sigra/admin/components.ex` exists with all 10 components (`stat_link`, `stat`, `task_card`, `summary_chip`, `applied_chip`, `empty_state`, `page_back`, `scope_ribbon`, `notice`, `skeleton`), each with documented `attr`/`slot` contracts.
  2. All 5×3 existing Playwright baselines (admin-checkpoints-chromium, -mobile, -dark) pass with zero re-records — confirmed by `render_component/2` markup equality checks before Playwright runs.
  3. The `admin-generated` installer-parity lane is green; no LiveView call sites have changed yet, so template parity is unaffected.
  4. No existing LiveView behavior changes; all axe (WCAG A/AA) checks stay green.

**Plans**: 3 plans

- [x] 155-01-PLAN.md — Build `Sigra.Admin.Components` with all 10 canonical function components (COMP-01)
- [x] 155-02-PLAN.md — `render_component` byte/structural-equality proof harness, goldens from original markup (COMP-02)
- [x] 155-03-PLAN.md — D-09 design-contract notice ARIA amendment + D-14 CI gate wiring (`needs: [release_ref_guard, library_tests]`)

**UI hint**: yes

### Phase 156: Adopt Shared Components on Baselined Screens

**Goal**: All 5 already-baselined admin screens import `Sigra.Admin.Components` and remove private duplicate component definitions; visual coherence seams are reconciled.
**Depends on**: Phase 155
**Requirements**: COHR-01, COHR-02, COHR-03, COHR-04, COHR-05, COHR-06
**Success Criteria** (what must be TRUE):

  1. No private duplicate `stat`/`task_card`/`chip`/`empty_state` definitions remain in any LiveView — all 5 screens use only `Sigra.Admin.Components`.
  2. `UserShowLive` renders via the open `sg-page-header` archetype (the `sg-card` boxed-header outlier is gone); header anatomy is consistent across all screens.
  3. Detail and leaf screens use a single `<.page_back>` component consuming `return_to`; breadcrumbs handle hierarchy; there is one obvious way back.
  4. A persistent `<.scope_ribbon>` component appears on every list and leaf screen, showing current scope (Global vs org name).
  5. All contextual alerts and flashes render through the shared `<.notice>` component with consistent tone treatment; no ad-hoc `sg-list-row` alert patterns remain.
  6. Empty-state structure and spacing are consistent across all screens via `<.empty_state>`.
  7. The `admin-generated` parity lane stays green after each screen is modified; intended visual deltas are re-recorded deliberately after HTML report review.

**Plans**: 6 plans
Plans:

**Wave 1**

- [x] 156-01-PLAN.md — CSS tone-merge: merge `.sg-list-row[data-tone]` + `.sg-notice[data-tone]` to shared selectors in `app.css` (D-08, COHR-05)
- [x] 156-02-PLAN.md — Pixel-neutral import swap: `index_live.ex` + `organization_live.ex` — delete `defp metric_link`/`defp task_card`, add import, rename to `<.stat_link>`, migrate `organization_live.ex` notice (COHR-01)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 156-03-PLAN.md — `UsersIndexLive` migration: import, `defp summary_chip` removal, `<.scope_ribbon>` after header, `<.applied_chip>`, `<.empty_state>`; re-record `global-user-index` + `org-scoped-admin` baselines (COHR-01, COHR-04, COHR-06)
- [x] 156-04-PLAN.md — `UserShowLive` migration: import, header archetype sg-card→sg-page-header, `<.page_back>`, `<.scope_ribbon>`, `<.notice>`, `<.empty_state>` ×4, `summary_alert/1` atom refactor; re-record `user-detail` baseline (COHR-01, COHR-02, COHR-03, COHR-04, COHR-05, COHR-06)
- [x] 156-05-PLAN.md — `AuditIndexLive` migration: import, `<.scope_ribbon>` after header, `<.applied_chip>`, `<.empty_state>`; re-record `audit-explorer` baseline (COHR-01, COHR-04, COHR-06)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 156-06-PLAN.md — Phase gate: full ExUnit + full Playwright checkpoint spec (4 slugs re-recorded, `impersonation-banner` byte-green) + parity smoke green (all COHR-01..06)

**Cross-cutting constraints:**

- D-07: A `<.scope_ribbon copy={scope_copy(@admin_scope)} />` element appears immediately after the `<header class=\"sg-page-header\">` block (not nested inside it) — same scope-display component on every list/leaf screen
- `impersonation-banner` snapshot stays byte-green

**UI hint**: yes

### Phase 157: Overview Landings (Highest Effort)

**Goal**: Both Overview screens are deliberate needs-led front doors — single prominent alarm, verb-first task cards, demoted posture/capability strips — and have committed Playwright checkpoint baselines for the first time.
**Depends on**: Phase 156
**Requirements**: LAND-01, LAND-02, LAND-03, LAND-04
**Success Criteria** (what must be TRUE):

  1. On both Global and Org Overview screens, the needs-review alarm is the most visually prominent element above the task grid — rendered loudly with count and a deep-link when count > 0, and as a calm "all clear" state when 0.
  2. Both Overviews lead with verb-first task cards as the primary content; posture metrics are demoted to a secondary deep-link strip; the capability matrix is demoted to the lowest priority position.
  3. Global and Org Overview screens share identical layout rhythm and component composition (differing task counts are acceptable; the visual archetype is the same).
  4. Async overview data renders a `<.skeleton>` loading state instead of an empty flash or layout jump.
  5. New Playwright checkpoints `global-overview` and `org-overview` pass with axe green across all 3 projects (chromium, mobile, dark); `admin-generated` parity lane stays green.

**Plans**: 4 plans
Plans:

**Wave 1** *(parallel — no file overlap)*

- [x] 157-01-PLAN.md — Global Overview redesign: `index_live.ex` connected?-gate mount, front-door archetype, alarm notice, skeleton shapes, delete sg-posture-strip__risk (LAND-01, LAND-02, LAND-03, LAND-04)
- [x] 157-02-PLAN.md — Org Overview redesign: `organization_live.ex` connected?-gate mount, delete Scoped-attention card (D-07 fold), front-door archetype, skeleton shapes ×3 regions, preserve members+invitations tail; design contract Org-variant note (LAND-01, LAND-02, LAND-03, LAND-04)

**Wave 2** *(blocked on Wave 1)*

- [x] 157-03-PLAN.md — ExUnit coverage: `describe "Phase 157 Overview redesign"` in `admin_shell_test.exs` — two-mount proof (GET=skeleton, live/2=data) for both screens; archetype-order and alarm-position assertions (LAND-01, LAND-02, LAND-03, LAND-04)

**Wave 3** *(blocked on Wave 2 — ExUnit must be green before baseline recording)*

- [x] 157-04-PLAN.md — Playwright baselines: add `global-overview` + `org-overview` slugs to `admin-checkpoints.spec.ts` with loaded-data wait guard; record 6 new PNGs; verify axe ×3 green; parity lane green (LAND-01, LAND-02, LAND-03, LAND-04)

**UI hint**: yes

### Phase 158: Audit Mobile + Per-User Audit (High Effort)

**Goal**: The audit surfaces are usable on mobile and fully coherent — `AuditIndexLive` has a mobile card fallback, `AuditUserLive` is reconciled with the explorer, and both have committed Playwright baselines.
**Depends on**: Phase 157
**Requirements**: AUDX-01, AUDX-02, AUDX-03
**Success Criteria** (what must be TRUE):

  1. `AuditIndexLive` renders a mobile card layout on small screens, mirroring the `UsersIndexLive` dual-layout pattern using `sg-show-desktop`/`sg-show-mobile` CSS utilities — usable on the iPhone 13 device profile.
  2. `AuditIndexLive` has quick-filter chips for common cases (failure outcome, impersonation events) consistent with the users-index filter idiom; no second bespoke filter pattern remains.
  3. `AuditUserLive` uses shared `<.page_back>`, `<.scope_ribbon>`, `<.notice>`, `<.empty_state>`, and a unified audit-row component also used by the `UserShowLive` "Recent audit" block.
  4. New Playwright checkpoint `user-audit` passes with axe green across all 3 projects; the `audit-explorer` mobile baseline is re-recorded deliberately as an intended delta; `admin-generated` parity lane stays green.

**Plans**: 5 plans
Plans:

**Wave 1**

- [x] 158-01-PLAN.md — Add shared `audit_row/1` (11th component) + unified `audit_tone/1` + reconciled `format_date/1` (D-09) with byte-goldens (AUDX-03, D-01, D-09, D-10)

**Wave 2** *(parallel — no file overlap; each touches one LiveView)*

- [x] 158-02-PLAN.md — `AuditIndexLive`: dual-layout (sg-show-desktop/mobile) + value-setting quick-filter chips + tone consolidation (AUDX-01, AUDX-02)
- [x] 158-03-PLAN.md — `AuditUserLive`: subject-scoped dual-layout + shared chrome (page_back/scope_ribbon/notice/empty_state/applied_chip) + chips + tone consolidation (AUDX-03)
- [x] 158-04-PLAN.md — `UserShowLive`: route "Recent Audit" through compact `audit_row/1`, retire old `audit_tone/1` (AUDX-03)

**Wave 3** *(blocked on Wave 2 — markup must be final before baselines)*

- [x] 158-05-PLAN.md — Playwright: new `user-audit` slug + deliberate `audit-explorer` ×3 re-record + conditional `user-detail` re-record + axe green ×3 + parity green (AUDX-01/02/03, GATE-01, GATE-02)

**UI hint**: yes

### Phase 159: Cross-Journey Coherence Sweep + Seed Enrichment

**Goal**: The full Platform Operator and Org Admin journeys are coherent end-to-end, seed data makes every screen self-demonstrating, and the motion usage audit is complete.
**Depends on**: Phase 158
**Requirements**: FIXT-01, FIXT-02, FIXT-03, FIXT-04, FIXT-05, GATE-03
**Success Criteria** (what must be TRUE):

  1. Seed data includes an expired Acme invitation (the "Expired" risk pill renders on the org overview), a deletion-scheduled member in an org roster, a passkey-only persona (no MFA), and richer audit event variety (password change, magic link, API token events, a second OAuth provider) — every previously-empty UI state now renders in the demo.
  2. Seed enrichment is deterministic (pinned `@seed_reference_ts`), idempotent (count-threshold and `on-conflict` guards updated in lockstep), and `MIX_ENV=test` guarded; running `Seeds.run/0` twice on a fresh DB produces identical counts.
  3. The motion usage audit is complete: keyboard-frequent interactions (⌘K result filtering, filter apply, row updates) have no animation; enters use ease-out; destructive actions use flat easing — verified by a keyboard-only session through the admin console.
  4. Empty-state spacing, notice/flash unification, focus/hover parity, back-nav round-trips, and `<.scope_ribbon>` presence are confirmed on all 6 screens via a scripted Playwright journey filmstrip.

**Plans**: 4 plans
Plans:

**Wave 1** *(parallel — no file overlap)*

- [x] 159-01-PLAN.md — Lib code fixes: deletion_scheduled? in detail.ex, roster pill + format_date in organization_live.ex, notice <p>→<div> in components.ex (FIXT-02)
- [x] 159-02-PLAN.md — New personas: pat (passkey-only) + grace (deletion-scheduled Acme) in personas.ex (FIXT-02, FIXT-03, FIXT-04, FIXT-05)

**Wave 2** *(blocked on Wave 1 — requires both lib code and persona definitions)*

- [x] 159-03-PLAN.md — Seed enrichment: expired invitation, grace membership, pat passkey, audit rows; seeds_test.exs assertions + snapshot_counts (FIXT-01, FIXT-02, FIXT-03, FIXT-04, FIXT-05)

**Wave 3** *(blocked on Wave 2 — verifies seeded demo DB states)*

- [x] 159-04-PLAN.md — CSS motion fix (sg-filter-chip pointer:fine guard) + admin-coherence-sweep.spec.ts filmstrip (GATE-03)

**Wave 4** *(gap closure — verification gaps_found 2026-06-04, closed 2026-06-05)*

- [x] 159-05-PLAN.md — GATE-03 closure: scope_ribbon emits sg-scope-ribbon + OrganizationLive ribbon call; discriminating static-CSS motion check; WR-01 NaiveDateTime guard; WR-04 transaction propagation (GATE-03)

**UI hint**: yes

### Phase 160: Regression Hardening + Baseline Ratification

**Goal**: All new and re-recorded baselines are ratified on a clean DB, all verification gates are formally closed, and the milestone is proven complete.
**Depends on**: Phase 159
**Requirements**: GATE-01, GATE-02
**Success Criteria** (what must be TRUE):

  1. All 3 new checkpoint slugs (`global-overview`, `org-overview`, `user-audit`) are ratified across chromium/mobile/dark with axe green — confirmed on a clean DB, not a dev DB with accumulated seed history.
  2. The `admin-generated` installer-parity lane is green across all phases that changed admin HEEx — confirmed by a final clean run proving templates mirror lib LiveViews (modulo namespace substitution).
  3. `admin-checkpoints-{chromium,mobile,dark}` passes cleanly; `demo-showcase` is green; no unintended baseline re-records exist in the committed PNG set.
  4. The component governance contract (Job→Component mapping, archetype compositions, when-NOT-to-use entries, ARIA specs) is committed and referenced from the repo.

**Plans**: TBD
**UI hint**: yes

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 150. Issue Triage & Bugfix Cadence | v1.33 | 1/1 | Complete | 2026-06-01 |
| 151. Ecosystem Sync & Hex Dependency Management | v1.33 | 1/1 | Complete | 2026-06-01 |
| 152. Strategic Bet Evaluation Gate | v1.33 | 1/1 | Complete | 2026-06-01 |
| 153. Infrastructure Stability & CI Hardening | v1.33 | 1/1 | Complete | 2026-06-02 |
| 154. Design Contract + sg-notice | v1.34 | 2/2 | Complete    | 2026-06-03 |
| 155. Shared Component Foundation (KEYSTONE) | v1.34 | 3/3 | Complete    | 2026-06-04 |
| 156. Adopt Shared Components on Baselined Screens | v1.34 | 6/6 | Complete    | 2026-06-04 |
| 157. Overview Landings (Highest Effort) | v1.34 | 4/4 | Complete    | 2026-06-04 |
| 158. Audit Mobile + Per-User Audit (High Effort) | v1.34 | 5/5 | Complete    | 2026-06-04 |
| 159. Cross-Journey Coherence Sweep + Seed Enrichment | v1.34 | 5/5 | Complete (6/6) | 2026-06-05 |
| 160. Regression Hardening + Baseline Ratification | v1.34 | 0/TBD | Not started | - |
