# Phase 252: Measure Current CI - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use this log as input to planning, research or execution. Decisions are in `252-CONTEXT.md`.

**Date:** 2026-10-12
**Phase:** 252-measure-current-ci
**Mode:** assumptions; text confirmation
**Areas analyzed:** run population/source identity; required-result waiting; job/step/test costs; failure states; bounded comparison and collection.

## User Intent and Confirmation

The user invoked `$gsd-discuss-phase 252` and explicitly requested subagent research across relevant technical, security, SRE, contributor/DX and adversarial viewpoints. They requested primary sources, applicable `prompts/` research, cohesive decisive recommendations and a small dependency tree. Product UI research was inapplicable to this measurement phase.

The recommendation was presented with a link to the full decision packet. Option 1 was: **Accept these recommendations — save and commit Phase 252's context.** The user answered **`1`**. All proposed decisions were accepted; no corrections were requested. This is discussion approval, not implementation or phase acceptance.

## Assumptions Presented

| Area | Recommendation and consequence if wrong | Initial confidence | Evidence |
| --- | --- | --- | --- |
| Population | Separate PR/main/nightly, docs-only/full work and attempts; mixing them can manufacture a timing improvement. | Likely | `ci.yml` triggers/changes; metrics query; Phase 252 requirements |
| Required result | Measure completion of enforced checks, not optional trailing jobs; a wrong endpoint credits work that contributors do not wait for. | Likely; live names confirmed | `MAINTAINING.md`; workflow dependencies; effective main rules |
| Runtime costs | Measure today's unchanged workload; old formatter/topology is absent and archived costs can select the wrong bottleneck. | Likely | `mix.exs`; library job; Playwright config/boot; timing todo |
| Failures | Use current repeated signatures and preserve literal states; red metadata alone can confuse superseded cancellation with a flake. | Likely | PR concurrency; skip manifest; current run inventories |
| Fixed comparison | Freeze sample, source, cache, runner and percentile method; changed conditions or extended samples can manufacture a passing result. | Unclear; recommended limits accepted | Roadmap targets; API rules; official docs; bounded live discovery |

## Research Dispatch and Synthesis

- `phase252_assumptions`: typed `gsd-assumptions-analyzer`, codebase/prompt/prior-context review, no web/API or edits; resolved model `gpt-6-sol`, effort `xhigh`.
- `phase252_measurement_method`: typed `gsd-advisor-researcher`, official GitHub fields and comparison tradeoffs; resolved model `gpt-6-luna`, effort `high`.
- `phase252_elixir_test_timings`: typed `gsd-advisor-researcher`, native ExUnit/Playwright timing, Sandbox ownership and contributor simplicity; same resolved model/effort.
- `phase252_live_feasibility`: typed `gsd-advisor-researcher`, sole live GitHub reader, effective rules and bounded input discovery; same resolved model/effort. A narrow follow-up corrected request-method diagnostics.

All children returned terminal answers before synthesis. No agents edited repository files or dispatched/reran/cancelled CI. The parent chose the hybrid measurement method, native test-only formatter plus built-in JSON, bounded snapshots and fixed matched comparison. Natural-only comparisons have confounding workload/cache/image mix; controlled-only dispatches do not prove PR waiting; extra custom reporters/services add maintenance and possible output/exit effects.

## Methodology Applied

- Automation and source identity: retain producing run/attempt/revision and replay inputs; do not substitute an aggregate green status for executed work.
- Evidence feasibility: input availability was checked before proposing a plan. Unknown queue/cache/test data and expired diagnostics are named, not passed.
- Security/SRE: one API owner, finite request budget, rate-limit stop, artifact-origin checks and no captured secrets.
- Contributor experience: keep `mix ci`, readable output and lean native tools; avoid adding a service, runtime dependency or broad menus.
- Statistical/adversarial review: fixed cache/workload strata and matched pairs; retain failures/cancellations/reruns; empirical p95 has limited tail resolution.
- Scope/preservation: no old release recovery, UI changes or product work; clean source bytes verified before writing context/state.

## External Research

- [GitHub workflow runs](https://docs.github.com/en/rest/actions/workflow-runs), [jobs](https://docs.github.com/en/rest/actions/workflow-jobs), [checks](https://docs.github.com/en/rest/checks/runs): run/attempt/job/step fields support replay; listed job timestamps alone do not establish pure queue time.
- [ExUnit configuration](https://hexdocs.pm/ex_unit/1.18.4/ExUnit.html) and [source](https://github.com/elixir-lang/elixir/blob/v1.18.4/lib/ex_unit/lib/ex_unit.ex): completed-test runtime is available; slowest/trace changes scheduling and timeout conditions.
- [Mix test](https://hexdocs.pm/mix/1.18/Mix.Tasks.Test.html), [Ecto Sandbox](https://ecto-sql.hexdocs.pm/3.12.0/Ecto.Adapters.SQL.Sandbox.html): preserve normal test execution and ownership.
- [Playwright reporters](https://playwright.dev/docs/test-reporters), [results](https://playwright.dev/docs/api/class-testresult), [fixtures](https://playwright.dev/docs/test-fixtures): built-in JSON and duration/status/retry/project data; shared setup is separate cost.
- [NIST percentiles](https://www.itl.nist.gov/div898/handbook/prc/section2/prc262.htm): percentile order-statistic context; 20 pairs and the chosen nearest-rank calculation are explicit project recommendations, not a statistical guarantee.

Official facts informed the choices; the snapshot/pair/time/request limits and hybrid method are the researched project defaults that the user approved.

## Discovery Facts and Limits

Since 2026-09-12 UTC, bounded CLI queries captured:

| Event | Captured | Success | Failure | Cancelled | Latest attempt above 1 |
| --- | ---: | ---: | ---: | ---: | ---: |
| PR | 100 | 68 | 13 | 19 | 1 |
| Push to main | 81 | 58 | 19 | 4 | 2 |
| Schedule | 31 | 22 | 9 | 0 | 0 |

The PR page covers only 2026-10-09 through 2026-10-11. A corrected one-row GET reports 264 PR records in the wider interval. Latest summaries do not reveal earlier attempt conclusions. No failure logs were collected; no test-level flake was identified. Cache state, actual runner image and current test costs remain unknown. One representative successful run is a lead only. Discovery inputs are retained under `discussion-sources/`; they are not the Phase 252 acceptance baseline.

Initial rate response reported core 5000 remaining. There were 13 top-level gh invocations and approximately 14 HTTP requests; transport counting was not instrumented. No 403/429 occurred. Three parameterized calls omitted explicit GET; their 404s did not establish blocked REST access. A corrected numeric-workflow GET succeeded. A parameterless workflow-list 404 did not prevent numeric run collection. Corrections are preserved in the access notes and raw responses.

## Corrections Made

No user corrections. Research corrected the API-method interpretation before recommendations were accepted. No inaccurate access blocker was promoted into the context.

## Todo Review and Scope

The runtime produced broad keyword matches among 70 pending todos. Existing milestone ownership and actual scope govern: no new todo was promoted; admin-eval remains Phase 253, timing history remains its existing Phase 241 disposition, and gate-manifest repair remains outside this measurement phase. Todo bytes are unchanged.

## Outcome

Approved context is ready for `$gsd-plan-phase 252`. Implementation, current baseline acceptance and phase verification have not started. All nine milestone requirements remain unchecked. Old release-record gaps remain separately recorded and do not block this route.
