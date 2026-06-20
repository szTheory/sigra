# Phase 195: Test-Suite Performance (partition / async / dep-off slim) - Pattern Map

**Mapped:** 2026-06-20
**Files analyzed:** 12 (1 CI workflow, 1 mix.exs alias, ~9 test modules, 2 docs)
**Analogs found:** 12 / 12 (every change has an in-repo analog — this is a CI-topology + test-tagging + docs phase with NO application/runtime/migration code)

> Scope note: there is no controller/service/model/component work here. Every "file" is a CI YAML job, a Mix alias entry, an ExUnit moduletag, an `async:` flag flip, or a docs section. Analogs are CI/test/docs structures already in this repo. No feature analogs were invented.

## File Classification

| File (modified/created) | Role | Data Flow | Closest Analog | Match Quality |
|-------------------------|------|-----------|----------------|---------------|
| `.github/workflows/ci.yml` — rename worker → `library_tests_shard` (matrix) | config (CI job) | batch / fan-out | current `library_tests` job (ci.yml:172-247) | exact (in-place transform) |
| `.github/workflows/ci.yml` — new `library_tests` thin aggregator | config (CI gate) | event-driven (result aggregation) | `ci-gate` job (ci.yml:1218-1269) | exact (same `needs`/`if: always()`/result-check shape) |
| `.github/workflows/ci.yml` — relocate `mix docs --warnings-as-errors` | config (CI step) | request-response (single artifact) | `fast_checks` job (ci.yml:48-100) | role-match (leaf-guard consolidation home) |
| `.github/workflows/ci.yml` — `library_tests_dep_off` final step → alias call | config (CI step) | batch | current dep-off lane (ci.yml:249-322) | exact (in-place) |
| `mix.exs` — new `sigra.dep_off` alias | config (build alias) | batch | `aliases/0` (mix.exs:138-151), esp. `ci.install_golden` | exact (same keyword-list idiom) |
| `@moduletag :threadline_guard` on ~7 guard modules | test (tagging) | n/a | `@moduletag :requires_threadline` (threadline_test.exs:13) | exact (mirror tag) |
| `async: true` flip on 2 named modules | test (concurrency flag) | n/a | `Sigra.Test.PostgresCase` `shared: not tags[:async]` (postgres_case.ex:26) | exact (sandbox already async-correct) |
| Async-safety checklist doc | docs | n/a | `CONTRIBUTING.md` §Developing / `guides/recipes/testing.md` §Pitfalls | role-match |
| Measurement-gate runbook doc | docs | n/a | `guides/recipes/local-development.md` structure + `CONTRIBUTING.md` §CI overview | role-match |

## Pattern Assignments

### `.github/workflows/ci.yml` — `library_tests_shard` worker (config, batch fan-out)

**Analog:** current `library_tests` job, ci.yml:172-247 (transform in place — change `name:`, add `strategy.matrix`, parametrize the test command, REMOVE the docs step).

**Job header + matrix to add** (mirrors the existing header at ci.yml:172-186; matrix is the only structural add):
```yaml
  library_tests_shard:
    name: Library tests shard ${{ matrix.partition }}
    runs-on: ubuntu-latest
    needs: release_ref_guard
    strategy:
      fail-fast: false            # D-01: one shard failing must NOT cancel the sibling
      matrix:
        partition: [1, 2]         # D-04: N=2
    services:
      postgres:                   # UNCHANGED from ci.yml:176-186 — per-leg container = free DB isolation (D-05)
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: sigra_test
        ports: ['5432:5432']
        options: >-
          --health-cmd pg_isready --health-interval 10s
          --health-timeout 5s --health-retries 5
```

**Cache step — copy ci.yml:194-202 BYTE-FOR-BYTE (D-06: partition is NOT in the key):**
```yaml
      - name: Cache library deps
        id: deps_cache
        uses: actions/cache@27d5ce7f107fe9357f9df03efb73ab90386fccae  # v5.0.5
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-library-otp${{ steps.setup.outputs.otp-version }}-elixir${{ steps.setup.outputs.elixir-version }}-test-${{ hashFiles('mix.lock') }}-v1
          restore-keys: ${{ runner.os }}-library-otp${{ steps.setup.outputs.otp-version }}-elixir${{ steps.setup.outputs.elixir-version }}-test-
```

