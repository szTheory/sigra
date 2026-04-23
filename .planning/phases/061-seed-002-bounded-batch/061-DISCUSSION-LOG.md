# Phase 61: SEED-002 bounded batch - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `061-CONTEXT.md`.

**Date:** 2026-04-23  
**Phase:** 61 — SEED-002 bounded batch  
**Areas discussed:** Subsystem boundary; T1 Multi vs documented substitute; audit-aware test bar; C-1 doc coupling (61 vs 62)

**Method:** User selected **all** gray areas; four parallel research subagents synthesized tradeoffs; maintainer agent merged into a single coherent decision set in CONTEXT.

---

## 1. Subsystem boundary

| Option | Description | Selected |
|--------|-------------|----------|
| MFA vertical (narrow cluster) | `mfa.ex` + existing MFA atomicity tests; many AUD-04 T2/target Multi rows | ✓ (primary) |
| API token lifecycle | Smallest clear “row + audit” template | ✓ (explicit fallback only) |
| Account + profile | High value but risk blurring two subsystems in one “batch” | |
| OAuth leftovers | Compliance narrative; more async/mock flakiness risk | |
| Plugs only | Small but weak C-1 / inventory story | |
| Smallest grep hit | Arbitrary; breaks traceability | |

**User's choice:** Research-backed **MFA** as default bounded batch, **one command cluster**; **API tokens** only if MFA scope forces god `Multi`.  
**Notes:** Cross-ecosystem lesson: explicit command + transaction beats callback/signal magic (Rails/Django/Spring footguns).

---

## 2. T1 Multi vs documented substitute

| Option | Description | Selected |
|--------|-------------|----------|
| Default T1 Multi | Same Repo transaction for same-DB short work | ✓ |
| T2 + EX-* only when structural | SessionStore, cross-Repo, network inside TX impossible | ✓ |
| Silent T2 for “awkward” same-DB | Convenience without documentation | ✗ (rejected) |

**User's choice:** Default **T1**; **T2 + EX-*** (or documented substitute) only for structural constraints.  
**Notes:** Library returns composable `Multi` steps; host owns orchestration — least surprise for Phoenix apps.

---

## 3. Audit-aware test bar

| Option | Description | Selected |
|--------|-------------|----------|
| B — Success-path audit rows | Assert audit exists on `{:ok, _}`; matches AUD-01 literal | ✓ (primary bar) |
| A — Fault injection / rollback | Prove domain rollback when audit fails | ✓ (surgical, per critical Multi) |
| C — Broad property tests | High cost unless project-wide standard | (omit unless pre-existing style) |

**User's choice:** **B** everywhere the batch touches success paths; **A** in focused doses with deterministic failures; actionable assertion messages.

---

## 4. C-1 matrix updates (Phase 61 vs 62)

| Option | Description | Selected |
|--------|-------------|----------|
| Same PR as code | Update `09-VERIFICATION.md` (+ linked inventory rows) with implementation | ✓ |
| Defer all matrix to Phase 62 | Risk intermediate false C-1 truth | ✗ (rejected) |

**User's choice:** **Phase 61** PR includes **minimal necessary** C-1 / inventory updates for touched **AUD-04** rows; **Phase 62** for summary/holistic narrative (`09-03-SUMMARY.md`).

---

## Claude's Discretion

- Internal MFA function grouping and count of surgical **A**-tests within **D-06** guidance.

## Deferred Ideas

- Full SEED-002; session-store batch; plugs-first audit; holistic summary-only edits deferred to Phase **62** where appropriate.
