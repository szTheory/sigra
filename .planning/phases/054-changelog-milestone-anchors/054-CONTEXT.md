# Phase 54: Changelog & milestone anchors — Context

**Gathered:** 2026-04-22  
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver **PUB-02**: **`CHANGELOG.md`** gives readers a **coherent version story through v1.4** (including **v1.3** boundaries), with **explicit milestone anchors** that **cannot contradict** `.planning/MILESTONES.md`. Success criteria from ROADMAP: (1) entries or deliberate pointers for v1.3 / v1.4 ship boundaries, (2) no contradictory claims vs `MILESTONES.md`, (3) CI/docs unchanged or greener when touched.

**Out of scope:** README / ExDoc entry narrative (**DOC-01 / DOC-02** → phase **55**); maintainer announcement checklist (**MAINT-01** → **56**). This phase may add **short** cross-links that README will later echo, but must not own full “GA posture” copy.

**Note:** `gsd-sdk query init.phase-op "54"` currently returns `phase_found: false` because v1.5 phases live in an HTML table in `ROADMAP.md`; execution uses this directory and roadmap row **54** as authoritative.

</domain>

<decisions>
## Implementation Decisions

### Milestone labels vs Hex semver (planning spine vs public artifact)

- **D-01 (changelog spine):** Top-level `CHANGELOG.md` headings remain **Keep a Changelog** semver only: `## [Unreleased]`, `## [0.x.y] - YYYY-MM-DD`. **Never** use `## [v1.4]`-style headings as if they were installable versions parallel to Hex.
- **D-02 (planning IDs are annotations):** Internal milestones **v1.0–v1.4** are **roadmap/planning labels**, not Hex dependency ranges. Any mention in `CHANGELOG.md` must read as **traceability**, not a second version axis (avoids `{:sigra, "~> 1.4"}` confusion while **0.x** is on Hex).
- **D-03 (per-release traceability block):** Under each shipped `[0.x.y]` that maps to a milestone close, include a **`### Roadmap traceability` subsection** (name fixed for grep/docs) containing **one short paragraph + bullet(s)** that link to **stable anchors** in `.planning/MILESTONES.md` (and archives under `.planning/milestones/` as listed there). Wording template: *“Planning milestone **v1.x** (not a Hex version): see …”*.
- **D-04 (glossary blurb):** Add a **3–5 sentence** “**Planning milestones vs Hex releases**” note immediately after the existing Keep a Changelog / SemVer intro at the top of `CHANGELOG.md`, stating that **v1.x** = internal shipped tranche, **0.x.y** = Hex semver until **1.0.0**, and pointing to `.planning/MILESTONES.md` as canonical narrative. Keeps discoverability without duplicating `MILESTONES.md` body.
- **D-05 (date honesty):** When a Hex publish date and a milestone “shipped” date differ, **do not force a single fake date**. Changelog keeps the **release line date** for `[0.x.y]`; milestone subsection cites **`MILESTONES.md` dates** as the planning truth. One clarifying sentence is enough when both matter.

### Density — hybrid narrative (integrators + auditors)

- **D-06 (hybrid policy — canonical split):** **`CHANGELOG.md` owns shipped deltas**: **Security**, **breaking / migration**, **deprecations**, **behavioral fixes** integrators must act on. **`.planning/MILESTONES.md` owns intent, sequencing, and long accomplishment narrative.** Do not paste milestone bodies into the changelog.
- **D-07 (PUB-02 “pointer” path):** Where depth would duplicate planning or GA evidence trees, use **crisp bullets + stable relative links** (repo-root paths, prefer paths that exist on **tagged** releases for anything security- or audit-sensitive). Minimum: for **v1.3** and **v1.4**, each must have either **substantive summary bullets** **or** an explicit “see `MILESTONES.md` § …” pointer block — **deliberate**, not empty drift.
- **D-08 (GA / audit evidence):** Do **not** restate waived/executed GA matrices or evidence bundles in prose. **Summarize at most one screen** of **non-marketing** facts (e.g. “formal verification gates landed; see …”) and **link** to `.planning/v1.4-GA-UAT.md`, `.planning/milestones/v1.4-*`, and `.planning/uat-evidence/` as appropriate. Aligns with **PROJECT.md** / phase **53**: transparency lives in **public, purpose-written** artifacts, not changelog-as-second-ROADMAP.
- **D-09 (link hygiene):** Prefer **tag-scoped GitHub URLs** for anything that must stay immutable across `main` churn; repo-relative paths are fine for `.planning/` **if** release policy treats tag + branch as paired (document in `MAINTAINING.md` if not already). Avoid dead `main` blob links for evidence readers rely on.

### `[Unreleased]` hygiene

- **D-10 (single rolling bucket):** Keep **one** `## [Unreleased]` at top, **Keep a Changelog 1.1.0** categories (`Added` / `Changed` / `Deprecated` / `Removed` / `Fixed` / `Security`). **Omit empty sections.**
- **D-11 (security bar):** Any merge that changes **runtime security posture** (sessions, tokens, cookies, crypto, password flows, MFA, OAuth ceremony, audit write semantics visible to hosts) **must** add or adjust a bullet **in the same PR** under the correct category — no “changelog later” except **embargo** (then follow embargo checklist).
- **D-12 (depth cap):** In `[Unreleased]`, **one bullet per user-meaningful change**; details → PR / issue / advisory / planning doc. Optional **`###` theme subheads** (e.g. Audit, Generators) **only** when they improve scanability and **do not replace** KAC types (nest themes under the type, or keep themes as a second dimension **sparingly** — pick one style project-wide in implementation and stay consistent).
- **D-13 (release cut):** On version bump **in the same commit** as the tag, **move the entire** `[Unreleased]` **block** into new `## [x.y.z] - YYYY-MM-DD`, then reset `[Unreleased]` to empty scaffolding. Prevents “upcoming” vs shipped contradiction.
- **D-14 (grooming):** Before each release tag, maintainer **grooms** `[Unreleased]`: dedupe, reclassify mis-filed bullets (especially **breaking** mis-tagged as **Added**), relocate items that belong to an **already tagged** release (see **D-16**).
- **D-15 (compare links):** Maintain Keep a Changelog **footer compare links** (`[Unreleased]`, `[0.2.0]`, etc.) when touching the file — improves audit / upgrade diffs without bloating bullets.

