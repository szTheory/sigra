---
gsd_state_version: 1.0
milestone: v1.49
milestone_name: FIRST-PARTY-CLIENT-READINESS
current_phase: 246.2
current_phase_name: close-gaps-app-04-and-app-05-generated-refresh-and-revocatio
status: executing
stopped_at: Completed 246.2-03-PLAN.md
last_updated: "2026-08-18T15:35:54.499Z"
last_activity: 2026-08-17
last_activity_desc: Phase 246.2 execution started
progress:
  total_phases: 6
  completed_phases: 6
  total_plans: 43
  completed_plans: 43
current_plan: 3
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-08-16)

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Current focus:** Phase 246.2 — close-gaps-app-04-and-app-05-generated-refresh-and-revocatio

## Current Position

Phase: 246.2 (close-gaps-app-04-and-app-05-generated-refresh-and-revocatio) — EXECUTING
Plan: 3 of 3
Status: Phase plans complete; verification pending
Last activity: 2026-08-18 — Final v4 runtime evidence retained

Progress: [██████████] 100%

## Performance Metrics

**Velocity:**

- Total plans completed: 41
- Average duration: 4min
- Total execution time: 4min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 243–249 | 1 | 4min | 4min |
| 243 | 5 | - | - |
| 244 | 7 | - | - |
| 245 | 8 | - | - |
| 246 | 19 | - | - |
| 246.1 | 1 | - | - |
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 243-credential-boundary-and-pipeline-foundation P01 | 4min | 2 tasks | 5 files |
| Phase 243 P02 | 8min | 2 tasks | 4 files |
| Phase 243-credential-boundary-and-pipeline-foundation P03 | 4min | 1 tasks | 3 files |
| Phase 243 P04 | 6min | 1 tasks | 2 files |
| Phase 243 P05 | 3min | 1 tasks | 4 files |
| Phase 244 P01 | 2min | 1 tasks | 4 files |
| Phase 244-pat-and-advanced-jwt-truth-repair P02 | 6min | 1 tasks | 3 files |
| Phase 244 P03 | 50min | 2 tasks | 6 files |
| Phase 244 P04 | 3min | 1 tasks | 5 files |
| Phase 244 P05 | 16min | 1 tasks | 5 files |
| Phase 244 P06 | 12min | 1 tasks | 10 files |
| Phase 244-pat-and-advanced-jwt-truth-repair P07 | 3min | 1 tasks | 4 files |
| Phase 245-opaque-app-session-core P01 | 14min | 1 tasks | 4 files |
| Phase 245-opaque-app-session-core P02 | 10min | 1 tasks | 3 files |
| Phase 245-opaque-app-session-core P03 | 5min | 1 tasks | 3 files |
| Phase 245-opaque-app-session-core P04 | 17min | 2 tasks | 4 files |
| Phase 245-opaque-app-session-core P05 | 4min | 1 tasks | 3 files |
| Phase 245-opaque-app-session-core P06 | 25min | 2 tasks | 3 files |
| Phase 245 P07 | 5min | 1 tasks | 3 files |
| Phase 245-opaque-app-session-core P08 | 4min | 1 tasks | 3 files |
| Phase 246-hosted-and-direct-login-ceremonies P06 | 4min | 1 tasks | 4 files |
| Phase 246 P01 | 13min | 1 tasks | 5 files |
| Phase 246-hosted-and-direct-login-ceremonies P02 | 16min | 1 tasks | 6 files |
| Phase 246 P03 | 13min | 2 tasks | 2 files |
| Phase 246 P07 | 5min | 3 tasks | 8 files |
| Phase 246 P04 | 15m | 2 tasks | 4 files |
| Phase 246 P05 | 18m | 2 tasks | 4 files |
| Phase 246 P08 | 6m | 2 tasks | 9 files |
| Phase 246 P09 | 6m | 1 tasks | 6 files |
| Phase 246 P10 | 12m | 2 tasks | 6 files |
| Phase 246 P11 | 12m | 2 tasks | 7 files |
| Phase 246-hosted-and-direct-login-ceremonies P12 | 20m | 2 tasks | 7 files |
| Phase 246 P13 | 18m | 2 tasks | 3 files |
| Phase 246-hosted-and-direct-login-ceremonies P14 | 14m | 2 tasks | 3 files |
| Phase 246 P15 | 12m | 2 tasks | 6 files |
| Phase 246-hosted-and-direct-login-ceremonies P16 | 12m | 2 tasks | 3 files |
| Phase 246-hosted-and-direct-login-ceremonies P17 | 10m | 2 tasks | 5 files |
| Phase 246-hosted-and-direct-login-ceremonies P18 | 12m | 1 tasks | 2 files |
| Phase 246-hosted-and-direct-login-ceremonies P19 | 18m | 2 tasks | 7 files |
| Phase 246.1-close-gap-pat-01-repair-generated-pat-authentication-pipelin P01 | 16min | 2 tasks | 6 files |
| Phase 246.2 P01 | 4min | 2 tasks | 5 files |
| Phase 246.2-close-gaps-app-04-and-app-05-generated-refresh-and-revocatio P02 | 7min | 3 tasks | 4 files |
| Phase 246.2 P03 | 15m | 2 tasks | 4 files |

