# Phase 255: Make Failures Reproducible and Report the Result - Research

**Researched:** 2026-10-24  
**Domain:** Elixir/Mix contributor commands, Playwright process diagnostics, GitHub Actions artifacts, offline CI measurement replay  
**Confidence:** HIGH for repository seams and saved observations; MEDIUM for hosted terminal-outcome behavior until an isolated canary runs

## User Constraints

### Locked Decisions

- **D-01:** Preserve the literal `MIX_ENV=test mix ci` entry point, its intended seven ordered legs and one library-suite owner. Keep heavyweight browser setup outside its default execution. Explain its local coverage boundary and link focused companion commands from `CONTRIBUTING.md`; unrestricted `npm test` is not a substitute for a specific CI selection.
- **D-02:** Before claiming parity, observe actual ordinary, scaffold and dep-off test execution with narrow process checks. Current alias text and static contract tests alone cannot prove every receiver ran. A standalone pinned-runtime probe showed that a nested second `mix test` can be skipped with exit 0; this is a concrete lead, not proof that Sigra's scaffold coverage is missing. If the repository reproduction confirms a defect, repair the scoped command path and retain the intended coverage, exclusions, ordering and nonzero failure behavior. Do not weaken old coverage expectations or start a numbered repair loop.
- **D-03:** Document cold-checkout preparation, live PostgreSQL, pinned `phx_new 1.8.8`, `.tool-versions`, the Playwright lockfile and browser/OS prerequisites. Verify required tests are not silently excluded because a prerequisite is absent. Reproduction records identify the actual failed test invocation and its seed; do not promise that `mix ci --seed N` propagates to all receivers. Formatting, dependency and startup failures have commands, not invented random seeds.
- **D-04:** Prefer small shared browser command definitions used by local reproduction and the relevant CI steps where that prevents recurring drift. Preserve exact selected specs/projects, setup dependencies, PR versus non-PR snapshot behavior, selection/execution reports, all five isolated browser jobs, one worker and zero retries. Check actual selected identities, not just total counts. A documentation-only catalog with deterministic drift checks is the fallback if extracting a shared command would materially complicate existing validators. No workflow framework or new dependency is justified.
- **D-05:** Browser reproduction prepares a fresh invocation-owned example database and server under `MIX_ENV=dev`. Set `CI=true` for preparation and the server as well as Playwright so the code reloader stays disabled; keep the compiled and running `PORT` identical. Distinguish example `PG*` settings from library `SIGRA_TEST_PG_*` settings. Reject occupied ports and unowned reset/drop targets; cleanup only processes, databases and directories created by this invocation. Use actual readiness conditions. Explain that macOS can reproduce behavior while Ubuntu/font-sensitive visual parity requires the supported Ubuntu environment; never silently re-record screenshots to make a local run pass.
- **D-06:** Every affected command failure reports the original command or native test identity, a shell-safe focused reproduction, working directory, source revision/dirty state, observed tool versions, relevant non-secret configuration and applicable per-invocation seed. Keep command stdout/stderr independently of test reports so installation, discovery, configuration, server startup and browser-launch failures remain diagnosable. Preserve the primary exit/signal; report later cleanup, capture or reporting failures separately. Never evaluate report text as shell code or print the entire environment.
- **D-07:** Enable `retain-on-failure` at the affected browser invocation boundary, including relevant custom contexts, rather than changing every Playwright consumer globally. Keep retries at zero. Verify a first-attempt assertion failure retains a useful trace and a passing test discards it. Recording still costs time on passing tests: measure/disclose that development overhead and bind it to the final changed source without subtracting estimates or adding it retroactively to the closed comparison. Failure before a browser context exists or hard runner termination can leave no trace; state the exact reason rather than promising an unavailable artifact.
- **D-08:** Retain an explicit invocation-bound diagnostic bundle with command/native output, server log and applicable failure artifacts. Include run, attempt, job/seam, invocation and source identities. Preserve outputs from sequential Playwright invocations before later reporters clear shared directories. Keep the existing bounded seven-day CI retention by default and document retrieval before expiry. Durable final comparison inputs need separate preserved storage; transient Actions artifacts are not that archive.
- **D-09:** Stage intended diagnostics explicitly and exclude authentication storage, unrelated/stale files, credentials and paths escaping the staging root. Use synthetic accounts without production credentials. Test the finished bundle for planted secret sentinels, auth files and escaping symlinks. Traces themselves may contain authentication requests and DOM content; excluding `.auth` does not make arbitrary traces safe. Current hidden-file upload defaults are not evidence of an existing credential leak. Keep auth state temporary and excluded from Git, retained bundles and Pages publication.
- **D-10:** Prove local failure behavior through narrow real-process/browser tests: command failure followed by failing cleanup, startup/discovery failure, initial assertion failure, passing trace disposal, output isolation and exact command/seed reproduction. When hosted upload/terminal behavior changes, plan a small isolated non-publishing canary that retrieves source/run/attempt-bound artifacts for success, failure and actual fixture cancellation. Freeze its own finite invocation/request/time/retry limits before execution; no old allowance is reused. Cancellation/runner loss can prevent final upload; missing files stay missing. Keep expensive boot out of cancellation-resistant recording paths and do not alter required-check names, gate policy or existing failure/skip protections.
- **D-11:** Make replay work from a clean checkout without network access after obtaining the preserved input package. Name an actually accessible evidence ref or exact-byte archive, restore receipt paths safely and verify hashes before calculation. Local ignored raw directories or an unpublished local ref alone are insufficient for another maintainer. Include the contract, registrations, source archive, workload map, captured run/job data and all transitive tool/data dependencies. Preserve original bytes; a missing or altered input produces a concrete diagnostic.
- **D-12:** Pin the replay calculator and its helpers/data separately from the original measured application/workflow. The captured metrics script predates the null-family/failed-cost repair in `d5b7300c809ce7cd474e87aa55fda278b3a09cbc`; current helpers and fallback timing files can otherwise change output. Reuse the existing calculator, cost derivation, archive safety and origin checks. Explain that repaired analysis ran on unchanged saved observations; it was not part of the original measured treatment. Do not overwrite the Phase 252 archive or failed-baseline manifest to make validation look cleaner.
- **D-13:** Validate result fields as well as process status. A successful calculation with exit 0 may correctly return `insufficient_data`; it does not pass performance acceptance. Replay must retain zero successful comparable pairs, null median/p95 values, baseline failure and candidate success, and observed runner costs of 2046 and 1589 seconds. These unequal failed/successful observations do not establish a percentage improvement. Test missing/corrupt inputs, a changed tool dependency, null families and all observed attempt costs. Verify replay leaves inputs unchanged.
- **D-14:** Keep the fixed method: ordinary median; nearest-rank p95 `ceil(0.95*n)`; 20 successful matched pairs under the original workload/cache/runner rules; literal outcomes and rerun costs retained. Report invocation counts, failures, cancellations, preparations/reruns, actual cache/image conditions, unknown overhead and remaining limitations separately. Do not count unused reservations as observations, missing times as zero or missing metadata as proven source divergence. The failed baseline never produced successful-family metadata; explain the evaluator's generic identity/missing-family diagnostics. One materialized candidate's successful origin check does not qualify both measured sides.
- **D-15:** Produce one concise final report with replay commands and machine-readable results, linked from contributor/maintainer guidance as appropriate. Name original baseline/candidate sources, analysis source and later diagnostic changes separately. Distinguish implemented optimizations, demonstrated reliability fixes, actual hosted development coverage and unproved speed targets. Later PR 353/source `8b3c3d8c75152438bb3259c1226b1044da717b3c` passed development CI with 108 browser cases and added zero acceptance samples. The controlled connection reproduction does not prove the missing initiating event in the original hosted trace.
- **D-16:** CIMEAS-03 can establish faithful replay/reporting of an insufficient-data result while CISPEED-01/02 remain open. Keep the original experiment terminal: no replacement samples, renewed window, new benchmark or reused acceptance budget. Any future benchmark needs separately agreed scope and method. This discussion authorizes decisions for planning, not Phase 255 execution or hosted acceptance.
- **D-17:** Prefer small repository-local helpers and existing Bash/Node/Python/Elixir facilities. Add no dependency, dashboard, parallel evidence framework or extra review layer without a demonstrated need. Repair ordinary implementation/test errors through scoped maintenance with meaningful tests, retaining original stopped results. Existing unrelated backlog items remain outside this phase.

