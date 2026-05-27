---
gsd_state_version: 1.0
milestone: v1.28
milestone_name: DATA-LIFECYCLE
status: blocked
last_updated: "2026-05-27T11:10:35.393Z"
last_activity: 2026-05-27 -- Phase 130 Plan 01 executed in blocked branch; PROOF-01 still pending due to docs gate failure
progress:
  total_phases: 4
  completed_phases: 3
  total_plans: 6
  completed_plans: 5
  percent: 75
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Current focus:** Phase 130 — verification-and-release-readiness

## Current Position

Phase: 130 (verification-and-release-readiness) — BLOCKED (release docs gate)
Plan: 1 of 1 (executed; PROOF-01 release-blocked, not completed)
Status: Phase 130 Plan 01 executed in blocked branch on 2026-05-27. PROOF-01 remains pending in REQUIREMENTS.md and v1.28-MILESTONE-AUDIT.md keeps status: gaps_found.
Last activity: 2026-05-27 -- Phase 130 Plan 01 executed in blocked branch; PROOF-01 still pending due to docs gate failure

## Accumulating Context

- Sigra now ships the missing organization-scoped enterprise login wedge: truthful setup, canonical routing, JIT reconciliation, SSO-only enforcement, and bounded generated-host/operator proof.
- The rough maturity band remains `80-89%`, but the largest remaining delta after v1.27 is no longer enterprise login truth; it is the thinner data-export and lifecycle surface.
- `DATA-LIFECYCLE` is now active. `SUITE-INTEGRATION` remains behind it.
- The enterprise and data-lifecycle planning threads are no longer open blockers; `enterprise-sso-b2b-connections` is resolved and `data-lifecycle-export-scope` is now the active milestone context.

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
- Shipped `v1.27 ENT-SSO` on 2026-05-26 after retroactively restoring authoritative verification artifacts for Phases 123-125, normalizing Nyquist records for Phases 123-126, and passing the milestone audit.
- Activated `DATA-LIFECYCLE` on 2026-05-26 as the next milestone because the repo already ships export and account-lifecycle substrate, but the contract and truth surface still need repair.
- Scaffolded `v1.28 DATA-LIFECYCLE` on 2026-05-27 with four phases: versioned export, deletion lifecycle truth, generated-host/docs parity, and verification/release readiness.
- Keep `DATA-LIFECYCLE` bounded to Sigra-owned auth/account export, audit/export boundary clarity, and truthful schedule/cancel/execute semantics.
- Treat SCIM, hosted-control-plane behavior, generic BI/reporting export, broad directory sync, and opinionated authorization policy as out of scope for `DATA-LIFECYCLE`.
- `SUITE-INTEGRATION` remains the next ranked follow-on after `DATA-LIFECYCLE`.
- Gathered Phase 127 assumptions-mode context on 2026-05-27; planning should use `.planning/phases/127-versioned-auth-data-export/127-CONTEXT.md` as the resume artifact.
- Completed Phase 127 Plan 01 as test-only RED proof on 2026-05-27; EXP-01/EXP-02 production behavior remains for Plan 02 implementation.
- Completed Phase 127 Plan 02 on 2026-05-27; `Sigra.DataExport.export_auth_data/3` now ships lifecycle status, structured omissions, curated safe optional-schema serializers, backup-code summary, and enterprise exclusion truth.
- [Phase 127]: Preserved the Plan 01 omission test surface as section/schema maps without adding a third reason key.
- [Phase 127]: Kept backup codes summary-only and enterprise connections explicitly excluded from user export.
- [Phase 127]: Kept export payload ownership in Sigra.DataExport.export_auth_data/3.
- Gathered Phase 128 assumptions-mode context on 2026-05-27; planning should use `.planning/phases/128-account-deletion-lifecycle-truth/128-CONTEXT.md` as the resume artifact.
- Completed Phase 128 Plan 01 on 2026-05-27; account deletion lifecycle truth is pinned by tests for Oban enqueue shape, missing-context degradation, stale worker no-op behavior, and row-preserving soft-delete finalization.
- [Phase 128]: Kept account-deletion enqueue ownership in `Sigra.Account.Deletion.schedule/3`.
- [Phase 128]: Kept missing job context as safe no-op degradation rather than failing scheduling.
- [Phase 128]: Kept soft-delete finalization row-preserving and `deleted_at`-preserving.
- [Phase 130]: Captured fresh Phase 130 PROOF-01 evidence on 2026-05-27 with 56+66 targeted-lane passing tests and 2211 full-suite passing tests, but recorded mix docs --warnings-as-errors as a release docs blocker on Sigra.OAuth.callback/4 references; PROOF-01 remains pending and v1.28-MILESTONE-AUDIT.md keeps status: gaps_found.
- [Phase 130]: Did not flip PROOF-01 to completed or Phase 130 plan count to 1/1 because the release docs gate failed; follow-up plan must fix guides/flows/oauth.md Sigra.OAuth.callback/4 references and rerun mix docs --warnings-as-errors before promotion.

## Operator Next Steps

- Plan a focused docs-hotfix follow-on (small Phase 130-02 plan or equivalent) that resolves the `Sigra.OAuth.callback/4` references in `guides/flows/oauth.md` (lines 15 and 58) and reruns `mix docs --warnings-as-errors` cleanly. Once the docs gate passes, promote PROOF-01 to completed in REQUIREMENTS.md, flip Phase 130 to 1/1 in ROADMAP.md, refresh v1.28-MILESTONE-AUDIT.md to `status: passed`, and update `130-VERIFICATION.md` to `status: passed`.
- Use `.planning/MILESTONE-ARC.md` to keep later milestone proposals behind the current sequence unless a new repo-grounded blocker outranks it.
- Keep `SUITE-INTEGRATION` deferred behind `DATA-LIFECYCLE` until v1.28 release readiness is closed.

### Blockers

- Phase 130 release docs gate failure: mix docs --warnings-as-errors fails on Sigra.OAuth.callback/4 undefined-reference warnings in guides/flows/oauth.md (lines 15 and 58). PROOF-01 BLOCKED. Recorded in 130-01-SUMMARY.md ## Release Blockers with owner Claude and retry condition.

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 130 P01 | 605s | 3 tasks; 3 files modified (130-01-SUMMARY.md, 130-VERIFICATION.md, 130-VALIDATION.md); blocked branch — PROOF-01 release-blocked on mix docs --warnings-as-errors. |
