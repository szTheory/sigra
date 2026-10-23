# Phase 252: Measure Current CI - Context

**Gathered:** 2026-10-12 (assumptions mode, researched with subagents)
**Confirmed:** User selected `1` to accept the complete recommendation set.
**Status:** Ready for planning; implementation and phase verification not started.

<domain>
## Phase Boundary

Deliver CIMEAS-01 and CIMEAS-02: a replayable current CI baseline for pull requests, main pushes and nightly runs; measured job, step, test, setup and cache costs; a ranked improvement list and bounded current failure shortlist. Fix the later comparison contract before optimizing anything. Contributors need to know how long they wait for required checks; maintainers need to know which costs and failures merit work.

The milestone targets remain a 20% reduction in median required PR-result elapsed time, no increase in its empirical p95, and no increase in total runner time for comparable PR workloads. Phase 253 owns fixes and required-check regression protection; Phase 254 owns optimization; Phase 255 owns final contributor guidance and comparison reporting. Existing old release-record gaps are not prerequisites.
</domain>

<decisions>
## Implementation Decisions

### Current run populations and required result

- **D-01:** Keep pull-request, push-to-main and scheduled-nightly runs separate. Manual probes and release-branch pushes are separate populations. Preserve literal outcomes and all attempts before selecting any speed cohort.
- **D-02:** Separate full-workload and docs-only PRs using saved actual change/skip information. A changed mix of these PR types must not count as a speed improvement.
- **D-03:** Re-read and save effective required rules before collection. The discovery check confirmed ruleset `14941512` requires `Library tests`, `Example unit smoke (ExUnit + ConnTest)`, `Install smoke (fresh phx.new + sigra.install)`, `Example HTTP smoke (boot + curl critical routes)`, and `Example Playwright smoke (full lifecycle)`. A changed rule is a concrete measurement-contract diagnostic, not permission to silently choose a different endpoint.
- **D-04:** Required PR-result elapsed time is original run creation to completion of the last enforced required context for that revision/run family. Record first-attempt and eventual-after-rerun waits separately. Missing, cancelled or unexpectedly skipped required work cannot become a successful speed observation. Report internal `ci-gate` and whole-workflow completion as additional diagnostics.
- **D-05:** Report initial waiting, dependency/orchestration gaps and job execution separately where source timestamps support them. Run creation to first actual job start is initial waiting; it is not proof of pure runner queue duration. Unknown queue or timestamp data stay unknown.
- **D-06:** Runner time is summed actual job start-to-end durations across all executed jobs and attempts in the comparable run family. Keep cancellation and rerun costs. Distinguish this from parallel wall time and billed minutes; absent timestamps are not zero. A PR containing several source revisions must not silently become several independent observations of one revision.

### Lean collection and replay

- **D-07:** Extend `scripts/ci/ci-run-metrics.sh` and its existing hermetic seams instead of adding a service or package. Save raw run, per-attempt job and step records with offline replay commands. Parameterized `gh api` reads must explicitly select `--method GET`.
- **D-08:** Bind retained data to repository, run ID, attempt, event, branch, source SHA, workflow identity, job ID/name, required-check map, expected workload, literal outcome, timestamps, runtime/runner-image identity and cache outcome. Save source hashes and a manifest. Verify artifact origin from the producing run; a PR-authored artifact name or manifest cannot establish its own authority. Do not capture secrets or execute untrusted record text.
- **D-09:** Before acquisition, freeze a UTC cutoff. Take at most the latest **100 CI runs per event within the preceding 30 days**. Paginate to that fixed cap and disclose API total count and capped/exhausted status. This is a bounded snapshot, which may cover less than a month.
- **D-10:** Each acquisition pass stops at **600 HTTP requests or 60 minutes**, including pages, retries and artifact retrieval. Check the REST core budget before collection, stop at 250 or fewer remaining, and honor GitHub's reset/retry time on 403/429. One owner watches each run, with the repository's 60-second watcher interval. A transient read may be retried once within the budget. Retain interruptions and unavailable/expired inputs as durable diagnostics; do not extend the window to improve results.

