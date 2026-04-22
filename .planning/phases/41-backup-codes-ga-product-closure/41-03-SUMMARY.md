---
phase: 41-backup-codes-ga-product-closure
plan: "03"
requirements-completed: [GA-01]
key-files:
  created: []
  modified:
    - priv/templates/sigra.install/core/mfa_settings_live.ex
    - priv/templates/sigra.install/core/auth.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/mfa_settings_live.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex
completed: 2026-04-20
---

# Phase 41 Plan 03 — Install template + golden parity

**Outcome:** Core `auth.ex` and `mfa_settings_live.ex` templates ship `mfa_regenerate_backup_codes` and the same regenerate handler as the example. Golden fixture `accounts.ex` and `mfa_settings_live.ex` updated; TODO markers removed.

## Self-Check: PASSED

- Greps for TODO removal and `mfa_regenerate_backup_codes` presence — PASS

## Deviations

None.
