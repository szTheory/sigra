---
phase: 195-test-suite-performance-partition-async-dep-off-slim
verified: 2026-06-20T14:05:00Z
status: passed
score: 4/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 195: Test-Suite Performance (Partition / Async / Dep-Off Slim) Verification Report

**Phase Goal:** Partition `library_tests` into evidence-chosen parallel shards with isolated per-shard Postgres (TEST-01); slim `library_tests_dep_off` to a targeted Threadline-absent guard subset (TEST-02); audit/convert safe `async: true` modules without flake under partitioning (TEST-03); apply larger runners only if measurement justifies, otherwise not, with a recorded runbook (CACHE-03).
**Verified:** 2026-06-20T14:05:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Success Criteria)

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | TEST-01 — `library_tests` runs as evidence-chosen parallel partitions with isolated per-shard Postgres; same tests pass; any coverage merge correct | ✓ VERIFIED | ci.yml parses: `library_tests_shard` job has `strategy.matrix.partition: [1, 2]`, `fail-fast: false`, own `services.postgres` (per-leg DB isolation), `runs-on: ubuntu-latest`. Test step sets `MIX_TEST_PARTITION: ${{ matrix.partition }}` and runs `mix test --partitions 2 --slowest 10`. N=2 chosen from recorded A/B measurement (Option a, D-01 default). Coverage merge clause is N/A — no `--cover`/excoveralls tooling exists in ci.yml or mix.exs (correct disposition). |
| 2 | TEST-02 — `library_tests_dep_off` proves Threadline-absent compile/guard paths via a targeted subset, materially faster than the full-suite rerun | ✓ VERIFIED | Dep-off lane keeps D-09 compile proof (`mix compile --warnings-as-errors --no-deps-check`) then runs `mix test --only threadline_guard --no-deps-check`; `--exclude requires_threadline` removed. Behavioral spot-check (live DB): `mix test --only threadline_guard` → **65 tests, 0 failures (2372 excluded) in 3.6s**, proving nonzero selection (fail-red property) and material speedup vs the ~13.8m baseline. |
| 3 | TEST-03 — newly-async modules are async-safe (no global-state mutator marked async); sandbox/pool correct under partitioning; no flake | ✓ VERIFIED | Exactly 2 modules flipped to `async: true` (`auth_plain_map_regression_test.exs:28`, `passkeys/rate_limit_test.exs:2`), both process-dictionary-only stubs. `application_forwarders_test.exs` (Application-env mutator) confirmed still `async: false`. Behavioral spot-check (live DB): both flipped files → **7 tests, 0 failures**. Sandbox config untouched (`shared: not tags[:async]` per D-18). Async-safety checklist shipped in testing.md. |
| 4 | CACHE-03 — larger-runner usage justified by recorded before/after measurement, or not used | ✓ VERIFIED | All 16 `runs-on:` entries = `ubuntu-latest` (16/16); no larger-runner label adopted. Measurement-gate runbook present in local-development.md with D-22 decision rule, D-21 billing fact, A/B procedure, and before/after table template. Reject-by-default posture recorded. |

