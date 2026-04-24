# Phase 66: SEED-002 bounded batch - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in **`066-CONTEXT.md`**.

**Date:** 2026-04-23  
**Phase:** 66 — SEED-002 bounded batch (AUD-09)  
**Areas discussed:** Subsystem slice; batch size; T1 vs T2 policy; verification merge policy; cross-ecosystem + Ecto research synthesis  
**Mode:** User requested **all** areas + **parallel subagent research** → recommendations merged into context without interactive menu.

---

## Subsystem / inventory slice

| Option | Description | Selected |
|--------|-------------|----------|
| MFA `confirm_enrollment/5` cluster (**AUD-04-020..022**) | Same vertical as **067**; **`mfa_audit_atomicity_test.exs`**; dense C-1 story | ✓ |
| Account **035–043** | Different module, invariants, tests | |
| API tokens **044–047** | Token lifecycle epic | |
| Session **015–017** | Explicitly deferred batch class | |

**User's choice:** Research-backed lock — **MFA enroll / confirm_enrollment** with explicit **AUD-04-020..022** linkage in PLAN; defer other verticals.  
**Notes:** Parallel agent + **`44-AUD-04-INVENTORY.md`** ground truth: **020** success already **`Multi`** in code—matrix may need alignment; **021** primary T1 target; **022** pre-DB validation → default **T2 + EX-44-02** unless explicitly changed with docs/tests.

---

## Batch size vs risk

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal coherent (`confirm_enrollment` only) | One PR narrative; avoids god **`Multi`** | ✓ |
| Broader (regen, disable, verify rows) | Higher diff, weaker focus | |

**User's choice:** **Minimal coherent** — **D-04** in context.

---

## T1 vs documented T2 policy

| Option | Description | Selected |
|--------|-------------|----------|
| Same as phase 61 + research refinements | **Multi` + `log_multi_safe`** default; **T2** only structural + **EX-***; telemetry after **`{:ok, changes}`**; no Oban/email in txn | ✓ |
| Tighten all paths to T1 | Rejected for **022**-class pure validation without rationale | |
| Relax T2 | Rejected — violates honest C-1 | |

**User's choice:** **D-05 / D-06** in context.

---

## Verification artifacts merge policy

| Option | Description | Selected |
|--------|-------------|----------|
| Matrix + inventories same PR when mechanism changes; **09-03** in phase 67 | Matches roadmap **AUD-09** / **AUD-10** split | ✓ |
| Defer matrix with code | Rejected | |

**User's choice:** **D-07 / D-08** in context.

---

## Research agents (summary)

1. **Cross-ecosystem:** Callback/signal/event **phase** ambiguity vs **one transactional unit**; outbox/ES overkill for lib auth; OWASP: **atomicity** for “no state without audit” vs **tamper evidence** as host concern.  
2. **Ecto:** **`Repo.transact`**, short txns, **`emit_telemetry_from_changes`** only on success, Oban/email after commit, **one Multi per command**, composable builders.  
3. **Sigra slice:** MFA first after **067**; enroll cluster; defer regen/trust/account/API/session.

---

## Claude's Discretion

- **`Multi` step naming**, helper extraction, fault seams — within **D-01–D-12** guardrails.

## Deferred Ideas

- See **`<deferred>`** in **`066-CONTEXT.md`**.
