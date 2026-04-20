# Phase 39: Audit trail completeness — Discussion log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `39-CONTEXT.md`.

**Date:** 2026-04-18  
**Phase:** 39 — Audit trail completeness  
**Mode:** User selected **all** gray areas and requested **maximum automation** for bookkeeping after a **single-pass** research synthesis (four parallel `generalPurpose` subagents: ExUnit/Sandbox/helpers, Multi vs post-commit audit cross-ecosystem, subsystem ROI ranking, security-doc traceability).

**Areas covered:** (1) Audit-aware test harness (AUD-01), (2) AUD-02 first conversion vs bounded plan, (3) AUD-03 three integration sites, (4) Verification / C-1 narrative.

---

## Synthesis method

1. In-session codebase read: `lib/sigra/audit.ex`, `lib/sigra/api_token.ex`, `lib/sigra/auth.ex` grep, `test/support/audit_test_event.ex`, test grep for `log_safe`.  
2. Parallel subagents on: helper vs CaseTemplate vs macro; `Ecto.Multi` + industry audit patterns; ranking of integration surfaces; doc mechanisms when phase-9 tree paths are absent.  
3. Single coherent package locked into CONTEXT (D-39-01 — D-39-17).

---

## Outcome

| Area | Direction | Locked in CONTEXT as |
|------|-----------|----------------------|
| AUD-01 harness | Plain functions, partial asserts, explicit repo; optional host DataCase snippet for Sandbox | D-39-01 — D-39-05 |
| AUD-02 | **Primary:** `api.token_create` → `Ecto.Multi` + `__log_internal__`; **Fallback:** bounded phased plan | D-39-06 — D-39-08 |
| AUD-03 | Token create + auth login/lockout + MFA *or* OAuth link (planner picks by test depth) | D-39-09 — D-39-12 |
| Docs / C-1 | REQUIREMENTS + CHANGELOG + SEED-002; optional `docs/audit-semantics.md` | D-39-13 — D-39-15 |
| Cross-cutting | Two-primitive story; conversion waves | D-39-16 — D-39-17 |

---

## Claude's discretion

- Helper module naming; MFA vs OAuth for third site if cost is equal (CONTEXT defaults MFA).

## Deferred ideas

- Full ~30-site `log_safe` elimination — see CONTEXT `<deferred>`.