### Native test timing and ranking

- **D-11:** Use a small opt-in, test-only ExUnit timing formatter and Playwright's built-in JSON reporter alongside existing human-readable reports. Add no dependency. Preserve the single `MIX_ENV=test mix ci` library owner, five isolated browser seams, `workers: 1`, `fullyParallel: false`, `retries: 0`, Sandbox ownership and useful test selection.
- **D-12:** Record completed test identity, result, duration and duration unit; Playwright records also identify project, seam and retry. Preserve skipped/excluded counts and report completeness. Output failure or partial data cannot turn into zero-cost entries or a green test result; report validation must preserve the original test exit status. Separate shared fixture/app boot/cache/setup and suite elapsed time from summed individual test time.
- **D-13:** Use identical timing instrumentation in both comparison conditions and account for its overhead. ExUnit `--slowest` is a local diagnostic, not this baseline: it enables trace behavior that changes scheduling and timeout conditions.
- **D-14:** Rank both critical-path contributor wait and summed runner cost. Break out setup, cache restore/download, compilation, database/app startup and test execution when measured. Archived timings and configured timeouts are leads, never current runtime measurements. Do not restore the obsolete two-shard library arrangement merely to measure it.

### Fixed later comparison

- **D-15:** Fix **20 matched pre/post pairs**, totaling 40 primary invocation families, before optimization. Freeze the exact baseline code/workflow identity after Phase 252 instrumentation and record the later candidate identity as the treatment. Match full PR workload, runner class and cache conditions; freeze cache-stratum allocation from the measured baseline before optimization. Record application/workload and workflow revisions separately rather than claiming an identical full repository SHA across a workflow change.
- **D-16:** Run the two code revisions within one predeclared **48-hour comparison window once both are available**. Record runner-image drift and incompatible conditions instead of pooling them silently. The planner can choose scoped, safe, non-publishing PR/evidence seams; manual-only dispatch timing does not replace actual PR wait.
- **D-17:** Do not replace failed, cancelled or non-comparable pairs to improve the numbers. One independently diagnosed infrastructure-only retry may stay inside its original family with every outcome/time/cost retained; test retries remain zero. Incomplete comparable successful pairs yield an insufficient-data result, not a pass.
- **D-18:** Median uses the middle value, averaging the two middle values for even samples. Empirical p95 uses nearest rank `ceil(0.95 * n)`. State that 20 pairs give a fragile tail estimate, not a population guarantee. Retain per-pair measurements, all outcome frequencies and family runner costs. Compare successful equivalent-workload timings while separately disclosing failures, cancellations and reruns. Compare total runner time over the same workload/count/strata and report its distribution. Target misses and unproved non-increase remain miss/unknown results; no favorable-window extension.

### Current failures and contributor output

- **D-19:** Choose at most **three current recurring failure signatures** after reading retained logs/reports. Begin bounded diagnostics with at most four newest failed families per event, twelve total. Separate test/application failure, infrastructure failure, superseded cancellation, expected skip, unexpected skip and missing job. A red run or a historical todo alone does not establish a flake.
- **D-20:** If adequate diagnostics identify no current flake, state that and define repeated isolation/readiness checks for Phase 253. Missing or expired diagnostics mean unknown, not no flake. The historical admin-eval WebKit registration recurrence is a lead already owned by Phase 253; it is not a proven current defect.
- **D-21:** Produce a short ranked report with source links, commands for offline replay/local timing and concrete limitations. Keep contributor instructions focused on reproducing results and failures. No reporting dashboard or product UI redesign.

### Agent's Discretion

Choose internal schema/helper/file organization, the narrow test-only formatter implementation, exact deterministic completeness checks, safe evidence storage and scoped comparison mechanics. Use official docs and current source to resolve these details without reopening broad option menus. The above population, endpoint, budget, sample, percentile, dependency and truth rules are locked. If a required source is unavailable, retain a concrete diagnostic and proceed with independent work; do not claim missing measurements passed.