### Agent's Discretion

Choose small helper/file boundaries, exact focused command names, internal diagnostics schema and report location. Use primary sources and pinned runtime APIs. Preserve the command/coverage, isolation, original-failure, artifact security, source identity and comparison-truth boundaries above. No further broad option menu is needed.

### Deferred Ideas (OUT OF SCOPE)

No new capability was requested. A future speed benchmark, product changes, broader workflow redesign and missing 1.6 upgrade guidance remain outside Phase 255. Keyword-matched pending todos add no scope and are not closed by this phase.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CIDX-01 | Contributors can run the relevant updated CI checks locally through documented commands that agree with CI, preserving `mix ci`. | Mix aliases and CI receiver map; focused browser lane recipes, controlled local setup and drift checks. |
| CIDX-02 | Failed updated checks report failed identity and reproduction details with retained logs/traces and seed when applicable. | Process outcome capture, Playwright first-failure trace, invocation-bound safe artifact staging and one isolated hosted terminal-outcome canary. |
| CIMEAS-03 | Maintainers can replay final before/after comparison from saved inputs and calculation, disclosing failures, cancellations, reruns, samples and limits. | Exact-source calculator and input package; local refs currently resolve, but accessible distribution must be created/proven. Expected result remains `insufficient_data`. |

## Summary

