---
phase: 195-test-suite-performance-partition-async-dep-off-slim
plan: "02"
subsystem: ci
tags: [ci, github-actions, matrix, partition, required-check, test-performance]
dependency_graph:
  requires: [195-01-SUMMARY.md]
  provides: [library_tests 2-shard matrix worker, library_tests thin aggregator, mix docs relocated]
  affects: [.github/workflows/ci.yml, ruleset 14941512 required-check Library tests]
tech_stack:
  added: []
  patterns: [GitHub Actions matrix strategy, result-aggregation thin job, per-leg postgres service]
key_files:
  modified:
    - .github/workflows/ci.yml
decisions:
  - "Measurement gate (Task 2): Option (a) chosen — keep --slowest 10 per shard (D-01 default). Local A/B probe showed ~47% speedup on async-only files without --slowest, but the serial subprocess/DDL test tail (~11 files, 23-33s each) bounds actual shard walltime. Partition win (~halving the ~14m test portion to ~7-8m) is the primary gain; within-shard async is deferred per D-15/D-20."
  - "mix docs relocation (Task 3, D-07): hosted on library_tests_dep_off (already has compiled toolchain: setup-beam + deps + compile; not a shard; runs once per CI run). Preferred option fast_checks would require adding a full Elixir toolchain prelude (~2-3m overhead); library_tests_dep_off already satisfies all requirements at zero added cost."
  - "Ruleset 14941512 confirmed at execution time: required check string is byte-identical 'Library tests' — aggregator name is safe."
metrics:
  duration_minutes: 5
  completed: "2026-06-20"
  tasks: 3
  files_modified: 1
status: complete
---

# Phase 195 Plan 02: Partition library_tests + Aggregator + Docs Relocation Summary

**One-liner:** 2-shard matrix worker (`library_tests_shard`) with name-preserving aggregator (`library_tests`) preserves the `Library tests` required check byte-identical; `mix docs` relocated to `library_tests_dep_off` for single-run execution (D-01..D-08).

## What Was Built

### Task 1: library_tests_shard matrix worker + library_tests thin aggregator (TEST-01 / D-01..D-06)

**Mandatory execution-time guardrail (D-02):** Confirmed `gh api repos/szTheory/sigra/rulesets/14941512` before editing. Ruleset 14941512 requires status check string `"Library tests"` (byte-identical). The aggregator's `name:` field is safe to set to exactly this string.

**Worker job (`library_tests_shard`):**
- Renamed from `library_tests`; `name: Library tests shard ${{ matrix.partition }}`
- `strategy.fail-fast: false` (D-01: one shard failing must not cancel the sibling)
- `strategy.matrix.partition: [1, 2]` (D-04: N=2)
- Each leg keeps its own `services.postgres` container — automatic per-leg DB isolation (D-05)
- Cache key unchanged from Phase 194 (D-06): partition NOT in key; both legs share one warm `-library-` entry
- `MIX_TEST_PARTITION: ${{ matrix.partition }}` env added to test step
- Test command: `mix test --partitions 2 --slowest 10` (see Task 2 for measurement gate)
- Log path partition-suffixed: `/tmp/library_tests_${{ matrix.partition }}.log` (no collision between legs)
- `$GITHUB_STEP_SUMMARY` observability steps point at partition-suffixed log
- `mix docs` step removed (relocated in Task 3, D-07)

**Aggregator job (`library_tests`):**
- Job id `library_tests` reused (D-03: ci-gate unchanged)
- `name: Library tests` — byte-identical to ruleset 14941512 required check string (D-02, HARD)
- `needs: [library_tests_shard]`, `if: always()`
- Single step: fails unless `needs.library_tests_shard.result == 'success'` (aggregates whole matrix)

**ci-gate unchanged (D-03):**
- Still `needs: library_tests` (aggregator id), not `library_tests_shard`
- `LIBRARY_TESTS: ${{ needs.library_tests.result }}` resolves against aggregator — no rewiring needed

### Task 2: Per-shard test command measurement gate (RESEARCH Pitfall 1)

**A/B measurement performed locally:**

| Option | Command | Mechanism | Local timing (single async-only file) |
|--------|---------|-----------|---------------------------------------|
| (a) — CHOSEN | `mix test --partitions 2 --slowest 10` | `--slowest` → `--trace` → `--max-cases 1` (serial within shard) | 1598ms |
| (b) — not adopted | `mix test --partitions 2` | async within shard at `max_cases=4` | 849ms |
| Delta | — | — | ~47% speedup on async-only files |

**Decision: Option (a) chosen (D-01 default).**

