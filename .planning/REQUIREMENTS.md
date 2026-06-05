# Requirements: Sigra — v1.34 ADMIN-UI-COHERENCE

**Defined:** 2026-06-03
**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Milestone goal:** Take the admin UI from "each screen polished individually" to one coherent, needs-led journey — principle of least surprise everywhere, "same job → same component."

## v1 Requirements

Requirements for this milestone. Each maps to exactly one roadmap phase.

### Shared Component Foundation (COMP)

- [x] **COMP-01**: A lib-owned `Sigra.Admin.Components` module provides the canonical admin component set (`stat_link`, `stat`, `task_card`, `summary_chip`, `applied_chip`, `empty_state`, `page_back`, `scope_ribbon`, `notice`, `skeleton`), each with documented `attr`/`slot` contracts.
- [x] **COMP-02**: The component extraction is behavior-preserving — the 5 existing admin checkpoint baselines (×3 projects) stay green with zero re-records, proven by rendered-markup equality before Playwright runs.
- [x] **COMP-03**: A committed "Job → Component" mapping plus 3 page archetypes (Overview / List / Detail) document the same-job→same-component conventions, including when-NOT-to-use, ARIA, and motion specs.
- [x] **COMP-04**: The one new `sg-notice` component style is added inside the existing `@layer sg-components` using existing tokens only (no new tokens or motion primitives).

### Needs-led Landing (LAND)

- [x] **LAND-01**: On both Overview landings, the needs-review alarm is the most prominent element above the task grid — loud when count > 0 (linking to the filtered risk view), "all clear" when 0.
- [x] **LAND-02**: Both Overviews lead with verb-first task cards; posture metrics are demoted to a secondary deep-link strip; the capability matrix is demoted to lowest priority.
- [x] **LAND-03**: The Global and Org overviews share a consistent visual rhythm and archetype (differing task counts are acceptable; layout and components are consistent).
- [x] **LAND-04**: Async overview data renders a loading skeleton instead of an empty flash or layout jump.

### Journey Coherence (COHR)

- [x] **COHR-01**: All 6 admin screens render via the shared components; no duplicated private `stat`/`task`/`chip`/`empty` defs remain.
- [x] **COHR-02**: The user-detail identity header uses the open `sg-page-header` archetype, consistent with the other screens (no boxed-card outlier).
- [x] **COHR-03**: A single back-nav component (consuming `return_to`) is used consistently on detail/leaf screens, with the breadcrumb handling hierarchy — one obvious way back.
- [x] **COHR-04**: A persistent in-body scope ribbon shows the current scope (Global vs org name) on every list and leaf screen.
- [x] **COHR-05**: Contextual alerts (summary alerts and flashes) render through the one shared `notice` component with consistent tone treatment.
- [x] **COHR-06**: Empty-state structure and spacing are consistent across all screens.

### Audit Screens (AUDX)

- [x] **AUDX-01**: The audit explorer (`AuditIndexLive`) has a mobile card layout mirroring the users-index dual-layout pattern, usable on small screens.
- [x] **AUDX-02**: The audit explorer gains quick-filter chips for common cases (e.g. outcome=failure, impersonation) consistent with the users-index filter idiom.
- [x] **AUDX-03**: Per-user audit (`AuditUserLive`) is reconciled with the explorer — shared components, shared filter idiom, mobile layout, and a shared audit-row presentation also used by the user-detail "recent audit" block.

### Seed Expression (FIXT)

- [ ] **FIXT-01**: Seed data includes an expired organization invitation so the "Expired" pill renders on the org overview.
- [ ] **FIXT-02**: Seed data places a deletion-scheduled user in an organization so the "Deletion scheduled" member state renders in the roster.
- [ ] **FIXT-03**: Seed data includes a passkey-only (no-MFA) user so that pill combination renders on the users index.
- [ ] **FIXT-04**: Audit seed data includes richer event variety (e.g. password change, magic link, API token, a second OAuth provider) so the audit explorer is self-demonstrating.
- [ ] **FIXT-05**: Seed enrichment stays deterministic (pinned reference timestamp) and idempotent (count-threshold / on-conflict guards updated in lockstep), test-env guarded, with no leakage into non-demo tests.

