---
gsd_state_version: 1.0
milestone: v1.27
milestone_name: v1.27 ENT-SSO
status: milestone_shipped
last_updated: "2026-05-26T15:05:00.000Z"
last_activity: 2026-05-26 -- v1.27 milestone audit passed and archive preparation completed
progress:
  total_phases: 5
  completed_phases: 5
  total_plans: 17
  completed_plans: 17
  percent: 100
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Current focus:** No active milestone; archive v1.27 and prepare the next milestone selection.

## Current Position

Phase: none
Plan: n/a
Status: v1.27 shipped; milestone archive and tag are the next repository actions
Last activity: 2026-05-26 -- v1.27 `ENT-SSO` reached `verified_and_archive_ready` in `.planning/v1.27-MILESTONE-AUDIT.md`

## Accumulating Context

- Sigra now ships the missing organization-scoped enterprise login wedge: truthful setup, canonical routing, JIT reconciliation, SSO-only enforcement, and bounded generated-host/operator proof.
- The rough maturity band remains `80-89%`, but the largest remaining delta after v1.27 is no longer enterprise login truth; it is the thinner data-export and lifecycle surface.
- `DATA-LIFECYCLE` is now the top-ranked follow-on candidate. `SUITE-INTEGRATION` remains behind it.
- The enterprise and data-lifecycle planning threads are no longer open blockers; `enterprise-sso-b2b-connections` is resolved and `data-lifecycle-export-scope` is dormant until the next milestone is selected.

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
- Shipped `v1.27 ENT-SSO` on 2026-05-26 after retroactively restoring authoritative verification artifacts for Phases 123-125, normalizing Nyquist records for Phases 123-126, and passing the milestone audit.
- `DATA-LIFECYCLE` is now the next ranked candidate; keep SAML, SCIM, hosted-control-plane behavior, and opinionated authz out of scope unless a future milestone explicitly re-selects them.

## Operator Next Steps

- Review `.planning/milestones/v1.27-ROADMAP.md`, `.planning/milestones/v1.27-REQUIREMENTS.md`, and `.planning/milestones/v1.27-MILESTONE-AUDIT.md` for the archived enterprise contract.
- Start the next milestone with `$gsd-new-milestone`; use `.planning/MILESTONE-ARC.md` to rank `DATA-LIFECYCLE` against any new proposal.
- Keep later milestone proposals behind the current sequence: `DATA-LIFECYCLE`, then `SUITE-INTEGRATION`, unless a new repo-grounded blocker outranks them.
