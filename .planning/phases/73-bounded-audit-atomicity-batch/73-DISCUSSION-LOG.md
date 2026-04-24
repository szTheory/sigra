# Phase 73: Bounded audit atomicity batch - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in **`073-CONTEXT.md`**.

**Date:** 2026-04-23  
**Phase:** 73 — Bounded audit atomicity batch  
**Areas discussed:** Subsystem / AUD-04 slice; T1 vs T2 boundaries; Audit-aware tests; Planning & C-1 traceability  
**Mode:** User selected **all** areas; research performed via **four parallel `generalPurpose` subagents** + maintainer verification grep against **`lib/sigra/mfa.ex`** and **`44-AUD-04-INVENTORY.md`**.

---

## 1 — Subsystem / AUD-04 slice

| Option | Description | Selected |
|--------|-------------|----------|
| A | MFA verify/lockout/regen/disable band **023–032** (single module + `mfa_audit_atomicity_test.exs`) | ✓ |
| B | Account **035–043** | |
| C | API tokens **044–047** | |
| D | Session store **015–017** | |

**User's choice:** **A** — per research synthesis and code/inventory drift check.  
**Notes:** **`mfa.ex`** already implements **`Multi` + `log_multi_safe`** for **023–029**, **031–032** class paths; **C-1** still labels many as **`log_safe`**. Phase **73** closes that honesty gap + test receipts. **API** mix of read-only / async (**Task.start**) and **session** second-store semantics are poor **single-batch** T1 targets.

---

## 2 — T1 vs documented T2

| Option | Description | Selected |
|--------|-------------|----------|
| A | Default **T1** for same-Repo mutations; **T2** only with **EX-*** + honest inventory | ✓ |
| B | Push **`log_multi_safe`** everywhere including no-DB / legacy hooks | |

**User's choice:** **A**  
**Notes:** Aligns **`docs/audit-semantics.md`** and **OWASP-honest** co-fate definition; rejects **after_commit** theater. Lock **022 / 033 / 034** as documented **T2** unless product adds paired durable writes.

---

## 3 — Audit-aware tests

| Option | Description | Selected |
|--------|-------------|----------|
| A | Extend **`mfa_audit_atomicity_test.exs`**; DB **constraint** fault injection; ≥1 rollback proof per distinct **`Multi`** needing receipt | ✓ |
| B | New mega **`audit_atomicity_test.exs`** | |
| C | Mock-only audit failures | |

**User's choice:** **A**  
**Notes:** Matches ExUnit + **Sandbox** idioms; avoids brittle mocks for transactional proofs.

---

## 4 — Planning / traceability

| Option | Description | Selected |
|--------|-------------|----------|
| A | One **PR**: **`09-VERIFICATION.md`** + **`44-AUD-04-INVENTORY.md`** + tests when auditable columns move; **PLAN** lists row IDs + greps + scoped **`mix test`** | ✓ |
| B | Split PRs between inventory and C-1 | |

**User's choice:** **A**  
**Notes:** Avoids **49**-family honesty windows on **`main`**. **D-06-class** “no **`09-VERIFICATION.md`** body change” only when reconciliation proves zero semantic delta.

---

## Claude's Discretion

- Constraint helper shape and parameterized vs duplicated tests for symmetric **`Multi`**s.

## Deferred Ideas

- Account/API/session batches; trust-browser **T1** until persistence story exists.
