# Phase 255: Make Failures Reproducible and Report the Result - Context

**Gathered:** 2026-10-23 (assumptions mode; researched defaults delegated by the user)
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver CIDX-01, CIDX-02 and CIMEAS-03: contributors can run the relevant updated CI checks locally, failures provide usable reproduction information, and maintainers can replay the actual final comparison from saved inputs. Keep `mix ci` as the contributor entry point.

Phase 254 implementation is complete, but its fixed comparison is terminal `insufficient_data`: two measured invocations, one baseline failure, one candidate success and zero successful comparable pairs. CISPEED-01/02 and Phase 254 verification remain open. Phase 255 reports that result without restarting collection, changing the method or substituting later development CI. No product feature, public API/authentication change, generator change, UI redesign, release, broad upgrade or new measurement service is included.
</domain>

<decisions>
## Implementation Decisions

### Contributor commands and actual CI parity

- **D-01:** Preserve the literal `MIX_ENV=test mix ci` entry point, its intended seven ordered legs and one library-suite owner. Keep heavyweight browser setup outside its default execution. Explain its local coverage boundary and link focused companion commands from `CONTRIBUTING.md`; unrestricted `npm test` is not a substitute for a specific CI selection.
- **D-02:** Before claiming parity, observe actual ordinary, scaffold and dep-off test execution with narrow process checks. Current alias text and static contract tests alone cannot prove every receiver ran. A standalone pinned-runtime probe showed that a nested second `mix test` can be skipped with exit 0; this is a concrete lead, not proof that Sigra's scaffold coverage is missing. If the repository reproduction confirms a defect, repair the scoped command path and retain the intended coverage, exclusions, ordering and nonzero failure behavior. Do not weaken old coverage expectations or start a numbered repair loop.
- **D-03:** Document cold-checkout preparation, live PostgreSQL, pinned `phx_new 1.8.8`, `.tool-versions`, the Playwright lockfile and browser/OS prerequisites. Verify required tests are not silently excluded because a prerequisite is absent. Reproduction records identify the actual failed test invocation and its seed; do not promise that `mix ci --seed N` propagates to all receivers. Formatting, dependency and startup failures have commands, not invented random seeds.
- **D-04:** Prefer small shared browser command definitions used by local reproduction and the relevant CI steps where that prevents recurring drift. Preserve exact selected specs/projects, setup dependencies, PR versus non-PR snapshot behavior, selection/execution reports, all five isolated browser jobs, one worker and zero retries. Check actual selected identities, not just total counts. A documentation-only catalog with deterministic drift checks is the fallback if extracting a shared command would materially complicate existing validators. No workflow framework or new dependency is justified.
- **D-05:** Browser reproduction prepares a fresh invocation-owned example database and server under `MIX_ENV=dev`. Set `CI=true` for preparation and the server as well as Playwright so the code reloader stays disabled; keep the compiled and running `PORT` identical. Distinguish example `PG*` settings from library `SIGRA_TEST_PG_*` settings. Reject occupied ports and unowned reset/drop targets; cleanup only processes, databases and directories created by this invocation. Use actual readiness conditions. Explain that macOS can reproduce behavior while Ubuntu/font-sensitive visual parity requires the supported Ubuntu environment; never silently re-record screenshots to make a local run pass.

### First-failure diagnostics and safe retained files

- **D-06:** Every affected command failure reports the original command or native test identity, a shell-safe focused reproduction, working directory, source revision/dirty state, observed tool versions, relevant non-secret configuration and applicable per-invocation seed. Keep command stdout/stderr independently of test reports so installation, discovery, configuration, server startup and browser-launch failures remain diagnosable. Preserve the primary exit/signal; report later cleanup, capture or reporting failures separately. Never evaluate report text as shell code or print the entire environment.
- **D-07:** Enable `retain-on-failure` at the affected browser invocation boundary, including relevant custom contexts, rather than changing every Playwright consumer globally. Keep retries at zero. Verify a first-attempt assertion failure retains a useful trace and a passing test discards it. Recording still costs time on passing tests: measure/disclose that development overhead and bind it to the final changed source without subtracting estimates or adding it retroactively to the closed comparison. Failure before a browser context exists or hard runner termination can leave no trace; state the exact reason rather than promising an unavailable artifact.
- **D-08:** Retain an explicit invocation-bound diagnostic bundle with command/native output, server log and applicable failure artifacts. Include run, attempt, job/seam, invocation and source identities. Preserve outputs from sequential Playwright invocations before later reporters clear shared directories. Keep the existing bounded seven-day CI retention by default and document retrieval before expiry. Durable final comparison inputs need separate preserved storage; transient Actions artifacts are not that archive.
- **D-09:** Stage intended diagnostics explicitly and exclude authentication storage, unrelated/stale files, credentials and paths escaping the staging root. Use synthetic accounts without production credentials. Test the finished bundle for planted secret sentinels, auth files and escaping symlinks. Traces themselves may contain authentication requests and DOM content; excluding `.auth` does not make arbitrary traces safe. Current hidden-file upload defaults are not evidence of an existing credential leak. Keep auth state temporary and excluded from Git, retained bundles and Pages publication.
- **D-10:** Prove local failure behavior through narrow real-process/browser tests: command failure followed by failing cleanup, startup/discovery failure, initial assertion failure, passing trace disposal, output isolation and exact command/seed reproduction. When hosted upload/terminal behavior changes, plan a small isolated non-publishing canary that retrieves source/run/attempt-bound artifacts for success, failure and actual fixture cancellation. Freeze its own finite invocation/request/time/retry limits before execution; no old allowance is reused. Cancellation/runner loss can prevent final upload; missing files stay missing. Keep expensive boot out of cancellation-resistant recording paths and do not alter required-check names, gate policy or existing failure/skip protections.

