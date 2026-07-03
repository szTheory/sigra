# Phase 205: Foundation - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-28
**Phase:** 205-foundation
**Mode:** assumptions + deep per-area research (user requested full pros/cons/tradeoffs,
idiomatic-Elixir/Phoenix grounding, prior-art lessons, DX/UX lens per JTBD)
**Areas analyzed:** INSTR-01 (persona-JTBD rubric), INSTR-02 (board-cfg composites),
INSTR-03 (IA diagnostic), FIXT-01 (edge/empty fixtures), folded-todo disposition

## Assumptions Presented

### INSTR-01 — Persona-JTBD Rubric
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Sibling doc mirroring fractal-scorecard; lenses bound to existing demo personas (admin/morgan) + L4 flows, not invented | Confident | `admin-fractal-scorecard.md`, `admin-quality-ledger.md:93-95`, `personas.ex:138`, REQUIREMENTS INSTR-01 |
| Fixed output schema = copy-pasteable template Phase 209's 8 docs instantiate | Likely | scorecard "feeds ledger identically"; PAGE-01; no prior `uat-evidence` panel precedent |

### INSTR-02 — board-cfg Composites
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `board-cfg-*` purely additive; new composites + CONFIG_BOARDS array; isolated boards untouched | Likely | grep: `board-cfg` only in `.planning/`; spec arrays + capture loop; gallery static dev-only |
| Not snapshot-neutral; recapture only new slugs; canary byte-stable; allowlists empty | Confident | Phase 199 D-12/D-14/D-15 |

### INSTR-03 / FIXT-01 — Fixtures + Diagnostic
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| FIXT-01 ~80% inherited from Phase 199; net-new gap = explicit empty-state fixture | Likely | `seeds.ex` cohort/≥25-event/overflow/status all present; `flow-org-admin` empty-boundary partial |
| "mix test fixture unmodified" holds via loadtest-/demo cohort segregation + MIX_ENV guard | Confident | Phase 199 D-09/D-10; `seeds_test.exs` invariants |
| `v1.42-IA-DIAGNOSTIC.md` net-new advisory doc; distinct from Phase 209 scored docs | Confident | no prior IA-diagnostic; ROADMAP 205 SC-3 vs 209 SC-1 separation |

### Folded-Todo Disposition
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Fold IN-02 / IN-04 / IN-05 (+ IN-01/IN-03 opportunistic) — harden this phase's substrate | Likely | todo flags IN-02/IN-05 "recommended"; IN-04 "200-204" string verifiably stale |

## Deep Research Performed (user-requested)

Three parallel `gsd-advisor-researcher` agents — each grounded in repo prior-art (`prompts/`,
`guides/reference/admin-*`, seeds/personas/gallery) plus external best-practice/prior-art.

- **Rubric instrument (INSTR-01/03):** heuristic-eval reliability (Nielsen severity unreliability,
  CHI-2016 5-point-scale noisy-middle), LLM-as-judge determinism (RULERS evidence-anchoring,
  W&B), adversarial/refute-by-default framing (MIT Sloan rubber-stamp risk). Findings → keep/
  tighten/kill 3-point + forced-finding floor + cited anchors + YAML-frontmatter schema +
  anti-collision rule vs the ledger's awk parse + coarse Impact×Effort (not RICE) for the diagnostic.
- **Composites (INSTR-02):** Atomic Design template/page stories, Storybook composition pages,
  kitchen-sink anti-pattern, visual-regression determinism (font-stability, element-scoping,
  data-freeze). Decisive finding: gallery already duplicates static archetype markup and real
  LiveViews expose no section-level components → duplicate (R1) is the only charter-consistent option.
- **Fixtures (FIXT-01):** idiomatic Ecto seeds (separate demo from test fixtures, idempotent
  upserts, no faker/time nondeterminism), empty-entity vs zero-results UX distinction (NN/g,
  Polaris, Carbon, Cloudscape), admin-panel edge-state taxonomy (Retool/Django/ActiveAdmin/
  Supabase lineage). Decisive finding: gallery empty boards already static; the gap is live pages →
  add a real-but-empty org + zero-state persona; i18n/RTL is the one uncovered overflow class.

## Architect-Level Forks Escalated (3) — user decided

### IA-diagnostic gating
- **Original assumption:** advisory (default).
- **User decision:** **Advisory** — Phase 209 per-surface panel is the single binding gate;
  avoids double-gating, keeps the up-front pass cheap, no roadmap edits on late-discovered issues.

### Composite rendering (share vs duplicate)
- **Original assumption:** duplicate static markup (R1) + anti-drift structural guard.
- **User decision:** **Duplicate + anti-drift guard** — consistent with existing MG boards;
  shared section-component extraction (R2) recorded as a Deferred Idea (long-term answer, future
  phase), NOT auto-scheduled.

### i18n/RTL fixture coverage
- **Original assumption:** flagged as a fork (requirement names only "long-string/UUID overflow").
- **User decision:** **Add one i18n/RTL user now** — pressure-tests bidi/multi-byte rendering the
  design system has never been tested against; low-cost; slightly widens snapshot blast radius.

## External Research

See "Deep Research Performed" above. Key sources cited in the advisor outputs:
- Rubric/LLM-judge: RULERS (arxiv 2601.08654), W&B LLM-as-a-judge, heuristic-eval reliability
  (DiVA 834138), CHI-2016 severity scales, MIT Sloan rubber-stamping, adversarial-review skill.
- Composites: Storybook build-pages + kitchen-sink issue #760, UI visual-regression playbook.
- Fixtures: NN/g empty states, Cloudscape/Carbon empty-state patterns, bitcrowd idempotent seeds,
  Ecto constraints-and-upserts, seedex (seeds-vs-test-data).
