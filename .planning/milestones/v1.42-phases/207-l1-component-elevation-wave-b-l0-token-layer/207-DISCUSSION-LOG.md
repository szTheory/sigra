# Phase 207: L1 Component Elevation Wave B + L0 Token Layer - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-28
**Phase:** 207-l1-component-elevation-wave-b-l0-token-layer
**Mode:** assumptions
**Areas analyzed:** Scope Boundary, Elevation Mechanics, Per-Component Gaps, COMP-03 Token CI Guard, Ledger Flip Targets

## Assumptions Presented

### Scope Boundary (component + token isolated-board work only)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| 207 = 5 components on isolated `board-*` boards + L0 token layer; cross-page page-composition findings route to Phase 209, NOT 207 | Confident | `ROADMAP.md:100-105` (207 criteria) vs `:125-135` (209); 206-CONTEXT D-01; IA-diagnostic uses stale v1.41 numbering |

### Elevation Mechanics (mirror 206 verbatim)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Identical 206 method: audit→cite→narrow-gap-fix→ledger-flip→recapture; edit `priv/templates/` source only; reuse existing axe harness + global reduced-motion block + conformance guard | Confident | 206-CONTEXT D-02/D-03/D-05/D-08/D-09; boards already in `admin-design.spec.ts:100-102`; guard at `scripts/ci/admin-css-conformance.sh` |

### Per-Component Gaps (boards + state CSS already wired)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Real CSS gaps minimal; interactive components already have full states; skeleton motion already reduced-motion-safe | Confident | `page_back` states `sigra_admin.css:430-486`; `field_help` states ~:894-903 + test ~:695-712; skeleton strip ~:1467-1477 + assertion ~:653-677; `empty_state`/`scope_ribbon` static |

### COMP-03 Token CI Guard
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Fold the deferred token-completeness guard (resolves_phase 207) + extend conformance guard to raw-px (COMP-03 says "no hex/px"; current guard checks hex only) | Likely | todo `2026-06-18-token-reference-completeness-ci-guard.md`; `admin-token-reference.md:~3` (96/96 claim); `admin-css-conformance.sh:6-7` (hex only) |

### Ledger Flip Targets
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Exactly 6 rows flip 1→bare 2 (5 L1 components + `token-layer` L0); allowlists empty; canaries byte-stable; monotonic guard exits 0 | Confident | `admin-quality-ledger.md:60,66-68,71,72` (rows at 1); Wave-A rows `:61-73` (exemplar); ROADMAP 207 criteria 3-4 |

## Corrections Made

No corrections — all assumptions confirmed. The single discretionary item (COMP-03 scope)
was resolved by user selection below rather than correcting a wrong assumption.

## User Decisions

### COMP-03 Token-Layer Scope (Likely assumption #4)
- **Question:** How ambitious should the COMP-03 token-layer conformance be?
- **User chose:** **Fold guard + raw-px** (the recommended option) — fold the token-
  completeness CI guard AND extend the conformance guard to catch raw-px (full COMP-03
  "no hex/px"), with a documented manual-review fallback only if raw-px proves too heavy.
- **Reason:** Strongest durable proof; matches the zero-human-UAT posture and the 206
  precedent of building durable guards over manual review. Captured as D-06 + D-07 (with
  D-07a fallback).

## External Research

None — internal design-system work mirroring the completed Phase 206 Wave A on
infrastructure (boards, axe harness, conformance guard, reduced-motion block, ledger format)
that already exists in-repo. No library-compatibility or ecosystem question was load-bearing.
