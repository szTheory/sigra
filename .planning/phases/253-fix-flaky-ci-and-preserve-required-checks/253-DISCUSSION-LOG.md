# Phase 253: Fix Flaky CI and Preserve Required Checks - Discussion Log

> **Audit trail only.** Planning and implementation use `253-CONTEXT.md`. This log preserves the assumptions, research, corrections and tradeoffs.

**Date:** 2026-10-12/13
**Mode:** assumptions, with explicit user-directed specialist fan-out
**Decision authority:** User instructed the agent to synthesize coherent recommendations and automatically follow them. No unanswered confirmation was treated as approval; no menu answer was fabricated. This adopts planning decisions, not completed implementation.

## Initial Assumptions and Corrections

| Area | Initial assumption | Evidence and final disposition |
|---|---|---|
| Current failures | Check the recurring Test D label before selecting a fix. | Confirmed: Test D passed. Actual PR fast-check failure was metrics Test Z; its archive dependency is already repaired. Preserve historical outcomes and correct diagnosis separately. |
| Browser lead | No current browser flake was established by the shortlist or historical todo. | Deeper archive inspection found registration failures on Oct 11/12. Latest helper blob matches current source, and the failing project is dark Chromium. Investigate it; cause remains unknown. |
| Repeats | Three runs per seam are a plausible finite default. | Refined: three fresh targeted invocations per affected project plus each full seam once. Controlled positive/negative readiness tests provide stronger sequencing evidence at lower cost than fifteen full seam repeats. |
| Gate ownership | Add required unit smoke to internal ci-gate. | Confirmed current omission and downstream release use. Keep the five required names unchanged. |
| Browser completeness | Verify all five selected bodies and correct aggregate skip inventory. | Confirmed native matrix aggregate alone does not count the expected bodies; use small retained records and failure injection. |
| Hosted feasibility | A dispatch canary needs a registered workflow path. | Confirmed safe route: fixture-only definition at existing ci.yml path with a distinct name, separately pinned candidate helpers and a dedicated verifier mode. Final normal PR proof remains necessary. |

The assumed no-browser-lead path was superseded by stronger retained-source evidence. It was not saved as a locked decision. The old todo's WebKit-only premise and suggested timeout/auth reuse fixes were also superseded by current facts.

## Specialist Passes

- `phase253_assumptions`: current code, prior decisions, gate ownership and candidate research gaps; terminal result received.
- `phase253_gate_research`: official GitHub semantics, gate/skip coverage, artifact origin, permissions, hosted negatives and a final pre-merge feasibility check; terminal results received.
- `phase253_browser_research`: Playwright/Phoenix/Ecto readiness, account/database state, pinned tool versions, traces, repeat controls and DX; terminal result received.
- `phase253_diagnosis_research`: original failed-job logs, misleading labels, missing producer details, bounded failure extraction, source identity and repeat budgets; terminal result received.

All passes were read-only. No application test, GitHub API acquisition, CI dispatch or external mutation was performed. Official web documentation was researched. The parent waited for each foreground fan-out to finish before further task work.

## Compared Approaches

### Failure diagnosis

| Approach | Benefit | Footgun/tradeoff | Chosen disposition |
|---|---|---|---|
| Native tool result plus actual failed job/step and bounded context | Identifies executed failure and preserves original result | Needs small tool-specific interpretation and partial-data handling | Default; standard libraries only |
| First error/assertion keyword in whole log | Cheap | Passing banners, expected negative tests, unrelated steps and setup noise can win | Reject as authoritative; bounded fallback only with failed-step binding |
| Third-party flake service or opaque classifier | More aggregation | New dependency, cost and another trust boundary without enough data | Unnecessary |

Lessons from the retained archive: two passing Test D banners became a recurring signature; actual Test Z appeared near the end of roughly 96 KiB logs. Current sanitizer prefix caps can lose that location. Saving the first failed job's log also cannot establish completeness when a run has multiple failed producers. The original logs/outcomes remain unchanged.

### Gate transport and coverage

| Approach | Benefit | Footgun/tradeoff | Chosen disposition |
|---|---|---|---|
| Native matrix result and static expected matrix | Minimal wiring | Does not prove all expected selected bodies executed | Necessary inputs, insufficient alone |
| Shared matrix output key | Small | Last finishing child overwrites the value | Reject |
| Five distinct output keys | Lightweight and permission-free | Missing/terminal combination must be proven; less durable diagnosis | Serious runner-up, not the default |
| Small unique execution artifact per seam | Counts exact producers, body outcomes and omissions; replayable fixtures | Some upload/download work | Default using existing pinned actions |
| API queries inside every ordinary gate | Independent observations | Extra permission, requests and availability on merge-critical path | Use for independent phase evidence, not routine producers |
| Replace matrix topology | Explicit ownership | Duplicates wiring or changes performance before optimization | Defer |

GitHub documents the matrix overwrite behavior and accepts some skipped checks for enforcement; the project's body-execution requirement is therefore stronger than a green aggregate alone. These are documented semantics, while the selected record design is a project recommendation. [Matrix outputs](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#using-job-outputs-in-a-matrix-job), [required-check behavior](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks).

### Browser readiness, repeats and diagnostics

