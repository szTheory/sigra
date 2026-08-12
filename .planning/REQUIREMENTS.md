# Requirements: Sigra v1.49 FIRST-PARTY-CLIENT-READINESS

**Defined:** 2026-08-12
**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

## v1.49 Requirements

### Product and Credential Boundaries

- [x] **BOUND-01**: A Phoenix adopter can determine from one normative contract whether Sigra, Lockspire, Crosswake, or the host owns each identity, session, delegation, runtime, authorization, media, lease, and replay concern.
- [x] **API-01**: A host can select explicit cookie-session, app-session, personal-access-token, or JWT authentication pipelines that load the normal current user Scope while keeping credential metadata separate and failing closed for incompatible scope checks.

### Personal Access Tokens and JWT

- [x] **PAT-01**: A fresh host generated with `--api` receives all schemas, migrations, configuration, Auth delegates, routes, and plugs required to create and authenticate with personal access tokens.
- [x] **PAT-02**: An authenticated user can list, create, and revoke only their own personal access tokens through CSRF-protected, recent-authenticated management operations with server-validated scopes.
- [x] **JWT-01**: A fresh host generated with `--jwt` receives an independently runnable advanced JWT configuration whose access tokens require the configured algorithm, type, issuer, audience, subject, issued-at, expiry, and identifier claims and validate not-before when present.
- [x] **JWT-02**: A host can issue server-scoped JWTs and atomically rotate/revoke opaque refresh-token families without exposing a generated password-to-JWT endpoint or accepting request-selected scopes.

### First-Party App Sessions

- [ ] **APP-01**: An adopter can independently opt into `--app-sessions` and the separately gated `--app-password-login`; `--api`, `--jwt`, and app-session generation do not imply one another.
- [ ] **APP-02**: A registered first-party app can authenticate through Sigra's existing hosted browser ceremonies using PKCE S256, state, an exact callback allowlist, explicit user continuation, a 60-second one-time code, and single-use exchange.
- [ ] **APP-03**: A host that opts into direct password login can authenticate a first-party app with uniform failures and an opaque five-minute MFA challenge, producing the same app session as hosted login or returning `browser_required` when host policy requires it.
- [ ] **APP-04**: A first-party app receives opaque digest-only credentials with 15-minute access, 30-day refresh-idle, and 90-day absolute defaults; refresh is atomic, rotates every use, and revokes the session family on consumed-token reuse.
- [ ] **APP-05**: A user or security event can revoke one app session or all applicable sessions, and password reset, account deletion, sign-out-all, explicit device revocation, and refresh reuse take effect on subsequent authentication.

### Language-Learning Digital Twin

- [ ] **TWIN-01**: The example PWA proves an authenticated lesson containing structured data, one image, and one audio asset while retaining Sigra's HttpOnly cookie session and exposing no app credentials to JavaScript or its service worker.
- [ ] **OFF-01**: The twin installs immutable media only after verifying expected size and SHA-256 and never reports corrupt or incomplete media as available.
- [ ] **OFF-02**: The twin proves an account-bound, host-configurable seven-day offline lease, account-partitioned cached state and outbox, logout/account-switch isolation, and explicit accepted/rejected/conflict exactly-once replay after backend reauthorization.

### Crosswake and Platform Proof

- [ ] **XW-01**: The example consumes released `crosswake` and `crosswake_sigra` packages and projects Sigra session authority into Crosswake route/replay decisions without passing credentials or making Crosswake an authentication authority.
- [ ] **NAT-01**: Automated physical-iPhone evidence proves hosted authentication, Keychain refresh storage, verified lesson/media availability, seven-day lease boundaries, offline audio, kill/relaunch persistence, logout/account switch, revocation, and exactly-once replay.
- [ ] **NAT-02**: Automated Android-emulator evidence proves the equivalent hosted authentication, Keystore-backed refresh storage, verified media, offline/relaunch, account isolation, revocation, and replay behavior.
- [ ] **DESK-01**: Contract tests define Electron's system-browser PKCE flow, allowed loopback callback behavior, main-process credential ownership, renderer isolation, and OS-backed `safeStorage` expectations without packaging an Electron application.
- [ ] **EVID-01**: Maintainers receive redacted machine-readable evidence and support documentation that distinguish contract-tested, emulator-tested, and physical-device-tested claims and fail closed when required proof is absent.

## Future Requirements

### Client Packaging

- **SDK-01**: Publish supported Swift and Kotlin client SDKs after first-adopter integration identifies stable platform abstractions.
- **SDK-02**: Package an Electron reference application after a desktop adopter requires runtime proof.
- **OFF-03**: Generalize additional offline islands or media/storage adapters after the bounded study flow demonstrates a repeated host need.

## Out of Scope

| Feature | Reason |
|---|---|
| OAuth/OIDC authorization-server behavior | Registered clients, consent, discovery, JWKS, delegation, and external access tokens belong to Lockspire. |
| Dynamic client registration or native client secrets | First-party app profiles are static public clients; compiled secrets are not authentication. |
| Product authorization, curricula, subscriptions, media/CDN policy, or replay business rules | These remain host-application concerns. |
| Generic offline sync, background sync, or media-cache framework | The milestone proves one bounded study island only. |
| Embedded WebView authentication | Native login uses the system browser and verified links/PKCE. |
| Published native SDKs or UI kits | This milestone ships server contracts, generated reference shells, and conformance evidence. |
| Packaged Electron application | Electron is contract-tested only. |
| Admin/operator UI changes | The milestone is credential-contract and adopter-proof work. |
| Sibling Lockspire or Crosswake source changes | Sigra consumes their released/public contracts without cross-repository mutation. |

## Traceability

| Requirement | Phase | Status |
|---|---:|---|
| BOUND-01 | Phase 243 | Complete |
| API-01 | Phase 243 | Complete |
| PAT-01 | Phase 244 | Complete |
| PAT-02 | Phase 244 | Complete |
| JWT-01 | Phase 244 | Complete |
| JWT-02 | Phase 244 | Complete |
| APP-01 | Phase 246 | Pending |
| APP-02 | Phase 246 | Pending |
| APP-03 | Phase 246 | Pending |
| APP-04 | Phase 245 | Pending |
| APP-05 | Phase 245 | Pending |
| TWIN-01 | Phase 247 | Pending |
| OFF-01 | Phase 247 | Pending |
| OFF-02 | Phase 247 | Pending |
| XW-01 | Phase 248 | Pending |
| NAT-01 | Phase 248 | Pending |
| NAT-02 | Phase 248 | Pending |
| DESK-01 | Phase 249 | Pending |
| EVID-01 | Phase 249 | Pending |

**Coverage:**

- v1.49 requirements: 19 total
- Mapped to phases: 19
- Unmapped: 0 ✓

---
*Requirements defined: 2026-08-12*
*Last updated: 2026-08-12 after Phase 243 completion*
