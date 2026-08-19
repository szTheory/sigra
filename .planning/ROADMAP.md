# Roadmap: Sigra

**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

## Milestones

- ✅ **v1.48 B2C-ALPHA-READINESS** — Phases 237–242, shipped 2026-08-12 (`verified_closeout`; 10/10 requirements; 9 phases, 38 plans, 34 tasks) · [full detail](milestones/v1.48-ROADMAP.md)
- ✅ **v1.47 CI-EFFICIENCY** — Phases 230–236, shipped 2026-08-04 (`override_closeout`; 24/24 requirements) · [full detail](milestones/v1.47-ROADMAP.md)
- ✅ **v1.46 ADOPTER-EXPERIENCE** — Phases 224–229, shipped 2026-07-27 · [full detail](milestones/v1.46-ROADMAP.md)
- ⚠️ **v1.45 RELEASE-CURRENCY** — Phases 221–223, shipped 2026-07-11 (`override_closeout`) · [full detail](milestones/v1.45-ROADMAP.md)
- 📋 **v1.49 FIRST-PARTY-CLIENT-READINESS** — Phases 243–249, planned

## Phases

- [x] **Phase 243: Credential Boundary and Pipeline Foundation** - Define credential ownership and explicit, fail-closed authentication pipelines. (completed 2026-08-12)
- [x] **Phase 244: PAT and Advanced JWT Truth Repair** - Make independently generated PAT and advanced JWT contracts complete and trustworthy. (completed 2026-08-12)
- [x] **Phase 245: Opaque App-Session Core** - Deliver rotating opaque app sessions with durable revocation semantics. (completed 2026-08-12)
- [x] **Phase 246: Hosted and Direct Login Ceremonies** - Let explicitly opted-in first-party apps obtain the same secure app session through hosted or policy-gated direct login. (completed 2026-08-16)
- [ ] **Phase 247: Language-Learning Digital Twin** - Prove the bounded PWA lesson, verified media, and account-isolated offline behavior.
- [ ] **Phase 248: Crosswake Native Proof** - Prove the shared contract through released Crosswake packages, a physical iPhone, and Android emulator.
- [ ] **Phase 249: Desktop Contract and Milestone Closure** - Define the Electron boundary and make support claims evidence-backed and fail-closed.

## Phase Details

### Phase 243: Credential Boundary and Pipeline Foundation

**Goal**: Phoenix adopters can choose a credential contract with clear ownership and receive a normal user Scope without credential confusion.
**Depends on**: Nothing (first phase)
**Requirements**: BOUND-01, API-01
**Success Criteria** (what must be TRUE):

  1. An adopter can consult one normative contract to identify whether Sigra, Lockspire, Crosswake, or the host owns each listed identity, session, delegation, runtime, authorization, media, lease, and replay concern.
  2. A host can explicitly select cookie-session, app-session, PAT, or JWT authentication and receives the normal current-user Scope for each supported selection.
  3. Credential metadata remains distinct from the current-user Scope, and an incompatible credential/scope combination is rejected rather than accepted ambiguously.

**Plans**: 5/5 plans executed

Plans:

- [x] 243-01-PLAN.md — Trace PAT authentication through live-user Scope construction and trusted scope enforcement.
- [x] 243-02-PLAN.md — Add explicit JWT authentication and the fail-closed app-session Plug foundation.
- [x] 243-03-PLAN.md — Load full browser-session users with struct and legacy Scope compatibility.
- [x] 243-04-PLAN.md — Convert FetchBearer into a deprecated deterministic compatibility dispatcher.
- [x] 243-05-PLAN.md — Ratify and machine-lock the ownership and explicit-pipeline documentation contract.

### Phase 244: PAT and Advanced JWT Truth Repair

**Goal**: Adopters can independently generate and safely use the PAT and advanced JWT capabilities Sigra presents.
**Depends on**: Phase 243
**Requirements**: PAT-01, PAT-02, JWT-01, JWT-02
**Success Criteria** (what must be TRUE):

  1. A fresh `--api` host can create and authenticate personal access tokens using its generated schemas, migrations, configuration, delegates, routes, and plugs.
  2. A recently authenticated user can list, create, and revoke only their own PATs through CSRF-protected operations, while the server validates token scopes.
  3. A fresh `--jwt` host can independently issue and validate advanced JWT access tokens only when their required configured claims and optional not-before claim are valid.
  4. A host can issue server-scoped JWTs and atomically rotate or revoke refresh-token families without a generated password-to-JWT endpoint or request-selected scopes.

