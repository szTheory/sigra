---
gsd_state_version: 1.0
milestone: v1.27
milestone_name: v1.27 ENT-SSO
status: executing
last_updated: "2026-05-25T16:45:53.071Z"
last_activity: 2026-05-25 -- Phase 123 execution started
progress:
  total_phases: 5
  completed_phases: 1
  total_plans: 6
  completed_plans: 2
  percent: 20
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Current focus:** Phase 123 — org-aware-enterprise-routing

## Current Position

Phase: 123 (org-aware-enterprise-routing) — EXECUTING
Plan: 1 of 4
Status: Executing Phase 123
Last activity: 2026-05-25 -- Phase 123 execution started

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

- Run `$gsd-verify-work 122` to confirm the enterprise connection contract, generated-host surface, and installer output against the Phase 122 plan and requirements.
- If verification passes, continue with Phase 123 enterprise routing rather than widening 122 into SCIM, hosted-control-plane UX, or opinionated authorization policy.
- Keep later milestone proposals behind the current sequence: finish `ENT-SSO`, then reassess `DATA-LIFECYCLE`, then `SUITE-INTEGRATION`.
