---
phase: 39
plan: 02
status: complete
---

# Plan 39-02 — AUD-02 atomic `api.token_create`

## Delivered

- `Sigra.APIToken.do_create/4` refactored to `Ecto.Multi` with
  `Sigra.Audit.log_multi_safe/3`; `Sigra.Audit.emit_telemetry_from_changes/1` on
  `{:ok, changes}` only; scope fields merged like legacy `log_safe/3`.
- `Sigra.APITokenTest.MockRepo` gains `transaction/1` and `insert/2` so existing
  unit tests exercise Multi without Postgres.
- `test/sigra/api_token_audit_atomic_test.exs` — Postgres-backed success +
  rollback (constraint violation) proofs.

## Verification

- `mix test test/sigra/api_token_test.exs test/sigra/api_token_audit_atomic_test.exs` with Postgres env.

## Self-Check: PASSED
