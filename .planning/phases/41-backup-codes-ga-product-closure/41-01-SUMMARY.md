---
phase: 41-backup-codes-ga-product-closure
plan: "01"
requirements-completed: [GA-01]
key-files:
  created: []
  modified:
    - lib/sigra/mfa.ex
    - lib/sigra/mfa/backup_codes.ex
completed: 2026-04-20
---

# Phase 41 Plan 01 — Library backup-code rotation

**Outcome:** `Sigra.MFA.regenerate_backup_codes/4` verifies TOTP, runs delete+insert backup rows in one `Repo.transaction/1`, optionally appends `mfa.backup_codes_regenerate` on the same `Ecto.Multi` via `Sigra.Audit.log_multi_safe/3`, and syncs credential lockout/replay fields. `BackupCodes.regenerate/4` now wraps the replace in a transaction; `append_replace_steps/4-5` composes the Multi for reuse.

## Self-Check: PASSED

- `mix compile --warnings-as-errors` (repo root) — PASS

## Deviations

None.
