# Roadmap: Sigra

**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

## Milestones

- 🚧 **v1.48 B2C-ALPHA-READINESS** — Phases 237–240 (active; 10 requirements mapped)
- ✅ **v1.47 CI-EFFICIENCY** — Phases 230–236, shipped 2026-08-04 (`override_closeout`; 24/24 requirements; 14 global planning artifacts deferred) · [full detail](milestones/v1.47-ROADMAP.md)
- ✅ **v1.46 ADOPTER-EXPERIENCE** — Phases 224–229, shipped 2026-07-27 · [full detail](milestones/v1.46-ROADMAP.md)
- ⚠️ **v1.45 RELEASE-CURRENCY** — Phases 221–223, shipped 2026-07-11 (`override_closeout`) · [full detail](milestones/v1.45-ROADMAP.md)

## v1.48 B2C-ALPHA-READINESS

**Goal:** Make the canonical single-user Phoenix authentication profile mechanically trustworthy for a first B2C adopter: email/password and magic links plus Google OAuth, a hosted iPhone return, and a fail-closed Crosswake session boundary.

### Phases

- [x] **Phase 237: Canonical B2C Generator Contract** — Fresh Phoenix profile with admin, organizations, and passkeys disabled; Google OAuth generation, migration, compilation, and boot proof. **Requirements:** B2C-01, B2C-02, B2C-03. (completed 2026-08-04)
- [x] **Phase 238: Generated Auth Runtime Proof** — Deterministic browser and accessibility coverage for the B2C email and Google journeys. **Requirements:** AUTH-01, AUTH-02, AUTH-03. (completed 2026-08-08)
- [x] **Phase 239: Hosted Session Interop** — Prove the SIGRA-to-Crosswake backend-session adapter, personal-account scope, return evidence boundary, and fail-closed replay. **Requirements:** XW-01, XW-02. (completed 2026-08-10)
- [x] **Phase 240: Alpha Operations Rehearsal** — Provider-neutral email/OAuth preflight and no-secrets launch gate. **Requirements:** OPS-01, OPS-02. (completed 2026-08-10)

## Phase Details

### Phase 237: Canonical B2C Generator Contract

**Goal:** Prove a fresh Phoenix host can generate the canonical personal-account B2C profile with Google OAuth while excluding admin, organizations, and passkeys.

**Depends on:** None

**Requirements:** B2C-01, B2C-02, B2C-03

**Success Criteria:**

1. The canonical no-admin/no-organizations/no-passkeys host installs, migrates, builds assets, compiles with warnings as errors, and boots.
2. Google OAuth generation emits its required routes, controller, identity, vault, and migration artifacts.
3. Generated output contains no admin, organization, or passkey surfaces.

### Phase 238: Generated Auth Runtime Proof

**Goal:** Establish deterministic browser and accessibility proof for the generated B2C email and Google authentication journeys without provider credentials.

**Depends on:** Phase 237

**Requirements:** AUTH-01, AUTH-02, AUTH-03

**Success Criteria:**

1. Browser coverage proves registration, confirmation, password sign-in and logout, magic-link request/verification, and password-reset completion in a generated B2C host.
2. A deterministic provider double proves Google OAuth start, callback, and account-link collision behavior without CI credentials.
3. Every rendered B2C auth state passes Axe plus stable label/control and duplicate-ID checks.

### Phase 239: Hosted Session Interop

**Goal:** Prove the fail-closed SIGRA-to-Crosswake backend-session boundary for personal accounts.

**Depends on:** Phase 238

**Requirements:** XW-01, XW-02

**Plans:** 7/7 plans complete

Plans:
**Wave 1**

- [x] 239-00-PLAN.md — Reproduce the public Crosswake successor tests at its immutable release SHA and record machine-readable proof.
- [x] 239-01-PLAN.md — Verify the independently published Crosswake successor and its immutable release provenance.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 239-02-PLAN.md — Trace one fresh personal SIGRA session through the released Crosswake evaluator.

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 239-03-PLAN.md — Expand fail-closed currentness, revocation, and expiry behavior.

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 239-04-PLAN.md — Bind replay to session, subject, and version and deny account switching.

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 239-05-PLAN.md — Keep hosted-return data evidence-only and align the B2C recipe.

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 239-06-PLAN.md — Seal the phase with bounded exact-SHA automated evidence.

