# Phase 49: Phase 45 verification, AUD-08 & C-1 reconciliation — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in **`49-CONTEXT.md`**.

**Date:** 2026-04-21  
**Phase:** 49 — phase-45-verification-aud08-c1  
**Areas discussed:** `45-VERIFICATION.md` shape; C-1 vs inventories; merge gate (alias / paths / tags); PR closure ordering  

**Method:** User requested **all** gray areas with **parallel subagent research** (`generalPurpose` × 4); primary agent synthesized tables + ecosystem notes into locked decisions (**D-49-01**–**D-49-04**).

---

## 1 — `45-VERIFICATION.md` shape (AUD-08)

| Option | Description | Selected |
|--------|-------------|----------|
| A | Single `45-VERIFICATION.md` with subsections per surface; `45-VALIDATION.md` living; Phase 9 paired | ✓ |
| B | Split verification files + index | |
| C | Minimal doc; C-1 matrix only | |

**Research highlights:** Kubernetes conformance (versioned pass/fail), OpenTelemetry (stability vs experimental semconv), Rails `paper_trail`/`audited` (weak txn-boundary docs), Go sumdb (repro hooks ≠ threat model), Rust RFC (intent vs shipped drift). **Elixir/Hex idiom:** conformance = **dated commands + CI**; long maps = maintainer docs in-repo.

**User's choice:** **A** (cohesive with 43/44/48).

**Notes:** Phase 9 answers “what should be true”; phase verification answers “what we ran to close AUD-08.”

---

## 2 — C-1 narrative vs `43` / `44` / `45` inventories

| Option | Description | Selected |
|--------|-------------|----------|
| A | One consolidated matrix (exhaustive only) | (acceptable if grouped) |
| B | Three **exhaustive** C-1 subsections; thin rows; inventories canonical for prose | ✓ |
| C | Pointers only; matrices only in phase files | |

**Research highlights:** SOC2/OWASP-style readers want **population + trace + pinned pointers**; SPDX/ADR footguns = stale IDs, duplicated tables, “representative” without population.

**User's choice:** **B** + **C-0 completeness** block (counts, mechanical check, no representative-only without exclusions).

---

## 3 — Merge gate (verbatim commands)

| Option | Description | Selected |
|--------|-------------|----------|
| A | Raw `mix test` path list only | (inside alias) |
| B | `--only` tags; guard against 0 matches | (secondary local) |
| C | **`mix ci.audit_45`** alias as **contract**; paths or guarded tags inside | ✓ |

**Research highlights:** Jest `testPathPattern` / Go `-run` / Minitest tags share **vacuous filter** footgun; **nextest**-style committed filters scale. **ExUnit:** `--only` with 0 tests → exit 0 is a **critical** hazard.

**User's choice:** **C** primary; explicit paths inside alias preferred; tags optional for local speed with guard if used in gate.

---

## 4 — PR / closure ordering

| Option | Description | Selected |
|--------|-------------|----------|
| A | Single atomic PR (verification + Phase 9 + REQ + roadmap if needed) | ✓ |
| B | Ordered PRs with strict enforcement | (exception only) |
| C | `status: draft` on `main` for WIP | (non-closure transparency only) |

**Research highlights:** Semver/release trains and KEP-style processes fail on **status ahead of evidence**; GitHub “definition of done” needs machine-checkable linkage.

**User's choice:** **A** default; **B** only with enforced ordering; **C** never satisfies REQ until final merge.

---

## Claude's discretion

- Alias naming collision handling; choice of guard mechanism for non-zero proof tests; subsection ordering in verification doc.

## Deferred ideas

- Split verification files; undifferentiated mega-matrix; unguarded tag-only merge gates — see **`49-CONTEXT.md` `<deferred>`**.
