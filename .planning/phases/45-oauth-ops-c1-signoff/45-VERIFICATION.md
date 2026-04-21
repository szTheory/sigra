---
status: draft
phase: "45"
---

# Phase 45 verification — AUD-08 (OAuth + ops + workers)

## Must-haves (AUD-08 — OAuth + ops + workers)

| Item | Evidence |
|------|----------|
| AUD-04 inventory rows (**AUD-04-050+**) | `45-AUD-04-INVENTORY.md` callback mutation block (**AUD-04-050**, **AUD-04-051**), main table (**AUD-04-052**–**AUD-04-066**), exclusions appendix (**EX-45-***), and priority table (waves **45-01**–**45-06**) |
| OAuth orchestration + callback **`log_multi_safe`** | `test/sigra/oauth/` (e.g. `oauth_audit_atomicity_test.exs`); `45-02-SUMMARY.md` |
| Lockout, suspicious login, impersonation alignment with **`Auth`** | `45-03-SUMMARY.md`; `test/sigra/auth/login_and_lockout_audit_atomicity_test.exs`, `test/sigra/lockout_test.exs`, `test/sigra/suspicious_login_test.exs`, `test/sigra/impersonation_test.exs` |
| Account deletion worker + **`account.deletion_executed`** | `45-04-SUMMARY.md`; `test/sigra/workers/account_deletion_test.exs`, `test/sigra/account/deletion_test.exs` |
| Phase 9 / audit semantics documentation | `45-05-SUMMARY.md`; `docs/audit-semantics.md` linkage |
| Scoped AUD-08 atomicity closure | `45-06-SUMMARY.md`; **`mix ci.audit_45`** path bundle (OAuth subtree + workers + account + lockout + impersonation + MFA/API proofs) |
| Living validation map | `45-VALIDATION.md` Per-Task Verification Map (`nyquist_compliant: true` at sign-off) |

## Merge gate

Compound proof (Postgres at `localhost:5432`, `postgres`/`postgres` per `CLAUDE.md`):

1. `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix compile`
2. `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci.audit_45`

## Release attestation (optional)

Full root `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` — **Not run in this closure** (merge gate is **`mix compile`** + **`mix ci.audit_45`**; full root suite remains optional per `45-06-SUMMARY.md`).

## Automated checks run

*(Filled after merge gate — see plan 49-01 Task 3.)*

1. `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix compile` — **PENDING**
2. `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci.audit_45` — **PENDING**

## Notes

- Full Nyquist batch **41–44** remains **phase 50** ownership; this verification closes falsifiable **AUD-08** evidence for phase **45** only.
- Git SHA at verification time: *(pending merge gate)*
