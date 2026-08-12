# Architecture Research

**Domain:** Layered first-party authentication and offline-client proof
**Researched:** 2026-08-12
**Confidence:** HIGH

## Ownership Architecture

```text
PWA / iOS / Android / Electron
               |
               v
Phoenix host routes and authorization
       |                     |
       v                     v
Sigra identity/session   Host lessons, media,
authority               leases, replay decisions
       |
       v
Crosswake auth projection -> route/runtime/offline policy

External registered clients -> Lockspire OAuth/OIDC AS
```

| Component | Responsibility |
|---|---|
| Sigra | Users, credentials, login ceremonies, browser/app sessions, MFA/passkeys, inbound providers, revocation, current identity scope |
| Lockspire | Registered external clients, consent, OAuth/OIDC codes and tokens, discovery, JWKS, delegation |
| Crosswake | Route ownership, offline-island vocabulary, account-partitioned journal/replay, activation and denial states |
| Phoenix host | Authorization, client profiles, product data, media/CDN, offline lease, storage policy, replay acceptance |

## App-Session Structure

- A logical app session represents one first-party client installation/session family.
- One-time authorization and MFA attempts are server records bound to client, callback, state, PKCE, account, expiry, and consumption state.
- Access and refresh credentials are random opaque values stored only as SHA-256 digests.
- Refresh happens in one database transaction: lock family, reject revoked/expired/reused state, consume the presented refresh token, and issue the next generation.
- Reuse of a consumed refresh token revokes the family. Existing short access credentials expire naturally or fail immediately when the configured verification posture checks family state.
- App-session authentication loads the current user and normal host Scope; credential metadata remains in `conn.private[:sigra_auth]`.

## Login Flows

### Hosted login

```text
App creates state + verifier
  -> system browser /auth/app/:client_id/start
  -> existing Sigra login, provider, passkey, MFA ceremonies
  -> explicit Continue to app
  -> callback receives one-time code + state
  -> app exchanges code + verifier
  -> opaque access + rotating refresh session
```

### Direct password login

```text
Opted-in app posts password
  -> uniform failure or opaque MFA challenge
  -> MFA completion when required
  -> same opaque app-session result
```

Provider-only or host-restricted accounts return `browser_required`; direct login never produces JWTs.

## Digital-Twin Flow

- PWA keeps Sigra's HttpOnly browser cookie and stores no auth tokens in JavaScript.
- The host issues an account-bound, expiring offline lease and immutable lesson/media manifest.
- Media installation verifies size and SHA-256 before atomic availability.
- Crosswake owns the offline-island/outbox vocabulary; the host owns answer schema, storage encryption, lease policy, and replay authorization.
- Reconnect revalidates Sigra authority before idempotent replay. Cached state never grants server authority.

## Integration Rules

- Consume released Crosswake coordinates from `test/example`; do not modify sibling repositories.
- Keep installer flags independent: browser is default; `--api`, `--jwt`, `--app-sessions`, and `--app-password-login` are explicit.
- Preserve compatibility for already-installed hosts through deprecation documentation, not automatic rewrites.

## Sources

- `guides/introduction/contract.md` and `guides/recipes/companion-oauth-provider.md`
- Lockspire `docs/supported-surface.md` and `docs/sigra-companion-host.md`
- Crosswake `.planning/FIRST-B2C-ADOPTER-ADOPTION-BRIEF.md`
- Crosswake `lib/crosswake/offline/contracts.ex`

---
*Architecture research for: v1.49 FIRST-PARTY-CLIENT-READINESS*

