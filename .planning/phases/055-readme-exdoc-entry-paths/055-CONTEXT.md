# Phase 55: README & ExDoc entry paths — Context

**Gathered:** 2026-04-22  
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver **DOC-01** and **DOC-02** from `.planning/REQUIREMENTS.md`: **README** (or agreed primary entry) gains a short **production / GA posture** block with honest **Executed vs Waived** framing and **stable pointers** to v1.4 evidence; **ExDoc** keeps integrator-first landing while exposing a **clear ≤2-hop path** from that landing to **maintainer-facing GA / audit narrative**.

**Out of scope:** **`MAINTAINING.md`** announcement checklist (**MAINT-01** → phase **56**); re-litigating waived GA matrix rows; duplicating milestone bodies or GA tables into README/CHANGELOG (see phases **53–54**).

**Tooling note:** `gsd-sdk query init.phase-op "55"` may return `phase_found: false` for v1.5 table-form roadmap rows; this directory + ROADMAP row **55** are authoritative.

</domain>

<decisions>
## Implementation Decisions

### README information architecture (DOC-01 — placement vs existing “Security posture”)

- **D-01 (separate section, not merged):** Add a **new** README section titled along the lines **“Production readiness & GA evidence”** (exact title left to executor). Place it **immediately after** the existing **“Security posture (headlines)”** table and its closing “map, not a spec” sentence — **do not** fold Executed/Waived, UAT, or milestone evidence language into that table.
- **D-02 (two parallel skim paths):** **Security posture** = **product defaults** (crypto, sessions, enumeration, step-up — what integrators ship). **New section** = **release assurance & evidence pointers** (what was verified, what was waived with substitutes, where to read it). Merging the two caused **research consensus**: readers conflate runtime defaults with process waivers (least-surprise failure).
- **D-03 (not maintainer-lane-only):** **`MAINTAINING.md`** / **`CONTRIBUTING.md`** **complement** but **do not substitute** for the README block — evaluators and security readers often stop at README; DOC-01 names README as primary entry.

### Evidence linking — Hex tarball, GitHub, relative paths (cross-cutting DOC-01 / DOC-02)

- **D-04 (hard rule — package surface):** `package[:files]` does **not** include `.planning/`. Therefore **repo-relative** links to `.planning/…` **break on hexdocs.pm** when README is rendered from the published tarball. **Never** use bare relative `.planning/` links for evidence meant to work from HexDocs.
- **D-05 (canonical link policy):**
  - **Between shipped artifacts** (`guides/**`, `docs/**`, `README.md`, `CHANGELOG.md`, `MAINTAINING.md` as listed in `mix.exs` `extras`) — **repo-relative** links remain idiomatic and work in Git + ExDoc.
  - **Anything outside the Hex/ExDoc bundle** (especially `.planning/milestones/*`, `.planning/v1.4-GA-UAT.md`, workflow-only paths) — use **`@source_url` + `blob/v#{@version}/…`** (or the **release tag** that matches the published Hex version). Aligns with `source_ref: "v#{@version}"` and phase **54** link-hygiene intent.
  - **`main`** GitHub URLs remain acceptable for **contributor tooling** (e.g. `.tool-versions`, `CLAUDE.md`, `test/example`) where “latest contributor view” is intended — **not** for version-attested GA evidence.
- **D-06 (minimum public link set — README + hub):** Include at least: **`.planning/milestones/v1.4-REQUIREMENTS.md`**, **`.planning/v1.4-GA-UAT.md`**, **`docs/uat-ci-coverage.md`** (packaged — stable on HexDocs), and **pointer to `.planning/MILESTONES.md`** or equivalent milestone index — using **D-05** URL forms. Executor may add **one** tag-scoped link to **`v1.4-MILESTONE-AUDIT.md`** if it keeps the block scannable.
- **D-07 (Hex `package[:links]` unchanged):** Do **not** add `.planning/` URLs to `package[:links]` — phase **53** already barred internal evidence dumps from narrow Hex metadata; README/docs narrative carries transparency.

