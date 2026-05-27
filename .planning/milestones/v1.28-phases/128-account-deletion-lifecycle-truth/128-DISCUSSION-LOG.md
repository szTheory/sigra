# Phase 128: Account Deletion Lifecycle Truth - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md - this log preserves the analysis.

**Date:** 2026-05-27
**Phase:** 128-account-deletion-lifecycle-truth
**Mode:** assumptions
**Areas analyzed:** Enqueue Ownership, Active-Scheduled Predicate, Soft-Delete Finalization Truth, Contract Boundary

## Assumptions Presented

### Enqueue Ownership

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Scheduling should continue to enqueue from `Sigra.Account.Deletion.schedule/3` when `Oban`, `Sigra.Workers.AccountDeletion`, and generated-host context such as `:user_schema` are available; absence of that context should remain a no-op degradation, not an error. | Likely | `.planning/ROADMAP.md`; `.planning/REQUIREMENTS.md`; `lib/sigra/account/deletion.ex`; `lib/sigra/auth.ex`; `lib/sigra/workers/account_deletion.ex` |

### Active-Scheduled Predicate

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| "Actively scheduled deletion" means both `deleted_at` and `scheduled_deletion_at` are present; finalized users with only `deleted_at` must be treated as `{:error, :not_scheduled}` for cancel and execute. | Confident | `lib/sigra/account/deletion.ex`; `test/sigra/account/deletion_test.exs`; `test/sigra/workers/account_deletion_test.exs` |

### Soft-Delete Finalization Truth

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Soft-delete execution should preserve the user row and `deleted_at`, while clearing `scheduled_deletion_at`, `pending_email`, and `original_email`; docs/templates/tests should avoid saying the row was hard-deleted or permanently removed when the configured strategy is soft-delete. | Confident | `lib/sigra/account/deletion.ex`; `test/sigra/account/deletion_test.exs`; `guides/flows/account-lifecycle.md`; `priv/templates/sigra.install/core/reactivation_live.ex`; `priv/templates/sigra.install/core/emails.ex`; `guides/recipes/testing.md` |

### Contract Boundary

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 128 should repair lifecycle semantics in the existing library-owned `Sigra.Account` / `Sigra.Account.Deletion` / `Sigra.Auth` path, with generated templates staying as thin context providers rather than owning deletion behavior. | Confident | `.planning/phases/127-versioned-auth-data-export/127-CONTEXT.md`; `lib/sigra/account.ex`; `priv/templates/sigra.install/core/auth.ex`; `test/example/lib/example/accounts.ex` |

## Corrections Made

No corrections - the interactive question tool was unavailable in Default mode, so the workflow fallback applied the recommended repo-grounded assumptions.

## External Research

No external research was needed; the codebase and prior planning artifacts provided enough evidence for Phase 128 context capture.
