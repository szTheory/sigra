# Phase 203: Consistency Propagation - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-26
**Phase:** 203-consistency-propagation
**Mode:** assumptions
**Areas analyzed:** Overviews, Branding workbench, Ledger ratchet + PAGE-04 fold, Design gallery / recapture, Docs/archetypes + CSS lockstep + scope guardrail

## Assumptions Presented

### Overviews (index_live + organization_live)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Both already emit the canonical Overview archetype; PROP-01 is a light component-level pass (align org `Confirmed`/`ok` pill + global "Auth coverage" chip to 201 reductions), NOT a recomposition | Likely | index_live.ex:38-75,113-122; organization_live.ex:48-87,102-106; admin-design-contract.md:178-195,276; 201 D-03/D-04 |

### Branding workbench
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Heaviest lift: bespoke composition, no archetype; private color_field/preview_pair/detail_input not in components.ex (UI-principle :29); #restore-defaults-overlay ConfirmDialog NOT tested by admin-modal-interaction.spec.ts (only user-sessions dialog is) | Confident | branding_live.ex:349-378; admin-modal-interaction.spec.ts:99,167; admin-quality-ledger.md:92; admin-ui-principles.md:29 |

### Ledger ratchet + PAGE-04 scoring fold
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Three bare-`1` cells (index-live :85, organization-live :86, branding-live :92) flip 1→2 with honestly-applicable proxies + N/A justifications like users-index-live :87; PAGE-04 todo (resolves_phase: 203) folded via expanded branding evidence | Likely | admin-quality-ledger.md:85,86,87,92,14-27; admin-fractal-scorecard.md:135-167; todos/.../2026-06-17-page04-branding-explicit-scoring.md:10 |

### Design gallery / MG boards + recapture
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Recapture global-overview/org-overview slugs + MG-3/MG-7/MG-8 iff markup changes; no branding board/slug exists → branding visual blast radius = existing admin-generated/admin-theme + new modal test (no screenshots); allowlists left empty for 204 | Likely | admin-checkpoints.spec.ts:193,204; design_gallery_live.ex:556,934,964; snapshot-recapture-gate.sh |

### Docs/archetypes + CSS triple-copy + scope guardrail
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add a Branding/Workbench archetype to the contract (only Overview/List/Detail/Audit Explorer exist); new sg-* classes land byte-identically in all three CSS copies; explicitly rule OUT net-new surfaces | Confident | admin-design-contract.md:172,211,284,331; three CSS copies (golden-diff gated); 202 D-13 |

## Corrections Made

No assumptions were overturned. Two consequential scope judgment calls were confirmed at their
maximal-coherence variant via AskUserQuestion:

### Branding workbench scope
- **Question:** How far should branding's elevation go this phase?
- **User choice:** **Full** — route private components through components.ex + add a real
  #restore-defaults-overlay APG/axe modal test + add a Branding/Workbench archetype + ratchet
  branding-live 1→2 with earned (not fabricated) proxy evidence.
- **Effect:** Locks D-05, D-06, D-07, D-08 (branding leg), D-09 at full scope.

### Overview pills
- **Question:** Touch the Overviews' stale pills/chips, or leave as-is?
- **User choice:** **Align pills to 201's reduced vocabulary (recapture overviews)** — drop the org
  roster's always-on green `Confirmed`/`ok` pill, demote the global "Authentication coverage" chip;
  accept recapture of global-overview + org-overview (+ MG-7/MG-8 iff mirrored).
- **Effect:** Locks D-02, D-03, D-10 at the "make same-job → same-component literally true" variant.

## External Research

None performed — codebase-internal consistency phase; all evidence resolvable from the repo and the
200–202 CONTEXT invariants.
