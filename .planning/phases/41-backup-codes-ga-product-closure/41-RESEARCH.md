# Phase 41 — Technical Research

**Phase:** 41 — Backup codes & GA product closure  
**Question:** What must be true in code and tests to ship **GA-01** (rotation + audit + merge-blocking proof)?

---

## Current implementation map

| Area | Finding |
|------|---------|
| **`Sigra.MFA.BackupCodes.regenerate/4`** | `delete_all` then `insert_all` **outside** `Repo.transaction/1`. Failure after delete yields **zero** backup rows — violates GA honesty (D-41-02). |
| **`Sigra.MFA.audit_backup_codes_regenerate/3`** | Uses **`Sigra.Audit.log_safe/3`** after the fact; not tied to DB commit — fails “audit rows match success path” when audit is on (D-41-03). |
| **`MFASettingsLive` (template + example)** | `handle_event("regenerate_codes", ...)` contains **TODO** and **`put_flash(:info, ...)`** without calling **`Auth`** — misleading UX (D-41-05). |
| **Example `router.ex`** | **`live "/settings/mfa", MFASettingsLive`** sits under **`require_authenticated` only**; passkey routes use **`require_sudo`**. **Install golden** already places **`MFASettingsLive`** under **`require_sudo`** — example must align (D-41-01). |
| **`Accounts` example** | Has **`mfa_confirm_enrollment`**, **`mfa_verify`**, **`mfa_disable`**, etc. — **no** `mfa_regenerate_backup_codes` delegate yet. |

---

## Recommended architecture

1. **Library orchestrator:** Add **`Sigra.MFA.regenerate_backup_codes/4`** with `verification` tagged **`{:totp, code}`** (and later **`{:passkey, payload}`**). Sequence: verify step-up → **`Repo.transaction`** wrapping delete+insert; when **`audit_schema`** present, extend **`Ecto.Multi`** with **`Sigra.Audit.log_multi_safe/3`** for **`"mfa.backup_codes_regenerate"`** so audit commits **with** rotation.
2. **TOTP path:** Reuse credential fetch + lockout + **`verify_totp/4`** semantics consistent with **`verify/4`** (same error families). Decide whether to call **`verify/4`** (adds **`mfa.verify.success`** audit) vs internal verify only — document choice in implementation; GA-01 does not mandate duplicate audit if product prefers single **`mfa.backup_codes_regenerate`** row.
3. **Host delegate:** **`Auth.mfa_regenerate_backup_codes(user, verification, opts \\ [])`** merging **`mfa_credential_schema`**, **`backup_code_schema`**, **`sigra_config()`** like **`mfa_disable/2`**.
4. **LiveView:** Replace stub with delegate call; success → assign **`backup_codes`**, **`enrollment_step: :backup_codes`** (or reuse existing render path), **`codes_acknowledged: false`**; refresh **`backup_remaining`** from **`mfa_status/1`**.
5. **GA-01 test:** **`Example.DataCase`** integration module under **`test/example/`** — establish user + MFA + known plaintext codes via **production-equivalent** helpers, assert old code verifies, call **`Accounts.mfa_regenerate_backup_codes`**, assert old plaintext **fails** **`mfa_verify_backup`** (or equivalent) and DB row count/hash changed.

---

## Pitfalls

| Pitfall | Mitigation |
|---------|------------|
| Backup code as rotation proof | **Forbidden** by default (D-41-01); tests must not encode that shortcut. |
| Telemetry span swallowing transaction errors | Keep **`Sigra.Telemetry.span`** around business logic but ensure **transaction return** propagates `{:error, _}` to caller. |
| **`insert_all`** without returning rows | GA-01 cares about **plaintext once**; keep returning **`{:ok, %{backup_codes: list}}`** from orchestrator. |

---

## Validation Architecture (Nyquist)

**Dimension 8 — backup rotation integrity**

| Dimension | Instrument | Signal |
|-----------|------------|--------|
| **Functional** | Example integration test | Old plaintext verifies **before** rotation, **rejects** after |
| **Transactional** | Same test + optional `Ecto.Repo.aggregate` / query | No window where user has **zero** backup rows after failed insert |
| **Audit (when enabled)** | Test with audit schema configured | Row **`mfa.backup_codes_regenerate`** exists **iff** rotation succeeds in same transaction |

**Sampling:** After each wave touching **`lib/sigra`**, run **`MIX_ENV=test mix test test/sigra/mfa/...`** if added; after example wiring, run **`PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example/...backup_code_rotation...`**.

---

## RESEARCH COMPLETE

Sources: **`41-CONTEXT.md`**, **`lib/sigra/mfa/backup_codes.ex`**, **`lib/sigra/mfa.ex`**, **`priv/templates/sigra.install/core/mfa_settings_live.ex`**, **`test/example/lib/example_web/router.ex`**, **`test/fixtures/install_golden/.../router.ex`**, **`test/example/lib/example/accounts.ex`**.
