# AUD-04 Inventory — Phase 44 (MFA + Account + API token)

**Gathered:** 2026-04-20  
**Upstream slice:** Auth-only rows **AUD-04-001–AUD-04-019** live in [`.planning/phases/43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md`](../43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md). This file continues **AUD-04-020+** for `lib/sigra/mfa.ex`, `lib/sigra/account.ex`, and `lib/sigra/api_token.ex` only.

## Grep log

```text
$ rg -n "Sigra\.Audit\.(log_safe|log_multi_safe|__log_internal__)" lib/sigra/mfa.ex lib/sigra/account.ex lib/sigra/api_token.ex
lib/sigra/mfa.ex:36:  #   enroll success          -> `Multi` + `Sigra.Audit.log_multi_safe("mfa.enroll.success", …)` (+ telemetry on `{:ok, changes}`)
lib/sigra/mfa.ex:86:      |> Sigra.Audit.log_multi_safe(action, opts)
lib/sigra/mfa.ex:222:          |> Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:275:        Sigra.Audit.log_safe(
lib/sigra/mfa.ex:351:                    |> Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:378:                    |> Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:394:                        Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:484:                |> Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:493:                |> Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:520:                    |> Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:536:                        Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:688:  `mfa.backup_codes_regenerate` row is written via `Sigra.Audit.log_multi_safe/3`
lib/sigra/mfa.ex:766:                    |> Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:794:                    |> Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:810:                        Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:1074:          Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:1176:      |> Sigra.Audit.log_multi_safe(
lib/sigra/api_token.ex:199:          Sigra.Audit.log_safe(
lib/sigra/api_token.ex:216:              Sigra.Audit.log_safe(
lib/sigra/api_token.ex:232:              Sigra.Audit.log_safe(
lib/sigra/api_token.ex:329:    Sigra.Audit.log_safe(
lib/sigra/api_token.ex:347:    Sigra.Audit.log_safe(
lib/sigra/account.ex:37:  # D-26 dispatch table (Phase 44 AUD-07 — `Ecto.Multi` + `Sigra.Audit.log_multi_safe`
lib/sigra/account.ex:49:  # `audit_forced_password_change/2` remains `Sigra.Audit.log_safe/3` (audit-only helper).
lib/sigra/account.ex:123:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:163:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:215:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:255:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:294:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:346:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:383:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:427:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:439:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:499:    Sigra.Audit.log_safe(
```

## Inventory table

