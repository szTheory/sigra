# Phase 195: Test-Suite Performance - Discussion Log (Assumptions Mode + Research)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in 195-CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-20
**Phase:** 195-test-suite-performance-partition-async-dep-off-slim
**Mode:** assumptions (codebase analysis) → user requested deep subagent research per area → synthesis
**Areas analyzed:** TEST-01 partitioning, TEST-02 dep-off slim, TEST-03 async audit, CACHE-03 larger runners

## Assumptions Presented (initial codebase pass)

### Partition mechanism & required-check preservation (TEST-01)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| N=2 matrix + aggregator job named `Library tests` preserves the required check; bare matrix orphans it | Confident | ci.yml:173 (`name: Library tests`); 194-CONTEXT D-01/D-02 (ruleset 14941512); ci-gate `needs.library_tests.result` |
| No coverage merge (no ExCoveralls in mix.exs) | Confident | mix.exs has no `:test_coverage`/coveralls |
| `mix docs` moves out of shards, runs once | Confident | ci.yml:246-247 (appended to library_tests) |

### Dep-off slim (TEST-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Keep compile-without-Threadline proof; slim test RUN to a `:threadline_guard`-tagged subset | Likely | ci.yml:299-315; `:requires_threadline` on one module only; ~7 Threadline-referencing test files |

### async audit & sandbox (TEST-03)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Conservative opt-in conversion; keep DDL/telemetry/subprocess serial; sandbox correct as-is | Likely | PostgresCase `shared: not tags[:async]`; pool_size 4; baseline serial-category analysis |

### Larger runners (CACHE-03)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Do not adopt larger runners; prefer standard-runner sharding | Confident | all jobs `runs-on: ubuntu-latest`; no larger-runner labels |

## User Direction

User did not correct the assumptions — instead requested a **deep subagent research pass per
area**: pros/cons/tradeoffs with examples, idiomatic Elixir/Plug/Ecto/Phoenix conventions,
lessons (right + footguns) from successful libs/apps in this and other ecosystems, great
contributor DX, consulting `prompts/` research, synthesized into ONE coherent decisive
recommendation set. (UI/UX lens N/A for a CI/DevOps phase; JTBD "user" = maintainer/contributor
+ CI itself.)

## Research Performed (4 parallel subagents)

- **TEST-01 (partitioning):** Confirmed ExUnit `--partitions` distributes by file, round-robin
  after sorting; `MIX_TEST_PARTITION` is 1..N. Matrix→check-name semantics confirmed (`Library
  tests (1)/(2)`, never bare). Aggregator-job pattern is the canonical GitHub workaround.
  Recommended matrix `library_tests_shard` + thin aggregator `library_tests` (name `Library
  tests`); N=2; `fail-fast: false`; partition NOT in cache key; docs → `fast_checks`. Key insight:
  since CRIT-01, Playwright (~22m) is the wall-clock pole, so N≥3 yields zero PR wall-clock gain.
  Sources: hexdocs mix test, elixir PR #9422, GitHub community #60792/#26822.
- **TEST-02 (dep-off):** Recommended keeping the compile proof load-bearing; slim only the test
  RUN via a `:threadline_guard` moduletag + `mix test --only threadline_guard`. Decisive safety
  property: `mix test --only <tag>` **fails on zero matches** → dropped tag = red, not silent
  green. Tag beats enumerated paths/globs. Add a `mix sigra.dep_off` alias; CI calls the alias to
  kill drift. Enumerated must-still-assert coverage list. Idiom precedent: Elixir
  `--no-optional-deps` compile + tagged behavioral subset (Phoenix/Plug/Oban/Ecto).
- **TEST-03 (async):** Recommended conservative inspection-driven conversion (Approach A); ~37
  `async: false` files, most serial for legitimate reasons; genuine candidates a handful
  (`auth_plain_map_regression_test.exs`, `passkeys/rate_limit_test.exs`). Deliverable = a
  documented async-safety checklist. Sandbox `shared: not tags[:async]` correct; pool_size 4
  stays. No proactive module-splitting. Honest: small lever vs partitioning (max_cases=4 already
  saturated). Cross-ecosystem: RSpec/Go `t.Parallel()`/pytest-xdist all surface hidden-global-
  state flake; mitigation = forbid shared global state + per-worker DB isolation.
- **CACHE-03 (runners):** Verified GitHub billing (June 2026): larger runners billed per-minute
  even on public repos, excluded from included minutes; standard runners free/unlimited on public
  repos. 4-core larger = $0.012/min vs 2 free standard shards = 4 cores at $0/min. Recommended:
  do not adopt; revisit only un-shardable-on-critical-path OR concurrency-capped + recorded
  measurement. Shipped a measurement-gate runbook. Sources: GitHub Docs Actions runner pricing,
  Hashrocket Elixir CI, Ecto #3599.

> Note: the first TEST-01 research agent aborted with no output (0 tool uses); it was re-run as a
> general-purpose agent which returned the full brief above.

## Synthesis & Corrections Made

No corrections — research **confirmed and sharpened** every initial assumption. Key sharpenings
folded into CONTEXT decisions:
- TEST-01: explicit `fail-fast: false`, partition-NOT-in-cache-key, the "Playwright is the real
  pole → don't over-shard" framing (D-04, honest-framing in domain).
- TEST-02: the `--only` zero-match red-not-green safety property as the decisive reason for tags
  (D-11); the `mix sigra.dep_off` alias to prevent CI/local drift (D-14).
- TEST-03: the async-safety checklist promoted to a first-class deliverable (D-17); honest
  small-lever framing (D-20).
- CACHE-03: verified billing facts as the decisive argument (D-21); the measurement-gate runbook
  (D-23).

User confirmed: **"Yes, lock it all."**

## External Research
- ExUnit `--partitions` mechanics + `MIX_TEST_PARTITION` 1..N, round-robin by file
  (hexdocs mix test; elixir PR #9422).
- GitHub Actions matrix → status-check-name semantics; aggregator-job required-check workaround
  (GitHub community #60792, #26822).
- `mix test --only <tag>` fails the run on zero matches (hexdocs Mix.Tasks.Test).
- Ecto SQL Sandbox `shared: not tags[:async]` authoritative idiom (ecto/elixir docs).
- GitHub Actions runner pricing June 2026 — larger runners billed on public repos; standard free
  (GitHub Docs; rate cut 2026-01-01).