Rationale: The ~47% speedup on a small async-only file does not represent the full suite. The real serial bottleneck is the ~11 subprocess install/upgrade test files (23-33s each, ranked 1-11 in 193-BASELINE) — these are serial for correctness reasons (subprocess + cwd/temp contention) and cannot benefit from within-shard async regardless of `--max-cases`. The partition win itself (~halving the ~14m test portion to ~7-8m wall-clock) is the load-bearing gain for TEST-01. Dropping `--slowest` (Option b) would sacrifice per-test timing observability in `$GITHUB_STEP_SUMMARY` for a marginal additional speedup bounded by the subprocess tail. Option (b) deferred to a future phase if the subprocess serial tail is addressed (D-15/D-20).

**Warning sign documented (per plan):** If post-change shard walltime ≈ (baseline / N) with no extra speedup, the shard is still `--trace`-serial (expected under Option a). If shard walltime drops more than N×, within-shard async was unlocked (Option b would have paid off).

**Inline comment in ci.yml:** Records which option was chosen and measurement rationale in the shard test step.

### Task 3: Relocate mix docs --warnings-as-errors to a compiled non-shard job (D-07)

**Host chosen: `library_tests_dep_off`**

Rationale:
- Already has the full compiled toolchain: `erlef/setup-beam`, `mix deps.get`, `mix deps.compile`, and `mix compile --warnings-as-errors --no-deps-check`
- Not a shard (runs exactly once per CI run, not N times)
- Not the aggregator
- Zero added overhead — the compile step already satisfies `ex_doc`'s requirements

**Alternative considered (fast_checks):** The plan's "preferred" option, but `fast_checks` has no `setup-beam` or deps today. Adding a full Elixir toolchain prelude (~2-3 minutes: setup-beam + cache + hex/rebar + deps.get + compile) would increase `fast_checks` walltime significantly and make it heavyweight. `library_tests_dep_off` is the clean host.

**Acceptance criteria met:**
- `grep -c 'mix docs --warnings-as-errors' .github/workflows/ci.yml` = 1
- That single step is on `library_tests_dep_off` (non-shard job with compiled toolchain)
- `library_tests_shard` contains no `mix docs` step

## Verification Results

All task verification checks passed:

```
TOPOLOGY_OK
TASK2_VERIFY_OK
DOCS_RELOCATED_OK
```

Detailed verification:
- `library_tests_shard` has matrix `partition: [1, 2]` and `fail-fast: false`
- Aggregator `library_tests` has `name: Library tests` (exact), `needs: [library_tests_shard]`, `if: always()`
- `ci-gate.needs` contains `library_tests` and does NOT contain `library_tests_shard` (D-03)
- `mix test --partitions 2 --slowest 10` in shard step with `MIX_TEST_PARTITION: ${{ matrix.partition }}`
- `mix docs --warnings-as-errors` appears exactly once, in `library_tests_dep_off`

## Ruleset Confirmation

Executed before editing: `gh api repos/szTheory/sigra/rulesets/14941512`

Confirmed: `"context":"Library tests"` — byte-identical. The aggregator `name: Library tests` is safe. The required check in ruleset 14941512 matches the aggregator's output context exactly. ci-gate wiring is preserved.

## Deviations from Plan

### Auto-fixed Issues

None.

### Planned Deviations

**1. [Planner option] mix docs host: library_tests_dep_off instead of fast_checks**
- **Decision context:** Task 3 offered two options: (1) add toolchain prelude to `fast_checks`, or (2) use another already-compiled non-shard job
- **Choice:** Option 2 — `library_tests_dep_off`
- **Why:** `library_tests_dep_off` already has setup-beam, deps, and compile at zero added cost; adding a toolchain prelude to `fast_checks` would add ~2-3m overhead and make it heavyweight
- **D-07 satisfied:** `mix docs` runs exactly once, not per shard

## Known Stubs

None. This is a CI topology change with no application code stubs.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The only trust-boundary mutation was the ci.yml job topology, which was addressed by the mandatory ruleset re-read (D-02 / T-195-03 mitigate).

| Flag | File | Description |
|------|------|-------------|
| T-195-03 mitigated | .github/workflows/ci.yml | Ruleset 14941512 re-read confirmed `Library tests` byte-identical before edit; aggregator restores bare required check context |

## Self-Check: PASSED

- FOUND: `.github/workflows/ci.yml`
- FOUND: `.planning/phases/195-test-suite-performance-partition-async-dep-off-slim/195-02-SUMMARY.md`
- FOUND commit: `fbc4d145` — feat(195-02): partition library_tests into 2-shard matrix + name-preserving aggregator + relocate docs
- YAML parses as valid; all 16 jobs present including `library_tests_shard` and `library_tests` aggregator
