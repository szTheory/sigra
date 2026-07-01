# Requirements: Sigra — v1.42 ADMIN-DS-ELEVATION

**Defined:** 2026-06-28
**Core Value:** Authentication that works out of the box with great DX on the happy path AND on the rough edges.
**Milestone goal:** Elevate the generated admin/operator design system building-blocks-up to award-grade (Tier-2) across the whole fractal, governed by the existing forward-only monotonic guard, and add a reusable adversarial persona/JTBD judge instrument.

> **REQ-ID convention:** each milestone uses fresh category prefixes (per v1.39/v1.40/v1.41 precedent); numbering restarts at `01` per category. Tier vocabulary and proxy contract are defined in `guides/reference/admin-fractal-scorecard.md`; the ratchet target is `guides/reference/admin-quality-ledger.md`.

## v1 Requirements

### Instrument & Foundation (INSTR)

- [x] **INSTR-01**: A committed adversarial persona/JTBD rubric (`guides/reference/admin-persona-jtbd-rubric.md`) defines the 3 lenses (platform admin / support investigator / org admin, sourced from the demo personas), the fixed verdict questions (earning its place? / IA muddy? / redundant-coherent-least-surprising?), an ordinal `keep`/`tighten`/`kill` scale, and a fixed output schema — cross-referenced from the fractal scorecard and quality ledger.
- [x] **INSTR-02**: The dev-only `/admin/_design` gallery renders meta-component groups in real page configurations (`board-cfg-*` composites, not just isolated boards), registered in `admin-design.spec.ts` across chromium/mobile/dark and snapshot-clean.
- [x] **INSTR-03**: An up-front IA diagnostic runs the persona panel across all 8 admin pages and is committed (`.planning/v1.42-IA-DIAGNOSTIC.md`) to prioritize the component/group/page work.

### Fixtures (FIXT)

- [x] **FIXT-01**: Demo seed/persona data exercises the error/boundary/edge states the gallery and pages need (e.g. empty, long-string/UUID overflow, high-count, failed/warning status, permission-denied), segregated to the `@demo.tasklane.test` cohort with the `loadtest-` marker — without altering the golden-path `mix test` CI fixture.

### Component & Token Elevation (COMP)

- [x] **COMP-01**: The 8 highest-reuse L1 components (`notice`, `notice_link`, `stat`, `stat_link`, `summary_chip`, `task_card`, `applied_chip`, `audit_row`) meet Tier-2 on their own merit — full interaction states, motion-token conformance (no `transition: all`, `prefers-reduced-motion` strips movement), light/dark/system, documented target-size, on-brand microcopy, per-component axe clean across chromium/mobile/dark.
- [x] **COMP-02**: The 5 remaining L1 components (`empty_state`, `page_back`, `scope_ribbon`, `field_help`, `skeleton`) meet the same Tier-2 bar across the 3 projects.
- [x] **COMP-03**: The L0 token layer is elevated to Tier-2 with documented brand-token conformance (no raw hex/px outside `--sg-*` tokens; light/dark/system parity) and a refreshed `admin-token-reference.md` citation.

### Meta-Component Group Elevation (GROUP)

- [x] **GROUP-01**: All 11 L2 meta-component groups (MG-1…MG-11) meet Tier-2 on their isolated boards — intra-group single-tier rhythm, no accidental card-in-card, right-component-for-job, defined zero/loading/error states, byte-coherent reuse — across chromium/mobile/dark.
- [x] **GROUP-02**: Every group also passes in its real page configuration (`board-cfg-*`), with desktop↔mobile content-equivalence proven where the group has a table+mobile-card swap (MG-5/MG-6 equivalence assertions green).

### Page Judgment Pass (PAGE)