### Offline replay and honest comparison status

- **D-11:** Make replay work from a clean checkout without network access after obtaining the preserved input package. Name an actually accessible evidence ref or exact-byte archive, restore receipt paths safely and verify hashes before calculation. Local ignored raw directories or an unpublished local ref alone are insufficient for another maintainer. Include the contract, registrations, source archive, workload map, captured run/job data and all transitive tool/data dependencies. Preserve original bytes; a missing or altered input produces a concrete diagnostic.
- **D-12:** Pin the replay calculator and its helpers/data separately from the original measured application/workflow. The captured metrics script predates the null-family/failed-cost repair in `d5b7300c809ce7cd474e87aa55fda278b3a09cbc`; current helpers and fallback timing files can otherwise change output. Reuse the existing calculator, cost derivation, archive safety and origin checks. Explain that repaired analysis ran on unchanged saved observations; it was not part of the original measured treatment. Do not overwrite the Phase 252 archive or failed-baseline manifest to make validation look cleaner.
- **D-13:** Validate result fields as well as process status. A successful calculation with exit 0 may correctly return `insufficient_data`; it does not pass performance acceptance. Replay must retain zero successful comparable pairs, null median/p95 values, baseline failure and candidate success, and observed runner costs of 2046 and 1589 seconds. These unequal failed/successful observations do not establish a percentage improvement. Test missing/corrupt inputs, a changed tool dependency, null families and all observed attempt costs. Verify replay leaves inputs unchanged.
- **D-14:** Keep the fixed method: ordinary median; nearest-rank p95 `ceil(0.95*n)`; 20 successful matched pairs under the original workload/cache/runner rules; literal outcomes and rerun costs retained. Report invocation counts, failures, cancellations, preparations/reruns, actual cache/image conditions, unknown overhead and remaining limitations separately. Do not count unused reservations as observations, missing times as zero or missing metadata as proven source divergence. The failed baseline never produced successful-family metadata; explain the evaluator's generic identity/missing-family diagnostics. One materialized candidate's successful origin check does not qualify both measured sides.

### Final reporting, delivery and scope

- **D-15:** Produce one concise final report with replay commands and machine-readable results, linked from contributor/maintainer guidance as appropriate. Name original baseline/candidate sources, analysis source and later diagnostic changes separately. Distinguish implemented optimizations, demonstrated reliability fixes, actual hosted development coverage and unproved speed targets. Later PR 353/source `8b3c3d8c75152438bb3259c1226b1044da717b3c` passed development CI with 108 browser cases and added zero acceptance samples. The controlled connection reproduction does not prove the missing initiating event in the original hosted trace.
- **D-16:** CIMEAS-03 can establish faithful replay/reporting of an insufficient-data result while CISPEED-01/02 remain open. Keep the original experiment terminal: no replacement samples, renewed window, new benchmark or reused acceptance budget. Any future benchmark needs separately agreed scope and method. This discussion authorizes decisions for planning, not Phase 255 execution or hosted acceptance.
- **D-17:** Prefer small repository-local helpers and existing Bash/Node/Python/Elixir facilities. Add no dependency, dashboard, parallel evidence framework or extra review layer without a demonstrated need. Repair ordinary implementation/test errors through scoped maintenance with meaningful tests, retaining original stopped results. Existing unrelated backlog items remain outside this phase.

### Agent's Discretion

