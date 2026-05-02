---
phase: 93-m2m-service-account-tokens-b2b-03
plan: "06"
subsystem: service-accounts
tags: [service-accounts, atomic-audit, postgres, gap-closure, b2b-03, d-aud-08, d-aud-07]

dependency_graph:
  requires:
    - "93-01: ServiceAccounts mutations with atomic Multi shape"
    - "91: Audit.log_multi_safe (Phase 82 reference shape)"
  provides:
    - "Executable D-AUD-08 co-fated rollback proof for all five SA mutations"
    - "93-VERIFICATION.md Open Gap #1 closed"
  affects:
    - "lib/sigra/service_accounts.ex"
    - "test/sigra/service_accounts_audit_atomicity_test.exs"

tech_stack:
  added: []
  patterns:
    - "Postgres CHECK constraint fault injection: ALTER TABLE audit_events ADD CONSTRAINT ... CHECK (action <> '<verb>')"
    - "try/after cleanup pattern for constraint teardown (compatible with start_supervised!)"
    - "start_supervised!({PostgresRepo, PostgresRepo.default_config()}) per-test Postgres lifecycle"
    - "Sigra.Config.new!/1 config construction — never raw %Sigra.Config{} struct"
    - "bytea column for hashed_client_secret to accept raw SHA-256 bytes from Token.hash_token/1"

key_files:
  created:
    - path: "test/sigra/service_accounts_audit_atomicity_test.exs"
      description: "478-line Postgres fault-injection test suite proving co-fated rollback for all five SA mutations (D-AUD-08, D-AUD-07, D-93-22)"
  modified:
    - path: "lib/sigra/service_accounts.ex"
      description: "Added try/rescue to issue_token/4 to catch Ecto.ConstraintError from repo.transaction and return :service_account_token_issuance_aborted (Rule 1 bug fix)"

decisions:
  - "Used bytea (not text) for hashed_client_secret column — Token.hash_token/1 returns raw 32 SHA-256 bytes (non-UTF-8); storing in text raises Postgrex.Error, bypassing ConstraintError-specific :constraint_violation telemetry reason"
  - "Removed on_exit constraint cleanup from setup block — start_supervised! tears down the repo supervision tree before on_exit callbacks run, causing cleanup to fail. Each test uses try/after for inline cleanup while the repo is still alive"
  - "Applied try/rescue to issue_token/4 — this function delegates to JWT.generate_service_account_tokens which internally calls repo.transaction. Ecto.ConstraintError from a CHECK violation propagates up through DBConnection's re-raise mechanism and must be caught at the caller level"
  - "Scoped SA/credential tables use prefixed names (sa_atomicity_*) to avoid conflicts with other Postgres test suites running against the same database"

metrics:
  duration: "~90 minutes (context resumed from prior session)"
  completed: "2026-05-02"
  tasks_completed: 1
  tasks_total: 1
  files_changed: 2
---

# Phase 93 Plan 06: SA Audit Co-fated Rollback Proof Summary

**One-liner:** Postgres CHECK fault injection proving D-AUD-08 co-fated rollback for all five SA mutations (`service_account.create`, `service_account.revoke`, `service_account.credential_create`, `service_account.credential_revoke`, `service_account.token_issued`) with stable error atoms and telemetry assertions.

## Objective

Close `93-VERIFICATION.md` Open Gap #1: the missing executable proof that audit failure atomically rolls back the corresponding SA / credential write. Plan 93-01 implemented the mutations with the `Multi.new() |> Multi.insert/update() |> Audit.log_multi_safe() |> repo.transaction()` shape but deferred the dedicated rollback-proof harness.

This plan mirrors `test/sigra/jwt_refresh_audit_cofate_test.exs` (Phase 82) replacing JWT refresh-flow schemas/calls with service-account equivalents.

## What Was Built

**`test/sigra/service_accounts_audit_atomicity_test.exs`** — 478 lines

Five named `test` blocks (D-AUD-07: no loops over fault paths):

| Test | Mutation | Guard constraint | Stable error atom | Row invariant |
|------|----------|-----------------|-------------------|---------------|
| create | `ServiceAccounts.create/3` | `sa_create_cofate_guard` | `:service_account_aborted` | SA row count unchanged |
| revoke | `ServiceAccounts.revoke/3` | `sa_revoke_cofate_guard` | `:service_account_aborted` | `revoked_at` nil, `token_epoch` unchanged |
| credential_create | `ServiceAccounts.create_credential/4` | `sa_cred_create_cofate_guard` | `:service_account_credential_aborted` | Credential row count unchanged |
| credential_revoke | `ServiceAccounts.revoke_credential/3` | `sa_cred_revoke_cofate_guard` | `:service_account_credential_aborted` | `revoked_at` nil |
| token_issued | `ServiceAccounts.issue_token/4` | `sa_token_issued_cofate_guard` | `:service_account_token_issuance_aborted` | `last_used_at` unchanged |

