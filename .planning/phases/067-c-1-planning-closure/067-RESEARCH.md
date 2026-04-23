# Phase 67 — Planning research (C-1 closure)

**Question:** What do we need to know to plan **AUD-10** well?

## Findings

### Authority split

- **Mechanism / tier / verdict** for **`AUD-04-020..022`** are authoritative in **`.planning/phases/09-audit-logging/09-VERIFICATION.md`** and **`.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md`** after phase **66** merge.
- **`09-03-SUMMARY.md`** is **L0** orientation: planning trace, bounded-batch narrative, pointers — **not** a second matrix (**067-CONTEXT D-01, D-02**).

### Post–phase-66 matrix state

- Rows **020** / **021** already read **`T1`**, **`Multi` + `log_multi_safe`**, **AUD-09 / phase 66** in **`09-VERIFICATION.md`**.
- **022** remains **`log_safe`**, **T2 / EX-44-02** — intentional; must not be “upgraded” in prose for optics (**067-CONTEXT D-07**).

### Reconciliation policy (hybrid)

- **Read** matrix rows **020..022** and matching **44-AUD-04-INVENTORY** table lines; **edit** only on material drift (**067-CONTEXT D-05, D-06**).
- Default expectation: **no** **`09-VERIFICATION.md`** edit; attestation must appear in **`09-03`** and **REQUIREMENTS** per **D-12** / roadmap success criterion **2**.

### Exemplar and pointer

- Primary exemplar for the phase **66** story: **`AUD-04-021`** (failure path with dedicated follow-up transaction). Mandatory closing pointer to **`./09-VERIFICATION.md`** (**067-CONTEXT D-04**).
- Optional short clause naming cluster **`020–022`** with **022** remaining **T2** (**067-CONTEXT D-03**).

### Trace and freshness

- Extend planning trace through **`66 (AUD-09) → 67 (AUD-10)`**; align **“Last materially updated for”** with **v1.9** when **`09-03`** prose changes (**067-CONTEXT D-08, D-09**).

---

## Validation Architecture

| Dimension | Strategy |
|-----------|----------|
| **1 — Correctness** | **`09-03-SUMMARY.md`** claims match **`09-VERIFICATION.md`** rows **020..022** and **44** inventory; no new mechanism/tier/verdict invented in summary. |
| **2 — Regression** | Phase **61** paragraph and **AUD-04-067** pointer remain present and accurate after edits. |
| **3 — Security / audit** | No repudiation gap: L0 summary cannot contradict C-1 matrix; explicit “no matrix edit” or row-level edit pointer (**D-10**). |
| **4 — Performance** | N/A (markdown only). |
| **5 — DX** | Relative links to **09-VERIFICATION**, inventories **43/44/45**, **`docs/audit-semantics.md`**, **REQUIREMENTS** stay valid (**D-14**). |
| **6 — Compatibility** | Preserve existing **09-03** section order where possible; additive bounded-batch paragraph for **66**. |
| **7 — Observability** | Execution record **`067-01-SUMMARY.md`** lists rows compared for **D-06** (attributable reconciliation). |
| **8 — Nyquist / feedback** | After each task: `rg` / `git diff` checks in **067-VALIDATION.md**; no library test gate unless executor opts for full **`mix test`** smoke. |

---

## RESEARCH COMPLETE

Findings are sufficient for **`067-*-PLAN.md`**: bounded-batch narrative, hybrid reconciliation, conditional matrix edit, **AUD-10** requirement closure.
