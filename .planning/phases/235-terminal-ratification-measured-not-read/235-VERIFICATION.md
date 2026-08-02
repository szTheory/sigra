---
phase: 235-terminal-ratification-measured-not-read
verified: 2026-08-02T18:26:53Z
status: gaps_found
score: 7/10 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "The terminal ledger is an immutable, fail-closed measurement source that can prove the strict FAST-01 result from run data."
    status: failed
    reason: "The focused contract accepts arbitrary statistics maps and arbitrary binary output hashes, and derives the verdict only from those stored values rather than from a retained, hash-bound metrics receipt and the ledger's run population. A forged p50/count/hash can therefore produce a passing FAST-01 ledger."
    artifacts:
      - path: "test/sigra/planning/phase_235_terminal_ratification_contract_test.exs"
        issue: "validate_captured_ledger!/1 and validate_verdict!/1 are fail-open for statistics, hashes, and eligible-run counts."
    missing:
      - "Retain canonical metrics output (or an immutable receipt), validate a 64-hex SHA-256 against its bytes, and recompute n/outcomes/mean/p50/max from the retained run timestamps."
      - "Require eligible_pr_run_count and verdict fields to equal the recomputed PR population; add forged p50/count/hash/outcome mutation tests."
  - truth: "The single ownership artifact proves complete before/after CI ownership without silently admitting an unreviewed family or event."
    status: failed
    reason: "The validator confirms required keys are present but never requires the actual ownership-key set to equal the declared universe or rejects event values outside pull_request/push/schedule. The complete-ownership claim is silently extensible."
    artifacts:
      - path: "test/sigra/planning/phase_235_terminal_ratification_contract_test.exs"
        issue: "validate_rows!/1 lacks an exact expected-key-set assertion."
    missing:
      - "Build the exact {family, spec, event} universe, require set equality, and add extra-family and extra-event negative mutations."
  - truth: "The terminal closeout remains resistant to contributor-topology contradictions."
    status: partial
    reason: "The current prose matches inspected workflow facts, but its contract only requires independent substrings and job names. It does not bind aggregate-versus-executor semantics or non-PR conditions, so contradictory documentation can pass."
    artifacts:
      - path: "test/sigra/planning/phase_235_terminal_ratification_contract_test.exs"
        issue: "validate_contributor_topology!/5 does not relate documentation assertions to workflow job blocks/conditions."
    missing:
      - "Assert aggregate needs/direct-owner behavior, exact non-PR job conditions, and whole documentation statements; add contradiction mutations."
---

# Phase 235: Terminal Ratification — Measured, Not Read Verification Report

**Phase Goal:** Execute a terminal, automation-first ratification of the CI-efficiency milestone using one immutable measured ledger: preserve the strict FAST-01 result honestly and prove complete GATE-05 CI ownership/closeout without manual UAT or unverified claims.
**Verified:** 2026-08-02T18:26:53Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | FAST-01's strict result is preserved honestly. | ✓ VERIFIED | Ledger records 19 PR runs and p50 772 with comparator `lt` / threshold 720 and status `miss`; independent recomputation from retained timestamps produced n=19, p50=772, mean=821.1052631578947, max=1447, 13 success/6 non-success. |
| 2 | PR wall-clock is under 12 minutes at p50 over at least ten post-change runs. | ✗ FAILED | The measured result is 772 seconds across 19 runs, not strictly less than 720. `REQUIREMENTS.md` correctly leaves FAST-01 pending. |
| 3 | One immutable, fail-closed ledger proves the measured FAST-01 outcome from run data. | ✗ FAILED | CR-01 is confirmed in source: `validate_captured_ledger!/1` accepts any statistics map and binary hash; `validate_verdict!/1` trusts stored p50/count instead of recomputing and binding a receipt. |
| 4 | Push and scheduled outcomes from the same window are recorded. | ✓ VERIFIED | Ledger retains two push and two schedule runs and their timestamps/outcomes; independent timestamp recomputation matches stored p50s 1439 and 1546. |
| 5 | A single artifact lists every affected spec/lane before and after across PR, push, and schedule. | ✗ FAILED | The artifact currently has 93 sorted rows and the Phase 234 inventory SHA matches, but CR-02 is confirmed: validation has no exact actual-versus-expected key-set comparison, so completeness is not enforced. |
| 6 | Every current moved row has a direct owner, receiver, and receipt rather than only an aggregate. | ✓ VERIFIED | Focused contract passed and `validate_rows!/1` rejects missing direct owners, `library_tests` aggregate-only owners, receiverless rows, and receiptless rows. |
| 7 | CONTRIBUTING accurately distinguishes direct owners, aggregates, reproduction, and non-PR signals. | ✓ VERIFIED | Current documentation states `library_tests_shard` and `example_playwright_shard` as direct owners, aggregates as non-executors, and both diagnostic jobs as non-PR. Inspected `ci.yml` confirms aggregate `needs` and both diagnostic `if: github.event_name != 'pull_request'` guards. |
| 8 | Contributor topology is mechanically protected against contradictory future prose. | ✗ FAILED | CR-03 is confirmed: the contract only searches independent substrings and job names; it neither parses job conditions nor rejects an aggregate-as-executor contradiction. |
| 9 | SEED-005 and CI-PERF reconcile the measured miss and Phase 230–235 sequence. | ✓ VERIFIED | Both records link the terminal ledger, state 19 retained PR runs / 772 seconds / FAST-01 unmet, preserve the residual link, and remove stale ACTIVE framing. |
| 10 | A miss has one owned residual and closeout state is ledger-backed. | ✓ VERIFIED | `closeout` names the residual path and records `performance_target_achieved: false`; the residual names both binding-pole receipt IDs/commands. |

