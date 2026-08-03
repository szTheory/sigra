---
phase: 235-terminal-ratification-measured-not-read
verified: 2026-08-03T14:19:52Z
status: gaps_found
score: 9/10 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 8/10
  gaps_closed:
    - "Every ownership row is now joined to the workflow-derived direct-owner job-name prefix in every retained protected event manifest; executed rows require a terminal non-skipped job and intentionally_absent rows require present skipped jobs."
  gaps_remaining:
    - "FAST-01 remains a measured miss: 19 PR runs have p50 772 seconds, not strictly below 720 seconds."
  regressions: []
gaps:
  - truth: "FAST-01 is achieved: PR p50 is under 12 minutes across at least 10 post-change PR runs."
    status: failed
    reason: "The protected, replayed measurement contains 19 eligible pull_request runs and p50 772 seconds. The requirement uses a strict <720-second comparator."
    artifacts:
      - path: ".planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json"
        issue: "verdict.fast_01.status is miss with observed_p50_seconds 772 and threshold_seconds 720."
      - path: ".planning/REQUIREMENTS.md"
        issue: "FAST-01 is accurately open/Gaps Found, confirming the target is not achieved."
    missing:
      - "A future, independently measured PR population whose p50 is strictly below 720 seconds; do not change the threshold or waive the existing miss."
---

# Phase 235: Terminal Ratification — Measured, Not Read Verification Report

**Phase Goal:** The milestone's headline claims are proven from run data, and a maintainer can see exactly what moved and where it landed.
**Verified:** 2026-08-03T14:19:52Z
**Status:** gaps_found
**Re-verification:** Yes — after protected ownership-job binding repair `d33a43c7`

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Terminal measurements use queue-inclusive wall mode, all conclusions, sorted `floor(n/2)` p50, and strict `< 720` comparison. | ✓ VERIFIED | Metrics contract passes; the ledger recomputes the retained PR population as p50 772 and treats 720 as a miss. |
| 2 | FAST-01 is achieved: PR p50 is under 12 minutes across at least 10 post-change PR runs. | ✗ FAILED | Protected replay proves `n=19`, but p50 is `772`, not strictly below `720`. |
| 3 | The complete source population is independently authenticated and exhaustively paginated. | ✓ VERIFIED | Protected receipt has 24 first-page runs plus retained empty page 2, with complete two-page job manifests; offline verification binds its SHA to protected-main run `30782184713`, signer/ref, and evidence-workflow commit `83ef9f5d7b00a99aa945cf9839c056283c3e6c65`. |
| 4 | Binding-pole diagnoses are deterministically selected and replayed from retained PR data. | ✓ VERIFIED | Focused contract passes and the ledger retains the 772-second miss with its binding-pole receipts. |
| 5 | One artifact has the exact before/after PR, push, and schedule ownership-key universe. | ✓ VERIFIED | Hash-pinned Phase 234 inventory and exact sorted 93-row comparison pass. |
| 6 | Every ownership row proves its actual executable owner, aggregate, receiver, and protected event receipt. | ✓ VERIFIED | `validate_protected_ownership_jobs!/3` joins every row to every protected run for its event through the workflow-derived job-name prefix. Executed rows require a terminal, non-skipped job; intentionally absent rows require present skipped jobs. Renamed push admin-eval and skipped schedule library-owner mutations both fail. |
| 7 | Push and schedule outcomes over the same measurement window are recorded from run data. | ✓ VERIFIED | Attested population maps exactly to push `1 success / 1 non-success` and schedule `0 success / 2 non-success`. |
| 8 | CONTRIBUTING describes current topology and CI-used local reproduction. | ✓ VERIFIED | Phase 235 and Phase 198 contributor contracts relate direct owners, aggregates, `MIX_ENV=test mix ci`, and Playwright seams to live sources. |
| 9 | SEED-005 and CI-PERF reconcile the delivered audit sequence and honest FAST residual. | ✓ VERIFIED | Both records retain the 19/772 miss, same-window outcomes, and residual path. |
| 10 | Closeout preserves the 772-second miss rather than fabricating a pass. | ✓ VERIFIED | Ledger status is `miss`; FAST-01 remains unchecked/Gaps Found and its residual is open. |

