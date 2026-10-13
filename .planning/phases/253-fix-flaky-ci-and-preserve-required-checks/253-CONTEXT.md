# Phase 253: Fix Flaky CI and Preserve Required Checks - Context

**Gathered:** 2026-10-12/13 (assumptions mode, specialist research and adversarial review)
**Decision authority:** The user requested a coherent researched recommendation set and instructed the agent to follow it automatically. These are delegated decisions, not a recorded menu selection or approval of completed work.
**Status:** Ready for planning. Implementation and phase verification have not started.

<domain>
## Phase Boundary

Deliver CIREL-01 and CIREL-02: investigate the selected current CI failures, fix causes established by reproduction, and prove that useful required work cannot silently disappear behind a green gate. Preserve required-check names, test ownership, isolated application/database state, and zero browser retries. The contributor needs an accurate failed command and a usable reproduction; the maintainer needs to know whether the expected tests actually ran.

Phase 252 supplies the immutable measurements and source archive. This phase corrects its failure diagnosis through a separate record, without rewriting those inputs. Phase 254 owns speed optimization and the fixed 20-pair/40-family, 48-hour comparison; Phase 255 owns final contributor guidance and the comparison report. Old release approvals are not prerequisites. No product feature, UI redesign, public authentication/API change, generator change, release, broad upgrade, paid runner, or new dependency is included.
</domain>

<decisions>
## Implementation Decisions

### Select failures from actual failed execution

- **D-01:** Preserve every Phase 252 artifact byte-for-byte. Add an explicitly versioned Phase 253 diagnosis path and companion correction record. Its records must identify the original archive/report hashes, analyzer source, run/attempt/job/step, original outcome, corrected diagnosis and missing details. Preserve the legacy baseline replay contract: its verifier compares the complete replay object. Do not silently change old failure fields or turn historical failures green.
- **D-02:** Reject the shortlist's `settled-findings-lint` Test D as a failure signature. Both cited PR logs show that test passing. Their actual fast-check failure was the metrics self-test's Test Z dependency on an unavailable historical archive; current source already replaced that dependency with a hermetic contract. Verify the present test and retain the old reds; do not repair a passing settled-findings test again.
- **D-03:** Select admin-eval registration as the first current investigation lead. Retained runs 38139851334, 38141796613 and 38205503164 contain registration failures. The latest nightly's `admin-eval.spec.ts` Git blob is identical to current source. Its failure occurred in `admin-eval-dark`, so investigate desktop Chromium, WebKit/mobile and dark Chromium. A recurring timeout and an unchanged helper establish a lead, not its cause or a completed flake fix.
- **D-04:** Before fixing anything, reproduce a specific readiness, transport, state/order or harness condition on the exact affected source with the pinned tools. Preserve before/after results and a negative control that detects the regression. The existing helper already waits for LiveView connection and captures registration diagnostics. Do not assume the old September explanation still applies, lengthen timeouts speculatively, replace registration with shared authentication, or change product authentication. If the cause lies outside the test/CI boundary, record it and keep independent gate work moving.
- **D-05:** Prefer native Playwright results and the actual failing job/step/command over whole-log keyword matching. For shell output, a passing banner or an intentional negative-test `FAIL:` is not an unexpected failure. Keep observed result, suspected cause and proved cause separate. Preserve expected versus actual test status, original nonzero exits, earlier attempts and producer failures behind aggregates. Timeout is not automatically infrastructure; rerun count does not prove superseded cancellation.
- **D-06:** Record diagnosis completeness per failed producer job and selected step. The current archive often retains only one failed-job log, and some failed jobs remain unexplained. Select relevant failure context before the existing redaction/display cap; retain original hashes, line ranges and truncation metadata. Missing, clipped, conflicting or hash-mismatched inputs remain unknown. A bounded collection limit or unavailable log must not become proof that there is no flake.

### Deterministic readiness, state isolation and diagnostics

