---
created: 2026-09-23T00:00:00.000Z
status: pending
title: "The honest-skip manifest records example_playwright_smoke as docs_only step-gated, but it is a pure aggregator with no such step gate"
area: ci
severity: medium
source: Phase 241 plan 03 (D-13 / D-14 constrained parity-guard correction)
files:
  - .github/ci-skip-manifest.tsv
  - .github/workflows/ci.yml
  - scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs
---

## Problem

The `example_playwright_smoke` row in `.github/ci-skip-manifest.tsv` records
`gate_level=step` and a `docs_only` gate. At HEAD, `.github/workflows/ci.yml` defines
that job as a one-step aggregator (`Aggregate every Playwright shard result`) with no
step-level `docs_only` gate; the gated browser work belongs to `example_playwright_shard`.

`p10-no-undocumented-demotion.test.mjs` deliberately skips gate-expression comparison
for `kind=job` rows with `gate_level=step`, because the manifest has no step id with
which to resolve the actual nested step. Phase 241's p21 is intentionally restricted to
MAINTAINING.md parity and does not parse gate expressions (D-13), so neither guard
should be broadened here merely to change this manifest cell.

## Suggested follow-up

Scope a dedicated CI-manifest change that decides the authoritative representation for
the aggregator and its shard-owned gate, then updates the TSV and p10's comparison model
with a newly observed RED/GREEN proof. Do not modify `ci-gate.needs` as part of this
follow-up: `example_unit_smoke` membership is the separate, already-filed FUT-03 debt.