Use the existing Mix, Bash, Playwright and Python seams. The checked-in Mix alias has seven entries, quoted verbatim here: `ci: ["format --check-formatted", "deps.get --check-locked", "deps.unlock --check-unused", "compile --warnings-as-errors", "test --exclude scaffold", "ci.install_golden", "sigra.dep_off"]` [VERIFIED: `mix.exs:149-157`]. Keep `MIX_ENV=test mix ci` as the entry point; its ordinary, scaffold, and dep-off legs need process-level execution proof because a standalone probe showed nested alias behavior can skip a receiver while exiting 0 [CITED: pinned Elixir 1.19.5 Mix source; Phase 255 context records probe output]. For browser checks, factor only exact existing invocations into reusable definitions if validators remain simple. The current Playwright config contains `workers: 1`, `retries: 0`, and `trace: 'on-first-retry'` [VERIFIED: `test/example/priv/playwright/playwright.config.ts:75-105`]; apply failure retention only to affected invocations and validate the exact locked Playwright 1.59.1 behavior [CITED: Playwright test options].

Diagnostics should wrap the native command at its invocation boundary, preserve stdout/stderr and the original exit/signal, and separately report cleanup/reporting errors. Stage an allowlisted bundle and inspect its final contents for auth state, planted secrets, and escaping symlinks. Playwright's existing zero-retry policy and lockfile version 1.59.1 are constraints; scope `retain-on-failure` to affected invocations and include custom contexts. Do not describe a trace as guaranteed when the browser context never opened or the runner was killed.

The comparison calculation and observations exist, but external distribution is not ready. The two local preservation commits resolve and contain 69/109 receipt-listed paths [VERIFIED: `255-RESEARCH-PREFLIGHT.json`]; remote availability is not established, so planning must make accessible packaging and clean-checkout materialization a deliverable. The saved result quotes: `"baseline_median_seconds": null`, `"baseline_p95_seconds": null`, `"baseline_runner_seconds": 2046.0`, `"candidate_median_seconds": null`, `"candidate_p95_seconds": null`, `"candidate_runner_seconds": 1589.0`, `"comparable_successful_pairs": 0` [VERIFIED: `.planning/execution/254-environment-recovery/MEASUREMENT/RESULT.json:50-59`]. It also records `"performance_verdict": "insufficient_data"` and `"status": "insufficient_data"` [VERIFIED: same file:107-109], with baseline `"conclusion": "failure"` and candidate `"conclusion": "success"` [VERIFIED: same file:68-91]. Replaying those facts is the goal; no renewed benchmark or performance claim is justified.

