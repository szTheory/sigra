# Phase 81: JWT refresh / reuse audit atomicity — Discussion log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in **81-CONTEXT.md**.

**Date:** 2026-04-24  
**Phase:** 81 — JWT refresh / reuse audit atomicity  
**Areas discussed:** Code structure (shared `commit_*` vs duplication), caller contract on audit failure, ExUnit fault-injection layout, planning-truth edit depth  
**Mode:** User selected **all** areas; research via parallel subagents; principal synthesized locked decisions.

---

## Area 1 — Code structure in `APIToken`

| Option | Description | Selected |
|--------|-------------|----------|
| Shared private `commit_api_token_jwt_audit*` | One transaction + telemetry shell; thin public wrappers | ✓ |
| Two parallel implementations | Full locality; duplicated `case transaction` / rescue risk |  |

**User's choice:** Research synthesis + user request for coherent defaults — **shared `commit_*` + thin wrappers**.  
**Notes:** Aligns with `commit_api_token_verify_failure_audit/2`; avoids Rails callback / Django signal ordering bugs; footgun is over-parameterized god-helper — keep opts explicit per action.

---

## Area 2 — Caller-visible behavior on audit insert failure

| Option | Description | Selected |
|--------|-------------|----------|
| A — Always `:ok` + `log_safe_error` telemetry | Matches `log_safe` integrator contract; does not block refresh on audit store failure | ✓ |
| B — `{:error, _}` | Explicit but breaking and misleading if refresh already committed |  |
| C — Raise on benign DB failure | High surprise; outage risk |  |
| D — Hybrid | Swallow classifiable failures, raise programmer errors — **folded into A** via same pattern as verify commit helper | ✓ |

**User's choice:** **A (+ raise only on unexpected Multi)** for **both** `audit_jwt_refresh` and `audit_jwt_refresh_reuse`.  
**Notes:** Document that `:ok` ≠ guaranteed audit row.

---

## Area 3 — Test layout and telemetry assertions

| Option | Description | Selected |
|--------|-------------|----------|
| Separate named tests + small DDL/telemetry helper | CI-readable; mirrors Phase 79 posture | ✓ |
| Parametrized loops / property tests | DRY but weak failure signals; poor fit |  |

**User's choice:** **Separate tests**; **strict telemetry** on fault path (event, count, action, reason); **helper** for CHECK/attach boilerplate only.  
**Notes:** Unique telemetry handler ids; action-scoped row counts.

---

## Area 4 — Planning truth (44 / 45 / 09 / CHANGELOG)

| Option | Description | Selected |
|--------|-------------|----------|
| Surgical updates + footnote on audit-only T1 vs AUD-08 | Honest mechanism + verdict alignment without erasing deferral history | ✓ |
| Minimal T1 flip only | Misleading if narrative implies co-fate |  |
| Full appendix rewrite | High churn; risks erasing audit trail |  |

**User's choice:** **Surgical pass** with **additive** EX-45 clarifications where needed.  
**Notes:** T1 only when code + tests prove **AUD-18** slice; footnote **AUD-08** still deferred.

---

## Claude's discretion

- Private function naming and arity for `commit_*`; optional one vs two happy-path tests.

## Deferred ideas

- **AUD-08** — JWT persistence / refresh-token row co-fate with audit.