**Plans**: 7/7 plans executed

Plans:

- [x] 244-07-PLAN.md

- [x] 244-01-PLAN.md — Split API/JWT generator contracts and lock four-combination idempotent emission.
- [x] 244-02-PLAN.md — Enforce owner-bound PAT revocation and server-side scope allowlists.
- [x] 244-03-PLAN.md — Deliver browser/CSRF/sudo PAT management and prove a fresh API-only host.
- [x] 244-04-PLAN.md — Enforce the complete advanced-JWT signer, header, and registered-claim contract.
- [x] 244-05-PLAN.md — Prove host-policy JWT issuance in an independent fresh JWT-only host.
- [x] 244-06-PLAN.md — Serialize refresh rotation/reuse in one audit-on/off transaction with concurrency proof.

### Phase 245: Opaque App-Session Core

**Goal**: First-party apps can hold opaque, rotating credentials whose lifecycle is bounded and reliably revocable.
**Depends on**: Phase 243
**Requirements**: APP-04, APP-05
**Success Criteria** (what must be TRUE):

  1. A first-party app receives only digest-backed opaque credentials with 15-minute access, 30-day refresh-idle, and 90-day absolute defaults.
  2. Refreshing an app session is atomic and rotates the credential every time; reuse of a consumed refresh credential revokes its session family.
  3. A user can revoke one app session or all applicable sessions, and the revoked credentials fail on their next authentication attempt.
  4. Password reset, account deletion, sign-out-all, explicit device revocation, and refresh reuse each invalidate applicable app sessions on subsequent authentication.

**Plans**: 8/8 plans executed

Plans:

- [x] 245-08-PLAN.md

- [x] 245-01-PLAN.md — Trace digest-only issuance and authentication through representative host schemas.
- [x] 245-02-PLAN.md — Activate the explicit FetchAppSession Scope/private-facts boundary.
- [x] 245-03-PLAN.md — Implement locked every-use refresh rotation and reuse-family revocation.
- [x] 245-04-PLAN.md — Prove audit co-fate, rollback, and deterministic concurrent refresh.
- [x] 245-05-PLAN.md — Add owner-constrained one/all app-session revocation facades.
- [x] 245-06-PLAN.md — Integrate password reset and sign-out-all invalidation.
- [x] 245-07-PLAN.md — Integrate account-deletion invalidation transactionally.

### Phase 246: Hosted and Direct Login Ceremonies

**Goal**: An adopter can independently opt into first-party app sessions and let apps securely obtain them through hosted browser or policy-gated direct login.
**Depends on**: Phase 245
**Requirements**: APP-01, APP-02, APP-03
**Success Criteria** (what must be TRUE):

  1. A fresh host can independently choose `--app-sessions` and `--app-password-login`; generating `--api`, `--jwt`, or one app feature never silently enables another.
  2. A registered first-party app can complete hosted system-browser login with PKCE S256, state, an exact callback allowlist, explicit continuation, and a single-use code that expires within 60 seconds.
  3. A host that opts into direct password login receives uniform login failures and an opaque MFA challenge that expires within five minutes.
  4. Successful hosted or direct login creates the same app-session contract, while a host policy requiring browser login returns `browser_required`.

**Plans**: 19/19 plans executed

Plans:
**Wave 1**

- [x] 246-01-PLAN.md — Trace atomic hosted code exchange into Phase 245 app-session issuance.
- [x] 246-06-PLAN.md — Add the independent app-session/password-login generator option matrix.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 246-02-PLAN.md — Validate static profiles, exact callbacks, state, PKCE S256, and explicit continuation.

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 246-03-PLAN.md — Prove hosted exchange locking, replay, expiry, audit co-fate, concurrency, and faults.
- [x] 246-07-PLAN.md — Generate host schemas, migration, static profiles, config, and issuance delegates.

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 246-04-PLAN.md — Implement policy-gated direct password login and opaque five-minute MFA challenges.

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 246-05-PLAN.md — Prove direct-login uniformity, replay, locking, concurrency, and rollback behavior.

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 246-08-PLAN.md — Generate real hosted/direct routes, continuation transport, and explicit approval UI.

**Wave 7** *(blocked on Wave 6 completion)*

