---
phase: 233-library-suite-economics
verified: 2026-07-31T22:45:00Z
status: gaps_found
score: 7/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "The measured manifest is exhaustive and self-invalidating on ordinary-test coverage drift; required CI cannot pass while an intended ordinary library test is omitted."
    status: failed
    reason: "The manifest derives its paths only from the historical timing_probe.per_file_costs receipt. It never discovers the current test universe or compares it with the two selected partitions, so a newly added untagged ordinary *_test.exs file is absent from both shard argv lists while the two shards, scaffold receiver, and Library tests aggregate can still succeed."
    artifacts:
      - path: test/support/ci/library_test_partitions.exs
        issue: "build_partitions!/0 reads only 233-EVIDENCE.json timing_probe.per_file_costs and filters scaffold paths; it contains no Path.wildcard/File discovery or exact-once reconciliation against current ordinary test files."
      - path: test/sigra/planning/phase_233_library_economics_contract_test.exs
        issue: "The passing contract exercises empty/duplicate/cost mutations but does not create or discover a current ordinary test file absent from the historical receipt, nor assert exact equality with the on-disk ordinary universe."
    missing:
      - "Fail closed by deriving the eligible current test-file universe (respecting test_load_filters and the exact scaffold set) and requiring equality with the manifest union before mix test runs."
      - "Add a deterministic regression test for an on-disk, untagged ordinary test file absent from per_file_costs/partitions."
---

# Phase 233: Library Suite Economics Verification Report

**Phase Goal:** The library shards do not become the new pole once Playwright stops being one.
**Verified:** 2026-07-31T22:45:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Slow-test visibility no longer requires serial library execution. | ✓ VERIFIED | CI run `30668911851` for functional SHA `6974bd1e2e4214fd5b9d519a987dfef2c3e89b89` ran shard 1 and shard 2 concurrently (starts one second apart). Each job invoked one `mix test` process with both `ExUnit.CLIFormatter` and `Sigra.CI.ExUnitTimingFormatter`; both receipts were uploaded. |
| 2 | The two ordinary library shards are materially balanced. | ✓ VERIFIED | Exact PR run durations were 115s and 114s: an after-gap of 1s versus the inherited 470s/278s before-gap of 192s. `233-EVIDENCE.json` records the inputs and computed gap. |
| 3 | The six subprocess-heavy scaffold tests are removed from ordinary shard wall-clock and execute on every PR. | ✓ VERIFIED | `library_tests_scaffold` has no docs/path/event gate and ran for 909s on the exact PR run; ordinary timing receipts report no canonical scaffold paths. |
| 4 | Upgrade, golden-diff, and idempotency coverage remains on a pull-request event. | ✓ VERIFIED | The run's scaffold receipt/evidence names `test/upgrade_test.exs`, `test/sigra/install/golden_diff_test.exs`, and `test/sigra/install/idempotency_test.exs`; `library_tests_scaffold` concluded success. |
| 5 | `Library tests` fails closed unless both ordinary shards and the scaffold receiver succeed. | ✓ VERIFIED | Workflow aggregate has `needs: [library_tests_shard, library_tests_scaffold]`, `if: always()`, and rejects either result unless it is `success`; the executable contract tests these branches and passed. The aggregate itself passed in run `30668911851`. |
| 6 | The final evidence is an exact, retry-free pull-request observation of the functional implementation. | ✓ VERIFIED | Direct `gh run view 30668911851` returned `event=pull_request`, `attempt=1`, matching functional SHA, and all four topology jobs successful. Current `HEAD` only adds planning/evidence/review documentation after that functional SHA. |
| 7 | The current repository ordinary suite is covered exactly once and the two newly added Phase 233 tests are not omitted. | ✓ VERIFIED | Independent manifest expansion finds both `test/support/ci/ex_unit_timing_formatter_test.exs` (partition 2) and `test/sigra/planning/phase_233_library_economics_contract_test.exs` (partition 1). They also appear in `timing_probe.per_file_costs`; CR-01's assertion that they are absent is not reproducible at current HEAD. |
| 8 | Coverage cannot silently drift when a new ordinary test file is introduced. | ✗ FAILED | The partition implementation reads the fixed historical receipt only. Neither production code nor its contract discovers/reconciles the present ordinary test-file universe. An added untagged test therefore receives no ordinary shard argv entry, and `mix test --only scaffold` does not select it; all required jobs can still be green. |

