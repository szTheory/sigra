# Phase 199: Foundation — Tier-2 Scorecard & Stress Fixtures - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-25
**Phase:** 199-foundation-tier-2-scorecard-stress-fixtures
**Mode:** assumptions
**Areas analyzed:** Tier-2 Proxy Encoding, Monotonic Guard Tier-2 Behavior, Stress-Fixture Shape & Persona Identity, Snapshot/Recapture Blast Radius

## Assumptions Presented

### Tier-2 Proxy Encoding (LEDGER-01)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New "Tier-2 Add-on" block in admin-fractal-scorecard.md (mirrors per-level add-on structure); proxies map to existing automated gates where present, else documented-as-manual; maintainer asserts Tier 2 by flipping ledger Tier→2 + expanding Evidence column | Likely | admin-fractal-scorecard.md:42-122; admin-quality-ledger.md:50-70,81-84; glossary_test.exs; admin-modal-interaction.spec.ts |

### Monotonic Guard Tier-2 Behavior (LEDGER-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| No parser/logic change needed — guard already numeric `-lt` on column-4; add a 2→1 self-test; reconcile the stale "Tier 2 not declared" ledger prose; confirm `--base origin/main` wiring | Confident | quality-ledger-monotonic.sh:22-53; ci.yml:109-110 |

### Stress-Fixture Shape & Persona Identity (FIXT-01, FIXT-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| ≥25-event persona = existing `admin` persona (top up @audit_actions to ≥25 self-tied); list-scale bulk cohort kept OUT of Personas.all(); idempotent count-threshold upserts under MIX_ENV=test guard; "severities" maps to outcome vocab (no severity column) | Likely | seeds.ex:479-498,634-651; personas.ex:188; seeds_test.exs:107,126; audit/changeset.ex:28; query_params.ex:22; query.ex:65 |

### Snapshot / Recapture Blast Radius
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Seed changes are NOT snapshot-neutral; un-skip MG-5/6 equivalence test + close todo; recapture only affected non-canary slugs via recapture gate (impersonation-banner canary byte-stable); allowlists reset empty at end-of-phase | Likely | todo 2026-06-17-...mg5-6; ci.yml:1377-1673,1666-1667; admin-checkpoints.spec.ts:40; admin-design.spec.ts:328,371-378 |

## Corrections Made

No corrections — all four assumptions confirmed via "Yes, proceed".

## Methodology

Lenses applied from `.planning/METHODOLOGY.md`:
- **Decisive Defaulting** — all four areas resolved to a single recommended path with the runner-up
  alternatives noted (not preserved as open menus). Each fork stays inside an already-chosen
  boundary (doc structure, fixture shape, snapshot strategy) and is implementation-detail.
- **Escalation Threshold** — none of the four decisions crossed it: no change to security model,
  public/semver contract, generated-host output split, or operator-truth claims. Phase 199 builds
  measuring instruments + stress data only; it does not move any cell to Tier 2. No user escalation
  was warranted beyond the single confirm gate.

## External Research

None performed — phase is entirely repo-internal infrastructure (quality-ledger docs, a bash
guard, Elixir seed fixtures, Playwright baselines). The analyzer flagged no research gaps.