**Score:** 9/10 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `235-PROTECTED-RECEIPTS.json` | Complete protected run/job receipt | ✓ VERIFIED | 24-run two-page source and 23 complete two-page job manifests; SHA matches ledger provenance. |
| Attestation bundle + trusted root | Offline-verifiable external provenance | ✓ VERIFIED | Network-denied verifier accepts the subject and rejects altered receipt, bundle, root, signer, and source ref. |
| `235-TERMINAL-RATIFICATION.json` | Single terminal measurement and ownership ledger | ✓ VERIFIED | Measurements flow exactly from protected evidence; 93 ownership rows are now verified against protected jobs. |
| `phase_235_terminal_ratification_contract_test.exs` | Fail-closed evidence and ownership contract | ✓ VERIFIED | Contains the protected ownership join and negative push/schedule mutation coverage; 20 focused tests pass. |
| Contributor and closeout records | Accurate topology and residual disclosure | ✓ VERIFIED | Contract-backed and congruent with the measured miss. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Protected receipt | Ledger measurements | Attested digest → complete pages → normalized exact run map | ✓ WIRED | All measured PR/push/schedule rows equal protected data. |
| Evidence workflow | Attestation | Protected-main signer/ref/workflow SHA → network-denied offline verification | ✓ WIRED | Positive and adverse cases pass as expected; current workflow blob equals `origin/main`. |
| Phase 234 inventory | Ownership ledger | Hash-pinned exact 93-key comparison | ✓ WIRED | Missing, duplicate, and extra ownership rows fail. |
| `ci.yml` and protected event jobs | Every ownership row | Eligibility + workflow-name prefix + terminal/non-skipped (or skipped absence) job | ✓ WIRED | The repaired validator is invoked from `validate_protected_receipt!/2`; adversarial push/schedule mutations fail. |
| Ledger | Requirements/closeout documents | Verdict-driven status and wording | ✓ WIRED | FAST-01 remains open; GATE-05 is independently proven and Complete. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Terminal measurements | `measurements.*.runs` / statistics | Attested protected source pages | Yes | ✓ FLOWING |
| Binding-pole receipts | Selected PR jobs | Retained PR rows and job data | Yes | ✓ FLOWING |
| Ownership rows | `after.direct_owner`, event state, receiver | Phase 234 inventory + `ci.yml` + protected job manifests | Yes | ✓ FLOWING |
| Contributor/closeout documents | Topology and verdict wording | `ci.yml`, Mix/Playwright sources, ledger | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Offline protected attestation | `bash scripts/ci/verify-terminal-ratification-attestation-offline.sh` | Positive verification plus altered receipt/bundle/root/signer/ref failures; exit 0 | ✓ PASS |
| Dispatch correlation selector | `bash scripts/ci/correlate-terminal-ratification-dispatch.sh --self-test` | Exactly-one accepted; zero/multiple/stale/wrong identity rejected | ✓ PASS |
| Protected collector | `bash scripts/ci/capture-terminal-ratification-evidence.test.sh` | Hermetic production-collector fixtures pass | ✓ PASS |
| Metrics semantics | `bash scripts/ci/ci-run-metrics.test.sh` | 9 passed, 0 failed | ✓ PASS |
| Protected ownership join | `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | 20 tests, 0 failures; renamed push owner and skipped schedule owner are rejected | ✓ PASS |
| Planning contracts | `MIX_ENV=test mix test test/sigra/planning/` | 115 tests, 0 failures, 12 skipped | ✓ PASS |

The test startup logs local PostgreSQL connection refusals, but these deterministic planning contracts complete without a database.

### Probe Execution

Step 7c: SKIPPED — no Phase 235 `probe-*.sh` script is declared. Applicable deterministic checks were executed above.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| FAST-01 | 235-01 through 235-08 | PR p50 under 12 minutes across at least 10 post-change runs | ✗ BLOCKED | Protected evidence proves 19 runs, p50 772 seconds; the explicit `<720` target is unmet. |
| GATE-05 | 235-01 through 235-08 | One artifact proves no test was silently dropped across PR/main/nightly | ✓ SATISFIED | Exact 93-row inventory plus event eligibility and protected terminal/non-skipped owner-job evidence all validate together. |

All Phase 235 plan requirements are FAST-01 and GATE-05; none is orphaned. There is no later phase in this milestone that specifically resolves the remaining FAST-01 miss.

### Review Finding Re-evaluation

| Earlier finding | Current verdict | Evidence |
| --- | --- | --- |
| Capped source population | Closed | Protected source has total `24`, pages `[1,2]`, and terminal empty page. |
| Self-authenticating digest | Closed | External offline attestation binds signer, repository, ref, commit, and subject. |
| Inverted measured timestamps | Closed | Retained measured run/job chronology rejects inversions before duration use. |
| Disconnected ownership execution proof | Closed | `validate_protected_ownership_jobs!/3` is invoked by protected receipt validation and has adverse push/schedule mutation coverage. |

### Anti-Patterns Found

No blocker or warning anti-pattern was found in the Phase 235 implementation artifacts. No unreferenced `TBD`, `FIXME`, or `XXX` marker was found.

### Gaps Summary

Plans 07–08 and `d33a43c7` now provide complete, externally authenticated source data and an automated row-to-protected-job execution proof. **GATE-05 is independently satisfied.**

The phase goal is still not fully achieved because **FAST-01 remains an honest measured miss**: 19 eligible PR runs have a p50 of 772 seconds, not the required value strictly below 720 seconds. This is an **Escalation Gate**: retain the evidence and residual, and only close FAST-01 after a new qualifying measurement proves the target.

---

_Verified: 2026-08-03T14:19:52Z_
_Verifier: the agent (gsd-verifier)_
