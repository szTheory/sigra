# Phase 57: Nyquist 41–44 posture matrix — Context

**Gathered:** 2026-04-22  
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver **NYQ-01** and **NYQ-02** (`.planning/REQUIREMENTS.md`): a **single maintainer-facing source of truth** for historical GA-phase **41–44** Nyquist posture — phase slug, honest disposition, canonical evidence paths (`*-VERIFICATION.md` / `*-VALIDATION.md` or explicit **none** + why), and **one-line reopen triggers** per row, with **no silent blank cells** for milestone disposition.

**Out of scope:** Re-litigating shipped 41–44 implementation (v1.4 reader note); OAuth ceremony tests (**OA-01** / phase **58**); UAT doc alignment (**OA-02** / phase **59**); **SEED-002** breadth; forcing cosmetic `nyquist_compliant: true` where honesty requires waiver + recorded rationale.

</domain>

<decisions>
## Implementation Decisions

### Matrix home — two-tier maintainer truth (summary + canonical)

- **D-01 (split layout — recommended “C”):** Keep **`MAINTAINING.md`** as the **public maintainer index**: a **short** “Nyquist 41–44 posture” block (what the matrix guarantees / does not guarantee, how to read disposition + reopen rules) plus a **single prominent relative link** to the canonical matrix file under **`.planning/`**. Do **not** grow `MAINTAINING.md` into the full historical GA grid unless the table stays trivially small after implementation.
- **D-02 (canonical file):** Author the **full matrix** as **one** new markdown file under **`.planning/`** (executor-chosen basename, e.g. **`nyquist-phases-41-44-matrix.md`**). This file is the **canonical table body** (all rows, all columns). Name should signal **process / governance**, not product marketing.
- **D-03 (precedence — least surprise):** One explicit sentence in **both** places: **if `MAINTAINING.md` summary and the `.planning/` matrix disagree, the `.planning/` canonical matrix wins.** Summaries must not introduce obligations absent from the matrix.
- **D-04 (discoverability):** Ensure at least one **root-truth hop** for humans: **`MAINTAINING.md`** (and optionally **`CONTRIBUTING.md`** one-line pointer only if maintainers routinely skip `MAINTAINING.md`). Avoid **only** `.planning/` with no stable entry link — Pow-style “honesty buried in folklore.”

### Evidence pointers — relative spine + scoped ref + optional URL sugar

- **D-05 (primary pointer shape):** In the **canonical matrix**, evidence columns use **repo-relative paths** from repository root (e.g. **`.planning/phases/41-backup-codes-ga-product-closure/41-VERIFICATION.md`**). This optimizes **clone / fork / offline / agents in CI checkout** and avoids hard dependency on GitHub UI.
- **D-06 (point-in-time header — not per-cell noise):** At the **top of the canonical matrix file**, include a **`ref:`** (or equivalent) block: **release tag + full commit SHA** (and optional calendar date). Rows do **not** repeat full tag+SHA unless a row truly diverges from the file-level ref (should be rare; call it out if so).
- **D-07 (optional GitHub `blob` URLs):** Parenthetical or secondary **tag-scoped** `github.com/.../blob/vX.Y.Z/...` links are **convenience only** for readers without a clone — **never** `main` blob URLs for “proof,” consistent with phase **56** link hygiene. URLs are **not** authority over relative paths + declared `ref:`.
- **D-08 (Hex / tarball honesty):** State once in the matrix header or `MAINTAINING.md` summary: **`.planning/` evidence is not assumed present in the Hex package tarball** unless explicitly added to **`mix.exs` `:files`** / ExDoc extras — do not imply deep planning paths work from **hexdocs.pm** relative links (same structural lesson as **056-CONTEXT** D-05/D-06 family).

### `nyquist_compliant` / technical posture — canonical in artifacts, not duplicated YAML

