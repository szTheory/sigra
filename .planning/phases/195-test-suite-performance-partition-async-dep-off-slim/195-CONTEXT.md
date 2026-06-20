# Phase 195: Test-Suite Performance (partition / async / dep-off slim) - Context

**Gathered:** 2026-06-20 (assumptions mode + deep subagent research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the two heaviest Elixir test poles faster with **identical quality signal and no
new flake**, by attacking them four ways (TEST-01, TEST-02, TEST-03, CACHE-03):

- **`library_tests`** (~16m): partition via `mix test --partitions N` across DB-isolated
  parallel shards.
- **`library_tests_dep_off`** (~14m): run a targeted subset that proves the Threadline-absent
  compile/guard paths instead of re-running ~the whole suite.
- **`async: true` audit:** convert safe modules, keep global-state mutators serial, keep
  sandbox/pool config correct under partitioning.
- **Larger runners:** apply only if a recorded before/after measurement justifies it.

**In scope:** `.github/workflows/ci.yml` topology for these two jobs, a new test moduletag +
a `mix` alias, a small conservative set of `async: true` flips, a documented async-safety rule,
and a measurement-gate runbook. **Out of scope:** the Playwright pole (Phase 197), the PR-fast
vs nightly trigger model (Phase 196), any feature/runtime/migration code, coverage tooling
(none exists today).

**Honest framing (cross-cutting):** After Phase 193's CRIT-01 fix, `example_playwright_smoke`
(~22m) — **not** `library_tests` — is the wall-clock pole. So Phase 195's measurable win is
**these two jobs' own durations + billed-minutes dropping with equal signal**, plus de-risking
them as *future* poles (once Playwright is parallelized in 197) and keeping the PR gate honest.
Do **not** over-shard chasing a PR wall-clock number that Playwright still bounds until 196/197.
</domain>

<decisions>
## Implementation Decisions

### TEST-01 — Partition `library_tests` (matrix shards + name-preserving aggregator)

- **D-01:** Split `library_tests` into a **matrix shard job** `library_tests_shard`
  (`name: Library tests shard ${{ matrix.partition }}`, `strategy.matrix.partition: [1, 2]`,
  **`fail-fast: false`** so one shard failing does not cancel the other). Each leg keeps its
  **own** `services.postgres` container and runs
  `MIX_TEST_PARTITION=${{ matrix.partition }} mix test --partitions 2` (keep `--slowest 10`
  + the per-shard `$GITHUB_STEP_SUMMARY` observability from Phase 193).
- **D-02 (required-check preservation — HARD):** Add a **new thin aggregator job, id
  `library_tests`, `name: Library tests`** — the byte-identical protected required-check name
  (Phase 194 D-01/D-02, ruleset 14941512). It `needs: [library_tests_shard]`, runs
  `if: always()`, and its only step **fails unless `needs.library_tests_shard.result == 'success'`**.
  Rationale: a bare matrix on a job named `Library tests` yields checks `Library tests (1)` /
  `(2)` — never a bare `Library tests` — which would orphan the required check (stuck pending →
  merge outage) and break `ci-gate`'s `needs.library_tests.result`. The aggregator is what the
  ruleset sees and what `ci-gate` references.
- **D-03:** **`ci-gate` keeps `needs: library_tests` and `LIBRARY_TESTS:
  ${{ needs.library_tests.result }}` verbatim** — the aggregator reuses the job id `library_tests`,
  so no `ci-gate` rewiring. Do **not** add `library_tests_shard` to `ci-gate.needs` (the
  aggregator already gates it; adding both double-counts).
- **D-04:** **N = 2.** Each shard is its own 2-core runner (2N effective cores), but pays
  ~2-3m fixed cost (spin-up + `deps.get` + compile + `ecto.setup` + phx_new archive). N=2 ~halves
  the ~14m test portion to ~9-10m wall-clock; N≥3 buys diminishing test-time for multiplied fixed
  cost — and since Playwright ~22m is the real pole, pushing below ~9m yields zero PR wall-clock
  gain. Revisit N only if Playwright is later parallelized below ~9m.
- **D-05:** **DB isolation is automatic** via per-leg Postgres containers (static `sigra_test`
  name is fine). **No `MIX_TEST_PARTITION`-suffixed DB name, no Ecto config change.**
- **D-06:** **Cache key keeps the Phase-194 shape exactly; the partition is NOT in the key**
  (deps/`_build` are identical across legs → both share one warm `-library-` cache entry).
  Partition-keying would split the warm cache and double cold-compile cost.
- **D-07:** **Move `mix docs --warnings-as-errors` OUT of the shard into the existing
  `fast_checks` job** — it is a single artifact; running it per-shard is N× cost for zero gain.
- **D-08:** **No coverage merge** — no ExCoveralls / `:test_coverage` in `mix.exs`; "merge
  coverage if applicable" is a no-op. Forward note only: if coverage is ever added, each shard
  runs `mix coveralls --export-coverage shard-${MIX_TEST_PARTITION}` and a dedicated merge job
  imports all shards — that merge job carries the threshold, not the shards.

### TEST-02 — Slim `library_tests_dep_off` (keep compile proof, tag behavioral subset)

- **D-09:** **Keep the `mix compile --warnings-as-errors --no-deps-check` step** (after
  `deps.unlock threadline` + `deps.clean threadline --build`) **exactly as-is** — it is the
  load-bearing assertion that the `Code.ensure_loaded?(Threadline)` wraps compile with the dep
  absent. Belt-and-suspenders: keep the full compile-without-dep proof, slim only the test RUN.
- **D-10:** Introduce a new **`@moduletag :threadline_guard`** on the ~7 guard-exercising test
  modules and change the lane's final step from `mix test --exclude requires_threadline
  --no-deps-check` to **`mix test --only threadline_guard --no-deps-check`**.
- **D-11:** **Tag-based selection (not enumerated ci.yml paths, not a directory glob).** Decisive
  reason: `mix test --only <tag>` **fails the run on zero matches**, so a dropped/renamed tag turns
  CI **red, not silently green** — the trust property a dep-off lane needs. The tag is greppable
  (`grep -rl threadline_guard test/`) and self-maintaining (a new guard test is picked up the
  moment it's tagged). Matches the existing `:requires_threadline` tagging idiom.
- **D-12:** **Keep `:requires_threadline` on `test/sigra/audit/forwarders/threadline_test.exs`**
  (it needs the dep *present*) — it is the inverse tag and is auto-excluded by `--only
  threadline_guard`. Verify that module is NOT also tagged `:threadline_guard`.
- **D-13:** The slimmed subset **MUST still assert** (non-negotiable coverage): (a) library
  compiles with `:threadline` absent [compile step, D-09]; (b) `threadline_available?/0` returns
  `false` (the `optional_deps_test.exs` `== Code.ensure_loaded?(Threadline)` canary); (c) boot
  degrade path — `attach_forwarders/0` skips the absent forwarder and emits exactly one
  `Logger.warning` (`application_forwarders_test.exs`); (d) no `apply/3`-to-absent-module crash in
  the worker/dispatch path; (e) `mix sigra.doctor` reports `threadline: false` without crashing.
- **D-14:** **Add a `mix sigra.dep_off` alias** (`deps.unlock threadline` → `deps.clean
  threadline --build` → `compile --warnings-as-errors --no-deps-check` → `test --only
  threadline_guard --no-deps-check`). The CI lane **calls the alias** rather than re-listing
  steps, so local repro (`MIX_ENV=test mix sigra.dep_off`) and CI cannot drift. Document it in the
  local-development guide.

### TEST-03 — async audit (conservative; documented rule is the deliverable)

- **D-15:** **Conservative, inspection-driven conversion (not a bulk flip).** Convert to
  `async: true` ONLY files that pass the async-safety checklist with zero global-state smell
  (realistically a handful — candidates include `test/sigra/auth_plain_map_regression_test.exs`
  and `test/sigra/passkeys/rate_limit_test.exs`). Measure, then stop. A bulk flip is disqualified
  by the hard zero-new-flake criterion (it surfaces unsafe tests probabilistically).
- **D-16:** **Keep legitimately-serial modules serial** — serial there is correctness, not debt:
  subprocess-spawning install/upgrade tests (`Sigra.Install.*`, `Sigra.UpgradeIntegrationTest`),
  durable-DDL tests using `checkout_repo!`/`unboxed_run`, global `:telemetry`-handler tests, and
  `Application.put_env`/`System.put_env` mutators.
- **D-17:** **Ship a documented "is this test allowed to be `async: true`?" checklist** in
  CONTRIBUTING / test docs — this is the lasting value. A module is async-safe only if it touches
  NO shared mutable global state (Application/System env, `:persistent_term`, named ETS, named/
  singleton processes, global telemetry handlers, fs/cwd/temp-dirs/archives), does DB access
  **sandboxed-only** (no durable un-sandboxed DDL), uses **private-mode Mox only** (no
  `set_mox_global`), and keeps state process-local. Standardize the existing `# async: false
  because <reason>` comment convention.
- **D-18:** **Sandbox `shared: not tags[:async]` is correct as-is — do not change it.**
  `pool_size: 4` stays (sufficient for `max_cases=4`; only bump if a future change raises
  `max_cases`, in the same change). Partitioning does NOT affect sandbox correctness (each shard
  is an independent process/connection against its own PG container).
- **D-19:** **No proactive module-splitting.** The must-stay-serial modules are serial for DDL/
  telemetry/subprocess reasons, not size — splitting yields two still-serial modules (churn, zero
  parallelism). Only act if per-module timing later flags a specific oversized module that is
  serial for no good reason — and the fix for that is making it async (D-17), not splitting.
- **D-20 (honest payoff):** The async audit is a **small lever** next to partitioning — 186
  async modules already saturate `max_cases=4`; the serial tail (subprocess/DDL tests) is the real
  pole and is not async-convertible. Do the safe cleanup + the checklist; do not over-invest.

### CACHE-03 — larger runners: do NOT adopt (measurement-gated exception only)

- **D-21:** **Stay on `ubuntu-latest` (free, 2-core) for every job. Do not adopt larger
  runners.** Verified billing fact (GitHub Docs, June 2026): larger runners are **billed
  per-minute even on public repos and do not use included minutes**, while standard runners are
  **free/unlimited on public repos**. 2 free standard shards = 4 cores at $0/min; one paid 4-core
  runner = 4 cores at ~$0.012/min — sharding on free standard runners strictly dominates for
  parallelizable work.
- **D-22:** **Revisit larger runners ONLY if** a pole is genuinely un-shardable **AND** on the
  critical path, **OR** GitHub's concurrency cap blocks adding standard shards — **AND** a recorded
  before/after measurement passes the gate. **Decision rule:** adopt only if the job is on the
  critical path, Δwall-clock is material (≥30% on that job), the run-level wall-clock actually
  drops (not masked by another pole), and the recurring $/min is accepted. Otherwise reject.
- **D-23:** **Ship a short measurement-gate runbook** (baseline from 193-BASELINE.md → A/B one
  job on a larger label ×3 runs → measure wall-clock + billed-minutes + cache-hit → apply decision
  rule, record the before/after table). `mix docs` and any future coverage-merge job run on
  standard runners (cheap, not core-bound).

### Claude's Discretion
- Exact aggregator shell (`if [[ "$SHARDS" != "success" ]]; then exit 1`), step ordering, and
  comment wording are implementation details for the planner/executor.
- Final list of `async: true` conversions is whatever passes the D-17 checklist on inspection —
  the two named candidates are a floor, not a cap.
- Where exactly the async checklist (D-17) and dep-off alias (D-14) get documented
  (CONTRIBUTING vs `guides/recipes/local-development.md` vs CLAUDE.md) is the planner's call.

### Folded Todos
None — no matched todo was in scope (see Deferred Ideas).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 195 definition, key tasks, success criteria, and the
  zero-human-UAT verification mechanism (CI measures itself vs the 193 baseline).
- `.planning/REQUIREMENTS.md` — TEST-01, TEST-02, TEST-03, CACHE-03 acceptance language;
  BASE-02 evidence requirement.
- `.planning/phases/193-baseline-observability-one-line-wins/193-BASELINE.md` — **ground-truth
  before-state.** Every Phase-195 speed/flake claim diffs against this (per-job durations, 2-core
  `schedulers_online`/`max_cases=4` evidence, slowest-tests, critical path, CRIT-01 reality).
- `.planning/phases/194-caching-correctness-micro-job-consolidation/194-CONTEXT.md` — **D-01/D-02
  (protected required-check names incl. `Library tests`; re-read live ruleset 14941512 at
  execution time), D-04/D-05 (cache-key shape + namespaces), D-11 (`fast_checks` job that now
  receives `mix docs`).**
- `.github/workflows/ci.yml` — current `library_tests` (~172-247), `library_tests_dep_off`
  (~249-323), `fast_checks` (~48), and `ci-gate` (~1218-1260) job definitions.
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — CI/CD + optional-dependency
  test-lane idioms (compile-without-dep proof + tagged behavioral subset).
- `prompts/elixir-best-practices-deep-research.md`,
  `prompts/ecto-best-practices-deep-research.md` — ExUnit async + Ecto SQL Sandbox
  (`shared: not tags[:async]`) authoritative idioms.
- **Live ruleset (execution-time, MANDATORY re-read):** `gh api repos/szTheory/sigra/rulesets/14941512`
  — confirm `Library tests` is still the required string before merging the aggregator rename.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`fast_checks` job (Phase 194 D-11)** already consolidates leaf guards on a general
  2-core runner — the natural home for the relocated `mix docs --warnings-as-errors` (D-07).
- **`ci-gate` aggregator pattern** already exists; the new `library_tests` aggregator (D-02)
  is the same pattern, narrowly scoped to keep the protected name bare.
- **Phase-193 `$GITHUB_STEP_SUMMARY` observability blocks** (`if: always()` shell steps) are
  the template for per-shard timing summaries.
- **`Sigra.Test.PostgresCase`** already implements `shared: not tags[:async]` — correct under
  partitioning, no change needed (D-18).
- **`:requires_threadline` moduletag** (on `threadline_test.exs`) is the existing precedent the
  new `:threadline_guard` tag mirrors (D-10/D-11).
- **`mix.exs` aliases** already exist — the home for the new `sigra.dep_off` alias (D-14).

### Established Patterns
- Every CI job declares its own `services.postgres` container (static `sigra_test` DB) — so
  matrix legs get DB isolation for free (D-05).
- Cache keys carry OTP+Elixir identity + `-v1` buster, namespaced (Phase 194 D-04/D-05) —
  the partition shard reuses the `-library-` key unchanged (D-06).
- Optional-dep coupling is guarded by `Code.ensure_loaded?(Threadline)` /
  `threadline_available?/0` (`lib/sigra/optional_deps.ex`) with a Noop fallback forwarder
  (`lib/sigra/audit/forwarders/`).

### Integration Points
- `ci-gate.needs` → `library_tests` (id preserved by the aggregator; no rewiring — D-03).
- Branch-protection ruleset 14941512 → status check string `Library tests` (the aggregator's
  `name:` must stay byte-identical — D-02).
- `mix sigra.dep_off` alias ↔ the dep-off CI lane (lane calls the alias — D-14).
</code_context>

<specifics>
## Specific Ideas

- **Local shard repro DX:** `MIX_TEST_PARTITION=2 mix test --partitions 2` reproduces CI shard 2
  exactly — document in the shard job comment + local-dev guide (a first-class DX win over today).
- **Dep-off one-command repro:** `MIX_ENV=test mix sigra.dep_off` (D-14).
- ExUnit `--partitions` distributes **by file, round-robin after sorting**; the ~11 subprocess
  install/upgrade tests (23-33s each) can clump unevenly onto one shard — accept at N=2, watch in
  the execution-time shard-balance probe; do NOT reflexively jump to N=4.
</specifics>

<deferred>
## Deferred Ideas

- **Timing-based shard balancing** (Knapsack/CircleCI-style) — only if N=2 shards prove >20%
  imbalanced; Mix has no native timing split, not worth the complexity for a non-pole job now.
- **ExCoveralls + partitioned coverage merge** — no coverage tooling exists today; forward-noted
  in D-08, not built this phase.
- **Playwright pole parallelization / spec sharding** — Phase 197.
- **PR-fast vs nightly-broad trigger model** — Phase 196.

### Reviewed Todos (not folded)
All 5 phase-matched todos are keyword false-positives (admin-UI/design-test, not CI-perf):
- `admin-design-mg5-6-content-equivalence-data-dependent` — admin Playwright data dependency; not
  about partition/async/dep-off.
- `token-reference-completeness-ci-guard` — admin token-reference doc guard; unrelated lane.
- `page04-branding-explicit-scoring` — admin quality-ledger scoring; out of scope.
- `uat-demo-dx-polish-nits` — UAT demo DX; unrelated to the test poles.
- `page04`/branding — admin UI. None folded; all remain open in their own backlog.
</deferred>
