# Phase 41 — Pattern Map

**Analog files** for executor `read_first` alignment.

| Role | Target (new / heavy edit) | Analog (existing) |
|------|---------------------------|-------------------|
| MFA delegate in host `Accounts` | `test/example/lib/example/accounts.ex` | **`mfa_disable/2`**, **`mfa_confirm_enrollment/4`** — same **`Keyword.merge`** of schemas + **`sigra_config()`** |
| LiveView success envelope | `test/example/lib/example_web/live/mfa_settings_live.ex` | **`do_confirm_enrollment/2`** branch **`{:ok, %{backup_codes: codes}}`** → assigns **`enrollment_step`**, **`backup_codes`** |
| Atomic MFA + DB writes | `lib/sigra/mfa.ex` | **`confirm_enrollment/5`** — **`Ecto.Multi`** + **`repo.transaction`** |
| Audit inside Multi | `lib/sigra/audit.ex` | **`Sigra.Audit.log_multi_safe/3`** + post-commit **`emit_telemetry_from_changes/1`** where other Multi paths do |
| Router sudo for MFA settings | `test/example/lib/example_web/router.ex` | **`test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex`** lines **117–122** (`require_sudo` + **`MFASettingsLive`**) |
| Generator LiveView parity | `priv/templates/sigra.install/core/mfa_settings_live.ex` | **`test/example/lib/example_web/live/mfa_settings_live.ex`** (mirror diff) |

**Data flow (target):**

`MFASettingsLive` → **`Accounts.mfa_regenerate_backup_codes/3`** → **`Sigra.MFA.regenerate_backup_codes/4`** → **`Repo.transaction(Multi)`** → **`BackupCodes`** delete+insert (+ optional **`log_multi_safe`**).
