# Phase 74: Planning truth + launch evidence - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in **`74-CONTEXT.md`**.

**Date:** 2026-04-24  
**Phase:** 74 — Planning truth + launch evidence  
**Areas discussed:** Gray areas **1–5** (09-03 narrative, D-06 attestation placement, v1.12 evidence file shape, `docs/uat-ci-coverage.md` v1.12 section, canonical paths)  
**Mode:** User requested **research-backed** pros/cons and a **one-shot cohesive recommendation**; two parallel **`generalPurpose`** subagents (planning-truth cluster + UAT/evidence cluster); user replied **“sure”** to capture context.

---

## Gray areas 1–2 — `09-03-SUMMARY` + D-06 / `09-VERIFICATION` unchanged

| Option | Description | Selected |
|--------|-------------|----------|
| A | Summary-only attestation | |
| B | Matrix preamble only | |
| C | **Hybrid** — full narrative in **09-03**; optional **one-line** pointer in **09-VERIFICATION** preamble; no duplicated rationale | ✓ |
| D | Git-only / no durable attestation | |

**User's choice:** **C** (synthesized recommendation; user accepted wholesale via **“sure”**).  
**Notes:** Normative **C-1** cells stay only in **`09-VERIFICATION.md`**. **D-06-class** “no row edit” story is primary in **`09-03-SUMMARY.md`** with ids + PR/test pointers.

---

## Gray area 3 — `.planning/v1.12-UAT-EVIDENCE.md` shape

| Option | Description | Selected |
|--------|-------------|----------|
| A | Minimal **8-row** matrix + short preamble; pointers to **`docs/uat-ci-coverage.md`** for depth | ✓ |
| B | Long narrative + matrix (duplicate risk) | |
| C | Outcomes only in **`docs/`** | |

**User's choice:** **A**  
**Notes:** Columns per **REQUIREMENTS UAT-01**; **SEED 1..8** order matches **`docs/uat-ci-coverage.md`** table.

---

## Gray area 4 — `docs/uat-ci-coverage.md` v1.12 alignment

| Option | Description | Selected |
|--------|-------------|----------|
| A | **Thin** **v1.12** section: pointer + division of labor; **no** pasted outcome rows | ✓ |
| B | Duplicate eight outcome rows in ExDoc | |

**User's choice:** **A**  
**Notes:** Single source of truth for outcomes remains **`.planning/v1.12-UAT-EVIDENCE.md`**.

---

## Gray area 5 — Canonical path

| Option | Description | Selected |
|--------|-------------|----------|
| A | **`.planning/v1.12-UAT-EVIDENCE.md`** (locked in **REQUIREMENTS** / **ROADMAP**) | ✓ |
| B | Rename / alternate path | |

**User's choice:** **A**  
**Notes:** Avoid link churn for phase **75** upgrade stub and adopters.

---

## Claude's Discretion

- Optional **`09-VERIFICATION.md`** one-line pointer vs summary-only if matrix merge noise is high (**74-CONTEXT**).

## Deferred Ideas

- **Phase 75** adoption/trust doc work (**TRN-01..03**).
