# Phase 246: Hosted and Direct Login Ceremonies — Context

**Gathered:** 2026-08-12
**Status:** Ready for planning

## Phase Boundary

Deliver independently generated first-party app-session support and two ways
for a public first-party client to obtain the Phase 245 credential contract:
hosted system-browser login and separately opted-in direct password/MFA login.
This is not an OAuth/OIDC authorization server and does not change Lockspire,
Crosswake, native SDKs, the PWA twin, or Electron packaging.

## Locked Decisions

- `--app-sessions` is independent of `--api` and `--jwt`.
  `--app-password-login` is a separate opt-in that depends on app sessions but
  is never implied by them.
- First-party app profiles are static public-client policy records. They may
  have identifiers, exact callback allowlists, and login policy; compiled
  client secrets are not authentication.
- Hosted login uses the system browser, state, PKCE S256, a literal exact
  callback allowlist (including literal loopback ports only when registered),
  explicit user continuation, a 60-second one-time code, and atomic
  single-use exchange.
- Centralize the signed/opaque continuation so controller, LiveView, and MFA
  branches preserve the same bounded state and return path.
- Direct login is a first-party host feature, not an OAuth password grant. It
  uses uniform failures and never reveals whether user/password/MFA/policy was
  the failing dimension.
- Direct MFA challenges are opaque, digest-only, profile/user bound, single
  use, and expire within five minutes.
- Host policy may require hosted browser login; direct attempts then return
  `browser_required` without authenticating or issuing credentials.
- Hosted and direct success both call `Sigra.AppSession.issue/4`; there is no
  second token/session lifecycle.
- One-time code/challenge consumption, issuance, and optional audit share one
  PostgreSQL transaction with row locking. Replacement credentials return only
  after commit. Concurrency tests use barriers, never sleeps.

## Scope Fence

- No OAuth/OIDC authorization server, consent, discovery, JWKS, dynamic client
  registration, external delegated access tokens, or Lockspire source change.
- No embedded WebView login, native SDK, mobile runtime, PWA/offline/media,
  Crosswake, or Electron runtime implementation.
- No request-selected scopes or authority, plaintext codes/challenges at rest,
  wildcard callbacks, callback normalization tricks, or client secrets.
- No admin/operator UI.

## Agent Discretion

- Exact module/schema/controller names and JSON response shapes.
- Whether static app profiles are config-only or host-schema-backed, provided
  lookup is server-owned and no dynamic registration is introduced.
- The narrowest generated UI/controller composition that proves explicit
  continuation across password and MFA without redesigning existing auth UI.

## Success Evidence

- Four-combination generator source contracts plus fresh-host install/rerun,
  migration, compile, and runtime proof.
- Hosted happy path and deny/replay/expiry/callback/state/PKCE/concurrency/fault
  matrix through real generated routes.
- Direct password/MFA/browser-required/uniform-failure/replay/expiry/fault
  matrix through real generated routes.
- Both ceremonies produce credentials accepted by `FetchAppSession`; no other
  optional credential feature appears unless explicitly selected.

