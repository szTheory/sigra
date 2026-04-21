---
status: draft
phase: "43"
---

# Phase 43 verification — AUD-04 inventory + AUD-05 Auth atomicity

## Must-haves

| Item | Evidence |
|------|----------|
| AUD-04 inventory rows | `43-AUD-04-INVENTORY.md` priority table + scope cut (Plan 04); aligned with `43-01-SUMMARY.md` |
| AUD-05 B1 register atomicity | `test/sigra/auth/register_audit_atomicity_test.exs`; `43-02-SUMMARY.md` |
| AUD-05 B2 magic link + reset atomicity | `test/sigra/auth/magic_link_and_reset_request_audit_atomicity_test.exs`; `43-03-SUMMARY.md` |
| AUD-05 B3 login / lockout atomicity | `test/sigra/auth/login_and_lockout_audit_atomicity_test.exs`; `43-04-SUMMARY.md` |
| Auth core regression + hybrid documentation | `test/sigra/auth_test.exs`; inventory exclusions / tier-9 notes in `43-AUD-04-INVENTORY.md` |
| Validation map honesty | `43-VALIDATION.md` Per-Task Verification Map (literal paths, `nyquist_compliant: false`) |

## Merge gate

Compound proof (Postgres at `localhost:5432`, `postgres`/`postgres` per `CLAUDE.md`):

1. `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix compile`
2. `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth/register_audit_atomicity_test.exs test/sigra/auth/magic_link_and_reset_request_audit_atomicity_test.exs test/sigra/auth/login_and_lockout_audit_atomicity_test.exs test/sigra/auth_test.exs`

*(Results recorded under **Automated checks run** after Task 3.)*

## Release attestation (optional)

Full root `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` — **Not run in this closure** (merge gate is the scoped compound command above; see phase **46** pattern for tiered gates).

## Notes

- Full Nyquist batch **41–44** remains **phase 50** ownership; this verification closes falsifiable AUD-04/AUD-05 evidence for phase **43** only.
- Git SHA at verification time: *(recorded when merge gate completes — Task 3.)*
