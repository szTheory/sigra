---
phase: 235-terminal-ratification-measured-not-read
verified: 2026-08-03T20:55:00Z
status: gaps_found
score: 5/6 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 9/10
  gaps_closed: []
  gaps_remaining:
    - "FAST-01 remains a strict measured miss: the independently attested population has n=13 and p50=724 seconds, not <720 seconds."
  regressions: []
gaps:
  - truth: "FAST-01 is achieved: PR p50 is under 12 minutes across at least 10 post-change PR runs."
    status: failed
    reason: "The protected-main receipt is complete and eligible (n=13), but its queue-inclusive wall-time p50 is 724 seconds. The requirement comparator is strict <720 seconds."
    artifacts:
      - path: ".planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-REMEASUREMENT.json"
        issue: "status is measured, verdict is miss, eligible_pr_run_count is 13, and statistics.p50_seconds is 724."
      - path: ".planning/REQUIREMENTS.md"
        issue: "FAST-01 is explicitly unchecked and mapped to Phase 235 with status Gaps Found."
    missing:
      - "A new protected, independent population of at least 10 terminal PR runs with p50 strictly below 720 seconds; retain the cutoff and threshold rather than waiving this miss."
---

# Phase 235: Terminal Ratification — Measured, Not Read Verification Report

**Phase Goal:** The milestone's headline claims are proven from run data, and a maintainer can see exactly what moved and where it landed.
**Verified:** 2026-08-03T20:55:00Z
**Status:** gaps_found
**Re-verification:** Yes — after the protected independent FAST-01 measurement

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | PR wall time is measured against the baseline semantics: all terminal conclusions, queue-inclusive wall time, stable `{wall_seconds, run_id}` ordering, `floor(n/2)` p50, and strict `<720` comparison. | ✓ VERIFIED | `235-FAST-01-REMEASUREMENT.json` declares `mode: wall`, the required ordering, n=13, p50=724, and `verdict: miss`; `ci-run-metrics.test.sh` passed 9/9 including even/odd p50 and failure-row retention. |
| 2 | FAST-01 is achieved: PR p50 is under 12 minutes across at least 10 post-change PR runs. | ✗ FAILED | Protected receipt has the required 13 terminal PR runs, but p50 is **724 seconds**, four seconds above the strict 720-second ceiling. |
| 3 | A single committed artifact proves where every covered item ran before versus after across PR, push, and schedule, with an executable receiver and protected receipt. | ✓ VERIFIED | `235-TERMINAL-RATIFICATION.json` has 93 ownership rows; the focused Phase 235 contracts passed 22/22 and reject aggregate-only, stale, malformed, and event-guarded ownership. |
| 4 | Push and schedule outcomes over the terminal measurement window are recorded. | ✓ VERIFIED | Terminal ledger retains captured push and schedule measurements and outcomes; its protected receipt validates offline. |
| 5 | CONTRIBUTING describes the live CI topology and supported local reproduction path. | ✓ VERIFIED | `CONTRIBUTING.md` names `MIX_ENV=test mix ci`, `library_tests_shard`/`Library tests`, the direct Playwright seams/aggregate, and intentional non-PR lanes. |
| 6 | SEED-005/CI-PERF reconciliation preserves an honest residual instead of claiming a performance pass, while GATE-05 stays independently complete. | ✓ VERIFIED | Requirement records keep FAST-01 unchecked/Gaps Found and GATE-05 checked/Complete; the protected 93-row ownership proof is independent of the new FAST receipt. |