### ExDoc landing & maintainer path (DOC-02)

- **D-08 (keep `main: "getting-started"`):** Default HexDocs landing stays **integrator-first** (install + first success path). **Do not** switch `main` to `README` or raw **`Sigra`** module doc for this phase — research consensus: README-as-main duplicates Hex/GitHub and under-serves generator workflows; module-first matches **Ecto/Oban** but not **Phoenix/LiveView**-style generator libs without a heavy moduledoc rewrite.
- **D-09 (new packaged hub page):** Add **`docs/ga-evidence.md`** (filename fixed for planning; executor may tweak if a better name fits `docs/` naming) to **`extras`** in `mix.exs`, under the existing **`Docs`** `groups_for_extras` regex. Content is **thin by design**: purpose of the page, one-paragraph **Executed vs Waived** glossary, **navigational bullets** only (tag-scoped GitHub URLs per **D-05** + relative link to **`docs/uat-ci-coverage.md`**), **no** full GA matrix copy-paste.
- **D-10 (≤2 hops from landing):** At the **top** of **`guides/introduction/getting-started.md`** (before or after the first paragraph — executor picks least disruption), add a **short “Reading map”** callout: links to **`docs/ga-evidence.html`** path as rendered, **`MAINTAINING.md`**, **`docs/audit-semantics.md`**, **`CONTRIBUTING.md`**, and **`SECURITY.md`** (or issue tracker for vulns per repo policy). Satisfies DOC-02 without changing `:main`.
- **D-11 (README → HexDocs bridge):** In the new README GA block, include **one line** pointing readers to **HexDocs** for the **hub page** (e.g. “On HexDocs: … **GA evidence** …”) so GitHub-first readers discover the same path.

### “Executed vs Waived” — depth, tone, liability (DOC-01 copy shape)

- **D-12 (shape — paragraph + bullets, not matrix):** Use **one honest paragraph** (library + generated code; integration/deployment risk stays with the host; **not** a compliance certification) plus **3–5 bullets** — each bullet **either** a single-line pointer **or** a factual scope line. **Do not** paste the GA matrix, per-row waiver rationale, owners, or SHAs into README.
- **D-13 (define terms once):** In that paragraph or the first bullet, define **Executed** vs **Waived** in **plain language** (e.g. Waived = human/matrix item not re-run for this milestone with a documented substitute such as CI — **link** to `v1.4-GA-UAT.md` for the full table).
- **D-14 (SECURITY.md split):** The README block (or hub page) should **prominently link `SECURITY.md`** for **coordinated disclosure** — aligns with CNCF / GitHub / npm hygiene patterns from research; keep **routine bugs** pointed at Issues / `CONTRIBUTING.md`.
- **D-15 (anti-patterns):** Avoid warranty-adjacent phrases (“GA passed”, “audit-certified”, “SOC2-ready”), competitor trash-talk, and **any** wording that implies optional features are universally on — consistent with phase **53** metadata discipline applied to README tone.

### Coherence across deliverables

- **D-16 (single story):** README block = **above-the-fold map**; **`docs/ga-evidence.md`** = **HexDocs-stable index**; **`.planning/v1.4-GA-UAT.md`** = **canonical milestone record** (tag URL); **`docs/uat-ci-coverage.md`** = **machine-substitute semantics** already referenced by GA docs. **CHANGELOG** continues link-first milestone traceability per **054** — README must not duplicate changelog or milestone bodies.
- **D-17 (`mix docs --warnings-as-errors`):** Any new/edited markdown in `extras` must keep **`mix docs --warnings-as-errors`** clean when this phase touches docs config or extras.

### Claude's Discretion

- **Exact section titles**, **bullet order**, and **whether** the hub file is named `ga-evidence.md` vs a synonym (`production-readiness.md`, etc.) — within **D-09** and existing `docs/` naming vibe.
- **Minor prose** in README / getting-started callout and hub page — constrained by **D-12–D-15** and tone from **053-CONTEXT** (integrator-first, precision over slogan).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — **DOC-01**, **DOC-02** (authoritative acceptance text).
- `.planning/ROADMAP.md` — Phase **55** row (goal + success criteria).
- `.planning/PROJECT.md` — v1.5 public narrative vs shipped reality.

