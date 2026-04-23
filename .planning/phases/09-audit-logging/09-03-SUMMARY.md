# Phase 9 — Audit logging & C-1 executive orientation

## Document status

- **Last materially updated for:** **v1.9** (planning text **2026-04-23** — phase **67** / **AUD-10**).
- **Planning trace:** Phase 9 → Phase 61 (AUD-01) → Phase 62 (AUD-02) → Phase 66 (AUD-09) → Phase 67 (AUD-10).
- **Canonical C-1 matrix:** [09-VERIFICATION.md](./09-VERIFICATION.md).
- **Requirement:** [**AUD-10**](../../milestones/v1.9-REQUIREMENTS.md) (archived **v1.9** requirements at milestone close).
- **C-1 verification note (phase 67 / AUD-10):** No edit to 09-VERIFICATION.md rows AUD-04-020..022 after D-06 reconciliation (hybrid D-06 / AUD-02 class).

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
