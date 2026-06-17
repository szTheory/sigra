# Phase 189: Page Compositions (L3) - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-17
**Phase:** 189-page-compositions-l3
**Mode:** assumptions
**Areas analyzed:** Page scorecard authoring vs reuse · Archetype mapping · Modal/overlay
focus-trap + scroll (PAGE-03) · Page-level CSS/JS parity surfaces · 8-checkpoint ratification

## Assumptions Presented

### Page scorecard — reuse, do not author
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| L3 rubric already exists; 189 fills evidence + ratifies the 6 L3 ledger rows, does not author a new scorecard | Confident | `guides/reference/admin-fractal-scorecard.md` L81-102; `admin-quality-ledger.md` L61-66; fixed grading anchor for phases 186-192 |

### Archetype mapping
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Overview=`index_live.ex` (+`organization_live.ex` as org-scoped Overview instance, not a 4th archetype); List=`users_index_live.ex`; Detail=`user_show_live.ex`; non-archetypal=`branding_live.ex` + `audit_index_live.ex`/`audit_user_live.ex` | Likely | Each page renders its archetype's named shape; `admin-checkpoints.spec.ts` L187-195 treats org overview as same front-door archetype, org scope |

### Modal/overlay focus-trap + scroll-restore (PAGE-03)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New `admin_hooks.js` LiveView hook (modeled on CmdK trap) for focus-trap/Escape/focus-return/scroll on `sg-confirm-overlay` in `user_show_live.ex` + `branding_live.ex` | Likely → Confident (APG-confirmed) | Both confirm overlays are server-rendered markup with no `phx-hook`/keydown/outside-click; CSS already centers (`sigra_admin.css` 637-665); CmdK reference trap exists in `admin_hooks.js`; 188 D-13/D-14 deferral. Stale-hint correction: no `<dialog>` remains — already migrated |

### Page-level CSS/JS parity surfaces
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Net-new page CSS → canonical `sigra_admin.css` `@layer sg-components`, var(--sg-*)-only, byte-identical across 3 surfaces; new JS → `admin_hooks.js` + example mirror; `app.css` keeps only `vt-*` | Confident | 187 D-01..04 / 188 D-03/D-05 parity rule; overlay/sticky CSS already canonical; `admin_hooks.js` has example mirror |

### 8-checkpoint ratification + evidence
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Ratification = existing `admin-checkpoints.spec.ts` (8 × 3: chromium/mobile/dark) + `toHaveScreenshot` baselines + axe wcag2a/aa; add assertions, not a new lane; intended deltas → canary-guarded recapture | Likely | `admin-checkpoints.spec.ts` L14-30, L115-148 enumerate 8 pages × 3 projects with axe gate; 188 D-09 + zero-human UAT convention |

## Corrections Made

No corrections — user selected "Yes, proceed". All assumptions confirmed.

## External Research

- **GOV.UK / GDS information architecture** — "most important information first" (inverted pyramid)
  and "start with user needs" are canonical GDS principles, **confirming** the rubric's
  general→specific ordering. **Refinement:** the literal "tasks-first / posture-second /
  capabilities-last" triplet is a *derived application*, not a GDS quote — cite as derived
  (→ CONTEXT D-02). Sources: gov.uk/guidance/government-design-principles;
  designnotes.blog.gov.uk/2015/07/03/one-thing-per-page.
- **WAI-ARIA APG Dialog (Modal) pattern** — **confirms** initial-focus-into-dialog,
  focus-return-to-trigger, Escape-closes, `role="dialog"` + `aria-modal="true"` + labelling,
  focus containment/wrap. **Refinements:** (1) outside-click dismissal is an *optional enhancement*,
  not an APG requirement; (2) background scroll-lock is *convention*, not APG; (3) score on
  behavior (background non-interactive + focus contained), not technique (`inert` vs JS-wrap) —
  → CONTEXT D-07/D-08. Source: w3.org/WAI/ARIA/apg/patterns/dialog-modal.