Choose small helper/file boundaries, exact focused command names, internal diagnostics schema and report location. Use primary sources and pinned runtime APIs. Preserve the command/coverage, isolation, original-failure, artifact security, source identity and comparison-truth boundaries above. No further broad option menu is needed.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents must read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 255 goal and four success criteria; older Phase 254 routing prose is historical.
- `.planning/REQUIREMENTS.md` — CIDX-01/02, CIMEAS-03 and fixed comparison requirements.
- `.planning/METHODOLOGY.md` and `AGENTS.md` — automatic verification, source identity, scoped preservation, finite hosted work and recovery lessons.
- `.planning/phases/252-measure-current-ci/252-CONTEXT.md` and `.planning/phases/252-measure-current-ci/252-COMPARISON-CONTRACT.json` — immutable baseline/method and statistical rules.
- `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-CONTEXT.md`, `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-VERIFICATION.md`, `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-RESET.md` and `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LEARNINGS.md` — reliability, gate/isolation boundaries and stopped-attempt handling.
- `.planning/phases/254-speed-up-the-measured-slow-jobs/254-CONTEXT.md` — optimization and coverage boundaries.
- `.planning/execution/254-environment-recovery/MEASUREMENT/CONTRACT.json`, `.planning/execution/254-environment-recovery/MEASUREMENT/RESULT.json`, `.planning/execution/254-environment-recovery/MEASUREMENT/REGISTRATIONS.json`, `.planning/execution/254-environment-recovery/MEASUREMENT/EVALUATION-COSTS.json`, `.planning/execution/254-environment-recovery/MEASUREMENT/REPLAYED-COSTS.json`, `.planning/execution/254-environment-recovery/MEASUREMENT/requests/pair-01/CAPTURE-before.json` and `.planning/execution/254-environment-recovery/MEASUREMENT/requests/pair-01/CAPTURE-after.json` — final actual observations, replay identities and cost results.
- `.planning/execution/254-transport-development-check/RESULT.json`, `.planning/execution/254-transport-development-check/VERIFICATION.json`, `.planning/execution/254-transport-development-check/REPAIR-SUMMARY.md` and `.planning/execution/254-transport-development-check/FINAL-RECOVERY.json` — later development proof and preservation, distinct from acceptance.
- `CONTRIBUTING.md`, `mix.exs`, `scripts/ci/sigra-dep-off.sh`, `test/test_helper.exs`, `.github/workflows/ci.yml`, `.github/actions/example-playwright-boot/action.yml` and `test/example/config/dev.exs` — real contributor/CI commands and preparation.
- `scripts/ci/ci-run-metrics.sh`, `scripts/ci/ci_metrics_security.py`, `scripts/ci/ci-hosted-gate-verify.py`, `scripts/ci/ci-browser-records.mjs`, `test/support/ci_timing_formatter.ex` and `test/example/priv/playwright/playwright.config.ts` — existing calculation, source checks and diagnostics.

Primary sources consulted:
- https://github.com/elixir-lang/elixir/blob/v1.19.5/lib/mix/lib/mix.ex — pinned Mix alias semantics; local pinned Mix task source supports receiver/argument analysis.
- https://playwright.dev/docs/trace-viewer and https://playwright.dev/docs/test-use-options — zero-retry tracing and recording/retention distinction; validate implementation against lockfile version 1.59.1.
- https://playwright.dev/docs/auth — authentication state sensitivity and server-state isolation.
- https://docs.github.com/en/actions/reference/workflows-and-actions/expressions — failure/cancellation conditions and narrow use of always().
- https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts — transient artifact lifecycle; retained comparison data must not depend on an expiring URL.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The metrics script already replays snapshots and evaluates comparisons; its repaired cost derivation retains failed/unpaired work.
- Browser selection/execution validators, native reporters, pinned boot action and readiness helpers already define the five CI workloads.
- The timing formatter and opt-in failure JSONL reporter are useful building blocks but currently omit seeds/global setup failures respectively.
- Existing PostgreSQL and UAT scripts provide local setup patterns; do not blindly reuse their persistent database targets for disposable browser checks.

### Established Patterns
- Library ExUnit uses test/Sandbox state; browser checks use real isolated dev servers/databases. Browser contexts alone do not reset backend state.
- HTML output can be cleared between invocations; auth storage can survive interrupted teardown. Capture and staging need explicit invocation boundaries.
- Native command outcomes and actual selected test identities take precedence over green aggregates, counters and documentation text.

### Integration Points
- Update contributor guidance alongside narrowly shared local/CI commands, failure recording and artifact upload paths.
- Materialize preserved captures at their receipt paths, pin tool/data sources and replay without fresh GitHub requests.
- Before rewriting any initially dirty planning state, preserve and verify exact bytes under a durable ref. This discussion began with clean planning files at commit `7ff20056b69e2a716b322d8a0415f9a818ecec91`; unrelated untracked Python bytecode remains untouched.
</code_context>

<specifics>
## Specific Ideas

The user requested adversarial breadth and depth across relevant roles, reputable primary sources, a coherent recommendation set and automatic adoption of the resulting defaults. Three parallel reviews covered contributor/Elixir command parity, diagnostics/security/CI delivery, and offline replay/reporting. Product UI and graphics roles would add no relevant decision here. Prefer a small copied helper over another dependency. Stop research when further reviews repeat the same tradeoffs; do not turn ordinary development errors into more plans.
</specifics>

<deferred>
## Deferred Ideas

No new capability was requested. A future speed benchmark, product changes, broader workflow redesign and missing 1.6 upgrade guidance remain outside Phase 255. Keyword-matched pending todos add no scope and are not closed by this discussion.
</deferred>