## Accumulated Context

### Decisions

- v1.49 separates browser sessions, PATs, advanced JWTs, and opaque first-party app sessions; credential pipelines must be explicit and fail closed.
- Sigra owns first-party authentication; Lockspire owns OAuth/OIDC delegation; Crosswake consumes projected session facts but never owns credentials or authentication authority.
- Native login is system-browser PKCE by default. Direct password/MFA login is separately opt-in; no generated password-to-JWT endpoint or client-selected authority.
- The language-learning twin is intentionally bounded: account-isolated, lease-limited media and replay proof, not a generic offline framework or published SDK.
- Platform claims must identify their evidence class (contract, emulator, or physical device) and fail closed when required proof is absent.
- [Phase 243]: Explicit PAT/JWT verification reloads the live user and stores only bounded private credential facts.
- [Phase 243]: RequireScopes authorizes only verified PAT/JWT metadata, never Scope-shaped fields or session identity.
- [Phase 243]: FetchAppSession remains a fail-closed public pipeline seam until Phase 245 adds verifier and storage.
- [Phase 243]: Generated Scope structs use Sigra.Scope.build/3 while only non-struct scopes use legacy new/1.
- [Phase 243]: FetchBearer is deprecated compatibility-only dispatch; primary documentation selects explicit credential-kind pipelines.
- [Phase 243]: The normative four-owner contract assigns first-party auth to Sigra, delegation to Lockspire, projected runtime facts to Crosswake, and authorization/media/lease/replay policy to the host.
- [Phase 244]: API selection emits only PAT artifacts and FetchAPIToken; JWT selection emits only JWT artifacts and FetchJWT.
- [Phase 244]: Generated JWT issuance is host policy through Auth.JWT, never a password/MFA exchange or request-selected scopes.
- [Phase ?]: Self-service PAT revocation requires the owner and normalizes foreign, missing, and revoked token outcomes.
- [Phase ?]: Empty PAT scope sets are allowed; non-empty selections are duplicate-checked and registry-validated in the library.
- [Phase ?]: PAT browser lifecycle proof uses real generated router gates and owner row-set invariants.
- [Phase ?]: JWT verification uses the configured Joken signer and RequiredClaims before protected typ inspection.
- [Phase ?]: Configured audiences match exact scalar or non-empty string-array recipients; optional nbf stays temporal only.
- [Phase ?]: Generated JWT router options resolve host config at request time to avoid compile-time endpoint access.
- [Phase ?]: JWT-only hosts install Joken and issue tokens through Sigra.JWT.generate_tokens/4 with generated UserToken storage.
- [Phase ?]: JWT refresh classification, rotation/reuse revoke, replacement insertion, and optional audit now share one FOR UPDATE transaction; replacement credentials return only after commit.
- [Phase ?]: JWT-only installation remains API-schema-free and documents only host-policy Auth.JWT issuance.
- [Phase ?]: Phase 244 installer inventory is an exact sorted 56-entry contract including independently shipped JWT and no-LiveView templates.
- [Phase ?]: PAT post-install guidance names the generated browser/sudo management route /users/api-tokens.
- [Phase 245]: App sessions use dedicated family and typed token rows rather than JWT metadata storage.
- [Phase 245]: App-session configuration requires paired host schemas and access_ttl < refresh_idle_ttl <= absolute_ttl.
- [Phase ?]: FetchAppSession accepts exactly one Bearer transport and invokes only Sigra.AppSession.authenticate/2.
- [Phase ?]: App-session facts expose only kind, credential ID, family ID, empty scopes, method, and assurance; client references and credential material remain excluded.
- [Phase ?]: App-session refresh locks the exact typed digest row before lifecycle classification.
- [Phase ?]: Consumed refresh reuse revokes the indexed family and all credential rows before returning :reuse_detected.
- [Phase ?]: App-session refresh audit is an optional step in the same lifecycle Multi, with bounded family/action metadata and post-commit telemetry only.
- [Phase ?]: App-session concurrent refresh proof uses real PostgreSQL locks and explicit barriers; one caller rotates and the second revokes the family for reuse.
- [Phase ?]: App-session family selectors are bound to the trusted owner ID in a locked active-family lookup, normalizing foreign, absent, and terminal selectors.
- [Phase ?]: append_revoke_all_multi/4 performs lifecycle mutation only so security-event callers compose their existing audit in the same outer transaction.
- [Phase ?]: Password reset composes configured app-session revoke-all in its existing Ecto.Multi before audit; sign-out-all fails closed before browser deletion.
- [Phase ?]: Account deletion scheduling appends configured app-session revocation to its existing transaction before hooks.
- [Phase ?]: [Phase 245]: Formatter-only closure is supported by exact formatter, diff-check, and focused APP-04/APP-05 evidence; unrelated full-suite CI failures remain non-green baseline diagnostics.
- [Phase ?]: App sessions, direct password login, API, and JWT remain independent installer selections; direct password login requires explicit app-session selection.
- [Phase ?]: App-session migration timestamps are Runner-owned and allocated in family, token, and ceremony order.
- [Phase ?]: Hosted attempt consumption, optional audit, and Phase 245 issuance execute in one Ecto.Multi transaction.
- [Phase ?]: Raw access and refresh material remains only in Ecto.Multi changes until the outer transaction commits.
- [Phase ?]: Hosted codes retain only the S256 challenge digest, never a PKCE verifier.
- [Phase ?]: Every authenticated browser must explicitly approve before code persistence.
- [Phase ?]: Hosted-code concurrency proof asserts the result multiset and persisted state, never a winner identity.
- [Phase ?]: Hosted exchange audit records only action, attempt ID, profile ID, and family ID in the issuance transaction.
- [Phase ?]: Generated app-session state uses one host-owned migration with binary IDs, auth-prefix support, cascading FKs, unique digests, and lifecycle indexes.
- [Phase ?]: First-party profiles remain finite module data with literal callback strings; direct adapters are emitted only when app-password-login is selected.
- [Phase ?]: Direct password login evaluates static browser-required policy before invoking host password verification.
- [Phase ?]: Direct MFA stores only a decoded-token digest and trusted binding facts, then consumes and issues in one transaction.
- [Phase ?]: Direct MFA completion persists bounded audit facts in the same transaction as challenge consumption and app-session issuance.
- [Phase ?]: Direct-MFA audit telemetry emits only after the outer transaction commits.
- [Phase ?]: Hosted browser state persists only as a bounded signed continuation handle through normal session renewal.
- [Phase ?]: Approval and cancellation are separate CSRF-protected POST decisions in the existing sigra-auth shell.
- [Phase ?]: Valid browser continuations resume only through the existing explicit approval controller after normal authentication.
- [Phase ?]: MFA-pending sessions retain the signed continuation until successful verification; invalid handles clear to ordinary auth.
- [Phase ?]: Fresh-host app-login evidence uses a disposable Phoenix host, bounded HTTP readiness, and a receipt-last SHA contract.
- [Phase ?]: Hosted and separately opted-in direct login issue the same FetchAppSession-verified opaque session; neither changes OAuth/OIDC ownership.
- [Phase ?]: Hosted approval persists :hosted_code and only completed standard or remember-me sessions may approve.
- [Phase ?]: Generated direct MFA decodes only literal totp and backup_code selectors before fixed callback forwarding.
- [Phase ?]: Generated direct login derives MFA-required state from host MFA status without changing browser authentication normalization.
- [Phase ?]: Generated-host runtime proof authenticates both hosted and direct credentials through a temporary FetchAppSession route and proves replay rejection without duplicate families.
- [Phase ?]: Generated runtime proof receipt v2 is atomically written last with per-transition booleans and exact source SHA-256 bindings, which CI validates before upload.
- [Phase ?]: Selected LiveView MFA factor forms POST through the existing CSRF-protected controller seam so persisted session rotation remains server-authoritative.
- [Phase ?]: Hosted approval continuations carry a signed nonce whose digest is uniquely persisted with the hosted code in one transaction.
- [Phase ?]: Generated approval-digest indexes use user_app_login_attempts_approval_digest_index so replay normalization stays stable across adapters and prefixes.
- [Phase ?]: Use typed persisted-family assertions instead of captured Mix output for generated-host policy proof.
- [Phase ?]: Retain byte-identical redacted CI receipt bound to immutable implementation head 62d22419.
- [Phase ?]: MFA factor verification accepts only the same persisted :mfa_pending row bound to the current scope user, then passes that row to the existing completion seam.
- [Phase ?]: Approve and cancel contend on the same nonce-derived approval_digest; the cancel row digest remains domain-separated storage identity only.
- [Phase ?]: Cancellation is terminal at commit time and clears the generated browser continuation only after its durable claim succeeds.
- [Phase ?]: Generated PAT configuration is resolved at request time, matching FetchJWT.
- [Phase ?]: Unauthenticated API requests return JSON 401 while browser redirects retain flash behavior.
- [Phase ?]: Refresh reuses the existing public rate limiter and delegates only to Auth.AppSessions.refresh/1.
- [Phase ?]: Generated revocation mutations derive owner only from current Scope under browser/sudo/CSRF.
- [Phase ?]: The final APP-04/APP-05 proof uses scripts/db/up.sh plus tmp/db.env for its isolated dynamic PostgreSQL endpoint.
- [Phase ?]: The v4 receipt is atomically published only after all generated lifecycle flags pass and source hashes validate.
- [Phase ?]: Canonical runtime evidence accepts only exact v4 receipt/provenance pairs through the same fail-closed validator as fixtures.
- [Phase ?]: Run 32154454396 is the sole authorized final workflow_dispatch, bound to immutable implementation head 139959b66af452e71d56e5fe1b32285f92909ec6.

### Pending Todos

None yet.

### Blockers/Concerns

- Physical-iPhone proof in Phase 248 requires deterministic device automation and redacted evidence; do not overstate emulator or contract evidence as physical-device proof.

### Roadmap Evolution

- Phase 246.1 inserted after Phase 246: Close gap: PAT-01 — repair generated PAT authentication pipeline (URGENT)
- Phase 246.2 inserted after Phase 246: Close gaps: APP-04 and APP-05 — generated refresh and revocation surfaces (URGENT)

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Client packaging | Native SDKs, an Electron reference app, and generalized offline behavior await concrete adopter evidence. | Deferred | v1.49 definition |

## Session Continuity

Last session: 2026-08-18T15:35:54.487Z
Stopped at: Completed 246.2-03-PLAN.md
Resume file: None
