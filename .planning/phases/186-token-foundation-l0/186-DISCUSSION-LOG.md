# Phase 186: Token Foundation (L0) - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-14
**Phase:** 186-token-foundation-l0
**Mode:** assumptions
**Areas analyzed:** Ratification deliverable shape · Scope of token-value changes · AA verification mechanism · Motion-budget ratification · Three-surface parity (+ fourth surface)

## Assumptions Presented

### Ratification deliverable shape (TOKEN-01)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Per-token rationale + brand ref → new standalone `guides/reference/admin-token-reference.md`; fill L0 ledger row pointing at it; not inline CSS prose, not scorecard inflation | Likely | Phase 185 standalone-sibling convention (`185-CONTEXT.md:108-117`); ledger has no L0 row (`admin-quality-ledger.md:34-59`); design-contract documents components not tokens |

### Scope of token-value changes (blast-radius)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Doc-and-test-dominant, near-zero value churn; dark AA already remediated; any real change declares slugs in both allowlists | Likely | `sigra_admin.css:167-204` dark block `#fdba74` "~1.88:1 → ≥4.5:1"; `tokens.json:82-97` matching dark values; `admin-design-contract.md:207` v1.34 AA resolution note; empty allowlists `snapshot-allowlist-design:1-19` |

### AA verification mechanism (TOKEN-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| axe (rendered boards, light+dark) + extend existing `contrastRatio()` for brand-soft/tone-soft pairs; no cartesian token-pair calculator; "every pair" = every rendered pair | Likely | `admin-design.spec.ts:32-43` axe per board; `admin-theme.spec.ts:183` `contrastRatio()` helper used at 519/536/554/570/675/697; gallery renders all components in all tones |

### Motion-budget ratification (TOKEN-03)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Motion tokens already exist; ratify = document existing budget against emilkowal.ski, no value change; defer exit-asymmetry to L1 | Confident (exist) / Likely (doc-only) | `sigra_admin.css:117-137` 18 motion declarations (press120/pop180/fast140/medium220/slow300 + 4 easings + 3 transitions); `tokens.json:155-160` subset; reduced-motion at 351-368; external research validated alignment |

### Three-surface parity + fourth surface (TOKEN-04, THEME-01)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| No automated parity guard today (parity manual); hidden fourth surface = example `app.css` explicit-toggle dark block duplicating `sigra_admin.css` `@media` System path; recommend adding lightweight parity assertion | Confident | grep for `tokens.json` finds only docs, zero scripts/CI/tests; `sigra_admin.css:167-204` (System) and `app.css:1474-1533+` (`data-sg-admin-theme`) carry byte-identical dark values; auth `sigra_auth.css:1-103` separate `--sigra-auth-*` namespace; `185-CONTEXT.md:244-246` auth-copy wart note |

## Corrections Made

No corrections — user selected "Yes, proceed"; all five assumptions confirmed as locked decisions.

## External Research

- **emilkowal.ski motion guidance (TOKEN-03 validation target):** Verdict **ALIGNED**. Durations
  — press 120ms (his 100–160), pop 180ms (his cited dropdown sweet-spot), fast 140ms, medium 220ms
  (his 150–250 dropdown range), slow 300ms (his "under 300ms" ceiling). Easings — ease-out for
  enters ✅, never ease-in ✅, flat ease-out on destructive ✅. Reduced-motion "strip movement,
  keep opacity" ✅. **Two non-blocking refinement flags** (deferred to Phase 187): (a) overlay
  300ms sits exactly on the ceiling (slightly slow for dropdown-class surfaces); (b) budget
  encodes no faster-exit-than-enter asymmetry, the one principle Emil explicitly wants. Sources:
  emilkowal.ski/ui/7-practical-animation-tips; Emil's emil-design-eng SKILL.md; animations.dev.
- **WCAG 2.1 AA thresholds:** standard (4.5:1 normal text, 3:1 large/UI), already encoded in the
  harness (`admin-fractal-scorecard.md:30,32`) — no external lookup needed.
