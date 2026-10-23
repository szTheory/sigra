# Phase 254: Speed Up the Measured Slow Jobs - Context

**Gathered:** 2026-10-23 (assumptions mode, four specialist analyses)
**Decision authority:** The user requested primary-source research, tradeoffs, adversarial review, and one coherent recommendation set to follow automatically. These are delegated implementation decisions; no completed optimization or acceptance result was approved.
**Status:** Discussion complete; ready for planning. Baseline source preflight passed; hosted preparation and acceptance remain unstarted. Implementation and phase verification have not started.

<domain>
## Phase Boundary

Deliver CISPEED-01 and CISPEED-02: required full-PR results at least 20% sooner by median, with non-increasing empirical p95 wait and total runner time for equivalent work. Target the measured Phase 252 costs and retain Phase 253 reliability and gate behavior. Contributors need a faster accurate answer; maintainers need unchanged useful coverage, bounded runner cost, and reproducible measurements.

No public API/authentication change, generated-host feature, UI redesign, package release, paid runner change, broad dependency upgrade, or unrelated backlog cleanup. Phase 255 owns the final contributor guidance and final replay/report presentation. Phase 254 must retain the real comparison inputs and its own acceptance calculation.
</domain>

<decisions>
## Implementation Decisions

### Measured priority and sequence
- **D-01:** Optimize both `admin_behavior` and `non_admin_smoke`. The instrumented full PR used 367 and 333 runner-seconds respectively and finished these jobs at offsets 380 and 346 seconds; the enforced required result arrived at 385 seconds. The library job used 79 seconds. Library sharding is not supported by this critical-path evidence.
- **D-02:** First reduce demonstrably repeated incidental browser preparation and confirmed duplicate tool setup. Measure the remaining preparation components. If needed, rebalance unchanged useful cases across the existing five isolated jobs using measured recipient headroom. Do not add shards or increase within-job workers by default: an extra observed container plus preparation costs roughly 67–107 seconds before useful browser work.
- **D-03:** Distinguish observed cost from proposed savings. Admin behavior's 43 native tests sum to 289.550 seconds; admin-theme's 19 sum to 85.237. Non-admin's 16 sum to 234.074, including 134.070 for organization cases across Chromium/mobile. These are opportunities, not predicted savings. Mixed failed/cancelled job averages are not successful critical-path measurements.

### Authentication preparation and state isolation
- **D-04:** Prefer a small opt-in fixture for eligible admin-theme presentation/navigation checks, reusing one freshly prepared login only within its isolated invocation. Keep a fresh browser context per test, explicit backend-state preconditions, serial execution, and fresh per-job/database authentication state. Never put authenticated storage state on the global Chromium/mobile projects. The existing design-gallery setup is precedent, not permission to apply state globally.
- **D-05:** Preserve real registration, confirmation, invitation, session, authorization and lockout assertions wherever those are the behavior under test. The organization registration/first-org lifecycle stays complete in both browser projects. Remove the invitation cases' redundant `logInIfNeeded` navigation only after proving the preceding helper already establishes that state. Retain fresh zero-organization owners and actual invitee signup/acceptance paths.
- **D-06:** Keep branding/database mutations independent of reused browser storage; a new browser context does not reset backend state. Capture auth before theme changes so default/System-mode checks remain meaningful. The theme lockout case must still create and lock its separate target through failed logins, using an explicitly anonymous context when necessary. Auth files remain temporary, uncommitted, excluded from uploads, and never shared across jobs/databases.
- **D-07:** Preserve convenient focused runs: eligible tests must work individually and as a file against fresh state. Prefer an opt-in fixture over a new setup project when project dependencies would complicate selection, coverage records or UI-mode usage. If a setup project is chosen, explicitly distinguish setup executions from original product cases and account for dependency/filter semantics. Do not add a public test endpoint, bypass security in shipped code, or add a dependency.

### Small BEAM/setup improvements and safe caches
- **D-08:** Remove explicit duplicate Hex/Rebar installation only where the pinned `setup-beam` already installed them and the tool home has not changed. The required library owner's outer dependency fetch is also redundant with `mix ci`'s existing `deps.get --check-locked`; preserve the alias and its lockfile checks. Scope cleanup to measured affected paths rather than a wholesale workflow rewrite.
- **D-09:** Evaluate a single `mix do` preparation invocation for dependency fetch, warnings-as-errors compilation, database creation/migration and seeds. Retain exact environment/port/database, task ordering and failure propagation; start the server separately. Verify cold and warm preparation, seed/migration results and a failing command before selecting it. Reduced VM startups are plausible savings, not established results.
- **D-10:** Keep current runtime/environment/port-partitioned compiled caches. A browser archive hit does not install Linux system libraries, and the npm download cache does not supply `node_modules`; retain browser OS dependencies and `npm ci`. No prebuilt image, cache trust expansion or cross-port compiled-output sharing without measured necessity and a separately justified change inside the phase boundary.
- **D-11:** Time toolchain setup, cache restoration, Mix preparation, npm/browser preparation, server readiness and route warming separately as needed. Phase 252's regex buckets classify outer GitHub step names: its summed 293-second browser “boot” includes many operations, and `test_execution: 5` is not total browser execution. Do not call those buckets component profiling. Retain identical comparison instrumentation on both paths; do not subtract estimated overhead from acceptance.

