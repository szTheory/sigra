---
gsd_state_version: 1.0
milestone: v1.49
milestone_name: FIRST-PARTY-CLIENT-READINESS
current_phase: 244
current_phase_name: PAT and Advanced JWT Truth Repair
status: planning
stopped_at: Phase 244 context gathered (assumptions mode)
last_updated: "2026-08-12T21:00:26.604Z"
last_activity: 2026-08-12
last_activity_desc: Phase 243 complete, transitioned to Phase 244
progress:
  total_phases: 2
  completed_phases: 1
  total_plans: 5
  completed_plans: 5
current_plan: 2
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-08-12)

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Current focus:** Phase 244 — PAT and Advanced JWT Truth Repair

## Current Position

Phase: 244 of 249 (PAT and Advanced JWT Truth Repair)
Plan: Not started
Status: Ready to plan
Last activity: 2026-08-12 — Phase 243 complete, transitioned to Phase 244

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

### Pending Todos

None yet.

### Blockers/Concerns

- Physical-iPhone proof in Phase 248 requires deterministic device automation and redacted evidence; do not overstate emulator or contract evidence as physical-device proof.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Client packaging | Native SDKs, an Electron reference app, and generalized offline behavior await concrete adopter evidence. | Deferred | v1.49 definition |

## Session Continuity

Last session: 2026-08-12T21:00:26.599Z
Stopped at: Phase 244 context gathered (assumptions mode)
Resume file: .planning/phases/244-pat-and-advanced-jwt-truth-repair/244-CONTEXT.md
