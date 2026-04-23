# Phase 70: Upgrade stub + non-goal attestation - Context

**Gathered:** 2026-04-23  
**Status:** Ready for planning  
**Source:** `/gsd-discuss-phase 70` — user selected **all** gray areas; four parallel **research** subagents (ecosystem + docs IA + release engineering + OSS scope transparency); synthesized **one** coherent decision set (no interactive Q&A menu).

<domain>

## Phase boundary

Ship **ACF-05** and **ACF-06**: (1) **`guides/introduction/upgrading-to-v1.10.md`** exists, follows established upgrade-doc contract, is registered in **`mix.exs`** ExDoc **`extras`** after **`upgrading-to-v1.8.md`**. (2) **`PROJECT.md`** and **`REQUIREMENTS.md`** explicitly attest **Lockspire / `sigra_lockspire` glue** and **full SEED-002** deferrals with accurate pointers to **ADR 001** and **`.planning/seeds/SEED-002-phase-9-log-safe-atomicity-followup.md`**, per live requirements text. No new runtime behavior.

</domain>

<decisions>

## Implementation decisions (cohesive system)

Cross-cutting principle (research synthesis): **CHANGELOG + Hex version = exhaustive facts and SemVer truth**; **milestone-titled upgrade pages = orientation, sequence, and “where to read next”** — never a shadow changelog or duplicated policy essay. **Least surprise** = same skeleton as **`upgrading-to-v1.8.md`**, thinner body for a docs-heavy milestone, **pointers** for depth (archives, ADRs, seeds).

### A. Narrative spine — `upgrading-to-v1.10.md` shape (gray area 1)

- **D-01:** **Mirror the v1.8 page skeleton** — opening paragraph (milestone vs Hex), **“After v1.9”** (or “After v1.8” if cleaner) predecessor handoff, **“Library / host upgrade checklist”** numbered list, **“See also”**. Repeat upgraders get a **predictable template**; maintenance is “diff the checklist,” not reinvent structure.
- **D-02:** **Proportional brevity:** v1.10 is **adopter-confidence / docs-first**; the page may be **shorter than v1.8** while keeping the **same headings** — signals “nothing scary” without training readers to expect empty stubs.
- **D-03:** **No heavy v1.9 narrative inline** — at most **one short paragraph** naming the shipped theme (bounded audit atomicity / planning closure) plus **one canonical archive link** (e.g. **`.planning/milestones/v1.9-ROADMAP.md`** bundle). Do **not** paste phase IDs, verification matrices, or SEED-002 technical depth — those rot and belong in **CHANGELOG** / **`.planning/`**.
- **D-04:** **Optional above-the-fold TL;DR** (3 bullets max) separating **library dep bump**, **host optional integrations** (Oban, Hammer, OAuth), and **generated code / installer** expectations — addresses the **lib+generator** footgun class (Elixir compile-time + generator surprises; lessons from Rails upgrade guides vs npm semver-only culture).
- **D-05:** **CHANGELOG owns exhaustivity**; this page **curates order of operations** and **“when to read what”** — same contract as v1.7/v1.8 (“accumulate host steps as phases ship” tone can be updated to “v1.10 focuses on …” without duplicating release notes).

### B. SemVer, pins, and planning labels (gray area 2)

- **D-06:** **Medium restate** (not link-only, not full essay): **one opening paragraph** (same role as v1.8 line 3) stating: (a) audience — this file is about **planning milestone v1.10**; (b) **library version** = **`mix.exs` on Hex** + **`CHANGELOG.md`** for breaks/features; (c) **planning v1.x** = **coordination label** in **`.planning/`**, not a second install axis; (d) practical path — pick **Hex constraint** from CHANGELOG/release notes, then **`mix deps.get` / compile / test**. Then **mandatory anchor link** to **`CHANGELOG.md` → “Planning milestones vs Hex releases”** for full policy and edge cases.
- **D-07:** **Explicit anti-footgun sentence:** **`mix deps.update sigra`** resolves the **version range in `mix.exs`** — it does **not** by itself mean “I completed planning milestone v1.10.”
- **D-08:** **Pinning guidance (one clause):** **`~> 0.2.x`** (or current line) vs **git ref** — defer detail to **CHANGELOG** / release notes; upgrade page states **Hex range is the compatibility contract**; git tracks commits, not planning labels unless tagged.

### C. Non-goal attestation — surfaces and tone (gray area 3)

- **D-09:** **`PROJECT.md` + `REQUIREMENTS.md`** remain **authoritative** for **ACF-06** tables and **Out of scope** rows — implementation phase must verify links to **`.planning/decisions/001-defer-sigra-lockspire-glue-package.md`** and **`.planning/seeds/SEED-002-phase-9-log-safe-atomicity-followup.md`** are present and accurate at milestone close.
- **D-10:** **`upgrading-to-v1.10.md` includes a short section** (e.g. **`## Out of scope for v1.10 (milestone close)`**) restating **Lockspire glue** and **full SEED-002** as **deliberate deferrals**, **not** apologies — **same two links** as REQUIREMENTS. Add **one guardrail line**: if prose disagrees with tables, **tables in PROJECT / REQUIREMENTS win**. Meets upgraders who **never** open `.planning/` requirements otherwise (Kubernetes / Rails pattern: user-facing boundary + ADR link).
- **D-11:** **CHANGELOG optional pointer only** (at next relevant Hex release): a **single** milestone traceability line pointing at **`upgrading-to-v1.10.md`** + ADR/SEED — **no second table** in CHANGELOG (avoids four-way drift).

