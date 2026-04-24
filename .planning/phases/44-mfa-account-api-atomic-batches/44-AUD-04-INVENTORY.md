# AUD-04 Inventory — Phase 44 (MFA + Account + API token)

**Gathered:** 2026-04-20  
**Upstream slice:** Auth-only rows **AUD-04-001–AUD-04-019** live in [`.planning/phases/43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md`](../43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md). This file continues **AUD-04-020+** for `lib/sigra/mfa.ex`, `lib/sigra/account.ex`, and `lib/sigra/api_token.ex` only.

## Grep log

```text
$ rg -n "Sigra\.Audit\.(log_safe|log_multi_safe|__log_internal__)" lib/sigra/mfa.ex lib/sigra/account.ex lib/sigra/api_token.ex
lib/sigra/mfa.ex:36:  #   enroll success          -> `Multi` + `Sigra.Audit.log_multi_safe("mfa.enroll.success", …)` (+ telemetry on `{:ok, changes}`)
lib/sigra/mfa.ex:86:      |> Sigra.Audit.log_multi_safe(action, opts)
lib/sigra/mfa.ex:237:          |> Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:290:        Sigra.Audit.log_safe(
lib/sigra/mfa.ex:366:                    |> Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:393:                    |> Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:409:                        Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:499:                |> Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:508:                |> Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:535:                    |> Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:551:                        Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:703:  `mfa.backup_codes_regenerate` row is written via `Sigra.Audit.log_multi_safe/3`
lib/sigra/mfa.ex:781:                    |> Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:809:                    |> Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:825:                        Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:870:  `Sigra.Audit.log_multi_safe/3` inside `Repo.transaction/1` when `:audit_schema`
lib/sigra/mfa.ex:891:  `Sigra.Audit.log_multi_safe/3` inside `Repo.transaction/1` when `:audit_schema`
lib/sigra/mfa.ex:1089:          Sigra.Audit.log_multi_safe(
lib/sigra/mfa.ex:1191:      |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:38:  # D-26 dispatch table (Phase 44 AUD-07 — `Ecto.Multi` + `Sigra.Audit.log_multi_safe`
lib/sigra/account.ex:51:  # `audit_forced_password_change/2` is **deprecated** — legacy `Sigra.Audit.log_safe/3` only.
lib/sigra/account.ex:126:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:166:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:218:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:258:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:297:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:341:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:393:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:430:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:474:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:486:        |> Sigra.Audit.log_multi_safe(
lib/sigra/account.ex:550:    Sigra.Audit.log_safe(
(no matches in lib/sigra/api_token.ex for `Sigra.Audit.*` — module aliases `Sigra.Audit` as `Audit`)
$ rg -n "Audit\.(log_safe|log_multi_safe)" lib/sigra/api_token.ex
lib/sigra/api_token.ex:129:      |> Audit.log_multi_safe("api.token_create", audit_opts)
lib/sigra/api_token.ex:213:          |> Audit.log_multi_safe(
lib/sigra/api_token.ex:256:          |> Audit.log_multi_safe(action, opts)
lib/sigra/api_token.ex:448:          |> Audit.log_multi_safe("api.token_revoke", audit_opts)
lib/sigra/api_token.ex:583:        |> Audit.log_multi_safe("api.token_revoke_all", audit_opts)
```

## Inventory table

