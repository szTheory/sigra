# Phase 79 — API token verify failure audit atomicity — Verification

**Milestone:** v1.16 — **AUD-16-01**..**AUD-16-04**  
**Goal:** **`Sigra.APIToken.verify/2`** writes **`api.token_verify.failure`** via **`Repo.transaction/1`** + **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** when `:audit_schema` is set (invalid / revoked / expired branches); align **44** inventory + **09** C-1 rows **044–046**; preserve **D-27** (no success-path audit).

## Checklist

| ID | Criterion | Evidence |
|----|-----------|----------|
| 79-01 | **`lib/sigra/api_token.ex`** — failure branches use **`commit_api_token_verify_failure_audit/2`** + **`log_multi_safe`** | `rg commit_api_token_verify_failure_audit lib/sigra/api_token.ex` |
| 79-02 | **`test/sigra/api_token_audit_atomic_test.exs`** — invalid / revoked / expired failure audits + CHECK guard + constraint telemetry | ExUnit file |
| 79-03 | **44** inventory **044–046** → **`Multi` + `log_multi_safe`**, phase **79** | `44-AUD-04-INVENTORY.md` |
| 79-04 | **09-VERIFICATION** Phase **44** rows **044–046** **T1** | `09-VERIFICATION.md` |
| 79-05 | **09-03-SUMMARY** + **`CHANGELOG` [Unreleased]** mention **v1.16** / **79** / **AUD-16** | Planning + changelog |
| 79-06 | **`mix test test/sigra/api_token_audit_atomic_test.exs test/sigra/api_token_test.exs`** green | ExUnit (Postgres via **`SIGRA_TEST_PG_USERNAME`** etc.) |

## Outcomes

- **79-01..79-05:** Code + planning truth shipped in-repo (**2026-04-24**).
- **79-06:** Local / CI Postgres required for **`Sigra.APITokenAuditAtomicTest`** (same contract as phase **78** atomic tests).