- [x] **PAGE-01**: The adversarial persona panel renders one committed scored review doc per surface (`.planning/uat-evidence/v1.42-persona-jtbd/<surface>.md`) for all 8 pages, each with 3-persona verdicts and a per-surface disposition (`clean`/`actionable`/`blocked`), indexed by a roll-up (`.planning/v1.42-PERSONA-JTBD-PANEL.md`).
- [x] **PAGE-02**: Judgment-level remediations (kill info-dump, redundant UI, verbosity; tighten IA) are applied across the pages — every actionable verdict is remediated with a diff or explicitly waived with rationale — with the monotonic guard green (no Tier-2 page regresses) and page baselines recaptured under allowlist→clear discipline.
- [x] **PAGE-03**: The `user-sessions` page is elevated to Tier-2 — overlay axe-clean + the 7 APG focus-trap/restore gates (it owns the confirm dialog) + glossary-clean microcopy + motion/density/target-size satisfied and cited.

### Persona Flow Elevation (FLOW)

- [x] **FLOW-01**: The 3 persona flows (`flow-platform-admin`, `flow-support-investigator`, `flow-org-admin`) are elevated to Tier-2 — each proves happy/error/boundary/edge paths, scope/return-context continuity, full keyboard operability, calm reduced-motion, and theme persistence, and cites its persona review doc as evidence.

### Terminal Ratification (GATE)

- [ ] **GATE-01**: Terminal ratification — every ledger cell reads Tier-2, `scripts/ci/quality-ledger-monotonic.sh --base origin/main` exits 0, all baselines recaptured with both allowlists empty and both canaries byte-stable, and compare-mode re-render shows zero PNG drift (idempotency proven).
- [ ] **GATE-02**: Installer↔example byte-parity + golden fixture stay green and generated-host parity is proven (fresh `phx.new` + `mix sigra.install` + admin-acceptance smoke renders the elevated styled admin); an adversarial milestone audit records the persona-JTBD verdicts as Tier-2 evidence.

## Future Requirements

Deferred unless a concrete adopter/security/product signal promotes them.

### Tooling

- **STORYBOOK-01**: Adopt PhoenixStorybook as the component-lab surface — deferred (dependency weight + host-app-friendliness; the in-repo `/admin/_design` gallery covers the need without a new dep).
- **JUDGE-CI-01**: Wire the persona panel as an automated CI gate — deferred (LLM non-determinism would make merges flaky; CI keeps the deterministic axe/APG/equivalence/glossary proxies).

## Out of Scope

| Feature | Reason |
|---------|--------|
| Net-new admin surfaces/pages | This milestone elevates the existing surface; "same job → same component", no new pages |
| New runtime/dev dependencies (incl. PhoenixStorybook) | Keep the library lean and host-app-friendly; deepen the existing gallery instead |
| Host-owned admin shell redesign | The shell (`admin_shell.ex`) is host-owned generated code; do not take it over |
| Changes to generated auth/email branding surface | Out of this milestone's admin/operator design-system scope |
| Persona judge as a merge-blocking CI gate | Non-deterministic; kept as a planning/review-time instrument feeding the manual Tier-2 assertion |
| Touching the golden-path `mix test` CI fixture data | All stress/edge data stays in the `@demo.tasklane.test` demo cohort |

## Traceability

Validated mapping — finalized in ROADMAP.md (2026-06-28). Phases continue from 204.

| Requirement | Phase | Status |
|-------------|-------|--------|
| INSTR-01 | Phase 205 | Complete |
| INSTR-02 | Phase 205 | Complete |
| INSTR-03 | Phase 205 | Complete |
| FIXT-01 | Phase 205 | Complete |
| COMP-01 | Phase 206 | Complete |
| COMP-02 | Phase 207 | Complete |
| COMP-03 | Phase 207 | Complete |
| GROUP-01 | Phase 208 | Complete |
| GROUP-02 | Phase 208 | Complete |
| PAGE-01 | Phase 209 | Complete |
| PAGE-02 | Phase 209 | Complete |
| PAGE-03 | Phase 210 | Complete |
| FLOW-01 | Phase 210 | Complete |
| GATE-01 | Phase 211 | Pending |
| GATE-02 | Phase 211 | Pending |

**Coverage:**

- v1 requirements: 15 total
- Mapped to phases: 15
- Unmapped: 0 ✓

---
*Requirements defined: 2026-06-28*
*Last updated: 2026-06-28 — traceability finalized by roadmapper; 15/15 mapped, 0 unmapped*