**Test run step — copy ci.yml:214-224, ADD `MIX_TEST_PARTITION` + `--partitions 2`** (per-shard log filename must be partition-suffixed so the two legs don't collide):
```yaml
      - name: Run library tests (shard ${{ matrix.partition }})
        env:
          MIX_ENV: test
          MIX_TEST_PARTITION: ${{ matrix.partition }}   # NEW — selects this leg's slice
          PGUSER: postgres
          PGPASSWORD: postgres
          PGHOST: localhost
        run: |
          set -o pipefail
          # ⚠ Pitfall 1: --slowest forces --trace forces --max-cases 1 (serial within shard).
          #   Measurement-gate decides whether to keep --slowest 10 (D-01 vs RESEARCH Open Q1).
          mix test --partitions 2 --slowest 10 2>&1 | tee /tmp/library_tests_${{ matrix.partition }}.log
```

**Observability steps — copy ci.yml:225-245 verbatim, but point `awk` at the partition-suffixed log** (`/tmp/library_tests_${{ matrix.partition }}.log`). This is the Phase-193 `if: always()` + `$GITHUB_STEP_SUMMARY` template:
```yaml
      - name: Test timing summary
        if: always()
        run: |
          {
            echo "## Slowest tests"
            echo '```'
            awk '/slowest/{f=1} f{print} /Finished in/{f=0}' /tmp/library_tests_${{ matrix.partition }}.log 2>/dev/null \
              || echo "(timing output unavailable)"
            echo '```'
          } >> "$GITHUB_STEP_SUMMARY"
```

**REMOVE from this job:** the `Check docs build cleanly` step (ci.yml:246-247) — it relocates to `fast_checks` (D-07). Running it per-shard is N× cost for one artifact.

---

### `.github/workflows/ci.yml` — `library_tests` thin aggregator (config, result aggregation)

**Analog:** `ci-gate` job, ci.yml:1218-1269 — same `needs` + `if: always()` + "fail unless every needed result == 'success'" shape, narrowly scoped to a single matrix dependency so it produces the bare protected name.

**Why this exact shape (D-02, HARD):** a matrix on a job named `Library tests` emits `Library tests (1)`/`(2)` — never bare `Library tests`. Ruleset 14941512 requires the literal string `Library tests`; a bare context never reporting = stuck-pending = merge outage. The aggregator restores both the bare check name AND the job id `library_tests` that `ci-gate.needs` references.

**Aggregator skeleton (mirror of the ci-gate result-loop at ci.yml:1244-1268, collapsed to one dependency):**
```yaml
  library_tests:
    name: Library tests          # BYTE-IDENTICAL to ruleset 14941512 — DO NOT EDIT (D-02)
    runs-on: ubuntu-latest
    needs: [library_tests_shard]
    if: always()                 # mirrors ci-gate:1231 — must run even if a shard fails
    steps:
      - name: Require all library_tests shards to pass
        env:
          SHARDS: ${{ needs.library_tests_shard.result }}   # aggregates the whole matrix:
                                                            #   success only if EVERY leg succeeded
        run: |
          set -euo pipefail
          if [[ "$SHARDS" != "success" ]]; then
            echo "library_tests_shard result: $SHARDS"
            exit 1
          fi
          echo "all library_tests shards passed"