| ID | Boundary (module.function) | action string | mechanism today | tier | REQ batch | Phase | notes |
|----|----------------------------|-----------------|-----------------|------|-----------|-------|-------|
| AUD-04-020 | `Sigra.MFA.confirm_enrollment/5` | `mfa.enroll.success` | **`Multi` + `log_multi_safe`** (same enrollment `Repo.transaction/1` as credential + backup codes) | 5 | AUD-06 | 66 | **Phase 66** — **`AUD-09`** / **SEED-002**; evidence **`test/sigra/mfa_audit_atomicity_test.exs`**. |
| AUD-04-021 | `Sigra.MFA.confirm_enrollment/5` | `mfa.enroll.failure` (`insert_failed`) | **`Multi` + `log_multi_safe`** (dedicated follow-up `Repo.transaction/1` after enrollment `Multi` rolls back or credential/backup persistence raises) | 5 | AUD-06 | 66 | **Phase 66** — **`AUD-09`**; failure audit not co-fated with rolled-back enrollment writes by design. |
| AUD-04-022 | `Sigra.MFA.confirm_enrollment/5` | `mfa.enroll.failure` | **`Repo.transaction/1`** on **`Ecto.Multi` + `Sigra.Audit.log_multi_safe`** (via **`commit_ad_hoc_mfa_audit/5`**) when `:audit_schema` | 9 | AUD-06 | **83** | **Phase 83** (2026-04-24) supersedes **073-CONTEXT D-05** waiver narrative for **022** only; **EX-44-02** appendix retired for this slice (historical **`log_safe`** note retained for **066/067**). |
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
| AUD-04-035 | `Sigra.Account.request_email_change/4` | `account.email_change_request` | **`Multi` + `log_multi_safe`** (same `Repo.transaction/1` as `Multi.run(:domain, …)`) | 5 | AUD-07 | **78** | **`lib/sigra/account.ex`**; phase **78** inventory + C-1 truth (**AUD-14**). |
| AUD-04-036 | `Sigra.Account.confirm_email_change/3` | `account.email_change_confirm` | **`Multi` + `log_multi_safe`** | 4 | AUD-07 | **78** | **`lib/sigra/account.ex`**; phase **78** (**AUD-14**). |
| AUD-04-037 | `Sigra.Account.cancel_email_change/3` | `account.email_change_cancel` | **`Multi` + `log_multi_safe`** | 5 | AUD-07 | **78** | **`lib/sigra/account.ex`**; phase **78** (**AUD-14**). |
| AUD-04-038 | `Sigra.Account.change_password/5` | `account.password_change` | **`Multi` + `log_multi_safe`** | 3 | AUD-07 | **78** | **`lib/sigra/account.ex`**; **`test/sigra/account_audit_atomicity_test.exs`** (**AUD-14**). |
| AUD-04-039 | `Sigra.Account.set_password/4` | `account.password_change` | **`Multi` + `log_multi_safe`** | 3 | AUD-07 | **78** | **`lib/sigra/account.ex`**; **`test/sigra/account_audit_atomicity_test.exs`**. |
| AUD-04-040 | `Sigra.Account.schedule_deletion/3` | `account.deletion_schedule` | **`Multi` + `log_multi_safe`** | 5 | AUD-07 | **78** | **`lib/sigra/account.ex`**; phase **78** (**AUD-14**). |
| AUD-04-041 | `Sigra.Account.cancel_deletion/3` | `account.deletion_cancel` | **`Multi` + `log_multi_safe`** | 5 | AUD-07 | **78** | **`lib/sigra/account.ex`**; phase **78** (**AUD-14**). |
| AUD-04-042 | `Sigra.Account.execute_deletion/3` | `account.deletion_execute` + `account.deletion_executed` | **`Multi` + `log_multi_safe`** (two audit steps + `Deletion.execute` in `Multi.run`) | 2 | AUD-07 | **78** | **`lib/sigra/account.ex`**; **`test/sigra/account_audit_atomicity_test.exs`** (`deletion_execute` CHECK guard). |
| AUD-04-043 | `Sigra.Account.clear_password_change_requirement/3` | `account.password_change` | **`Multi` + `log_multi_safe`** | 7 | AUD-07 | **80** | **Phase 80** — **`AUD-17`**; paired **`must_change_password`** clear + audit; **`audit_forced_password_change/2`** deprecated (**`log_safe`** legacy only). Evidence **`test/sigra/account_audit_atomicity_test.exs`**. |
| AUD-04-044 | `Sigra.APIToken.verify/2` | `api.token_verify.failure` | **`Repo.transaction/1`** on audit-only **`Multi` + `log_multi_safe`** | 9 | AUD-07 | **79** | **AUD-16**; **EX-44-01** verify-failure slice retired (**2026-04-24**). |
| AUD-04-045 | `Sigra.APIToken.verify/2` | `api.token_verify.failure` | **`Repo.transaction/1`** on audit-only **`Multi` + `log_multi_safe`** | 9 | AUD-07 | **79** | Revoked branch — same as **044**. |
| AUD-04-046 | `Sigra.APIToken.verify/2` | `api.token_verify.failure` | **`Repo.transaction/1`** on audit-only **`Multi` + `log_multi_safe`** | 9 | AUD-07 | **79** | Expired branch — same as **044**. |
| AUD-04-047 | `Sigra.APIToken.revoke/2` | `api.token_revoke` | **`Multi` + `Audit.log_multi_safe`** (`config.repo.transaction/1`) | 4 | AUD-07 | **78** | **`lib/sigra/api_token.ex`**; **`test/sigra/api_token_audit_atomic_test.exs`** (**AUD-14**). |
| AUD-04-048 | **`Sigra.JWT.refresh/3`**; **`Sigra.APIToken.audit_jwt_refresh/2`** | `api.jwt_refresh` | When **`:audit_schema`**: **`Sigra.JWT.refresh/3`** — one **`Repo.transaction/1`** on **`Ecto.Multi`** composing **`user_tokens`** rotation + **`Audit.log_multi_safe`** (`append_api_token_jwt_audit_to_multi`). Standalone **`audit_jwt_refresh/2`** — **`Repo.transaction/1`** on audit-only **`Multi` + `log_multi_safe`** (**phase 81** / **AUD-18**). | 8 | AUD-08 (co-fate via **`JWT.refresh`**) | **82** | **2026-04-24** supersession: **81** = audit-only helper txn; **82** = **AUD-08** persistence + audit co-fate for **`JWT.refresh`**. Evidence: **`test/sigra/jwt_refresh_audit_cofate_test.exs`**, **`lib/sigra/jwt.ex`**, **`lib/sigra/api_token.ex`**. **T1** for the guided path = rotation + **`api.jwt_refresh`** commit or roll back together. |
| AUD-04-049 | **`Sigra.JWT.refresh/3`**; **`Sigra.APIToken.audit_jwt_refresh_reuse/2`** | `api.jwt_refresh_reuse` | When **`:audit_schema`**: **`Sigra.JWT.refresh/3`** reuse branch — one **`Repo.transaction/1`** on **`Ecto.Multi`** composing family **`user_tokens`** revocation + **`Audit.log_multi_safe`** for **`api.jwt_refresh_reuse`**. Standalone **`audit_jwt_refresh_reuse/2`** — audit-only **`Multi`** (**phase 81**). | 8 | AUD-08 (co-fate via **`JWT.refresh`**) | **82** | Same supersession as **048**; evidence **`jwt_refresh_audit_cofate_test.exs`**. |