**Primary recommendation:** plan small shared command/diagnostic helpers, real process and browser failure checks, an isolated hosted upload canary for success/failure/cancellation if terminal reporting changes, and a clean-checkout offline replay from a newly accessible immutable evidence package. Keep analysis source identity separate from measured source identity and assert JSON result fields, not just exit code.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Local Mix CI entry point and receiver ordering | API / Backend (repository command layer) | CI workflow | `mix.exs` owns aliases; the library CI job invokes the alias. |
| Example browser environment preparation | CI / local process orchestration | Database / Storage | A script/action owns app startup and disposable Postgres identity; Playwright drives the live host. |
| Failure logs, trace capture and artifact staging | CI / process orchestration | Browser / Client | Native command outcomes and Playwright context traces are gathered at the invocation boundary. |
| Saved comparison replay and report | Repository analysis tool | Database / Storage (immutable files) | Python/Bash calculator consumes preserved files offline and emits machine-readable result. |

## Standard Stack

### Core

| Library/tool | Version | Purpose | Why standard |
|---|---:|---|---|
| Elixir / Mix | `.tool-versions` pinned; inspect exact values in plan | CI alias and ExUnit receivers | Existing contributor entry point and CI implementation. |
| `@playwright/test` | lockfile 1.59.1 (per context) | Browser selection, projects and traces | Already runs the five isolated example seams; no new dependency. |
| Bash + Python 3 + jq + Node | repository runner requirements | Native process handling, measurement replay, bundle/coverage checks | Existing scripts implement capture, safety validation, result calculation and coverage comparison. |
| PostgreSQL | Local live service | Library tests and example app | Both use real DB state; use distinct configured database names and invocation-owned example DB. |

### Supporting

| Existing seam | Purpose | Planning use |
|---|---|---|
| `scripts/ci/ci-run-metrics.sh` | Snapshot replay, safe archive extraction and comparison evaluation | Reuse; pin source and assert semantic output. |
| `scripts/ci/ci_metrics_security.py` | Origin, archive, receipt, identity and cost checks | Include in transitive analysis bundle. |
| `scripts/ci/ci-browser-records.mjs` | Browser selection/execution identity comparison | Include if native parity is calculated. |
| `test/support/ci_timing_formatter.ex` | ExUnit timing JSON | Preserve as existing timing output; ensure command output remains independently captured. |
| `actions/upload-artifact` in workflow | Temporary hosted diagnostics | Retain bounded seven-day lifetime; this is not durable comparison storage. |

### Alternatives Considered

| Instead of | Could use | Tradeoff |
|---|---|---|
| Shared, small command definitions | Duplicated documented commands plus drift tests | Use fallback only if extraction tangles validators; duplicate invocations can silently drift. |
| Explicit allowlist staging | Upload whole workspace/report folder | Easier but risks stale files, auth state, symlinks or unrelated secrets. |
| Immutable refs/package for replay | Actions artifacts or ignored local directories | Expiring artifacts and workstation-only files cannot support independent clean-checkout replay. |
| Existing helpers | New evidence framework/dependency | Adds maintenance and trust boundaries without need established in current code. |

**Installation:** none. Do not add dependencies in this phase.

## Architecture Patterns

### Recommended Project Structure

Keep project-native boundaries: `scripts/ci/` for small runner/replay helpers, `test/example/priv/playwright/` for browser config and specs, `.github/actions/` for reusable browser boot, `.github/workflows/ci.yml` for job orchestration, `CONTRIBUTING.md` for commands and result/report location, and `.planning/execution/` for immutable replay inputs/results.

### Pattern 1: Preserve command outcome before cleanup

**What:** Capture stdout and stderr as separate files; record command, working directory, source identity, selected test identity/seed if available, exit code or signal; run cleanup and report its failure without replacing the first failure.  
**When:** Every affected local or CI command wrapper.  
**Example (shape, not a new API):** `run command >command.stdout 2>command.stderr; primary_status=$?; cleanup; cleanup_status=$?; emit_record "$primary_status" "$cleanup_status"` with strict quoting and no `eval`. Add `set +e` only around bounded outcome capture and restore strict mode.

