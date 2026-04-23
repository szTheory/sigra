# Requirements: Sigra v1.9

**Defined:** 2026-04-23  
**Core Value (from PROJECT.md):** Authentication that works out of the box with great DX on the happy path **and** on the rough edges — including **credible audit-trail completeness** for successful business operations where **D-01** / **C-1** commitments apply.

This milestone continues **SEED-002** in **bounded** batches (not a whole-library conversion). It **does not** ship **SEED-001** human GA matrix work, **`sigra_lockspire`**, SAML/SCIM/IdP mode, or net-new product features unless required as a side effect of the audit batch.

---

## Audit durability — SEED-002 continuation (AUD)

- [ ] **AUD-09**: At least **one** bounded subsystem batch from the Phase **9** **C-1** deferral set (canonical disposition in **`.planning/phases/09-audit-logging/09-VERIFICATION.md`**; row IDs trace to inventories under **`.planning/phases/43-*`**, **`44-*`**, **`45-*`**) moves from hybrid **`log_safe/3`** post-commit audit to **`Ecto.Multi`**-co-fated audit writes using **`Sigra.Audit.log_multi_safe/3`** (or an explicitly documented substitute approved in phase planning), with **audit-aware** regression tests merged under the **same** phase gate as the production change. **Phase 66.**

- [ ] **AUD-10**: **`.planning/phases/09-audit-logging/09-03-SUMMARY.md`** reflects the **post-phase-66** batch (planning trace, “Recent bounded batches”, pointers). **`09-VERIFICATION.md`** is updated **only** when a **C-1** row’s mechanism, tier, or verdict materially changes; otherwise carry an explicit “no **`09-VERIFICATION.md`** edit required” rationale (same class as v1.7 **D-06** for **AUD-02**). **Phase 67.**

---

## Out of scope (v1.9)

- Full **SEED-002** conversion of **all** remaining hybrid sites in one milestone.
- **SEED-001** human-only GA / OAuth / clean-machine matrix rows (reserve for a **public launch** milestone).
- Optional Hex package **`sigra_lockspire`** or mandatory companion OAuth server dependency (see **`.planning/decisions/001-defer-sigra-lockspire-glue-package.md`**).
- Net-new auth features, new OAuth providers, or LiveView/product UX unless strictly required by the audit batch.

---

## Future (post-v1.9)

- Further bounded **SEED-002** batches until **C-1** is honestly downgraded or closed.
- **SEED-001** when marketing / GA loud-launch work is scheduled.

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUD-09 | 66 | Pending |
| AUD-10 | 67 | Pending |

**Coverage**

- v1.9 requirements: **2** total  
- Mapped to phases: **2**  
- Unmapped: **0**

---

*Requirements defined: 2026-04-23 after `/gsd-new-milestone` (v1.9 Audit atomicity).*
