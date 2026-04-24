# Phase 9 — Audit logging & C-1 executive orientation

## Document status

- **Last materially updated for:** **v1.18** (**2026-04-24**) — phase **`81`** / **`AUD-18`**: **`Sigra.APIToken.audit_jwt_refresh/2`** / **`audit_jwt_refresh_reuse/2`** use **`Repo.transaction/1`** + audit-only **`Multi` + `log_multi_safe`** when `:audit_schema` is set (**AUD-04-048** / **049** **T1** for audit rows only); **AUD-08** not claimed closed.
- **Planning trace:** Phase 9 → … → Phase 79 (AUD-16) → Phase 80 (AUD-17) → Phase 81 (AUD-18).
- **Canonical C-1 matrix:** [09-VERIFICATION.md](./09-VERIFICATION.md).
- **Requirement:** [**AUD-10**](../../milestones/v1.9-REQUIREMENTS.md) (archived **v1.9** requirements at milestone close — historical anchor).
- **`v1.12` carry-forward (archived):** [`milestones/v1.12-REQUIREMENTS.md`](../../milestones/v1.12-REQUIREMENTS.md) — **`AUD-12`**, **`UAT-01`**, **`UAT-02`** (and **`AUD-11`**, **`TRN-*`**) at milestone close **2026-04-24**; live **`.planning/REQUIREMENTS.md`** removed until **`/gsd-new-milestone`**.
- **C-1 verification note (phase 67 / AUD-10):** No edit to 09-VERIFICATION.md rows AUD-04-020..022 after D-06 reconciliation (hybrid D-06 / AUD-02 class).
- **C-1 verification note (phase 73 / AUD-11):** Rows **AUD-04-023..032** reconciled to **`lib/sigra/mfa.ex`** **`Multi` + `log_multi_safe`** where **T1**. Evidence **`test/sigra/mfa_audit_atomicity_test.exs`**; planning **`.planning/phases/73-bounded-audit-atomicity-batch/`**; merge commits **`aed7a9a`** (matrix + inventory) and **`b5500a7`** (Postgres CHECK fault-injection tests) — if `git log` shows different tip SHAs for those changes, substitute the **first-parent** SHAs that touch the listed files instead of these literals.
- **C-1 verification note (phase 77 / AUD-13):** **AUD-04-033** / **034** (`audit_backup_codes_regenerate/3`, `audit_trust_browser/2`) now use **`commit_ad_hoc_mfa_audit/5`** (**`Repo.transaction/1`** + **`log_multi_safe`**) → **T1** in **`09-VERIFICATION.md`**; **EX-44-03** / **EX-44-04** appendix rows updated for mechanism (compensating controls unchanged). **`AUD-04-022`** remains **`log_safe`** (**EX-44-02**).
- **C-1 verification note (phase 79 / AUD-16):** **AUD-04-044..046** — **`Sigra.APIToken.verify/2`** failure branches (**invalid_token**, **token_revoked**, **token_expired**) emit **`api.token_verify.failure`** via **`Repo.transaction/1`** + **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** when `:audit_schema` is configured; success path remains unaudited (**D-27**). Constraint / invalid-changeset insert failures emit **`[:sigra, :audit, :log_safe_error]`** and callers still receive **`{:error, reason}`**. Evidence: **`test/sigra/api_token_audit_atomic_test.exs`**.
- **C-1 verification note (phase 78 / AUD-14):** **AUD-04-035..042** and **047** — **`Sigra.Account`** and **`Sigra.APIToken.revoke/2`** were already **`Multi` + `log_multi_safe`** in **`lib/`**; **44-AUD-04-INVENTORY.md** and **09-VERIFICATION.md** Phase **44** rows were stale vs code. **044–046** were **`log_safe`** (**EX-44-01**) until **phase 79**. Evidence: **`test/sigra/account_audit_atomicity_test.exs`** (password + **email-change** request/confirm/cancel happy paths + audit `CHECK` rollbacks), **`test/sigra/api_token_audit_atomic_test.exs`**.
- **C-1 verification note (phase 80 / AUD-17):** **AUD-04-043** — **`T1`** via **`Multi` + `log_multi_safe`** on **`Sigra.Account.clear_password_change_requirement/3`** (phase **80**); evidence **`account_audit_atomicity_test.exs`**; **`audit_forced_password_change/2`** is **`@deprecated`** for that completion path (do not call both).
- **C-1 verification note (phase 81 / AUD-18):** **AUD-04-048** / **049** — **`Sigra.APIToken.audit_jwt_refresh/2`** and **`audit_jwt_refresh_reuse/2`** emit **`api.jwt_refresh`** / **`api.jwt_refresh_reuse`** via **`Repo.transaction/1`** + **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** when `:audit_schema` is configured; **AUD-08** persistence scope explicitly **not** claimed closed. Evidence: **`test/sigra/api_token_audit_atomic_test.exs`**.

## Recent bounded batches

