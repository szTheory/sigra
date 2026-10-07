# Phase 244: `@playwright/test` 1.59.1 → 1.62.1, Alone - Context

**Gathered:** 2026-09-25 (assumptions mode, research-backed)
**Status:** Ready for planning

<domain>
## Phase Boundary

Determine whether PR #213's isolated Playwright dependency bump from 1.59.1 to 1.62.1 can merge with provably zero visual consequence. Measure any rendering difference CI-native on Ubuntu, preserve the browser revision and measurement evidence regardless of outcome, merge only at exactly zero drift, otherwise close/defer with the measurement, open no recapture lane, and verify the required Playwright consumers and `ci-gate` on `main` afterward. This phase does not include unrelated visual changes, snapshot recapture, Playwright parallelization/database isolation, or CI cache redesign.
</domain>

<decisions>
## Implementation Decisions

### Visual drift proof
- **D-01:** Measure the old and candidate Playwright versions on the same source revision and CI-native Ubuntu environment. Render the complete inventory of committed Playwright PNGs (expected about 115) for both versions and compare exact pixels. Missing images, dimension changes, or any differing pixel count as drift. Do not use Playwright's configurable visual-comparison tolerance as proof of exact zero.
- **D-02:** Do not update or commit PNG baselines as part of the measurement. Preserve the result in a committed machine-readable manifest regardless of the merge decision. Record source SHA, run ID, package versions, Chromium revisions, inventory, and per-image result; retain rendered images and diffs as run artifacts for inspection.

### Browser provenance and cache behavior
- **D-03:** Record the Chromium revision from each version's tagged Playwright browser manifest; do not hand-maintain revision values. Re-read the tagged manifests when executing because package-to-browser mappings can change over time.
- **D-04:** Keep the existing CI cache strategy in this phase. Update the applicable versioned cache keys for 1.62.1 and re-check that the guard validates each Playwright cache-key variant. Do not replace the cache with a lockfile-wide hash, redesign the cache mechanism, or remove caching in the same change; evaluate cache economics separately if warranted.
- **D-05:** Preserve the repository's existing CI boot and test-data isolation seams. This is an npm test-tooling update consumed by the Phoenix example and generated-host workflows, not a change to Sigra's Elixir/Plug/Ecto/Phoenix runtime contract.

### Merge or defer
- **D-06:** Merge PR #213 only if the exact-pixel comparison reports zero drift and required checks pass for the latest PR SHA. Otherwise close/defer it with the measurement and actionable failure details attached. Never open a recapture lane for this phase.
- **D-07:** Refresh the PR against current `main` and diagnose any existing failed checks before making the merge decision. The August 8, 2026 run observed during discussion was failing and the PR was conflicted; this stale run establishes neither zero nor nonzero visual drift and must not substitute for new evidence.

### Final `main` verification
- **D-08:** After either merge or deferral, capture the exact resulting `main` SHA and run ID and verify successful execution of `ci-gate`, every `example_playwright_shard` matrix job, `example_playwright_smoke`, and `generated_admin_playwright_smoke`. A skipped job or green aggregate alone does not prove that each named consumer ran successfully.
- **D-09:** Preserve a committed machine-readable receipt that maps each required consumer to its exact-SHA job conclusion. Keep the aggregate gate result and individual consumer results distinct so the evidence states exactly what ran.

### the agent's Discretion
- Choose the focused CI job/script structure, machine-readable manifest schema, and artifact layout that reuse existing repository conventions while proving the decisions above. Keep logs and the committed receipt understandable to a maintainer who only needs to decide merge versus defer.
- Reconfirm live PR state, required check names, cache-key variants, and browser manifest revisions at execution time; those external/current values may change after this context was gathered.

