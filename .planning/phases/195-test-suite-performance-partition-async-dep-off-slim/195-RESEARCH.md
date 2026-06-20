# Phase 195: Test-Suite Performance (partition / async / dep-off slim) - Research

**Researched:** 2026-06-20
**Domain:** GitHub Actions matrix-shard topology + ExUnit `--partitions` mechanics + Ecto SQL Sandbox async-safety + Mix alias authoring (Elixir/Phoenix CI)
**Confidence:** HIGH (every mechanism verified against the live ci.yml, the installed Elixir 1.19.5 `mix help test`, and the actual test source tree)

## Summary

Phase 195 has 23 locked decisions (D-01..D-23). This research does **not** re-open them; it de-risks executing them by pinning down the exact YAML/ExUnit/sandbox mechanics and flagging one **planning-critical correction** to a premise baked into several decisions.

**The premise correction (HIGH, verified via `mix help test` on the installed Elixir 1.19.5):** the current `library_tests` lane runs `mix test --slowest 10`. `--slowest` **automatically sets `--trace`, which automatically sets `--max-cases` to `1`** — i.e. the entire 2401-test suite currently runs **fully serial** on CI, not 4-wide. The 193-BASELINE "`max_cases = 4`" figure describes the *default* ExUnit behavior, **not what this lane actually does** — `--slowest 10` overrides it to 1. This matters because (a) D-20's "186 async modules already saturate max_cases=4" reasoning understates the available headroom — the real serial bottleneck is `--trace`, not core count; and (b) the cheapest single win available this phase may be **decoupling timing observability from the hot test run** (run the timed suite without `--trace`, or accept `--slowest-modules`/no-trace) — which is *additive* to partitioning, not a replacement for it. The planner should treat "keep `--slowest 10` exactly as Phase 193 left it" (implied by D-01) as a decision to **revisit with a one-line measurement**, because per-shard `--trace` re-serializes each shard and erodes the partition win.

**Primary recommendation:** Implement D-01..D-23 as written, with two execution-time guardrails the planner must encode: (1) **measure the `--trace`/`--slowest` serialization cost** before locking the per-shard test command — either run shards concurrent (drop `--slowest`, or use a tee+grep timing capture that does not force `--trace`) and keep observability via the existing `$GITHUB_STEP_SUMMARY` log-scrape; (2) the aggregator job (D-02) must be byte-identical `name: Library tests` and the only thing the ruleset + `ci-gate` reference — verified the current wiring makes this a drop-in rename of the *worker* and an *add* of the aggregator.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Shard fan-out + DB isolation | GitHub Actions (`strategy.matrix` + per-leg `services.postgres`) | — | CI topology owns parallelism; each leg's own PG container gives isolation for free (D-05) |
| Required-check name preservation | GitHub Actions aggregator job (`name: Library tests`) | Branch ruleset 14941512 | The ruleset matches a status-check *string*; only a bare-named job produces it (D-02) |
| Test distribution across shards | ExUnit (`mix test --partitions N` + `MIX_TEST_PARTITION`) | — | ExUnit sorts files round-robin and selects this partition's slice |
| Sandbox correctness per shard | Ecto SQL Sandbox (`Sigra.Test.PostgresCase`) | per-leg PG container | Each shard is an independent VM+connection vs its own DB; `shared: not tags[:async]` unchanged (D-18) |
| Dep-off guard selection | ExUnit moduletag (`:threadline_guard`) + `mix test --only` | `mix sigra.dep_off` alias | Tag selection fails-red on zero matches (D-11); alias prevents CI/local drift (D-14) |
| Async-safety policy | Documentation (CONTRIBUTING / testing guide) | per-module `async:` flag | The lasting deliverable is the checklist (D-17), not the handful of flips (D-15) |

## Standard Stack

No new packages. This phase edits CI YAML, one Mix alias, ExUnit moduletags, and docs. Stack is the existing toolchain:

| Tool | Version (verified) | Purpose | Source |
|------|--------------------|---------|--------|
| Elixir | 1.19.5-otp-28 | `mix test --partitions` / `--only` / `--slowest` host | `.tool-versions` [VERIFIED: read] |
| Erlang/OTP | 28.5 | runtime | `.tool-versions` [VERIFIED: read] |
| ExUnit (stdlib) | 1.19.x | partitioning + tag filtering + sandbox | `mix help test` on this machine [VERIFIED: tool] |
| GitHub Actions | matrix strategy, `needs`, `if: always()` | shard fan-out + aggregator | live ci.yml [VERIFIED: read] |
| erlef/setup-beam | v1.24.0 (SHA `fc68ffb`) | already pinned in every lane | ci.yml:189 [VERIFIED: read] |
| actions/cache | v5.0.5 (SHA `27d5ce7`) | already pinned; reused unchanged per D-06 | ci.yml:196 [VERIFIED: read] |

**No installation step. No `npm install` / `mix deps.get` changes. No Package Legitimacy Audit needed (zero new external packages).**

## Architecture Patterns

### System Architecture Diagram (post-195 CI topology for the two poles)