Phase **61** shipped **AUD-01** for **`Sigra.MFA.verify_backup/4`** invalid-backup and wrong-code attempts. **`verify_backup/4`** wrong-code / invalid-backup attempts emit **`mfa.verify.failure`** via **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** (and **`mfa.lockout`** in the same transaction when the lockout threshold is reached), matching **`verify/4`** failure semantics. For mechanism, tier, and verdict, see the C-1 row for **`AUD-04-067`** in [`09-VERIFICATION.md`](./09-VERIFICATION.md).

Phase **66** shipped **AUD-09** for **`Sigra.MFA.confirm_enrollment/5`**, covering **`AUD-04-020`–`022`**; **`AUD-04-022`** stays on **`log_safe`** as **T2** under **`EX-44-02`** (invalid TOTP before DB writes). The primary story is **`AUD-04-021`**: **`Multi`** + **`log_multi_safe`** with a dedicated follow-up **`Repo.transaction/1`** when enrollment persistence fails after DB work—so failure audit does not disagree with rolled-back enrollment effects. For mechanism, tier, and verdict, see the C-1 row for **`AUD-04-021`** in [`09-VERIFICATION.md`](./09-VERIFICATION.md).

Phase **73** shipped **AUD-11** for **`Sigra.MFA`** paths covering **`AUD-04-023`..`032`**: **`verify/4`**, **`verify_backup/4`**, **`cleanup_mfa/6`**, **`disable!/4`**, and **`regenerate_backup_codes/4`** — audit rows are **`Multi`**-co-fated via **`Sigra.Audit.log_multi_safe/3`** where the matrix claims **T1**. **`44-AUD-04-INVENTORY.md`** Phase column + **`## Grep log`** were refreshed with **`lib/sigra/mfa.ex`**; **`09-VERIFICATION.md`** C-1 rows **023..032** were updated in the same closure.

Phase **77** shipped **AUD-13** for ad-hoc **`Sigra.MFA.audit_backup_codes_regenerate/3`** and **`Sigra.MFA.audit_trust_browser/2`** — **`AUD-04-033`** / **034** now **T1** via dedicated **`Repo.transaction/1`** + **`log_multi_safe`** steps (failure telemetry parity with former **`log_safe/3`**). See **`.planning/phases/77-mfa-adhoc-audit-multi/77-VERIFICATION.md`** and C-1 rows **033** / **034** in [`09-VERIFICATION.md`](./09-VERIFICATION.md).

Phase **79** ships **AUD-16** for **`Sigra.APIToken.verify/2`** failure audits (**AUD-04-044..046**) — transactional **`log_multi_safe`** + extended **`test/sigra/api_token_audit_atomic_test.exs`**. See **`.planning/phases/79-api-token-verify-failure-audit/79-VERIFICATION.md`**.

Phase **81** ships **AUD-18** for **`audit_jwt_refresh/2`** / **`audit_jwt_refresh_reuse/2`** (**AUD-04-048** / **049**) — **`Repo.transaction/1`** + **`Multi` + `log_multi_safe`** when `:audit_schema` is set; **does not** close **AUD-08** (refresh-token storage co-fate). See **`.planning/phases/81-jwt-refresh-audit-atomicity/81-VERIFICATION.md`**.

Phase **78** ships **AUD-14** for **`Sigra.Account`** (**AUD-04-035..042**) and **`Sigra.APIToken.revoke/2`** (**AUD-04-047**) — **planning truth** aligning **44** inventory + **09-VERIFICATION** C-1 rows with **`lib/`** (code already **`Multi` + `log_multi_safe`**); extends **`test/sigra/account_audit_atomicity_test.exs`** for **`change_password`**. See **`.planning/phases/78-account-api-c1-planning-truth/78-VERIFICATION.md`**.

## Inventory pointers

| Phase | File | Scope |
|-------|------|-------|
| 43 | [`.planning/phases/43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md`](../43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md) | Auth-only **AUD-04-001–019** |
| 44 | [`.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md`](../44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md) | MFA + account + API token **AUD-04-020–049** |
| 45 | [`.planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md`](../45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md) | OAuth + ops + worker **AUD-04-050+** |

Row counts drift with code — treat the linked inventories as canonical.

## Trust model (short)

- **DB co-fate (T1):** domain `Ecto.Multi` / `Repo.transaction` + `Sigra.Audit.log_multi_safe/3` (or `__log_internal__/3`) so audit rows roll back with failed mutations.
- **Telemetry / SMTP / enqueue:** not claimed as co-fated with SQL; documented as **T2** with compensating controls where applicable.
- **Oban / session store:** job bookkeeping and `SessionStore` behaviour are orthogonal to audit **Multi** composition unless explicitly wrapped (see **EX-*** rows in phase **45** inventory).

Normative vocabulary: [`docs/audit-semantics.md`](../../../docs/audit-semantics.md).

## C-1 row-level matrices

Per-**`AUD-04-xxx`** rows for phases **43**, **44**, and **45** (mechanism, tier, verdict, evidence pointer) live in **[`09-VERIFICATION.md`](./09-VERIFICATION.md)** under **C-1** — exhaustive sub-inventories, not a high-level rollup alone.