| Approach | Benefit | Footgun/tradeoff | Chosen disposition |
|---|---|---|---|
| Signal-controlled readiness plus real-server browser check | Proves sequencing and actual delivery separately | Fixture must hold the relevant transport and avoid fallback bypass | Default where the reproduction needs it |
| Larger timeout or retry | May accommodate legitimate measured progress | Can hide a missing action or repeat the failure without explaining it | No speculative increase; retries remain zero |
| Shared authenticated account | Less setup | Mutable backend/session state and changed registration coverage | Optimization phase unless indispensable to demonstrated cause |
| Scoped retain-on-failure trace | Captures initial failed attempt | Records successful attempts too before discarding them | Diagnostic/repeat override |
| Global tracing | Broad diagnostic coverage | Unmeasured cost across all jobs | Do not silently add |
| Three targeted fresh invocations plus one integration run per seam | Finite cost, focused regression evidence | Cannot prove absence of flakiness | Default, limitations explicit |
| Fifteen complete seam runs | More repetition | Much higher cost without a mechanically selected cause | Not justified |

Playwright actionability does not establish hydration readiness. LiveView's initial HTTP mount and connected mount are distinct. Ecto's owner/allowance pattern belongs to ExUnit; real browser apps use ordinary isolated databases. These native boundaries are preferable to another proxy/test dependency. [Hydration](https://playwright.dev/docs/navigations#hydration), [LiveView lifecycle](https://phoenix-live-view.hexdocs.pm/1.1.28/Phoenix.LiveView.html#c:mount/3), [Sandbox](https://hexdocs.pm/ecto_sql/3.14.0/Ecto.Adapters.SQL.Sandbox.html).

Playwright explicitly supports retain-on-failure for zero-retry diagnostics. Current local installed 1.62.1 differs from locked 1.59.1; execution must restore and observe the pinned version. Three separate invocations preserve ordinary scheduling better than a same-VM repeat loop or ExUnit trace mode. [Trace policy](https://playwright.dev/docs/trace-viewer#tracing-on-ci), [pinned trace implementation](https://github.com/microsoft/playwright/blob/v1.59.1/packages/playwright/src/worker/testTracing.ts), [Mix test options](https://github.com/elixir-lang/elixir/blob/v1.19.5/lib/mix/lib/mix/tasks/test.ex).

### Hosted probe feasibility

Use a scoped fixture definition at the registered ci.yml path, not a new unregistered dispatch filename or the production recapture exception. Keep fixture workflow identity separate from the candidate checkout. Its distinct name avoids observers listening for CI/release names; execution must recheck those bindings. A separate verifier dispatch can retrieve cancellation outcomes without changing the default branch's workflow_run observers. [Dispatch events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch), [dispatch API](https://docs.github.com/en/rest/actions/workflows#create-a-workflow-dispatch-event).

The six lightweight scenarios exercise real GitHub failure/cancellation/missing/skip behavior using candidate helpers. A synthetic PR classifier input must still record its actual dispatch event. A normal candidate PR run proves normal production names/owners. Dispatch checks cannot stand in for that result. [PR event eligibility](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks#checks-from-some-workflow-jobs-are-not-evaluated).

## Methodology and Stakeholder Lenses

| Lens | Question addressed | Result |
|---|---|---|
| Contributor/product DX | What failed, how can it be reproduced, what does the maintainer receive? | Native identity/command/project/seed/repeat index, original exit, safe trace and clear unresolved status |
| CI/SRE | Does green account for intended producers, and do real negatives stay red? | Fixed ownership, explicit skips, hosted cancellation and missing-producer probes |
| Elixir/Phoenix/Ecto | Which state and lifecycle does each test actually own? | Sandbox owners for ExUnit; isolated real app/DB and connection readiness for browser flows |
| Security/supply chain | Can untrusted records forge origin or expand privileges? | Source/run/artifact bindings, small validators, safe paths/redaction, no broad producer API token or new package |
| Performance/cost | How much proof is justified before speed work? | Targeted repeats and tiny canaries; no global trace or fifteen full suite repeats; Phase 254 keeps its comparison contract |
| Architecture/least surprise | Can established seams do the job? | Extend current metrics/gates/reporters/artifact actions; keep five seams and one mix ci owner |
| Adversarial verification | Would a broken waiter, omitted job, fake docs-only value or passing error banner fool the check? | Explicit negative fixtures and real hosted negative outcomes |
| Source identity/write-ahead state | Can the previous record be recovered and the tested source identified? | Exact Git read-back before tracking edits; immutable Phase 252 inputs and separate corrections |
| Accessibility/UI | Does this phase change product interaction or design? | No design work selected; roles/stable hooks and existing contracts apply if a proven fix touches UI source |

## Budgets and Limits

Budgets are locked in CONTEXT D-19 through D-23, independently of outcomes. Selection is at most three leads. Current registration is first. Added diagnosis is at most 60 requests/15 minutes; reproductions at most ten invocations/20 minutes per lead and 60 minutes total. Acceptance repeats are three fresh targeted invocations per affected project, plus each existing seam once. Canary is six scenarios, at most one infrastructure rerun, 45 tiny jobs/60 minutes/120 requests. Final normal PR proof reserves one family, at most one independently diagnosed infrastructure rerun, and its own capped 120-request/60-minute acquisition budget.

These are operational stopping limits, not statistical reliability guarantees. Missing selected evidence or reaching a limit leaves a diagnosis/requirement gap; it is not a waiver. The old source archive only contains bounded subsets of failed-job details, and diagnosis cannot claim global absence of flakiness. Trace retention is scoped and privacy-aware. All attempts remain visible.

## Todo and Scope Disposition

One existing todo already names resolves_phase 253. Its current investigation stays in scope; it remains pending. Unit-gate ownership and aggregate skip-model leads fall directly under CIREL-02, without importing unrelated todos. Per-shard parallelization and auth-state/cache/boot speed changes remain Phase 254; complete documentation/reporting stays Phase 255. No todo or requirement was closed during discussion.

## Next Route

After context creation, check `init.plan-phase 253`, then record `$gsd-plan-phase 253` in both state files and the handoff. No implementation, phase verification, CI mutation or auto-advance is included in discussion completion.
