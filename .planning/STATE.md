---
gsd_state_version: 1.0
milestone: v1.49
milestone_name: FIRST-PARTY-CLIENT-READINESS
current_phase: 243
current_phase_name: Credential Boundary and Pipeline Foundation
status: verifying
stopped_at: Completed 243-05-PLAN.md
last_updated: "2026-08-12T19:55:42.258Z"
last_activity: 2026-08-12
last_activity_desc: Plan 243-01 completed; explicit PAT pipeline and trusted scope boundary committed.
progress:
  total_phases: 1
  completed_phases: 1
  total_plans: 5
  completed_plans: 5
current_plan: 2
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-08-12)

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Current focus:** Phase 243 — Credential Boundary and Pipeline Foundation

## Current Position

Phase: 243 of 249 (Credential Boundary and Pipeline Foundation)
Plan: 5 of 05
Status: Phase complete — ready for verification
Last activity: 2026-08-12 — Plan 243-01 completed; explicit PAT pipeline and trusted scope boundary committed.

Progress: ░░░░░░░░░░ [██████████] 100%

## Performance Metrics

**Velocity:**

- Total plans completed: 1
- Average duration: 4min
- Total execution time: 4min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 243–249 | 1 | 4min | 4min |
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 243-credential-boundary-and-pipeline-foundation P01 | 4min | 2 tasks | 5 files |
| Phase 243 P02 | 8min | 2 tasks | 4 files |
| Phase 243-credential-boundary-and-pipeline-foundation P03 | 4min | 1 tasks | 3 files |
| Phase 243 P04 | 6min | 1 tasks | 2 files |
| Phase 243 P05 | 3min | 1 tasks | 4 files |

## Accumulated Context

### Decisions

- v1.49 separates browser sessions, PATs, advanced JWTs, and opaque first-party app sessions; credential pipelines must be explicit and fail closed.
- Sigra owns first-party authentication; Lockspire owns OAuth/OIDC delegation; Crosswake consumes projected session facts but never owns credentials or authentication authority.
- Native login is system-browser PKCE by default. Direct password/MFA login is separately opt-in; no generated password-to-JWT endpoint or client-selected authority.
- The language-learning twin is intentionally bounded: account-isolated, lease-limited media and replay proof, not a generic offline framework or published SDK.
- Platform claims must identify their evidence class (contract, emulator, or physical device) and fail closed when required proof is absent.
- [Phase ?]: Explicit PAT verification reloads the live user and stores only bounded private credential facts.
- [Phase ?]: RequireScopes authorizes only verified PAT/JWT metadata, never Scope-shaped fields or session identity.
- [Phase ?]: FetchJWT verifies only JWTs, reloads the live user, and projects bounded private facts.
- [Phase ?]: FetchAppSession remains a fail-closed public pipeline seam until Phase 245 adds verifier and storage.
- [Phase ?]: FetchSession reloads config.user_schema before building identity-only browser Scope state.
- [Phase ?]: Generated Scope structs use Sigra.Scope.build/3 while only non-struct scopes use legacy new/1.
- [Phase ?]: FetchBearer preserves only legacy prefix/JWT/default dispatch and delegates to explicit credential-kind plugs.
- [Phase ?]: FetchBearer.init/1 and call/2 are deprecated with explicit FetchAPIToken/FetchJWT migration guidance.
- [Phase ?]: Published normative four-owner credential-boundary contract with Sigra first-party auth, Lockspire delegation, Crosswake projected facts, and host policy ownership.
- [Phase ?]: Primary API documentation selects explicit FetchSession, FetchAppSession, FetchAPIToken, and FetchJWT pipelines; FetchBearer is migration-only.

### Pending Todos

None yet.

### Blockers/Concerns

- Physical-iPhone proof in Phase 248 requires deterministic device automation and redacted evidence; do not overstate emulator or contract evidence as physical-device proof.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Client packaging | Native SDKs, an Electron reference app, and generalized offline behavior await concrete adopter evidence. | Deferred | v1.49 definition |

## Session Continuity

Last session: 2026-08-12T19:55:42.250Z
Stopped at: Completed 243-05-PLAN.md
Resume file: None