### Pattern 2: Own browser resources per invocation

**What:** Allocate/check a free port, unique database and temp output root; prepare and start with consistent env; wait using HTTP/readiness; record process identity; cleanup only owned PID/database/path.  
**When:** Local repro of an existing browser seam.  
**Evidence:** `.github/actions/example-playwright-boot/action.yml`, `test/example/config/dev.exs`, and `playwright.config.ts` are current sources to preserve.

### Pattern 3: Offline replay from immutable receipt paths

**What:** Materialize a named evidence package, reject path traversal/symlink escapes, verify every receipt hash, run the separately pinned calculator and assert status, outcomes, pair count, null metrics and costs. Snapshot input hashes before/after to establish immutability.  
**When:** Final comparison reporting; no GitHub API calls during replay.  
**Must report:** exact baseline, candidate, analysis identities and all observed attempts; never promote evaluator process success to performance acceptance.

### Anti-Patterns to Avoid

- Do not assume Mix nested alias calls executed a second receiver just because the parent command exited 0; prove receiver markers/process invocation.
- Do not change retries, replace readiness with sleeps, broaden selected Playwright specs, or merge five independent database/browser jobs.
- Do not use shell evaluation on generated report content or dump all environment variables into failure artifacts.
- Do not rely on a later step with a success-only condition to upload a failure bundle; test actual terminal branches in hosted CI.
- Do not infer speed from 2046 versus 1589 runner-seconds: these observations have different conclusions and no matched successful pair.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Browser trace creation | Custom browser event logger | Playwright trace recording/retention | Playwright documents trace recording and local viewing [CITED: [Trace Viewer](https://playwright.dev/docs/trace-viewer)]; traces may contain sensitive page/request data, so retain only scoped failure artifacts. |
| Comparison statistics and receipts | New ad-hoc calculator | Existing `ci-run-metrics.sh` and `ci_metrics_security.py` | Existing validation encodes method, identities, archive safety and cost inclusion. |
| Test selection parity | Count-only selection logic | Native selection/execution records and `ci-browser-records.mjs` | Same count can represent different selected tests/projects. |
| CI artifact retention | Custom persistence service | Existing Actions artifact upload for transient diagnostics; scoped immutable package for replay | Keep ephemeral diagnostic and durable evidence lifecycles distinct. |

**Key insight:** The difficult part is preserving identity and truth across process, browser, hosted-run and replay boundaries, not inventing another runner abstraction.

## Common Pitfalls

1. **Nested Mix alias skips a leg.** A standalone pinned Mix probe showed the nested second `mix test` can be skipped with exit 0. Confirm ordinary/scaffold/dep-off receiver execution in the actual repo; a static alias list is not evidence of execution.
2. **Local browser setup collides with a developer service.** Refuse occupied ports and unsafe existing DBs; allocate invocation-owned resources, pin `PORT` for compile/start, set `CI=true` in all app processes, and use readiness probes rather than fixed sleeps.
3. **First failure is hidden by cleanup or report failure.** Store primary status/signal before cleanup; diagnostic/report failure is additional data, not a replacement exit code.
4. **A passing exit code masks an insufficient result.** Validate `performance_verdict`, pair count and expected nulls. `insufficient_data` is a valid replay output and an unproven target.
5. **Trace/bundle leaks sensitive content.** Allowlist staged files, reject symlinks escaping the stage root, and scan planted sentinels/auth files. Traces can contain DOM and auth requests.
6. **Transient artifacts are mistaken for archive.** Seven-day CI artifacts support debugging only; durable source/input package must have clean-checkout access and receipt hashes.
7. **One side's origin proof is mistaken for full pair qualification.** Baseline lacked successful-family metadata; preserve this uncertainty and the literal failure outcome.

## Validation Architecture

Phase tests should be deterministic and narrow; do not execute hosted acceptance or renew any measurement budget as part of implementation verification.

| Requirement/behavior | Test type | Automated check to plan |
|---|---|---|
| `MIX_ENV=test mix ci` receiver parity | Real process | Run instrumented command probes against actual ordinary, scaffold and dep-off receivers; require each expected receiver marker once and preserve nonzero failure. |
| Browser command parity | Contract + real command selection | Compare actual selected test/project identities for each of five CI seams against shared local command definition; test PR/non-PR snapshot selection. |
| Local failure record | Real process | Simulate command failure plus cleanup failure; assert original exit/signal retained, both streams kept, argv safely rendered, seed only where applicable. |
| Browser trace handling | Real browser | First-attempt assertion failure retains trace with zero retries; passing run removes trace; include custom contexts and output isolation. |
| Diagnostic archive safety | Deterministic file fixture | Plant secret sentinel, auth storage, stale output and escaping symlink; assert final bundle includes only explicit safe files. |
| Replay calculator | Clean checkout/offline deterministic replay | Materialize exact package, verify receipt hashes, run pinned calculator with no network, assert expected result fields/costs and unchanged input hashes. Corrupt/missing dependency fixtures fail with concrete diagnostics. |
| Hosted upload/terminal behavior | Finite isolated non-publishing canary | If workflow delivery changes: separately frozen bounded success, injected failure and actual fixture cancellation runs; retrieve and validate run/attempt/source-bound artifacts. No publish secrets; do not cancel a real release. |

Existing tests include `scripts/ci/ci-run-metrics*.test.*`, `scripts/ci/ci-browser-records.test.mjs`, `scripts/ci/ci_metrics_security.py` tests, dep-off harness tests and `test/sigra/planning/ci_timing_formatter_test.exs`. Add cases beside the owner seam; inspect commands/config during planning before asserting complete coverage. The hosted cancellation test must demonstrate an actual cancellation condition, not simulate it only in a unit fixture.

## Security Domain

| ASVS area | Applies | Control for this phase |
|---|---|---|
| V2 Authentication | Yes, test fixture | Synthetic accounts only; no production credentials in command env or archive. |
| V3 Session Management | Yes | Keep browser auth storage temporary and out of Git, artifact bundle and Pages. |
| V4 Access Control | Yes, CI artifacts | Use least-privileged non-publishing canary; explicit allowlist of staged files. |
| V5 Input Validation | Yes | Treat report values as data; shell-quote reproduction commands; validate paths and archive entries. |
| V6 Cryptography | Limited | Do not create custom crypto; use SHA-256 receipt verification already implemented. |

Threat patterns: argument injection through report-derived commands (mitigate by argv arrays/shell-safe rendering and never `eval`); path traversal/symlink escape in archives (reuse existing archive safety and enforce stage-root containment); credential leakage in trace/artifact (allowlist and sentinel tests); false green from missing/skipped jobs (retain required check/gate and verify native identities); untrusted workflow output injection (pass data through environment/files, not interpolated shell source).

## Environment Availability

This phase depends on pinned Elixir/OTP, Node/npm, Python, jq, PostgreSQL, Playwright browser binaries and GitHub Actions for the hosted canary [VERIFIED: `CONTRIBUTING.md:27-51`, `.github/actions/example-playwright-boot/action.yml:86-165`]. The example app's current configuration reads `PGDATABASE` with fallback `"example_dev"`, and reads `PORT` with fallback `"4000"` [VERIFIED: `test/example/config/dev.exs:8-9`, `:32-34`]. It disables code reloading when `CI` is `"true"` or `"1"` [VERIFIED: `test/example/config/dev.exs:32-34`]. Exact quotes: `dev_endpoint_port = String.to_integer(System.get_env("PORT", "4000"))` and `dev_code_reloading? = System.get_env("CI") not in ["true", "1"]` [VERIFIED: `test/example/config/dev.exs:32-34`]. The local environment versions were not probed during this research; planning/execution should record availability before running checks. Existing `.tool-versions`, Mix lock, Playwright lock and CI boot action define intended versions/setup. Browser parity for font-sensitive screenshots needs Ubuntu; local macOS runs are behavioral reproduction only [VERIFIED: `CONTRIBUTING.md:46-51`].

## Project Constraints (from AGENTS.md)

- Use plain English and explain actual missing items and their resolution.
- Preserve automation-first, deterministic validation; hosted success/failure/cancellation artifact behavior requires an isolated non-publishing canary with bounded limits.
- Bind CI/build/report claims to the exact source identity and preserve earlier evidence; do not substitute later development results into closed comparison.
- Never renew the Phase 254 benchmark/sample/acceptance budget. Do not claim speed from non-comparable outcomes.
- No extra numbered repair plan for ordinary implementation errors; diagnose and fix within scope while retaining stopped history.
- Do not run multiple watchers for one workflow; follow rate-limit and 60-second polling rules when authorized hosted work occurs.

## Open Questions

1. **Where will exact replay inputs be distributed?** Local refs `1c1cc0f786e52cacddb8e69a07a5855c0b74045c` and `5df0b52e9773364de9fa1aa8a37b831133c56600` resolve, but are not found on remote branches and no accessible archive is established. Make scoped refs or exact-byte archive distribution and clean-checkout restoration an explicit implementation deliverable.
2. **Will workflow terminal artifact delivery change?** If yes, use the separately bounded canary for success, failure and actual cancellation; do not infer hosted proof from local fixtures.

## Sources

### Primary / repository sources (HIGH confidence)

- `.planning/phases/255-make-failures-reproducible-and-report-the-result/255-CONTEXT.md` — locked decisions and canonical references.
- `.planning/REQUIREMENTS.md`, `.planning/METHODOLOGY.md`, `.planning/ROADMAP.md`, `AGENTS.md` — requirements, verification and scope constraints.
- `mix.exs`, `CONTRIBUTING.md`, `.github/workflows/ci.yml`, `.github/actions/example-playwright-boot/action.yml`, `scripts/ci/sigra-dep-off.sh`, `test/example/config/dev.exs`, `test/example/priv/playwright/playwright.config.ts` — current execution/configuration seams.
- `scripts/ci/ci-run-metrics.sh`, `scripts/ci/ci_metrics_security.py`, `scripts/ci/ci-browser-records.mjs`, `.planning/execution/254-environment-recovery/MEASUREMENT/run.py` — replay and validation seams.
- Evidence commits `1c1cc0f786e52cacddb8e69a07a5855c0b74045c` and `5df0b52e9773364de9fa1aa8a37b831133c56600`; current result and cost records listed in `255-RESEARCH-PREFLIGHT.json`.

### Official upstream sources (CITED)

- [Pinned Elixir 1.19.5 Mix source](https://github.com/elixir-lang/elixir/blob/v1.19.5/lib/mix/lib/mix.ex) — Mix alias and argument behavior; local pinned Mix source was also consulted per phase context.
- [Playwright trace viewer](https://playwright.dev/docs/trace-viewer) and [Playwright test options](https://playwright.dev/docs/test-use-options) — trace recording and retention controls; apply the API available in locked Playwright 1.59.1.
- [Playwright authentication](https://playwright.dev/docs/auth) — stored browser auth state is sensitive.
- [GitHub Actions expressions](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions) — failure and cancellation conditions.
- [GitHub Actions workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts) — artifacts are tied to workflow-run lifecycle and are not durable archive storage.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | Exact pinned Elixir/OTP versions can be installed on the target contributor machine using `.tool-versions`. | Environment Availability | Local parity command cannot run on a fresh checkout until toolchain setup is documented. |
| A2 | A maintained archive/ref mechanism can distribute evidence blobs to another maintainer without changing historical bytes. | Open Questions | CIMEAS-03 clean-checkout replay cannot be completed until a distribution path is selected. |
| A3 | Playwright v1.59.1 supports required per-invocation trace retention semantics as documented for the current API. | Standard Stack | Plan must confirm behavior against locked package docs/types and adapt if unsupported. |

## Metadata

**Confidence breakdown:** Standard stack HIGH (repository lockfiles/current workflow); architecture HIGH (opened source files); hosted terminal delivery MEDIUM (requires real isolated canary).  
**Research date:** 2026-10-24  
**Valid until:** 2026-11-23 for repository patterns; recheck upstream behavior if Playwright/GitHub workflow versions change.
