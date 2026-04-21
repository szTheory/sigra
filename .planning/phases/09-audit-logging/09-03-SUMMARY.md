# Phase 9 — Audit logging summary (post v1.4)

Executive snapshot after **AUD-08** (OAuth + ops + worker) and prior **AUD-04** waves on auth, MFA, and account/API surfaces.

## Inventory pointers

| Phase | File | Scope |
|-------|------|--------|
| 43 | [`.planning/phases/43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md`](../43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md) | Auth-only **AUD-04-001–019** |
| 44 | [`.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md`](../44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md) | MFA + account + API token **AUD-04-020–049** |
| 45 | [`.planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md`](../45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md) | OAuth + ops + worker **AUD-04-050+** |

Row counts drift with code — treat the linked inventories as canonical.

## Trust model (short)

- **DB co-fate (T1):** domain `Ecto.Multi` / `Repo.transaction` + `Sigra.Audit.log_multi_safe/3` (or `__log_internal__/3`) so audit rows roll back with failed mutations.
- **Telemetry / SMTP / enqueue:** not claimed as co-fated with SQL; documented as **T2** with compensating controls where applicable.
- **Oban / session store:** job bookkeeping and `SessionStore` behaviour are orthogonal to audit **Multi** composition unless explicitly wrapped (see **EX-*** rows in phase **45** inventory).

Normative vocabulary: [`docs/audit-semantics.md`](../../../docs/audit-semantics.md).
