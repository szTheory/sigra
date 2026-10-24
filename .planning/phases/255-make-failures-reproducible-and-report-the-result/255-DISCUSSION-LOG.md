# Phase 255: Make Failures Reproducible and Report the Result - Discussion Log

> Audit trail only. Planning and implementation decisions are in `255-CONTEXT.md`.

**Date:** 2026-10-23 America/New_York (analysis continued into 2026-10-24 UTC)
**Mode:** assumptions; user-delegated researched defaults
**Areas:** contributor command parity; diagnostics/security/CI delivery; offline replay/reporting
**Capture boundary:** `7ff20056b69e2a716b322d8a0415f9a818ecec91`

## User direction

After four initial recommendations were presented, the user requested a sanity check using parallel, adversarial reviews across relevant stakeholder and technical roles, reputable primary sources where useful, and a coherent set of defaults to follow automatically. They prefer small repository-local helpers and a flatter dependency tree. This answered the assumption gate by delegating the final choices; no second confirmation menu was needed. It did not authorize implementation, hosted acceptance or a replacement benchmark.

## Initial assumptions and review outcome

| Area | Initial recommendation | Confidence after review | Result |
| --- | --- | --- | --- |
| Contributor commands | Keep `mix ci`; document focused browser commands and setup | Confident boundary; likely helper shape | Retained; require actual receiver execution, explicit environments/prerequisites and exact CI selection parity |
| Failures | Give exact command/test, seed and retained logs/traces | Confident need; likely invocation-level tracing | Retained; scope first-failure tracing, preserve primary exits and capture pre-browser failures/server logs |
| Comparison | Replay saved inputs; keep insufficient-data outcome | Confident | Retained; require portable preserved inputs and separately pinned repaired calculator/helpers |
| Guide/report | Concise guide and report, automatic proof, separate bounded hosted diagnostic if needed | Confident boundary | Retained; test real contributor behavior and source-bound artifact retrieval; keep performance claims unaccepted |

## Parallel reviews

Three read-only `gsd-assumptions-analyzer` agents ran with the resolved `gpt-6.1-sol` model and `xhigh` effort. The user explicitly requested fan-out. Agents owned separate review areas and made no repository edits or hosted calls.

### Contributor and Elixir/CI parity

- `CONTRIBUTING.md` still describes deterministic browser work as CI-only and suggests unrestricted `npm test`; it lacks complete isolated database/server preparation.
- `test/example/config/dev.exs` requires `CI=true` for the dev server to disable reloading. Setting it only on Playwright is insufficient. The compile-time and runtime endpoint port must agree.
- Example `PG*` configuration and library `SIGRA_TEST_PG_*` configuration must be distinguished. Never run the example reset alias against a contributor's inherited database.
- Cold checkout formatting can need dependencies before the alias's fetch step. Missing pinned `phx_new` can exclude upgrade tests. Guidance must verify intended coverage actually runs.
- Mix alias argument forwarding and once-per-process task execution make a seed appended to `mix ci` and textual alias assertions insufficient proof of execution. Observe each intended receiver before claiming the seven-leg contract.

### Diagnostics, security and CI operations

- Zero retries plus `on-first-retry` leaves first-attempt failures without traces. Prefer invocation-scoped `retain-on-failure`; passing tests still incur recording overhead.
- The server log is printed but omitted from the shard diagnostic upload. The completed-test JSONL reporter cannot by itself diagnose dependency/configuration/discovery/browser-launch failures.
- Browser steps can execute after boot failure because they use `!cancelled()`. Keep the boot failure primary and later browser/report errors secondary.
- Authentication storage can exist below diagnostic roots, but existing hidden-file defaults do not prove an upload leak. Use explicit staging/exclusion and archive-content checks. Traces can themselves contain sensitive request/page content.
- Preserve sequential invocation output before another HTML reporter clears its directory. Bind retained files to the run attempt as well as the run/seam/source.
- An isolated canary is required for changed hosted success/failure/cancellation delivery. It gets a separately frozen finite budget during planning; historical allowances remain closed. A hard-killed runner may be unable to finalize/upload diagnostics.

### Replay, measurement and reporting

- Saved raw directories are present locally but ignored/untracked. A clean checkout needs an accessible exact-byte package or scoped refs plus safe materialization and hash verification.
- Review verified receipt hashes for 69 baseline paths and 109 candidate paths and resolved these local preservation identities:
  - `refs/evidence/phase254-measurement-pair-01-before-attempt-2` → `1c1cc0f786e52cacddb8e69a07a5855c0b74045c`
  - `refs/evidence/phase254-measurement-pair-01-after-attempt-2` → `5df0b52e9773364de9fa1aa8a37b831133c56600`