**Note:** `Sigra.APIToken.create/3` uses `Audit.log_multi_safe/3` (qualified alias, not `Sigra.Audit` prefix) and is therefore absent from the grep pattern above; it is already **Multi**-bound and tracked under **AUD-07** / **D-44-05** as the reference pattern for **AUD-04-047**.

## Exclusions appendix

| ID | REQ / control | scope | mechanism | residual risk | compensating control | owner | reopen trigger | evidence | last reviewed |
|----|---------------|-------|-----------|---------------|----------------------|-------|------------------|----------|----------------|
| EX-44-01 | **D-44-05**, **AUD-07** | `Sigra.APIToken.verify/2` → `api.token_verify.failure` (all branches) | **Retired for 044–046 (phase 79)** — was `log_safe` | Historical: classic hybrid gap for failure-only audits | **Phase 79:** transactional **`log_multi_safe`** + **`log_safe_error`** on changeset / constraint insert failure | Sigra | *Closed 2026-04-24* — **AUD-16** | `lib/sigra/api_token.ex`; `test/sigra/api_token_audit_atomic_test.exs` | 2026-04-24 |
| EX-44-02 | **D-44-03** | `mfa.enroll.failure` on invalid enrollment code (no DB mutation) | **Retired for 022 slice (phase 83, 2026-04-24)** — was **`log_safe`**; now **`Repo.transaction/1` + `Multi` + `log_multi_safe`** via **`commit_ad_hoc_mfa_audit/5`** when `:audit_schema` | *Historical:* pre-83 **`log_safe`** gap on rejected enroll attempts | MFA unit tests + **`[:sigra, :audit, :log_safe_error]`** telemetry | Sigra | *022 closed* — **AUD-20** | `lib/sigra/mfa.ex`; `test/sigra/mfa_audit_atomicity_test.exs` | 2026-04-24 |
| EX-44-03 | **D-44-03** | `Sigra.MFA.audit_backup_codes_regenerate/3` | **`Multi` + `log_multi_safe`** in dedicated txn (phase **77**) | Callers may still omit library rotation — prefer `regenerate_backup_codes/4` | Document authoritative path: `regenerate_backup_codes/4` | Sigra | Legacy call sites removed | `@doc` on `audit_backup_codes_regenerate/3` | 2026-04-24 |
| EX-44-04 | **D-44-03** | `Sigra.MFA.audit_trust_browser/2` | **`Multi` + `log_multi_safe`** in dedicated txn (phase **77**) | Trust events still not co-fated with in-library DB writes | Trust module tests / product analytics stance | Sigra | Trust browser becomes security-critical persistence | `lib/sigra/mfa.ex` | 2026-04-24 |
| EX-44-05 | **D-44-04** | `Sigra.Account.clear_password_change_requirement/3` | **`Multi` + `log_multi_safe`** | *Closed 2026-04-24* — paired domain + audit in-library | Hosts migrate off standalone **`audit_forced_password_change/2`** for the same completion | Sigra | *Closed* — **phase 80** / **AUD-17** | `lib/sigra/account.ex`; `test/sigra/account_audit_atomicity_test.exs` | 2026-04-24 |

