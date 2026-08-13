# Phase 245: Opaque App-Session Core — Context

**Gathered:** 2026-08-12
**Status:** Ready for planning
**Source:** v1.49 milestone decisions, APP-04/APP-05, and Phase 245 research

## Phase Boundary

Phase 245 delivers the library-owned credential lifecycle beneath first-party
mobile, PWA, Crosswake, and future Electron clients. It does not expose a login
ceremony or installer flag yet; Phase 246 owns `--app-sessions`, hosted PKCE,
direct password/MFA policy, generated schemas/migrations, and HTTP endpoints.

## Locked Decisions

### Credential model

- App access and refresh credentials are opaque random values and only digests
  are persisted.
- Use a dedicated app-session family and immutable credential/token rows. Do
  not overload browser sessions, PATs, or JWT refresh-token JSON metadata.
- Defaults are 15 minutes for access, 30 days refresh-idle, and 90 days
  absolute family lifetime. Expiry is enforced at authentication/refresh time.
- A bounded server-selected first-party app/client reference may be stored for
  lifecycle and operator context; it is not a client secret or authority input.

### Authentication and rotation

- Activate the explicit `FetchAppSession` seam from Phase 243. Every request
  rechecks the credential row and family for digest match, expiry, revocation,
  and user existence before constructing normal host Scope.
- Keep credential metadata in `conn.private[:sigra_auth]`; never put raw
  credentials or credential authority into host Scope.
- Refresh uses one PostgreSQL transaction with row locking, classification,
  rotation/reuse mutation, and optional audit co-fate. Raw replacement
  credentials are returned only after commit.
- Every successful refresh consumes the presented refresh token and issues a
  new access/refresh pair. Reuse of a consumed refresh token revokes the entire
  family before returning a bounded reuse error.
- Concurrency proof must use deterministic barriers/locks and no sleeps: one
  rotation winner, one serialized reuse result, deterministic revoked family.

### Revocation

- Provide owner-constrained single-device/family revocation and all-app-session
  revocation.
- Password reset, account deletion, sign-out-all, explicit device revocation,
  and refresh reuse invalidate the applicable app sessions on the next auth.
- Security-event revocation joins the existing business operation transaction
  where that operation is transactional; do not create a best-effort gap.

## Agent Discretion

- Exact library module/function names and internal schema field names.
- Whether access and refresh credentials share one token table with a typed
  purpose or use separate tables, provided immutable rows and digest-only
  persistence remain mechanically proven.
- Error atom names and bounded private metadata shape, consistent with Phase
  243 explicit plug conventions.
- Test fixture organization and the narrowest reusable transaction helpers.

## Scope Fence

- No password exchange, MFA challenge, authorization code, PKCE, callback,
  browser continuation, or app registration endpoint.
- No generator flag, generated host schema/migration/controller, native SDK,
  PWA/offline/media behavior, Crosswake behavior, Electron runtime, OAuth/OIDC
  authorization server, Lockspire change, or admin/operator UI.
- No plaintext access or refresh credential at rest, in audit metadata, or in
  logs; no replacement credential returned after rollback.

## Success Evidence

- PostgreSQL-backed lifecycle tests cover defaults, authentication, idle and
  absolute expiry, atomic rotation, rollback, reuse-family revocation, and
  barrier-controlled concurrency.
- Integration tests prove single/all and each named security event revokes the
  intended app sessions without broadening unrelated session semantics.
- Existing browser, PAT, and JWT credential paths remain green and independent.

