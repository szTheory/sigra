# Phase 47: Phase 43 verification & AUD-04/05 closure — Discussion log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `47-CONTEXT.md`.

**Date:** 2026-04-21  
**Phase:** 47 — phase-43-verification-aud0405  
**Areas discussed:** Nyquist vs validation doc; `43-VERIFICATION` vs `43-VALIDATION` shape; merge vs release CI gate; REQUIREMENTS PR hygiene  
**Mode:** User selected **all** areas; four `generalPurpose` research subagents ran in parallel; maintainer chose **one-shot synthesized recommendations** (no per-turn conversational prompting).

---

## 1. Nyquist vs `43-VALIDATION.md` (“if required”)

| Option | Description | Selected |
|--------|-------------|----------|
| A | Full Nyquist now; flip `nyquist_compliant: true` |  |
| B | Evidence-first validation updates; defer formal Nyquist to phase **50** | ✓ |
| C | Versioned partial Nyquist subset only if explicitly needed | (optional) |
| D | Editorial merge only without honesty policy |  |

**User's choice:** Locked to **B** after research synthesis (aligns ROADMAP “if required” with phase **50** ownership; avoids false compliance labels).

**Notes:** Elixir OSS norms favor reproducible CI + documented commands over ornate taxonomy unless rigor is productized. Rails/Django/Go patterns warn against checkbox theater without pinned commands.

---

## 2. `43-VERIFICATION.md` document architecture

| Option | Description | Selected |
|--------|-------------|----------|
| A | Mirror **46** only; drop or orphan validation map |  |
| B | Single merged mega-file |  |
| C | Short **VERIFICATION** (outcome) + **VALIDATION** (contract/map) | ✓ |
| D | (C) plus explicit ownership rules for duplicated commands | ✓ |

**User's choice:** **C + D** — `43-VERIFICATION.md` frozen snapshot; `43-VALIDATION.md` appendix; snapshot copies commands at sign-off.

**Notes:** K8s-style conformance favors bounded reports + deeper maps; duplication drift is the main footgun (addressed by authority rule).

---

## 3. “Passes project gate” / CI depth

| Option | Description | Selected |
|--------|-------------|----------|
| A | Full root `mix test` only |  |
| B | Scoped tests + explicit paths only | Partial (minimum merge gate) |
| C | Tiered PR vs release jobs | ✓ (vocabulary) |
| D | Named “merge gate” vs “release attestation” blocks | ✓ |

**User's choice:** **D** with **B** as minimum merge evidence and **A** (or CI full job) as optional release attestation; scoped list must map to AUD/inventory claims.

**Notes:** Rust workspace / Node affected-test patterns support scope-by-boundary; atomic audit claims need falsifiable DB-backed commands, not format-only checks.

---

## 4. REQUIREMENTS / ROADMAP reconciliation PR strategy

| Option | Description | Selected |
|--------|-------------|----------|
| A | Single PR: verification + REQUIREMENTS (+ ROADMAP if needed) | ✓ |
| B | Split PRs with strict ordering | (fallback only) |
| C | Fix table drift only when file touched anyway | Rejected for known drift |

**User's choice:** **A** — atomic closure; never mark AUD complete before verification artifact on `main`.

**Notes:** Matches `43-CONTEXT` guardrail on AUD-04 closure ordering.

---

## Claude's discretion

- Minor frontmatter field naming vs **46** template.  
- Optional Mix alias for stable `mix test` entry point.  
- Exact wording of Nyquist deferral paragraph.

## Deferred ideas

- Full Nyquist for **41–44** — phase **50**.  
- AUD-06+ / C-1 — phases **48–49**.
