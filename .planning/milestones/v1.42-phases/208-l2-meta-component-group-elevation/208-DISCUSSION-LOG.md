# Phase 208: L2 Meta-Component Group Elevation - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-29
**Phase:** 208-l2-meta-component-group-elevation
**Mode:** assumptions
**Areas analyzed:** Scope boundary (GA-1), Elevation mechanic, cfg baselines + MG-7/8 coverage (GA-2), Ledger flip + snapshot discipline, State-coverage nuance

## Assumptions Presented

### GA-1: Scope boundary — group boards only
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| 208 stays strictly group-board work; IA-diagnostic "feeds 208" page findings (org empty-state, alarm verbosity, invite CTA, total-users redundancy) route to Phase 209 | Confident | ROADMAP.md:116-129 (208=group) vs :131-144 (209=page pass); v1.42-IA-DIAGNOSTIC.md:248-282 stale v1.41 numbering; 207-CONTEXT D-01 precedent |

### Elevation mechanic
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Mirror 206/207 verbatim (audit→cite→narrow-fix→flip→recapture); boards already structurally Tier-2; CSS edits in priv/templates source, board markup example-only | Confident | admin-design.spec.ts gate stack :257/:349/:318-362; design_gallery_live.ex:455-1177; 207-CONTEXT D-02/D-03 |

### GA-2: cfg baselines + MG-7/8 coverage
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| 0 committed cfg baselines → capture 4 cfg composites (12 PNGs) CI-native via admin_design_recapture; fold Phase-205 debt todo | Confident | 33 committed mg vs 0 cfg baselines; phase205-debt todo:16-25; ci.yml:1379/:1044 |
| MG-7/MG-8 isolated-board-only sufficient; no net-new cfg-org board | Likely → user-ratified | CONFIG_BOARDS=4 (admin-design.spec.ts:118), no cfg-org; mg-7/8 full isolated coverage design_gallery_live.ex:934-994 |

### Ledger flip + snapshot discipline
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Flip 11 mg rows 1→bare `2`; mg-5/6 content-equivalence only, N/A elsewhere; surgical recapture; canaries stable; allowlists empty; monotonic exits 0 | Confident | admin-quality-ledger.md:74-84 (rows), :61-73 (exemplar); 207-CONTEXT D-08/D-09 |

### State-coverage nuance
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| mg-3/mg-9/mg-11 deliberate "state N/A note" — don't fabricate; cite explicitly in ledger | Likely | design_gallery_live.ex:574-579, :1024-1028, :1108-1110; GROUP_STATE_MARKERS:120-131 |

## Corrections Made

No corrections to the assumption set — user selected "All correct — proceed."

One genuine fork (the only Unclear/judgment item) was surfaced and ratified:

### GA-2 — MG-7/MG-8 composite coverage
- **Original assumption:** Isolated-board coverage sufficient; do not author a net-new
  `board-cfg-org` composite.
- **User decision:** **Isolated-board-only is sufficient.** Document in the ledger that no
  cfg-org composite exists by design; criterion 2 reads as "every group that *has* a cfg
  composite passes." (Honors the milestone's "no net-new surfaces" posture.)
- **Reason:** Avoid net-new gallery surface; MG-7/8 already have full isolated-board state
  coverage + committed baselines.

## External Research

None performed — self-contained design-system work; all gates, baselines, ledger rows, and the
scope-boundary precedent are present in the repo.
