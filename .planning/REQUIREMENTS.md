# Requirements — v1.48 B2C-ALPHA-READINESS

**Milestone goal:** Make SIGRA's single-user B2C authentication profile trustworthy before a first adopter host exists, with deterministic generator, browser, accessibility, and Crosswake session-boundary proof.

## Requirements

### Canonical B2C profile

- [ ] **B2C-01**: A fresh Phoenix app can install `--no-admin --no-organizations --no-passkeys`, migrate, build assets, compile with warnings as errors, and boot.
- [ ] **B2C-02**: That exact app can generate Google OAuth and contains its required routes, controller, identity, vault, and migration artifacts.
- [ ] **B2C-03**: The profile emits no admin, organization, or passkey routes/assets/configuration.

### Auth journey proof

- [x] **AUTH-01**: A generated B2C host browser suite proves registration, confirmation, email/password sign-in and logout, magic-link request/verification, and password reset completion.
- [x] **AUTH-02**: The same suite proves Google OAuth start/callback and account-link collision behavior with a deterministic provider double; no CI credential is required.
- [x] **AUTH-03**: Each rendered B2C auth state passes Axe and stable label/control and duplicate-ID checks.

### Crosswake interop

- [ ] **XW-01**: A backend-validated SIGRA personal-account session can project to `crosswake_sigra` without inventing an organization or exposing credentials/tokens.
- [ ] **XW-02**: Missing, expired, revoked, or account-switched session state fails closed for Crosswake replay; return data alone never grants access.

### Operations

- [ ] **OPS-01**: A provider-neutral alpha recipe specifies host origin, secure session, Google redirect, Cloak, rate-limit, and transactional-email rehearsal requirements.
- [ ] **OPS-02**: A no-secrets CI gate protects the canonical profile and its contract tests; real Google/email/iPhone proof is named as a host launch gate, not claimed by library CI.

## Traceability

| Requirement | Phase |
| --- | --- |
| B2C-01, B2C-02, B2C-03 | 237 |
| AUTH-01, AUTH-02, AUTH-03 | 238 |
| XW-01, XW-02 | 239 |
| OPS-01, OPS-02 | 240 |

## Out of Scope

Admin/operator UI, organization support, passkeys, MFA, native/deep-link auth tokens, and an adopter-specific application or device run.
