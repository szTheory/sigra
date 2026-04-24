# Phase 74: Planning truth + launch evidence - Context

**Gathered:** 2026-04-24  
**Status:** Ready for planning

<domain>
## Phase Boundary

**AUD-12:** Update **`.planning/phases/09-audit-logging/09-03-SUMMARY.md`** so planning truth reflects the **post–phase-73** bounded **SEED-002** batch (MFA **AUD-04-023..032** narrative, planning trace, “Recent bounded batches”). When reconciliation is **D-06-class** (no **mechanism / tier / verdict** change in **C-1**), carry an explicit **“no `09-VERIFICATION.md` row edit required”** rationale with ids and evidence pointers—not silence.

**UAT-01:** Create **`.planning/v1.12-UAT-EVIDENCE.md`** with **eight SEED-001-aligned rows**: machine substitute pointer, residual human note, outcome per row (**Executed** / **Waived with substitute** / **Deferred** with owner/date/trigger when used). Single **milestone attestation** surface; do not fork the SEED×CI catalog into a second full matrix.

**UAT-02:** Add a **short** **v1.12** subsection to **`docs/uat-ci-coverage.md`** that points at the evidence file, states the division of labor (machine map vs release outcomes), and introduces **no contradictions** with existing SEED table, Policy, or **v1.4 GA** cross-links.

**Explicitly out of scope:** **`upgrading-to-v1.12.md`** and ExDoc extras ordering (**TRN-01**, phase **75**); intro/maintainer **CHANGELOG** / **MAINTAINING** trust-bundle surfacing beyond an optional **one-sentence** pointer if folded into the same PR for discoverability (**TRN-02**—prefer phase **75** unless trivial).

</domain>

<decisions>
## Implementation Decisions

### AUD-12 — `09-03-SUMMARY.md` and planning trace

- **D-74-01:** Extend **`09-03-SUMMARY.md`** with a **phase 73** entry under **Recent bounded batches**: **AUD-04-023..032** band, what shipped (inventory + **`09-VERIFICATION.md`** + tests), PR and validation pointers. Refresh **planning trace** and **“Last materially updated for”** to **v1.12** / phases **73–74** when this work lands.

- **D-74-02 (D-06-class attestation):** If reconciliation shows **no** **C-1** cell change, the **primary** attestation lives in **`09-03-SUMMARY.md`** (explicit **D-06 class**: ids reconciled, why **no `09-VERIFICATION.md`** body edit, links). **Optional:** at most **one short pointer line** in **`09-VERIFICATION.md`** C-1 preamble (e.g. “latest bounded attestation: see **09-03** § …”)—**no duplicated rationale** in two places. If **any** auditable column would change, **`09-VERIFICATION.md`** **must** diff in the same PR as the code/tests (**73-CONTEXT D-10** continuity).

### UAT-01 — `.planning/v1.12-UAT-EVIDENCE.md`

- **D-74-03:** **Canonical path** — **`.planning/v1.12-UAT-EVIDENCE.md`** only (matches **REQUIREMENTS.md**, **ROADMAP.md**, **PROJECT.md**); do not rename.

- **D-74-04 (shape):** **Short invariant preamble** (purpose, relationship to **`docs/uat-ci-coverage.md`**, execute-by-default / waivers exceptional—aligned with **38-CONTEXT D-38-01** culture). Then **exactly eight rows** in **SEED 1..8** order (same order as the SEED table in **`docs/uat-ci-coverage.md`** for 1:1 mental mapping).

- **D-74-05 (columns):** **SEED** · **Machine substitute pointer** (test path, CI job id, and/or `→ docs/uat-ci-coverage.md` anchor—short) · **Residual human note** (one line) · **Outcome** · **Owner** · **Date** · **Deferred trigger** (and **waiver expiry** fields when used) per **REQUIREMENTS.md** language.

- **D-74-06:** **No** second full copy of the SEED×CI matrix in the evidence file; **pointers** into **`docs/uat-ci-coverage.md`** for depth. Outcomes are **Executed** or **Waived with substitute** by default where machine substitutes exist; **Deferred** only with owner, date, and **re-open trigger**.

### UAT-02 — `docs/uat-ci-coverage.md`

- **D-74-07:** New section **`## v1.12 launch evidence (attestation)`** (or equivalent stable heading): **3–6 sentences + bullet(s)** linking **`.planning/v1.12-UAT-EVIDENCE.md`**, stating the existing SEED table remains the **machine vs residual catalog**, and the planning file is the **v1.12 outcome index**. If Policy and outcomes disagree, **fix the evidence file first** (one-line governance).

