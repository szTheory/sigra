# Phase 75: Upgrade continuity + triage polish - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in **75-CONTEXT.md** — this log preserves the alternatives considered.

**Date:** 2026-04-23  
**Phase:** 75 — Upgrade continuity + triage polish  
**Areas discussed:** Upgrade stub shape; Intro/maintainer surfaces; Triage/issue outcome; ExDoc/link hygiene  
**Mode:** `[--all]` + parallel research subagents + user-requested one-shot synthesis (no interactive per-area Q&A)

---

## 1. Upgrade stub shape (TRN-01)

| Option | Description | Selected |
|--------|-------------|----------|
| A — Thin pointer + trust framing | Same family as **v1.11**; explicit “eight rows only in evidence file”; checklist + See also | ✓ |
| B — Full narrative | Multi-section essay; high drift risk | |
| C — Checklist-heavy | Temptation to duplicate UAT rows | |
| D — CHANGELOG companion | Duplicates release facts | |

**User's choice:** Delegated to research-backed synthesis — **Option A** locked as **D-75-01**..**D-75-06** in **75-CONTEXT.md**.

**Notes:** Cross-ecosystem pattern (Rails/Django/Next): **one canonical fact layer** + thin orientation. **Devise-wiki** footgun: duplicate matrices. **Elixir idiomatic:** **CHANGELOG** + short **extras** upgrade pages.

---

## 2. Intro / maintainer surfaces (TRN-02)

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal | **getting-started** only | |
| Balanced | **getting-started** + **MAINTAINING** + thin **CHANGELOG** hook | ✓ |
| Broad | + **README** + **first-hour** heavy | |

**User's choice:** **Balanced** — **D-75-07**..**D-75-11**; **README** explicitly **unchanged** (**D-75-10**) to avoid GitHub/Hex drift; **first-hour** default **skip**.

**Notes:** Phoenix/Elixir attention order: HexDocs guides → **CHANGELOG** on bump → **MAINTAINING** for release discipline. Single-sentence + stable links per surface.

---

## 3. Triage / issue outcome (TRN-03)

| Option | Description | Selected |
|--------|-------------|----------|
| A | Small doc edit only | |
| B | Append-only closure subsection in **`.planning/v1.11-TRIAGE.md`** | ✓ (primary) |
| C | Issue-linked | ✓ (conditional, **D-75-20**) |
| D | Phase summary only | (supplement only, **D-75-15**) |

**User's choice:** **B + D**; **C** if real issues exist.

**Notes:** Avoid **performative closure** and **triage churn**; **Kubernetes/RFC** lesson = explicit **state** next to original debt list.

---

## 4. ExDoc / link hygiene

| Option | Description | Selected |
|--------|-------------|----------|
| A | Extend **`skip_undefined_reference_warnings_on`** for new guide | Conditional |
| B | **GitHub `blob`** URLs to **`.planning/`** from published extras | ✓ (primary) |
| C | Copy evidence summary into **`docs/`** | |
| D | Plain text paths only | |

**User's choice:** **B** as default (**D-75-16**); **A** only if **`mix docs`** still requires it (**D-75-17**).

**Notes:** Grounded in **ExDoc** `autolink` behavior (relative `*.md` → extras basename resolution). **Footgun:** per-file skip silences **all** undefined-ref warnings from that file (**D-75-18**).

---

## Claude's Discretion

- Exact subsection titles; optional **09-VERIFICATION** one-liner (low priority).

## Deferred Ideas

- Migrate **v1.10** / **v1.11** upgrade guides to **blob URLs** and narrow skips — see **75-CONTEXT.md** `<deferred>`.
