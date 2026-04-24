# Phase 9 — Audit logging & C-1 executive orientation

## Document status

- **Last materially updated for:** **v1.12** (**2026-04-23**) — phases **`73–74`** / **`AUD-11`** closed in **`73`**; **`AUD-12`** narrative in **`74`**.
- **Planning trace:** Phase 9 → Phase 61 (AUD-01) → Phase 62 (AUD-02) → Phase 66 (AUD-09) → Phase 67 (AUD-10) → Phase 73 (AUD-11).
- **Canonical C-1 matrix:** [09-VERIFICATION.md](./09-VERIFICATION.md).
- **Requirement:** [**AUD-10**](../../milestones/v1.9-REQUIREMENTS.md) (archived **v1.9** requirements at milestone close — historical anchor).
- **`v1.12` carry-forward:** [`.planning/REQUIREMENTS.md`](../../REQUIREMENTS.md) — active trust-bundle requirements **`AUD-12`**, **`UAT-01`**, **`UAT-02`** for this milestone.
- **C-1 verification note (phase 67 / AUD-10):** No edit to 09-VERIFICATION.md rows AUD-04-020..022 after D-06 reconciliation (hybrid D-06 / AUD-02 class).
- **C-1 verification note (phase 73 / AUD-11):** Rows **AUD-04-023..032** reconciled to **`lib/sigra/mfa.ex`** **`Multi` + `log_multi_safe`** where **T1**; **AUD-04-033** / **034** remain **`log_safe`** **T2** (**EX-44-03** / **EX-44-04**). Evidence **`test/sigra/mfa_audit_atomicity_test.exs`**; planning **`.planning/phases/73-bounded-audit-atomicity-batch/`**; merge commits **`aed7a9a`** (matrix + inventory) and **`b5500a7`** (Postgres CHECK fault-injection tests) — if `git log` shows different tip SHAs for those changes, substitute the **first-parent** SHAs that touch the listed files instead of these literals.

## Recent bounded batches

Phase **61** shipped **AUD-01** for **`Sigra.MFA.verify_backup/4`** invalid-backup and wrong-code attempts. **`verify_backup/4`** wrong-code / invalid-backup attempts emit **`mfa.verify.failure`** via **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** (and **`mfa.lockout`** in the same transaction when the lockout threshold is reached), matching **`verify/4`** failure semantics. For mechanism, tier, and verdict, see the C-1 row for **`AUD-04-067`** in [`09-VERIFICATION.md`](./09-VERIFICATION.md).

Phase **66** shipped **AUD-09** for **`Sigra.MFA.confirm_enrollment/5`**, covering **`AUD-04-020`–`022`**; **`AUD-04-022`** stays on **`log_safe`** as **T2** under **`EX-44-02`** (invalid TOTP before DB writes). The primary story is **`AUD-04-021`**: **`Multi`** + **`log_multi_safe`** with a dedicated follow-up **`Repo.transaction/1`** when enrollment persistence fails after DB work—so failure audit does not disagree with rolled-back enrollment effects. For mechanism, tier, and verdict, see the C-1 row for **`AUD-04-021`** in [`09-VERIFICATION.md`](./09-VERIFICATION.md).

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