**Score:** 7/10 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `.planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json` | Single terminal measurement and ownership source | ⚠️ PARTIAL | Exists, is substantive, sorted (93 rows), and pins the live Phase 234 inventory SHA. Its measurement receipts are not cryptographically bound or recomputed by the enforcing contract. |
| `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | Fail-closed ledger/topology/closeout contract | ✗ STUB FOR CRITICAL CLAIMS | Exists (529 lines), is invoked, and 11 tests pass, but it omits the adversarial mutations needed to prevent forged metrics, extra ownership keys, and topology contradictions. |
| `CONTRIBUTING.md` | Current CI topology and local reproduction | ✓ VERIFIED | Current content matches inspected workflow owners and event guards. |
| `.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md` | Ledger-backed terminal addendum | ✓ VERIFIED | Contains dated Phase 235 addendum, honest miss, exact p50/count, ledger and residual links. |
| `.planning/MILESTONE-ARC.md` | Reconciled CI-PERF outcome | ✓ VERIFIED | Records completed remediation sequence with honest FAST-01 miss and residual. |
| `.planning/todos/pending/2026-08-02-fast-01-terminal-p50-miss.md` | Owned measured-miss residual | ✓ VERIFIED | Exists and is referenced by ledger and both reconciliation records. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Phase 234 Playwright inventory | Terminal ledger | Pinned path/schema/SHA and row reconciliation | ⚠️ PARTIAL | Current SHA is `c11853…970bc3`; required rows are present, but no exact ownership-key-set enforcement rejects additions. |
| `scripts/ci/ci-run-metrics.sh` | Terminal ledger | Literal wall-mode commands and output receipts | ✗ NOT_WIRED | The ledger stores command strings and hashes only; the validator does not retain/verify canonical script output or recompute its statistics. |
| GitHub Actions metadata | Terminal ledger | IDs, timestamps, conclusions, URLs, job receipts | ⚠️ PARTIAL | Current entries are internally consistent, but hash fields and receipt contents have no fail-closed binding. |
| `.github/workflows/ci.yml` | `CONTRIBUTING.md` | Owner/aggregate/event topology | ⚠️ PARTIAL | Current facts match, but the automated contract is substring-based and fails to enforce semantic relationships. |
| Terminal ledger | SEED-005 / CI-PERF | Verdict/count/p50/residual wording | ✓ WIRED | Current records agree with the current ledger's measured miss. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Terminal ledger | `measurements.*.runs` / statistics | Retained GitHub run metadata | Yes, internally recomputable | ⚠️ UNBOUND — original metrics-script output and its digest are not retained/verified. |
| Terminal ledger | `ownership.rows` | Phase 234 inventory plus workflow/evidence references | Yes, current rows populated | ⚠️ EXTENSIBLE — complete universe is not enforced. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Focused Phase 235 contract | `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | 11 tests, 0 failures (local Postgrex startup logs are non-fatal to this contract) | ✓ PASS, inadequate coverage identified by source review |
| Wall-mode metric semantics | `bash scripts/ci/ci-run-metrics.test.sh` | 9 passed, 0 failed | ✓ PASS |
| Retained run arithmetic | read-only Node calculation over ledger timestamps | All stored n/p50/mean/max/outcomes match | ✓ PASS |
| Inventory pin and ordering | `jq` / SHA-256 checks | 93 sorted rows; inventory SHA matches | ✓ PASS |

### Probe Execution

Step 7c: SKIPPED — no Phase 235 probe script or declared probe was found.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| FAST-01 | 235-01, 235-02, 235-03 | Under-12-minute PR p50 over at least 10 post-change runs | ✗ BLOCKED | 19-run measurement is 772 seconds, failing strict `< 720`; additionally, the mechanism that would prove a result from immutable receipts is fail-open. |
| GATE-05 | 235-01, 235-02, 235-03 | One before/after PR/main/nightly ownership artifact with no silently dropped tests | ✗ BLOCKED | Current artifact is populated, but exact universe and receipt integrity are not fail-closed; complete ownership cannot be ratified without unverified claims. |

No phase requirement is orphaned: every plan declares both FAST-01 and GATE-05, and `REQUIREMENTS.md` maps both to Phase 235. No later roadmap phase specifically schedules these enforcement defects, so none are deferred.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | 376-422 | Arbitrary statistics/hash accepted; verdict copies stored p50 | 🛑 BLOCKER | Forged FAST-01 pass could satisfy the contract. |
| `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | 340-362 | Required ownership rows checked without exact key-set equality | 🛑 BLOCKER | Unreviewed family/event can be silently added to a supposedly complete ownership map. |
| `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | 473-500 | Independent substring topology checks | ⚠️ Warning | Contradictory contributor guidance can remain mechanically accepted. |

No Phase 235-created file contains an unreferenced `TBD`, `FIXME`, or `XXX` debt marker.

### Gaps Summary

This phase correctly records the *current* strict FAST-01 miss: 772 seconds is not under 12 minutes, and it does not falsely call the requirement complete. That honesty is not enough to meet the submitted goal, which explicitly requires an immutable, automation-first ledger with no unverified claims.

The critical failure is structural and reproducible from the source: the passing focused test trusts ledger-provided metrics and receipt hashes. Because it cannot reject an altered p50/count/hash, it cannot ratify either a future pass or the claimed immutable evidence path. The GATE-05 exact-universe and contributor-topology weaknesses independently leave the asserted closeout non-fail-closed. These are implementation gaps, not human-UAT questions; the Escalation Gate should route them to a corrective closure plan.

---

_Verified: 2026-08-02T18:26:53Z_
_Verifier: the agent (gsd-verifier)_
