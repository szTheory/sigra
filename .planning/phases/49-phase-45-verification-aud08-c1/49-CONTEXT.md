# Phase 49: Phase 45 verification, AUD-08 & C-1 reconciliation — Context

**Gathered:** 2026-04-21  
**Status:** Ready for planning

**Source:** User selected **all** gray areas; four parallel **generalPurpose** research passes (verification doc shape, C-1 vs inventories, merge gate mechanics, PR closure ordering) synthesized into one policy set aligned to **45-CONTEXT**, **47-CONTEXT**, **48-CONTEXT**, ROADMAP phase **49**, and Sigra’s **honest GA / SEED-002** posture.

<domain>

## Phase boundary

Publish **`45-VERIFICATION.md`** (dated outcome + receipts), close **AUD-08** in `.planning/REQUIREMENTS.md`, and reconcile **`.planning/phases/09-audit-logging/09-VERIFICATION.md` C-1** with **row-level** traceability across **`43-AUD-04-INVENTORY.md`**, **`44-AUD-04-INVENTORY.md`**, and **`45-AUD-04-INVENTORY.md`** — **without** re-executing Phase **45** implementation work (that remains phase **45**).

Formal **Nyquist** batch **41–44** remains **phase 50** unless explicitly escalated; phase **49** closes falsifiable **AUD-08** evidence and requirement bookkeeping for **phase 45** plus **Phase 9 C-1** narrative honesty (same division of labor as **47**/**48** for **43**/**44**).

</domain>

<decisions>

## Implementation decisions

### D-49-01 — `45-VERIFICATION.md` shape (single file + subsections)

- **Adopt Option A:** **One** `45-VERIFICATION.md` with **subsections** aligned to AUD-08 surfaces (e.g. OAuth domain mutations vs T2 boundaries, lockout / suspicious login, impersonation, workers such as account deletion), mirroring **`43-VERIFICATION.md`**, **`44-VERIFICATION.md`**, and **D-48-02** (single verification surface per phase closure).
- **Separation of concerns:** **`45-VALIDATION.md`** remains the **living** map (sampling, per-row honesty, links during execution); **`45-VERIFICATION.md`** is the **frozen** “what we demonstrated, with which commands, on which tree” snapshot — do not collapse that into Phase 9 alone.
- **Phase 9 role:** **`09-VERIFICATION.md` / C-1** answer “what should be true across inventories”; **`45-VERIFICATION.md`** answers “what we ran to close **AUD-08** for phase **45** work” — **paired**, not redundant substitutes.
- **Split files (Option B):** Deferred — only revisit if concurrent ownership makes a single file unmaintainable; if so, add an **index** that preserves one merge gate and one auditor door.
- **Minimal verification + matrix only (Option C):** **Reject** as sole closure — matrices rot without verbatim commands, PASS lines, and dated scope; invites “checkbox theater.”

**Footgun to avoid:** Duplicating long narrative from **`45-VALIDATION.md`** into verification without an **authority rule** (snapshot vs living map) — follow **D-47-02**: at sign-off, **verbatim commands** live in **`45-VERIFICATION.md`**.

### D-49-02 — C-1 narrative vs three inventories (exhaustive sub-matrices)

- **Adopt Option B (exhaustive sub-matrices in `09-VERIFICATION.md`):** Three explicit **C-1 subsections** keyed to **`43-AUD-04-INVENTORY.md`**, **`44-AUD-04-INVENTORY.md`**, and **`45-AUD-04-INVENTORY.md`**, each claiming **full row coverage** for that file.
- **Thin matrix pattern:** Rows are **ID → mechanism / tier (as locked in 45-CONTEXT T1/T2/T3) → verdict → evidence pointer** (test module, plan summary path, or artifact); **requirement wording stays canonical in the inventory files** — do not maintain a second prose corpus in the matrix.
- **C-0 completeness block (mandatory):** Add a short **completeness** preamble: counts per inventory, expected **AUD-04-xxx** blocks / ranges, and a **mechanical** check (script or documented `grep` / checklist) that the union of inventory row IDs matches what C-1 claims — **no “representative only”** unless the **excluded population** is explicitly listed with owner + trigger (same honesty bar as **D-45-05**).
- **Option A (one giant flat matrix):** Acceptable **only** if still **exhaustive** and **grouped by source inventory** — not a trimmed “sample.”
- **Option C (pointers only; matrices only in phase verification files):** **Reject as sole pattern** — too much auditor chasing; use **only** as **deep links** from the subsection headers or per-row evidence columns.

**Footguns to avoid:** Stale relative links; duplicated requirement tables that diverge; “representative rows” without defined population — fails ROADMAP criterion (2).

### D-49-03 — Merge gate: Mix alias as contract, paths or guarded tags inside

- **Primary merge gate:** Introduce a **Mix alias** (name **`mix ci.audit_45`** unless a naming collision forces adjustment) as the **single contractual command** cited **verbatim** in **`45-VERIFICATION.md`** under **Automated checks run** — idiomatic Elixir OSS “project-defined CLI,” easy for contributors and auditors to grep and CI to pin.
- **Implementation of the alias:** Prefer **explicit `mix test` path lists** *inside* the alias (mirrors **`43-VERIFICATION.md` today**) for **reviewability** and to avoid **vacuous pass** (`mix test --only tag` with **0 tests** still exits 0). If **`--only`** is used, **pair with a guard**: minimum test count, manifest check, or tiny Mix task that fails when no proofs ran.
- **Secondary (local DX):** Optional **namespaced ExUnit tags** (e.g. scope `audit_atomicity:45`) for fast iteration while editing one surface — **not** the sole cited merge gate unless guarded as above.
- **Inventory binding:** Prefer the **verification / alias / table** triangle to make it obvious **which inventory rows** the gate implies (table row → test path; or generated list from inventory — planner may choose).

