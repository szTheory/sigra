---
phase: 44-mfa-account-api-atomic-batches
plan: "05"
subsystem: api_token
tags: [audit, AUD-07, Ecto.Multi, postgres]

requires:
  - phase: 44-02
    provides: "log_multi_safe + emit_telemetry_from_changes"
provides:
  - "APIToken revoke + revoke_all atomic with audit when :audit_schema set"
affects: []

key-files:
  created: []
  modified:
    - "lib/sigra/api_token.ex"
    - "test/sigra/api_token_audit_atomic_test.exs"

requirements-completed: [AUD-07]

completed: 2026-04-20
---

# Phase 44 — Plan 05 summary (AUD-07 API token revoke)

## Shipped

- **`lib/sigra/api_token.ex`**: `revoke/2` uses `Multi.update` + `Audit.log_multi_safe("api.token_revoke", …)` + `emit_telemetry_from_changes/1`, mirroring `create/3`. `revoke_all/2` with audit enabled uses `Multi.run` for `update_all` then `log_multi_safe("api.token_revoke_all", …)` with `metadata_resolver` returning `%{count: n}` only (no token material). `DateTime.utc_now()` values for `:utc_datetime` fields are truncated to seconds. Moduledoc notes `maybe_update_last_used/2` async behavior. `api.token_verify.failure` stays on `log_safe`.
- **`test/sigra/api_token_audit_atomic_test.exs`**: Tests for successful revoke audit, revoke rollback on audit CHECK failure, and `revoke_all` summary row with `metadata["count"] == 2`.

## Verification

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/api_token_audit_atomic_test.exs`
- `grep -q "api.token_revoke_all" lib/sigra/api_token.ex && grep -q "log_multi_safe" lib/sigra/api_token.ex`