| ID | Boundary (module.function) | action string | mechanism today | tier | REQ batch | Phase | notes |
|----|----------------------------|-----------------|-----------------|------|-----------|-------|-------|
| AUD-04-020 | `Sigra.MFA.confirm_enrollment/5` | `mfa.enroll.success` | **`Multi` + `log_multi_safe`** (same enrollment `Repo.transaction/1` as credential + backup codes) | 5 | AUD-06 | 66 | **Phase 66** — **`AUD-09`** / **SEED-002**; evidence **`test/sigra/mfa_audit_atomicity_test.exs`**. |
| AUD-04-021 | `Sigra.MFA.confirm_enrollment/5` | `mfa.enroll.failure` (`insert_failed`) | **`Multi` + `log_multi_safe`** (dedicated follow-up `Repo.transaction/1` after enrollment `Multi` rolls back or credential/backup persistence raises) | 5 | AUD-06 | 66 | **Phase 66** — **`AUD-09`**; failure audit not co-fated with rolled-back enrollment writes by design. |
| AUD-04-022 | `Sigra.MFA.confirm_enrollment/5` | `mfa.enroll.failure` | **`log_safe`** (invalid TOTP before DB) | 9 | AUD-06 | 44 | **EX-44-02** — unchanged in phase **66** (**066-CONTEXT D-02**). |
| AUD-04-023 | `Sigra.MFA.verify/4` | `mfa.verify.success` | **`Multi` + `log_multi_safe`** (`Multi.update_all` + audit in one `Repo.transaction/1`) | 3 | AUD-06 | 73 | **Phase 73** — **`AUD-11`**; evidence **`test/sigra/mfa_audit_atomicity_test.exs`** + **`lib/sigra/mfa.ex`**. |
| AUD-04-024 | `Sigra.MFA.verify/4` | `mfa.verify.failure` | **`Multi` + `log_multi_safe`** (`Lockout.increment` + audit) | 5 | AUD-06 | 73 | **Phase 73** — same txn as counter increment; **`lib/sigra/mfa.ex`**. |
| AUD-04-025 | `Sigra.MFA.verify/4` | `mfa.lockout` | **`Multi` + `log_multi_safe`** (`Multi.merge` lockout append) | 4 | AUD-06 | 73 | **Phase 73** — **`lib/sigra/mfa.ex`**. |
| AUD-04-026 | `Sigra.MFA.verify_backup/4` | `mfa.verify.success` | **`Multi` + `log_multi_safe`** | 3 | AUD-06 | 73 | **Phase 73** — paired **AUD-04-027**; consume txn (**AUD-11**). |
| AUD-04-027 | `Sigra.MFA.verify_backup/4` | `mfa.backup_code_used` | **`Multi` + `log_multi_safe`** | 3 | AUD-06 | 73 | **Phase 73** — paired with **AUD-04-026**. |
| AUD-04-067 | `Sigra.MFA.verify_backup/4` | `mfa.verify.failure` | **`Multi` + `log_multi_safe`** (invalid backup / `:consume` miss); optional **`mfa.lockout`** in same txn at threshold | 5 | AUD-01 | 61 | **Phase 61** — parity with **`verify/4`** failure **`Multi`** (**AUD-01**); phase **73** verification receipts extend **023–032** band. |
| AUD-04-028 | `Sigra.MFA.disable/4` | `mfa.disable` | **`Multi` + `log_multi_safe`** (`cleanup_mfa/6` + deletes + trust revoke) | 6 | AUD-06 | 73 | **Phase 73** — **`lib/sigra/mfa.ex`**. |
| AUD-04-029 | `Sigra.MFA.disable!/4` | `mfa.disable` | **`Multi` + `log_multi_safe`** (admin `cleanup_mfa/6` path) | 6 | AUD-06 | 73 | **Phase 73** — same pattern as **AUD-04-028**. |
| AUD-04-030 | `Sigra.MFA.regenerate_backup_codes/4` | `mfa.backup_codes_regenerate` | **`Multi` + `log_multi_safe`** (replace + audit one txn) | 5 | AUD-06 | 73 | **Phase 73** — rotation atomicity (**AUD-11**); **`lib/sigra/mfa.ex`**. |
| AUD-04-031 | `Sigra.MFA.regenerate_backup_codes/4` | `mfa.verify.failure` | **`Multi` + `log_multi_safe`** (wrong TOTP on regen path) | 5 | AUD-06 | 73 | **Phase 73** — **`lib/sigra/mfa.ex`**. |
| AUD-04-032 | `Sigra.MFA.regenerate_backup_codes/4` | `mfa.lockout` | **`Multi` + `log_multi_safe`** (`Multi.merge` on regen failure path) | 4 | AUD-06 | 73 | **Phase 73** — **`lib/sigra/mfa.ex`**. |
| AUD-04-033 | `Sigra.MFA.audit_backup_codes_regenerate/3` | `mfa.backup_codes_regenerate` | **`Repo.transaction/1`** on **`Multi` + `log_multi_safe`** (`:audit_mfa_backup_codes_regenerate_adhoc`) | 8 | AUD-06 | **77** | Ad-hoc helper — **phase 77** / **AUD-13**; authoritative rotation path remains **`regenerate_backup_codes/4`** (**EX-44-03** compensating control unchanged). |
| AUD-04-034 | `Sigra.MFA.audit_trust_browser/2` | `mfa.trust_browser` | **`Repo.transaction/1`** on **`Multi` + `log_multi_safe`** (`:audit_mfa_trust_browser_adhoc`) | 8 | AUD-06 | **77** | **Phase 77** / **AUD-13**; still no paired domain write in-library (**EX-44-04** stance). |
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
| EX-44-03 | **D-44-03** | `Sigra.MFA.audit_backup_codes_regenerate/3` | **`Multi` + `log_multi_safe`** in dedicated txn (phase **77**) | Callers may still omit library rotation — prefer `regenerate_backup_codes/4` | Document authoritative path: `regenerate_backup_codes/4` | Sigra | Legacy call sites removed | `@doc` on `audit_backup_codes_regenerate/3` | 2026-04-24 |
| EX-44-04 | **D-44-03** | `Sigra.MFA.audit_trust_browser/2` | **`Multi` + `log_multi_safe`** in dedicated txn (phase **77**) | Trust events still not co-fated with in-library DB writes | Trust module tests / product analytics stance | Sigra | Trust browser becomes security-critical persistence | `lib/sigra/mfa.ex` | 2026-04-24 |
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

**Note — Phase 73 (2026-04-24):** **`lib/sigra/mfa.ex`** is already **Multi**-first for **AUD-04-023–032**; phase **73** closed planning drift versus legacy **44-03** “target Multi” language and shipped **CHECK** rollback receipts in **`test/sigra/mfa_audit_atomicity_test.exs`**.

**Note — Phase 77 (2026-04-24):** **`audit_backup_codes_regenerate/3`** and **`audit_trust_browser/2`** now use **`commit_ad_hoc_mfa_audit/5`** (**`Repo.transaction/1`** + **`log_multi_safe`**) when `:audit_schema` is set — **AUD-04-033** / **034** align with **T1** in **`09-VERIFICATION.md`**; **`mfa.enroll.failure`** invalid-code (**AUD-04-022**) remains **`log_safe`** (**EX-44-02**).

OAuth, operational security helpers (`Lockout`, `SuspiciousLogin`, `Impersonation`), and the account-deletion worker continue in [`.planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md`](../45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md) (**AUD-04-050+**, **AUD-08** batch).

**Note — Phase 61 (2026-04-23):** **`verify_backup/4`** invalid-backup / wrong-code path (**`AUD-04-067`**) now shares **`Lockout.increment`** fate with **`mfa.verify.failure`** (+ optional **`mfa.lockout`**) via **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** (**AUD-01**). Evidence: **`test/sigra/mfa_audit_atomicity_test.exs`**.

**Note — Phase 66 (2026-04-23):** **`confirm_enrollment/5`** — **`AUD-04-020`** success audit is **`Multi` + `log_multi_safe`** inside the enrollment transaction; **`AUD-04-021`** **`mfa.enroll.failure`** / **`insert_failed`** uses a follow-up **`Repo.transaction(Multi + log_multi_safe)`** after the enrollment **`Multi`** rolls back (**AUD-09**). **`AUD-04-022`** remains **`log_safe`** under **EX-44-02**. Evidence: **`test/sigra/mfa_audit_atomicity_test.exs`**.