- Local ref existence does not establish availability to another maintainer. Planning must establish the distribution/materialization path rather than assume it.
- Read-only cost derivation exactly reproduced the saved 2046-second failed baseline and 1589-second successful candidate objects. No successful comparable pair exists. The candidate's individual 261-second wait is not a paired median or speed result.
- Captured metrics script hash: `479ea27c7f4ff63b544e1687b2427568e766a16929a4f6630f028eb926478b3d`. Repaired analysis script hash at capture: `2a4e54049575a3ab2ed14865e1051bcac19beda0e083061dfd71ba68f92876d8`. Commit `d5b7300c809ce7cd474e87aa55fda278b3a09cbc` repairs null-family handling and retains failed/unpaired cost. Bind analysis source separately from measured source and include transitive helpers/fallback timing data.
- The evaluator exits 0 when it successfully generates `insufficient_data` JSON. A replay check must assert the result fields; successful generation cannot become a passed speed target.
- The failed baseline lacks successful-family metadata. Generic identity-mismatch diagnostics must be explained as missing qualification data, not automatically as changed raw source. The single materialized candidate's origin check is not proof that both observations qualified.

## Small independent process probe

To investigate the alias warning without running any Sigra tests, database, dependency fetch or acceptance, the parent created and removed a standalone temporary Mix project. It used the pinned Elixir `1.19.5-otp-28`, Erlang `28.5` and `MIX_ENV=test`.

The aliases were:

```elixir
ci: ["test test/first_test.exs", "ci.second"],
"ci.second": ["test test/second_test.exs"]
```

Each file contained one passing test printing a distinct marker. Running `mix ci` produced:

```text
PHASE255_FIRST_EXECUTED
1 test, 0 failures
{"exit_code":0,"first_executed":true,"second_executed":false}
```

This establishes the pinned-runtime alias risk. It does not establish Sigra's actual scaffold execution or change any historical coverage result. Context D-02 requires that narrower repository observation and a scoped fix if needed.

## Primary sources and tradeoffs

- [Pinned Mix source](https://github.com/elixir-lang/elixir/blob/v1.19.5/lib/mix/lib/mix.ex): aliases and argument forwarding; inspected local pinned `mix/task.ex` as well. Shared command definitions reduce drift; a generic runner/framework would add needless coupling. Default: small shared seams with real process checks.
- [Playwright trace viewer](https://playwright.dev/docs/trace-viewer) and [use options](https://playwright.dev/docs/test-use-options): `retain-on-failure` supports zero retries and records passing runs before discarding traces. Default: affected invocations only, measured/disclosed cost. Avoid newer options absent from lockfile version 1.59.1.
- [Playwright authentication](https://playwright.dev/docs/auth): stored cookies/headers are sensitive; contexts do not solve shared backend mutation. Default: fresh owned state and explicit safe diagnostic staging.
- [GitHub status expressions](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions): distinguish failure/cancellation and reserve `always()` for bounded recording/cleanup, not expensive setup.
- [GitHub artifact lifecycle](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts): deleting runs deletes artifacts. Default: bounded transient diagnostic retention plus separate preserved final replay inputs.

The versioned HexDocs Mix URL was unavailable through the browser; pinned GitHub/local source resolved the semantics instead. Broad ecosystem research and irrelevant UI/graphics roles were unnecessary. Further fan-out would repeat the same command, artifact and truth boundaries.

## Methodology applied

Automation-first verification drove real receiver, browser, exit-status and artifact retrieval checks. Source identity drove separate application/workflow/analysis identities and clean-checkout replay. Decisive defaulting favored small existing helpers and primary-source-supported trace behavior. Truthful reporting preserved the terminal insufficient-data result and distinguished later development proof. Recovery lessons ruled out new repair-plan/count migrations and renewed budgets.

## Preservation and route

All planning paths were clean at the capture boundary. Before any state mutation, the parent verified exact `HEAD:path` read-back for `.planning/STATE.md`, `.planning/state.json` and `.planning/HANDOFF.json` at `7ff20056b69e2a716b322d8a0415f9a818ecec91`. Their SHA256 identities were respectively `bae96fcfb9a2c3b0389bff632d9e4f05c3f6aabdc5def9712307ddfb595c0581`, `b4dc4ecc9a574e0cf362fbcce4395d8d824a117a5314ef976ab9315bf7fa1719`, and `d3facd0f3f3fe597230a994063d4bd0c546887a3ad3dbb9a2b74ae206ab4b732`. No dirty planning revision required separate preservation. Unrelated untracked Python bytecode was untouched.

`init.plan-phase 255` reported Pending, CIDX-01/02 and CIMEAS-03, no existing context/research/plans and no prerequisite blocker. Recheck after capture before reporting `$gsd-plan-phase 255`. Discussion does not complete implementation or phase verification. Phase 254's closed comparison and open speed requirements remain unchanged. No backlog item was promoted or closed.
