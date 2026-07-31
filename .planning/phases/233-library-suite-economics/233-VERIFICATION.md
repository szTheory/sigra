---
phase: 233-library-suite-economics
verified: 2026-07-31T23:29:58Z
status: passed
score: 16/16 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 7/8
  gaps_closed:
    - "The measured manifest is exhaustive and self-invalidating on ordinary-test coverage drift; required CI cannot pass while an intended ordinary library test is omitted."
  gaps_remaining: []
  regressions: []
---

# Phase 233: Library Suite Economics Verification Report

**Phase Goal:** The library shards do not become the new pole once Playwright stops being one.
**Verified:** 2026-07-31T23:29:58Z
**Status:** passed
**Re-verification:** Yes — after Plan 233-06 gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Ordinary shards retain ExUnit parallelism and same-run slow-test visibility. | ✓ VERIFIED | The shard has exactly one `mix test`, no `--trace`/`--slowest`, and configures both `ExUnit.CLIFormatter` and `Sigra.CI.ExUnitTimingFormatter` with a shard-owned fixed receipt path. GitHub PR run `30668911851`, attempt 1, shows both legs starting one second apart and succeeding. |
| 2 | Timing receipts are deterministic, safe, and handle empty/malformed completed-test inputs correctly. | ✓ VERIFIED | `ExUnitTimingFormatter` sorts entries, permits only the three CI paths, atomically writes receipts, and raises on malformed events. `mix test test/support/ci/ex_unit_timing_formatter_test.exs` passed: 5 tests. |
| 3 | The timing-probe evidence is a retry-free PR observation with usable measured costs and inherited baseline. | ✓ VERIFIED | `233-EVIDENCE.json` records timing probe `30666977944`, `pull_request`, attempt 1, both receipt identities, 217 per-file costs, and the 470s/278s baseline. |
| 4 | The measured two-list assignment uses costs rather than test count and preserves deterministic tie behavior. | ✓ VERIFIED | `assign!/1` orders by descending `time_us` then path and assigns exact ties to partition 1. The focused contract exercises lexical equal-cost ordering and tie ownership. |
| 5 | The ordinary suite is owned exactly once by two shards; the exact six scaffold modules are excluded and template render remains ordinary. | ✓ VERIFIED | Live production expansion returned 107 and 104 paths; `build_partitions!/0` reports `current=211 assigned=211 unique=211`. The contract verifies the six tags, exact exclusion, and template-render inclusion. |
| 6 | The scaffold receiver runs on every PR and retains upgrade, golden-diff, and idempotency coverage. | ✓ VERIFIED | `library_tests_scaffold` has no docs/path/event gate and runs `mix test --only scaffold`. Run `30668911851` was a successful PR run; its evidence names the three required files and records the 909s receiver. |
| 7 | `Library tests` remains merge-blocking and fails closed unless both ordinary matrix legs and the scaffold receiver succeed. | ✓ VERIFIED | The aggregate has `needs: [library_tests_shard, library_tests_scaffold]`, `if: always()`, and rejects either non-`success` result. The contract exercises topology and the observed aggregate succeeded in run `30668911851`. |
| 8 | The observed ordinary after-gap is materially smaller while no coverage was deleted. | ✓ VERIFIED | Final PR evidence at functional SHA `6974bd1e2e4214fd5b9d519a987dfef2c3e89b89` records 115s/114s ordinary jobs: a 1s gap versus the inherited 192s gap; ordinary receipts contain no scaffold paths. |
| 9 | The current eligible ordinary universe is discovered through the actual project `test_load_filters` before either shard launches tests. | ✓ VERIFIED | `current_ordinary_paths!/1` enumerates `test/**/*_test.exs`, normalizes repo-relative paths, and applies `Mix.Project.config()[:test_load_filters]`; current `mix.exs` filters exclude only the example/fixtures subtrees. |
| 10 | A current ordinary test omitted from historical receipt-derived ownership fails closed rather than being silently appended or skipped. | ✓ VERIFIED | `build_partitions!/1` invokes `validate_current_universe!/2`; the deterministic temporary-filesystem test writes `test/new_ordinary_test.exs` without a cost and asserts the named missing-path `ArgumentError`. The 14-test contract passed. |
| 11 | Drift validation rejects missing, stale, duplicate, scaffold-leaking, and empty ownership. | ✓ VERIFIED | `validate_current_universe!/2` checks non-empty exact-once assignment, scaffold leakage, and both set-difference directions. Focused tests cover each mutation with named diagnostics. |
| 12 | A validator or selector failure cannot be masked by shell plumbing; an empty selector also stops before test execution. | ✓ VERIFIED | The CI selector uses an exit-status-preserving command substitution under `set -euo pipefail`, then checks non-empty output/argv/members before its sole `mix test`. The executable shell-harness contract proves a failing selector never reaches its sentinel and a success reaches it once. |
| 13 | Live discovery validates the committed measured assignment without changing shard topology, routing, or appending guessed costs. | ✓ VERIFIED | Production defaults still load the committed `timing_probe.per_file_costs`, remove only the fixed scaffold set, and call live validation after assignment. Neither discovery nor CI synthesizes costs or creates additional shards. |
| 14 | The two Phase-233 contract/formatter tests themselves are not omitted by the historical receipt. | ✓ VERIFIED | Both `test/support/ci/ex_unit_timing_formatter_test.exs` and `test/sigra/planning/phase_233_library_economics_contract_test.exs` occur in `per_file_costs` and in the validated current partition union. |
| 15 | Plan 233-06 closed the prior verification blocker without regressing verified economics/routing. | ✓ VERIFIED | The new live-universe reconciliation and CI transport are wired in production, all focused tests pass, and the prior PR evidence/topology remains unchanged and independently rechecked through GitHub. |
| 16 | No Plan 233 must-have prohibition was violated. | ✓ VERIFIED | Plans 01–05 declare none. Plan 06's flagged descriptors specify preservation of the already-proven timing and receiver contracts; both remain wired and covered by focused tests and the observed PR run. |

