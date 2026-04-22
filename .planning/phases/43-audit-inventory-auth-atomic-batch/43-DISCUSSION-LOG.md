# Phase 43: Audit inventory + Auth atomic batch — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `43-CONTEXT.md`.

**Date:** 2026-04-20  
**Phase:** 43 — Audit inventory + Auth atomic batch  
**Areas discussed:** (1) AUD-04 inventory artifact, (2) AUD-05 Auth prioritization, (3) Exclusions register, (4) Verification layout, (5) Delivery waves  
**Method:** User selected **all** areas; orchestrator ran **five parallel `generalPurpose` research subagents** (Composer 2) on inventory docs, risk-based auth ordering, exclusion templates, ExUnit library patterns, and doc-first vs combined PR delivery; orchestrator synthesized with Phase 39/41 context and `lib/sigra/auth.ex` dispatch comments.

---

## (1) AUD-04 inventory artifact

| Approach | Description | Selected |
|----------|-------------|----------|
| Single file | One markdown for all rows + exclusions | |
| Split / sections | Inventory table + exclusions appendix (+ optional batch list) | ✓ (primary: split concerns; optional second section) |
| Machine-readable | YAML/JSON canonical + generated MD | ✓ deferred unless >~30 sites |

**User's choice:** Research-synthesized default — **split-style** artifact under phase dir, **use-case/event-key** granularity, **stable AUD-04-NNN IDs**, **no** machine-readable twin for v1.4 Auth scope.

**Notes:** Hex-idiomatic public spine remains **CHANGELOG** + guides; `.planning/` inventory is maintainer contract + audit evidence tree.

---

## (2) AUD-05 Auth batch ordering

| Approach | Description | Selected |
|----------|-------------|----------|
| Ad hoc | Planner picks arbitrary order | |
| Risk-ordered stack | Credential change → bulk invalidation → session mint → lockout → magic link → register → reset request → logout → failure-only | ✓ |

**User's choice:** Locked **D-43-02** nine-tier stack (see CONTEXT.md), aligned OWASP-style trust ordering + `auth.ex` comment block; confirm/reset/confirm-code paths **excluded** as already atomic.

---

## (3) Exclusions & deferrals

| Approach | Description | Selected |
|----------|-------------|----------|
| Minimal high-signal register | Every hybrid row → convert, forward, or exclusion row with full fields | ✓ |
| Exhaustive matrix | Large component × control grid | Rejected for v1.4 small-team |

**User's choice:** **EXC-*** / table template with REQ, scope, risk, compensating control, owner, reopen trigger, evidence, last reviewed.

---

## (4) Verification layout

| Approach | Description | Selected |
|----------|-------------|----------|
| Dedicated atomicity modules | `*_audit_atomicity_test.exs` + shared IntegrationCase | ✓ |
| Spread only | Audit assertions only in feature tests | Rejected as primary |

**User's choice:** Dedicated atomicity tests + **partial assertions** + **ordered queries** + real Repo; example app for merge-blocking slice where host-shaped (Phase 41 precedent).

---

## (5) Delivery shape

| Approach | Description | Selected |
|----------|-------------|----------|
| Two-wave | AUD-04 doc merge → AUD-05 code PR(s) | ✓ default |
| One-wave | Single PR doc+code | Allowed only tiny scope + disciplined commits |

**User's choice:** **Wave A** inventory on **main** as batching authority; **Wave B** conversions.

---

## Claude's discretion

- ID formatting, PR splitting within Wave B, minor test helper naming.

## Deferred ideas

- Static-analysis-generated inventory; MFA/OAuth batches (Phases 44–45).
