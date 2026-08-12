---
gsd_state_version: 1.0
milestone: v1.49
milestone_name: FIRST-PARTY-CLIENT-READINESS
current_phase: 244
current_phase_name: PAT and Advanced JWT Truth Repair
status: verifying
stopped_at: Completed 244-06-PLAN.md
last_updated: "2026-08-12T23:48:58.765Z"
last_activity: 2026-08-12
last_activity_desc: Completed Phase 244 Plan 01 independent PAT/JWT generator contracts
progress:
  total_phases: 2
  completed_phases: 2
  total_plans: 11
  completed_plans: 11
current_plan: 2
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-08-12)

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Current focus:** Phase 244 — PAT and Advanced JWT Truth Repair

## Current Position

Phase: 244 of 249 (PAT and Advanced JWT Truth Repair)
Plan: 6 of 6
Status: Phase complete — ready for verification
Last activity: 2026-08-12 — Completed Phase 244 Plan 01 independent PAT/JWT generator contracts

Progress: ░░░░░░░░░░ [██████████] 100%

## Performance Metrics

**Velocity:**

- Total plans completed: 6
- Average duration: 4min
- Total execution time: 4min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 243–249 | 1 | 4min | 4min |
| 243 | 5 | - | - |
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

### Pending Todos

None yet.

### Blockers/Concerns

- Physical-iPhone proof in Phase 248 requires deterministic device automation and redacted evidence; do not overstate emulator or contract evidence as physical-device proof.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Client packaging | Native SDKs, an Electron reference app, and generalized offline behavior await concrete adopter evidence. | Deferred | v1.49 definition |

## Session Continuity

Last session: 2026-08-12T23:48:58.759Z
Stopped at: Completed 244-06-PLAN.md
Resume file: None