### Fixed comparison and practical feasibility
- **D-12:** Keep `252-COMPARISON-CONTRACT.json` unchanged in substance: 20 matched pre/post pairs, 40 primary real-PR invocation families, its frozen all-warm cache allocation, same full workload/runner class, and one predeclared 48-hour window. Freeze candidate identities, exact pair registrations and a balanced baseline-first/candidate-first schedule before collection. Pair nearby executions; do not update a PR mid-family and trigger superseding cancellation. Do not replace families or extend the window to improve results.
- **D-13:** The saved cohort has eight known full PR families, seven failures and one success. The successful 385-second wait is `n=1`, not an established median; 308 seconds is illustrative only. Calculate actual acceptance from the fixed matched samples: ordinary candidate median ≤0.8×baseline median, nearest-rank candidate p95 ≤baseline p95 (19th sorted value at n=20), and summed actual runner-seconds over equivalent families/attempts ≤baseline total. Report pair deltas as diagnostics, not a substituted median-of-ratios rule.
- **D-14:** Use the exact frozen application/workflow and producer source, workflow/workload files and digests from the preserved bundle plus the recovered trusted source. Both initially missing commits were resolved through GitHub and retained at `refs/gsd/phase254/baseline-application` and `refs/gsd/phase254/baseline-producer`; both have tree `bcda2b1eb386bdbaaf1bde2b6f034e0c7ee74452`. Bundle, workflow and all six declared workload-file digests match. Recheck this compact preflight before dependent implementation/acceptance. Never substitute HEAD or repair the frozen baseline to manufacture comparability.
- **D-15:** Predeclare cache preparation and image compatibility before consuming comparison families. GitHub PR merge-ref caches do not generally warm another PR; distinguish exact hits from fallback restoration. The observed historical image is not a promise that GitHub still serves it. Match compatible actual runner conditions across the new pair, disclose drift, and apply the frozen compatibility rules. Undefined warm-cache preparation or an unavailable equivalent baseline blocks hosted collection. Extra warm-up runs need a distinct explicit budget; no old Phase 253 allowance is renewed.
- **D-16:** The complete candidate includes Phase 253's reloader fix, report validation and transfer overhead. Count these costs and identify the treatment honestly as the current candidate versus the frozen Phase 252 condition; do not attribute its entire effect to Phase 254 changes alone.
- **D-17:** Preserve failure/cancellation/retry outcomes and costs. An independently diagnosed infrastructure retry stays in its original family under the locked limit. Fewer than 20 valid successful comparable pairs means insufficient data; 20 valid pairs missing any threshold means a miss. Missing timestamps/reports or incompatible conditions never count as zero cost or a pass. The p95 result describes this small sample, not a population guarantee.
- **D-18:** Reuse the existing collector and origin verifier. Keep each acquisition pass within 600 HTTP requests/60 minutes including retrieval/retries/watcher traffic, stop at REST core ≤250, and honor 403/429 reset/retry times. One owner/watcher per run, 60-second interval, one structured completion summary, failed logs only on failure. No open-ended acquisition or new measurement service.

### Useful coverage, honest failures and bounded maintenance
- **D-19:** Retain required names, one library `mix ci` owner, all five isolated browser owners, one worker per invocation and zero browser retries. Preserve Phase 253 readiness/reloader and failure/cancellation/missing/unexpected-skip controls. Rebalancing may change ownership only with an explicit before/after case/project mapping and matching gate expectations; it must not drop assertions, projects or useful work.
- **D-20:** Compare exact product test/project identities and expected/actual skipped or excluded status, not counts alone. Current native records validate selection completeness but allow skipped rows when another test passes; passing that guard alone does not prove unchanged useful coverage. Retain existing intentional skip policy and fail on newly unexplained missing/skipped work. Reuse existing records/provenance checks rather than another parallel evidence framework.
- **D-21:** Run focused local/integration checks while developing; spend fixed hosted acceptance only on a prepared candidate. Ordinary parser, fixture or expected-message errors get scoped fixes and meaningful tests, not new numbered recovery plans, count migrations or replenished acceptance. Keep prior stopped attempts and results unchanged. Implementation complete, comparison pass/miss/insufficient and whole-phase verification are separate outcomes.

### Agent's Discretion
Choose the small fixture/helper shape, internal command timing and matched scheduling mechanics within these boundaries. Select the smallest measured bundle that can plausibly improve both bottlenecks and retain runner-cost headroom. No further broad option menu is needed. Escalate only an actual contract/security change or a baseline/cache problem automation cannot resolve within existing authority.