```
release_ref_guard (2s gate)
        │
        ├──────────────────────────────────────────────┐
        ▼                                                ▼
  library_tests_shard  (strategy.matrix.partition: [1,2],   library_tests_dep_off (slimmed)
   fail-fast: false)                                         │  steps:
   ├─ leg 1: own postgres service                            │   - deps.compile (test env)
   │    MIX_TEST_PARTITION=1 mix test --partitions 2         │   - deps.unlock threadline
   │    + $GITHUB_STEP_SUMMARY per-shard timing              │   - deps.clean threadline --build
   └─ leg 2: own postgres service                            │   - compile --warnings-as-errors --no-deps-check  (D-09 proof KEPT)
        MIX_TEST_PARTITION=2 mix test --partitions 2         │   - mix test --only threadline_guard --no-deps-check  (was: --exclude requires_threadline)
        │                                                     │     └─ (lane body = `mix sigra.dep_off` alias — D-14)
        ▼                                                     ▼
  library_tests  (id: library_tests, name: "Library tests")   (unchanged job id/name; ci-gate.needs verbatim)
   needs: [library_tests_shard]; if: always()
   step: fail unless needs.library_tests_shard.result == 'success'
        │
        ▼
  ci-gate  (needs: library_tests  ← unchanged; D-03)
        └─ LIBRARY_TESTS: ${{ needs.library_tests.result }}  ← unchanged
```

`mix docs --warnings-as-errors` is **removed from the shard** and **relocated to `fast_checks`** (D-07). The aggregator carries no test logic — it is a 1-step result gate, mirroring the existing `ci-gate` pattern.

### Pattern 1: Matrix-shard worker + name-preserving thin aggregator (D-01/D-02)

**What:** A `strategy.matrix` job produces per-leg checks named `Library tests shard 1` / `Library tests shard 2`; a separate dependent job reuses the protected id/name `library_tests` / `Library tests` and gates on the matrix result.

**Why the aggregator is mandatory (verified mechanism):** a job named `Library tests` *with* a matrix produces status checks `Library tests (1)` and `Library tests (2)` — GitHub never emits a bare `Library tests` context for a matrixed job. Ruleset 14941512 requires the literal string `Library tests` [CITED: 194-CONTEXT D-01]. With no bare context, that required check stays **pending forever → merge outage**, and `ci-gate`'s `needs.library_tests.result` resolves against a job that no longer exists. The aggregator restores a single bare `Library tests` context and a single `library_tests` job id.

