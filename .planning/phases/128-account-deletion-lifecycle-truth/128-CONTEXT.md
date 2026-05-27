# Phase 128: Account Deletion Lifecycle Truth - Context

**Gathered:** 2026-05-27 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Repair schedule, cancel, execute, and worker-enqueue semantics so account deletion behavior matches operator-facing docs. This phase covers library-owned lifecycle truth for `LIFE-01`, `LIFE-02`, and `LIFE-03`: enqueue scheduled deletion jobs when Oban and generated-host context are available, reject cancel/execute for users that are not actively scheduled, and finalize soft deletion without claiming hard deletion. Generated-host and broad documentation parity remain Phase 129 except where Phase 128 needs to identify the truthful contract they must follow.
</domain>

<decisions>
## Implementation Decisions

### Enqueue Ownership
- **D-01:** Keep scheduled deletion job creation in the library-owned `Sigra.Account.Deletion.schedule/3` path.
- **D-02:** When `Oban`, `Sigra.Workers.AccountDeletion`, and generated-host job context such as `:user_schema` are available, scheduling must enqueue `Sigra.Workers.AccountDeletion` for the computed `scheduled_deletion_at`.
- **D-03:** Missing job context or missing Oban support should safely degrade without failing the schedule operation, but the degradation must remain explicit enough for tests and operator documentation to stay truthful.

### Active-Scheduled Predicate
- **D-04:** An actively scheduled deletion means both `deleted_at` and `scheduled_deletion_at` are present.
- **D-05:** Cancel and execute must return `{:error, :not_scheduled}` for users with no deletion markers and for finalized soft-deleted users where `deleted_at` is set but `scheduled_deletion_at` is nil.
- **D-06:** Worker execution should use the same active-scheduled predicate, so stale jobs created before cancellation become no-ops instead of re-finalizing or reactivating the wrong state.

### Soft-Delete Finalization Truth
- **D-07:** Soft-delete execution preserves the user row and `deleted_at`.
- **D-08:** Soft-delete execution must clear `scheduled_deletion_at`, `pending_email`, and `original_email` so finalized rows are no longer interpreted as pending deletion and do not retain email-change staging fields.
- **D-09:** Operator-facing surfaces must not claim the user row was hard-deleted or permanently removed when the configured strategy is `:soft_delete`.

### Contract Boundary
- **D-10:** Repair lifecycle semantics in the existing `Sigra.Account`, `Sigra.Account.Deletion`, `Sigra.Auth`, and `Sigra.Workers.AccountDeletion` path rather than moving behavior into generated host code.
- **D-11:** Generated templates and example app wrappers should remain thin providers of repo, schema, scope, audit, token, and session context for the library contract.
- **D-12:** Keep lifecycle truth aligned with Phase 127 export semantics and `Sigra.Account.Deletion.status/1`; do not infer host-domain retention or generic compliance behavior.

### the agent's Discretion
- Exact helper names and test organization for enqueue proof.
- Whether to prove enqueue behavior through fake repo insertion, Oban changeset assertions, or a focused integration test, as long as `scheduled_at`, worker module, and args are pinned.
- Exact warning/log message wording for no-op job degradation, if implementation needs to surface it.

### Folded Todos
None.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone contract
- `.planning/ROADMAP.md` - Phase 128 goal, success criteria, and sequencing after Phase 127.
- `.planning/REQUIREMENTS.md` - `LIFE-01`, `LIFE-02`, and `LIFE-03` requirement definitions.
- `.planning/PROJECT.md` - active `DATA-LIFECYCLE` boundary and hybrid library/generated-host philosophy.
- `.planning/STATE.md` - current instruction to discuss and plan Phase 128 next.
- `.planning/METHODOLOGY.md` - decisive-defaulting and escalation thresholds applied during context gathering.

### Prior phase authority
- `.planning/phases/127-versioned-auth-data-export/127-CONTEXT.md` - lifecycle truth aligns with `Sigra.Account.Deletion.status/1`; Sigra stays bounded to Sigra-owned auth/account fields.
- `.planning/phases/127-versioned-auth-data-export/127-RESEARCH.md` - Phase 127 research notes raw lifecycle fields plus derived status as the current export truth.

