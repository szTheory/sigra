# Phase 48: Phase 44 verification & AUD-06/07 closure — Context

**Gathered:** 2026-04-21  
**Status:** Ready for planning

**Source:** `/gsd-discuss-phase 48` with **all** gray areas selected; four parallel research passes (merge gate / PR shape / validation-vs-Nyquist / partial verification) synthesized into one policy set aligned to **47-CONTEXT**, **44-CONTEXT**, ROADMAP phase **48**, and phase **50** Nyquist ownership.

<domain>

## Phase boundary

Publish **`44-VERIFICATION.md`** (dated outcome + receipts), reconcile **AUD-06** and **AUD-07** in `.planning/REQUIREMENTS.md` (and ROADMAP narrative if needed) with **phase 44** inventories, plan summaries, validation map, and atomicity tests — **without** doing MFA/Account/API implementation work (that remains **phase 44**).

Formal **Nyquist** sign-off for phases **41–44** remains **phase 50** unless an explicit project exception is recorded; phase **48** closes falsifiable evidence and requirement bookkeeping for **44** only (same division of labor as **47** for **43**).

</domain>

<decisions>

## Implementation decisions

### D-48-01 — Merge gate vs release attestation (hybrid, drift-resistant)

**Adopt the same tiered story as D-47-03**, tuned for MFA + Account + API-token atomicity claims:

1. **Merge gate (contributor-realistic, audit-meaningful)**  
   - **`mix compile`** with the repo’s normal warnings policy (include `--warnings-as-errors` if `main` already treats that as non-negotiable).  
   - **Scoped `mix test`** that **enumerates every boundary** claimed complete for **AUD-06** and **AUD-07** (file paths and/or **ExUnit tags** such as `@tag :audit_atomicity` — **prefer tags or a Mix alias** over a hand-maintained path list that can silently drift when files move).  
   - **Canonical command strings** must appear **verbatim** in `44-VERIFICATION.md` at sign-off (snapshot authority), with `44-VALIDATION.md` as the living map that may evolve during execution.

2. **Release attestation (optional but recommended before REQ flips)**  
   - **Full** root `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` **or** a **named CI workflow/job** at a **pinned commit SHA** (record URL / job id). Same rationale as phase **47**: scoped tests prove **co-fate** invariants; full suite proves **global regression** and optional-dep matrices.

3. **DX / least surprise (Elixir & Hex OSS idioms)**  
   - Prefer a **stable Mix alias** (e.g. `mix ci.audit_44`) that expands to the merge-gate filter when it reduces copy-paste drift; document the alias in `44-VERIFICATION.md` when introduced.  
   - **Footgun to avoid:** “Green” without commands tied to **inventory row IDs** and **test module names** — that reads as process theater to auditors and fails Sigra’s honest GA posture.

**Cohesion with prior work:** This is intentionally the **same ladder** as phase **43** verification (`43-VERIFICATION.md`) and **D-47-03**, extended to the **44** test surface.

### D-48-02 — Single `44-VERIFICATION.md`, REQ reconciliation, and PR shape

**Document architecture**

- **One** `44-VERIFICATION.md` with **separate subsections / must-have tables** for **AUD-06** vs **AUD-07** (mirrors how **43** treated **AUD-04** + **AUD-05** in one file with distinct evidence rows).  
- **Authority:** `44-VALIDATION.md` may hold canonical commands during active work; at sign-off, **copy verbatim** into `44-VERIFICATION.md` (same boundary as D-47-02).

**PR / checkbox policy (aligned to D-47-04, refined by bisect/review research)**

- **Default (preferred when both batches complete together):** **Single atomic PR** on `main` that contains **`44-VERIFICATION.md`** (new) **and** updates **`REQUIREMENTS.md`** (both **AUD-06** and **AUD-07** checkboxes + traceability table) **and** **`ROADMAP.md`** only if narrative drift — so `main` **never** shows both requirements satisfied **without** the verification artifact and merge-gate receipts in the **same** change-set. This matches **47** closure hygiene and minimizes “checkbox before evidence” windows.

- **Exception (when one batch lands materially earlier):** **Split merges** are allowed **only** with strict ordering: **PR adds evidence (tests/docs) for AUD-06 or AUD-07 → merge → then** a follow-up may flip **only** the satisfied requirement’s checkbox **in the same PR as the evidence** for that REQ (never the reverse order). The **single** `44-VERIFICATION.md` is updated **monotonically** (append or revise dated sections; no second competing verification file).

- **Release notes / changelog:** Even under one PR, call out **MFA vs Account/API** separately for consumer clarity (semver and migration risk).

### D-48-03 — `44-VALIDATION.md` vs Nyquist (“if required”)

- **Carry forward D-47-01:** Do **not** set `nyquist_compliant: true` or claim full Nyquist compliance in phase **48** unless an explicit decision moves that work forward from **phase 50**.  
- **Default policy:** **Evidence-first, Nyquist-deferred** — keep `44-VALIDATION.md` honest (per-row status, sampling notes, links to tests/docs); satisfy ROADMAP criterion (3) “Nyquist run if required” for phase **48** by **explicit cross-reference to phase 50** plus **scoped, falsifiable** verification in `44-VERIFICATION.md` — not checkbox theater.  
- **Optional bridge:** A **named, versioned partial** Nyquist-style slice may be recorded **only** if labeled **partial** and never as a silent substitute for the **41–44** batch owned by **50**.  
- **Living map vs snapshot:** Same two-layer rationale as D-47-02 — contract map evolves; verification snapshot freezes commands + outcomes for auditors.