- **D-74-08:** **Do not** paste the full eight outcome rows into **`docs/uat-ci-coverage.md`**—avoids ExDoc vs `.planning/` fork of truth. Keep **v1.4 GA** subsection behavior unchanged except where a **v1.12** sentence removes ambiguity (no contradictory claims).

### Cross-cutting — governance pattern (research synthesis)

- **D-74-09:** **Single source of truth per concern:** **C-1** cells → **`09-VERIFICATION.md`**; SEED→CI/residual catalog → **`docs/uat-ci-coverage.md`**; milestone UAT outcomes → **`v1.12-UAT-EVIDENCE.md`**; bounded batch narrative → **`09-03-SUMMARY.md`**. Narrative files **point** at normative artifacts; they do not restate verdict columns.

### Claude's Discretion

- Exact **subsection title** string for **v1.12** in **`docs/uat-ci-coverage.md`**; whether **`09-VERIFICATION.md`** gets the optional **one-line** preamble pointer or **summary-only** attestation if merge conflict risk on the matrix is high—provided **D-74-02** primary attestation in **`09-03`** remains complete.

### Folded Todos

- None (**todo.match-phase** returned no matches).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap

- `.planning/REQUIREMENTS.md` — **AUD-12**, **UAT-01**, **UAT-02**
- `.planning/ROADMAP.md` — Phase **74** goal and success criteria
- `.planning/PROJECT.md` — North star: production trust, honest machine/human boundaries

### Phase 9 planning truth (edit targets)

- `.planning/phases/09-audit-logging/09-03-SUMMARY.md` — bounded batch narrative, planning trace, D-06 notes
- `.planning/phases/09-audit-logging/09-VERIFICATION.md` — **C-1** matrix (normative cells); optional preamble pointer only

### UAT / evidence precedents

- `.planning/seeds/SEED-001-v1.0-ga-human-uat-gate.md` — eight items, shift-left context, breadcrumbs
- `docs/uat-ci-coverage.md` — SEED 1–8 machine/residual catalog; OA-01/OA-02 depth anchors
- `.planning/v1.4-GA-UAT.md` — **Executed / Waived / Blocked** matrix lineage (tone, not duplicate structure in `docs/`)

### Prior phase context

- `.planning/phases/73-bounded-audit-atomicity-batch/73-CONTEXT.md` — phase **73** scope (**AUD-11**); **D-12** deferral of **`09-03`** substantive work to phase **74**
- `.planning/phases/38-human-ga-uat-gate/38-CONTEXT.md` — **D-38-01** execute-by-default posture for human GA work (culture reference for outcomes wording)

### Audit vocabulary

- `docs/audit-semantics.md` — **T1** / **T2** (for consistency if **`09-VERIFICATION`** edits occur)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **`docs/uat-ci-coverage.md`** — existing SEED table, Policy, “Where to run this”, **v1.4 GA** pointer subsection; extend with **v1.12** attestation hub without duplicating rows.
- **`.planning/v1.4-GA-UAT.md`** — prior art for outcome-style tables in `.planning/`.

### Established patterns

- **`09-03-SUMMARY.md`** — executive orientation + “Recent bounded batches”; phase **67** already models a **D-06 / no 09-VERIFICATION edit** note for **AUD-04-020..022**.

### Integration points

- **Phase 75** will link **`upgrading-to-v1.12.md`** to **`.planning/v1.12-UAT-EVIDENCE.md`** per **TRN-01**; phase **74** creates the file and doc alignment so that link is stable.

### Creative constraint

- This phase is **documentation and planning artifacts only**—no production **`lib/`** feature work unless a contradiction review forces a doc fix in code comments (unlikely).

</code_context>

<specifics>
## Specific Ideas

- User asked for **deep research** (parallel subagents) on gray areas **1–5**, then a **single cohesive recommendation set**; user confirmed **“sure”** to capture decisions in **CONTEXT.md**.
- Research synthesis favored **hybrid governance**: full narrative in **`09-03`**, optional **one-line** matrix preamble pointer, **minimal eight-row** evidence file + **thin** **`docs/uat-ci-coverage.md`** **v1.12** section—mirrors common OSS separation (catalog vs attestation vs release story).

</specifics>

<deferred>
## Deferred Ideas

- **`upgrading-to-v1.12.md`**, **ExDoc extras**, intro/maintainer trust-bundle sentences — **phase 75** (**TRN-01..03**).
- **MAINTAINING.md** multi-paragraph trust-bundle refresh — **TRN-02** unless a **one-sentence** pointer is trivially included in the phase **74** PR.

### Reviewed Todos (not folded)

- None.

</deferred>

---

*Phase: 74-planning-truth-launch-evidence*  
*Context gathered: 2026-04-24*
