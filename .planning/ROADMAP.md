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
- [ ] **Phase 238: Generated Auth Runtime Proof** — Deterministic browser and accessibility coverage for the B2C email and Google journeys. **Requirements:** AUTH-01, AUTH-02, AUTH-03.
- [ ] **Phase 239: Hosted Session Interop** — Prove the SIGRA-to-Crosswake backend-session adapter, personal-account scope, return evidence boundary, and fail-closed replay. **Requirements:** XW-01, XW-02.
- [ ] **Phase 240: Alpha Operations Rehearsal** — Provider-neutral email/OAuth preflight and no-secrets launch gate. **Requirements:** OPS-01, OPS-02.

### Explicitly Deferred

Admin/operator UI, organizations, passkeys, MFA, native/deep-link token authority, billing, and physical-device/product-host evidence are outside this library milestone. A real iPhone and production provider rehearsal remains a host launch gate once the adopter application exists.