### Verification Gates (GATE)

- [x] **GATE-01**: New screenshot checkpoints (`global-overview`, `org-overview`, `user-audit`) are added across chromium/mobile/dark with axe (WCAG A/AA) gates.
- [ ] **GATE-02**: The `admin-generated` installer-parity lane stays green on every phase that changes admin HEEx (templates mirrored to `test/example/`).
- [x] **GATE-03**: Motion usage is audited — keyboard-frequent interactions (⌘K result filtering, filter apply, row updates) are not animated; enters use ease-out; destructive uses flat easing.

## v2 Requirements

Deferred to future work. Tracked but not in this roadmap.

### Future admin surfaces (ADMN)

- **ADMN-F1**: Net-new admin surfaces for currently-unsurfaced features (API-token management, service-account management). Deferred — out of scope this milestone (no net-new surfaces).
- **ADMN-F2**: Top-level navigation / IA restructure (persona-differentiated default views, user-detail tab restructure). Deferred — milestone keeps the Overview→List→Detail IA intact.
- **ADMN-F3**: Host-overridable admin component/section hook system (let adopters swap table↔cards or sidebar items without forking). Deferred — larger architectural change.

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| New admin screens / features | Locked: this is a coherence pass on the 6 existing screens, not feature expansion |
| Top-level nav restructure | The Overview→List→Detail IA is sound; restructuring is churn-risk and out of the locked scope |
| New design tokens / motion primitives | The `sg-*` token + motion layer is mature and Emil-Kowalski-compliant; this milestone audits *usage* (one `sg-notice` component style is the only CSS addition) |
| Tailwind / new JS framework / new runtime deps | Example app is `--no-tailwind`; coherence needs only Phoenix.Component + existing plain-JS hooks |
| Human UAT as a gate | Verification is automated-only (playwright admin-checkpoints + axe + admin-generated parity), per standing zero-human-UAT preference |
| `Phoenix.Ecto.SQL.Sandbox` for Playwright | Remains deferred per v1.33 — not reopened here |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| COMP-03 | Phase 154 | Complete |
| COMP-04 | Phase 154 | Complete |
| COMP-01 | Phase 155 | Complete |
| COMP-02 | Phase 155 | Complete |
| COHR-01 | Phase 156 | Complete |
| COHR-02 | Phase 156 | Complete |
| COHR-03 | Phase 156 | Complete |
| COHR-04 | Phase 156 | Complete |
| COHR-05 | Phase 156 | Complete |
| COHR-06 | Phase 156 | Complete |
| LAND-01 | Phase 157 | Complete |
| LAND-02 | Phase 157 | Complete |
| LAND-03 | Phase 157 | Complete |
| LAND-04 | Phase 157 | Complete |
| AUDX-01 | Phase 158 | Complete |
| AUDX-02 | Phase 158 | Complete |
| AUDX-03 | Phase 158 | Complete |
| FIXT-01 | Phase 159 | Pending |
| FIXT-02 | Phase 159 | Pending |
| FIXT-03 | Phase 159 | Pending |
| FIXT-04 | Phase 159 | Pending |
| FIXT-05 | Phase 159 | Pending |
| GATE-03 | Phase 159 | Complete |
| GATE-01 | Phase 160 | Complete |
| GATE-02 | Phase 160 | Pending |

**Coverage:**
- v1 requirements: 25 total
- Mapped to phases: 25/25 ✓
- Unmapped: 0

---
*Requirements defined: 2026-06-03*
*Last updated: 2026-06-03 — traceability populated by roadmapper (v1.34 ADMIN-UI-COHERENCE)*