**Score:** 16/16 deduplicated observable truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `test/support/ci/ex_unit_timing_formatter.ex` | Same-run deterministic receipt formatter | ✓ VERIFIED | Substantive GenServer formatter with fixed-path validation, ordered receipt creation, and atomic output. |
| `test/support/ci/ex_unit_timing_formatter_test.exs` | Formatter lifecycle/error tests | ✓ VERIFIED | Five focused tests passed. |
| `test/support/ci/library_test_partitions.exs` | Measured two-shard manifest plus current-universe reconciliation | ✓ VERIFIED | Reads historical costs, constructs the two lists, discovers the live filtered universe, and rejects any difference before returning paths. |
| `test/sigra/planning/phase_233_library_economics_contract_test.exs` | Routing, manifest, and selector regressions | ✓ VERIFIED | Fourteen focused tests passed, including temporary on-disk omission and failing-selector behavior. |
| `.github/workflows/ci.yml` | Ordinary matrix, unconditional receiver, and fail-closed aggregate | ✓ VERIFIED | Selector output is guarded before one `mix test`; scaffold/aggregate topology is present and observed on a PR. |
| `233-EVIDENCE.json` / `233-EVIDENCE.md` | Retry-free before/after PR evidence | ✓ VERIFIED | Machine-readable run identity, costs, jobs, receipts, coverage and duration comparison are present; run metadata was independently re-fetched. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `ci.yml` ordinary shard | Timing formatter | Both formatter flags plus `SIGRA_EXUNIT_TIMING_PATH` | WIRED | Same single `mix test` invocation writes the uploaded receipt. |
| Timing-probe receipt | Partition manifest | `JSON.decode!` → `timing_probe.per_file_costs` | WIRED | The measured source remains authoritative for assignment. |
| `mix.exs` filters | Live manifest universe | `Mix.Project.config()[:test_load_filters]` | WIRED | No duplicate filter regex is embedded in the manifest module. |
| Live filesystem | Partition manifest | `Path.wildcard` → normalized/filter-matched paths → exact equality | WIRED | Current 211-file universe equals the 211 unique assigned paths. |
| Partition selector | CI test argv | Status-preserving command substitution then non-empty checks | WIRED | A raised selector exits the CI shell before the sole `mix test`. |
| Scaffold tags | Scaffold receiver | `mix test --only scaffold` | WIRED | Exact six paths are tagged and receiver is unconditional. |
| Shard and receiver results | `Library tests` | `needs`, `if: always()`, explicit exact-success checks | WIRED | Any non-success fails the required aggregate. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Timing formatter | Completed ExUnit tests | Same test process | Yes | ✓ FLOWING |
| Partition manifest | Measured costs | Committed retry-free receipt | Yes, then live-validated | ✓ FLOWING |
| Partition manifest | Eligible ordinary paths | Current filesystem + live Mix configuration | Yes | ✓ FLOWING |
| CI shard argv | Selected paths | Validated partition output | Yes | ✓ FLOWING |
| Evidence ledger | Jobs, durations, artifacts | GitHub PR runs | Yes; direct `gh run view` cross-check succeeded | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Plan-06 manifest/CI failure paths | `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs` | 14 tests, 0 failures | ✓ PASS |
| Timing formatter behavior | `mix test test/support/ci/ex_unit_timing_formatter_test.exs` | 5 tests, 0 failures | ✓ PASS |
| Phase formatting | `mix format --check-formatted …` | Exit 0 | ✓ PASS |
| Current production selectors | `mix run … LibraryTestPartitions.partition/1` | Partition 1: 107 paths; partition 2: 104 paths | ✓ PASS |
| Live exact ownership | `build_partitions!/0` + `current_ordinary_paths!/0` | `current=211 assigned=211 unique=211` | ✓ PASS |
| Final PR topology | `gh run view 30668911851 …` | `pull_request`, attempt 1, exact functional SHA; both shards, scaffold, and aggregate success | ✓ PASS |