```

**`needs.<matrix-job>.result` semantics (verified):** it is `success` only if every leg succeeded, `failure` if any failed — independent of `fail-fast: false` (which only controls sibling *cancellation*, not the aggregated result). This is the same `result == 'success'` gate `ci-gate` already relies on (ci.yml:1259).

**ci-gate stays UNCHANGED (D-03):** `ci-gate.needs` still lists `library_tests` (ci.yml:1223) and `LIBRARY_TESTS: ${{ needs.library_tests.result }}` (ci.yml:1236) resolve against the aggregator id. Do NOT add `library_tests_shard` to `ci-gate.needs` — double-counts.

---

### `.github/workflows/ci.yml` — relocated `mix docs --warnings-as-errors` (config, single artifact)

**Analog:** `fast_checks` job, ci.yml:48-100 — Phase 194 D-11's consolidated home for leaf guards on a general 2-core runner. Add `mix docs` as one more named `run:` step there (it is a single artifact, core-independent).

**Step to add (lifted verbatim from ci.yml:246-247):**
```yaml
      - name: Check docs build cleanly
        run: mix docs --warnings-as-errors
```
Note: `fast_checks` has no `setup-beam`/deps-fetch today (it runs pure shell guards). The planner must confirm whether `mix docs` needs a `setup-beam` + `deps.get`/`compile` prelude in that job, or whether a different already-compiled job (NOT a shard) is the cheaper home. The decision constraint is D-07 (run once, not per-shard) — the exact host job is the planner's call.

---

### `.github/workflows/ci.yml` — `library_tests_dep_off` final step → alias (config, batch)

**Analog:** current dep-off lane, ci.yml:249-322 (transform in place). Keep steps ci.yml:265-308 EXACTLY (checkout, setup, cache, hex/rebar, phx_new, `deps.get`, `deps.compile`, `deps.unlock`/`deps.clean threadline`, **and the `mix compile --warnings-as-errors --no-deps-check` proof at ci.yml:305-308 — D-09 load-bearing**).

**Only the final run step changes (ci.yml:309-315):**
```yaml
      # BEFORE (ci.yml:309-315):
      - name: Run library tests (Threadline absent)
        env: { MIX_ENV: test, PGUSER: postgres, PGPASSWORD: postgres, PGHOST: localhost }
        run: mix test --exclude requires_threadline --no-deps-check

      # AFTER (D-10/D-14) — the lane calls the alias so local==CI:
      - name: Run guard subset (Threadline absent)
        env: { MIX_ENV: test, PGUSER: postgres, PGPASSWORD: postgres, PGHOST: localhost }
        run: mix test --only threadline_guard --no-deps-check
```
RESEARCH caveat: the alias bundles unlock/clean/compile/test; the lane already does unlock/clean (ci.yml:299-304) and the compile proof (ci.yml:305-308) as discrete steps. The planner decides whether the lane's final step calls the whole `mix sigra.dep_off` alias (and drops the now-redundant discrete steps) or just runs `mix test --only threadline_guard`. Either way the alias is the single-source-of-truth for LOCAL repro (`MIX_ENV=test mix sigra.dep_off`).

---

### `mix.exs` — `sigra.dep_off` alias (config, batch)

**Analog:** `aliases/0`, mix.exs:138-151 — the existing `ci.install_golden` / `ci.audit_45` entries are the exact keyword-list-of-shell-task-strings idiom to copy.

**Existing pattern (mix.exs:143-145):**
```elixir
"ci.install_golden": [
  "test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs"
],
```

**New entry to add inside the `aliases/0` list (D-14):**
```elixir
"sigra.dep_off": [
  "deps.unlock threadline",
  "deps.clean threadline --build",
  "compile --warnings-as-errors --no-deps-check",   # D-09 proof KEPT
  "test --only threadline_guard --no-deps-check"     # D-10 slimmed run
],
```
Local repro: `MIX_ENV=test mix sigra.dep_off`. Document in `guides/recipes/local-development.md` (it already has a "Postgres for `mix test`" section — add a dep-off-repro note there).

---

### `@moduletag :threadline_guard` on ~7 guard modules (test, tagging)

**Analog:** `@moduletag :requires_threadline`, `test/sigra/audit/forwarders/threadline_test.exs:13` — the existing moduletag idiom this new tag mirrors exactly.

**Existing pattern (threadline_test.exs:12-13):**
```elixir
  use Sigra.Test.PostgresCase, async: false
  @moduletag :requires_threadline
