---
phase: 41-backup-codes-ga-product-closure
plan: "04"
requirements-completed: [GA-01]
key-files:
  created:
    - test/example/test/example_web/smoke/backup_code_rotation_test.exs
  modified:
    - docs/uat-ci-coverage.md
completed: 2026-04-20
---

# Phase 41 Plan 04 — GA regression + SEED-7 doc trace

**Outcome:** `Example.BackupCodeRotationTest` proves a consumed backup plaintext no longer verifies after `Accounts.mfa_regenerate_backup_codes/3` with valid TOTP, and invalid TOTP leaves remaining count unchanged. `docs/uat-ci-coverage.md` SEED-7 row cites `example_unit_smoke` and `backup_code_rotation_test.exs`.

## Self-Check: PASSED

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --include example_app test/example_web/smoke/backup_code_rotation_test.exs` (from `test/example`) — PASS

## Deviations

None.
