---
phase: 217-adversarial-panel-auto-fix-safety-rails
plan: "04"
subsystem: admin-eval-quality
tags: [graphic-design-lens, panel, brand-v2, admin-ui]
status: complete

dependency_graph:
  requires:
    - guides/reference/admin-persona-jtbd-rubric.md
    - guides/reference/admin-ui-principles.md
    - brandbook/brand-book.md
    - brandbook/tokens.css
  provides:
    - guides/reference/admin-graphic-design-lens.md
  affects:
    - scripts/ci/panel-forced-floor-check.mjs
    - guides/reference/admin-panel-verdicts.json

tech_stack:
  added: []
  patterns:
    - sibling-lens-instrument (parallel to persona rubric, not appended)
    - graphic_design:<key> class prefix for panel finding_id key space
    - seven-named-pillar framework for anti-generic-critique enforcement
    - forced-floor + NONE-searched-for token (verbatim from persona rubric)
    - A3 award = all 4 lenses clean (extends 216 award bands)

key_files:
  created:
    - guides/reference/admin-graphic-design-lens.md
  modified: []

decisions:
  - "Graphic-design lens is a sibling file, not appended to persona rubric — mirrors 216 D-19 sibling-file discipline and keeps persona rubric markdown untouched"
  - "Three perceptual questions only: salience (Q1), emphasis_ember (Q2), composition (Q3) — each defers its measurable/structural half to a deterministic probe"
  - "Q3 (composition) is the only question requiring BOTH light and dark screenshots (evidence_cell: light | dark | both)"
  - "Seven named Sigra pillars are the anti-generic-critique contract — every finding must cite a named pillar or fail the forced-finding floor"
  - "Column-4 integer prohibition obeyed: all table columns use string values (keep/tighten/kill/clean/actionable/blocked or descriptive strings)"
  - "A3 award extension: A3 = all 4 lenses clean (3 persona + 1 graphic-design); deterministic A2 is a prerequisite"

metrics:
  duration: "176s"
  completed_date: "2026-07-04"
  tasks_completed: 1
  tasks_total: 1
  files_created: 1
  files_modified: 0
---

# Phase 217 Plan 04: Admin Graphic-Design Lens Summary

Authored new sibling `guides/reference/admin-graphic-design-lens.md` — the graphic-design
perceptual judge instrument (D-16/D-17/D-18) that plugs into the 4-lens panel via
`class = graphic_design:<key>` with the same forced-floor + `keep|tighten|kill` +
`NONE — searched for:` contract as the persona rubric.

## What Was Built

**`guides/reference/admin-graphic-design-lens.md`** — 431 lines, sibling to
`admin-persona-jtbd-rubric.md`. Defines:

1. **IMPORTANT DISAMBIGUATION section** — distinguishes this perceptual/visual-quality lens
   (judges rendered PNGs) from the UX/operator lenses (judge DOM + facts.json). Includes a
   clear table showing the two instrument types, evidence inputs, and output class prefixes.

2. **Seven Named Sigra Pillars table** — the anti-generic-critique contract. Every finding must
   cite one of: hierarchy/salience, restraint, ember-as-boundary, consistency, typographic
   coherence, dark/light emphasis parity, composition/balance. Each pillar has a source citation
   to `admin-ui-principles.md` or `brandbook/brand-book.md`.

3. **Verdict scale** — identical to persona rubric's `keep`/`tighten`/`kill` 3-point scale with
   the same worst-verdict rollup rule. Documents the A3 award: all 4 lenses (3 persona + this
   graphic-design lens) must read `clean`.

4. **Three refutation questions:**
   - **Q1 `salience`** (`class = graphic_design:salience`) — perceived first-fixation dominance
     of the wrong element. Defers above-fold geometry + target-size measurements to probe #9;
     picks up probe #9's deferred salience judgment call. Named pillar: hierarchy/salience.
   - **Q2 `emphasis_ember`** (`class = graphic_design:emphasis_ember`) — ember earning semantic
     meaning vs decorating. Brand-v2 values explicitly cited: `#c2410c` (light) / `#fdba74`
     (dark) / Space Grotesk / Core Rails. Defers structural ember allowlist to probe #4; owns
     the perceptual semantics call. Named pillars: restraint + ember-as-boundary.
   - **Q3 `composition`** (`class = graphic_design:composition`) — grouping/type-hierarchy/
     balance coherence in BOTH themes. Only question requiring both light AND dark screenshots.
     Defers measured spacing/rhythm to D-16 proxies and contrast correctness to axe. Named
     pillars: consistency + typographic coherence + dark/light emphasis parity + composition/balance.

5. **Adversarial Framing and Forced-Finding Floor** — verbatim standing instruction requiring
   either a cited element (observation + structural anchor + evidence_cell + named pillar) OR
   the literal `NONE — searched for:` token. No vague positives allowed. Two-field finding
   shape: `observation` (perceptual prose) + `anchor` (DOM selector from `data-testid`/`sg-*`
   BEM vocabulary) + `evidence_cell`.

6. **Output schema** — YAML frontmatter (machine-rollup-able: `disposition`, `verdicts` with all
   3 keys, `findings` list with pillar + observation + anchor + evidence_cell + none_searched_for)
   + markdown body (one section per question, each ending with finding or NONE token).

7. **`finding_id` computation** — documents the byte-identical formula
   `sha256(surface + "\0" + class + "\0" + anchor)` where class is the full
   `graphic_design:<key>` string, so panel findings share the key space with probe and persona
   findings in `settled-findings.tsv` and the fix queue.

8. **Not-owned explicit list table** — misalignment (probe #2), radius/shadow/control-height
   (probe #5), focus-ring (probe #7), card-in-card (probe #8), motion (D-16 proxy), responsive
   reflow, above-fold geometry/target-size (probe #9), contrast ratio (axe), measured spacing
   (D-16 proxies). The lens only fires where judgment is irreducibly perceptual.

9. **A3 award extension** — documents the four-lens requirement (A2 is a prerequisite; the
   panel proposes, `admin-award-ledger.json` disposes).

10. **Relationship to quality ledger** — explains column-4 prohibition compliance, the
    parallel `panel-findings.json` separation, and cross-references to all related files.

## Verification

Automated verification all passed:
- `grep -q 'graphic_design:salience'` — FOUND
- `grep -q 'graphic_design:emphasis_ember'` — FOUND
- `grep -q 'graphic_design:composition'` — FOUND
- `grep -q '#c2410c'` — FOUND
- `grep -q '#fdba74'` — FOUND
- Column-4 integer prohibition: CLEAN (Python scan, zero violations)

## Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| task-1 | Author admin-graphic-design-lens.md | b612aea8 | guides/reference/admin-graphic-design-lens.md (created) |

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None. The document is complete and standalone — it does not depend on data from future plans to
function as the graphic-design lens instrument.

## Threat Flags

No new threat surface introduced. The document is a guide/reference markdown file with no
network endpoints, auth paths, file access patterns, or schema changes at trust boundaries.
The T-217-04-COL4 and T-217-04-BRAND threats from the plan's threat model were mitigated:
column-4 prohibition verified clean, brand-v2 ember values present.

## Self-Check: PASSED

- [x] `guides/reference/admin-graphic-design-lens.md` — FOUND
- [x] Commit b612aea8 — FOUND (verified via `git log`)
- [x] Three `graphic_design:<key>` classes present
- [x] Brand-v2 ember values (#c2410c, #fdba74) cited
- [x] Column-4 integer prohibition: CLEAN
