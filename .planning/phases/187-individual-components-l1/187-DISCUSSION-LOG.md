# Phase 187: Individual Components (L1) - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-14
**Phase:** 187-individual-components-l1
**Mode:** assumptions
**Areas analyzed:** Component-CSS source of truth · Deferred motion vs. 186 token-value lock ·
Golden scoping / gallery state coverage / microcopy

## Assumptions Presented

### Component-CSS source of truth (the central finding)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| The 13 components' visual/state CSS is example-trapped in `app.css`; the shipped `sigra_admin.css` carries only tokens + layout + container classes, so hosts render bare components | Likely → **VERIFIED** | `sigra_admin.css` (368 lines) `@layer sg-components` holds only `.sg-card/.sg-cluster/.sg-grid/.sg-filter-panel/.sg-detail-panel/.sg-page-title/.sg-theme-switch`. Dual-file grep: `sg-metric` 0 shipped / 30 app.css; `sg-btn` 0/22; `sg-notice` 0/9; `sg-status-pill` 0/13; `sg-field-help` 0/10; `sg-applied-chip` 0/3; `sg-empty-state` 0/3; `sg-skeleton` 0/2; `sg-card-hover` 0/1. `root.html.heex:10-12` links default+admin+app; hosts link only `sigra_admin.css` |

### Deferred motion refinements vs. the 186 token-value lock
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Resolve the two 186-deferred motion refinements (exit/enter asymmetry; dropdown-tier timing) by adding net-new motion tokens, never re-tuning ratified `--sg-*` values | Likely | 186 CONTEXT D-09 explicitly defers these to 187; `sigra_admin.css:130-137` has only enter/press/tone composites (no exit); `--sg-motion-slow:300ms ~:125`; the 186 lock + `quality-ledger-monotonic.sh` constrain values only |

### Golden scoping / gallery state coverage / microcopy
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| CSS-only improvements → zero byte-golden churn; goldens update only for intended markup | Confident | `components_test.exs:35-94` strict literal goldens tied to fixed assigns; ROADMAP success "byte-goldens updated only for intended markup" |
| Gallery boards (default-only today) get enriched with full interaction-state matrices — legitimate L1 work | Likely | `design_gallery_live.ex` renders single default instances; scorecard L1 add-on demands state-matrix exhaustiveness; gallery's purpose is "every component in every state" |
| Component microcopy sourced from `admin-design-contract.md`; system-wide voice sweep deferred to Phase 191 | Confident | `components.ex` delegates copy to the design contract; ROADMAP assigns COPY-01..03 to Phase 191 |

## Corrections Made

No corrections to the three assumption areas — all locked as recommended. Two decisions were
escalated to the user (above the methodology escalation threshold):

### Component-CSS source of truth → scope decision
- **Question:** How should Phase 187 handle the confirmed gap (component visual/state CSS lives
  only in `app.css`, not shipped)?
- **User decision:** **Fold migration into 187** — 187 migrates each component's visual/state CSS
  from `app.css` into the shipped `sigra_admin.css` as it audits/improves it, so L1 improvements
  reach hosts and the milestone's distribution goal is truly met.
- **Reason:** An L1 audit improving only `app.css` would pass all gallery/Playwright gates while
  hosts ship bare components — defeating the milestone's headline goal. Accepts the scope
  expansion (cascade-layer order, example≡template byte-parity, visual-no-op canary).

### Phase-186 review-hardening todo → fold decision
- **Question:** Fold the pending todo (WR-01..03 D-11 parity-extractor hardening, IN-02
  `readNoticeStyles` dedup, IN-03 token-reference completeness guard) into Phase 187?
- **User decision:** **Don't fold — keep as a focused L0 pass.**
- **Reason:** Orthogonal L0 token-parity / test-harness robustness; the D-11 tests pass today
  (brittleness latent); folding dilutes the L1 component focus. Left in backlog.

## External Research

None performed — emilkowal.ski micro-interaction principles are already captured in the ratified
scorecard D6 and the Phase 186 motion-budget research; the codebase provided sufficient evidence
for every assumption.
