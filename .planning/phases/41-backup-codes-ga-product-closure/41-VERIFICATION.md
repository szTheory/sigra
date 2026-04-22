---
phase: "41"
status: passed
completed: 2026-04-20
---

# Phase 41 verification

## Must-haves

| Item | Evidence |
|------|----------|
| Library `regenerate_backup_codes/4` + transactional replace + optional audit Multi | `lib/sigra/mfa.ex`, `lib/sigra/mfa/backup_codes.ex`; `mix compile --warnings-as-errors` |
| Example Accounts + LiveView + sudo route | `test/example/lib/example/accounts.ex`, `mfa_settings_live.ex`, `router.ex` |
| Install / golden parity | `priv/templates/...`, `test/fixtures/install_golden/...` |
| Automated GA-01 regression | `test/example/test/example_web/smoke/backup_code_rotation_test.exs` with `--include example_app` |
| SEED-7 doc pointer | `docs/uat-ci-coverage.md` |

## Commands run

- `mix compile --warnings-as-errors` (root)
- `cd test/example && mix compile --warnings-as-errors`
- `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --include example_app test/example_web/smoke/backup_code_rotation_test.exs`
- `mix test test/sigra/telemetry_test.exs` (root)

## Notes

- Full `golden_diff_test.exs` run hit ExUnit default timeout in this environment; not treated as a functional regression of these edits.