### D. ExDoc `extras` + “See also” mesh (gray area 4)

- **D-12:** **`mix.exs` `extras`:** insert **`"guides/introduction/upgrading-to-v1.10.md"`** **immediately after** **`"guides/introduction/upgrading-to-v1.8.md"`** and **before** **`"guides/introduction/upgrading-to-v1.1.md"`** — satisfies **ACF-05** verbatim, keeps **v1.10** discoverable ahead of the historical **v1.1** page, preserves room to add **`upgrading-to-v1.9.md`** later **between v1.8 and v1.10** if ever needed.
- **D-13:** **“See also” cap five links**, prioritized for **upgrade → ops/reference** handoff (Diátaxis: escape the “upgrade archipelago”):
  1. **`CHANGELOG.md`** (ExDoc extra — e.g. `changelog.html`) — authoritative deltas.
  2. **`upgrading-to-v1.8.html`** — immediate predecessor narrative.
  3. **`intermediate-production-path.html`** — solo production journey (phase 69).
  4. **`deployment.html`** — production how-to hub (phase 68).
  5. **`generator-options.html`** — post-upgrade generator alignment (phase 69).
- **D-14:** **Do not** list **multiple** archived roadmap files in “See also” — at most **one** `.planning/milestones/…` pointer **in prose** (D-03). **Do not** ring-link every **`upgrading-to-v*.html`**. **Do not** default-link **`first-hour.html`** unless v1.10 explicitly changes greenfield install (it does not). **Do not** push **Nyquist / GA evidence** docs into “See also” unless the upgrade page is *about* that contract.

### E. Coherence note

**One story:** Reader opens **v1.10 upgrade** → **orients** (milestone vs Hex in one screen) → **checks** short checklist → **sees deferrals** (trust) → **follows** five handoffs to **CHANGELOG + ops + generator truth**. **PROJECT / REQUIREMENTS** close **ACF-06** for governance; **upgrade page** closes **ACF-06** for the **HexDocs reader path**; **CHANGELOG** stays **SemVer truth** with at most **one** milestone pointer (D-11).

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing.**

### Requirements and scope

- `.planning/REQUIREMENTS.md` — **ACF-05**, **ACF-06**
- `.planning/ROADMAP.md` — Phase 70 goals and success criteria
- `.planning/PROJECT.md` — v1.10 milestone framing and non-goals (must stay aligned after edits)

### Precedent upgrade pages and SemVer source

- `guides/introduction/upgrading-to-v1.8.md` — **primary structural template**
- `guides/introduction/upgrading-to-v1.7.md` — predecessor pattern / cross-link style
- `CHANGELOG.md` — **“Planning milestones vs Hex releases”** (H2) — canonical SemVer vs planning policy

### Deferral authority

- `.planning/decisions/001-defer-sigra-lockspire-glue-package.md` — ADR **001** (**Lockspire** / optional glue)
- `.planning/seeds/SEED-002-phase-9-log-safe-atomicity-followup.md` — **SEED-002** (full hybrid → `Multi` conversion deferral)

### v1.9 archive (light pointer target)

- `.planning/milestones/v1.9-ROADMAP.md` — shipped audit atomicity tranche narrative (link from prose, not link-spider)

### Prior phase context (do not contradict)

- `.planning/phases/068-deploy-and-mail-confidence/068-CONTEXT.md` — deployment hub ownership
- `.planning/phases/069-intermediate-path-optional-features/069-CONTEXT.md` — intermediate path + generator-options ownership

### Implementation targets

- `mix.exs` — `docs/0` → `extras` ordering
- `guides/introduction/upgrading-to-v1.10.md` — **to create**

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- `guides/introduction/upgrading-to-v1.8.md` — copy structure, trim body for v1.10 themes.
- `CHANGELOG.md` — already defines planning vs Hex; upgrade page links here instead of restating essay.

### Established patterns

- ExDoc **`extras`** list order drives Introduction sidebar — insert new upgrade doc adjacent to **v1.8**.
- v1.7/v1.8 use **`.html`** peer links in “See also” — match for v1.10.

### Integration points

- Phase **68** (`deployment.md`) and **69** (`intermediate-production-path.md`, `generator-options.md`) are the **operational** exit ramps from the upgrade page — cross-link explicitly (D-13).

</code_context>

<specifics>

## Specific ideas

- Research synthesis emphasized: **Oban/Rails-style** procedural upgrade pages + **Cargo-like** short local explanation with **canonical deep link**; avoid **npm-style** “just bump” without generator/config context.
- Tone for deferrals: **neutral product discipline** (“defer”, “out of scope”, “revisit when”) — not defensive legalese.

</specifics>

<deferred>

## Deferred ideas

- **`upgrading-to-v1.9.md` as its own ExDoc page** — not required for v1.10; if added later, insert between **v1.8** and **v1.10** in `extras` per D-12 footnote logic.

### Reviewed todos (not folded)

_None — `todo.match-phase` returned no matches._

</deferred>

---

*Phase: 70-upgrade-stub-non-goal-attestation*  
*Context gathered: 2026-04-23*
