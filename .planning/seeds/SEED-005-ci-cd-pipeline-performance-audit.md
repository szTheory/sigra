# SEED-005 — CI/CD Pipeline Performance Audit (reduce ~17–30 min PR wall-clock)

**Status:** OPEN — future milestone candidate. Filed 2026-06-18 during the v1.39
DS-COHERENCE + Docker DX ship (PR #54).
**Priority:** Medium-High — pure DX / PR-feedback latency, **not** a correctness bug. CI is
green and trustworthy; it is just slow. Schedule as a "Maintenance / trust (CI / DX)" lane
milestone, not a hotfix.

## Problem
PR #54's CI wall-clock runs **~17–30 min**, which is too long for fast developer feedback.
The pipeline is correct and the gate model is sound — the goal is to make it **fast,
deterministic, resource-efficient, and contributor-friendly** without dropping high-value
signal or trading trust for speed.

## Grounded baseline (gathered read-only 2026-06-18 from `ci.yml` + runs `27783442056` / `27785703122`)

- **One workflow** `.github/workflows/ci.yml`, **22 jobs**, all `ubuntu-latest` (2-core
  hosted). A single `ci-gate` aggregator already `needs:` 10 lanes → clean single required
  check. **Keep that pattern.**
- **Long poles (the critical path):**

  | Job | ~Duration | Notes |
  |-----|-----------|-------|
  | `library_tests` | **~16m** | plain `mix test` (whole suite, **no `--partitions`, no `max_cases`**) + `mix docs --warnings-as-errors`. Suite = **274 test files, 186 `async: true` / 27 non-async**. |
  | `library_tests_dep_off` | **~13m35s** | **re-runs the full suite** with `:threadline` removed — only needs to prove `Code.ensure_loaded?` compile/guards work. |
  | `example_playwright_smoke` | **~8–13m** | boots full Phoenix app + browser. |
  | `generated_admin_playwright_smoke` | **~8m** | scaffolds + boots generated host + browser. |
  | everything else (install matrix ×4, smokes, golden, upgrade, guards) | **<5m** | |

- **No PR-fast vs nightly-broad split** — every PR pays for `upgrade_smoke`, `install_matrix`
  (4 flag combos), both Playwright lanes, and the dep-off full rerun.
- **No Elixir/OTP version matrix** (single version). Only `playwright-github-pages.yml` has a
  `schedule:` cron (daily 06:45) — there is **no nightly lane for code/compat tests**.
- Several **micro-gate jobs** (`release_ref_guard`, `milestone_verification_gate`,
  `installer_milestone_audit`, `getting_started_uat_contract`, `phase_34_uat_contract`,
  `snapshot_drift_guard`, `quality_ledger_monotonic`) each spin a fresh runner for seconds.

## Candidate optimization theses (for the audit milestone to validate with evidence)
1. **Partition `library_tests`** — `mix test --partitions N` across parallel shard jobs (each
   with its own PG database); 186 modules are already `async: true`. Likely the single biggest
   win. Mind: per-partition DB isolation, coverage merge, don't oversubscribe a 2-core runner.
2. **Slim the dep-off lane** — run a **targeted subset** that actually exercises the
   Threadline-absent compile/guard paths instead of rerunning the entire ~13m suite.
3. **PR-fast vs nightly-broad split** — move exhaustive/low-probability coverage (full install
   matrix, upgrade smoke, broad Playwright galleries) to a `schedule:`/main lane; keep a fast
   representative gate on PRs. Never let a correctness-critical test live *only* on nightly.
4. **Playwright lanes** — share app boot/setup; consider sharding or moving heavier galleries
   to nightly; ensure deterministic readiness (no `Process.sleep`).
5. **Larger runners only for the long poles** — measure `System.schedulers_online()` first;
   2-core hosted under-serves a 186-async-module suite. Apply selectively if cost/speed justifies.
6. **Consolidate micro-jobs** — fold the trivial guard jobs into one cheap "fast checks" job to
   cut per-job runner startup overhead, while preserving stable required-check names.

### Session-discovered evidence (2026-06-19, debugging PR #54)

Three concrete, repo-specific findings surfaced while getting the v1.39 ship green —
ground truth that sharpens the theses above:

1. **The ~25m critical path is a job-level SERIALIZATION, not just slow jobs (likely #1 win).**
   `example_playwright_smoke` declares `needs: [release_ref_guard, library_tests]`
   (`.github/workflows/ci.yml`), so the two longest jobs run **sequentially**: `library_tests`
   (~16m) must finish before the full-lifecycle Playwright lane (~9m) even starts. The
   Playwright lane boots its own example app + Postgres service and consumes **no** output
   from `library_tests`, so that `needs` edge appears gratuitous. Dropping it (keep only
   `release_ref_guard`) likely cuts wall-clock from ~25m toward ~16m for one-line change —
   evaluate first.

2. **Fail-fast inside a multi-step job hides downstream failures (DX + iteration-cost tax).**
   `example_playwright_smoke` runs ~6 sequential `npx playwright test` steps in one shared
   booted app; a failure in an early step masks all later steps. This session that cost
   **3 full ~25m CI round-trips** to surface three independent stale assertions in ONE spec
   (`admin-user-operations.spec.ts`), then a 4th round-trip to surface the design-gallery
   step. Weigh splitting these seams into parallel jobs, or a run-all-then-report harness
   (`--max-failures=0` + aggregate), against the current one-shared-boot cost saving.

3. **Visual-snapshot lanes are environment-fragile and were never CI-validated.**
   The net-new admin-design gallery boards hard-fail on image *dimension* mismatch — CI's
   dev-mode boot renders boards ~20–53px taller than the local capture harness (brand
   webfont almost certainly not loading → fallback line-heights). Now demoted to
   `continue-on-error` and tracked in **`SEED-006`**. The audit should treat gallery lane
   placement (PR vs nightly) and deterministic visual capture (font load + in-CI recapture)
   as in-scope.

P-levels, tradeoffs, patches, and the broader audit (caching keys, `mix test --slowest`,
dialyzer/credo decisions, matrix/trigger redesign, security/release hardening) are the audit
milestone's job — see the companion playbook embedded below.

## Scope guardrails (preserve verbatim — Jon's intent)
- **Keep the high-value tests.** Demote or delete **only** the lowest-signal / redundant /
  flaky / over-scoped checks — and only with evidence, never on vibes.
- **Deterministic and reliable gates.** No flake; do not "fix" flake by blanket retries
  (retry is a temporary quarantine tool, not a root fix).
- **Cache correctly.** Caching is fine — do it right (precise keys, no stale `_build` reuse
  across incompatible OTP/Elixir/MIX_ENV, never skip `deps.get` after a partial restore).
- **Never trade trust for speed.** Any change that makes CI faster but less trustworthy must
  be labeled a tradeoff and moved to an optional/nightly tier.
- **Keep it simple.** Use all runner cores intelligently *without* a Rube Goldberg pipeline.
- **Great contributor DX.** Provide a single local `mix ci` (or `make ci`/`just ci`) that
  mirrors CI; document it in CONTRIBUTING; make failures obvious and reproducible.
- **High quality, maintainable, fast/deterministic/bulletproof specs.**

## How to run this (when it becomes a milestone)
Use `/gsd-new-milestone` (or a planned phase) and drive it with the verbatim companion
prompt below. It is a deliberately exhaustive multi-lens playbook ("boil the ocean" with
subagents) — measure-before-optimize, classify tests by value, produce prioritized
recommendations + concrete patches as stepwise PRs.

## Acceptance (for the eventual milestone, not this seed)
- Measured before/after PR wall-clock + p95, cache hit-rate, flake/rerun rate, top slow tests.
- PR feedback meaningfully faster (target: well under the current ~17m) with **equal or
  greater** quality signal on the required gate.
- A documented local `mix ci` equivalent; required-check names stable; no hidden risk.

## Pointers
- Baseline source: `.github/workflows/ci.yml`; PR #54 runs `27783442056` / `27785703122`.
- Related: `[[reference_sigra_docker_dx]]` (the Docker DX overhaul that landed alongside this);
  `SEED-004` (phx_new pin — a CI determinism decision the audit must respect);
  `SEED-006` (admin-design gallery CI fragility — the gallery lane's placement and
  deterministic visual capture are part of this audit's surface).
- Registered as a future strategic-bet candidate in `.planning/MILESTONE-ARC.md` (Candidates → `### future-idea`).

---

## Companion execution playbook (preserved verbatim — Jon's prompt, 2026-06-18)

Jon's framing:

> capture this idea for maybe next GSD milestone or whatever b/c this CI is too long we can
> probably parallelize it taking advantage properly of cores on the github action runner
> etc... or maybe there are some other efficiency gains we can do...
>
> audit our ci/cd pipeline make sure it's as efficient as possible, great DX also important
> and efficient so like not wasting our time or CI runner time
>
> but yeah we want to keep the high value tests just dropping the lowest quality ones,
> poorest quality least value. i think it's nice to be able to boil the ocean especially
> with AI/LLM help nowadays i'm just saying i want to identify bottlenecks and clean them up,
> make sure things aren't flaky, that they're reliable deterministic as possible gates,
> consider the hat/lens of someone who is trying to optimize for all this all the things they
> might come up with be very comprehensive we want to address each of them systematically
>
> also making sure we're using all of the cpus/cores on our github runners max efficiently
> while keeping it simple (at least, not overcomplicating it), speedy feedback for developer
> great DX efficient runtime reliable avoiding pitfalls with caching (caching is fine but do
> it right), we like fast/deterministic/reliable/bulletproof specs... high quality maintainable
>
> goal would be to reduce CI time b/c 17 min is too long we can probably optimize the pipeline
> significantly

---

## Addendum 2026-06-20 — Playwright parallelization is the #1 unrealized win (phase-197 evidence)

Jon, re-raising during the v1.40 ship (PR #58): **"that playwright time is way too
slow we should be able to parallelize it somehow."** This sharpens thesis #4 with
ground truth discovered while executing/verifying **Phase 197** (Playwright Lanes &
Design-Gallery Re-Gate):

- **Phase 197 did NOT meaningfully cut Playwright wall-clock — and that was recorded
  honestly.** `197-VERIFICATION.md` Truth #2: "Criterion 1b (critical-path time
  reduction) — honestly modest/near-zero." What Phase 197 *did* deliver was
  **failure-surfacing** (5 `!cancelled()`-guarded steps + an `always()` aggregator so
  an early step no longer masks later ones) and **determinism** (`expect.poll()`, no
  `waitForTimeout`; self-hosted webfont + `fonts.ready`). Reliability win, not a speed win.

- **Why the speed win is still on the table — the real blocker is serial-by-design:**
  `playwright.config.ts` is `workers: 1, fullyParallel: false` **deliberately**, because
  the 5 specs share one booted example app + one Postgres DB with mutating state
  (D-03/Plan 02 rationale). So the 5 `npx playwright test` launches run **serially** and
  webkit can't be dropped (three mobile projects use iPhone 13). True parallelism is
  therefore gated on **test-data isolation**, not on Playwright config flags.

- **The actual path to "way faster" Playwright (for the audit milestone to validate):**
  1. **Per-shard DB + app isolation** so `fullyParallel`/multi-worker (or matrix-sharded
     jobs) becomes safe — each shard gets its own database (mirror the `library_tests`
     partition pattern from Phase 195) + its own booted app/port. This is the structural
     change that unlocks real wall-clock reduction.
  2. **Boot-cost amortization** — the `mix deps.get → compile → ecto.create/migrate →
     seeds → npm ci → playwright install` prelude is the dominant fixed cost and is
     re-paid per shard; measure whether N shards still net-win after N× prelude, or
     whether a shared pre-built/cached app image (Docker layer cache, see
     `[[reference_sigra_docker_dx]]`) removes the per-shard prelude tax.
  3. **Move heavy galleries to nightly** (design-gallery, demo-showcase) keeping a fast
     representative admin smoke on the PR path — once visual baselines are deterministic.

- **Adjacent live finding (this session): the design-gallery re-gate has a bootstrap
  ordering hazard.** Re-gating (removing `continue-on-error`) before ubuntu-native
  baselines exist on `main` deadlocks the ship, because the recapture job only runs
  post-merge. Tracked in
  `.planning/todos/pending/2026-06-20-complete-d10-design-gallery-re-gate-after-recapture.md`.
  The audit should treat **"gate vs baseline-availability ordering"** as a determinism
  concern, not just placement.

**Net:** the original audit playbook below still stands; this addendum just pins
**Playwright test-data isolation (per-shard DB)** as the highest-leverage remaining
lever and records that Phase 197 already banked the reliability half, leaving the
wall-clock half explicitly open.

---

The full inflated companion prompt to use as the audit playbook:

```text
<INFLATED_COMPANION_PROMPT_FOR_CI_CD_PERFORMANCE_AUDIT>

You are acting as a combined principal Elixir maintainer, OSS library maintainer, GitHub Actions expert, SRE/DevOps engineer, test architect, DX-focused staff engineer, release engineer, security/supply-chain reviewer, and practical software economist.

We are auditing the CI/CD pipeline for one or more OSS Elixir libraries/apps. The goal is not “make CI look fancy.” The goal is to make the pipeline fast, deterministic, trustworthy, resource-efficient, maintainable, and pleasant for contributors, while preserving or increasing the actual quality signal.

The original human prompt is high-priority taste/context. Preserve its intent:
- fast feedback for developers
- reliable deterministic gates
- no wasting maintainer time or CI runner time
- keep high-value tests
- remove or demote low-signal / redundant / flaky / poorly scoped checks
- use all available runner CPU/core resources intelligently without overcomplicating things
- do not “optimize” by hiding risk
- prefer boring, idiomatic, least-surprise CI
- optimize for OSS contributor DX and maintainer sanity

Do not give generic CI advice. Make concrete, repo-specific recommendations.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
0. OPERATING MODE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Work as if this is a serious one-shot architecture/research pass.

Use subagents if available. If actual subagents are not available, simulate separate expert passes and clearly merge their findings.

Minimum expert passes / lenses:

1. GitHub Actions topology + critical-path analyst
2. Elixir/Mix/ExUnit performance specialist
3. Phoenix/Plug/Ecto ecosystem specialist, where applicable
4. Test quality / flakiness / determinism specialist
5. CI caching and artifact strategy specialist
6. OSS maintainer DX and contributor onboarding specialist
7. Security / supply-chain / secrets / release engineer
8. “Lessons from successful libraries” researcher
9. Simplicity reviewer whose job is to delete cleverness
10. Final integrator whose job is to make all recommendations coherent with each other

Use current, high-quality sources:
- official GitHub Actions docs
- official Elixir/Mix/ExUnit docs
- official Ecto/Phoenix/Plug docs when relevant
- setup-beam docs
- Dialyxir, Credo, Sobelow, ExCoveralls/cover tooling docs when relevant
- current workflows from respected Elixir OSS projects such as Phoenix, Ecto, Plug, Broadway, Nx, Oban, Livebook, Ash, Tesla, Finch, etc., where comparable
- lessons from other ecosystems only when the pattern transfers cleanly: Rust/cargo-nextest, Go test caching, Rails parallel tests, pytest-xdist, Node package CI, etc.

When citing examples from other projects, explain:
- what they do
- why it likely works for them
- whether it applies here
- what not to copy blindly

If you cannot inspect a file, say so and state the assumption. Do not hallucinate repo contents.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. INPUTS TO READ BEFORE RECOMMENDING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Inspect all relevant repo files before making recommendations:

Core CI:
- `.github/workflows/*`
- `.github/actions/*`
- `.github/dependabot.yml`
- `.github/codeql/*`
- any reusable workflow files
- branch protection / required checks if visible
- recent workflow run history, job timings, failures, reruns, cache hit/miss logs if available

Elixir project:
- `mix.exs`
- `mix.lock`
- `.tool-versions`, `.mise.toml`, `.asdfrc`, `elixir_ls` config, Dockerfiles, devcontainer files
- `.formatter.exs`
- `.credo.exs`
- `dialyzer` config in `mix.exs`
- `config/test.exs`
- `test/test_helper.exs`
- `test/support/*`
- `Makefile`, `justfile`, `Taskfile`, `bin/*`, `scripts/*`
- umbrella `apps/*/mix.exs` if this is an umbrella
- `assets/package.json`, lockfiles, esbuild/tailwind config if Phoenix/UI/assets are involved

Project knowledge:
- `README*`
- `CONTRIBUTING*`
- `CHANGELOG*`
- release docs
- Hex package metadata
- docs generation config
- anything in `prompts/` or prompt/research subdirectories
- brandbook/design docs only if user-facing app/UI/docs presentation is relevant
- existing TODOs/issues mentioning CI, slow tests, flaky tests, release, coverage, Dialyzer, GitHub Actions

Historical data:
- recent 20–50 CI runs if accessible
- PR vs main vs release timings
- cold-cache vs warm-cache timings
- most common failure modes
- flaky reruns
- average and p95 wall-clock time
- queue time vs execution time
- per-step duration
- cache size and hit rate
- dependency install time
- compile time
- test time
- slowest tests
- DB/container startup time
- asset build time if applicable

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2. NORTH STAR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Optimize for this hierarchy:

1. Correctness and trustworthiness of release/merge gates
2. Deterministic, non-flaky developer feedback
3. Fast PR feedback on the most likely regressions
4. Efficient use of GitHub-hosted runners and caches
5. Maintainability and simplicity of workflow YAML
6. Contributor friendliness
7. Security and OSS supply-chain posture
8. Nice presentation/logging/reporting

Do not recommend changes that make CI faster but less trustworthy unless explicitly labeled as a tradeoff and moved to an optional tier.

Do not recommend “just retry flaky tests” as a fix. Retries may be a temporary quarantine tool, not the root solution.

Do not recommend deleting slow tests solely because they are slow. First classify whether they are high-value, redundant, flaky, over-scoped, mis-layered, or just expensive but necessary.

Do not create a Rube Goldberg CI system. Prefer simple, legible workflows with comments explaining non-obvious choices.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
3. BASELINE FIRST: MEASURE BEFORE OPTIMIZING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Before recommendations, create a current-state baseline.

Produce a table:

- workflow name
- trigger
- job name
- runner
- matrix dimensions
- services/containers
- command(s)
- average duration
- p95 duration if available
- failure/rerun rate if available
- cache usage
- whether it is required for merge
- quality signal
- likely bottleneck
- notes

Compute or infer the critical path:
- which jobs gate merge?
- which jobs run in parallel?
- which job determines wall-clock feedback?
- which steps dominate each job?
- what work is duplicated across jobs?

Distinguish:
- PR fast path
- push-to-main path
- scheduled/nightly path
- release/tag publishing path
- docs path
- security/dependency path

When data is unavailable, recommend commands or GitHub UI/API steps to obtain it.

Suggested local/CI diagnostics where applicable:

- `mix test --slowest 20`
- `mix test --profile-require`
- `MIX_ENV=test mix compile --profile time`
- `mix xref graph --label compile-connected`
- `mix xref graph --format cycles --label compile-connected`
- `mix deps.unlock --check-unused`
- `mix deps.get --check-locked`
- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- `mix hex.audit`
- `mix deps.audit` if `mix_audit` is already used or clearly worth adding
- `mix dialyzer` if Dialyzer is already present or worth adding
- `mix credo --strict` only if Credo is already part of the project or clearly valuable
- `mix sobelow` only for Phoenix/web apps where it applies
- `elixir -e "IO.inspect(System.schedulers_online(), label: :schedulers_online)"`
- print cache hit/miss state in CI summaries
- collect top slow tests and top slow compile modules

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
4. TEST VALUE CLASSIFICATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Classify tests and checks by value, not vibes.

For every major test/check category, answer:

- What bug class does this catch?
- How often does it fail usefully?
- Is it deterministic?
- Is it fast enough for PR?
- Is it redundant with another check?
- Is it testing behavior or implementation trivia?
- Is it overly broad integration coverage for a unit-level concern?
- Does it require network/time/random/global state?
- Could it be moved to nightly without meaningfully increasing merge risk?
- Could it be split/sharded/partitioned?
- Could it become async-safe?
- Could fixture/setup cost be reduced?
- Is the failure output actionable?

Use this classification:

A. Must remain in PR gate
- catches likely regressions
- fast enough or high enough signal to justify cost
- deterministic
- actionable failure output

B. Keep in PR but optimize
- valuable but slow due to setup, lack of async, bad fixture strategy, duplicated compile/deps, inefficient services

C. Move to scheduled/main/release gate
- valuable but too slow/broad for every PR
- catches lower-probability compatibility issues
- exhaustive matrix, broad adapter matrix, old-version matrix, coverage reports, security scans with network dependency, docs publishing dry runs, etc.

D. Quarantine/fix before trusting
- flaky, timing-sensitive, global state leaks, relies on external services, nondeterministic ordering

E. Delete or rewrite
- low-signal snapshots
- tests that only assert implementation detail
- duplicated test paths
- tests that never fail except during unrelated refactors
- brittle over-mocking
- coverage-only tests with no meaningful assertion

Be conservative about deletion. Recommend deletion only with evidence.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
5. ELIXIR-SPECIFIC AUDIT POINTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Audit these Elixir/Mix/ExUnit areas deeply.

5.1 ExUnit concurrency
- Identify which test modules can safely use `async: true`.
- Identify why non-async modules are non-async: DB sandbox, global app env, ETS named tables, registered processes, filesystem paths, ports, time, randomness, process dictionary, Mox global mode, Bypass/global HTTP server, Application env mutation, Logger capture, telemetry handlers, etc.
- Recommend converting safe modules to `async: true`.
- Do not mark tests async if they mutate global state.
- Remember tests within a module are still serialized; splitting huge modules can improve concurrency.
- Check `ExUnit.configure(max_cases: ...)` only after measuring. Do not blindly set it above runner CPU capacity.
- Compare `System.schedulers_online()` with runner CPU count and observed bottlenecks.

5.2 Test partitioning / sharding
- Consider `mix test --partitions N` and `MIX_TEST_PARTITION` when suite time is dominated by non-async modules or integration tests.
- Explain overhead: duplicated setup, duplicated compile unless cached, service contention, coverage merge complexity.
- For DB tests, ensure each partition gets isolated DB/schema/database names.
- For coverage with partitions, ensure coverage data is exported and merged correctly.
- Recommend partition count based on evidence, not “more is better.”
- Avoid oversubscribing a small runner with too many partitions plus DB services.

5.3 Ecto/Phoenix/Plug specifics
Where applicable:
- Verify Ecto SQL Sandbox config is correct for concurrent transactional tests.
- Check `config/test.exs` pool sizes relative to async tests/partitions.
- Ensure tests using shared sandbox mode are not incorrectly async.
- For Phoenix channel/LiveView/endpoint tests, verify sandbox allowances and process ownership.
- For Plug/Cowboy/Bandit tests, watch port conflicts and registered process conflicts.
- For adapter integration tests, separate unit tests from DB/service/container integration tests.
- For Phoenix assets, avoid rebuilding assets unnecessarily in pure Elixir test jobs.
- Cache Node package manager data correctly if assets are tested.
- Use deterministic service readiness checks rather than sleeps.

5.4 Mocks and external services
- Prefer behaviour-based mocks/contracts such as Mox when idiomatic.
- Keep mocks private/async-safe where possible.
- Avoid global mocks for async tests.
- Replace real network calls with local fakes, Bypass, Mox behaviours, or contract tests.
- If integration with real services is essential, move to scheduled/release workflow and clearly label it.

5.5 Compile performance
- Check if compile time is a major contributor.
- Use `mix compile --profile time` and `mix xref`.
- Look for compile-connected dependency chains and macro-heavy modules that cause recompilation.
- Consider CI guardrails for compile-time cycles only if the project has a real problem and the threshold is pragmatic.
- Avoid overly strict xref gates that create churn without measurable benefit.

5.6 Dialyzer
- If Dialyzer exists, ensure PLTs are cached with keys including OS, OTP, Elixir, lockfile, and relevant Dialyzer config.
- Consider split restore/save so a failed Dialyzer run does not prevent PLT cache persistence.
- Decide whether Dialyzer belongs in PR, main, or scheduled based on runtime and value.
- Ensure output format is useful in GitHub Actions logs/annotations.
- Avoid adding Dialyzer as a mandatory PR gate to a library with poor specs unless the remediation plan is realistic.

5.7 Formatting, lockfile, dependencies
- `mix format --check-formatted` should be fast and PR-gated.
- `mix deps.get --check-locked` is valuable for reproducibility.
- `mix deps.unlock --check-unused` is useful for library hygiene.
- `mix compile --warnings-as-errors` should run where it provides signal without duplicating across every matrix entry.
- Consider `mix hex.audit` and `mix_audit`/`mix deps.audit` based on security posture and dependency profile.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
6. GITHUB ACTIONS AUDIT POINTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

6.1 Workflow triggers
Evaluate:
- `pull_request`
- `push` to default branch
- `merge_group` if GitHub merge queue is used
- `workflow_dispatch`
- `schedule`
- tags/releases
- docs-only changes
- path filters

Watch for footguns:
- path-filtered workflows that are required checks can leave PRs blocked/pending.
- commit-message skip directives may block required checks.
- `pull_request_target` is dangerous with untrusted fork code; avoid unless necessary and hardened.
- scheduled workflows should not be the only place correctness-critical tests run.

Recommend a trigger model:
- PR: fast representative gate
- main: same or slightly broader
- nightly/scheduled: broad compatibility matrix, slow integration, security, coverage, exhaustive tests
- tags/releases: full verification before publishing

6.2 Concurrency
Use concurrency intentionally:
- cancel outdated PR runs on the same branch/PR
- avoid canceling main/release workflows that should complete
- use workflow-specific group names to avoid cross-workflow cancellation
- deployment/release jobs should serialize rather than cancel unless explicitly desired

6.3 Runner selection
Evaluate:
- explicit Ubuntu version vs `ubuntu-latest`
- public vs private runner CPU/memory differences
- whether `ubuntu-slim` is inappropriate for heavyweight CI
- larger runners only if the cost/speed tradeoff is justified
- service container overhead and disk limits
- whether macOS/Windows/ARM matrices are actually needed for this library

For standard Linux runners, detect actual CPUs in logs and tune accordingly rather than guessing.

6.4 Matrix strategy
Avoid accidental matrix explosion.

For Elixir OSS libraries, consider:
- latest supported Elixir/OTP as the primary lint/test job
- minimum supported Elixir/OTP to protect compatibility
- one or two representative intermediate versions only if needed
- broad version matrix on scheduled/main rather than every PR
- lint/static checks only on one matrix entry unless version-specific
- integration adapter matrix separated from unit test matrix
- `fail-fast: false` for compatibility matrix where full failure information is useful
- `fail-fast: true` or default for homogeneous shards where one failure is enough

For each matrix dimension, justify:
- What compatibility promise does this protect?
- Is it required on every PR?
- Does it catch real bugs historically?
- Can it be scheduled instead?

6.5 setup-beam and versions
- Prefer `erlef/setup-beam`.
- Use exact versions or a clear version policy.
- Align CI versions with `mix.exs` minimum supported Elixir version.
- Avoid unsupported OTP/Elixir combinations.
- Use `.tool-versions`/mise if the repo already standardizes on it, but ensure CI is explicit enough to be reproducible.
- Capture resolved versions in logs/job summary.

6.6 Caching
Treat caching as a correctness-sensitive optimization, not magic.

Audit current cache:
- paths cached
- key specificity
- restore key breadth
- cache hit rate
- stale cache failure modes
- cache size/eviction risk
- whether dependencies/build outputs are safe to reuse across matrix entries
- whether cache misses still run install/compile steps correctly

Good cache-key dimensions often include:
- runner OS
- architecture if relevant
- OTP version
- Elixir version
- MIX_ENV
- lockfile hash
- cache version/buster
- relevant tool config hash for Dialyzer/PLT/assets if needed

Be careful with broad restore keys:
- do not restore `_build` across incompatible OTP/Elixir/MIX_ENV combinations
- do not skip `mix deps.get` merely because a partial cache restored
- do not cache generated artifacts that can mask warnings or stale compilation issues
- separate dependency cache from PLT cache when appropriate
- use restore/save split for PLTs if failure prevents cache save
- document how to bust cache

Decide whether to cache:
- `deps`
- `_build`
- Dialyzer PLTs
- `~/.cache/rebar3` if relevant
- package manager cache for assets
- downloaded tools
- not build artifacts that are cheaper/safer to recreate

6.7 Artifacts
Use artifacts when they improve DX or enable downstream jobs:
- JUnit/XML test reports if available
- coverage reports
- logs for flaky failures
- compiled docs preview only if useful
- release tarballs/packages only from trusted workflows

Avoid artifacts that slow CI without clear value.

6.8 Required checks
Recommend a clean required-check strategy:
- stable names
- avoid requiring every matrix child unless intentional
- consider a final summary/required job that depends on matrix jobs
- ensure skipped jobs report success if required
- avoid branch/path filter pending check traps
- document required checks in CONTRIBUTING

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
7. SECURITY / SUPPLY CHAIN / RELEASE AUDIT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Review:
- top-level `permissions`
- per-job permissions
- use of `GITHUB_TOKEN`
- third-party actions
- action pinning policy
- Dependabot/Renovate for actions and dependencies
- secrets exposure to forks
- `pull_request_target`
- shell injection from untrusted PR metadata
- release/tag workflows
- Hex publishing
- docs publishing
- package provenance/signing if applicable
- OIDC vs long-lived cloud credentials if deployments exist

Recommend:
- `permissions: contents: read` by default
- write permissions only in jobs that need them
- pin third-party actions to immutable SHAs for higher-security OSS posture, or explicitly justify tag pinning with Dependabot automation
- avoid long-lived cloud credentials where OIDC is practical
- release/publish only on trusted refs/tags after tests pass
- dry-run package publishing where useful
- do not run untrusted fork code with secrets
- do not use random third-party actions for trivial shell commands

For Hex package release:
- verify package metadata
- verify docs build
- verify changelog/version/tag semantics
- verify `mix hex.publish --dry-run` if appropriate
- use scoped API keys/secrets
- ensure release job depends on full verification

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
8. DX / MAINTAINER EXPERIENCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

A good CI pipeline should make failure obvious and local reproduction easy.

Audit:
- Is there a single local command equivalent to CI, e.g. `mix ci`, `make ci`, or `just ci`?
- Are CI commands documented in CONTRIBUTING?
- Are failure logs readable?
- Are long logs grouped?
- Are warnings surfaced as GitHub annotations where reasonable?
- Are slowest tests reported?
- Are flaky tests labeled with reproduction seed?
- Are service/container failures distinguishable from test failures?
- Are caches observable?
- Are matrix failures named clearly?
- Does the README badge reflect meaningful required checks?
- Can a new contributor run the same checks locally without guessing?

Recommend:
- a `mix ci` alias or documented command set:
  - deps check
  - format
  - compile warnings-as-errors
  - unused deps
  - tests
  - optional lint/dialyzer/security checks
- job summaries with:
  - versions
  - cache hits
  - test timing summary
  - slowest tests
  - coverage link if generated
- clearer job names:
  - `test / elixir 1.19 / otp 28`
  - `lint / latest`
  - `integration / postgres`
  - `compat / min-supported`
- minimal but useful comments in YAML explaining non-obvious decisions

Do not optimize only for CI maintainers. Optimize for external OSS contributors who hit a red check and need to understand what to do.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
9. LESSONS FROM OTHER LIBS / ECOSYSTEMS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Research comparable successful projects and summarize transferable lessons.

For Elixir, inspect respected libraries/apps:
- Phoenix
- Ecto
- Plug
- Broadway
- Livebook
- Nx/Axon
- Finch/Tesla/Req
- Oban if accessible
- Ash ecosystem if applicable
- other libraries in the same domain as this project

Look for:
- matrix shape
- min/latest version policy
- where lint runs
- cache strategy
- test partitioning
- integration test isolation
- release workflow
- action pinning
- docs publishing
- coverage policy
- security checks
- contributor docs

For other ecosystems, only transfer patterns with clear applicability:
- Rust: `cargo nextest`, deterministic test sharding, lockfile/toolchain pinning
- Go: built-in test caching and small fast package-level tests
- Rails: DB test parallelization and schema-per-worker tradeoffs
- pytest: xdist, flaky test quarantine, JUnit reporting
- Node: package-manager cache vs `node_modules` cache tradeoffs
- Java: test reports and expensive integration tests separated from unit tests

For each lesson:
- what they do right
- what footguns they avoid
- what does not apply here
- how this repo should adapt it

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
10. RECOMMENDATION FORMAT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Produce the final answer in this structure:

1. Executive summary
   - top 5 recommended changes
   - expected impact
   - risk level
   - first PR to make

2. Current pipeline map
   - workflows/jobs/triggers/matrix/required checks/services/cache

3. Baseline metrics
   - table of durations and bottlenecks
   - critical path
   - cold vs warm cache notes
   - flaky/failure history if available

4. Findings by category
   - correctness
   - performance
   - determinism/flakiness
   - caching
   - matrix/version policy
   - test suite quality
   - security
   - release
   - DX/docs

5. Prioritized recommendations
   For each recommendation include:
   - Title
   - Priority: P0/P1/P2/P3
   - Category
   - Current issue
   - Proposed change
   - Why this is idiomatic for Elixir/GitHub Actions
   - Pros
   - Cons/tradeoffs
   - Expected speed/reliability impact
   - Risk
   - How to implement
   - How to verify
   - Rollback plan

6. Proposed target pipeline
   Describe the ideal steady-state design:
   - PR workflow
   - main workflow
   - scheduled/nightly workflow
   - release/tag workflow
   - optional docs workflow
   - optional security workflow

7. Concrete patches
   Provide concrete YAML / Mix / config patches where possible.
   Keep patches minimal and coherent.
   Do not rewrite the entire pipeline unless necessary.
   Prefer stepwise PRs:
   - PR 1: observability/baseline
   - PR 2: cache/version cleanup
   - PR 3: test concurrency/partitioning
   - PR 4: matrix/trigger refinement
   - PR 5: release/security polish

8. Test cleanup plan
   - high-value tests to keep
   - slow tests to optimize
   - flaky tests to fix/quarantine
   - low-value tests to delete/rewrite
   - tests to move to nightly/scheduled

9. Validation plan
   Include:
   - before/after CI wall-clock
   - p95 PR runtime
   - cache hit rate
   - failure/rerun rate
   - top slow tests
   - compile time
   - mean time to actionable failure
   - contributor reproduction instructions

10. Final recommended `mix ci` / local dev command
    Provide the exact command(s) contributors should run locally.

11. Open questions / assumptions
    Only list questions that genuinely affect decisions.
    Do not block the whole audit on them; make best-effort recommendations.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
11. PRIORITIZATION RUBRIC
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Score each recommendation from 1–5 on:

- Runtime impact
- Reliability/determinism impact
- Quality-signal impact
- Maintainer complexity
- Security impact
- Contributor DX impact
- Reversibility

Prefer recommendations with:
- high runtime/reliability/DX impact
- low complexity
- easy rollback
- strong idiomatic fit

Be skeptical of recommendations with:
- high cleverness
- small speedup
- hard-to-debug behavior
- hidden correctness risk
- fragile cache assumptions
- hard contributor reproduction

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
12. SPECIFIC DARK CORNERS TO CHECK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Do not miss these:

- required checks stuck pending because workflow is skipped by path/branch/commit-message filtering
- matrix explosion from OS × OTP × Elixir × DB adapter × partition
- lint running redundantly across every matrix entry
- `ubuntu-latest` moving under the project unexpectedly
- using `ubuntu-slim` for heavyweight builds
- restoring `_build` across incompatible OTP/Elixir/MIX_ENV
- broad restore keys causing stale compiled dependencies
- skipping `mix deps.get` after partial cache restore
- Dialyzer PLT cache not saved when Dialyzer fails
- PLT key missing OTP/Elixir/mix.lock dimensions
- tests marked async while mutating Application env/global state
- Mox global mode preventing async
- DB sandbox ownership issues across processes
- test partitions sharing the same DB
- fixed ports in async tests
- `Process.sleep` as readiness or race-condition masking
- real network calls in PR tests
- random data without reproducible seed
- huge test modules limiting ExUnit concurrency
- coverage slowing every PR without meaningful gate value
- doctests that compile too much or depend on unstable docs
- integration containers dominating PR runtime
- dependency/security scans that hit network and flake
- action versions not maintained
- overprivileged `GITHUB_TOKEN`
- secrets exposed to untrusted PR contexts
- release workflows not depending on CI
- package publishing without dry-run/metadata/docs checks
- branch protection requiring unstable matrix job names
- local commands diverging from CI
- opaque logs with no actionable failure guidance

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
13. IDEAL SHAPE TO CONSIDER, NOT BLINDLY COPY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

A good final state for a typical OSS Elixir library often looks like this, but adapt to the repo:

PR workflow:
- checkout
- setup exact Elixir/OTP via setup-beam
- restore deps/_build cache with precise key
- `mix deps.get --check-locked` or equivalent
- fast lint/static checks on latest version only:
  - format
  - unused deps
  - compile warnings-as-errors
- tests on latest supported pair
- tests on minimum supported pair if compatibility promise matters
- optional partitions only if test suite is actually long enough
- no broad integration matrix unless necessary

Main workflow:
- same as PR
- maybe broader compatibility matrix
- upload coverage or docs artifact if useful

Nightly/scheduled:
- full OTP/Elixir compatibility matrix
- slow integration/service adapter tests
- security/dependency audit
- Dialyzer if too slow for PR
- exhaustive property/long-running tests
- coverage report if not PR-gated

Release/tag workflow:
- depends on full verification
- docs build
- package dry-run
- publish to Hex only from trusted tag/ref
- minimal required permissions
- secrets only in publish job

Docs/UI workflow:
- only if relevant
- never block code PRs unless docs are part of quality contract
- keep statuses understandable

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
14. OUTPUT TONE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Be opinionated but evidence-based.

Be direct:
- “Do this.”
- “Do not do this.”
- “This is not worth it.”
- “This is worth it despite cost because...”

Surface tradeoffs honestly.

Avoid generic advice like “use caching” without exact keys/paths and failure modes.

Avoid vague “consider optimizing tests.” Name the concrete test categories, files, or patterns.

Make the final recommendations cohesive. The output should feel like one integrated CI/CD design, not a pile of unrelated tips.

</INFLATED_COMPANION_PROMPT_FOR_CI_CD_PERFORMANCE_AUDIT>
```