- **D-07:** Preserve five browser seams, their existing selected specs/projects, separate databases/apps/ports, `workers: 1`, `fullyParallel: false` and `retries: 0`. Keep one ordinary `MIX_ENV=test mix ci` library owner. Browser runs use a real `MIX_ENV=dev` application/database; ExUnit uses Sandbox owners. Do not describe browser state as Sandbox-isolated or random identifiers as proof of database isolation.
- **D-08:** Use application readiness conditions before interaction: actual HTTP readiness at boot, LiveView connection for LiveView routes, and server-confirmed registration outcomes. Controller login pages must not wait for a LiveView marker. Test controlled delayed/missing readiness with explicit signals and a broken-wait negative control, then establish the relevant behavior through the real browser/server. Preserve bounded condition polling at boot; add no fixed test sleeps, retry wrappers or `test.slow` masking. Do not infer the observed transport from comments about long-poll fallback.
- **D-09:** Verify the affected state boundary with a deliberate collision/isolation control and rollback/ownership checks where applicable. Preserve Ecto's existing owner lifecycle, explicit allowances for collaborating async processes, and shared mode only for non-async tests. Supervise test-owned processes. Keep isolated and preceding-order reproductions distinct: a fresh isolated pass cannot exclude an order-dependent failure.
- **D-10:** Capture first-failure traces for the selected diagnostic/repeat invocations with `--trace=retain-on-failure`, beginning before navigation and submission. Current global `on-first-retry` produces no trace with zero retries. Keep this override scoped; global recording cost has not been measured. Verify a deliberately failing test retains useful actions and its original assertion, while a passing control discards the trace. Use synthetic accounts, safe structural diagnostics and bounded CI artifact retention; exclude auth-state files, secrets and public Pages publication.
- **D-11:** Preflight the exact checkout SHA/cleanliness, workflow/source identities and command-observed tools. Restore the lockfile-installed Playwright 1.59.1 in the execution checkout before collecting evidence: ignored local `node_modules` currently contains 1.62.1. Confirm each host's actual Ecto/LiveView versions rather than using the library lockfile for the example app. Keep source, PR head, merge checkout and fixture workflow identities separate.

### Complete required-check ownership and honest skips

- **D-12:** Preserve the five effective required names: `Library tests`, `Example unit smoke (ExUnit + ConnTest)`, `Install smoke (fresh phx.new + sigra.install)`, `Example HTTP smoke (boot + curl critical routes)`, and `Example Playwright smoke (full lifecycle)`. Freshly read effective rules and check sources before hosted work. Unexpected changes produce a contract diagnostic; do not mutate protection rules or make `ci-gate` a sixth required name. No redundant check removal is proposed.
- **D-13:** Add `example_unit_smoke` to the internal `ci-gate` dependency/result/verdict ownership together, including the fixed lane-set tests and explanatory notes. Its independent required check does not close the internal release-gate omission. Reuse `honest-skip-verdict.sh` and existing tests; do not create a competing gate policy.
- **D-14:** Require the browser aggregate to account for exactly five producers and their selected bodies: `non_admin_smoke`, `admin_behavior`, `admin_checkpoints`, `design_gallery`, `demo_showcase`. Keep native successful matrix results necessary. Add small per-seam execution records using existing artifact actions and a standard-library validator. Records include selected step IDs, pre/post-`continue-on-error` outcomes, actual source/run/attempt/event/seam and report completeness where available. Reject missing, duplicate, unknown, malformed, wrong-run/attempt/source records, skipped full-workload bodies and cancelled producers. A record cannot override a failed native job or prove tests ran when the native report is empty/incomplete.
- **D-15:** Use unique artifact names containing seam/run/attempt, require the expected record file, and keep downloaded producer directories separate. Ordinary same-run validation needs no broad new token permission or per-job GitHub API polling. Do not merge matrix children into a shared output key: the last finishing job overwrites it. Distinct per-seam outputs are a lighter runner-up only if hosted proof establishes their complete terminal behavior; the chosen default is retained execution records.
- **D-16:** Accept intentional docs-only body skips only for an actual PR with a successful classifier and exactly `true`. Unknown classification runs full work or leaves a non-green result. Always account for all five producers; the terminal browser aggregate has no docs-only skip. Correct the manifest's synthetic aggregate entry, document the actual selected body boundaries, and update p10/p21/MAINTAINING parity with a negative fixture for this exact mismatch. Do not lower populated-inventory guards merely to pass.
- **D-17:** Preserve native command exits, matrix `fail-fast: false`, real cancellations and useful coverage owners. Add no `continue-on-error`. Use cancellation-resistant conditions narrowly for bounded result recording/verdicts, not expensive boot. Inject failed commands, cancelled work, missing jobs/records, unexpected skips, malformed identity, false classifier claims, and ownership/manifest drift. Expected negative probes are successful verification only when their source run actually fails/cancels and a separate verifier proves that expected result.
- **D-18:** For hosted phase evidence, independently compare retained GitHub jobs/steps and artifact metadata/digests with the producing run, attempt, source and workflow. Filename/JSON claims alone cannot establish origin. Operational same-run coverage records protect against accidental omission; they are not an attestation against an arbitrary malicious rewrite of a PR workflow. Preserve read-only ordinary CI permissions and existing action pins.

