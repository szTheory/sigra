# Phase 218: Elevation Wave + Nit Cleanup - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-04
**Phase:** 218-elevation-wave-nit-cleanup
**Mode:** assumptions
**Areas analyzed:** surface enumeration & render matrix, wave decomposition, panel execution & climb posture, auto-fix reality / CSS-token seam, baseline recapture seam, UI-01/UI-02 folding, harness-debt todos

## Assumptions Presented

### Surface enumeration & render matrix
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Surfaces = 8 L3 ledger cells; fractal = 36-cell inventory rendered via `/admin/_design` boards, not live routes | Confident | `admin-quality-ledger.md` L85-92; `design_gallery_live.ex` board fixtures; `admin-eval.spec.ts:187-215` |
| 8 L3 cells re-verified via representative gallery boards (mg-2/5 = users-index, mg-9/10/11 = user-show); other 6 mappings not yet written | Likely | `admin-award-ledger.json` cites board-based evidence, not live captures; 216-07 pilot `c214b574` |
| **Committed matrix is only the 2-pilot / 4-cell slice — matrix expansion is the first task** | Confident | `admin-render-sha.json` + `admin-award-ledger.json` = 4 cells vs `fix-queue.json` = 117 findings mg-1..11; `admin-panel.sh:94-99` reads `--all` from render-sha.json |

### Wave decomposition, auto-fix boundary, panel role
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Per-surface-group decomposition (7 plans), not per-cell; existing `--all` fan-outs drive the loop | Likely | `admin-eval-harness.sh` renders all boards in one run; `award-guard.mjs` climbs per-cell |
| Auto-fix applies ≈0 fixes — 13 token findings are CSS-anchored (fix-apply refuses CSS per D-13), rest are judgment/warn | Confident | `fix-apply.mjs:25-26,74`; `fix-queue.json` anchors; `open_findings` currently 0 |
| Panel run locally/operator-driven, advisory-only, never gates; baseline recapture deferred to 219 | Confident | `admin-panel.sh:47` exit-0 degrade; D-05 parallel `panel-findings.json`; ROADMAP Phase 219 owns recapture |

### UI-01/UI-02 + harness-debt todos
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| UI-01 (scripts/uat) + UI-02 (example authed screens) independent of harness, separate plans | Confident | both todos `resolves_phase:218`, touch no scripts/ci·panel·admin-eval files |
| Both harness-debt todos fold in early (probe-ids single-source, first-nav flake) | Confident | both `resolves_phase:218`; flake cost + drift risk scale with the larger matrix |

## Corrections Made

No assumptions were corrected. Two open operator choices (cost + operator-truth) were escalated
and answered:

### Panel execution
- **Question:** Run the LLM panel in this wave (real API spend, advisory) or stay deterministic-only?
- **Operator choice:** **Run panel locally, `--changed-only`** (bounded first-run spend; skip cache
  keeps re-runs ~free). → CONTEXT D-04.

### Climb ambition
- **Question:** How aggressive should the award sub-score climb be, given auto-fix ≈0?
- **Operator choice:** **Verify-hold + selective earned raises** (honesty/operator-truth-first;
  raises land as PR sign-off decisions). → CONTEXT D-05.

## External Research

None performed — entirely an in-repo execution wave on the 216/217 harness. The one genuine
planning gap (the 6 not-yet-mapped L3→gallery-board proxies) is an in-repo authoring task against
`design_gallery_live.ex` + `admin-quality-ledger.md`, not external research.
