---
created: 2026-06-20T20:30:00.000Z
status: pending
title: Make Playwright way faster — per-shard DB isolation to unlock true parallelism
area: ci
files:
  - test/example/priv/playwright/playwright.config.ts
  - .github/workflows/ci.yml
source: Jon (v1.40 ship, PR #58) — re-raise of SEED-005 thesis #4 with phase-197 evidence
---

## What

Playwright CI wall-clock is still too slow. Phase 197 banked the **reliability**
half (failure-surfacing aggregator + deterministic readiness/fonts) but explicitly
**not** the **speed** half — `197-VERIFICATION.md` Truth #2 records the critical-path
reduction as "honestly modest/near-zero."

The blocker is structural: `playwright.config.ts` is `workers: 1,
fullyParallel: false` **by design**, because all specs share one booted example app +
one Postgres DB with mutating state. So the 5 spec launches run serially. True
parallelism requires **test-data isolation**, not config flags.

## The lever (highest-leverage remaining CI-PERF win)

1. **Per-shard DB + app isolation** — give each shard its own database (mirror the
   Phase 195 `library_tests` partition pattern) + its own booted app/port, so
   `fullyParallel`/multi-worker or matrix-sharded Playwright jobs become safe.
2. **Amortize the boot prelude** — `deps.get → compile → ecto → seeds → npm ci →
   playwright install` is the dominant fixed cost and is re-paid per shard; measure
   whether N shards net-win after N× prelude, or use a cached/pre-built app image
   (Docker layer cache — see reference_sigra_docker_dx) to kill the per-shard tax.
3. **Move heavy galleries to nightly** (design-gallery, demo-showcase), keep a fast
   representative admin smoke on the PR path, once visual baselines are deterministic.

## Where this lives

Part of the **SEED-005 CI-PERF audit** (the v1.40 CI-PERF milestone, phases 193→198).
Full context + verbatim audit playbook: `.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md`
(see the "Addendum 2026-06-20" section). Do this as part of that audit, not as a
one-off — measure-before-optimize, don't oversubscribe a 2-core hosted runner.
