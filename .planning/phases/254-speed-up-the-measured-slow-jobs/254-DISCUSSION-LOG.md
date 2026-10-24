# Phase 254: Speed Up the Measured Slow Jobs - Discussion Log

> Audit trail only. Planning and execution decisions are in `254-CONTEXT.md`.

**Date:** 2026-10-23
**Mode:** assumptions; user-delegated defaults after primary-source research
**Authority:** User requested subagent fan-out, pros/cons, relevant prompt research, adversarial review and coherent recommendations to follow automatically. No confirmation menu was needed for these internal defaults. No implementation or hosted acceptance was authorized by a fabricated menu answer.

## Analysis and recommendations

| Area | Recommendation | Confidence and evidence |
|---|---|---|
| Bottlenecks | Improve admin behavior and non-admin browser work together | Likely improvement path; `252-BASELINE.json` full sample has 367/333-second jobs, versus library 79 seconds. No proposed saving measured. |
| Browser preparation | Reuse auth only for eligible theme checks; remove redundant invitation login navigation | Likely; `admin-theme.spec.ts`, `organizations.spec.ts`, existing `admin-design.setup.ts`; preserve lifecycle and backend-state boundaries. |
| BEAM setup | Remove proven duplicate setup; evaluate one Mix preparation invocation | Likely; pinned setup-beam defaults/implementation, `mix.exs` alias, composite action. Failure propagation/cold-warm behavior still need implementation checks. |
| Caches | Preserve port/runtime isolation and OS/npm preparation; profile before redesign | Confident boundary; all measured caches hit; outer step buckets cannot resolve components. |
| Comparison | Retain fixed20pairs/40families/48hours, real PR endpoint, three independent thresholds and finite budgets | Confident locked method; `252-COMPARISON-CONTRACT.json`. 385seconds is n1, not a historical median. |
| Coverage | Preserve identities/projects/assertions and skip status, in addition to current native guards | Confident need; `ci-browser-records.mjs` permits some skips while proving selected-set completeness. |

## Alternatives considered

- Selective fixture reuse beats global saved sessions: global sessions would invalidate anonymous flows and can hide theme/backend-state assumptions. Fresh account preparation remains a conditional fallback where zero-state is necessary; no public bypass endpoint.
- Existing-job rebalance beats automatic extra shards: extra container/preparation costs67–107seconds in the observed sample, so new concurrency can violate runner-cost non-increase.
- Small preparation cleanup beats prebuilt images/cache redesign: current caches hit and compiled endpoint configuration is port-sensitive. Browser binary and npm download cache hits do not replace Linux libraries or `npm ci`.
- Frozen matched acceptance beats natural PR averages or manual dispatch: workload mix, failed partial jobs and event timing would answer different questions. Do not repair or silently substitute the frozen baseline.

## Specialist work

Four read-only agents returned terminal results: `phase254_analysis` (codebase assumptions), `browser_speed_research` (pinned Playwright), `setup_cache_research` (BEAM and caches), `comparison_adversarial_research` (measurement and failure controls). No agent changed files or dispatched hosted work. Relevant repository prompt: `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md`. Broad authentication-product/UI research was unnecessary for this CI phase.

## External research

- [Playwright1.59.1 auth](https://github.com/microsoft/playwright/blob/v1.59.1/docs/src/auth.md): new browser contexts isolate storage, not database mutations; auth files can impersonate accounts.
- [Playwright1.59.1 dependencies](https://github.com/microsoft/playwright/blob/v1.59.1/docs/src/test-projects-js.md#dependencies): primary selection can still execute setup dependencies; account for focused-run behavior and setup-only records.
- [Playwright CI caching](https://playwright.dev/docs/ci#caching-browsers): Linux browser dependencies remain separate from binary caches.
- [Pinned setup-beam action](https://github.com/erlef/setup-beam/blob/54075bcc5e249e4758d363f27d099f55d843f124/action.yml): Hex/Rebar install defaults enabled; pinned source was checked by setup researcher.
- [Mix task composition](https://hexdocs.pm/mix/1.19.5/Mix.Tasks.Do.html): one invocation avoids repeated completed tasks and aborts on an error. Savings require measurement.
- [GitHub cache reference](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching): exact/fallback distinction, immutable keys and PR cache scope matter to warm-pair feasibility.
- [GitHub concurrency](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency): superseded revisions may cancel current families.
- [NIST randomized blocks](https://www.itl.nist.gov/div898/handbook/pri/section3/pri332.htm): supports paired nuisance-factor control; the project's percentile formula remains the frozen nearest-rank choice.

## Corrections during synthesis

- Source check corrected an over-specific agent inference: failed `git show <sha>:<path>` does not establish a missing path when the commit itself is unavailable. Both frozen commits were initially absent locally. Authenticated GitHub commit reads found both with the same tree; scoped fetch retained exact application/producer refs. Fresh checks match the bundle SHA-256, both workflow digests and all six declared workload files in both sources. `254-BASELINE-PREFLIGHT.json` records the result. No source deletion/path absence claim is made. The first fetch hit the local Git write sandbox; an authorized escalation succeeded, with no auto-review rejection.
- Old roadmap prose contains backward Phase253 routes. Current state, completed verification and `init.plan-phase254` select Phase254; do not resume the old repair loop.
- No todo was folded in solely because the matcher assigned a high keyword score. The per-shard item is prior implemented work; unrelated release/UI/product items remain outside scope.

## Methodology applied

Applied automation-first checks, exact source identity, feasibility before dependent implementation, preservation, decisive defaults, minimal dependencies, consumer/contributor ergonomics and honest bounded measurement. Existing Phase253 history stays unchanged. No additional numbered repair recipes or copied historical ledger were created.

## Work performed and remaining

Discussion inspected files, consulted primary sources, recovered scoped exact baseline source refs and verified bundle/workflow/workload digests. No product changes, browser test execution, CI dispatch, cache warm-up or acceptance runs occurred. No requirement or phase verification was marked complete. Source recovery is resolved; candidate identity, cache preparation and baseline execution readiness still precede hosted collection. No user-supplied old release record is needed. Next command: `$gsd-plan-phase 254`.