### Fixed verification budget and delivery boundaries

- **D-19:** Freeze at most three investigated signatures, their selected tests/projects/order, seeds, source identities and stop conditions before observing results. First reuse the saved archive. Additional selected diagnostics are capped at 60 HTTP requests or 15 minutes, including retries/redirects. Reproduction is capped at ten targeted invocations or twenty minutes per signature, sixty minutes total. Stop and diagnose deterministic failures; retain every attempt. One independently diagnosed infrastructure retry stays inside the relevant budget and never replaces the original result.
- **D-20:** After a demonstrated cause is fixed, run three fresh targeted invocations per affected project, plus the deterministic regression and negative controls. For relevant narrow ExUnit checks use three fixed seeds in separate processes (default 101/202/303), preserving normal scheduling/timeouts. Freeze these selections before starting. Use separate fresh app/database/context invocations for acceptance repeats; `--repeat-each` alone does not reset backend state. Run each existing browser seam selection once for integration coverage, and normal affected library/contracts, rather than fifteen full-seam repeats. Three passes prove those executions, not absence of flakiness. No unbounded retry-until-green or repeat-until-failure acceptance loop.
- **D-21:** Preflight and use the already registered `.github/workflows/ci.yml` path on a sealed scoped fixture ref for the lightweight hosted canary. On that fixture ref only, use the distinct workflow name `Phase 253 Gate Canary`, dispatch-only triggering, five tiny producers, candidate gate/record helpers, strict fixture identity checks, and a separate verifier mode. No default-branch mutation, release tag, recapture, issue notification, publishing credential or auto-merge is needed. Confirm downstream workflow-name triggers do not match before dispatch. Pin the tested helper checkout to the candidate commit and separately record fixture workflow SHA/blob; do not present fixture topology as production CI.
- **D-22:** The canary has six scenarios: full pass, intentional docs-only fixture, actual failed body, missing seam, unexpected body skip and actual run cancellation. Allow at most one infrastructure-only rerun, 45 lightweight job executions, sixty minutes and 120 GitHub requests. Reserve one separate verifier job inside the ceiling; six six-job scenarios plus a six-job rerun and verifier are at most 43 jobs. Cancellation targets only the positively identified fixture run/ref/SHA. The PR docs-only scenario is explicitly synthetic: record the real `workflow_dispatch` event alongside its logical PR input. Push/schedule/dispatch must not obtain the production docs-only exemption.
- **D-23:** Follow the canary with one normal production `pull_request` CI family on the exact candidate, plus at most one diagnosed infrastructure rerun if necessary; preserve all outcomes and existing job timeout ceilings. Reuse its integration coverage where it meets D-20 rather than running duplicate full suites. Freeze a separate finite collection budget before launch, no larger than 120 requests/60 minutes. Dispatch canaries do not satisfy PR required checks or prove real PR classification. Keep real PR required-check proof and offline classifier controls separate; add a real docs-only PR probe only if changed classification behavior requires it, reserved within this same budget before outcomes.
- **D-24:** Completion needs proven selected fixes or the roadmap's honest no-flake path with adequate reviewed diagnostics and passing deterministic readiness/isolation controls. Recent unresolved registration failures, missing selected diagnostics or an exhausted reproduction budget cannot automatically qualify as no flake. Record `not_reproduced`, `diagnosis_incomplete`, target failures and requirement gaps honestly. No human UAT or old release record is a substitute. Honor one watcher per run, 60-second polling, core-budget stop at 250 and hard 403/429/reset handling. This discussion authorizes planning choices; no phase acceptance or optimization result is claimed.

### Agent's Discretion

Choose small internal helper/schema/file boundaries, exact signal-driven fixtures, targeted test names/seeds/order within the frozen limits, and safe artifact storage. Reuse Bash/Node/Python standard libraries, existing native reporters, gates and artifact actions. The failure selection, preserved baseline, required names, isolation/retry rules, proof boundaries and numeric ceilings above are locked. Research current pinned APIs before using a new fixture capability. A materially changed public/security/generated-host contract requires a separate decision; routine internal implementation choices do not.