### Probe Execution

Step 7c: SKIPPED — no Phase 233 probe scripts are declared or present; the focused contract suite supplies the deterministic executable checks.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| TEST-01 | 233-01, 02, 05, 06 | Slow-test visibility does not force serial library execution. | ✓ SATISFIED | Parallel same-run formatter wiring, timing receipt tests, and retry-free PR run evidence. |
| TEST-02 | 233-02, 04, 05, 06 | Two library shards finish in comparable time. | ✓ SATISFIED | Cost-based deterministic split and observed 115s/114s final PR durations (1s gap versus 192s baseline). |
| TEST-03 | 233-03, 04, 05, 06 | Subprocess-heavy install tests no longer dominate ordinary shard wall-clock. | ✓ SATISFIED | Exact scaffold extraction, unconditional 909s PR receiver, preserved named coverage, and ordinary receipts without scaffold paths. |

All plan-declared IDs map to Phase 233 in `REQUIREMENTS.md`; no Phase 233 requirement is orphaned. No later milestone phase specifically defers a remaining Phase 233 concern.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `test/sigra/planning/phase_233_library_economics_contract_test.exs` | 112–231 | Runtime `Code.require_file/1` leaves direct manifest calls unresolved at compile time. | ⚠️ Warning | The focused suite passes but emits undefined-function compiler warnings, obscuring new warnings. This does not weaken execution of the asserted regressions. |

No untracked `TBD`, `FIXME`, or `XXX` debt marker was found in Phase 233 implementation files. The `console.log`/`return null` matches in the changed passkeys fixture are JavaScript fixture behavior, not empty Elixir test implementation or user-visible stubs.

### Human Verification Required

None. All phase behavior claims are covered by deterministic code inspection, focused automated tests, live selector execution, and re-fetched CI evidence.

---

_Verified: 2026-07-31T23:29:58Z_
_Verifier: the agent (gsd-verifier)_