```

**Tag to add — one line directly under each module's `use ExUnit.Case…`:**
```elixir
  @moduletag :threadline_guard
```

**Modules to tag (verified set — D-13 coverage map):**

| Module | Current header | D-13 clause covered |
|--------|----------------|---------------------|
| `test/sigra/optional_deps_test.exs` | `use ExUnit.Case, async: true` | (b) `threadline_available?/0 == false` canary |
| `test/sigra/application_forwarders_test.exs` | `use ExUnit.Case, async: false` | (c) boot degrade path, one `Logger.warning` |
| `test/sigra/audit/forwarders/noop_test.exs` | `use ExUnit.Case, async: true` | (d) Noop fallback dispatch (no `apply/3` crash) |
| `test/sigra/workers/audit_forward_test.exs` | `use ExUnit.Case, async: true` | (d) worker dispatch path |
| `test/sigra/doctor_test.exs` | `use ExUnit.Case, async: true` | (e) doctor reports `threadline: false` |
| `test/sigra/mix/tasks/doctor_task_test.exs` | `use ExUnit.Case` (default async: false) | (e) doctor task in-process |
| `test/sigra/config_forwarders_test.exs` | `use ExUnit.Case, async: true` | (supporting) forwarder config cascade |

**MUST NOT tag (D-12):** `test/sigra/audit/forwarders/threadline_test.exs` keeps `:requires_threadline` (needs the dep PRESENT); `--only threadline_guard` auto-excludes it. Verify it does not also gain `:threadline_guard`.

**Inspect-before-tagging (A1, LOW):** `test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs` references threadline — include in the tag set ONLY if it asserts a true dep-off guard path; the other 7 cover all of D-13(a–e) regardless.

**Greppable invariant:** `grep -rl threadline_guard test/` enumerates the set; `mix test --only threadline_guard` fails RED on zero matches (the D-11 trust property — verified via `mix help test`).

---

### `async: true` flip on 2 named modules (test, concurrency flag)

**Analog:** `Sigra.Test.PostgresCase`, `test/support/postgres_case.ex:22-32` — `shared: not tags[:async]` already makes the sandbox async-correct; NO sandbox change is needed (D-18). The flip is a one-token edit on each module's `use` line.

**Sandbox pattern that makes the flip safe (postgres_case.ex:22-31):**
```elixir
    setup tags do
      sandbox_owner =
        Ecto.Adapters.SQL.Sandbox.start_owner!(
          Sigra.Test.PostgresRepo,
          shared: not tags[:async]      # async test → isolated (not shared) connection
        )
      on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(sandbox_owner) end)
```

**Flips (both currently `async: false`, both verified process-local-only → SAFE):**

| Module | Current (verified) | Change to |
|--------|--------------------|-----------|
| `test/sigra/auth_plain_map_regression_test.exs:28` | `use ExUnit.Case, async: false` | `use ExUnit.Case, async: true` |
| `test/sigra/passkeys/rate_limit_test.exs:2` | `use ExUnit.Case, async: false` | `use ExUnit.Case, async: true` |

Both store state in the **process dictionary** (`StubRepo` / `RecordingLimiter`), touch no Application/System env, named ETS, or global telemetry — they pass the D-17 checklist. These two are a FLOOR, not a cap (D-15): flip any other module that passes the checklist on inspection.

**Must-stay-serial set — DO NOT flip (D-16), serial-for-correctness:** `Sigra.Install.*` / `Sigra.UpgradeIntegrationTest` (subprocess + cwd/temp contention), `checkout_repo!`/`unboxed_run` durable-DDL tests, global `:telemetry`-handler tests (e.g. threadline_test.exs:6-8 comment), `Application.put_env`/`System.put_env` mutators (application_forwarders_test.exs).

---

### Async-safety checklist doc (docs)

**Analog:** `CONTRIBUTING.md` §Developing (line 3) for the contributor-facing rule, and/or `guides/recipes/testing.md` §Pitfalls (line 220) for the test-authoring home. Standardize the existing `# async: false because <reason>` comment convention already used in `threadline_test.exs:6-8`:
```elixir
  # NOTE: async: false required because:
  # (1) live Postgres in Test 5 ...
  # (2) global :telemetry handler state ...
```
The checklist (D-17) is the lasting deliverable: a module is async-safe ONLY if it touches no shared mutable global state (Application/System env, `:persistent_term`, named ETS, named/singleton processes, global telemetry handlers, fs/cwd/temp-dirs/archives), does DB access sandboxed-only (no durable DDL), uses private-mode Mox only (no `set_mox_global` — verified absent repo-wide), keeps state process-local.