### Folded Todos

The already-linked `2026-09-15-admin-eval-webkit-registration-flake-recurrence.md` is investigated through current source/logs; its title and suggested fixes are not conclusions. The unit-owner omission and `2026-09-19-example-playwright-smoke-manifest-step-gate-inaccuracy.md` are directly within CIREL-02's ownership/skip proof. Neither is closed by discussion. Other keyword matches remain unpromoted and unchanged.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope, decisions and preserved source

- `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`, `.planning/METHODOLOGY.md`, `AGENTS.md`, `test/example/AGENTS.md`.
- `.planning/phases/252-measure-current-ci/252-CONTEXT.md`.
- `.planning/phases/252-measure-current-ci/252-BASELINE.md` and `.planning/phases/252-measure-current-ci/252-BASELINE.json`.
- `.planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz` and `.planning/phases/252-measure-current-ci/252-COMPARISON-CONTRACT.json`.
- `.planning/phases/252-measure-current-ci/252-VALIDATION.md` and `.planning/phases/252-measure-current-ci/252-VERIFICATION.md`.
- `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-DISCOVERY.json` — source identities, corrected leads and limits; discussion discovery, not acceptance.
- `.planning/milestones/v1.48-phases/236-flake-root-cause-reproduce-name-fix/236-CONTEXT.md` and `.planning/milestones/v1.47-phases/232-playwright-economics-authenticate-once-then-shard/232-CONTEXT.md` — existing readiness and state ownership.

### Current CI and test seams

- `.github/workflows/ci.yml`, `.github/actions/example-playwright-boot/action.yml`, `.github/ci-skip-manifest.tsv`, `MAINTAINING.md`.
- `scripts/ci/honest-skip-verdict.sh`, `scripts/ci/honest-skip-verdict.test.sh`, `scripts/ci/wait-for-ci-gate.sh`.
- `scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs`, `scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs`, `scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs`.
- `scripts/ci/ci-run-metrics.sh`, `scripts/ci/ci-run-metrics.test.sh`, `scripts/ci/ci_metrics_security.py`, `scripts/ci/ci-playwright-report.mjs`.
- `test/example/priv/playwright/playwright.config.ts`, `test/example/priv/playwright/package-lock.json`, `test/example/priv/playwright/tests/admin-eval.spec.ts`, `test/example/priv/playwright/helpers/adminFlows.ts`.
- `mix.exs`, `mix.lock`, `test/support/postgres_case.ex`, `test/test_helper.exs`, `test/example/mix.lock`, `test/example/test/support/data_case.ex`.
- `.github/workflows/ci-observe.yml`, `.github/workflows/release-pr-automerge.yml`, `.github/workflows/release-run-observer.yml` — fixture dispatch must not trigger production observers.
- `.planning/todos/pending/2026-09-15-admin-eval-webkit-registration-flake-recurrence.md`, `.planning/todos/pending/2026-09-19-example-playwright-smoke-manifest-step-gate-inaccuracy.md`, `.planning/todos/pending/2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md` — diagnostic leads, not completed fixes.

### Project research and official documentation

- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md`, `prompts/elixir-opensource-libs-best-practices-deep-research.md`, `prompts/ecto-best-practices-deep-research.md`, `prompts/phoenix-live-view-best-practices-deep-research.md`, `prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md`.
- [GitHub required-check troubleshooting](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks), [matrix output semantics](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#using-job-outputs-in-a-matrix-job), [step outcomes](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#steps-context), [cancellation](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-cancellation).
- [Workflow dispatch](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch), [dispatch API](https://docs.github.com/en/rest/actions/workflows#create-a-workflow-dispatch-event), [attempt jobs](https://docs.github.com/en/rest/actions/workflow-jobs#list-jobs-for-a-workflow-run-attempt), [artifact origin fields](https://docs.github.com/en/rest/actions/artifacts#get-an-artifact), [upload](https://github.com/actions/upload-artifact#not-uploading-to-the-same-artifact), [download](https://github.com/actions/download-artifact#usage).
- [Playwright traces](https://playwright.dev/docs/trace-viewer#tracing-on-ci), [1.59.1 trace implementation](https://github.com/microsoft/playwright/blob/v1.59.1/packages/playwright/src/worker/testTracing.ts), [hydration](https://playwright.dev/docs/navigations#hydration), [authentication state](https://playwright.dev/docs/auth#basic-shared-account-in-all-tests), [JSON reporter](https://playwright.dev/docs/test-reporters#json-reporter), [test result](https://playwright.dev/docs/api/class-testresult).
- [Example LiveView 1.1.28 lifecycle](https://phoenix-live-view.hexdocs.pm/1.1.28/Phoenix.LiveView.html#c:mount/3), [example Sandbox 3.13.5 source](https://github.com/elixir-ecto/ecto_sql/blob/v3.13.5/lib/ecto/adapters/sql/sandbox.ex), [library Sandbox 3.14.0](https://hexdocs.pm/ecto_sql/3.14.0/Ecto.Adapters.SQL.Sandbox.html), [Mix 1.19.5 test options](https://github.com/elixir-lang/elixir/blob/v1.19.5/lib/mix/lib/mix/tasks/test.ex), [Chromium order investigation](https://www.chromium.org/developers/testing/fixing-flaky-tests/fixing_flaky_unittests/).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- Current admin-eval registration helper already has connection and POST/redirect diagnostics. Its surviving failure is the investigation seam; the original September helper is no longer the source of truth.
- Existing honest-skip tests cover several negative outcomes. Extend their fixed lane ownership and workflow parity rather than replacing them.
- Native Playwright JSON, small metrics/security helpers, safe path/hash checks, and existing artifact actions can implement failure diagnosis and seam records without another package.
- The shared boot action already uses bounded HTTP condition polling. Browser invocation state is deliberately serial and separate between five matrix jobs.

### Established Patterns

- PR supersession cancellation differs from a failing current candidate. Preserve both literal outcomes.
- Required browser jobs stay present for docs-only PRs while selected bodies skip. Their aggregate must still count producers and legitimate eligibility.
- The internal release waiter reads `ci-gate`; independently required unit smoke is currently outside that verdict.
- Passing whole-run or aggregate conclusions do not establish every selected body executed. Native command outcomes, execution records and independent hosted observations serve different purposes.

### Integration Points

- Versioned diagnosis companion at the existing metrics CLI; unchanged legacy baseline replay.
- `ci-gate` and browser aggregate producer/body records, with skip manifest and local prohibition tests.
- Test-only readiness/registration controls using the real example app and scoped first-failure traces.
- Scoped fixture dispatch through an already registered workflow path, followed by normal production PR proof.
</code_context>

<specifics>
## Specific Ideas

- The user wants relevant broad research, adversarial consideration and one coherent recommendation set, followed automatically. Prefer copying a small purposeful helper to adding an unnecessary dependency. Explain failures and missing inputs in plain English.
- Registration lead: nightly run `38205503164`, source `4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97`, helper blob `6540493e78121f134867445dffc7010afcd85815`, `admin-eval-dark`, `board-mg-9/populated`. Preserve earlier failing test order when available.
- A proposed narrow registration selection should exercise the existing `beforeEach/registerUser` through an affected render test across all three projects. Exact commands, restored pinned tools and isolated boot are implementation preflight work; discussion ran no application tests.
- No UI design change is needed. If a proven fix touches UI source, apply the existing admin design contracts; use accessible roles and stable hooks for browser assertions.
</specifics>

<deferred>
## Deferred Ideas

- Auth-state reuse, higher worker counts, changed shard topology, cache/boot optimization, or removed coverage: Phase 254 only with measurements and ownership proof.
- Full contributor runbook, broad failure-report polish and final speed/reliability comparison: Phase 255.
- Public authentication/generator changes, product UI design, external flake platforms, broad upgrades, paid runners, releases and historical release-record recovery: outside this phase.
- Unexplained unselected failed producer jobs remain disclosed. Do not open a broad new history acquisition or unrelated backlog sweep to make the phase exhaustive.

### Reviewed Todos (not folded)

Per-shard parallelization belongs to optimization; timing orphan history already has prior ownership; unrelated installer, auth, release and planning keyword matches remain unchanged. The missing 1.6 upgrade guide remains its separate task. Discussion closes no todo or requirement.
</deferred>

---

*Phase: 253-fix-flaky-ci-and-preserve-required-checks*
*Research is decision input; phase implementation and acceptance remain pending.*