### Folded Todos

No new todo is promoted into Phase 252. The approved milestone already links admin-eval recurrence to Phase 253. The old timing-machinery todo is a diagnostic lead with existing Phase 241 ownership, not authority to revive its historical topology or mark it resolved here.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope, goals and operating rules

- `.planning/ROADMAP.md` — Phase 252 criteria and Phase 253–255 boundaries.
- `.planning/REQUIREMENTS.md` — CIMEAS-01/02 and unchanged milestone targets.
- `.planning/PROJECT.md` — authentication library vision, contributor experience and scope.
- `.planning/METHODOLOGY.md` — automation, exact source identity, decisive defaults and evidence feasibility.
- `AGENTS.md` — plain English, deterministic verification, write-ahead preservation, routing and API limits.
- `MAINTAINING.md` — contributor commands and required checks; reconfirm live rules during execution.

### Current implementation seams

- `scripts/ci/ci-run-metrics.sh` and `scripts/ci/ci-run-metrics.test.sh` — collection, calculation and hermetic tests.
- `.github/workflows/ci.yml` — current events, jobs, dependencies, caches, skip conditions and check owners.
- `.github/actions/example-playwright-boot/action.yml` — shared boot and cache behavior.
- `.github/ci-skip-manifest.tsv` — recorded expected skips; compare to actual current workflow.
- `mix.exs`, `test/test_helper.exs`, `test/support/postgres_case.ex` — contributor gate, current test selection and database ownership.
- `test/example/priv/playwright/playwright.config.ts` — reporters, project isolation, scheduling and zero retries.

### Project research and historical leads

- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — CI security, reproducibility and contributor simplicity; its Stripe/release examples do not expand this phase.
- `prompts/elixir-opensource-libs-best-practices-deep-research.md`, `prompts/elixir-best-practices-deep-research.md`, `prompts/ecto-best-practices-deep-research.md` — native boundaries, lean dependencies and test ownership.
- `prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md` — developers need approachable local reproduction and reliable library behavior.
- `.planning/todos/pending/2026-09-15-test-01-02-timing-machinery-orphaned.md` — historical timing regression; inspect present source rather than restoring old claims.
- `.planning/todos/pending/2026-09-15-admin-eval-webkit-registration-flake-recurrence.md` — Phase 253 lead requiring current evidence.
- `.planning/todos/pending/2026-09-19-example-playwright-smoke-manifest-step-gate-inaccuracy.md` — aggregator/skip distinction to diagnose, without expanding Phase 252 into gate repair.
- `.planning/phases/252-measure-current-ci/252-DISCUSSION-RECORD.json` and `.planning/phases/252-measure-current-ci/discussion-sources/manifest.json` — approval, discovery provenance and raw source identities; discovery is not phase acceptance.

### Official external references