- **D-09 (source of truth):** Treat **`nyquist_compliant` (and related waiver narrative) in `*-PLAN.md` / `*-VALIDATION.md` frontmatter** in each phase directory as **authoritative** for literal boolean / waiver intent. The matrix **does not** replace those files.
- **D-10 (matrix column — “B” not “A”):** The matrix carries a **maintainer-authored summary** of posture (waiver + superseding evidence vs elevated compliant, etc.) **plus pointers** to the phase tree — **not** a hand-copied YAML mirror of `nyquist_compliant:` that can drift and imply false machine precision (**avoid “A”**).
- **D-11 (optional automation — “C” lite):** Prefer **verify, don’t necessarily rewrite**: if drift would hurt honesty, add or extend a **small ExUnit contract** (pattern: **`test/sigra/planning/phase_50_nyquist_docs_contract_test.exs`**) or a script that **fails CI** when matrix disposition claims disagree with parsed frontmatter — avoid huge auto-regenerated markdown on every PR unless the team explicitly wants full generation.

### NYQ-02 disposition vocabulary — strict three-label + mandatory satellites

- **D-12 (primary disposition column):** Use **exactly three** mutually exclusive primary labels (human-readable strings; executor may tweak casing but not semantics):
  - **`COMPLIANT` (elevated)** — bar tracked here is now met; **Evidence** satellite **mandatory** (paths, test module names, doc §, or CI job + commit).
  - **`UNCHANGED`** — intentional non-elevation; **Rationale** satellite **mandatory** (risk acceptance, compensating controls, what is monitored, pointer to waiver text).
  - **`DEFERRED`** — not done yet; **Trigger + date/window** satellite **mandatory** (named event: e.g. next major, issue label, contract test removal — **not** bare “TBD”).
- **D-13 (banned sole disposition tokens):** Do **not** allow **empty**, **N/A**, **Done**, **Addressed**, **See above** without pointer, or pure euphemism (**“mostly compliant”**, **“good enough”**) as the **only** disposition content.
- **D-14 (prose placement):** Nuance beyond three labels lives in **linked** `*-VERIFICATION.md` / `*-VALIDATION.md` / short **bulleted** sub-cells (≤ 2–4 bullets) — **not** as a substitute for picking a primary label (**matrix = disposition + pointers; appendix = prose**).
- **D-15 (optional `SPLIT` escape):** If one logical row truly spans incompatible dispositions, allow **`SPLIT`** **only** when it **fans out** into separate sub-rows on the next edit — never a permanent hedge label.

### Coherence with roadmap / milestone honesty

- **D-16 (reader note alignment):** Matrix language must match **`.planning/ROADMAP.md` v1.6 reader note**: v1.6 **does not** re-ship 41–44; **honest disposition** beats cosmetic `nyquist_compliant: true`. Formal `nyquist_compliant: true` on a row remains **optional** where waiver + superseding evidence is the truthful story.
- **D-17 (NYQ-01 column completeness):** Every **41–44** row includes: **phase slug** (directory slug), **primary disposition** (**D-12**), **nyquist / waiver mode** (may mirror existing **“Waiver + superseding evidence”** language from current `MAINTAINING.md` table), **canonical evidence paths** (relative) or explicit **none** + why, **one-line reopen trigger** (command-oriented where possible — e.g. **`mix ci.install_golden`**, scoped `mix test` slice, human matrix row state).

### Claude's Discretion

- **Exact filename** for the canonical matrix under **`.planning/`** (within **D-02** constraints).
- **Whether** to add a second thin summary table in `MAINTAINING.md` vs link-only intro — bounded by **D-01** (stay short).
- **Optional** micro-**`mix`** task vs raw **ExUnit** for **D-11** if the contract stays clearer in code than in a shell script.

### Folded Todos

_None._

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — **NYQ-01**, **NYQ-02** (authoritative acceptance text).
- `.planning/ROADMAP.md` — Phase **57** row, success criteria, **Reader note: phases 41–44 vs v1.6**.
- `.planning/PROJECT.md` — v1.6 goals: Nyquist honesty, optional mechanical elevation, no unrelated product scope.

