---
phase: 82
plan: "02"
status: complete
---

# Plan 82-02 — Postgres co-fate tests

## Outcome

Added **`test/sigra/jwt_refresh_audit_cofate_test.exs`** (`async: false`): happy path + audit, audit-off, happy-path **`CHECK`** guard → **`:jwt_refresh_aborted`**, reuse + audit row, reuse audit guard → **`:jwt_refresh_aborted`** with **`raw2`** still refreshable after rollback.

## Self-Check: PASSED

- `MIX_ENV=test mix compile --warnings-as-errors`
- Postgres: run **`PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/jwt_refresh_audit_cofate_test.exs`** before release (orchestrator host lacked **`postgres`** role).

## Deviations

None.