### Prior phase coordination

- `.planning/phases/053-package-hex-metadata/053-CONTEXT.md` — Hex metadata tone; no GA matrix in `description` / `package[:links]`; README owns transparency.
- `.planning/phases/054-changelog-milestone-anchors/054-CONTEXT.md` — Changelog vs planning split; tag-scoped links; link hygiene.

### Evidence & CI (content targets — use D-05 URL policy when linking from README/hexdocs)

- `.planning/milestones/v1.4-REQUIREMENTS.md` — v1.4 requirement closure narrative.
- `.planning/v1.4-GA-UAT.md` — GA matrix, Executed vs Waived canonical wording.
- `.planning/MILESTONES.md` — Milestone index and archive pointers.
- `docs/uat-ci-coverage.md` — CI substitution / coverage map (packaged).

### Implementation surface

- `README.md` — DOC-01 primary entry.
- `mix.exs` — `package/0`, `docs/0` (`main`, `extras`, `groups_for_extras`, `source_ref`, `source_url`).
- `guides/introduction/getting-started.md` — DOC-02 landing hop.
- `MAINTAINING.md`, `CONTRIBUTING.md`, `docs/audit-semantics.md` — linked from reading map / hub.

### External patterns (verify URLs if cited in commits)

- https://contribute.cncf.io/maintainers/security/security-guidelines/ — CNCF security hygiene (README vs SECURITY.md split).
- https://docs.github.com/en/code-security/getting-started/adding-a-security-policy-to-your-repository — GitHub `SECURITY.md` expectations.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **`README.md`** — “Pick your lane”, topic map, **“Security posture (headlines)”** (~L153–162) and “map, not a spec” guardrail: extend **after** this block, do not replace it.
- **`mix.exs` `docs/0`** — `main: "getting-started"`, rich `extras` list, `groups_for_extras` (**Introduction** / **Flows** / **Recipes** / **Docs**); add one **`docs/*.md`** extra + optional ordering tweak only if required for sidebar clarity.
- **`docs/uat-ci-coverage.md`**, **`docs/audit-semantics.md`** — Existing packaged narrative; hub page should link here rather than duplicating.

### Established patterns

- **README** already mixes **HexDocs badges**, **repo-relative** guide links (valid for packaged extras), and **full GitHub URLs** for non-packaged paths — **D-05** formalizes that split for GA evidence.
- **Phase 54** changelog policy — README + hub remain **routers**, not second copies of verification tables.

### Integration points

- **`guides/introduction/getting-started.md`** — First screen integrators see on HexDocs; minimal “reading map” satisfies DOC-02 without new milestone phases.

</code_context>

<specifics>
## Specific Ideas

- Research synthesis (parallel agents, 2026-04-22) converged on: **Phoenix/LiveView-style guide-first landing** + **Pow-style link-first security depth** (Pow points to `guides/security_practices.md` rather than inlining assurance tables) + **Comeonin/argon2-style sober scope** (crypto READMEs avoid audit theater) + **CNCF/GitHub norm** of **`SECURITY.md`** for disclosure vs README navigational honesty.
- Cross-language: **OWASP ASVS** and **Terraform registry docs** reinforce **large assurance artifacts as standalone docs**, README as **index** — aligns with **D-12** / **D-09**.

</specifics>

<deferred>
## Deferred Ideas

- **`guides/introduction/overview.md` + `main: "overview"`** — Phoenix-style evolution if Getting Started becomes crowded; **not** required for DOC-02 if **D-09–D-10** land.
- **Changelog `Documentation` link migration to hexdocs changelog** — long-term per **053-D-06**; not owned by phase 55.

### Reviewed Todos (not folded)

_None — `todo.match-phase` returned empty._

</deferred>

---

*Phase: 55-readme-exdoc-entry-paths*  
*Context gathered: 2026-04-22*
