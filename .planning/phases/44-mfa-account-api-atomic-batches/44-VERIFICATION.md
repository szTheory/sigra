---
status: draft
phase: "44"
---

# Phase 44 verification — AUD-06 MFA + AUD-07 Account / API token atomicity

## Must-haves (AUD-06 — MFA)

| Item | Evidence |
|------|----------|
| Inventory slice for MFA boundaries | `44-AUD-04-INVENTORY.md` rows **AUD-04-020**–**AUD-04-034** (MFA / `Sigra.MFA` scope) |
| Postgres atomicity for MFA success + paired failure paths | `test/sigra/mfa_audit_atomicity_test.exs` |
| Named Multi audit steps + telemetry plumbing | `test/sigra/audit_multi_step_test.exs`; `44-02-SUMMARY.md` |
| Plan 44-03 delivery narrative | `44-03-SUMMARY.md` |

## Must-haves (AUD-07 — Account + API)

| Item | Evidence |
|------|----------|
| Inventory slice for Account + API token boundaries | `44-AUD-04-INVENTORY.md` rows **AUD-04-035**–**AUD-04-047** (Account / `Sigra.APIToken` revoke family) |
| Account mutations + audit shared fate | `test/sigra/account_audit_atomicity_test.exs`; `44-04-SUMMARY.md` |
| Token revoke / revoke_all + audit | `test/sigra/api_token_audit_atomic_test.exs`; `44-05-SUMMARY.md` |
| Validation map honesty | `44-VALIDATION.md` Per-Task Verification Map (literal `PGUSER=… mix test` paths; `nyquist_compliant: false`) |

## Merge gate

Compound proof (Postgres at `localhost:5432`, `postgres`/`postgres` per `CLAUDE.md`):

1. `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix compile`
2. `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs test/sigra/account_audit_atomicity_test.exs test/sigra/api_token_audit_atomic_test.exs test/sigra/audit_multi_step_test.exs`

## Release attestation (optional)

Full root `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` — **Not run in this closure** (merge gate is the scoped compound command above).

## Automated checks run

_Pending merge gate (Task 3)._

## Notes

- Full Nyquist batch **41–44** remains **phase 50** ownership; this verification closes falsifiable **AUD-06** / **AUD-07** evidence for phase **44** only (**D-48-03**).
- No Mix alias in this closure — raw compound `mix test` is canonical.
- Git SHA at verification time: _pending Task 3._