### Folded Todos
None. The per-shard database todo describes prior implemented isolation; it is a lead for measured rebalancing, not a new migration. Old unit-smoke/manifest concerns are represented by current Phase 253 controls. Other keyword matches do not add scope or close backlog items.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**
- `.planning/ROADMAP.md` — Phase 254 goal, requirements and four success criteria; old Phase 253 route prose is historical.
- `.planning/REQUIREMENTS.md` and `.planning/PROJECT.md` — v1.50 scope, target and exclusions.
- `.planning/METHODOLOGY.md` and `AGENTS.md` — evidence feasibility, source identity, preservation, decisive defaults and bounded maintenance.
- `.planning/phases/252-measure-current-ci/252-CONTEXT.md` — prior locked measurement decisions.
- `.planning/phases/252-measure-current-ci/252-COMPARISON-CONTRACT.json` — frozen method and identities.
- `.planning/phases/252-measure-current-ci/252-BASELINE.md` and `.planning/phases/252-measure-current-ci/252-BASELINE.json` — saved measurements and limitations.
- `.planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz` — immutable source records; its digest must match the contract.
- `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-CONTEXT.md` and `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-VERIFICATION.md` — retained boundaries and current passed controls.
- `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LEARNINGS.md` and `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-RESET.md` — historical repair-loop lessons; old routing remains historical.
- `.planning/phases/254-speed-up-the-measured-slow-jobs/254-BASELINE-PREFLIGHT.json` — discussion-time local source checks; not hosted comparison readiness.
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — selective repository research on CI ergonomics, runtime-aware caches and minimal workflow abstraction.
- `test/example/AGENTS.md` — example-app and deterministic test conventions.
- [Pinned Playwright authentication guidance](https://github.com/microsoft/playwright/blob/v1.59.1/docs/src/auth.md), [project dependencies](https://github.com/microsoft/playwright/blob/v1.59.1/docs/src/test-projects-js.md#dependencies), [CI browser caching](https://playwright.dev/docs/ci#caching-browsers) — session reuse, backend mutation boundaries and Linux dependencies. Use pinned capabilities, not newer live-document options.
- [Pinned setup-beam inputs](https://github.com/erlef/setup-beam/blob/54075bcc5e249e4758d363f27d099f55d843f124/action.yml), [Mix do](https://hexdocs.pm/mix/1.19.5/Mix.Tasks.Do.html), [Mix dependency lock checking](https://hexdocs.pm/mix/1.19.5/Mix.Tasks.Deps.Get.html) — tool setup and idiomatic task composition.
- [GitHub cache semantics](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching), [concurrency](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency), [artifact API](https://docs.github.com/en/rest/actions/artifacts), [workflow jobs](https://docs.github.com/en/rest/actions/workflow-jobs) — cache scope, cancellation, producing-run identity and duration inputs.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/example/priv/playwright/tests/admin-theme.spec.ts` — repeated incidental admin registration, branding mutations and separate lockout target.
- `test/example/priv/playwright/tests/organizations.spec.ts` — complete registration/confirmation/org lifecycle plus redundant invitation-login navigation.
- `test/example/priv/playwright/tests/admin-design.setup.ts` and `test/example/priv/playwright/playwright.config.ts` — scoped auth-state precedent, five isolated serial owners and zero retries.
- `.github/actions/example-playwright-boot/action.yml` — common toolchain/cache/DB/browser/readiness setup and port-aware compiled cache.
- `scripts/ci/ci-run-metrics.sh`, `scripts/ci/ci-playwright-report.mjs`, `scripts/ci/ci-browser-records.mjs`, `scripts/ci/ci-hosted-gate-verify.py` — collection, native reports, selected-case checks and independent origin verification.

### Established Patterns
- `mix.exs` keeps contributor library checks under `mix ci`; use existing Mix tasks and explicit warnings/lockfile failures.
- Browser isolation includes server/database state, not just browser contexts. Keep roles/stable hooks/LiveView readiness without sleeps; retain existing light/dark/System checks.
- No new dependency, production auth hook, service or image is justified by present measurements.

### Integration Points
- `.github/workflows/ci.yml` — setup deduplication, existing browser selections, collection and required aggregate.
- Existing native record/report tests, workflow contract tests and Phase 253 gate controls must accompany any ownership change.
- `scripts/ci/ci-run-metrics.sh` already distinguishes pass/miss/insufficient; extend only the missing comparison mechanics.
</code_context>

<specifics>
## Specific Ideas

The user delegated coherent researched defaults, emphasized developer ergonomics and a small dependency tree, and requested adversarial analysis across relevant roles. Apply this to CI/testing/maintainer experience; product UI/brand redesign is unnecessary. Four agents covered measured costs, browser state, BEAM/cache setup and comparison failure modes. Research stops where alternatives lack measured benefit; no repeated broad fan-out is required.
</specifics>

<deferred>
## Deferred Ideas

- Final contributor runbook and final comparison-report presentation: Phase 255.
- More shards/workers, prebuilt images, broad cache redesign or transport changes: not selected; reconsider only if narrow measurements establish necessity without changing phase constraints.
- UI/auth/public API work, dependency upgrades, paid runners, releases and old release-record recovery: out of scope.
- Reviewed todos remain unchanged; no unrelated pending item was folded in or closed.
</deferred>