## Priority table (implementation waves)

| Wave | Plan | Delivers |
|------|------|----------|
| B0 | **44-02** | **D-44-02** — `audit_multi_step` (named `Ecto.Multi` audit steps) + telemetry for multiple committed inserts (`Sigra.Audit`). Prerequisite for **AUD-04-026/027**. |
| B1 | **44-03** | **AUD-06** — MFA rows targeting **Multi** in this file (**AUD-04-020–034** except exclusions / already-Multi). |
| B2 | **44-04** | **AUD-07** — Account rows **AUD-04-035–043** per **D-44-04** stack ordering. |
| B3 | **44-05** | **AUD-07** — API token **AUD-04-047**, `revoke_all/2` summary audit (no grep row until implemented); **EX-44-01** verify slice retired by **phase 79** (**AUD-04-044–046**). |

## Changelog pointer

Release notes should reference this file when **AUD-06 / AUD-07** land for MFA + Account + API token; see repository `CHANGELOG.md` under **[Unreleased]** for the continuation bullet from phase **43**.

**Note — Phase 73 (2026-04-24):** **`lib/sigra/mfa.ex`** is already **Multi**-first for **AUD-04-023–032**; phase **73** closed planning drift versus legacy **44-03** “target Multi” language and shipped **CHECK** rollback receipts in **`test/sigra/mfa_audit_atomicity_test.exs`**.

**Note — Phase 79 (2026-04-24):** **`Sigra.APIToken.verify/2`** failure paths (**AUD-04-044..046**) use **`Repo.transaction/1`** + audit-only **`Multi` + `log_multi_safe`** when `:audit_schema` is set (**AUD-16**); **EX-44-01** appendix row marked retired for this slice.

