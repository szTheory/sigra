---
gsd_state_version: 1.0
milestone: v1.27
milestone_name: v1.27 ENT-SSO
status: ready_for_phase_planning
last_updated: "2026-05-25T13:26:42.000Z"
last_activity: 2026-05-25 -- Started v1.27 ENT-SSO, wrote fresh research and requirements, and created the roadmap for phases 122-126
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Current focus:** v1.27 ENT-SSO — enterprise login routing, JIT organization membership provisioning, and truthful SSO-only / break-glass posture

## Current Position

Phase: 122
Plan: 0 of 0
Status: v1.27 ENT-SSO is initialized; requirements and roadmap are live, and the project is ready for phase planning
Last activity: 2026-05-25 -- activated the ENT-SSO milestone with OIDC-first enterprise connection requirements, org-aware routing, JIT membership, enforcement, and proof/docs phases

## Accumulating Context

- Assessment takeaway remains unchanged: Sigra is already strong for Phoenix SaaS teams on installer DX, sessions, MFA, passkeys, orgs, admin, audit, and operator truth; enterprise SSO per organization is the remaining contract-closing wedge.
- Current rough maturity band remains `80-89%` for the library's intended scope. The remaining delta is meaningful but concentrated rather than foundationally weak.
- `v1.27` is intentionally OIDC-first and keeps SAML as a future-compatible seam unless implementation research proves a broader protocol cut is honest inside this milestone.
- `Sigra.DataExport` is still intentionally thin compared with the rest of the library surface. That keeps `DATA-LIFECYCLE` as the next ranked follow-on after `ENT-SSO`.
- Open investigation threads:
  - `.planning/threads/enterprise-sso-b2b-connections.md`
  - `.planning/threads/data-lifecycle-export-scope.md`

## Deferred Items

Items acknowledged and deferred at v1.26 milestone close on 2026-05-25:

| Category | Item | Status |
|----------|------|--------|
| todo | 2026-05-08-write-accrue-integration-recipe.md | pending |
| todo | 2026-05-08-write-lockspire-integration-recipe.md | pending |
| todo | 2026-05-08-write-relyra-integration-recipe.md | pending |
| todo | 2026-05-08-write-rulestead-integration-recipe.md | pending |
| todo | 2026-05-08-write-threadline-integration-recipe.md | pending |
| seed | SEED-011-ecosystem-integrations | dormant |

### Decisions

- Activated `PK-LIFECYCLE` as the v1.26 milestone per the ranked milestone arc.
- Treat existing passkey CRUD, WebAuthn ceremony plumbing, and passkey-primary toggle as shipped foundation rather than new feature scope.
- Closed the stale Phase 88 working-tree todo after re-verifying the branch was clean on 2026-05-23.
- Archived `v1.26 PK-LIFECYCLE` after the repaired-form proof surfaces, milestone audit, and Nyquist closure all aligned on 2026-05-25.
- Repo-grounded next-step assessment kept `ENT-SSO` as the highest-leverage milestone because the org/MFA/RBAC/service-account substrate already exists while enterprise customer auth routing and JIT provisioning do not.
- `DATA-LIFECYCLE` stays second: the audit stream and account-lifecycle primitives are real, but the export contract is still much thinner than the enterprise-auth gap.
- Treat SCIM, broad directory sync, hosted-control-plane behavior, and opinionated authorization policy as out of scope for the immediate `ENT-SSO` milestone.
- Start `v1.27` at Phase `122` and keep the roadmap to five phases: connection contract, routing, JIT reconciliation, enforcement, and proof/docs.
- Treat enterprise SSO in this milestone as an auth-control-plane extension, not a generic company-directory platform.

## Operator Next Steps

- Start with `$gsd-plan-phase 122` to plan the enterprise connection contract and setup-truth phase.
- Keep later milestone proposals behind the current sequence: finish `ENT-SSO`, then reassess `DATA-LIFECYCLE`, then `SUITE-INTEGRATION`.
- Do not widen the current milestone into SCIM, hosted-control-plane UX, or opinionated authorization policy.
