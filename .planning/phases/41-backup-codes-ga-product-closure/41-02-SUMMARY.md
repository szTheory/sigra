---
phase: 41-backup-codes-ga-product-closure
plan: "02"
requirements-completed: [GA-01]
key-files:
  created: []
  modified:
    - test/example/lib/example/accounts.ex
    - test/example/lib/example_web/live/mfa_settings_live.ex
    - test/example/lib/example_web/router.ex
completed: 2026-04-20
---

# Phase 41 Plan 02 — Example host wiring

**Outcome:** `Example.Accounts.mfa_regenerate_backup_codes/3` delegates to the library with schema opts and impersonation guard. MFA settings route moved under `pipe_through` including `:require_sudo` in a dedicated `live_session`. `MFASettingsLive` calls the delegate with `{:totp, code}` and maps success and error tuples to honest flashes and assigns.

## Self-Check: PASSED

- `cd test/example && mix compile --warnings-as-errors` — PASS

## Deviations

None.