**Note — Phase 80 (2026-04-24):** **`Sigra.Account.clear_password_change_requirement/3`** — **AUD-04-043** uses **`Ecto.Multi` + `log_multi_safe`** for paired **`must_change_password`** clear + **`account.password_change`** (**AUD-17**); **EX-44-05** closed; **`audit_forced_password_change/2`** deprecated (**`log_safe`** legacy only). Evidence: **`test/sigra/account_audit_atomicity_test.exs`**.

**Note — Phase 81 (2026-04-24):** **`Sigra.APIToken.audit_jwt_refresh/2`** and **`audit_jwt_refresh_reuse/2`** use **`Repo.transaction/1`** + audit-only **`Ecto.Multi` + `Audit.log_multi_safe`** when `:audit_schema` is set (**AUD-18**). Evidence: **`test/sigra/api_token_audit_atomic_test.exs`**.

**Note — Phase 82 (2026-04-24):** **`Sigra.JWT.refresh/3`** (**AUD-19**) closes **AUD-08** for the guided path — **`user_tokens`** effects and **`api.jwt_refresh`** / **`api.jwt_refresh_reuse`** share one **`Repo.transaction/1`** when `:audit_schema` is set; failures return **`{:error, :jwt_refresh_aborted}`**. Standalone **`audit_jwt_refresh*`** helpers remain audit-only (**81**) for backward compatibility. Evidence: **`test/sigra/jwt_refresh_audit_cofate_test.exs`**.

**Note — Phase 78 (2026-04-24):** **`Sigra.Account`** email/password/deletion paths (**AUD-04-035..042**) and **`Sigra.APIToken.revoke/2`** (**AUD-04-047**) already use **`Ecto.Multi` + `log_multi_safe`** in **`lib/`**; phase **78** closes **44** inventory + **09** C-1 drift vs legacy “target **Multi**” language (**AUD-14**).

**Note — Phase 77 (2026-04-24):** **`audit_backup_codes_regenerate/3`** and **`audit_trust_browser/2`** now use **`commit_ad_hoc_mfa_audit/5`** (**`Repo.transaction/1`** + **`log_multi_safe`**) when `:audit_schema` is set — **AUD-04-033** / **034** align with **T1** in **`09-VERIFICATION.md`**.

**Note — Phase 83 (2026-04-24):** **`AUD-04-022`** invalid-code path now uses **`commit_ad_hoc_mfa_audit/5`** (**`Repo.transaction/1`** + **`Multi` + `log_multi_safe`**) when `:audit_schema` is set — **EX-44-02** appendix retired for the **022** slice; **09-VERIFICATION** C-1 **022** → **T1**. Evidence: **`test/sigra/mfa_audit_atomicity_test.exs`** (invalid-code matrix), **`lib/sigra/mfa.ex`**.

OAuth, operational security helpers (`Lockout`, `SuspiciousLogin`, `Impersonation`), and the account-deletion worker continue in [`.planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md`](../45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md) (**AUD-04-050+**, **AUD-08** batch).

**Note — Phase 61 (2026-04-23):** **`verify_backup/4`** invalid-backup / wrong-code path (**`AUD-04-067`**) now shares **`Lockout.increment`** fate with **`mfa.verify.failure`** (+ optional **`mfa.lockout`**) via **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** (**AUD-01**). Evidence: **`test/sigra/mfa_audit_atomicity_test.exs`**.

**Note — Phase 66 (2026-04-23):** **`confirm_enrollment/5`** — **`AUD-04-020`** success audit is **`Multi` + `log_multi_safe`** inside the enrollment transaction; **`AUD-04-021`** **`mfa.enroll.failure`** / **`insert_failed`** uses a follow-up **`Repo.transaction(Multi + log_multi_safe)`** after the enrollment **`Multi`** rolls back (**AUD-09**). **`AUD-04-022`** was **`log_safe`** under **EX-44-02** until **phase 83** promoted invalid-code auditing to **`commit_ad_hoc_mfa_audit/5`**. Evidence: **`test/sigra/mfa_audit_atomicity_test.exs`**.