**Footgun to avoid:** “Green CI” where the command subset **does not** cover the rows marked Pass in C-1 — same “process theater” risk called out in **D-47-03** / **D-48-01**.

### D-49-04 — PR / closure ordering (atomic default; draft is non-closure)

- **Default: single atomic PR** closing **AUD-08**: includes **`45-VERIFICATION.md`** (final **`status: passed`** or project equivalent), **`09-03-SUMMARY.md`** and **`09-VERIFICATION.md`** (C-1 updates per **D-45-05**), **`REQUIREMENTS.md`** (checkbox + traceability table), **`ROADMAP.md`** only if narrative drift — so **`main` never shows AUD-08 satisfied without** the verification bundle in the **same** merge (extends **D-47-04** / **D-48-02**).
- **Ordered PRs (exception):** Allowed only with **hard ordering** and enforcement (evidence on `main` **before** REQ flip; link in PR body; ideally CI/bot fails REQ-only PRs) — if enforcement is weak, **do not use**; atomic PR is safer.
- **`status: draft` on `main`:** **Optional transparency only** — **`REQUIREMENTS.md` stays Pending**; banner states scope and “not closure”; prefer **draft PRs** for WIP verification prose to avoid auditors reading **`main`** as done (**D-48-04** spirit).

**Invariant:** Zero ambiguous window where **AUD-08** reads satisfied on `main` without non-draft verification artifacts that support the claim.

### Claude's discretion

- Final **`mix ci.audit_45`** name if `mix.exs` naming collides with existing aliases.  
- Whether the **non-zero test guard** is a small Mix task vs CI step vs documented manual check — pick lowest-friction **honest** option for this repo.  
- Exact subsection titles in **`45-VERIFICATION.md`** and **C-1** subsection ordering (43 → 44 → 45 vs risk-based ordering) — content rules above win.

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — **AUD-08**, traceability table, exclusion rules  
- `.planning/ROADMAP.md` — Phases **45** (implementation), **49** (this closure), **50** (Nyquist **41–44** + CI hygiene)  
- `.planning/PROJECT.md` — v1.4 GA readiness & audit completeness narrative  

### Prior closure & implementation context

- `.planning/phases/47-phase-43-verification-aud0405/47-CONTEXT.md` — Nyquist deferral, two-file verification pattern, tiered gates, PR hygiene  
- `.planning/phases/48-phase-44-verification-aud0607/48-CONTEXT.md` — Dual-req single file, merge gate, draft policy  
- `.planning/phases/45-oauth-ops-c1-signoff/45-CONTEXT.md` — T1/T2/T3, EX-*, Phase 9 C-1 falsifiability (**D-45-05**)  
- `.planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md` — Phase **45** inventory rows  
- `.planning/phases/45-oauth-ops-c1-signoff/45-VALIDATION.md` — Living map during phase **45** execution  
- `.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md`  
- `.planning/phases/43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md`  
- `.planning/phases/43-audit-inventory-auth-atomic-batch/43-VERIFICATION.md` — Structural template for **`45-VERIFICATION.md`**  

### Normative semantics

- `docs/audit-semantics.md` — Primitives, C-1 / co-fate vocabulary (**D-45-05**)  

### Phase 9 deliverables (created/updated per phase **45** / **49**)

- `.planning/phases/09-audit-logging/09-03-SUMMARY.md`  
- `.planning/phases/09-audit-logging/09-VERIFICATION.md` — **C-1** sections  

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- **`43-VERIFICATION.md` / `44-VERIFICATION.md`** — Frontmatter, Must-haves → Evidence, merge gate, automated checks, notes including phase **50** deferral.  
- **`45-VALIDATION.md` + `45-0x-SUMMARY.md` + `45-AUD-04-INVENTORY.md`** — Evidence sources and row IDs for **`45-VERIFICATION.md`**.  
- **`mix.exs` aliases** — Natural home for **`mix ci.audit_45`** (or chosen name).

### Established patterns

- **Frozen verification vs living validation** — Proven in **47-CONTEXT** (**D-47-02**).  
- **Tiered gates** — Scoped DB-backed proof + optional full-suite attestation (**D-47-03**, **D-48-01**).

### Integration points

- **`REQUIREMENTS.md` AUD-08 row** — Flip only per **D-49-04** invariants.  
- **Phase **50**** — Cross-phase Nyquist; phase **49** does not subsume that ownership.

</code_context>

<specifics>

## Specific ideas

- User asked for **all** discuss areas in one pass with **parallel subagent research**, then a **single cohesive recommendation set** emphasizing defensible audit evidence, contributor DX, least surprise, ecosystem idioms (Elixir/Mix/ExUnit, plus patterns from Kubernetes conformance, OpenTelemetry stability tiers, Rails audit gems, Go/Ruby/Jest-style gates), and alignment with Sigra’s **honest GA** and **SEED-002** goals.

</specifics>

<deferred>

## Deferred ideas

- **Split `45-VERIFICATION` into multiple files** — only if single-file merge/review cost becomes prohibitive; require index + one composed merge gate.  
- **C-1 as one flat undifferentiated matrix** — only if kept exhaustive and grouped by inventory; default remains **three subsections**.  
- **Vacuous `--only` tag runs** — any tag-only gate must ship with a **non-zero proof** guard in implementation phases.

### Reviewed todos (not folded)

- None — `todo.match-phase "49"` returned empty.

</deferred>

---

*Phase: 49-phase-45-verification-aud08-c1*  
*Context gathered: 2026-04-21*
