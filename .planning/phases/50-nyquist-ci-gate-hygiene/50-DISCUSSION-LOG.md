# Phase 50: Nyquist validation & CI gate hygiene - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `50-CONTEXT.md` — this log preserves alternatives considered.

**Date:** 2026-04-21  
**Phase:** 50 — Nyquist validation & CI gate hygiene  
**Areas discussed:** Nyquist 41–44 closure posture; expensive in-repo / subprocess tests; installer golden nested host; validation artifact scope  
**Method:** User requested **all** areas + parallel **generalPurpose** subagent research briefs; maintainer synthesized into **D-50-01..04**.

---

## 1. Nyquist outcome for phases 41–44

| Option | Description | Selected |
|--------|-------------|----------|
| A — Full validate-phase | Drive every `*-VALIDATION.md` to `nyquist_compliant: true` | |
| B — Waivers only | Leave false; bulk waiver without full maps | |
| C — Hybrid + policy table | Full Nyquist where cheap/honest; waiver + superseding evidence where expensive or redundant; one published table | ✓ |

**User's choice:** Delegated to maintainer synthesis — **Hybrid (C)** with explicit waiver discipline (phase 36 lineage) and a **single policy table**.  
**Notes:** Avoids merge theater and release drag while staying honest when scoped verification (47–48) already closed product risk.

---

## 2. golden_diff / long library CI tests

| Option | Description | Selected |
|--------|-------------|----------|
| Default ExUnit excludes + second job | Fast PR, risk of local/CI drift vs this repo's invariant | |
| Timeouts + engineering + schedule / path layering | Keep default `mix test` contract; add hygiene and layered CI without silent skips | ✓ |
| Manual-only heavy suite | Lowest CI cost, highest ship risk | |

**User's choice:** Synthesis — **respect `test/test_helper.exs` + CLAUDE.md parity**; prefer timeouts, determinism, docs, scheduled drift checks, and **nested** job/alias pattern over default excludes.  
**Notes:** Subagent “tag exclude” path was **rejected** as conflicting with stated project invariant unless explicitly amended later.

---

## 3. Installer golden nested `mix test`

| Option | Description | Selected |
|--------|-------------|----------|
| `mix ci.install_golden` + CI job + path filter + always on main | Named contract, cache isolation, aligned with `ci.audit_45` | ✓ |
| Docs-only manual | Poor release confidence | |
| Run only nightly | Useful as add-on, insufficient alone for generator changes | |

**User's choice:** **`mix ci.install_golden`** flat alias + dedicated CI job + path filter + **always on `main`** + optional schedule.  
**Notes:** Matches ecosystem pattern (Rails dummy app / codegen CI) and Sigra’s existing installer audit job shape.

---

## 4. Validation artifact scope (Nyquist policy)

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal — VALIDATION only | Fast, drift risk vs indexes | |
| Holistic — VALIDATION + VERIFICATION + light index links | Single atomic change set; SSoT for `nyquist_compliant` | ✓ |
| Sprawl — duplicate full commands everywhere | Anti-pattern | |

**User's choice:** **VALIDATION + VERIFICATION** as phase-local pair; **index docs** get links/status only — update together when closing batch.

---

## Claude's Discretion

- Schedule cadence; exact `50-VALIDATION.md` shape (rollup vs pointer-only), micro-copy in index docs.

## Deferred Ideas

- Default tag exclusions for in-root heavy tests — see `50-CONTEXT.md` `<deferred>`.
