# Phase 62: C-1 narrative alignment - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in **`062-CONTEXT.md`**.

**Date:** 2026-04-23  
**Phase:** 62 — C-1 narrative alignment (**AUD-02**)  
**Areas discussed:** Summary depth; Title/era framing; `09-VERIFICATION` scope; Canonical links (L0/L1/L2)  
**Mode:** User selected **all** gray areas; research via parallel subagents; one-shot synthesis into context (no interactive per-question loop).

---

## 1. Executive summary depth (`09-03-SUMMARY.md`)

| Option | Description | Selected |
|--------|-------------|----------|
| A — Minimal | Milestone stamp + pointer only | |
| B — Moderate | Stamp + short bounded-batch subsection + exemplar id + pointer to matrix (no duplicated columns) | ✓ |
| C — Rich | Long narrative, test lists, duplicated tier/verdict story | |

**User's choice:** **B — Moderate** (research consensus: map vs law; avoids second authority / silent drift).  
**Notes:** Prefer “see C-1 row AUD-04-xxx” over copying matrix columns into summary.

---

## 2. Title and era framing

| Option | Description | Selected |
|--------|-------------|----------|
| A | Keep historical `H1` + “Updated v1.7” line only | |
| B | Retitle only (rolling / time-independent) | |
| Hybrid | **Stable topical `H1`** + mandatory **status block** under `H1` (semver, phases, verification link) | ✓ |

**User's choice:** **Hybrid** (stable keywords in title; volatile era in status block—reduces “frozen at v1.4” misread).  
**Notes:** Aligns with long-lived OSS pattern: living doc carries explicit “as of” metadata.

---

## 3. `09-VERIFICATION.md` scope in phase 62

| Option | Description | Selected |
|--------|-------------|----------|
| A | Summary only; verification untouched | |
| B | Full editorial consistency pass on entire matrix | |
| A+ hybrid | Summary primary + **targeted** read of cited rows; edit verification only on mismatch / trigger | ✓ |

**User's choice:** **Hybrid (A+)**.  
**Notes:** Phase 61 already co-shipped matrix + code; wide **B** only on explicit triggers (id churn, multi-phase slip, audit gate).

---

## 4. Canonical links in summary (information architecture)

| Option | Description | Selected |
|--------|-------------|----------|
| Mesh | Link inventories + `09-VERIFICATION` + `061-*` + deep row anchors from summary | |
| Tiered L0 | **Thin L0**: inventories + semantics + **one** matrix hub; row/phase depth via **L1** (`09-VERIFICATION`) / **L2** (phase plans) | ✓ |

**User's choice:** **Tiered L0** (~4–8 egresses from `09-03-SUMMARY.md`).  
**Notes:** ExDoc-style overview → reference; avoids “summary as site map” and link rot from volatile phase paths.

---

## Claude's Discretion

- Subsection wording, optional future CI grep for summary-mentioned **AUD-04-*** ids, micro-edits in status block.

## Deferred Ideas

- Automated summary vs matrix **AUD-04** id guard (CI)—captured in **062-CONTEXT** `<deferred>` as optional follow-up.
