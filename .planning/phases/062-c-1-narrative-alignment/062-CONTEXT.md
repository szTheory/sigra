# Phase 62: C-1 narrative alignment - Context

**Gathered:** 2026-04-23  
**Status:** Ready for planning

<domain>
## Phase Boundary

Close **AUD-02**: **`.planning/phases/09-audit-logging/09-03-SUMMARY.md`** reflects **post–phase-61** (and ongoing bounded **SEED-002**) reality so the **C-1** story cannot silently drift from code or from **`09-VERIFICATION.md`**. **`09-VERIFICATION.md`** is touched **only when applicable** (per REQUIREMENTS): targeted consistency fixes—**not** a second full matrix-authoring pass, because phase **61** already owned matrix rows for the shipped batch (**061-CONTEXT D-08/D-09**).

</domain>

<decisions>
## Implementation Decisions

### Executive summary depth (`09-03-SUMMARY.md`)

- **D-01:** Use **moderate** depth (between “stamp only” and “rich narrative”). Include: (a) a **milestone / phase stamp** so readers know currency; (b) a short **“Recent bounded batches”** (or equivalent) subsection **per shipped batch** that affects C-1 narrative—starting with **phase 61 / AUD-01**; (c) **one exemplar `AUD-04-*` id** per batch (e.g. **AUD-04-067**) with wording of the form **“see C-1 row … in `09-VERIFICATION.md`”**—**not** re-copying mechanism / tier / verdict columns from the matrix.
- **D-02 (anti-pattern guard):** Do **not** turn the summary into a second matrix or a changelog of test filenames. Row-level truth stays in **`09-VERIFICATION.md`** and inventories; summary records **intent, requirement id, and pointers**.

### Title and era framing

- **D-03:** **Stable topical `H1`** (purpose + domain: audit logging / C-1 orientation)—**avoid** implying the file stopped at **v1.4** as the only era signal in the title alone (skimmers and link previews misread frozen-era titles).
- **D-04:** Immediately under `H1`, add a fixed-shape **“Document status”** (or equivalent) block: **last materially updated for** (semver / milestone), **planning trace** (phase ids, e.g. 9 → 61 → 62), **canonical verification** link (`09-VERIFICATION.md`), optional **“see also”** to `REQUIREMENTS.md` **AUD-02** line. Volatile era lives here, not buried only in prose.

### `09-VERIFICATION.md` scope in phase 62

- **D-05 (default):** Primary artifact is **`09-03-SUMMARY.md`**. Treat **`09-VERIFICATION.md`** as **already authoritative** for matrix rows updated in phase **61**.
- **D-06 (lightweight reconciliation — hybrid “A+”):** Before merge, **read** C-1 rows (and inventory rows) **cited or implied** by the new summary text; confirm **wording, links, and ids** still match. **Edit `09-VERIFICATION.md` only if** you find a mismatch, broken anchor, missing caveat implied by new summary language, or REQUIREMENTS explicitly demand a caveat row update.
- **D-07 (when to widen verification work):** Expand beyond D-06 only if: verification was **not** updated in the same PR as behavior change; **ids/paths renamed**; summary introduces a **new** residual-risk / scope boundary not reflected in matrix or inventories; external audit / release gate; or multi-phase **slip** (code moved, matrix lagged).

### Canonical links and information architecture (L0 / L1 / L2)

- **D-08 (L0 — summary):** Keep **~4–8 canonical egresses**: the **43 / 44 / 45** `*-AUD-04-INVENTORY.md` files, **`docs/audit-semantics.md`**, **`09-VERIFICATION.md`** as the **single** C-1 matrix hub. Optional: **one** program-level pointer (e.g. `.planning/REQUIREMENTS.md` **AUD-02**) if it helps traceability—**not** a mesh of phase `061-*` execution docs from the summary header.
- **D-09 (L1/L2):** Row-specific evidence, **061** provenance, and deep **`PLAN` / phase `VERIFICATION`** links belong in **`09-VERIFICATION.md`** rows and/or **inventory** notes—not routine new links from **`09-03-SUMMARY.md`** (reduces link rot and “summary as site map” anti-pattern).
- **D-10:** Preserve the **canonical triangle** for audit posture: **three inventories + `09-VERIFICATION.md` + semantics doc**; phase folders remain **provenance**, not navigation roots from L0.