- [x] 246-09-PLAN.md — Preserve hosted continuation through controller and LiveView login/MFA branches.

**Wave 8** *(blocked on Wave 7 completion)*

- [x] 246-10-PLAN.md — Prove fresh-host install/rerun/runtime parity and lock scope/ownership documentation.

**Wave 9** *(blocked on Wave 8 completion)*

- [x] 246-11-PLAN.md — Repair typed hosted approval and require completed browser assurance through a fresh-host tracer.

**Wave 10** *(blocked on Wave 9 completion)*

- [x] 246-12-PLAN.md — Carry an allowlisted direct-MFA factor and prove generated backup-code success.

**Wave 11** *(blocked on Wave 10 completion)*

- [x] 246-13-PLAN.md — Prove replay rejection and FetchAppSession authentication for both generated ceremonies.

**Wave 12** *(blocked on Wave 11 completion; plans may run in parallel)*

- [x] 246-14-PLAN.md — Rotate persisted MFA-pending browser sessions before hosted approval resumes.
- [x] 246-15-PLAN.md — Make signed hosted approval continuations transactionally single-use.

**Wave 13** *(blocked on Plan 246-15)*

- [x] 246-16-PLAN.md — Propagate the unique approval digest into generated storage and prove concurrent approval.

**Wave 14** *(blocked on Plans 246-14 and 246-16)*

- [x] 246-17-PLAN.md — Execute and retain exact PostgreSQL CI evidence for the repaired ceremony contract.

**Wave 15** *(gap closure; both plans depend on Plan 246-17 and may run in parallel)*

- [x] 246-18-PLAN.md — Gate generated TOTP and backup-code verification on an authoritative MFA-pending browser session.
- [x] 246-19-PLAN.md — Make hosted cancellation atomically terminal for copied and concurrently used continuations.

### Phase 246.1: Close gap: PAT-01 — repair generated PAT authentication pipeline (INSERTED)

**Goal:** A fresh `--api` host authenticates real personal access tokens through its generated explicit PAT pipeline with normal Scope projection and bounded credential facts.
**Requirements**: TBD
**Depends on:** Phase 246
**Plans:** 1/1 plans complete

Plans:

- [x] 246.1-01-PLAN.md — Repair generated PAT options and prove real routed fresh-host authentication.

### Phase 246.2: Close gaps: APP-04 and APP-05 — generated refresh and revocation surfaces (INSERTED)

**Goal:** A fresh app-session host exposes secure generated HTTP refresh and owner-derived one/all revocation routes whose rotation, replay-family revocation, owner isolation, and next-auth denial are proven by receipt-last PostgreSQL evidence.
**Requirements**: APP-04, APP-05
**Depends on:** Phase 246
**Success Criteria** (what must be TRUE):

  1. A first-party client can rotate a refresh credential through a public rate-limited generated route without browser or access-token authentication and receives only the committed four-field credential response.
  2. Consumed-refresh replay returns one bounded unauthenticated failure, revokes only its session family, and denies that family's replacement access credential on its next generated-route authentication.
  3. A recently authenticated browser user can revoke one owned family or all applicable owned families through CSRF-protected JSON mutations whose owner is derived only from current Scope; foreign families remain unchanged.
  4. A twice-installed disposable PostgreSQL host proves routed rotation, replay, one/all revocation, owner isolation, and next-auth denial before atomically publishing a credential-free, exact-source-bound receipt.

**Plans:** 7/7 plans complete

Plans:

**Wave 1**

- [x] 246.2-01-PLAN.md — Ship generated refresh/revocation routes and prove a real routed refresh tracer.

**Wave 2** *(depends on Plan 246.2-01)*

- [x] 246.2-02-PLAN.md — Prove refresh replay, owner-safe one/all revocation, and seal v4 receipt-last evidence.

**Wave 3** *(depends on Plan 246.2-02)*

- [x] 246.2-03-PLAN.md — Reject stale canonical evidence and retain one exact-head v4 PostgreSQL proof artifact with matching provenance.

**Wave 4** *(depends on Plan 246.2-03)*

- [x] 246.2-04-PLAN.md — Separate generated direct-login and refresh limiter budgets.

**Wave 5** *(depends on Plan 246.2-04)*

- [x] 246.2-05-PLAN.md — Prove direct-budget exhaustion cannot block refresh replay revocation.

**Wave 6** *(depends on Plan 246.2-05)*