---

### Measurement-gate runbook doc (docs)

**Analog:** `guides/recipes/local-development.md` (TL;DR gameplan + numbered-step structure) for the doc shape, and `CONTRIBUTING.md` §CI overview (line 11) for the CI-facing home. The runbook (D-23) is short: baseline from `193-BASELINE.md` → A/B one job on a larger label ×3 runs → measure wall-clock + billed-minutes + cache-hit → apply the D-22 decision rule → record a before/after table. Place where the planner judges best (the existing `guides/recipes/*.md` numbered-runbook format is the template).

## Shared Patterns

### CI result-aggregation gate (applies to: the new `library_tests` aggregator)
**Source:** `ci-gate` job, `.github/workflows/ci.yml:1218-1269`
```yaml
    needs: [ ... ]
    if: always()
    steps:
      - run: |
          set -euo pipefail
          result="${!lane}"
          if [[ "$result" != "success" ]]; then exit 1; fi
```
The `if: always()` + `result != "success"` → `exit 1` shape is the canonical "gate on a dependency's outcome" idiom in this repo. The aggregator is the single-dependency narrowing of it.

### Per-job Postgres service container (applies to: `library_tests_shard` each leg)
**Source:** `.github/workflows/ci.yml:176-186` (and replicated in install/dep-off/example jobs)
Every DB-touching CI job declares its OWN `services.postgres` (static `sigra_test`). Copy the block unchanged into the shard job — each matrix leg gets an independent container = automatic per-shard DB isolation (D-05), no Ecto/`config/test.exs` change.

### Phase-193 `$GITHUB_STEP_SUMMARY` observability (applies to: each shard leg)
**Source:** `.github/workflows/ci.yml:225-245`
`if: always()` shell steps that scrape a tee'd `/tmp/*.log` into `$GITHUB_STEP_SUMMARY`. Reuse verbatim per shard; the only change is the partition-suffixed log path so the two legs don't overwrite each other.

### Cache key shape (applies to: `library_tests_shard`)
**Source:** `.github/workflows/ci.yml:201-202`
`${{ runner.os }}-library-otp…-elixir…-test-${{ hashFiles('mix.lock') }}-v1`. Copy byte-for-byte; the partition is deliberately NOT in the key (D-06) so both legs share one warm `-library-` entry.

### Mix alias keyword-list idiom (applies to: `sigra.dep_off`)
**Source:** `mix.exs:138-151` — `"<name>": ["task arg arg", ...]`. The new alias is one more entry in the same list.

### Moduletag idiom (applies to: the ~7 guard modules)
**Source:** `test/sigra/audit/forwarders/threadline_test.exs:13` — `@moduletag :requires_threadline`. The new `:threadline_guard` is the identical one-line idiom (inverse selection).

## No Analog Found

None. Every change maps to an existing CI job, Mix alias, moduletag, sandbox config, or guide doc in this repo.

## Metadata

**Analog search scope:** `.github/workflows/ci.yml` (full job set), `mix.exs` (`aliases/0`), `test/support/postgres_case.ex`, `test/sigra/**` (guard modules + async candidates), `guides/recipes/`, `guides/reference/`, `CONTRIBUTING.md`.
**Files scanned:** ci.yml (4 job regions), mix.exs (aliases), postgres_case.ex (full), 9 test modules (headers + tags), 3 docs (structure).
**Pattern extraction date:** 2026-06-20