### D-48-04 — Incomplete phase 44: draft verification vs deferring the closure phase

- **REQ checkboxes:** **Never** flip **AUD-06** / **AUD-07** to satisfied until the corresponding evidence is on **`main`** and recorded in `44-VERIFICATION.md` (same invariant as D-47-04).

- **Draft / blocked artifact (allowed for maintainer transparency):** A **`44-VERIFICATION.md` may exist early** only with:  
  - YAML frontmatter `status: draft` or `status: blocked`, and  
  - A **banner** stating scope (branch/commit), **what is not claimed**, and that **REQUIREMENTS rows remain Pending**.  
  - Prefer **strict row semantics** in linked validation material (`NOT STARTED` / `IN PROGRESS` / `BLOCKED` with owner+date / `VERIFIED` with evidence) over vague “partial.”

- **Final closure:** `status: passed` (or project-standard equivalent), dated **`verified`**, merge gate + optional attestation completed, **then** REQ + traceability updates in the **closure** PR.

- **Footgun to avoid:** Stale **blocked** rows — if used, they must be **time-bounded** (owner, last reviewed) or removed to prevent false freshness.

**Net:** **A-style workflow for maintainers** (visible gaps on `main`), **B-style clarity for external “done” claims** (REQ flips and `passed` verification only on a coherent green boundary).

### Claude's discretion

- Exact Mix alias name and whether tags vs explicit paths win for the **44** gate (prefer whichever stays most stable in this repo).  
- Minor YAML frontmatter field names on `44-VERIFICATION.md` (mirror **43** / **46** closely).  
- Wording of the phase **50** deferral paragraph.

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/ROADMAP.md` — Phases **44** (implementation), **48** (this closure), **50** (Nyquist **41–44**)
- `.planning/REQUIREMENTS.md` — **AUD-06**, **AUD-07**, traceability table, exclusion rules

### Prior closure precedent (process)

- `.planning/phases/47-phase-43-verification-aud0405/47-CONTEXT.md` — **D-47-01..04** (Nyquist deferral, two-file pattern, tiered gates, PR hygiene)
- `.planning/phases/43-audit-inventory-auth-atomic-batch/43-VERIFICATION.md` — Structure to mirror for `44-VERIFICATION.md`
- `.planning/phases/46-human-ga-matrix-gap-closure/46-VERIFICATION.md` — Frontmatter + receipt pattern (GA family)

### Phase 44 implementation artifacts (evidence sources)

- `.planning/phases/44-mfa-account-api-atomic-batches/44-CONTEXT.md` — Locked AUD-06/07 scope, Multi/audit patterns, testing bar
- `.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md` — Row IDs for MFA / Account / API slice
- `.planning/phases/44-mfa-account-api-atomic-batches/44-VALIDATION.md` — Per-task map (update honestly; see D-48-03)
- `.planning/phases/44-mfa-account-api-atomic-batches/44-01-SUMMARY.md` through `44-05-SUMMARY.md` — Plan narratives

### Audit implementation references

- `lib/sigra/audit.ex` — `log_safe/3`, `log_multi_safe/3`, `__log_internal__/3`
- `lib/sigra/mfa.ex`, `lib/sigra/account.ex`, `lib/sigra/api_token.ex` — Conversion surfaces for **44**
- `guides/recipes/testing.md` — Audit testing recipe (if present)
- `.planning/phases/39-audit-trail-completeness/39-CONTEXT.md` — Audit assertion patterns

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- **`43-VERIFICATION.md` + `47-CONTEXT`** — Proven closure template for inventory-backed audit phases.  
- **Phase 44 deliverables** — Inventory extension, validation map, summaries, and targeted `*_audit_atomicity_test.exs` modules planned in **44-CONTEXT** / **44-VALIDATION.md**.

### Established patterns

- **Tiered CI honesty** — Scoped DB-backed proof for atomic claims; full suite as attestation (not sole contributor gate).  
- **Single verification file, dual REQ rows** — Phase **43** verification covered two requirement IDs in one artifact; **48** repeats that for **AUD-06** + **AUD-07**.

### Integration points

- **`REQUIREMENTS.md` checkboxes** — Flip only per **D-48-02** / **D-48-04** invariants.  
- **Phase 50** — Cross-phase Nyquist; `44-VALIDATION.md` `nyquist_compliant` aligns with **D-48-03** unless explicitly escalated.

</code_context>

<specifics>

## Specific ideas

- User requested **all** gray areas with **subagent research** and a **single cohesive recommendation set** emphasizing defensible audit evidence, contributor DX, least surprise, and alignment with Sigra’s v1.4 GA / SEED-002 posture.

</specifics>

<deferred>

## Deferred ideas

- **Full Nyquist compliance** for phase **44** in isolation — **phase 50** (or explicit out-of-band decision).  
- **AUD-08** and Phase **9** C-1 narrative — **phase 49** per ROADMAP.

</deferred>

---

*Phase: 48-phase-44-verification-aud0607*  
*Context gathered: 2026-04-21*
