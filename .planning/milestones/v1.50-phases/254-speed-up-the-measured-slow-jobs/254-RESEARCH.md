# Phase 254: Speed Up the Measured Slow Jobs - Research

**Researched:** 2026-10-23  
**Domain:** Elixir/Mix CI preparation, Playwright browser-test setup, GitHub Actions measurement and comparison  
**Confidence:** HIGH for repository seams and fixed comparison contract; MEDIUM for optimization effects, which remain unmeasured

<user_constraints>
## User Constraints (from CONTEXT.md)

The following locked decisions, discretion and deferred scope are copied verbatim from `.planning/phases/254-speed-up-the-measured-slow-jobs/254-CONTEXT.md` (`## Implementation Decisions`, `## Agent's Discretion`, and `## Deferred Ideas`). [VERIFIED: `254-CONTEXT.md` lines 20-106 — the text below retains the phase's D-01 through D-21 decisions and their exact values.]

### Phase Boundary
Deliver CISPEED-01 and CISPEED-02: required full-PR results at least 20% sooner by median, with non-increasing empirical p95 wait and total runner time for equivalent work. Target the measured Phase 252 costs and retain Phase 253 reliability and gate behavior. Contributors need a faster accurate answer; maintainers need unchanged useful coverage, bounded runner cost, and reproducible measurements.

No public API/authentication change, generated-host feature, UI redesign, package release, paid runner change, broad dependency upgrade, or unrelated backlog cleanup. Phase 255 owns the final contributor guidance and final replay/report presentation. Phase 254 must retain the real comparison inputs and its own acceptance calculation. [VERIFIED: `254-CONTEXT.md` lines 9-18 — exact phase boundary copied.]

### Locked Decisions

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

### Folded Todos
None. The per-shard database todo describes prior implemented isolation; it is a lead for measured rebalancing, not a new migration. Old unit-smoke/manifest concerns are represented by current Phase 253 controls. Other keyword matches do not add scope or close backlog items.

### the agent's Discretion
Choose the small fixture/helper shape, internal command timing and matched scheduling mechanics within these boundaries. Select the smallest measured bundle that can plausibly improve both bottlenecks and retain runner-cost headroom. No further broad option menu is needed. Escalate only an actual contract/security change or a baseline/cache problem automation cannot resolve within existing authority.

### Deferred Ideas (OUT OF SCOPE)
- Final contributor runbook and final comparison-report presentation: Phase 255.
- More shards/workers, prebuilt images, broad cache redesign or transport changes: not selected; reconsider only if narrow measurements establish necessity without changing phase constraints.
- UI/auth/public API work, dependency upgrades, paid runners, releases and old release-record recovery: out of scope.
- Reviewed todos remain unchanged; no unrelated pending item was folded in or closed.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CISPEED-01 | Contributors receive the required PR CI result at least 20% faster by median elapsed time than the newly captured baseline, using a comparison method fixed before optimization. | Existing Phase 252 contract and `ci-run-metrics.sh --evaluate-comparison`; optimize measured critical-path setup/browser work and preserve exact matched workload, identities, cache and image conditions. |
| CISPEED-02 | The same comparison shows no increase in total runner time per comparable PR or in the 95th-percentile wait for the required PR CI result. | Existing comparison evaluator calculates median, nearest-rank p95 and runner seconds; tighten failure/retry cost accounting and ensure all five required browser owners and the library owner remain equivalent. |
</phase_requirements>

## Summary

**Primary recommendation:** Keep the existing five serial, isolated browser jobs and library `mix ci` owner. Implement only measured preparation reductions: opt-in admin-theme login reuse with fresh per-test contexts, remove redundant invitation login navigation only after helper-level proof, deduplicate BEAM/dependency preparation where the pinned action/alias guarantees it, and test whether composing unchanged Mix preparation tasks reduces startup cost. Add component timings and close the comparison evaluator gaps before any fixed hosted sample is spent. No optimization savings or hosted acceptance result has yet been demonstrated.

The slow-job target is specifically `admin_behavior` and `non_admin_smoke`; Phase 252’s one successful full-PR endpoint is not a population estimate. The preserved source preflight is ready for offline source replay, but it records hosted acceptance as `not_started`, candidate identity unset, and cache/image feasibility still outstanding. The frozen contract requires 20 successful comparable matched pairs within a predeclared 48-hour window. [VERIFIED: `.planning/phases/254-speed-up-the-measured-slow-jobs/254-BASELINE-PREFLIGHT.json` lines 1-32 — quote: `"source_status": "ready"`, `"acceptance_status": "not_started"`, `"hosted_comparison_runs_started": false`]

**Important implementation seam:** `scripts/ci/ci-run-metrics.sh` already validates a 40-family reservation/registration set and computes the target metrics, so do not create another collector. Its evaluator needs targeted extensions: validate frozen balanced/nearby ordering, include all attempt costs (including failed/cancelled families) in runner-cost reporting, and return exact selected product test/project identity plus expected/actual skipped status for before/after comparison. Its current selected-case records permit skipped rows, so a green selection-completeness check alone cannot establish useful coverage. [VERIFIED: `scripts/ci/ci-run-metrics.sh` lines 1850-1922 — quote: `"median_candidate_seconds"`, `"candidate_p95_seconds"`, `"candidate_runner_seconds"`; source inspection also shows runner totals are currently summed over successful pairs only.]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Browser test login reuse and test state | Browser / Client | Database / Storage | Playwright contexts and auth state are per invocation; server/database fixtures remain independent. |
| Example app compile, migration, seed and readiness | API / Backend | CI runner | Composite action `example-playwright-boot` prepares each job’s own app/database and serves the browser lane. |
| Required job identity, execution records and acceptance calculation | CI runner | — | GitHub Actions jobs, artifacts, and the existing metrics/origin-verification scripts own the workflow evidence. |
| Library contributor gate | CI runner | API / Backend | One `Library tests shard` invokes the repository’s `mix ci` alias. |

## Project Constraints (from AGENTS.md)

- Preserve the root project's `sg-*` cascade-layer/BEM design system, Rail Accent assets, Light/Dark/System support, and deterministic Playwright conventions where tests touch the admin UI.
- Keep Playwright/admin tests deterministic: role selectors or stable hooks, LiveView readiness, and no sleeps.
- Within authorized implementation work, use deterministic automated verification; do not treat this research assignment as authority to start hosted runs or unrelated phases.
- Preserve existing dirty planning/evidence files before replacing them; Phase 254's target research file was absent at capture time.
- Keep old Phase 253 recovery history and acceptance budgets intact; ordinary local development failures receive scoped fixes, not a new numbered repair-plan loop.
- For any later CI watch: one watcher per run, 60-second interval, check rate limit before long watch, stop at REST core ≤250, and do not retry 403/429 before reset.

Applicable `test/example/AGENTS.md` constraints: use `mix help` before unfamiliar Mix tasks; prefer existing dependencies and do not add dependencies without need; preserve Phoenix/Playwright conventions and avoid sleeps in tests. [VERIFIED: `test/example/AGENTS.md` lines 4-8, 64-79 — quote: `Read the docs and options before using tasks (by using mix help task_name)` and `Avoid Process.sleep/1 and Process.alive?/1 in tests`.]

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| GitHub Actions `ci.yml` | pinned actions in current workflow | Required PR workflow, five existing browser owners and one library owner | The phase changes measured CI paths and must preserve current required job identities. |
| Elixir/Mix | `.tool-versions` is the source for CI; local environment observed Mix 1.19.5 / OTP 28 | Example app preparation and library `mix ci` | Existing task aliases and build/test paths own preparation and library checks. |
| Playwright Test | CI config pins browser cache key/version 1.59.1; repo package range is broader | Serial isolated browser execution and native reports | Existing config and report guards already define browser projects and zero-retry behavior. |
| PostgreSQL | CI service image `postgres:15` | Independent job database and example app persistence | Each browser matrix entry owns a separate database. |

**Quoted in-repo values:** `.github/actions/example-playwright-boot/action.yml` contains `uses: erlef/setup-beam@54075bcc5e249e4758d363f27d099f55d843f124 # v1.24.1` (lines 61-66), and `with: version-file: .tool-versions` / `version-type: strict`. `test/example/priv/playwright/playwright.config.ts` contains `fullyParallel: false`, `workers: 1`, and `retries: 0` (lines 75-81). `mix.exs` declares `ci: [` followed by `"format --check-formatted"`, `"deps.get --check-locked"`, `"deps.unlock --check-unused"`, and `"compile --warnings-as-errors"` (lines 149-157). [VERIFIED: cited source lines; values quoted verbatim.]

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `scripts/ci/ci-playwright-report.mjs` | Native Playwright JSON parsing and timing metadata | Keep the same reporter identity on both comparison paths. |
| `scripts/ci/ci-browser-records.mjs` | Selected product test/project record and seam execution verification | Extend existing records for exact identity/status comparison; do not build a parallel evidence framework. |
| `scripts/ci/ci-hosted-gate-verify.py` | Independent required-gate and origin verifier | Preserve Phase 253 readiness, failure, cancellation, missing-job and unexpected-skip controls. |
| `scripts/ci/ci-run-metrics.sh` | Collection, source replay, run registration and fixed comparison evaluation | Reuse for existing snapshots and acceptance; extend its missing comparison mechanics narrowly. |

No package install is called for by the decisions, so no package legitimacy audit is applicable. `@playwright/test` already exists in `test/example/priv/playwright/package.json`; do not upgrade it in this phase.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Existing opt-in fixture and isolated serial jobs | Setup project and global project storage state | Can shorten repeated logins but adds execution identities/filter dependencies and risks giving unrelated tests authenticated state; only select if fixture cannot meet focused-run requirements. |
| Existing runtime/port cache and `npm ci` | Shared compiled cache, broad cache redesign, prebuilt image | Larger trust and compatibility surface; explicitly out of scope absent narrow measured proof. |
| One shared Mix preparation command | Separate shell invocations | Could save VM startup overhead, but must verify task ordering, failure propagation, cold/warm behavior, and unchanged environment. No savings assumed. |

## Architecture Patterns

### System Architecture Diagram

```text
PR event + frozen source/workflow identity
                  |
           required CI workflow
        /         |          \
 library mix ci  five isolated browser jobs   required-gate checks
                      |                       (names/statuses retained)
       setup toolchain/cache/DB/browser
                      |
       boot app + readiness + route warming
                      |
       selected Playwright cases/projects
                      |
       native reports + execution records
                      |
       collector + origin verifier + frozen reservations
                      |
          paired comparison calculation
```

### Recommended Project Structure

No new package or service. Keep changes within existing seams:

```text
.github/workflows/ci.yml                         # narrow workflow steps and timing metadata
.github/actions/example-playwright-boot/action.yml # measured setup/task composition
test/example/priv/playwright/playwright.config.ts # opt-in fixture/project only if needed
test/example/priv/playwright/tests/*.spec.ts       # eligible browser cases and helper proof
scripts/ci/ci-browser-records.mjs                  # exact selection/status identity
scripts/ci/ci-run-metrics.sh                       # matched schedule, attempt cost and metrics
scripts/ci/*comparison*.test.*                     # regression checks for comparison contract
```

### Pattern 1: Narrow authenticated test fixture

**What:** Generate a fresh admin test login for the one isolated `admin_behavior` invocation, then reuse its browser storage only for eligible admin-theme presentation/navigation tests. Continue creating a fresh browser context for each product case. Keep real auth lifecycle cases on anonymous fresh state and backend mutations in explicit test preconditions. [CITED: pinned Playwright auth docs; VERIFIED: `playwright.config.ts` lines 75-81 quote `fullyParallel: false`, `workers: 1`, `retries: 0`.]

**When to use:** Only cases whose subject is admin presentation/navigation and whose expected backend state is set/reset independently. Preserve individual-test and whole-file execution on fresh CI database state.

**Source:** Current code precedent is `test/example/priv/playwright/tests/admin-design.setup.ts`; pinned Playwright auth guidance explains that state files can impersonate a test user and warns against sharing state when tests mutate server state. [CITED: https://github.com/microsoft/playwright/blob/v1.59.1/docs/src/auth.md]

```ts
// Design constraint, not a proposal to configure global project state:
// prepare invocation-local auth once; let each test get a fresh context;
// keep auth output under ignored test-results and out of uploaded artifacts.
```

### Pattern 2: Same-workload comparison with explicit component timing

**What:** Preserve identical measurement identities on both paths. Capture named durations for setup-beam/toolchain, cache restore, Mix tasks, npm/browser work, readiness and route warming; calculate acceptance from actual required-result endpoint and all runner attempts.

**When to use:** All candidate-vs-frozen-baseline comparison runs. Existing outer-step regex categories are not sufficiently precise to claim component savings.

**Existing commands:** The baseline record documents these source-replay commands; they are present commands, not new CLI syntax:

```sh
bash scripts/ci/ci-run-metrics.sh --replay --source-bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --format json
bash scripts/ci/ci-run-metrics.sh --verify-baseline --source-bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --baseline .planning/phases/252-measure-current-ci/252-BASELINE.json
```

`ci-run-metrics.sh` also has existing `--register-comparison-run` and `--evaluate-comparison` branches. The latter requires an unchanged contract, before/after replay directories and registration evidence; implementation planning should use its current parser and workflow, not invent a new command interface. [VERIFIED: `scripts/ci/ci-run-metrics.sh` lines 1091-1122, 1823-1926 — quote: `--evaluate-comparison requires --contract and extracted --before-bundle/--after-bundle directories`.]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PR source and run provenance | A new collector or synthetic timing input | `ci-run-metrics.sh`, frozen source bundle, reservation ledger and `ci-hosted-gate-verify.py` | Existing code binds run IDs, PR head, workflow path, source SHA and append-only registration chain. |
| Playwright product selection | Count-only coverage records or replacement reporter | `ci-browser-records.mjs` plus native Playwright JSON | Existing records bind spec/project selection and test IDs; add exact before/after status parity there. |
| Browser platform setup | Assume cached browser binaries include OS packages | Existing `playwright install-deps`/`install --with-deps` branch and retained `npm ci` | Browser cache and npm cache do not replace system libraries or materialized `node_modules`. [CITED: https://playwright.dev/docs/ci#caching-browsers] |
| Auth storage | Global storage state or cached credential files | Invocation-local, ignored auth output with per-test contexts | Auth state contains impersonation-capable cookies/headers. Never cache or upload it. [CITED: https://github.com/microsoft/playwright/blob/v1.59.1/docs/src/auth.md] |
| Percentiles and acceptance verdict | New benchmark math or median of pair ratios | Current `ci-run-metrics.sh --evaluate-comparison` with targeted corrections | It already defines ordinary median, nearest-rank p95 and thresholds from contract values. |

**Key insight:** The likely waste is repeated preparation on parallel critical-path browser jobs. Improvements must cut wall-clock critical path without multiplying runner setup cost or relaxing coverage. A technically faster test lane that weakens useful assertions or changes required names is not an acceptable result.

## Common Pitfalls

### Pitfall 1: Treating setup buckets as component profiles
**What goes wrong:** A broad workflow-step bucket is reported as time spent compiling or starting browsers.  
**Why it happens:** Baseline grouping classifies outer step names, and the browser “boot” bucket contains multiple preparations.  
**How to avoid:** Add narrow timing around the preparation subcommands; keep instrumentation identical in both paths and include its overhead.  
**Warning signs:** Summed step labels disagree with job wall time or a short test bucket is mistaken for total browser execution.

### Pitfall 2: Reusing browser auth while backend state is not reset
**What goes wrong:** A test sees another test's organization, branding, or lockout state despite a new browser context.  
**Why it happens:** A new Playwright context isolates browser storage, not the job database.  
**How to avoid:** Keep real lifecycle/auth tests fresh; supply explicit DB preconditions for reused auth cases; isolate lockout target and anonymous cases; keep the three browser jobs' databases/auth fresh.  
**Warning signs:** Test passes in suite order but fails alone, or a System theme/default assertion changes after branding mutation.

### Pitfall 3: Cache hits are not portable or equivalent by default
**What goes wrong:** “Warm cache” is assumed for both conditions when one PR can restore only a sibling-inaccessible merge-ref cache, or a partial fallback is called exact.  
**Why it happens:** GitHub scopes PR caches to `refs/pull/.../merge`; cache access differs by branch and fallback restore keys. The frozen baseline's historical runner image may no longer be available. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching]  
**How to avoid:** Predeclare actual cache preparation, record exact hits versus fallback, verify actual runner image compatibility before comparison families, and stop if equivalent conditions cannot be arranged within the fixed budget.  
**Warning signs:** Cache setup uses an unverified warm-up assumption, candidate has different image or dependency cache outcome, or an extra warm-up consumes acceptance allowance.

### Pitfall 4: Reporting a pass with partial useful coverage
**What goes wrong:** Product tests newly skipped or excluded are hidden by unchanged totals or a different set of tests with the same count. [VERIFIED: `scripts/ci/ci-browser-records.mjs` lines 133-138 — quote: `(row.retry === 0 && row.result === 'passed') || (row.retry === null && row.result === 'skipped')`.]  
**Why it happens:** Current native browser guard confirms the selected set but accepts `result: skipped`; counts are not exact identities/status.  
**How to avoid:** Retain before/after normalized rows keyed by project + spec/test identity, compare expected status and actual passed/skipped/excluded state, preserve intentional skip policy, and require a reviewed mapping if ownership changes.  
**Warning signs:** Selection counts match while one project/test is missing, unexpectedly skipped, or assigned elsewhere without an explicit mapping.

### Pitfall 5: Under-counting runner work after failures
**What goes wrong:** Candidate runner total looks better because failed/cancelled jobs or retry costs disappear from its sum.  
**Why it happens:** Current evaluator calculates runner totals from successful comparable pairs only, while the locked rule counts actual execution across attempts and requires outcomes retained.  
**How to avoid:** Report each family/attempt outcome and actual seconds first; keep incomplete success samples as `insufficient_data`, and never coerce missing job costs to zero.  
**Warning signs:** Runner cost totals differ from the sum of captured attempt job records.

### Pitfall 6: Updating a PR during the registered family window
**What goes wrong:** GitHub cancels superseded runs, breaking fixed pair identities.  
**Why it happens:** Current CI workflow cancels same-PR runs when another run supersedes it. [CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency]  
**How to avoid:** Freeze candidate commit and all 40 reservations/order first; execute without updating its PR; preserve cancellations and don't replace families.  
**Warning signs:** Registered source SHA differs from PR head, run is cancelled, or collection dates exceed frozen window.

### Pitfall 7: Treating the native report as final required-result wait
**What goes wrong:** A job end time or total workflow completion is used instead of the agreed required-check endpoint.  
**Why it happens:** Test reports and job durations are available earlier than the last required check.  
**How to avoid:** Keep the contract endpoint: last successful completion of all five currently enforced required contexts. Keep runner time and wait time as separate measures. [VERIFIED: `252-COMPARISON-CONTRACT.json` lines 113-124 — quote: `"required_result_wait_endpoint": "last successful completion of all five currently enforced required contexts, not workflow close"`.]

## Code Examples

### Existing example app setup sequence

`example-playwright-boot/action.yml` currently sequences the work below; any single-`mix do` experiment must preserve task ordering and environment, and the server still starts separately. [VERIFIED: `.github/actions/example-playwright-boot/action.yml` lines 86-120 — quote: `mix deps.get`, `mix compile --warnings-as-errors`, `mix ecto.create`, `mix ecto.migrate`, `mix run priv/repo/seeds.exs`, `npm ci`.]

```sh
mix deps.get
mix compile --warnings-as-errors
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
npm ci
```

`mix help do` on installed Mix 1.19.5 states: “Executes the tasks separated by `+`, aborting if any task errors”; it also says a task generally runs only once per invocation. This confirms ordered composition and failure propagation for the candidate experiment. [VERIFIED: local Mix 1.19.5 `mix help do`; same versioned docs URL: https://hexdocs.pm/mix/1.19.5/Mix.Tasks.Do.html]

### Existing browser isolation contract

```ts
fullyParallel: false,
workers: 1,
retries: 0,
```

Keep that contract while optimizing fixture setup. Playwright's CI guide recommends one worker for stability/reproducibility and requires browser dependencies to remain installed; its browser-cache guidance notes Linux OS dependencies are not cacheable. [CITED: https://playwright.dev/docs/ci#workers; https://playwright.dev/docs/ci#caching-browsers]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Login afresh in each eligible presentation case | Invocation-local auth prepared once, browser context still fresh per test | Proposed for Phase 254, not implemented | Could save repeated navigations while protecting per-test browser isolation; benefit must be measured. |
| Workflow outer-step durations as “component profiling” | Measure preparation substeps, retain full-path timing for acceptance | Required by Phase 254 D-11 | Avoids overclaiming savings from coarse categories. |
| Cache binary presence as full browser readiness | Cache binaries only; still install Linux browser OS dependencies and `npm ci` | Current Playwright CI docs | Avoids cache hits that still fail on missing system packages or node_modules. |
| Count equality as coverage equality | Exact test/project and skip/exclusion parity | Required by D-20 | Prevents changed or skipped work hiding behind equal totals. |

**Deprecated/outdated:** No dependency/API upgrade is approved. Do not use newer Playwright APIs absent from pinned v1.59.1 docs/config.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir/Mix + OTP | focused local Mix verification | ✓ | Mix 1.19.5 / OTP 28 | Hosted pinned `setup-beam` for exact CI-source runs |
| Node/npm | Playwright reports and browser tools | ✓ | Node 26.10.0 / npm 11.19.1; CI uses Node 20 | Use CI's pinned Node 20 for comparable browser execution |
| Playwright node_modules | local browser tests | ✓ directory present | CLI version probe could not run because npm cache access returned `EPERM` | CI runs locked `npm ci` |
| Playwright browser binaries | local browser tests | ✗ no `~/.cache/ms-playwright` directory found | — | CI action installs browsers and Linux system dependencies |
| PostgreSQL | local browser/app checks | ✓ accepting on `/tmp:5432` | client `psql` 14.17; service version is CI-pinned `postgres:15` | GitHub job-local PostgreSQL service |
| Docker | optional local container setup | ✓ | 29.5.2 | GitHub job service |
| GitHub CLI | hosted evidence acquisition | ✓ | 2.101.0; auth/permissions not established here | Existing scoped collector; report blocked if required auth/cache/image preflight cannot be satisfied |

This workstation is not an equivalent acceptance runner: its Node version differs from CI Node 20 and local Playwright browsers are absent. A local `npx playwright --version` probe was blocked by npm cache ownership/permission error (`EPERM`); do not repair global cache ownership as part of this phase. No tests or hosted runs were executed during research.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Shell contract/self-tests, Node.js `node:test`, Python `unittest`, Playwright Test; existing Mix `ci` alias |
| Config file | `test/example/priv/playwright/playwright.config.ts`; root `.github/workflows/ci.yml` |
| Focused comparison regression command | `bash scripts/ci/ci-run-metrics-comparison.test.sh` |
| Selected-case record test | `node --test scripts/ci/ci-browser-records.test.mjs` |
| Required-gate verifier test | `python3 scripts/ci/ci-hosted-gate-verify.test.py` |
| Full phase acceptance | Existing recorded `ci-run-metrics.sh --evaluate-comparison` using the frozen baseline and 20 candidate pairs; not runnable until candidate/window/cache readiness are frozen. |

No new package or framework install is needed. `workflow.nyquist_validation` is explicitly `true`, so retain this architecture in planning. [VERIFIED: `.planning/config.json` line 21 — quote: `"nyquist_validation": true`.]

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|------------|-------------------|--------------|
| CISPEED-01 | Fixed comparison returns median ≤80% baseline from 20 valid matched pairs | Regression + hosted evidence | `bash scripts/ci/ci-run-metrics-comparison.test.sh`; existing `ci-run-metrics.sh --evaluate-comparison` after freeze | ✅ evaluator/test exist; add cases for schedule order and insufficient outcomes |
| CISPEED-02 | Candidate p95 and total actual runner seconds do not exceed baseline while retaining useful test coverage | Regression + workflow contract + hosted evidence | `node --test scripts/ci/ci-browser-records.test.mjs`; `bash scripts/ci/ci-run-metrics-comparison.test.sh` | ✅ records/evaluator exist; add exact before/after case-status and all-attempt-cost assertions |

### Wave 0 Gaps

- [ ] Extend comparison fixtures to prove the balanced near-pair schedule is frozen, order-compliant, and not replaceable.
- [ ] Add comparison fixtures where failed/cancelled jobs and diagnosed retries contribute actual attempt runner seconds; verify `<20` successful pairs yields `insufficient_data`, never pass/zero.
- [ ] Extend browser-record acceptance to compare exact test/project identities and expected/actual skipped/excluded status, retaining intentional skips and emitting a before/after ownership map if rebalanced.
- [ ] Add focused test coverage for eligible admin-theme runs individually and by file, anonymous lockout behavior, clean per-test context, and backend-state preconditions.
- [ ] Add tests for the Mix preparation candidate: cold and warm execution, migrations/seeds, preserved env/database/port, and early failure propagation. No command-shape assumption until official Mix docs and local experiment confirm it.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes | Keep actual registration, confirmation, session, invitation and lockout assertions in behavior suites; reuse test auth only for eligible presentation cases. |
| V3 Session Management | Yes | Auth state stays invocation/job/database scoped; fresh browser contexts per test; never share/cache/upload auth files. |
| V4 Access Control | Yes | Preserve authorization and role lifecycle cases; no global authenticated projects or public test endpoint. |
| V5 Input Validation | Yes | Preserve existing tests' role-based locators/stable hooks and application validation assertions; avoid introducing shell interpolation from workflow inputs. |
| V6 Cryptography | No new crypto boundary | No cryptographic implementation or dependency change in this phase. |

### Known Threat Patterns for GitHub Actions + Playwright

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Auth storage leaks through cache or artifact | Information disclosure / elevation | Temporary ignored output; no upload/cache; use fresh per-job state. Playwright warns state files can impersonate the account. |
| Untrusted cache contents execute in privileged workflow | Tampering / elevation | Keep current runtime/env/port cache partition; no cache trust expansion; verify source and exact cache outcome. GitHub warns cache contents are not signed or verified. |
| Workflow run accidentally bypasses required checks | Tampering / denial of service | Retain five required browser owners, library owner, and Phase 253 independent origin/failure/missing/unexpected-skip verification. |
| Shell injection from user-controlled workflow context | Tampering | Keep interpolated contexts in `env:` and quote shell variables; avoid direct expressions inside shell code. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Invocation-local auth fixture can reduce repeated `admin-theme` preparation without changing meaningful assertions. | Architecture Patterns | No useful savings; fixture complexity should be removed if timing does not improve. |
| A2 | A single Mix task invocation may reduce startup overhead in the existing composite action. | Code Examples | May not improve timing or may alter semantics; keep separate commands unless cold/warm/failure probes show equivalence and benefit. |
| A3 | Existing job report artifacts retain enough product case identity to add exact before/after status parity without another artifact system. | Validation Architecture | If not, extend the current native browser record, but avoid parallel ledgers. |
| A4 | Candidate and baseline can obtain compatible warm cache/image conditions during the fixed comparison window. | Environment Availability | If not, hosted acceptance must remain blocked/insufficient; do not spend families or broaden cache trust. |

## Open Questions

1. **Can the fixed cache allocation be prepared in both PR contexts?** Current contract allocates all-warm strata from one observation; GitHub PR caches are merge-ref scoped, and no runner-side hosted compatibility probe has happened. Implementation can resolve this before freezing the candidate/window using current cache semantics and an explicit bounded prep budget. If not, this is a comparison blocker, not a reason to alter the contract.
2. **Will GitHub provide an equivalent runner image to the saved `ubuntu24` baseline?** The baseline image is historical and the contract requires image compatibility. Verify before acceptance; report the actual drift rule outcome rather than assuming `ubuntu-latest` is equivalent.
3. **Does the existing registration schema encode balanced alternation and run proximity strongly enough?** It binds 40 reserved PR runs and a hash-chained registration ledger, but current evaluator does not verify the user-required balanced order or maximum proximity. Add a simple fixed schedule/proximity validation to existing comparison records; settle a concrete proximity bound during implementation before any run reservation.
4. **Can browser records distinguish intentional skip from newly unexplained skip for exact case/project identities?** The existing selected status comes from Playwright selection JSON and execution JSON. Add targeted fixtures that pin allowed intentional skip policy and prove new skipped/missing rows fail.
5. **Does the repeated login removal preserve helper guarantees?** `registerAndConfirmUser` calls `logInIfNeeded`; prove the subsequent invitation helper sees the authenticated state without navigating back to login before removing duplicate navigation. This is resolvable with a local focused test.

## Sources

### Primary (HIGH confidence)
- `254-CONTEXT.md` — all locked D-01–D-21, discretion, deferred scope and canonical references.
- `252-COMPARISON-CONTRACT.json`, `252-BASELINE.md`, `252-BASELINE.json` — frozen identities, sample size, endpoint, cache allocation, image and metrics limitations.
- `254-BASELINE-PREFLIGHT.json` — local frozen source verification and unstarted hosted acceptance state.
- `253-CONTEXT.md`, `253-VERIFICATION.md`, `253-LEARNINGS.md`, `253-RECOVERY-RESET.md` — retained reliability controls and bounded-maintenance rules.
- `.github/workflows/ci.yml`; `.github/actions/example-playwright-boot/action.yml`; `mix.exs`; Playwright config/specs; `scripts/ci/ci-run-metrics.sh`, `ci-browser-records.mjs`, `ci-hosted-gate-verify.py` — current implementation seams and exact command/task identities.
- [Pinned Playwright authentication guide](https://github.com/microsoft/playwright/blob/v1.59.1/docs/src/auth.md) — context isolation, auth-state handling, setup-project behavior and sensitive state cautions.
- [Pinned Playwright project dependencies](https://github.com/microsoft/playwright/blob/v1.59.1/docs/src/test-projects-js.md#dependencies) — setup-project dependency semantics.
- [Playwright CI browser caching](https://playwright.dev/docs/ci#caching-browsers) — Linux system dependencies are not cacheable and browser caching may not pay off.
- [Pinned setup-beam action input](https://github.com/erlef/setup-beam/blob/54075bcc5e249e4758d363f27d099f55d843f124/action.yml) — pinned action capability is to install Hex/Rebar according to inputs; verify actual defaults at the pinned revision before removing duplicate commands.
- [Mix `do` documentation](https://hexdocs.pm/mix/1.19.5/Mix.Tasks.Do.html) — official task-composition syntax; the exact pinned page could not be retrieved during this session, so task semantics must be confirmed by local `mix help do` and focused tests before adoption.
- [GitHub Actions dependency cache scope](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching) and [workflow concurrency behavior](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency) — cache branch scope and same-PR cancellation semantics.
- [GitHub Actions workflow jobs API](https://docs.github.com/en/rest/actions/workflow-jobs) — job-level timing and attempt records source.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — current repository workflow/config and local source versions read; no package additions proposed.
- Architecture: HIGH — workflow/action/test ownership read directly.
- Pitfalls: HIGH for auth/cache/measurement caveats from primary docs and local contracts; MEDIUM for magnitude of prospective savings.

**Research date:** 2026-10-23  
**Valid until:** 2026-11-22 for local code map; recheck GitHub cache and runner-image availability immediately before collection because hosted behavior changes.