**Score:** 5/6 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `235-FAST-01-REMEASUREMENT.json` | Protected independent FAST population and strict verdict | ✓ VERIFIED | Exists, is substantive, and records `authority: protected_main_attestation`, n=13, wall p50=724, `miss`. |
| FAST attestation, trusted root, and offline verifier | Offline provenance check for the exact fresh receipt | ✓ VERIFIED | `verify-fast-01-remeasurement-attestation-offline.sh` passed positive verification and adverse receipt/bundle/root/signer/ref cases. |
| `235-TERMINAL-RATIFICATION.json` | Exact before/after ownership inventory and terminal measurements | ✓ VERIFIED | Versioned ledger has 93 rows and retained PR/push/schedule evidence; focused contract passed. |
| `235-PROTECTED-RECEIPTS.json` and terminal verifier | GATE-05 protected execution proof | ✓ VERIFIED | Offline terminal verifier passed; requirement points to protected main run `30782184713`. |
| `CONTRIBUTING.md` | Current CI topology and local reproduction | ✓ VERIFIED | Substantive, current descriptions match direct owners and aggregates in `ci.yml`. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Protected FAST receipt | FAST-01 requirement status | Exact n/p50/verdict flow | ✓ WIRED | The receipt's strict `miss` is reflected in unchecked FAST-01/Gaps Found; no pass was fabricated. |
| FAST receipt/bundle/root | Offline verifier | Network-denied subject, repository, signer, and main-ref validation | ✓ WIRED | Direct verifier execution succeeded and exercised negative inputs. |
| Phase 234 inventory and protected job receipts | 93-row terminal ownership ledger | Contract reconciliation and executable-owner validation | ✓ WIRED | 22 focused contract tests passed. |
| Terminal ownership receipt | GATE-05 requirement | Protected run `30782184713` and 93-row evidence | ✓ WIRED | `REQUIREMENTS.md` independently marks GATE-05 Complete. |
| `CONTRIBUTING.md` | `ci.yml` / local CI command | Direct owner and aggregate topology | ✓ WIRED | The documented `mix ci`, library, Playwright, and non-PR lanes match the checked workflow topology. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| FAST receipt | `runs`, `eligible_pr_run_count`, `statistics.p50_seconds` | Protected workflow's paginated `ci.yml` PR-run collection | Yes | ✓ FLOWING |
| Terminal ledger | `ownership.rows` and event measurements | Phase 234 inventory plus protected run/job manifests | Yes | ✓ FLOWING |
| CONTRIBUTING | owner/aggregate and reproduction descriptions | `ci.yml`, Mix alias, and Playwright seams | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Metrics semantics | `bash scripts/ci/ci-run-metrics.test.sh` | 9 passed, 0 failed | ✓ PASS |
| Fresh collector boundary and pagination checks | `bash scripts/ci/capture-fast-01-remeasurement.test.sh` | PASS | ✓ PASS |
| Fresh protected attestation | `bash scripts/ci/verify-fast-01-remeasurement-attestation-offline.sh` | Positive plus adverse receipt/bundle/root/signer/ref checks passed | ✓ PASS |
| GATE-05 protected attestation | `bash scripts/ci/verify-terminal-ratification-attestation-offline.sh` | Positive plus adverse cases passed | ✓ PASS |
| Focused Phase 235 contracts | `MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_remeasurement_contract_test.exs test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | 22 tests, 0 failures | ✓ PASS |

The ExUnit process logged unavailable local PostgreSQL connections during startup; these planning contracts completed without database access.

### Probe Execution

Step 7c: SKIPPED — Phase 235 declares no `probe-*.sh` script. The deterministic collector, attestation, and contract checks above are the applicable runnable evidence.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| FAST-01 | 235-01 through 235-10 | PR p50 under 12 minutes across at least 10 post-change runs | ✗ BLOCKED | Authoritative replacement measurement is n=13, p50=724 seconds, verdict `miss`; 724 is not strictly below 720. |
| GATE-05 | 235-01 through 235-10 | One artifact proves no test was silently dropped across PR/main/nightly | ✓ SATISFIED | Protected receipt and exact 93-row execution proof validate offline; requirement is checked Complete. |

All IDs declared by the ten Phase 235 PLAN frontmatters are FAST-01 and GATE-05. Both appear in `REQUIREMENTS.md`; no Phase 235 requirement is orphaned. The current milestone has no later phase that explicitly resolves the FAST-01 miss.

### Anti-Patterns Found

No Phase-235 blocker marker (`TBD`, `FIXME`, or `XXX`) was found in the inspected runtime artifacts. The prior review's warning remains: the FAST offline verifier is not itself invoked by `ci.yml`; it was executed directly here and does not invalidate the retained evidence, but future CI wiring should add its hermetic self-test and verifier.

### Gaps Summary

**GATE-05 is independently achieved.** The immutable inventory, execution-proof wiring, and protected attestation all validate.

**FAST-01 is not achieved.** The authoritative protected remeasurement has a sufficient sample but a strict miss: **n=13, p50=724 seconds**. This is a **BLOCKER / Escalation Gate** for the phase goal. Do not rewrite the requirement, treat 724 as a pass, or select a new preferred window; only a future independent protected population with p50 below 720 seconds can close it.

---

_Verified: 2026-08-03T20:55:00Z_
_Verifier: the agent (gsd-verifier)_