**Example (aggregator — Claude's-discretion shell, D placeholder):**
```yaml
# Source: pattern verified against existing ci-gate job (ci.yml:1218-1269)
  library_tests:
    name: Library tests          # byte-identical to ruleset 14941512 — DO NOT EDIT
    runs-on: ubuntu-latest
    needs: [library_tests_shard]
    if: always()
    steps:
      - name: Require all library_tests shards to pass
        env:
          SHARDS: ${{ needs.library_tests_shard.result }}
        run: |
          set -euo pipefail
          if [[ "$SHARDS" != "success" ]]; then
            echo "library_tests_shard result: $SHARDS"
            exit 1
          fi
          echo "all library_tests shards passed"
```
Note: `needs.<matrix-job>.result` aggregates across the whole matrix — it is `success` only if **every** leg succeeded, `failure` if any leg failed, regardless of `fail-fast: false`. `fail-fast: false` only changes whether a sibling leg is *cancelled* when one fails; it does not change the aggregated result the aggregator reads. [CITED: docs.github.com/actions — needs context & job matrix].

### Pattern 2: `mix test --partitions N` + `MIX_TEST_PARTITION` (D-01, D-04)

**Verified from `mix help test` (Elixir 1.19.5 on this machine):**
- `--partitions N` requires `MIX_TEST_PARTITION` env to select the active partition.
- "The test files are sorted upfront in a **round-robin** fashion." → distribution is **by file**, deterministic, not timing-balanced. This is the D-specifics warning: the ~11 subprocess install/upgrade files (23–33s each, per 193-BASELINE ranks 1–11) can clump onto one shard. Accept at N=2 (D-04); watch the shard-balance probe.
- Local repro is exact: `MIX_TEST_PARTITION=2 mix test --partitions 2` reproduces CI shard 2 (D-specifics DX win).
- Mix's own docs note: "you typically use a different database instance per partition in `config/test.exs`." **Sigra does not need this** — each CI leg has its own `services.postgres` container (D-05), so the static `sigra_test` DB name is isolated per leg. No `config/test.exs` change, no `MIX_TEST_PARTITION`-suffixed DB. [VERIFIED: tool — `mix help test`].

### Pattern 3: Tag-based dep-off selection with fail-red-on-zero-match (D-10/D-11)

**Verified from `mix help test`:** `--only` "differs in that the test suite will **fail if no tests are executed when the `--only` option is used**." This is the exact trust property D-11 relies on: a dropped/renamed `:threadline_guard` tag turns CI **red**, never silently green. [VERIFIED: tool — `mix help test`].

The existing `:requires_threadline` moduletag (`test/sigra/audit/forwarders/threadline_test.exs:14`) is the precedent the new `:threadline_guard` mirrors. That module needs the dep **present**, so it must **keep** `:requires_threadline` and **NOT** gain `:threadline_guard` (D-12) — `--only threadline_guard` auto-excludes it. [VERIFIED: grep].

### Anti-Patterns to Avoid
- **`--slowest 10` per shard without measuring its serialization cost.** `--slowest` forces `--trace` forces `--max-cases 1` (see Pitfall 1). Per-shard `--trace` makes each shard run serial; you get parallelism *across* legs but not *within* a leg. Measure first.
- **Enumerating dep-off test paths in ci.yml** (rejected by D-11) — a renamed file silently drops coverage green. Tag selection fails red.
- **Adding `library_tests_shard` to `ci-gate.needs`** (rejected by D-03) — the aggregator already gates the matrix; adding both double-counts and risks a `ci-gate` red on a transient matrix-context resolution.
- **Partition-keying the deps cache** (rejected by D-06) — both legs build identical `deps`/`_build`; one warm `-library-` entry serves both. Keying by partition splits the cache and doubles cold-compile.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Distribute test files across shards | A custom file-splitting script | `mix test --partitions N` + `MIX_TEST_PARTITION` | Built-in, deterministic round-robin, local-reproducible |
| Select the dep-off guard subset | A directory glob or ci.yml path list | `@moduletag :threadline_guard` + `--only` | `--only` fails red on zero match; glob/list fail green on rename (D-11) |
| Aggregate matrix results into one required check | A bespoke status-check API poster | A thin `needs:` aggregator job reusing the protected id/name | Mirrors existing `ci-gate`; no PAT/API surface; ruleset sees a real job context |
| DB isolation per shard | Per-partition DB names + Ecto config | One `services.postgres` per matrix leg | GitHub gives each leg its own container; zero Ecto change (D-05) |
| Repro CI dep-off lane locally | Hand-copying ci.yml steps into a README | `mix sigra.dep_off` alias the lane calls | Single source of truth; CI and local cannot drift (D-14) |

**Key insight:** every "build it" temptation here has a first-class Mix or Actions primitive. The phase's real engineering is the *async-safety checklist* (judgment, D-17), not code.

## Runtime State Inventory

> This is a CI-topology + test-tagging phase, not a rename/migration. No stored data, live-service config, OS-registered state, or build artifacts carry a renamed string. The one rename — worker job `library_tests` → `library_tests_shard`, plus a new aggregator named `library_tests` — is a **YAML job-id change**, covered explicitly below.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — verified: no DB/datastore keys on job names | none |
| Live service config (UI/DB, not git) | **Branch ruleset 14941512** holds the required-check string `Library tests` (lives in GitHub repo settings, NOT git). The aggregator's `name:` must stay byte-identical or the required check orphans. | MANDATORY: `gh api repos/szTheory/sigra/rulesets/14941512` at execution time; confirm `Library tests` is still the required string before merging (D-02 / 194 D-03). |
| OS-registered state | None | none |
| Secrets/env vars | None — `MIX_TEST_PARTITION` is set inline in the shard step; no secret involved | none |
| Build artifacts | The `-library-` and `-library-dep-off-` cache entries persist across runs; D-06 keeps their keys unchanged so no stale-cache risk introduced | none (no key change) |

**Canonical job-id mapping to encode in the plan:**
- `library_tests` (current worker, ci.yml:172) → **rename to** `library_tests_shard`, add `strategy.matrix.partition: [1,2]`, `fail-fast: false`, `name: Library tests shard ${{ matrix.partition }}`.
- **Add new** `library_tests` aggregator job (id reused, `name: Library tests`).
- `ci-gate.needs: library_tests` (ci.yml:1223) and `LIBRARY_TESTS: ${{ needs.library_tests.result }}` (ci.yml:1236) — **unchanged** (D-03); the aggregator reuses the id.

## Common Pitfalls

### Pitfall 1: `--slowest` silently serializes the shard (`--trace` → `--max-cases 1`)  [HIGH — verified]
**What goes wrong:** keeping `mix test --slowest 10` in the per-shard command makes each shard run fully serial. `mix help test`: `--slowest` "Automatically sets `--trace` and `--preload-modules`"; `--trace` "Automatically sets `--max-cases` to `1`". So within a shard there is **no async concurrency** at all.
**Why it happens:** the current `library_tests` lane already runs `--slowest 10` (ci.yml:224) — meaning the *baseline* 15.9m is itself a fully-serial run, not a `max_cases=4` run. Partitioning into 2 legs that are each `--trace`-serial roughly halves serial walltime (the D-04 estimate holds), but leaves the within-shard async lever **completely unused**.
**How to avoid:** Treat the per-shard test command as a measurement decision, not a copy of ci.yml:224. Options to compare in the execution-time probe:
  (a) Keep `--slowest 10` per shard — simplest, preserves identical observability, accepts serial-within-shard.
  (b) Run the shard **without** `--slowest` (parallel within shard at `max_cases=4`) and capture timing via the existing tee+`awk` step against the test stdout, or via `--slowest-modules` only if its `--trace` cost is acceptable. ⚠ `--slowest-modules` *also* forces `--trace` (verified) — so (b) means dropping per-test timing on the hot path and keeping it as a separate diagnostic run if needed.
**Warning signs:** post-change shard walltime ≈ (baseline / N) with no extra speedup → you are still `--trace`-serial; if shard walltime drops *more* than N× you successfully unlocked within-shard async.
**Note for the planner:** D-01 says "keep `--slowest 10`"; this pitfall is the single most material reason to put a measurement gate in front of that choice rather than encoding it as fixed. Either outcome is defensible — but it must be *measured*, per the phase's zero-regression + measurement-gate ethos (CACHE-03 spirit).

### Pitfall 2: Matrix on a protected-name job orphans the required check  [HIGH — verified mechanism]
**What goes wrong:** adding `strategy.matrix` directly to the job named `Library tests` yields contexts `Library tests (1)`/`(2)`; the bare `Library tests` required check never reports → stuck pending → merge blocked.
**How to avoid:** D-02 aggregator. The worker gets a *new* name (`Library tests shard N`); the aggregator owns the protected bare name. Verified the ruleset matches a string and `ci-gate` reads a job id — both satisfied by the aggregator.
**Warning signs:** a PR with a perpetually-pending `Library tests` check after the change merges to a test branch.

### Pitfall 3: Subprocess install/upgrade tests clump onto one shard  [MEDIUM]
**What goes wrong:** round-robin-by-file (verified) can put most of the 11 subprocess tests (~95s+ combined, 193-BASELINE ranks 1–11) on the same partition, making shard balance poor at N=2.
**How to avoid:** accept at N=2 per D-04; add the shard-balance probe to the execution-time measurement; do **not** reflexively jump to N≥3 (diminishing returns vs fixed cost, and Playwright ~22m still bounds wall-clock until Phase 197). Timing-based balancing is explicitly deferred.
**Warning signs:** one shard consistently >20% slower than the other across runs (the D-deferred threshold).

### Pitfall 4: dep-off `--only threadline_guard` accidentally pulls in serial subprocess tests  [MEDIUM]
**What goes wrong:** if a heavy subprocess install test were tagged `:threadline_guard`, the slimmed lane (target <3m, 193-BASELINE) would re-inflate.
**How to avoid:** tag **only** the ~7-8 lightweight guard modules (see D-13 coverage map below). None of them spawn `phx.new` subprocesses — verified: the guard modules are `optional_deps_test`, `config_forwarders_test`, `doctor_test`, `application_forwarders_test`, `mix/tasks/doctor_task_test`, `audit/forwarders/noop_test`, `workers/audit_forward_test` (and optionally `planning/phase_148_*`). All use stubs/process-dict, not subprocesses.
**Warning signs:** dep-off lane walltime > ~3m after slimming → an expensive module got tagged.

### Pitfall 5: `mix sigra.doctor` not available with deps absent  [LOW — verify]
**What goes wrong:** D-13(e) wants the slimmed lane to assert `mix sigra.doctor` reports `threadline: false` without crashing. The doctor task lives in the library (`lib/sigra/doctor.ex`, `lib/mix/tasks/...`) and is compiled in the dep-off lane (compile step is kept, D-09), so the task IS available. But `doctor_task_test.exs` runs the task in-process via `Mix.Tasks.Sigra.Doctor` — confirm it does not require an optional dep at load.
**How to avoid:** the doctor coverage is already exercised by `doctor_test.exs` (asserts `threadline: false` at line 16) and `doctor_task_test.exs` (lines 17, 36) — both pure predicate-map tests, no live dep. Tag both `:threadline_guard`. [VERIFIED: grep].

## Code Examples

### Per-shard worker job skeleton (D-01)
```yaml
# Source: derived from current library_tests (ci.yml:172-247), verified structure
  library_tests_shard:
    name: Library tests shard ${{ matrix.partition }}
    runs-on: ubuntu-latest
    needs: release_ref_guard
    strategy:
      fail-fast: false
      matrix:
        partition: [1, 2]
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: sigra_test
        ports: ['5432:5432']
        options: >-
          --health-cmd pg_isready --health-interval 10s
          --health-timeout 5s --health-retries 5
    steps:
      - uses: actions/checkout@df4cb1c069e1874edd31b4311f1884172cec0e10  # v6.0.3
      - uses: erlef/setup-beam@fc68ffb90438ef2936bbb3251622353b3dcb2f93  # v1.24.0
        id: setup
        with: { version-file: .tool-versions, version-type: strict }
      - name: Cache library deps
        id: deps_cache
        uses: actions/cache@27d5ce7f107fe9357f9df03efb73ab90386fccae  # v5.0.5
        with:
          path: |
            deps
            _build
          # UNCHANGED key (D-06): partition NOT in key — both legs share one warm -library- entry
          key: ${{ runner.os }}-library-otp${{ steps.setup.outputs.otp-version }}-elixir${{ steps.setup.outputs.elixir-version }}-test-${{ hashFiles('mix.lock') }}-v1
          restore-keys: ${{ runner.os }}-library-otp${{ steps.setup.outputs.otp-version }}-elixir${{ steps.setup.outputs.elixir-version }}-test-
      - name: Install Hex + Rebar
        run: mix local.hex --force && mix local.rebar --force
      - name: Install phx_new archive          # SEED-004: keep 1.8.7 pin
        run: mix archive.install --force hex phx_new 1.8.7
      - name: Fetch library deps
        run: mix deps.get
      - name: Run library tests (shard ${{ matrix.partition }})
        env:
          MIX_ENV: test
          MIX_TEST_PARTITION: ${{ matrix.partition }}
          PGUSER: postgres
          PGPASSWORD: postgres
          PGHOST: localhost
        run: |
          set -o pipefail
          # ⚠ Pitfall 1: --slowest forces --trace forces --max-cases 1 (serial within shard).
          # Measurement gate decides whether to keep --slowest 10 here.
          mix test --partitions 2 --slowest 10 2>&1 | tee /tmp/library_tests_${{ matrix.partition }}.log
      # ... per-shard $GITHUB_STEP_SUMMARY timing (reuse Phase-193 awk-on-/tmp/*.log step) ...
      # NOTE: `mix docs --warnings-as-errors` MOVED OUT to fast_checks (D-07) — not here.
```

### `mix sigra.dep_off` alias (D-14)
```elixir
# Source: mix.exs aliases/0 (ci.yml dep-off lane steps 295-315 collapsed into one alias)
# Add to the aliases/0 keyword list (mix.exs:138-151).
"sigra.dep_off": [
  "deps.unlock threadline",
  "deps.clean threadline --build",
  "compile --warnings-as-errors --no-deps-check",   # D-09 proof KEPT
  "test --only threadline_guard --no-deps-check"     # D-10 slimmed run
]
```
Local repro: `MIX_ENV=test mix sigra.dep_off`. The dep-off CI lane's final two steps become `mix sigra.dep_off` so CI and local cannot drift (D-14). Note: the lane's *preceding* `mix deps.compile` (ci.yml:295-298, needed so `--no-deps-check` has deps built on a cache miss) stays a separate ci.yml step **before** the alias — the alias assumes deps are already compiled.

### Moduletag on a guard test (D-10)
```elixir
# Source: mirrors @moduletag :requires_threadline at threadline_test.exs:14
defmodule Sigra.OptionalDepsTest do
  use ExUnit.Case, async: true
  @moduletag :threadline_guard          # NEW — picked up by `mix test --only threadline_guard`
  # ...
end
```

## D-13 Coverage Map (non-negotiable — each assertion has a verified test home)

| D-13 clause | What must be asserted | Verified test home | Tag action |
|-------------|----------------------|--------------------|-----------|
| (a) compiles with `:threadline` absent | `mix compile --warnings-as-errors --no-deps-check` succeeds | dep-off lane **compile step** (kept, D-09) — not a tagged test | none (CI step) |
| (b) `threadline_available?/0 == false` | `== Code.ensure_loaded?(Threadline)` canary | `test/sigra/optional_deps_test.exs:32-34` (`async: true`) | tag `:threadline_guard` |
| (c) boot degrade path: `attach_forwarders/0` skips absent forwarder, one `Logger.warning` | Tests 1–9 (`maybe_warn_missing_forwarder_deps/0`, `attach_forwarders/0`) | `test/sigra/application_forwarders_test.exs` (`async: false` — Application env) | tag `:threadline_guard` |
| (d) no `apply/3`-to-absent-module crash in worker/dispatch path | Noop fallback dispatch + worker dispatch | `test/sigra/audit/forwarders/noop_test.exs` (`async: true`) + `test/sigra/workers/audit_forward_test.exs` (`async: true`) | tag both `:threadline_guard` |
| (e) `mix sigra.doctor` reports `threadline: false` without crashing | predicate-map render asserts `threadline: false` | `test/sigra/doctor_test.exs:16` (`async: true`) + `test/sigra/mix/tasks/doctor_task_test.exs:17,36` | tag both `:threadline_guard` |
| (supporting) config cascade reads forwarders | forwarder config resolution | `test/sigra/config_forwarders_test.exs` (`async: true`) | tag `:threadline_guard` (optional but recommended) |

**Verified key fact for (d):** `lib/sigra/audit/forwarders/threadline.ex` is **entirely wrapped in `if Code.ensure_loaded?(Threadline) do`** (line 1). With the dep absent the module is **never defined**, so the dispatch path falls through to `Sigra.Audit.Forwarders.Noop`. The "no `apply/3` crash" guarantee is therefore the Noop fallback + worker dispatch behaving correctly — exactly what `noop_test.exs` and `audit_forward_test.exs` assert. [VERIFIED: read threadline.ex:1, grep].

**Candidate `:threadline_guard` module set (greppable post-tag via `grep -rl threadline_guard test/`):** `optional_deps_test`, `config_forwarders_test`, `doctor_test`, `application_forwarders_test`, `mix/tasks/doctor_task_test`, `audit/forwarders/noop_test`, `workers/audit_forward_test`. (`planning/phase_148_evaluator_funnel...` references threadline but is a Phase-148 DX test — include only if it asserts a true dep-off guard path; the planner should inspect it.) That is the ~7 modules D-10 anticipates. **`threadline_test.exs` is excluded** (keeps `:requires_threadline`, D-12). [VERIFIED: grep].

## Async Audit Grounding (TEST-03 — D-15..D-20)

**Verified facts:**
- Counts in the tree: **199 `async: true` modules, 66 `async: false` modules** (grep, library test tree). (193-BASELINE said "186 async / 27 non-async"; the tree has grown — use these live numbers, not the baseline's, when reasoning about headroom.) [VERIFIED: grep]
- **No `set_mox_global` anywhere** in the test tree → Mox is private-mode throughout, which is the async-safe mode (D-17 requirement satisfied globally). [VERIFIED: grep]
- `Sigra.Test.PostgresCase` uses `shared: not tags[:async]` (verified, postgres_case.ex) and `Sigra.Test.PostgresRepo` has `pool_size: 4` (verified, `test/support/postgres_test_repo.ex:35`). **Do not change** (D-18). `pool_size: 4` is sufficient for the *default* `max_cases=4`; note that whenever `--slowest`/`--trace` is in effect, `max_cases=1` so the pool is over-provisioned, never under (safe either way). [VERIFIED: read]

**The two named async candidates — verdicts (both currently `async: false`):**

| Candidate | Global state touched? | Verdict | Evidence |
|-----------|----------------------|---------|----------|
| `test/sigra/auth_plain_map_regression_test.exs` | **None.** Uses an in-module `StubRepo` storing rows in the **process dictionary** (`Process.put(:stub_repo_rows, ...)`); no Application/System env, no named ETS, no global telemetry, no real DB. | **SAFE to flip `async: true`** | full read — process-local only |
| `test/sigra/passkeys/rate_limit_test.exs` | **None.** `RecordingLimiter` stores counters in the **process dictionary** keyed by module+key; `send(self(), ...)` / `assert_received` are process-local; config built in-test. | **SAFE to flip `async: true`** | full read — process-local only |

Both are a **floor, not a cap** (D-15). The async checklist (D-17) is the deliverable; the flips are the demonstration. **Measure suite walltime before/after the flips** — with `--trace` in effect they will show *no* speedup (Pitfall 1), so the async measurement is only meaningful on a non-`--trace` run. This is another reason the per-shard command and the async audit are coupled to the same measurement gate.

**Must-stay-serial set (D-16) — confirmed serial-for-correctness, not debt:**
- Subprocess-spawning install/upgrade tests: `Sigra.Install.*`, `Sigra.UpgradeIntegrationTest` (spawn `phx.new`/`sigra.install`; temp-dir + cwd contention if async).
- Durable-DDL tests using `checkout_repo!`/`unboxed_run` (`Sigra.Test.PostgresCase.checkout_repo!` runs **outside** the sandbox — verified — so concurrent runs would race uncommitted DDL).
- Global `:telemetry`-handler tests (`threadline_test.exs` notes "global :telemetry handler state … auto-detach landmine" — verified comment).
- `Application.put_env`/`System.put_env` mutators (`application_forwarders_test.exs` mutates `:sigra`/`:test_app` app env — verified; correctly `async: false`).

**No proactive module-splitting (D-19):** confirmed the serial modules are serial for DDL/telemetry/subprocess reasons; splitting yields two still-serial modules. Leave them.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single 2-core `mix test` for the whole library suite | `mix test --partitions N` across N runners, aggregated by a thin required-check job | This phase (TEST-01) | ~halves serial test walltime at N=2; reusable matrix idiom |
| dep-off lane re-runs the full ~14m suite with `--exclude requires_threadline` | dep-off lane runs `--only threadline_guard` (tagged subset) + keeps the compile proof | This phase (TEST-02) | ~14m → target <3m; fail-red-on-zero-match trust property |
| Larger runners as a default speed lever | Free 2-core standard runners; larger runners only behind a measurement gate | This phase (CACHE-03 / D-21) | $0/min on public repo; larger runners are billed-per-minute even on public repos and do not consume included minutes |

**Deprecated/outdated for this codebase:**
- The "max_cases=4 saturated" framing (193-BASELINE, D-20): **misleading for the actual lane** — `--slowest 10` forces `max_cases=1`. Use the live `--trace` reality when reasoning about the partition win.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `planning/phase_148_evaluator_funnel...test.exs` exercises a genuine threadline-absent guard path (vs. merely referencing the word) | D-13 Coverage Map | LOW — if it is not a guard path, simply omit it from the `:threadline_guard` set; the other 7 modules cover all of D-13(a–e). Planner should inspect it. |
| A2 | The ruleset still requires exactly `Library tests` (and ci-gate is not itself required) at execution time | Runtime State Inventory | HIGH if stale — but mitigated: D-02/194-D-03 mandate re-reading `gh api repos/szTheory/sigra/rulesets/14941512` before merge. Treat as MUST-VERIFY, not assumed. |
| A3 | Dropping/avoiding `--trace` (via not using `--slowest` per shard) is acceptable to the user as a measurement-gated option | Pitfall 1 | MEDIUM — D-01 literally says "keep `--slowest 10`". This research recommends *measuring* that choice, not overriding it. If the user wants `--slowest 10` kept unconditionally, the partition win is still real (serial-per-shard, /N), just smaller than the within-shard-async ceiling. Surface to discuss-phase if the planner wants to relax D-01. |

## Open Questions

1. **Keep `--slowest 10` per shard, or drop it to unlock within-shard async?**
   - What we know: `--slowest`→`--trace`→`max_cases=1` (verified); current baseline is already serial; partitioning at N=2 halves serial time regardless.
   - What's unclear: whether the user values per-test timing on every CI run more than the within-shard-async speedup it forecloses.
   - Recommendation: encode a measurement gate (A/B one shard with vs without `--slowest`, ×3 runs, compare walltime + that observability survives via the tee+awk step). Default to keeping D-01's `--slowest 10` if the async delta is small; this is exactly the CACHE-03 measurement-gate discipline applied to TEST-01.

2. **N=2 shard balance with subprocess-test clumping.**
   - What we know: round-robin-by-file (verified); 11 subprocess tests dominate.
   - What's unclear: which partition they land on (depends on file sort order + count).
   - Recommendation: add the shard-balance line to the per-shard `$GITHUB_STEP_SUMMARY`; do not pre-optimize. Defer timing-balance to the >20%-imbalance trigger (D-deferred).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / `mix test --partitions` | TEST-01 | ✓ | 1.19.5-otp-28 | — |
| `mix test --only` fail-red property | TEST-02 | ✓ | 1.19.x (verified `mix help test`) | — |
| GitHub Actions `strategy.matrix` + `needs` aggregation | TEST-01 | ✓ | n/a (platform) | — |
| `gh` CLI (ruleset re-read at execution) | D-02 verification | ✓ | 2.94.0 (per 193-BASELINE) | manual ruleset UI check |
| Live PostgreSQL for local shard repro | local DX | ✓ (scripts/db/up.sh) | postgres:15 | localhost:5432 fallback |

**Missing dependencies:** none. All mechanisms are platform/stdlib primitives already in use.

## Validation Architecture (Nyquist)

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.19.5 stdlib) |
| Config file | `mix.exs` (`test_load_filters`, `aliases`), `test/test_helper.exs` (sandbox `:manual` mode) |
| Quick run command | `MIX_ENV=test mix sigra.dep_off` (dep-off subset, local) / `MIX_TEST_PARTITION=1 mix test --partitions 2` (single shard, local) |
| Full suite command | `mix test` (library), then CI is the integration check |

### Phase Requirements → Observable Signal Map
| Req ID | Behavior | Test Type | Automated Signal (vs 193-BASELINE) | Where it lives |
|--------|----------|-----------|-------------------------------------|---------------|
| TEST-01 | `library_tests` partitioned, faster, identical signal | CI measurement | Both shard durations + aggregated pass count vs `library_tests` 15.9m baseline; shard walltime ≈ baseline/2 (or better if async unlocked); same total test count (2401) reported across legs; **required check `Library tests` still green & bare** | ci.yml shard + aggregator jobs; `$GITHUB_STEP_SUMMARY` per shard |
| TEST-01 (correctness) | required-check name preserved; ci-gate unchanged | CI structural | `gh api .../rulesets/14941512` shows `Library tests`; PR shows a single bare `Library tests` check resolving (not `(1)`/`(2)`); `ci-gate` green with `needs.library_tests.result == success` | aggregator job; ci-gate |
| TEST-02 | dep-off slimmed, compile proof kept | CI measurement + red-property | dep-off lane walltime ≈ baseline 13.8m → target <3m; **compile step still runs** (`--warnings-as-errors --no-deps-check`); **renaming/removing `:threadline_guard` makes the lane RED** (zero-match), provable by a throwaway tag-drop on a branch | `library_tests_dep_off` lane; `mix sigra.dep_off` alias |
| TEST-02 (coverage) | D-13(a–e) all asserted | unit | `mix test --only threadline_guard` runs ≥7 modules covering compile/predicate/degrade/dispatch/doctor; nonzero test count | tagged guard modules |
| TEST-03 | safe modules async, serial set unchanged, no new flake | unit + repeated-run | The 2 named flips (+ any others passing D-17) are `async: true` and green; **zero new flake** provable via `mix test --repeat-until-failure N` locally on flipped modules and repeated CI runs; serial set still `async: false` | flipped modules; checklist doc |
| TEST-03 (deliverable) | async-safety checklist documented | doc contract | Checklist exists in CONTRIBUTING / testing guide; `# async: false because <reason>` convention standardized | docs |
| CACHE-03 | larger runners NOT adopted absent measurement | structural + runbook | Every job stays `runs-on: ubuntu-latest` (grep); measurement-gate runbook exists with the before/after table template | ci.yml; runbook doc |

### Sampling Rate
- **Per task commit:** `MIX_ENV=test mix sigra.dep_off` (dep-off path) and/or `MIX_TEST_PARTITION=1 mix test --partitions 2` (one shard) locally.
- **Per wave merge:** full `mix test` library suite green.
- **Phase gate:** a real CI run on a PR branch showing (1) bare `Library tests` green, (2) both shard durations recorded, (3) dep-off <3m with the red-property demonstrated once, (4) `ci-gate` green — all diffed against 193-BASELINE in the phase VERIFICATION.

### Wave 0 Gaps
- [ ] `@moduletag :threadline_guard` added to the ~7 guard modules — covers D-13(a–e). (No new test *files* needed; the guard tests already exist — this is a tagging task.)
- [ ] `mix sigra.dep_off` alias in `mix.exs` — enables local==CI repro.
- [ ] Async-safety checklist doc (CONTRIBUTING or `guides/recipes/testing.md`) — the TEST-03 deliverable.
- [ ] Measurement-gate runbook (CACHE-03 / D-23) — short doc with the before/after table.
- *(No framework install needed — ExUnit is present and the suite is comprehensive.)*

## Security Domain

`security_enforcement` not disabled in config → included. This is a CI-topology + test-tagging phase; it introduces **no new auth/crypto/input surface**. The relevant standard controls are supply-chain and required-check integrity, already in place:

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V1 Architecture/CI | yes | All Actions pinned to full SHA (verified across ci.yml); `permissions: contents: read` default; no new action introduced |
| V14 Configuration | yes | Required-check ruleset is the integrity boundary — D-02 preserves it; the aggregator must not weaken the gate (red shard → red aggregator → red ci-gate, verified result-aggregation semantics) |
| V5 Input Validation | no | no user input surface in this phase |
| V6 Cryptography | no | no crypto touched |

| Threat Pattern | STRIDE | Standard Mitigation |
|----------------|--------|---------------------|
| Required check silently dropped by matrix rename → unreviewed merges | Tampering / Elevation | D-02 aggregator + execution-time ruleset re-read (mandatory) |
| dep-off coverage silently lost on tag rename → false-green guard signal | Repudiation | `--only` fail-red-on-zero-match (verified); greppable tag |
| Cache poisoning via partition-split keys | Tampering | D-06 keeps one warm key shape; no partition in key |
| Unpinned action introduced for sharding | Supply chain | No new action needed; matrix is native YAML |

## Sources

### Primary (HIGH confidence)
- `mix help test` on the installed toolchain (Elixir 1.19.5-otp-28) — `--partitions`, `MIX_TEST_PARTITION`, `--only` fail-red, `--slowest`→`--trace`→`max_cases=1`, round-robin-by-file. [VERIFIED: tool]
- `.github/workflows/ci.yml` (read in full) — current `library_tests` (172-247), `library_tests_dep_off` (249-323), `fast_checks` (48), `ci-gate` (1218-1269), all cache keys, all SHAs. [VERIFIED: read]
- `mix.exs` (read) — `aliases/0` shape (138-151), optional deps incl. `:threadline` (119), `elixirc_options` no_warn list. [VERIFIED: read]
- `lib/sigra/optional_deps.ex`, `lib/sigra/audit/forwarders/threadline.ex` (line 1 `if Code.ensure_loaded?` wrap), `lib/sigra/doctor.ex` (170) — guard surfaces. [VERIFIED: read/grep]
- `test/support/postgres_case.ex` (`shared: not tags[:async]`, `checkout_repo!` unboxed), `test/support/postgres_test_repo.ex:35` (`pool_size: 4`), `test/test_helper.exs` (`:manual` sandbox, no global Mox). [VERIFIED: read/grep]
- The two async candidates (full read) + D-13 guard-module set (grep + async-flag inventory). [VERIFIED: read/grep]
- 193-BASELINE.md, 194-CONTEXT.md, 195-CONTEXT.md, REQUIREMENTS.md (TEST-01/02/03, CACHE-03, BASE-02). [VERIFIED: read]

### Secondary (MEDIUM confidence)
- GitHub Actions matrix `needs.<job>.result` aggregation + `fail-fast` semantics — standard documented behavior, cross-checked against the existing `ci-gate` aggregator pattern in this repo. [CITED: docs.github.com/actions]
- Larger-runner billing on public repos (D-21 premise) — carried forward from 195-CONTEXT's verified GitHub Docs citation (not re-fetched this session). [CITED: 195-CONTEXT D-21]

### Tertiary (LOW confidence)
- A1: `phase_148_*` test's exact role in the dep-off guard set — needs a one-line inspection by the planner.

## Metadata

**Confidence breakdown:**
- Partition/aggregator/dep-off mechanics: HIGH — verified against installed `mix help test` and live ci.yml.
- `--slowest`→`--trace`→`max_cases=1` serialization finding: HIGH — verbatim from `mix help test`.
- D-13 coverage homes + async-candidate verdicts: HIGH — full source reads.
- Larger-runner billing premise: MEDIUM — carried from CONTEXT, not re-verified this session.
- `phase_148_*` guard-path role: LOW — inspect before tagging.

**Research date:** 2026-06-20
**Valid until:** 2026-07-20 (stable; the one volatile input is ruleset 14941512, which D-02 mandates re-reading at execution time regardless of this date).
