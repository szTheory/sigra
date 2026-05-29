# Requirements: Sigra — v1.31 DEMO-SHOWCASE

**Defined:** 2026-05-29
**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Milestone goal:** Turn `test/example/` into double-duty adopter proof + click-around evaluator showcase — a one-command, seed-populated realistic SaaS that lets an evaluator experience every auth/account feature without setup. This is the unbuilt remainder of v1.29 SUITE-INTEGRATION's deferred "reference starter app"; it extends `test/example/`, not a new repo.

**Research basis:** `.planning/research/SUMMARY.md` (HIGH confidence; grounded in direct repo inspection on `v1.28-data-lifecycle` HEAD). Faker rejected for determinism; deterministic demo-only TOTP secret accepted behind the `Mix.env()==:test` seed guard; 6-persona roster; firm ordering seeds → Playwright → screenshots → README.

## v1 Requirements

Requirements for this milestone. Each maps to exactly one roadmap phase (phases continue from 141).

### Seed Data Layer (SEED)

- [ ] **SEED-01**: Evaluator runs `mix setup` in `test/example/` and gets a fully-populated demo database in one command; re-running is idempotent (no errors, no duplicate rows).
- [ ] **SEED-02**: Six personas are seeded, each demonstrating a distinct auth state — admin (TOTP MFA + multi-org + API token + passkey display row), standard confirmed user, MFA-enrolled org owner, OAuth-linked user, locked user, and scheduled-deletion user.
- [ ] **SEED-03**: Seeded data exercises the rough edges — TOTP enrollment, a locked account, an OAuth identity, a scheduled deletion, and multi-org membership including a pending invitation — not just the happy path.
- [ ] **SEED-04**: The seeded audit log shows realistic variety (6–8 distinct event types) so the admin audit explorer reads as a real, in-use system.
- [ ] **SEED-05**: Demo seeds stay isolated from the CI-fixture role — dev/test database separation, a `Mix.env()==:test` raise-guard in `seeds.exs`, and `@demo.sigra.dev` (seeded) vs `@example.test` (golden-path) email-domain segregation — so `mix test` stays deterministic.
- [ ] **SEED-06**: The demo preserves Sigra's production security posture — real Argon2id hashing at a safe dev cost, no committed real secrets (the demo-only TOTP secret is clearly labeled demo-only), and enumeration/rate-limit protections left unchanged.

### Evaluator Affordances (DEMO)

- [ ] **DEMO-01**: Evaluator can open a dev-only credentials cheat-sheet (`/demo/credentials`) listing each persona, its login, and the auth feature it demonstrates; the route is present in dev and absent in test/prod.
- [ ] **DEMO-02**: The example app presents a realistic SaaS framing (app name / layout) so the demo reads as a real product rather than a bare scaffold.

### Visual Proof & Browser Coverage (PW)

- [ ] **PW-01**: A Playwright demo spec exercises the seeded personas' auth states using structural assertions (`data-testid` / auth-state, not brittle persona-name matching), in its own Playwright project partition, leaving the golden-path specs unaffected.
- [ ] **PW-02**: Evaluator-facing screenshots are captured via the existing Playwright capture infrastructure, covering key surfaces (login, admin user list, audit log, MFA, organization switcher).
- [ ] **PW-03**: A seeds-smoke check proves the seeds are idempotent and each persona's auth state is verifiable, guarding CI against seed/schema drift.

### Evaluator Documentation (DOC)

- [ ] **DOC-01**: The README has a "Try it locally" evaluator lane — prerequisites, the one-command spin-up, a credentials table, and rough-edge persona callouts.
- [ ] **DOC-02**: A guide page (`guides/introduction/demo-showcase.md`) walks an evaluator through the demo with embedded screenshots.
- [ ] **DOC-03**: A milestone proof bundle confirms the full test suite is green, the dependency-off lane is green, the `mix setup` one-command spin-up works from a clean state, and screenshots are committed/rendered.

## Future Requirements

Deferred to a post-milestone polish cycle. Tracked, not in this roadmap.

### Evaluator Affordances (DEMO)

- **DEMO-03**: In-app per-persona explainer banner (dev-only) describing the active persona's auth state in context. Deferred because it is the only affordance touching new LiveView code beyond the credentials page; the credentials cheat-sheet (DEMO-01) covers the core need.

## Out of Scope

Explicitly excluded. Documented to prevent scope creep. Anti-features carried from `MILESTONE-ARC.md` non-goals and the research.

| Feature | Reason |
|---------|--------|
| Separate standalone demo repo | Phase 114 already paid the nested-app-drift cost; the arc mandates extending `test/example/`. |
| Marketing site / landing page | The demo is an evaluator funnel, not product marketing; out of library scope. |
| CSS framework or React/component library | Aesthetics belong to the adopter (Diminishing Returns Wall). |
| Generic / reusable seeding framework | The milestone seeds one app's personas, not a framework; ~30 lines of find-or-create, not a library. |
| Host-app domain data beyond auth legibility | Seed only what makes auth/account features legible (arc non-goal). |
| Faker / any non-deterministic data generation | Determinism is mandatory — the demo doubles as a CI fixture and Playwright asserts on it. |
| Weakening Argon2id / enumeration / rate-limit for the demo | The demo must demonstrate the exact security posture Sigra ships to production. |
| Greenfield SCIM directory sync | Deprioritized below DEMO-SHOWCASE and the subsequent 1.0 adoption push (already an ENT-SSO non-goal; needs a concrete adopter need). |

## Traceability

Which phases cover which requirements. Populated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SEED-01 | Phase 141 | Pending |
| SEED-02 | Phase 141 | Pending |
| SEED-03 | Phase 141 | Pending |
| SEED-04 | Phase 141 | Pending |
| SEED-05 | Phase 141 | Pending |
| SEED-06 | Phase 141 | Pending |
| DEMO-01 | Phase 142 | Pending |
| DEMO-02 | Phase 142 | Pending |
| PW-01 | Phase 143 | Pending |
| PW-02 | Phase 143 | Pending |
| PW-03 | Phase 143 | Pending |
| DOC-01 | Phase 144 | Pending |
| DOC-02 | Phase 144 | Pending |
| DOC-03 | Phase 144 | Pending |

**Coverage:**
- v1 requirements: 14 total
- Mapped to phases: 14 (roadmap complete)
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-29*
*Last updated: 2026-05-29 — traceability filled by roadmapper (v1.31 DEMO-SHOWCASE, Phases 141–144)*
