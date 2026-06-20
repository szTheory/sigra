# Phase 194: Caching Correctness & Micro-Job Consolidation - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-19
**Phase:** 194-caching-correctness-micro-job-consolidation
**Mode:** assumptions
**Areas analyzed:** Required-check safety; Cache key precision; deps/_build/PLT separation + restore guarantee; Cache hit-rate observability + bust docs; Micro-job consolidation shape; Reality reconciliation

## Assumptions Presented

### Required-check safety
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Only 5 lane names in ruleset 14941512 are required; ci-gate and the 7 guards are NOT | Confident | `gh api …/rulesets/14941512` active; legacy branch protection 404; `193-BASELINE.md:36` checked only legacy API; `MAINTAINING.md:111-117` lists a stale required name |

### Cache key precision
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add OTP+Elixir+buster to every deps+_build key, uniformly across ~10 blocks | Confident | All keys today `${{ runner.os }}-library-${{ hashFiles('mix.lock') }}` (ci.yml:125,174,248,310,361,411,459,517,680); `.tool-versions` single pin; a version bump silently reuses stale `_build` |

### deps/_build/PLT separation + restore guarantee
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Keep deps+_build co-located (no PLT today); preserve unconditional deps.get; restore-keys optional | Confident | No dialyxir/PLT in ci.yml (grep); deps+_build share path (ci.yml:122-125); deps.get always-run step per lane (ci.yml:136,185,255,313,...) |

### Cache hit-rate observability + bust docs
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Extend Phase-193 `$GITHUB_STEP_SUMMARY` pattern (no new action); doc buster in MAINTAINING.md | Likely | 193 pattern at ci.yml:197-217; `193-03-SUMMARY.md:62-72`; MAINTAINING.md owns the CI runbook |

### Micro-job consolidation shape
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Fold 6 leaf guards into fast_checks; keep release_ref_guard separate; rewire ci-gate.needs | Confident | release_ref_guard is `needs:` of ~9 lanes (ci.yml:82,149,224,339,389,658,723,1012); other 6 are leaves; ci-gate references only snapshot_drift_guard + quality_ledger_monotonic (ci.yml:1216-1217) |

## Corrections Made

No assumptions were overturned. Two genuine forks (deviations from / contradictions of the
ROADMAP text) were surfaced as explicit questions; the user confirmed the recommended option
for both:

### Micro-job consolidation — release_ref_guard
- **Original assumption:** Keep release_ref_guard as a separate fast DAG gate; fold only the 6 leaf guards.
- **User decision:** **Keep it separate (deviate from roadmap literal).** ROADMAP/CACHE-02 lists
  release_ref_guard among jobs to fold, but folding it would add checkout latency in front of ~9
  heavy lanes. Confirmed deviation → D-12.

### Required-check reality reconciliation
- **Original assumption:** Live ruleset (5 names) is ground truth, not ci-gate.
- **User decision:** **Preserve the 5 names AND fix the docs.** This phase corrects
  MAINTAINING.md's stale required-check list and records that ci-gate is an internal aggregator,
  not the enforced required check (ROADMAP success criterion #4 reflects an outdated premise).
  Confirmed → D-15.

## External Research

Two tight items were flagged by the analyzer as codebase-insufficient; deferred to the
plan-phase researcher (not blocking context capture):
- GitHub ruleset enforcement semantics on job rename/removal under
  `strict_required_status_checks_policy: true` (informs how strictly to preserve the 5 names).
- `actions/cache@v5` `restore-keys` partial-restore vs `outputs.cache-hit` semantics
  (informs how the hit-rate metric is labeled — exact vs partial restore).