**Score:** 4/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `.github/workflows/ci.yml` (shard worker) | `library_tests_shard` matrix worker | ✓ VERIFIED | partition [1,2], fail-fast false, per-leg postgres, `mix test --partitions 2` |
| `.github/workflows/ci.yml` (aggregator) | `library_tests` thin aggregator, `name: Library tests` byte-identical | ✓ VERIFIED | name exactly `Library tests`; `needs: [library_tests_shard]`; `if: always()`; gate step reads `needs.library_tests_shard.result` via `SHARDS` env, exits 1 unless `success` |
| `.github/workflows/ci.yml` (dep-off) | slimmed `library_tests_dep_off` final step | ✓ VERIFIED | `mix test --only threadline_guard --no-deps-check`; D-09 compile proof retained; `mix docs --warnings-as-errors` relocated here (count = 1, non-shard) |
| `mix.exs` | `sigra.dep_off` alias | ✓ VERIFIED | 4 steps in order: unlock → clean → compile --warnings-as-errors --no-deps-check → test --only threadline_guard --no-deps-check |
| 7 guard test modules | `@moduletag :threadline_guard` | ✓ VERIFIED | Real `@moduletag :threadline_guard` lines in exactly the 7 named modules; threadline_test.exs keeps only `:requires_threadline` (D-12); phase_148 excluded (A1) |
| `guides/recipes/testing.md` | Async-safety checklist | ✓ VERIFIED | "Is this test allowed to be async: true?" section: global-state items (Application/System env, persistent_term, named ETS, telemetry, `set_mox_global`, fs/cwd, durable DDL), `# async: false because <reason>` convention, partitioning note |
| `guides/recipes/local-development.md` | dep-off repro + CACHE-03 runbook | ✓ VERIFIED | `MIX_ENV=test mix sigra.dep_off` repro note + "Larger-runner measurement gate (CACHE-03)" runbook with decision rule, billing fact, before/after template |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `library_tests` aggregator | `library_tests_shard` matrix | `needs.library_tests_shard.result == 'success'` | ✓ WIRED | aggregator `needs: [library_tests_shard]`; gate step env `SHARDS: ${{ needs.library_tests_shard.result }}`, fails unless `success` |
| `ci-gate` | `library_tests` aggregator | `needs.library_tests` (unchanged id, D-03) | ✓ WIRED | `library_tests` in ci-gate.needs; `library_tests_shard` NOT in ci-gate.needs (no double-count) |
| `mix.exs sigra.dep_off` | `test --only threadline_guard` | alias final step | ✓ WIRED | alias final step is `test --only threadline_guard --no-deps-check`, byte-matching the CI dep-off final command (no-drift, D-14) |
| 7 guard modules | `threadline_guard` tag | `@moduletag` picked up by `--only` | ✓ WIRED | `mix test --only threadline_guard` selects 65 tests (nonzero, live run) |
| dep-off lane final step | `threadline_guard` subset | `mix test --only threadline_guard --no-deps-check` | ✓ WIRED | present in ci.yml; `--exclude requires_threadline` absent |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Guard subset selects nonzero & green (TEST-02 fail-red + speedup) | `mix test --only threadline_guard` | 65 tests, 0 failures (2372 excluded), 3.6s | ✓ PASS |
| Async-flipped modules green under async (TEST-03 no-flake) | `mix test auth_plain_map_regression_test.exs passkeys/rate_limit_test.exs` | 7 tests, 0 failures (`max_cases: 36`, async) | ✓ PASS |
| ci.yml topology valid (TEST-01) | `yaml.safe_load` + assertions | matrix [1,2], fail-fast false, aggregator name `Library tests`, ci-gate wiring intact | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| TEST-01 | 195-02 | Partition library_tests across shards, isolated PG, evidence-chosen N | ✓ SATISFIED | 2-shard matrix + per-leg postgres + aggregator; N=2 measured |
| TEST-02 | 195-01, 195-03 | Slim library_tests_dep_off to targeted Threadline-absent subset | ✓ SATISFIED | 7-module guard tag + `--only threadline_guard` lane; 65 tests vs ~14m suite |
| TEST-03 | 195-01 | Audit async, convert safe, no global-state mutator async, sandbox correct | ✓ SATISFIED | 2 safe flips green; serial set untouched; checklist shipped; sandbox config unchanged |
| CACHE-03 | 195-03 | Larger runners selectively, only if measured; else not used; runbook | ✓ SATISFIED | All runners ubuntu-latest; measurement-gate runbook with before/after template |

REQUIREMENTS.md note: lines 25-27/39 are checked `[x]` for all four IDs, but the traceability table (line 74) still shows `TEST-01, TEST-02, TEST-03 | 195 | Pending`. This is a stale status-table cell, not a goal failure — the implementation evidence above satisfies all four. (Minor doc-hygiene follow-up; does not block.)

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| — | — | None | — | No TBD/FIXME/XXX in phase-modified files; no stubs; comments are documentation of measured decisions, not debt |

### Post-Merge Gate Triage (orchestrator-supplied, independently re-confirmed)

- Phase58 OA-01 ci-contract regression caused by partitioning: FIXED in `ca9ac843` (re-anchored the structural lock onto `library_tests_shard`). Commit present and verified.
- All 6 phase commits present: `1eae478a`, `d1220f52`, `b222b301`, `fbc4d145`, `3d916910`, `3ab7ad4e` (+ fix `ca9ac843`).
- The other 5 full-suite failures are pre-existing/environmental (Phase51 ci-contract baseline; GoldenDiffTest local phx_new 1.8.8 vs pinned 1.8.7 per CLAUDE.md; 3 UpgradeIntegrationTest env DB-creation failures that pass in CI) — NOT caused by this phase.

### Human Verification Required

None. All four success criteria are verified by codebase inspection plus live behavioral spot-checks (guard subset 65/0, async flips 7/0). The two CI-runtime properties that need GitHub to observe (bare `Library tests` required check resolving green on a PR; per-shard wall-clock ~halving) are deterministically wired and were re-confirmed against ruleset 14941512 byte-identically during 195-02 — no human gate added.

### Gaps Summary

No gaps. All must-haves (4 truths, 7 artifacts, 5 key links) verified. The dep-off subset and async flips were exercised against a live test Postgres and passed. The CI topology parses and wires the protected required check, aggregator, and ci-gate exactly as specified. CACHE-03 correctly results in no larger-runner adoption with the measurement runbook shipped. The only observation is a stale "Pending" cell in the REQUIREMENTS.md traceability table (the per-ID checkboxes are already `[x]`), which is doc hygiene, not a goal miss.

---

_Verified: 2026-06-20T14:05:00Z_
_Verifier: Claude (gsd-verifier)_