- [GitHub workflow runs](https://docs.github.com/en/rest/actions/workflow-runs), [workflow jobs](https://docs.github.com/en/rest/actions/workflow-jobs), [check runs](https://docs.github.com/en/rest/checks/runs) — attempts, timestamps and job/step source fields.
- [ExUnit 1.18.4 configuration](https://hexdocs.pm/ex_unit/1.18.4/ExUnit.html), [its source](https://github.com/elixir-lang/elixir/blob/v1.18.4/lib/ex_unit/lib/ex_unit.ex), [Mix test](https://hexdocs.pm/mix/1.18/Mix.Tasks.Test.html) — timing fields and scheduling effects. Reconfirm against CI's actual pinned toolchain before implementation.
- [Ecto Sandbox](https://ecto-sql.hexdocs.pm/3.12.0/Ecto.Adapters.SQL.Sandbox.html) — ownership and async/shared-state constraints.
- [Playwright reporters](https://playwright.dev/docs/test-reporters), [test results](https://playwright.dev/docs/api/class-testresult), [fixtures](https://playwright.dev/docs/test-fixtures) — built-in JSON, duration/status/retry and fixture lifecycle.
- [NIST percentiles](https://www.itl.nist.gov/div898/handbook/prc/section2/prc262.htm) — order-statistic context; the chosen empirical method and small-sample limits are project decisions.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- The metrics script and self-test are the existing collection/calculation seam. Its default latest-40 mixed-event query filters afterward and lacks the revision/attempt/cache/test detail this phase needs. PR source-page mode is more structured but does not cover every population or p95.
- Current CI has one non-matrix `library_tests_shard` running `mix ci`; the old ExUnit timing formatter is absent. Existing archived probes are research leads, not executable current infrastructure.
- Five browser seams already own separate app/database/port state. Shared boot exposes cache behavior; OS browser dependencies still require installation on a browser-cache hit.
- Playwright list/HTML output can coexist with built-in JSON. Diagnostic artifacts have limited retention, so save usable current source data promptly and disclose expiry.

### Established Patterns

- PR concurrency cancels superseded runs. Docs-only bodies can intentionally skip while aggregate checks succeed. Keep these distinct from missing execution and current test defects.
- Required contexts differ from internal `ci-gate` and optional trailing jobs. Whole-run `updatedAt - createdAt` is not the required-result endpoint.
- PostgreSQL Sandbox ownership, one browser worker per invocation and zero retries protect test state. Measurement must not change these conditions.

### Integration Points

- Existing metrics CLI plus retained raw GitHub inputs and offline replay.
- Test-only ExUnit event output from the ordinary contributor/CI path.
- Built-in Playwright JSON and retained shard artifacts.
- Current workflow step/cache/runtime records and a concise ranked report.
</code_context>

<specifics>
## Specific Ideas

- User requests broad, relevant, adversarial research followed by one coherent recommendation set. They prefer a small copied helper over an unnecessary dependency, and plain English over abstract evidence terminology.
- Natural records are representative but confounded by workload/cache/runner mix; controlled-only dispatches miss real PR gate waiting. Use natural diagnosis plus a bounded matched PR comparison.
- Discovery captured 100 PR, 81 main-push and 31 scheduled records since 2026-09-12 UTC. A corrected explicit-GET probe reports 264 PR records, so the PR sample is capped. These counts prove input availability, not completeness, a flake or a phase baseline.
- Representative PR run [38144377407](https://github.com/szTheory/sigra/actions/runs/38144377407), source `40e0a7b9fa6c31953e4c1dc3e2cced41f77071d8`, contains five required contexts and five browser seams. Its 459-second admin-behavior job is one investigation lead, not a representative ranking.
- Initial parameterized API calls omitted explicit GET and returned 404; a corrected capped GET succeeded. Do not carry that request mistake forward as an API-access blocker.
</specifics>

<deferred>
## Deferred Ideas

- Current flaky-test fixes and required-gate fault injection: Phase 253.
- Job splitting, cache optimization, redundant-check removal or changed scheduling: Phase 254 only when current measurements support the choice and useful coverage remains proved.
- Final local reproduction guidance and complete before/after report: Phase 255.
- Product UI, public API/auth changes, reporting services, broad upgrades, paid runners, package release and historical release-proof recovery: outside this milestone.
- Missing 1.6 upgrade guidance remains its separate todo.

### Reviewed Todos (not folded)

- Orphaned timing machinery: inspect current measurements; preserve its existing ownership and historical disposition.
- Admin-eval WebKit recurrence: already linked to Phase 253; confirm against current diagnostics.
- Skip-manifest aggregator discrepancy: measurement must describe actual skips; repairing its guard is not added to Phase 252.
- Other keyword-only todo matches do not belong to current CI measurement and remain unchanged.
</deferred>

---

*Phase: 252-measure-current-ci*
*Context gathered and confirmed: 2026-10-12*
