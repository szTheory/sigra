---
phase: 248-crosswake-native-proof
plan: "09"
subsystem: native-proof-host-prerequisite
tags: [phoenix, app-session, pkce, bearer, crosswake, learning-twin]
requires:
  - phase: 246
    provides: Hosted PKCE app-login and opaque app-session templates
  - phase: 247
    provides: Host-authoritative bounded lesson, media, lease, and replay policy
  - phase: 248-01
    provides: Fact-only native return and replay projection boundaries
provides:
  - Example-installed browser-only iOS and Android app-session profiles with exact callbacks
  - Hosted start, continuation, approval, cancellation, exchange, refresh, and browser-owner revocation routes
  - Bearer-authenticated native return, lesson, media, replay, and current-family logout routes
  - Fresh app-session token/family/user reload before Crosswake evaluation
  - Test-only device-reachable host bind and expanded credential parameter filtering
affects: [248-04, 248-06, NAT-01, NAT-02]
tech-stack:
  added: []
  patterns: [finite callback allowlist, digest-only opaque credentials, exact JSON 401 guard, server-selected route, proof-only network bind]
key-files:
  created:
    - test/example/lib/example/accounts/auth/app_sessions.ex
    - test/example/lib/example/accounts/first_party_apps.ex
    - test/example/lib/example/accounts/user_app_session_family.ex
    - test/example/lib/example/accounts/user_app_session_token.ex
    - test/example/lib/example/accounts/user_app_login_attempt.ex
    - test/example/lib/example_web/controllers/app_login_controller.ex
    - test/example/lib/example_web/controllers/native_proof_controller.ex
    - test/example/priv/repo/migrations/20260819000001_create_user_app_sessions.exs
    - test/example/test/example_web/controllers/native_proof_controller_test.exs
  modified:
    - test/example/lib/example/accounts.ex
    - test/example/lib/example/accounts/crosswake_session_adapter.ex
    - test/example/lib/example/accounts/crosswake_native_bridge.ex
    - test/example/lib/example_web/router.ex
    - test/example/lib/example_web/user_auth.ex
    - test/example/lib/example_web/controllers/session_controller.ex
    - test/example/lib/example_web/live/mfa_challenge_live.ex
    - test/example/config/config.exs
    - test/example/config/runtime.exs
key-decisions:
  - "Install Phase 246 into Example as a corrective proof-host integration, not a reusable product API or direct-password ceremony."
  - "Represent app-session assurance as :none with :app_session authentication facts because the opaque credential rows do not persist password or MFA assurance."
  - "Reject unknown native posture fields and server-select the only Crosswake return route before evaluation."
actuals:
  tokens: 46118
  tasks: 3
  commits: 9
duration: 12min
completed: 2026-08-28
status: complete
---

# Phase 248 Plan 09: Native Proof Host Prerequisite Summary

**The Example host now runs the shipped browser-only PKCE/app-session ceremony and exposes a fresh-authority bearer surface for the physical-iPhone and Android-emulator proof lanes.**

## Accomplishments

- Installed the current Phase 246 app-session schemas, auth-prefixed migration, finite profiles, facade, continuation, approval UI, controller, rate-limited routes, and supervised Hammer limiter into Example.
- Registered exactly `sigra-native-proof://auth/callback` for iOS and `sigra-native-proof://auth/android` for Android; both profiles are `:browser_required`, and no direct-password route exists.
- Added exact JSON-401 bearer authentication for native return, lesson bootstrap, image/audio media, replay, and logout. Current family and user ownership come only from trusted authentication state.
- Added a real Crosswake app-session path that reauthenticates the access credential and reloads its token, family, and user rows before fact projection. Superseded and revoked access never invokes the evaluator.
- Preserved the signed app-login continuation through session renewal, password/magic-link/passkey login, and current MFA completion surfaces.
- Added test/dev-only `0.0.0.0` binding behind `SIGRA_NATIVE_PROOF_HOST=1`, with configurable proof port and no production network/cookie relaxation.

## Task Commits

1. `db668c8b` — RED native proof host tests
2. `9ced2907` — Install app-session host and bearer proof surface
3. `c6d8d89e` — RED hosted ceremony and native return tests
4. `033d6b86` — Bind signing and native posture to exact host policy
5. `14da4404` — Routed browser approval proof
6. `418dc04f` — Preserve continuation through MFA and supervise rate limiting
7. `32e6dd58` — Fresh app-session Crosswake authority regression
8. `1d0d9901` — Scoped formatting and host-owned Hammer module
9. `2df296c5` — Expanded cancellation, media, replay-outcome, and renewal coverage

## Verification Evidence

- Example migration: `MIX_ENV=test mix ecto.migrate` — all migrations up.
- Proof environment: `SIGRA_NATIVE_PROOF_HOST=1 SIGRA_NATIVE_PROOF_PORT=4102 ...` — exact `0.0.0.0:4102`, server enabled.
- Focused native host suite — 11 tests passed.
- Fresh Crosswake native bridge suite — 6 tests passed.
- Combined Example controller/adapter/LearningTwin/session/UserAuth/MFA regression set — 47 tests passed, 26 tagged exclusions unchanged.
- Sigra app-login/app-session/FetchAppSession core regression set — 23 tests passed.
- P14/P17 authority, secret, embedded-browser, direct-password, and evidence-boundary checks — 6 tests passed.
- `MIX_ENV=test mix compile` — passed. The stricter warnings-as-errors variant remains blocked only by the pre-existing `SettingsLive` `/dev/mailbox` verified-route warning outside this slice.

## Security Boundaries Proven

- Wrong callback, wrong verifier, copied continuation, and exchanged-code replay fail closed.
- Missing, superseded, and revoked access credentials return bounded JSON 401 responses.
- Logout revokes only the current authenticated family; sibling and foreign families remain isolated.
- Accepted, rejected, and conflict replay outcomes are selected and persisted by the host.
- Native return input cannot select route, binding, account, or outcome, and retained Crosswake output contains no raw credential, family ID, or user ID.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Installed and supervised the generated Hammer limiter.**
- **Found during:** Routed browser approval proof
- **Issue:** The Example host did not have the Phase 246 generated rate-limiter module or supervision entry, so the new ceremony pipelines would fail open.
- **Fix:** Added `Example.RateLimit`, configured it as Sigra's Hammer module, supervised its ETS backend, and reran the routed proof without warnings.
- **Commit:** `418dc04f`, `1d0d9901`

**2. [Rule 2 - Missing Critical] Rejected unknown native return fields.**
- **Found during:** Native return RED test
- **Issue:** Projection could ignore extra client-provided route/outcome selectors instead of rejecting the request exactly.
- **Fix:** Enforced an exact six-field posture map and finite value allowlists before building released evidence.
- **Commit:** `033d6b86`

## Threat Flags

| Flag | File | Description |
|---|---|---|
| threat_flag: auth-path | `test/example/lib/example_web/router.ex` | Adds hosted app-login and explicit app-session bearer pipelines with dedicated rate limits and exact auth guard. |
| threat_flag: network-endpoint | `test/example/lib/example_web/controllers/native_proof_controller.ex` | Adds bounded native proof endpoints whose owner and family derive only from fresh trusted auth state. |

## Known Stubs

None.

## Requirement Status

This corrective prerequisite **enables but does not satisfy** NAT-01 or NAT-02. Both requirements remain pending until their physical-iPhone and pinned Android-emulator receipt-last lanes complete against this host.

## Self-Check: PASSED

- All 24 created/modified integration files exist.
- All nine task commits exist in repository history.
- The working tree contains no uncommitted Phase 248-09 source changes.
