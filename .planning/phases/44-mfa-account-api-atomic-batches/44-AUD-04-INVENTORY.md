# AUD-04 Inventory — Phase 44 (MFA + Account + API token)

**Gathered:** 2026-04-20  
**Upstream slice:** Auth-only rows **AUD-04-001–AUD-04-019** live in [`.planning/phases/43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md`](../43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md). This file continues **AUD-04-020+** for `lib/sigra/mfa.ex`, `lib/sigra/account.ex`, and `lib/sigra/api_token.ex` only.

## Grep log

```text
$ rg -n "Sigra\.Audit\.(log_safe|log_multi_safe|__log_internal__)" lib/sigra/mfa.ex lib/sigra/account.ex lib/sigra/api_token.ex
lib/sigra/account.ex:40:  #   request_email_change  -> Sigra.Audit.log_safe("account.email_change_request", nil, ...)
lib/sigra/account.ex:41:  #   confirm_email_change  -> Sigra.Audit.log_safe("account.email_change_confirm", nil, ...)
lib/sigra/account.ex:42:  #   cancel_email_change   -> Sigra.Audit.log_safe("account.email_change_cancel", nil, ...)
lib/sigra/account.ex:43:  #   change_password       -> Sigra.Audit.log_safe("account.password_change", nil,
lib/sigra/account.ex:45:  #   forced password chg   -> Sigra.Audit.log_safe("account.password_change", nil,
lib/sigra/account.ex:47:  #   schedule_deletion     -> Sigra.Audit.log_safe("account.deletion_schedule", nil, ...)
lib/sigra/account.ex:48:  #   cancel_deletion       -> Sigra.Audit.log_safe("account.deletion_cancel", nil, ...)
lib/sigra/account.ex:49:  #   execute_deletion      -> Sigra.Audit.log_safe("account.deletion_execute", nil, ...)
lib/sigra/account.ex:76:        Sigra.Audit.log_safe(
lib/sigra/account.ex:97:        Sigra.Audit.log_safe(
lib/sigra/account.ex:118:        Sigra.Audit.log_safe(
lib/sigra/account.ex:151:        Sigra.Audit.log_safe(
lib/sigra/account.ex:172:        Sigra.Audit.log_safe(
lib/sigra/account.ex:207:        Sigra.Audit.log_safe(
lib/sigra/account.ex:228:        Sigra.Audit.log_safe(
lib/sigra/account.ex:250:    Sigra.Audit.log_safe(
lib/sigra/account.ex:282:    Sigra.Audit.log_safe(
lib/sigra/api_token.ex:194:          Sigra.Audit.log_safe(
lib/sigra/api_token.ex:211:              Sigra.Audit.log_safe(
lib/sigra/api_token.ex:227:              Sigra.Audit.log_safe(
lib/sigra/api_token.ex:281:            Sigra.Audit.log_safe(
lib/sigra/api_token.ex:310:    Sigra.Audit.log_safe(
lib/sigra/api_token.ex:328:    Sigra.Audit.log_safe(
lib/sigra/mfa.ex:35:  #   enroll success          -> Sigra.Audit.log_safe("mfa.enroll.success", Sigra.Scope.from_config(config, user), ...)
lib/sigra/mfa.ex:36:  #                              (see Sigra.Audit.__log_internal__ for Multi form)
lib/sigra/mfa.ex:37:  #   enroll failure          -> Sigra.Audit.log_safe("mfa.enroll.failure", Sigra.Scope.from_config(config, user), ...)
lib/sigra/mfa.ex:38:  #   verify success (totp)   -> Sigra.Audit.log_safe("mfa.verify.success", Sigra.Scope.from_config(config, user), ...)
lib/sigra/mfa.ex:39:  #   verify success (backup) -> Sigra.Audit.log_safe("mfa.verify.success", Sigra.Scope.from_config(config, user), ...)
lib/sigra/mfa.ex:40:  #                            + Sigra.Audit.log_safe("mfa.backup_code_used", Sigra.Scope.from_config(config, user), ...)
lib/sigra/mfa.ex:41:  #   verify failure          -> Sigra.Audit.log_safe("mfa.verify.failure", Sigra.Scope.from_config(config, user), ...)
lib/sigra/mfa.ex:42:  #   disable                 -> Sigra.Audit.log_safe("mfa.disable", Sigra.Scope.from_config(config, user), ...)
lib/sigra/mfa.ex:43:  #   lockout                 -> Sigra.Audit.log_safe("mfa.lockout", Sigra.Scope.from_config(config, user), ...)
lib/sigra/mfa.ex:181:            Sigra.Audit.log_safe(
lib/sigra/mfa.ex:194:            Sigra.Audit.log_safe(
lib/sigra/mfa.ex:209:        Sigra.Audit.log_safe(
lib/sigra/mfa.ex:286:                  Sigra.Audit.log_safe(
lib/sigra/mfa.ex:305:                  Sigra.Audit.log_safe(
lib/sigra/mfa.ex:320:                    Sigra.Audit.log_safe(
lib/sigra/mfa.ex:383:                  Sigra.Audit.log_safe(
lib/sigra/mfa.ex:392:                  Sigra.Audit.log_safe(
lib/sigra/mfa.ex:460:          Sigra.Audit.log_safe(
lib/sigra/mfa.ex:498:      Sigra.Audit.log_safe(
lib/sigra/mfa.ex:519:  `mfa.backup_codes_regenerate` row is written via `Sigra.Audit.log_multi_safe/3`
lib/sigra/mfa.ex:597:                    |> Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:623:                  Sigra.Audit.log_safe(
lib/sigra/mfa.ex:637:                    Sigra.Audit.log_safe(
lib/sigra/mfa.ex:667:    Sigra.Audit.log_safe(
lib/sigra/mfa.ex:683:    Sigra.Audit.log_safe(
```