### Current maintainer surface (pre-phase-57 baseline)

- `MAINTAINING.md` — existing **Nyquist policy (phases 41-44)** table (tag URLs today — **D-05–D-07** govern the evolution).

### Phase evidence trees (41–44)

- `.planning/phases/41-backup-codes-ga-product-closure/41-VERIFICATION.md`
- `.planning/phases/41-backup-codes-ga-product-closure/41-VALIDATION.md`
- `.planning/phases/42-human-ga-matrix-evidence/42-VERIFICATION.md`
- `.planning/v1.4-GA-UAT.md` — human GA matrix (phase **42** evidence cross-link)
- `.planning/phases/43-audit-inventory-auth-atomic-batch/43-VERIFICATION.md`
- `.planning/phases/43-audit-inventory-auth-atomic-batch/43-VALIDATION.md`
- `.planning/phases/44-mfa-account-api-atomic-batches/44-VERIFICATION.md`
- `.planning/phases/44-mfa-account-api-atomic-batches/44-VALIDATION.md`

### Prior phase context (link hygiene + doc contracts)

- `.planning/phases/56-maintainer-announcement-checklist/56-CONTEXT.md` — HexDocs-safe vs tag-scoped URL policy family (**D-08** alignment).
- `.planning/phases/52-roadmap-nyquist-milestone-honesty/52-CONTEXT.md` — milestone honesty framing if needed for tone.

### Machine-enforced doc structure precedent

- `test/sigra/planning/phase_50_nyquist_docs_contract_test.exs` — structural / grep contract pattern for planning docs (**D-11** optional extension model).
- `.planning/phases/50-nyquist-ci-gate-hygiene/50-VALIDATION.md` — Nyquist waiver vocabulary reference for contracts.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`MAINTAINING.md`** — existing **Nyquist policy (phases 41-44)** subsection to **trim/replace** with **D-01** summary + link once the canonical matrix exists.
- **`test/sigra/planning/phase_50_nyquist_docs_contract_test.exs`** — precedent for **grep/structural** guarantees over `.planning/` markdown without duplicating content in code (informs **D-11**).

### Established Patterns

- **Relative `.planning/` paths** in maintainer docs for in-repo work; **tag-scoped GitHub URLs** when pointing through **Hex-published** surfaces (see **056-CONTEXT**).
- **`nyquist_compliant:`** lives in phase **PLAN** / **VALIDATION** frontmatter — matrix is **downstream narrative**, not a second owner (**D-09**, **D-10**).

### Integration Points

- **`MAINTAINING.md`** remains the maintainer **front door**; new **`.planning/*.md`** matrix is the **dense evidence + disposition grid**.
- Optional **CI**: extend or mirror **`phase_50_nyquist_docs_contract_test.exs`** style checks if **D-11** is implemented.

</code_context>

<specifics>
## Specific Ideas

- Decisions **D-01–D-17** come from a **2026-04-22** research synthesis (maintainer-doc architecture, evidence-link strategy, single-source-of-truth for `nyquist_compliant`, controlled vocabulary for disposition) with explicit **Sigra / Elixir / Hex / security-honesty** constraints — treat as the default implementation contract unless superseded by a later discuss pass.

</specifics>

<deferred>
## Deferred Ideas

- **`### Phase 57:`** (or equivalent) **GSD-parseable** heading blocks in **`.planning/ROADMAP.md`** — tooling hygiene so `gsd-sdk query init.phase-op 57` returns **`phase_found: true`**; not product scope for **NYQ-01/02** themselves but unblocks automated GSD workflows.

### Reviewed Todos (not folded)

_None._

</deferred>

---

*Phase: 57-nyquist-41-44-posture-matrix*  
*Context gathered: 2026-04-22*