- [x] 246.2-06-PLAN.md — Fail-close run URL, artifact name, and immutable implementation reference.

**Wave 7** *(depends on Plan 246.2-06)*

- [x] 246.2-07-PLAN.md — Publish fresh exact-head v5 runtime evidence.

### Phase 247: Language-Learning Digital Twin

**Goal**: The example PWA demonstrates a bounded, account-safe offline lesson experience without treating cached data as authentication authority.
**Depends on**: Phase 246
**Requirements**: TWIN-01, OFF-01, OFF-02
**Success Criteria** (what must be TRUE):

  1. An authenticated learner can use a lesson with structured data, one image, and one audio asset while the PWA keeps the Sigra session HttpOnly and exposes no app credentials to JavaScript or its service worker.
  2. The PWA marks media available only after its expected size and SHA-256 verify, never presenting corrupt or incomplete media as ready for offline use.
  3. A learner can use a host-configured seven-day offline lease, and cached lesson state and outbox data remain partitioned to that account across logout or account switch.
  4. When the learner reconnects, replay is backend-reauthorized and each queued action is explicitly recorded as accepted, rejected, or conflicted exactly once.

**Plans**: 4/6 plans executed

Plans:
**Wave 1**

- [x] 247-01-PLAN.md — Trace one authenticated lesson through verified install, offline study, and accepted replay.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 247-02-PLAN.md — Close every immutable-media corruption, interruption, write-failure, and orphan-cache path.
- [x] 247-03-PLAN.md — Enforce exact lease expiry and current-account partition boundaries.

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 247-04-PLAN.md — Persist current-Scope-authorized accepted, rejected, and conflict outcomes exactly once.
- [ ] 247-05-PLAN.md — Prove partition-first offline practice across expiry, logout, account switch, themes, and small viewports.

**Wave 4** *(blocked on Wave 3 completion)*

- [ ] 247-06-PLAN.md — Reconcile terminal receipt UI and seal complete source-bound automated evidence.

### Phase 248: Crosswake Native Proof

**Goal**: The same first-party session and offline contract is demonstrated through Crosswake, a physical iPhone, and an Android emulator without granting companion runtimes authentication authority.
**Depends on**: Phase 247
**Requirements**: XW-01, NAT-01, NAT-02
**Success Criteria** (what must be TRUE):

  1. The example uses released `crosswake` and `crosswake_sigra` packages to project Sigra session facts into Crosswake route and replay decisions without passing credentials or making Crosswake an authentication authority.
  2. Automated physical-iPhone evidence proves hosted login, Keychain refresh storage, verified offline lesson/media and audio, seven-day lease boundaries, relaunch persistence, account isolation, revocation, and exactly-once replay.
  3. Automated Android-emulator evidence proves the equivalent hosted login, Keystore-backed refresh storage, verified media, offline/relaunch behavior, account isolation, revocation, and replay outcomes.

**Plans**: TBD

### Phase 249: Desktop Contract and Milestone Closure

**Goal**: Maintainers can support the bounded first-party client contract with explicit Electron rules and evidence that never overstates platform proof.
**Depends on**: Phase 248
**Requirements**: DESK-01, EVID-01
**Success Criteria** (what must be TRUE):

  1. Contract tests define an Electron system-browser PKCE flow with only allowed loopback callbacks, main-process credential ownership, renderer isolation, and OS-backed `safeStorage` expectations.
  2. The milestone does not package an Electron application while still making its supported desktop boundary executable and testable.
  3. Maintainers receive redacted machine-readable evidence and support guidance that distinguish contract-tested, emulator-tested, and physical-device-tested claims.
  4. A missing required proof artifact causes the associated readiness claim to fail closed rather than being reported as supported.

**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 243. Credential Boundary and Pipeline Foundation | 5/5 | Complete    | 2026-08-12 |
| 244. PAT and Advanced JWT Truth Repair | 7/7 | Complete    | 2026-08-12 |
| 245. Opaque App-Session Core | 8/8 | Complete    | 2026-08-12 |
| 246. Hosted and Direct Login Ceremonies | 19/19 | Complete    | 2026-08-16 |
| 247. Language-Learning Digital Twin | 4/6 | In Progress|  |
| 248. Crosswake Native Proof | 0/TBD | Not started | - |
| 249. Desktop Contract and Milestone Closure | 0/TBD | Not started | - |