### Existing lifecycle code
- `lib/sigra/account/deletion.ex` - schedule, cancel, execute, scheduled predicate, soft-delete finalization, and enqueue helper.
- `lib/sigra/account.ex` - public account lifecycle orchestration and audit co-fate wrappers.
- `lib/sigra/auth.ex` - generated-host-facing auth API that supplies repo/config/schema context before calling account lifecycle functions.
- `lib/sigra/workers/account_deletion.ex` - Oban worker queue, args contract, stale-job no-op behavior, and execute delegation.
- `lib/sigra/workers.ex` - worker args normalization and behaviour contract.

### Generated host and example surfaces
- `priv/templates/sigra.install/core/auth.ex` - generated context wrapper for schedule/cancel/deletion status.
- `priv/templates/sigra.install/core/user.ex` - generated user lifecycle fields and deletion changeset.
- `priv/templates/sigra.install/core/reactivation_live.ex` - generated reactivation copy and cancel flow.
- `test/example/lib/example/accounts.ex` - example app wrapper and impersonation guard around deletion operations.
- `test/example/lib/example_web/live/reactivation_live.ex` - example reactivation copy and cancel flow.

### Proof and docs to inspect
- `test/sigra/account/deletion_test.exs` - current unit coverage for schedule, cancel, execute, scheduled predicate, and finalized-user rejection.
- `test/sigra/workers/account_deletion_test.exs` - current worker behavior and stale-job no-op coverage.
- `test/sigra/account_audit_atomicity_test.exs` - audit co-fate expectations for account lifecycle operations.
- `guides/flows/account-lifecycle.md` - operator-facing lifecycle narrative and strategy descriptions.
- `guides/recipes/testing.md` - current testing helper claims that may overstate hard-delete behavior.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Account.Deletion.schedule/3`: already sets `deleted_at`, `scheduled_deletion_at`, `original_email`, clears `pending_email`, revokes tokens/sessions, and calls `maybe_enqueue_deletion_job/4`.
- `Sigra.Account.Deletion.scheduled?/1`: existing source of truth for active scheduled state.
- `Sigra.Account.Deletion.status/1`: existing source of truth for `{:scheduled, days}`, `:deleted`, and `:not_scheduled`, already consumed by Phase 127 export truth.
- `Sigra.Workers.AccountDeletion`: existing Oban worker using `:sigra_lifecycle`, unique `:user_id`, stringified module args, and stale-job no-op behavior.
- `Sigra.Account` audit wrappers: existing `log_multi_safe` discipline for schedule, cancel, and execute audit events.

### Established Patterns
- Security-sensitive lifecycle behavior belongs in the dependency, with generated code passing host-specific schemas and scope.
- Optional infrastructure degrades explicitly rather than pretending behavior exists.
- Finalization semantics must be truthful: soft-delete preserves rows, hard-delete deletes rows, anonymize preserves rows while clearing Sigra-owned PII.
- Stale async work should be idempotent/no-op when the underlying lifecycle state has changed.

### Integration Points
- `lib/sigra/account/deletion.ex` is the likely primary implementation target for enqueue proof and any lifecycle truth repair.
- `lib/sigra/auth.ex` and generated wrappers may need context propagation if enqueue args are incomplete in generated-host calls.
- `test/sigra/account/deletion_test.exs` and `test/sigra/workers/account_deletion_test.exs` are the primary proof targets for `LIFE-01..03`.
- Phase 129 should handle broad generated-host, example-app, install-golden, and docs parity after Phase 128 locks the library contract.
</code_context>

<specifics>
## Specific Ideas

- Treat `scheduled_deletion_at` clearing as the durable marker that soft-delete has finalized and should export as `:deleted`, not `{:scheduled, days}`.
- Keep stale worker behavior as `{:ok, :not_scheduled}` rather than raising, because cancellation during the grace window is expected.
- Pin worker job args enough that generated hosts with Oban can execute without custom controller logic: repo, user schema, scope module, organization schema, audit schema, token/session/credential schemas, user id, actor id, organization id, and strategy.
</specifics>

<deferred>
## Deferred Ideas

Generated-host, example-app, install-golden, and public docs parity are Phase 129 unless Phase 128 implementation needs a narrow template/context propagation fix to prove `LIFE-01`.

### Reviewed Todos (not folded)
None.
</deferred>

---

*Phase: 128-account-deletion-lifecycle-truth*
*Context gathered: 2026-05-27*