### Reviewed Todos (not folded)
- `.planning/todos/pending/2026-06-20-playwright-parallelization-per-shard-db.md` concerns CI speed and per-shard database/app isolation. It remains outside this version-bump-only phase.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 244 goal and success criteria; fixed merge/defer boundary.
- `.planning/REQUIREMENTS.md` — QUEUE-02 requirement.
- `.planning/METHODOLOGY.md` — Automation-First Verification, Decisive Defaulting, and escalation/research principles.
- `.planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-CONTEXT.md` — #213 reservation, ordered dependency work, and recovery boundaries.
- `.planning/phases/240-green-main-evidence-honest-pages-script/240-CONTEXT.md` — repository precedent for exact-run and job-level CI evidence.
- `.planning/todos/pending/2026-06-20-playwright-parallelization-per-shard-db.md` — reviewed adjacent idea, explicitly deferred from this phase.
- `.github/workflows/ci.yml` — Playwright jobs, cache keys, aggregators, and `ci-gate` dependency graph.
- `test/example/priv/playwright/package-lock.json` — locked Playwright package versions.
- `.github/actions/example-playwright-boot/action.yml` — shared example Playwright boot/cache behavior.
- `scripts/ci/playwright-cache-key-guard.sh` — current version/cache-key guard.
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — project CI/CD research guidance.
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — project OSS maintenance guidance.
- `prompts/ARCHITECTURE-CODE-WALKTHROUGH-DNA.md` — project architecture and maintainability lens.
- [Playwright visual comparisons](https://playwright.dev/docs/test-snapshots) — environment consistency guidance.
- [Playwright screenshot assertion configuration](https://playwright.dev/docs/api/class-testconfig) — comparison threshold semantics.
- [Playwright CI guidance](https://playwright.dev/docs/ci) — browser caching tradeoffs and CI artifacts.
- [Playwright browser installation/version guidance](https://playwright.dev/docs/browsers) — package-specific browser revisions.
- [GitHub Actions dependency caching](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching) — exact cache-hit behavior.
- [GitHub workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts) — temporary evidence retention.
- [GitHub status checks](https://docs.github.com/en/pull-requests/reference/status-checks) — skipped/success conclusions.
- [GitHub required status check guidance](https://docs.github.com/en/enterprise-cloud%40latest/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks) — latest-SHA requirement.
- [Playwright 1.59.1 browser manifest](https://raw.githubusercontent.com/microsoft/playwright/v1.59.1/packages/playwright-core/browsers.json) and [Playwright 1.62.1 browser manifest](https://raw.githubusercontent.com/microsoft/playwright/v1.62.1/packages/playwright-core/browsers.json) — source of pre/post browser revisions.
- [Puppeteer release history](https://github.com/puppeteer/puppeteer/releases) — ecosystem example of explicit browser rolls paired with package updates.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.github/workflows/ci.yml` already provides Ubuntu Playwright shard jobs, smoke aggregation, generated-admin smoke, and the downstream `ci-gate`.
- `.github/actions/example-playwright-boot/action.yml` centralizes example app startup and browser-cache handling.
- `scripts/ci/playwright-cache-key-guard.sh` already checks a lockfile/version-to-cache-key relationship and is the existing seam to re-check.
- Existing Playwright tests and committed snapshots supply the visual corpus; inventory all committed PNGs instead of assuming a test subset is complete.
- Existing CI evidence and capture scripts provide patterns for durable JSON receipts and exact-run provenance.

### Established Patterns
- CI runs against Ubuntu for stable browser rendering; local macOS renders are not acceptable as the phase measurement.
- `npm ci` and the committed lockfile define the dependency state. Playwright package versions and their browser binaries are coupled.
- Snapshot canary guards protect committed PNG changes but do not measure rendered pixel drift; the measurement needs its own explicit comparator.
- GitHub Actions can report skipped jobs as successful to downstream checks, so consumer execution must be distinguished from aggregate success.
- Sigra's existing Playwright lanes boot example/generated hosts and isolate data per shard. Preserve those boundaries; this phase does not change application behavior or Ecto data architecture.

### Integration Points
- Dependency and lockfile: `test/example/priv/playwright/package-lock.json`.
- Browser setup and cache key consumers: `.github/workflows/ci.yml` and `.github/actions/example-playwright-boot/action.yml`.
- Cache guard: `scripts/ci/playwright-cache-key-guard.sh`, invoked through the `fast_checks` workflow path.
- Post-decision proof: the five `example_playwright_shard` matrix jobs, `example_playwright_smoke`, `generated_admin_playwright_smoke`, and `ci-gate` on the resulting `main` SHA.
</code_context>

<specifics>
## Specific Ideas

- Make the decision understandable at a glance: exactly zero pixel changes means the bump may merge if current checks pass; any difference or unproven result means defer with evidence.
- The committed receipt is durable truth; uploaded images/diffs support human inspection but do not replace the receipt.
- Do not let a previous red run, a skipped job, or a green aggregate stand in for the specific claim it does not prove.
</specifics>

<deferred>
## Deferred Ideas

- Per-shard database/app isolation and Playwright CI parallelization remain in `.planning/todos/pending/2026-06-20-playwright-parallelization-per-shard-db.md`; they are a separate CI performance effort.
- Any ongoing hosted visual-review service or browser-cache redesign should be evaluated separately from this isolated dependency bump.
</deferred>