## Inventory table

| ID | Boundary (module.function) | action string | mechanism today | tier | REQ batch | Phase | notes |
|----|----------------------------|-----------------|-----------------|------|-----------|-------|-------|
| AUD-04-020 | `Sigra.MFA.confirm_enrollment/5` | `mfa.enroll.success` | `log_safe` (post `Repo.transaction`) | 6 | AUD-06 | 44 | Target **Multi** + `log_multi_safe` / `__log_internal__` per **D-44-03** (plan **44-03**). |
| AUD-04-021 | `Sigra.MFA.confirm_enrollment/5` | `mfa.enroll.failure` | `log_safe` (after failed credential insert) | 7 | AUD-06 | 44 | Failure path after rolled-back txn; evaluate **Multi** vs intentional **log_safe** during **44-03** (no paired success commit). |
| AUD-04-022 | `Sigra.MFA.confirm_enrollment/5` | `mfa.enroll.failure` | `log_safe` (invalid TOTP before DB) | 9 | AUD-06 | 44 | Pure validation — see **EX-44-02** if retained as hybrid. |
| AUD-04-023 | `Sigra.MFA.verify/4` | `mfa.verify.success` | `log_safe` (after `update_all` + lockout reset) | 3 | AUD-06 | 44 | Target **Multi** per **D-44-03** ordering #1 (plan **44-03**). |
| AUD-04-024 | `Sigra.MFA.verify/4` | `mfa.verify.failure` | `log_safe` (after `Lockout.increment`) | 5 | AUD-06 | 44 | Target **Multi** (counter + audit share fate) per **D-44-03** #5. |
| AUD-04-025 | `Sigra.MFA.verify/4` | `mfa.lockout` | `log_safe` (threshold reached) | 4 | AUD-06 | 44 | Target **Multi** with verify-failure row or merged metadata per **D-44-03**. |
| AUD-04-026 | `Sigra.MFA.verify_backup/4` | `mfa.verify.success` | `log_safe` | 3 | AUD-06 | 44 | Second row **AUD-04-027** in same success path — requires **D-44-02** named steps then **Multi** (plan **44-03**). |
| AUD-04-027 | `Sigra.MFA.verify_backup/4` | `mfa.backup_code_used` | `log_safe` | 3 | AUD-06 | 44 | Paired with **AUD-04-026**; dual audit in one txn (plan **44-03**). |
| AUD-04-028 | `Sigra.MFA.disable/4` | `mfa.disable` | `log_safe` (after `cleanup_mfa/5`) | 6 | AUD-06 | 44 | Target audit on **`cleanup_mfa`** **Multi** per **D-44-03** #4. |
| AUD-04-029 | `Sigra.MFA.disable!/4` | `mfa.disable` | `log_safe` (after `cleanup_mfa/5`) | 6 | AUD-06 | 44 | Admin path; same **Multi** pattern as **AUD-04-028**. |
| AUD-04-030 | `Sigra.MFA.regenerate_backup_codes/4` | `mfa.backup_codes_regenerate` | **Multi (`log_multi_safe`)** | 5 | AUD-06 | 44 | Already atomic with rotation (**Phase 41**); verify telemetry still correct after **44-02**. |
| AUD-04-031 | `Sigra.MFA.regenerate_backup_codes/4` | `mfa.verify.failure` | `log_safe` | 5 | AUD-06 | 44 | Failed TOTP on regen path — align with **AUD-04-024** treatment. |
| AUD-04-032 | `Sigra.MFA.regenerate_backup_codes/4` | `mfa.lockout` | `log_safe` | 4 | AUD-06 | 44 | Lockout on regen path — align with **AUD-04-025**. |
| AUD-04-033 | `Sigra.MFA.audit_backup_codes_regenerate/3` | `mfa.backup_codes_regenerate` | `log_safe` | 8 | AUD-06 | 44 | Legacy/ad-hoc helper — see **EX-44-03**; not the authoritative audited rotation path. |
| AUD-04-034 | `Sigra.MFA.audit_trust_browser/2` | `mfa.trust_browser` | `log_safe` | 8 | AUD-06 | 44 | Trust-browser observability; defer **Multi** unless paired domain write is added (see **EX-44-04**). |
| AUD-04-035 | `Sigra.Account.request_email_change/4` | `account.email_change_request` | `log_safe` (after `{:ok, _}`) | 5 | AUD-07 | 44 | Target **Multi** per **D-44-04** (plan **44-04**). |
| AUD-04-036 | `Sigra.Account.confirm_email_change/3` | `account.email_change_confirm` | `log_safe` (after `{:ok, _}`) | 4 | AUD-07 | 44 | Target **Multi** (priority #2 stack). |
| AUD-04-037 | `Sigra.Account.cancel_email_change/3` | `account.email_change_cancel` | `log_safe` (after `{:ok, _}`) | 5 | AUD-07 | 44 | Target **Multi**. |
| AUD-04-038 | `Sigra.Account.change_password/5` | `account.password_change` | `log_safe` (after `{:ok, _}`) | 3 | AUD-07 | 44 | Target **Multi** (priority #1). |
| AUD-04-039 | `Sigra.Account.set_password/4` | `account.password_change` | `log_safe` (after `{:ok, _}`) | 3 | AUD-07 | 44 | Target **Multi** with **AUD-04-038**. |
| AUD-04-040 | `Sigra.Account.schedule_deletion/3` | `account.deletion_schedule` | `log_safe` (after `{:ok, _}`) | 5 | AUD-07 | 44 | Target **Multi**. |
| AUD-04-041 | `Sigra.Account.cancel_deletion/3` | `account.deletion_cancel` | `log_safe` (after `{:ok, _}`) | 5 | AUD-07 | 44 | Target **Multi**. |
| AUD-04-042 | `Sigra.Account.execute_deletion/3` | `account.deletion_execute` | `log_safe` (**before** `Deletion.execute`) | 2 | AUD-07 | 44 | **Must** become shared-fate **Multi** (audit + delete) per **D-44-04** (plan **44-04**). |
| AUD-04-043 | `Sigra.Account.audit_forced_password_change/2` | `account.password_change` | `log_safe` | 7 | AUD-07 | 44 | Audit-only helper after forced change — evaluate **EX-44-05** vs small **Multi** if a domain write is co-located later. |
| AUD-04-044 | `Sigra.APIToken.verify/2` | `api.token_verify.failure` | `log_safe` | 9 | AUD-07 | 44 | Intentional hybrid (volume / read-heavy) — **EX-44-01**; keep unless REQ changes (**D-44-05**). |
| AUD-04-045 | `Sigra.APIToken.verify/2` | `api.token_verify.failure` | `log_safe` | 9 | AUD-07 | 44 | Revoked token branch — same exclusion family as **AUD-04-044**. |
| AUD-04-046 | `Sigra.APIToken.verify/2` | `api.token_verify.failure` | `log_safe` | 9 | AUD-07 | 44 | Expired token branch — same exclusion family as **AUD-04-044**. |
| AUD-04-047 | `Sigra.APIToken.revoke/2` | `api.token_revoke` | `log_safe` (after `repo.update`) | 4 | AUD-07 | 44 | Target **Multi** symmetric to `api.token_create` (**D-44-05**, plan **44-05**). |
| AUD-04-048 | `Sigra.APIToken.audit_jwt_refresh/2` | `api.jwt_refresh` | `log_safe` | 8 | defer AUD-08 | 45 | JWT persistence / refresh work — out of phase **44** per **D-44-05** / **D-44-07** honesty rule. |
| AUD-04-049 | `Sigra.APIToken.audit_jwt_refresh_reuse/2` | `api.jwt_refresh_reuse` | `log_safe` | 8 | defer AUD-08 | 45 | Same deferral as **AUD-04-048**. |

**Note:** `Sigra.APIToken.create/3` uses `Audit.log_multi_safe/3` (qualified alias, not `Sigra.Audit` prefix) and is therefore absent from the grep pattern above; it is already **Multi**-bound and tracked under **AUD-07** / **D-44-05** as the reference pattern for **AUD-04-047**.

## Exclusions appendix

| ID | REQ / control | scope | mechanism | residual risk | compensating control | owner | reopen trigger | evidence | last reviewed |
|----|---------------|-------|-----------|---------------|----------------------|-------|------------------|----------|----------------|
| EX-44-01 | **D-44-05**, **AUD-07** | `Sigra.APIToken.verify/2` → `api.token_verify.failure` (all branches) | `log_safe` | High-volume failure rows may commit if later logic rolls back (classic hybrid) | Telemetry on verify path; rate limits at edge | Sigra | REQ amendment or incident class “durable verify failures required” | `lib/sigra/api_token.ex` | 2026-04-20 |
| EX-44-02 | **D-44-03** | `mfa.enroll.failure` on invalid enrollment code (no DB mutation) | `log_safe` | Forensic gap on rejected enroll attempts | MFA unit tests + telemetry | Sigra | User story needs durable pre-DB enroll failures | `lib/sigra/mfa.ex` | 2026-04-20 |
| EX-44-03 | **D-44-03** | `Sigra.MFA.audit_backup_codes_regenerate/3` | `log_safe` | Callers may omit Multi-backed rotation | Document authoritative path: `regenerate_backup_codes/4` | Sigra | Legacy call sites removed | `@doc` on `audit_backup_codes_regenerate/3` | 2026-04-20 |
| EX-44-04 | **D-44-03** | `Sigra.MFA.audit_trust_browser/2` | `log_safe` | Trust events not co-fated with optional future DB writes | Trust module tests / product analytics stance | Sigra | Trust browser becomes security-critical persistence | `lib/sigra/mfa.ex` | 2026-04-20 |
| EX-44-05 | **D-44-04** | `Sigra.Account.audit_forced_password_change/2` | `log_safe` | Audit-only row; no in-function domain mutation | PasswordChange tests + host call ordering | Sigra | Forced-change flow gains paired Ecto writes in-library | `lib/sigra/account.ex` | 2026-04-20 |

## Priority table (implementation waves)

| Wave | Plan | Delivers |
|------|------|----------|
| B0 | **44-02** | **D-44-02** — `audit_multi_step` (named `Ecto.Multi` audit steps) + telemetry for multiple committed inserts (`Sigra.Audit`). Prerequisite for **AUD-04-026/027**. |
| B1 | **44-03** | **AUD-06** — MFA rows targeting **Multi** in this file (**AUD-04-020–034** except exclusions / already-Multi). |
| B2 | **44-04** | **AUD-07** — Account rows **AUD-04-035–043** per **D-44-04** stack ordering. |
| B3 | **44-05** | **AUD-07** — API token **AUD-04-047**, `revoke_all/2` summary audit (no grep row until implemented), retain **EX-44-01** for **AUD-04-044–046**. |

## Changelog pointer

Release notes should reference this file when **AUD-06 / AUD-07** land for MFA + Account + API token; see repository `CHANGELOG.md` under **[Unreleased]** for the continuation bullet from phase **43**.
