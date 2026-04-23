# Requirements — Sigra v1.6 Nyquist closure + OAuth audit depth

**Defined:** 2026-04-22  
**Core value (from PROJECT.md):** Authentication that works out of the box with great DX on the happy path **and** on the rough edges — including **credible verification narrative** for historical GA work (**41–44**) and **machine-backed OAuth + audit** claims.

This milestone **does not** ship net-new end-user auth features. It tightens **planning truth**, **Nyquist posture visibility**, and **automated OAuth ceremony ↔ audit** proof.

---

## Nyquist & verification (NYQ)

- [ ] **NYQ-01**: **`MAINTAINING.md`** (or one linked maintainer doc under `.planning/` referenced from it) contains a **matrix of phases 41–44** with: phase slug, current `nyquist_compliant` disposition, canonical path to `*-VERIFICATION.md` / `*-VALIDATION.md` (or explicit “none”), and a **one-line reopen trigger** per row.
- [ ] **NYQ-02**: Each **41–44** row in that matrix has an explicit **milestone disposition**: *elevated to compliant* (with evidence), *unchanged with recorded rationale*, or *deferred with trigger + date* — no silent blank cells.

---

## OAuth ceremony & audit smoke (OA)

- [ ] **OA-01**: **Merge-blocking** tests exercise at least one **OAuth ceremony** path the library owns (mocked HTTP / in-process strategy is fine) and **assert audit outcomes** where production code already emits audit on success — **or** assert an explicitly documented substitute (telemetry-only, etc.) with a **code comment** referencing **OA-01** so the absence of an audit row is not an accident.
- [ ] **OA-02**: **`docs/uat-ci-coverage.md`** (and, if applicable, a **GA-03** pointer note in `.planning/v1.4-GA-UAT.md` or evidence index) names the **OA-01** test module(s) and states what machine proof **now** covers vs what remains **human / live-provider** only.

---

## Out of scope (v1.6)

- Full **SEED-002** `log_safe/3` → `Ecto.Multi` conversion across all subsystems.
- **Live Google** (or other real IdP) OAuth in CI; new OAuth providers.
- SAML, SCIM, IdP mode, authorization frameworks.

---

## Future (post-v1.6)

- **SEED-002** remainder — batch Multi conversion with audit-aware tests.
- Product features promoted from **Backlog** in `.planning/ROADMAP.md`.
- Optional fresh **SEED-001** human rows before a major external announcement.

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| NYQ-01 | 57 | Pending |
| NYQ-02 | 57 | Pending |
| OA-01 | 58 | Pending |
| OA-02 | 59 | Pending |

**Coverage**

- v1.6 requirements: **4** total  
- Mapped to phases: **4**  
- Unmapped: **0**

---

*Requirements defined: 2026-04-22 after `/gsd-new-milestone` (research skipped by maintainer choice; phases continue from **57**).*
