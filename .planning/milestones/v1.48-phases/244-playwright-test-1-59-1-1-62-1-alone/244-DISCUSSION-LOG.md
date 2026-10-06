# Phase 244: `@playwright/test` 1.59.1 → 1.62.1, Alone - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `244-CONTEXT.md` — this log preserves the research and confirmation.

**Date:** 2026-09-25
**Phase:** 244-playwright-test-1-59-1-1-62-1-alone
**Mode:** assumptions, research-backed
**Areas analyzed:** visual drift proof; browser provenance/cache; PR #213 disposition; exact-SHA main gate evidence

## User Direction

The user requested subagent research for each assumption, evaluating pros/cons/tradeoffs, idiomatic ecosystem practices, lessons from mature projects, DX, relevant prompts, and a coherent recommendation set. Three `gsd-advisor-researcher` agents investigated the visual measurement, browser/cache, and merge/final-gate decisions. The user selected “1” to confirm the synthesized recommendations.

## Assumptions Presented and Recommendations

### Visual drift proof
- **Recommended:** Pair old/candidate renders on the same Ubuntu source revision; inventory all committed PNGs, compare exact pixels, commit a machine-readable manifest, and retain images/diffs as run artifacts.
- **Alternatives considered:** Existing PR lanes alone (incomplete snapshot coverage and tolerant comparator); a hosted service such as Percy (adds a continuing service/token/baseline contract for a one-off decision).
- **Rationale:** Playwright warns about environment-specific rendering and supports nonzero comparator thresholds. A paired run isolates the package change and gives the merge rule a direct, reviewable measurement.
- **Sources:** [Playwright visual comparisons](https://playwright.dev/docs/test-snapshots); [assertion configuration](https://playwright.dev/docs/api/class-testconfig); [CI guidance](https://playwright.dev/docs/ci).

### Browser provenance and cache behavior
- **Recommended:** Record Chromium revisions from tagged Playwright manifests. Keep the current cache design for this isolated bump, update applicable version keys, and ensure the guard checks each relevant key variant. Defer cache architecture/economics work.
- **Alternatives considered:** Download every run (simplest, repeats download cost); full lockfile hashes (easy invalidation, unrelated cache churn); derived version/revision parsing (less manual duplication, parser and maintenance risk).
- **Rationale:** Playwright binds browser binaries to its version and says browser caches may not save time. Existing multi-shard CI makes keeping current behavior reasonable for this phase, while a broad cache redesign would confound causal attribution.
- **Sources:** [Playwright browser guidance](https://playwright.dev/docs/browsers); [Playwright caching guidance](https://playwright.dev/docs/ci#caching-browsers); tagged [1.59.1 manifest](https://raw.githubusercontent.com/microsoft/playwright/v1.59.1/packages/playwright-core/browsers.json) and [1.62.1 manifest](https://raw.githubusercontent.com/microsoft/playwright/v1.62.1/packages/playwright-core/browsers.json); [Puppeteer release history](https://github.com/puppeteer/puppeteer/releases).

### PR #213 merge/defer
- **Recommended:** Merge only on exact zero drift and current passing checks; otherwise close/defer with the measurement and actionable blocker details, without opening a recapture lane.
- **Rationale:** This follows Phase 244's locked rule. At research time PR #213 was open and conflicted, and its observed August 8 run was red; that stale run is not evidence of visual drift. Live state must be checked again during execution.
- **Sources:** [PR #213](https://github.com/szTheory/sigra/pull/213); [observed run](https://github.com/szTheory/sigra/actions/runs/31229468400); [roadmap](../../ROADMAP.md).

### Final `main` gate evidence
- **Recommended:** Record the exact post-decision `main` SHA/run and job conclusions for `ci-gate`, every Playwright shard, its smoke aggregator, and generated-admin smoke. Require each consumer to have actually succeeded; a skipped job or green aggregate alone is insufficient.
- **Alternatives considered:** Aggregate-only receipt (simpler but cannot substantiate every consumer claim); detailed exact-SHA job receipt (more evidence to retain but directly proves the claim).
- **Rationale:** GitHub permits skipped jobs to count as successful, and required checks apply to the latest SHA. The receipt should preserve the distinction between “aggregate passed” and “all named consumers ran and passed.”
- **Sources:** [GitHub status checks](https://docs.github.com/en/pull-requests/reference/status-checks); [required-check troubleshooting](https://docs.github.com/en/enterprise-cloud%40latest/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks); [workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts).

## Corrections Made

No corrections — the user confirmed the complete recommendation set.

## Cohesion and Scope Notes

- The four decisions reinforce one proof chain: package/browser identity → paired visual measurement → merge/defer decision → exact-SHA main verification.
- Relevant lenses are release engineering, supply-chain correctness, deterministic testing, SRE/evidence quality, maintainability, and contributor/operator DX.
- This phase does not change Sigra's runtime Elixir/Plug/Ecto/Phoenix contracts and has no user-facing UI; brandbook, visual design, and UI accessibility decisions do not apply.
- The pending per-shard DB isolation todo was reviewed but remains out of scope because Phase 244 is explicitly isolated to the dependency bump.
- No tests were run; this discussion only created planning documentation.