**Success Criteria:**

1. A backend-validated personal-account session can project to `crosswake_sigra` without creating organization scope or exposing credentials or tokens.
2. Missing, expired, revoked, or account-switched state fails closed, and return data alone cannot grant access.

### Phase 240: Alpha Operations Rehearsal

**Goal:** Deliver a provider-neutral, no-secrets launch-readiness gate for the canonical B2C profile.

**Depends on:** Phase 239

**Requirements:** OPS-01, OPS-02

**Plans:** 5/5 plans complete

Plans:
**Wave 1**

- [x] 240-05-PLAN.md — Create all four executable Nyquist Wave 0 contract artifacts before Plans 01-04.
- [x] 240-01-PLAN.md — Trace explicit generated Hammer ownership through one bounded B2C POST path.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 240-02-PLAN.md — Expand independent route/context limiting and seal generated golden parity.
- [x] 240-03-PLAN.md — Publish and contract-test the three-tier provider-neutral launch checklist.
- [x] 240-04-PLAN.md — Enforce separate credential-free CI lanes and truthful evidence claims.

**Success Criteria:**

1. The alpha recipe specifies host-origin, secure-session, Google redirect, Cloak, rate-limit, and transactional-email rehearsal requirements.
2. CI proves the canonical profile and contract tests use no secrets, while real Google, email, and iPhone proof remains explicitly a host launch gate.

### Explicitly Deferred

Admin/operator UI, organizations, passkeys, MFA, native/deep-link token authority, billing, and physical-device/product-host evidence are outside this library milestone. A real iPhone and production provider rehearsal remains a host launch gate once the adopter application exists.

### Phase 240.3: Close gap: XW-01/XW-02 — wire hosted Crosswake runtime flow (INSERTED)

**Goal:** Make the already-proven personal-session Crosswake adapter reachable through a deterministic example-host request/session, one-time continuation, evaluator, and safe response flow without widening Sigra core or generated-host scope.
**Requirements:** XW-01, XW-02
**Depends on:** Phase 240
**Plans:** 5 plans

Plans:
**Wave 1**

- [ ] 240.3-01-PLAN.md — Trace one authenticated host start/return through the existing adapter and a digest-only Ecto continuation.

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 240.3-02-PLAN.md — Harden one-time claim, expiry, replay/race isolation, cleanup, and persisted-field redaction.

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 240.3-03-PLAN.md — Prove the complete real-router switch, smuggling, recovery, evaluator non-invocation, and telemetry matrix.

**Wave 4** *(blocked on Wave 3 completion)*

- [ ] 240.3-04-PLAN.md — Drive one deterministic real-cookie-jar browser journey and prove clean final navigation.

**Wave 5** *(blocked on Wave 4 completion)*

- [ ] 240.3-05-PLAN.md — Guard the copyable contract and emit receipt-last exact-SHA runtime evidence.

### Phase 240.1: Repair canonical B2C OAuth recipe handoff (INSERTED)

**Goal:** Make the documented canonical B2C install-to-Google-OAuth sequence executable with the host-owned `cloak_ecto` prerequisite.
**Requirements**: B2C-02, OPS-01
**Depends on:** Phase 240
**Plans:** 0 plans

Plans:

- [x] 240.1-01: Document and lock the host-owned OAuth dependency handoff

### Phase 240.2: Close gap: OPS-01 — add controller-mode generated-host compile proof (INSERTED)

**Goal:** Close the OPS-01 controller-limiter integration gap with a distinct credential-free fresh `--no-live` B2C host that compiles warning-free, migrates, boots, and passes bounded readiness while the canonical LiveView lane remains unchanged.
**Requirements**: TBD
**Depends on:** Phase 240
**Plans:** 1/1 plans complete

Plans:

- [x] 240.2-01-PLAN.md — Add and contract-lock the controller-mode generated-host compile/boot tracer.

### Phase 241: Close gap: OPS-01 — repair controller MFA settings rendering

**Goal:** [To be planned]
**Requirements**: TBD
**Depends on:** Phase 240
**Plans:** 0 plans

Plans:

- [ ] TBD (run $gsd-plan-phase 241 to break down)