**Score:** 7/8 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `test/support/ci/ex_unit_timing_formatter.ex` | Same-run deterministic timing formatter | ✓ VERIFIED | Substantive formatter is configured by both ordinary CI legs and covered by focused formatter tests. |
| `test/support/ci/library_test_partitions.exs` | Two-list measured ordinary-suite manifest | ⚠️ HOLLOW | Exists, is substantive, and is invoked by CI, but its only data source is the historical receipt; no live inventory guard prevents silent omission of later ordinary tests. |
| `test/sigra/planning/phase_233_library_economics_contract_test.exs` | Exact coverage and fail-closed topology contract | ✗ STUB FOR DRIFT CLAIM | 13 focused assertions pass, but none exercises or forbids a current test file missing from the fixed receipt/manifest. |
| `.github/workflows/ci.yml` | Two ordinary shards, receiver, aggregate, receipts | ✓ VERIFIED | Exact PR execution validates the wired topology. |
| `233-EVIDENCE.json` / `233-EVIDENCE.md` | Machine-readable before/after PR evidence | ✓ VERIFIED | Run identity, attempt, job durations, artifacts, required context, and coverage routing are present and independently cross-checked with GitHub. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `ci.yml` ordinary shard | timing formatter | formatter flags and fixed `SIGRA_EXUNIT_TIMING_PATH` | WIRED | One test invocation writes the uploaded same-job receipt. |
| timing-probe evidence | partition manifest | `JSON.decode!` → `timing_probe.per_file_costs` | WIRED, UNSAFE | The historic source is consumed, but current repository coverage is not validated. |
| partition manifest | ordinary shard `mix test` | `mix run ... LibraryTestPartitions.partition(...)` | WIRED | Explicit path argv is passed to `mix test`; this is the mechanism that makes later omissions silent. |
| scaffold receiver | `Library tests` aggregate | `needs` + exact-success shell check | WIRED | Static contract plus observed PR aggregate support it. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| partition manifest | `costs` | committed `233-EVIDENCE.json` `timing_probe.per_file_costs` | Yes, but historical only | ⚠️ STATIC SNAPSHOT |
| CI ordinary shards | `library_test_files` | manifest partition output | Yes, explicit paths | ⚠️ HOLLOW FOR NEW FILES |
| evidence ledger | after durations/job ids | GitHub run `30668911851` | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Focused formatter and Phase 233 contract | `mix test test/support/ci/ex_unit_timing_formatter_test.exs test/sigra/planning/phase_233_library_economics_contract_test.exs` | 13 tests, 0 failures | ✓ PASS |
| Exact required topology run | `gh run view 30668911851 --json databaseId,event,headSha,conclusion,attempt,jobs,url` | pull_request, attempt 1, matching functional SHA; both shards, receiver, and aggregate success | ✓ PASS |
| Current manifest includes CR-01's two named tests | expand both `LibraryTestPartitions.partition/1` lists and search paths | formatter test in partition 2; contract test in partition 1 | ✓ PASS |
| Inventory drift rejection | inspect `build_partitions!/0` and contract's coverage assertions | no current-universe discovery/equality check exists | ✗ FAIL |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| TEST-01 | 233-01, 02, 05 | Slow-test visibility does not force serial execution. | ✓ SATISFIED | Same-run timing formatter/receipts and two concurrently starting successful shards on the exact PR run. |
| TEST-02 | 233-02, 04, 05 | Two shards complete in comparable time. | ✓ SATISFIED | 1s after-gap is strictly smaller than 192s before-gap. |
| TEST-03 | 233-03, 05 | Heavy install tests no longer dominate ordinary shard wall-clock with recorded routing. | ✓ SATISFIED | Exact scaffold receiver routing and named PR coverage; ordinary shards complete in ~115s. |

All three plan-declared IDs are mapped in `REQUIREMENTS.md` to Phase 233; none is orphaned. Their observed economics are satisfied, but the phase's explicit fail-closed manifest-drift acceptance criterion is not, so the phase goal cannot be accepted as complete.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `test/support/ci/library_test_partitions.exs` | 73-78 | Historical fixed list used as the complete suite with no inventory comparison | 🛑 Blocker | Required CI can remain green while a later ordinary test is never run. |
| `test/sigra/planning/phase_233_library_economics_contract_test.exs` | 110-143 | Test name claims missing coverage validation but only checks empty/duplicate/invalid-cost cases | 🛑 Blocker | Passing contract is misleading: it cannot detect the stated drift failure. |

### Gaps Summary

The measured PR topology genuinely improves the shard economics and preserves the explicitly named heavy tests. The code review's narrower CR-01 claim is inaccurate at current HEAD: both named tests are in the receipt-derived manifest and were observed in the PR run.

Nevertheless, the underlying safety property is absent. `LibraryTestPartitions.build_partitions!/0` treats an old timing receipt as the entire ordinary suite. It does not enumerate the current eligible test files, subtract the exact scaffold class, or reject a difference. Because CI passes only the resulting explicit paths to `mix test`, a new untagged ordinary test is selected by neither ordinary shard nor `--only scaffold`; `Library tests` still aggregates successful jobs and reports green. This is a blocking gap under the phase's stated "coverage cannot silently drift" contract and the phase requirement that CI must not pass without its intended library tests.

---

_Verified: 2026-07-31T22:45:00Z_
_Verifier: the agent (gsd-verifier)_
