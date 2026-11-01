---
created: 2026-09-19
status: pending
severity: low
area: ci
files:
  - .github/ci-skip-manifest.tsv
  - .github/workflows/ci.yml
  - scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs
---

# `example_playwright_smoke` is inaccurately recorded as step-gated in the skip manifest

The `example_playwright_smoke` manifest row records `gate_level=step` and a `docs_only` gate,
but the job is a pure one-step aggregator with no step-level `docs_only` condition. The actual
docs-only gate is on the `example_playwright_shard` browser bodies.

Phase 241-03 records rather than fixes this discrepancy. `p10` intentionally skips gate
comparison for job rows whose gate level is `step` because the manifest has no step id to resolve,
and `p21` deliberately does not parse gate expressions. Changing the cell would activate p10's
comparison branch and needs a separately measured guard change.

## Follow-up

Decide whether to model the aggregator without a synthetic step gate, or add a resolvable step
identifier to the manifest before making gate parity enforceable for this row.