Each test also asserts `[:sigra, :audit, :log_safe_error]` telemetry with `reason: :constraint_violation`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Missing rescue in `issue_token/4` for `Ecto.ConstraintError`**

- **Found during:** Task 1 (token_issued test block)
- **Issue:** `issue_token/4` only handled the `{:error, _step, _reason, _changes}` Multi failure return tuple. When a Postgres CHECK constraint fires during `repo.transaction`, DBConnection's exception pipeline re-raises as `Ecto.ConstraintError`. This propagated uncaught out of `JWT.generate_service_account_tokens` through `Telemetry.span` and out of `issue_token/4`, crashing the test process instead of returning `{:error, :service_account_token_issuance_aborted}`.
- **Fix:** Added `try/rescue` block to `issue_token/4` that catches all exceptions, checks `match?(%Ecto.ConstraintError{}, e)` to distinguish `:constraint_violation` from `:database_error`, emits `[:sigra, :audit, :log_safe_error]` telemetry, and returns `{:error, :service_account_token_issuance_aborted}`. Pattern is consistent with `commit_verify_failure_audit/3` in the same module (lines 283-292 of original file).
- **Files modified:** `lib/sigra/service_accounts.ex` (lines 197-232)
- **Commit:** 559193a

**2. [Rule 1 - Bug] `hashed_client_secret` column type must be `bytea` not `text`**

- **Found during:** Task 1 (credential_create, credential_revoke, token_issued tests)
- **Issue:** `Token.hash_token/1` returns raw 32-byte SHA-256 digest (non-UTF-8 binary). Storing in a `text NOT NULL` Postgres column raises `Postgrex.Error` (invalid UTF-8 encoding), not `Ecto.ConstraintError`. The `emit_constraint_or_reraise/3` helper identifies `Ecto.ConstraintError` by struct match; a `Postgrex.Error` falls through to the catch-all clause and emits `reason: :database_error` instead of `:constraint_violation`. This would cause three of the five telemetry assertions to fail.
- **Fix:** Changed `SATestCredential` field declaration to `field :hashed_client_secret, :binary` and the DDL to `hashed_client_secret bytea NOT NULL`. Consistent with the production migration template at `priv/templates/sigra.install/organizations/service_accounts_migration.exs` and the example schema at `test/example/lib/example/accounts/service_account_credential.ex`.
- **Files modified:** `test/sigra/service_accounts_audit_atomicity_test.exs` (schema declaration + DDL)
- **Commit:** 559193a

**3. [Rule 1 - Bug] `on_exit` callback runs after `start_supervised!` tears down the repo**

- **Found during:** Task 1 (setup block)
- **Issue:** `on_exit(fn -> Ecto.Adapters.SQL.query!(repo, ...) end)` runs after the test's supervision tree (including PostgresRepo) is stopped. Every test reported failure in the `on_exit` phase even when the test body passed.
- **Fix:** Removed the `on_exit` block entirely. Each test's `try/after` block drops its own constraint while the repo is still alive. The `try/after` pattern is always executed (even on assertion failure), providing equivalent cleanup without the lifecycle ordering problem.
- **Files modified:** `test/sigra/service_accounts_audit_atomicity_test.exs` (setup block)
- **Commit:** 559193a

## Acceptance Criteria Verification

| Criterion | Result |
|-----------|--------|
| 5 tests passing | PASS — `5 tests, 0 failures` |
| Line count >= 250 | PASS — 478 lines |
| 5 named test blocks | PASS |
| 5 ADD CONSTRAINT calls | PASS |
| 5 DROP CONSTRAINT IF EXISTS calls | PASS |
| async: false | PASS |
| Sigra.Config.new!/1 used | PASS |
| All 5 audit verbs in CHECK guards | PASS |
| All 3 stable error atoms present | PASS |
| 5 telemetry assertions | PASS |

## Threat Model Coverage

**T-93-AUD-01** (Tampering — audit-row insert may fail leaving half-written SA/credential): Mitigated by this plan. All five mutations now have executable rollback proof. Telemetry observability (D-AUD-04) confirmed by `assert_receive` on `[:sigra, :audit, :log_safe_error]`.

## Gap Closure

`93-VERIFICATION.md` Open Gap #1 ("Missing: `test/sigra/service_accounts_audit_atomicity_test.exs`") is now CLOSED.

The D-AUD-* anchors now executable:
- **D-AUD-07:** Five separate named test blocks, no loops
- **D-AUD-08:** Co-fated rollback contract proven for all five SA mutations
- **D-AUD-10:** Dedicated atomicity test file separate from unit suite
- **D-93-22:** Stable error atom contract locked and asserted

## Self-Check: PASSED

Files exist:
- `test/sigra/service_accounts_audit_atomicity_test.exs` — FOUND
- `lib/sigra/service_accounts.ex` — FOUND (modified)

Commits exist:
- 559193a — FOUND (`feat(93-06): D-AUD-08 co-fated rollback proof for all five SA mutations`)
