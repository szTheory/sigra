# Phase 54 — Technical research: Changelog & milestone anchors

**Status:** Research complete  
**Question answered:** What do we need to know to plan **PUB-02** well?

---

## Gap vs `MILESTONES.md` (authoritative dates)

| Milestone | Shipped (planning) | Hex line in `CHANGELOG.md` today | Gap |
|-----------|-------------------|----------------------------------|-----|
| v1.0 | 2026-04-11 | No explicit anchor | No `### Roadmap traceability` under any `[0.x.y]` pointing to v1.0 archive |
| v1.1 | 2026-04-16 | No explicit anchor | Same |
| v1.2 | 2026-04-17 | `## [0.1.0] - 2026-04-17` exists; no milestone subsection | Need traceability block naming **v1.2** + links to `milestones/v1.2-*` |
| v1.3 | 2026-04-19 | `## [0.2.0] - 2026-04-19` exists; no milestone subsection | Need traceability block naming **v1.3** + links to `milestones/v1.3-*` |
| v1.4 | 2026-04-22 | Work largely in **`[Unreleased]`**; no shipped `[0.x.y]` line dated 2026-04-22 yet | Need **deliberate** v1.4 pointer: either concise bullets under `[Unreleased]` + traceability, and/or prose that states “planning milestone v1.4 (see `MILESTONES.md` § …)” without implying a parallel Hex **v1.4** version (**D-01** / **D-02** from CONTEXT) |

**Contradiction watch:** Never state a Hex publish or dependency range as **v1.4**; always pair internal **v1.x** language with “planning milestone” or “see `MILESTONES.md`”.

---

## Current `CHANGELOG.md` structural issues

1. **Missing glossary** after the Keep a Changelog / SemVer intro (**CONTEXT D-04**).
2. **`[Unreleased]`** mixes long-lived narrative (AUD inventories, GA pointer) with true upcoming delta; several bullets read like **already-released** v1.3 / example-app polish that may belong under **`[0.2.0]`** per **D-20** (executor must diff against `MILESTONES.md` section ordering and git tag intent).
3. **No `### Roadmap traceability`** subsections yet (**D-03**).
4. **KAC section order** under dated releases follows historical “Added first”; **D-16** asks **Security → Deprecated → Removed → Changed → Fixed → Added** (omit empty). Executor applies when touching those releases.
5. **Footer compare links** absent — **D-15** expects them when the file is edited.

---

## Keep a Changelog & ecosystem norms

- **Spec:** https://keepachangelog.com/en/1.1.0/ — `[Unreleased]`, types, ordering guidance, compare URL footer.
- **Practice:** SemVer headings **`[0.x.y]`** stay the only installable axis; internal program labels (Phoenix-style “v1.4 GA”) belong in prose or traceability blocks, not as fake version headings.

---

## Planning implications

1. **Single primary file:** `CHANGELOG.md` (plus optional grep-only verification; no code paths).
2. **Executor must read** `.planning/MILESTONES.md` **before** moving bullets so dates and “what shipped” strings stay consistent.
3. **Link targets** listed in `054-CONTEXT.md` `<canonical_refs>` must resolve as repo-relative paths (clone readers); avoid implying Hex package **1.4.x** exists.

---

## Validation Architecture

**Dimension 8 (Nyquist):** Doc-only phase. Feedback is **markdown structure grep** + optional **`mix format`** (if no Elixir touched, compile not required). Primary gate: **string presence / absence** contracts on `CHANGELOG.md`.

| Dimension | Approach |
|-----------|----------|
| Structure | `grep` for fixed headings: `### Roadmap traceability`, glossary title from plan, `Planning milestones vs Hex releases` |
| Consistency vs milestones | Manual spot-check: every **Shipped:** date claimed in a traceability paragraph matches `.planning/MILESTONES.md` for that milestone |
| Regression | `mix compile --warnings-as-errors` (repo unchanged by markdown-only — quick sanity) |

---

## RESEARCH COMPLETE