### Cohesion with phase 61 and project vision

- **D-11:** Phase **62** does **not** re-litigate matrix **mechanism/tier/verdict** edits that phase **61** already shipped; it **orients** readers and **prevents narrative drift** between executive summary and the merge-gated matrix—aligned with **honest C-1**, **least surprise**, and **maintainer DX** (small, link-heavy, low prose duplication).

### Claude's Discretion

- Exact **subsection title** (“Recent bounded batches” vs “Rolling SEED-002 alignment”), micro-copy in the status block, and whether to add a **future** CI helper that greps summary-mentioned **AUD-04-*** ids against `09-VERIFICATION.md` (not required for AUD-02 closure).

</decisions>

<specifics>
## Specific Ideas

- Research synthesis (parallel review): **moderate** summary depth beats minimal (context gap) and rich (duplicate authority / stale prose); **stable H1 + status block** beats era-only titles for security-adjacent docs; **hybrid A+** for verification scope; **thin L0 / rich L1** linking matches ExDoc-style overview → reference and common compliance **narrative vs control-register** splits.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and traceability

- `.planning/REQUIREMENTS.md` — **AUD-02** (phase 62), **AUD-01** (phase 61 shipped scope)
- `.planning/ROADMAP.md` — Phase **62** goal row (v1.7)
- `.planning/PROJECT.md` — v1.7 milestone (audit durability + adoption)

### Prior phase context (boundary)

- `.planning/phases/061-seed-002-bounded-batch/061-CONTEXT.md` — **D-08/D-09**: matrix updates in **61**; **62** owns **summary** + holistic narrative alignment

### Phase 9 C-1 surfaces (edit targets)

- `.planning/phases/09-audit-logging/09-03-SUMMARY.md` — primary **AUD-02** deliverable
- `.planning/phases/09-audit-logging/09-VERIFICATION.md` — C-1 matrix hub; **conditional** edits per **D-06/D-07**

### Normative vocabulary and inventories

- `docs/audit-semantics.md` — T1/T2, co-fate vocabulary
- `.planning/phases/43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md`
- `.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md` — includes **AUD-04-067** definition context
- `.planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **`09-VERIFICATION.md`** — already contains **Phase 61** narrative and **AUD-04-067** row; use as **single matrix authority** when reconciling summary text.
- **`09-03-SUMMARY.md`** — existing **inventory table**, **trust model** bullets, and **pointer to C-1**; extend with **status block** + **bounded-batch** subsection without restructuring the whole file.

### Established patterns

- **Merge-gated planning docs**: exhaustive rows live in **verification**; executive files stay **thin and link-heavy** (Sigra v1.4+ audit phases).
- **061-CONTEXT** explicitly reserved **062** for summary / cross-cutting prose (**D-09**).

### Integration points

- **REQUIREMENTS.md** checkboxes: **AUD-02** flips to complete when summary (+ any required verification touch) merges.
- **STATE.md** / milestone honesty: phase **62** completion should match observable doc truth under `.planning/phases/09-audit-logging/`.

</code_context>

<deferred>
## Deferred Ideas

- **Automated id consistency check** (CI or script): grep **AUD-04-*** ids mentioned in `09-03-SUMMARY.md` against presence in `09-VERIFICATION.md`—valuable, not part of minimal **AUD-02** closure unless explicitly pulled in.

### Reviewed Todos (not folded)

- None surfaced by `todo.match-phase` for phase **62**.

</deferred>

---

*Phase: 062-c-1-narrative-alignment*  
*Context gathered: 2026-04-23*
