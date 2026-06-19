# Phase 185: Audit Infrastructure - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-14
**Phase:** 185-audit-infrastructure
**Mode:** assumptions
**Areas analyzed:** Gallery construction & route, Snapshot lane extension, Allowlist/canary discipline, Quality ledger format, Monotonic guard script, Scorecard rubric artifact

## Assumptions Presented

### Gallery construction & route
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Single example-only LiveView at `test/example/lib/example_web/live/admin/design_gallery_live.ex`, dev-gated, wrapped in real `:admin` shell, imports `Sigra.Admin.Components`, 13 component fns + MG groups, element-scoped stable-id boards | Confident | `lib/sigra/admin/components.ex` (13 fns at lines 50-683); `credentials_live.ex:1-8` (dev-gated precedent); `router.ex:250-294` |

### Snapshot lane extension
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add `admin-design-{chromium,mobile,dark}` projects cloning `admin-checkpoints-*`, new `tests/admin-design.spec.ts`, one element-scoped board PNG per item, paired with already-wired axe (`wcag2a`+`wcag2aa`, 0) | Confident | `playwright.config.ts:60-61,131-138`; `admin-checkpoints.spec.ts:2,114-126,143-147`; `@axe-core/playwright` in package.json |

### Allowlist / canary discipline
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Second empty `snapshot-allowlist-design` + extend `snapshot-canary-guard.sh` for `-admin-design-*` slugs (one-line sed); designate a gallery canary board | Confident | `snapshot-canary-guard.sh:17,20,24-33,53-55`; `snapshot-recapture-gate.sh:38`; `ci.yml:1095-1114` |

### Quality ledger format
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `guides/reference/admin-quality-ledger.md` Markdown table, one row per item, machine-parseable tier cell (0/1/2) + evidence link | Likely | `guides/reference/` (only contract/principles/generator-options today); `ROADMAP.md:23,191` (tier vocab) |

### Monotonic guard script
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `scripts/ci/quality-ledger-monotonic.sh` mirroring canary-guard conventions; per-cell tier compare vs base ref; new `quality_ledger_monotonic` `ci-gate` lane | Confident | `snapshot-canary-guard.sh` (template); `ci.yml:1102-1112,1116-1166` |

### Scorecard rubric artifact
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Standalone `guides/reference/admin-fractal-scorecard.md` — D1–D11 + component/group/page/flow add-ons | Likely | `ROADMAP.md:192,220`; no existing rubric file in `guides/reference/` |

## Corrections Made

No corrections — all six assumptions confirmed ("Yes, proceed").

## Genuine Ambiguities (routed to planner discretion, both below escalation threshold)

- **MG-N catalog → real-markup mapping.** Meta-component groups named in the kickoff plan but
  defined for the first time in this gallery by mirroring composed markup from the lib-owned
  admin pages. Exact MG-N → page-region mapping left to planner.
- **Guard refactor vs. second invocation** for `snapshot-canary-guard.sh` covering both lanes.

## External Research

None — the codebase plus ROADMAP/kickoff plan fully specify the rubric tiers, D-dimensions,
harness scripts, and CI wiring. `gsd-assumptions-analyzer` flagged no research gaps.