### Ordering & audience (upgraders first, KAC-coherent)

- **D-16 (section order — risk-weighted):** Within each release, use **`###` headings only for KAC types**, in this **display** order (omit empty): **Security → Deprecated → Removed → Changed → Fixed → Added**. Deviates from KAC’s example ordering but stays within the **same type namespace** — document once in contributor/maintainer docs if needed.
- **D-17 (within `Changed`):** All **`**BREAKING:**`** bullets **first**, then other changes. Same “blast radius first” rule inside other sections when multiple bullets exist.
- **D-18 (optional preamble):** Allow **≤6 lines** of prose **immediately under** the `## [x.y.z]` heading (before first `###`): release theme, upgrade doc link, milestone pointer summary. **No new taxonomy** (no top-level `### GA` / `### Audit` sections).
- **D-19 (Security section semantics):** Use **`### Security`** only for vulnerability-class material, materially unsafe defaults corrected, or equivalent — not generic hardening marketing.
- **D-20 (concrete cleanup for current file):** Re-home bullets currently under `[Unreleased]` that describe work **already shipped** in **0.2.0** / **0.1.0** into the correct dated section (or drop as duplicate if fully captured), then rebuild `[Unreleased]` from **true post-tag** work only. Add **v1.3** and **v1.4** milestone anchor coverage per **D-03** / **D-07** so PUB-02 is satisfied after edit.

### Claude's Discretion

- **Exact prose** inside glossary / traceability paragraphs and the **minimal** set of bullets moved between sections during cleanup — constrained by **D-01–D-20** and verification against `MILESTONES.md` dates and archive paths.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — **PUB-02** (authoritative acceptance text).
- `.planning/ROADMAP.md` — Phase **54** row (goal + success criteria).
- `.planning/PROJECT.md` — v1.5 narrative goals (public story vs shipped reality).

### Milestones & evidence (must stay consistent with changelog)

- `.planning/MILESTONES.md` — Canonical **v1.0–v1.4** shipped narrative, dates, and archive links.
- `.planning/milestones/v1.3-ROADMAP.md`, `.planning/milestones/v1.3-REQUIREMENTS.md`, `.planning/milestones/v1.3-MILESTONE-AUDIT.md` — v1.3 archive tranche.
- `.planning/milestones/v1.4-ROADMAP.md`, `.planning/milestones/v1.4-REQUIREMENTS.md`, `.planning/milestones/v1.4-MILESTONE-AUDIT.md` — v1.4 archive tranche.
- `.planning/v1.4-GA-UAT.md` — GA matrix / Executed–Waived framing (link, do not duplicate).
- `.planning/uat-evidence/` — Versioned evidence trees referenced from milestones / GA docs.

### Prior phase coordination

- `.planning/phases/053-package-hex-metadata/053-CONTEXT.md` — **D-05–D-08** (single canonical Changelog URL in `package/0`, long-term hexdocs preference). Changelog edits must stay compatible with that policy.

### Implementation surface

- `CHANGELOG.md` — Primary file edited in this phase.

### External norms

- https://keepachangelog.com/en/1.1.0/ — Keep a Changelog structure, `[Unreleased]`, types, yanked releases.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- Current `CHANGELOG.md` already follows **Keep a Changelog** + SemVer preamble; extend in place rather than new format.
- `.planning/MILESTONES.md` provides **ready-made** milestone titles, dates, and archive paths for traceability bullets.

### Established patterns

- **053-CONTEXT** locks Hex `Changelog` link strategy and forbids `.planning/` URLs in **Hex** `package/0`** — changelog may still **reference** `.planning/` for **repo-cloned** readers (integrators cloning source), which matches PUB-02 pointer language.

### Integration points

- Phase **55** will align **README** / docs landing with the glossary message; keep **wording parallel** to **D-04** to avoid contradiction.

</code_context>

<specifics>
## Specific Ideas

- User selected **all** gray areas and requested **one-shot**, research-backed recommendations; subagent synthesis is folded into **D-01–D-20** above.
- Ecosystem pattern applied: **semver spine** (Phoenix/Ecto/Oban-style), **planning labels as annotations** (npm/Ruby/Rust norm), **hybrid density** (changelog = operational + links; milestones = narrative), **risk-weighted section order** with **only** KAC `###` types.

</specifics>

<deferred>
## Deferred Ideas

- **Automation** (PR templates, link checkers, release scripts that move `[Unreleased]`) — optional hardening; not required to satisfy PUB-02; consider under maintainer CI phases or backlog.
- **GitHub Releases body** mirroring changelog — nice-to-have; `CHANGELOG.md` remains source of truth unless maintainers later adopt generation.

### Reviewed Todos (not folded)

- None — `todo.match-phase` returned no matches.

</deferred>

---

*Phase: 054-changelog-milestone-anchors*  
*Context gathered: 2026-04-22*
