# Pitfalls Research

**Domain:** First-party Phoenix app authentication
**Researched:** 2026-08-12
**Confidence:** HIGH

## Critical Pitfalls

| Pitfall | Failure | Prevention | Phase |
|---|---|---|---|
| Credential shape autodetection | Prefixes accidentally select a different verifier or pipeline | Explicit `FetchAppSession`, `FetchAPIToken`, and `FetchJWT` pipelines | 243 |
| Broken generated contract | Installer emits routes whose required config, schemas, or delegates are missing | Full generator matrix and fresh-host runtime proof | 244/246 |
| Client-selected JWT scopes | Login request elevates its own authorization | Server policy is the only scope source | 244 |
| Password-to-JWT coupling | Credential ceremony becomes inseparable from token format | Direct password login returns the same opaque app session | 246 |
| Refresh race/reuse ambiguity | Two refreshes mint multiple live descendants or theft is missed | Transactional consume-and-rotate with family reuse revocation | 245 |
| Callback/login CSRF | Wrong app/account receives a session | Exact callback allowlist, PKCE S256, state, one-time attempt, explicit continuation | 246 |
| Scope struct overload | Credential scopes mutate the host's identity/authorization object | Store credential facts in `conn.private[:sigra_auth]` | 243 |
| Cached state treated as authority | Offline cache bypasses revocation or account change | Seven-day lease for local use only; backend reauthorization before replay | 247/248 |
| Cross-account cache/replay | Logout or switch exposes another learner's data | Account partitioning and fail-closed activation/replay | 247/248 |
| Inflated platform claims | Simulator/docs evidence is described as production support | Evidence classes for contract, emulator, and physical-device proof | 249 |

## Existing Defects Requiring Closure

1. Generated `api_authenticated` calls `FetchBearer` without required configuration and scope module.
2. `FetchBearer` constructs a host Scope using an incompatible map and token-only fields.
3. Generated API token context delegates are referenced but not emitted.
4. Generated PAT/JWT configuration is written under keys not consumed by `Sigra.Config` and omits required schema/enabled values.
5. JWT refresh generation omits the required user-token schema.
6. PAT create/revoke routes do not prove recent authentication, safe scope selection, or ownership.
7. JWT login accepts request-provided scopes.
8. Public API-auth documentation names return shapes and helpers that do not match implementation.
9. JWT verification does not consistently require issuer, audience, expiry, not-before, and token type.

## Security Verification Checklist

- [ ] Authorization codes, access tokens, refresh tokens, and MFA attempts are never logged raw.
- [ ] Refresh concurrency yields one winning descendant.
- [ ] Consumed-token reuse revokes the family and is audited.
- [ ] Exact redirects reject query/path/scheme/port mismatches except registered loopback port behavior.
- [ ] Password reset, account deletion, logout-all, and device revocation terminate applicable app sessions.
- [ ] JWT algorithms and required claims fail closed.
- [ ] PAT lifecycle operations are browser-session, CSRF, recent-auth, and ownership protected.
- [ ] Logout/account switch isolates local media, metadata, and outbox state.
- [ ] Replay always rechecks current backend authority.

## Sources

- Sigra source and generated templates audited 2026-08-12
- RFC 8252 and RFC 9700
- Crosswake support matrix and first-adopter brief

---
*Pitfalls research for: v1.49 FIRST-PARTY-CLIENT-READINESS*

