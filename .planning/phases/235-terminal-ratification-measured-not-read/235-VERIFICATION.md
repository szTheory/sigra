---
phase: 235-terminal-ratification-measured-not-read
verified: 2026-08-04T00:54:05Z
status: gaps_found
score: 3/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 5/6
  gaps_closed:
    - "The original FAST-01 n=13/p50=724 miss is superseded by a separately retained n=15/p50=486 post-remediation population."
  gaps_remaining: []
  regressions:
    - "The new FAST-01 gap-closure offline verifier resolves realpath and mktemp from inherited PATH before isolation."
    - "The GATE-05 terminal verifier still creates its pre-isolation staging directory with inherited TMPDIR on the Ubuntu-supported execution path; its runtime self-test can pass before exercising that path."
gaps:
  - truth: "FAST-01 closes only from one newly attested, protected-main, post-remediation population with valid offline provenance."
    status: failed
    reason: "The receipt recomputes to n=15/p50=486/pass, but its sole offline provenance verifier executes PATH-controlled realpath and mktemp before its network-denied process. The plan expressly makes valid offline provenance a closure precondition, so the retained subject is not acceptably proven as an independent protected measurement."
    artifacts:
      - path: scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh
        issue: "Lines 13-14 resolve mktemp/realpath from inherited PATH and line 22 runs inherited mktemp before isolation; neither command is trusted by absolute path or covered by a staging-path regression test."
      - path: test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs
        issue: "The contract recomputes receipt fields but does not test the new FAST verifier's pre-isolation command or temporary-directory trust boundary."
    missing:
      - "Use trusted absolute utilities (or validate their canonical paths), clear TMPDIR/TMP/TEMP for staging under a fixed trusted parent, and add a test that reaches and proves the staging path while rejecting PATH/TMPDIR control."
  - truth: "GATE-05 is independently complete: the protected 93-row ownership proof is verified with the planned offline trust boundary."
    status: failed
    reason: "The 93-row ledger and protected receipt are present and their focused contract passes, but the CI-wired offline verifier invokes trusted mktemp with inherited TMPDIR before isolation. On the repository's Ubuntu path this permits caller-selected pre-isolation staging. Its self-test uses `|| true`, so it can pass if validation exits before staging."
    artifacts:
      - path: scripts/ci/verify-terminal-ratification-attestation-offline.sh
        issue: "Line 63 runs `$MKTEMP_BIN -d` without clearing temporary-directory overrides, before receipt/bundle/root copies and before network isolation."
      - path: scripts/ci/verify-terminal-ratification-attestation-offline.test.sh
        issue: "Lines 27 and 35 accept any verifier failure and assert only that a shadow binary was not called; they do not prove execution reaches trusted staging."
    missing:
      - "Create staging with a trusted absolute env/mktemp invocation that clears TMPDIR, TMP, and TEMP, verify ownership/non-symlink location under a fixed trusted parent, and make the regression test fail unless that checkpoint is reached."
next_action: "Escalation Gate — repair the two offline-verifier trust boundaries, then re-run scoped Phase 235 verification."
next_command: "bash scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh && bash scripts/ci/verify-terminal-ratification-attestation-offline.sh && MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs test/sigra/planning/phase_235_terminal_ratification_contract_test.exs"
---

# Phase 235: Terminal Ratification — Measured, Not Read Verification Report

**Phase Goal:** The milestone's headline claims are proven from run data, and a maintainer can see exactly what moved and where it landed.
**Verified:** 2026-08-04T00:54:05Z
**Status:** gaps_found
**Re-verification:** Yes — after a claimed FAST-01 gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | The protected FAST population uses all terminal PR conclusions, queue-inclusive wall time, stable `{wall_seconds, run_id}` ordering, `floor(n/2)` p50, and strict `<720`. | ✓ VERIFIED | The retained subject has 15 unique terminal PR rows, sorted median row 8 at 486 seconds, `mode: wall`, and `verdict: pass`; `capture-fast-01-gap-closure.test.sh` passed. |
| 2 | FAST-01 is proven by a newly attested, protected-main post-remediation measurement. | ✗ FAILED | The calculated result is n=15/p50=486, but its required offline-provenance link is insecure before isolation: `verify-fast-01-gap-closure-attestation-offline.sh` resolves `realpath`/`mktemp` through inherited `PATH` and runs `mktemp` before isolation. |
| 3 | A single committed ledger shows every covered before/after ownership path across PR, push, and schedule. | ✓ VERIFIED | `235-TERMINAL-RATIFICATION.json` is substantive and has 93 ownership rows; the focused terminal-ratification ExUnit contract passed and validates exact topology/inventory semantics. |
| 4 | GATE-05's 93-row proof is independently and safely verified rather than merely asserted by JSON. | ✗ FAILED | `ci.yml` wires `verify-terminal-ratification-attestation-offline.sh`, but its pre-isolation staging still inherits `TMPDIR` on the supported Ubuntu path; its test can pass before that security path executes. |
| 5 | Maintainers can reproduce the current topology and distinguish direct owners, aggregates, and intentional non-PR signals. | ✓ VERIFIED | `CONTRIBUTING.md` accurately names `MIX_ENV=test mix ci`, `library_tests_shard`/`Library tests`, the five Playwright seams and aggregate, and non-PR signals; matching anchors exist in `ci.yml`. |

**Score:** 3/5 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `235-FAST-01-GAP-CLOSURE-REMEASUREMENT.json` | Protected independent FAST population and strict result | ⚠️ PRESENT, PROVENANCE LINK UNSAFE | Substantive n=15/p50=486/pass receipt; content recomputation passes, but the verifier that makes it authoritative is not safe. |
| `scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh` | Network-denied exact-subject provenance verification | ✗ STUBBED SECURITY BOUNDARY | Has positive/adverse behavior, but pre-isolation `PATH` control violates its intended hostile-caller integrity boundary. |
| `235-TERMINAL-RATIFICATION.json` | Single before/after ownership and event ledger | ✓ VERIFIED | Substantive 93-row ledger, direct receivers, and PR/push/schedule rows; its focused contract passed. |
| `235-PROTECTED-RECEIPTS.json` plus terminal verifier | GATE-05 protected execution proof | ⚠️ PRESENT, PROVENANCE LINK UNSAFE | Receipt and attestation verification execute, but the verifier's inherited temporary directory invalidates the claimed independent trust boundary on Ubuntu. |
| `CONTRIBUTING.md` | Current CI topology and local reproduction | ✓ VERIFIED | Direct owners/aggregates and current command seams align with `.github/workflows/ci.yml`. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| FAST closure bundle/root | FAST offline verifier | Repository/signer/main-ref/subject-digest validation under network denial | ✗ NOT SECURE | The code reaches network denial only after untrusted PATH-controlled utilities have already run. |
| FAST receipt | `REQUIREMENTS.md` | Independent recomputation drives FAST-01 only | ✗ NOT WIRED SAFELY | Requirement says Complete, but the precondition of valid offline provenance is not met. |
| Phase 234 inventory + workflow | Terminal 93-row ledger | Exact inventory/topology reconciliation | ✓ WIRED | The focused terminal contract passed and rejects ownership/event/topology substitutions. |
| GATE protected receipt/bundle/root | Terminal offline verifier | CI-required positive and adverse attestation checks | ✗ NOT SECURE | The verifier is CI-wired at `ci.yml:312-317`, but trusted staging is not established before it handles its inputs. |
| `ci.yml` | `CONTRIBUTING.md` | Direct owner, aggregate, command, and non-PR documentation | ✓ WIRED | Matching current workflow anchors and deterministic contract coverage. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| FAST receipt | `runs`, `eligible_pr_run_count`, `statistics.p50_seconds` | Attested protected workflow subject | Yes; 15 retained terminal PR rows | ⚠️ Data is real, provenance acceptance is unsafe |
| Terminal ledger | `ownership.rows` | Phase 234 inventory plus live workflow receipts | Yes; 93 retained rows | ✓ FLOWING |
| CONTRIBUTING | owner/aggregate/reproduction statements | Current `ci.yml` topology | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| FAST collector comparator/window controls | `bash scripts/ci/capture-fast-01-gap-closure.test.sh` | PASS | ✓ PASS |
| FAST retained receipt recomputation | `jq` check of ordered rows, n=15, p50=486, strict pass | `true` | ✓ PASS |
| FAST offline attestation cases | `bash scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh` | Positive and adverse cases passed | ⚠️ PASS DOES NOT CURE pre-isolation PATH control |
| Terminal/FAST focused contracts | `MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | 25 tests, 0 failures | ⚠️ PASS; tests do not cover the discovered staging boundary |
| Existing terminal verifier self-test | `bash scripts/ci/verify-terminal-ratification-attestation-offline.test.sh` | PASS | ⚠️ Inadequate: `|| true` permits early exit before the asserted path |

The ExUnit startup logged unavailable local PostgreSQL connections; these focused planning contracts completed without database access.

### Probe Execution

Step 7c: SKIPPED — this phase declares no `probe-*.sh` scripts. The deterministic collector, verifier, and focused contract commands above are the applicable runnable checks.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| FAST-01 | 235-01 through 235-13 | PR p50 under 12 minutes across at least 10 post-change PR runs | ✗ BLOCKED | n=15/p50=486 satisfies the numeric predicate, but Plan 13 makes valid offline provenance mandatory. The closure verifier violates that boundary before isolation, so the requirement's checked/Complete record is not established. |
| GATE-05 | 235-01 through 235-13 | One artifact proves no test was silently dropped across PR/main/nightly | ✗ BLOCKED | The 93-row artifact and contract are sound as data/topology checks, but the protected provenance verifier has the unresolved pre-isolation temporary-directory flaw. Its checked/Complete record is therefore not independently established. |

All Phase 235 plans declare only `FAST-01` and `GATE-05`; both are present in `REQUIREMENTS.md`. No Phase 235 requirement is orphaned. No later milestone phase explicitly covers either verifier trust-boundary repair, so neither gap is deferred.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh` | 13-14, 22 | PATH-resolved `realpath`/`mktemp` before isolation | 🛑 BLOCKER | A malicious caller can control commands before the verifier establishes the intended network-denied, trusted staging boundary. |
| `scripts/ci/verify-terminal-ratification-attestation-offline.sh` | 63 | Inherited temporary-directory selection before isolation | 🛑 BLOCKER | On the Ubuntu-supported path, pre-isolation staged inputs can be placed under caller-selected temporary storage. |
| `scripts/ci/verify-terminal-ratification-attestation-offline.test.sh` | 27, 35 | `|| true` permits early success of a negative test | ⚠️ WARNING | The test can pass without proving it reached the trusted-staging behavior it claims to guard. |

No unreferenced `TBD`, `FIXME`, or `XXX` debt marker was found in the inspected Phase 235 runtime artifacts.

### Gaps Summary

The receipts are not fabricated: FAST's retained run data recomputes to **n=15, strict p50=486 seconds**, and the ownership ledger contains **93 rows**. Those facts alone do not satisfy this phase's proof discipline. Plan 13 explicitly says only protected data with **valid offline provenance** can close FAST-01, while GATE-05 requires an independent terminal verifier.

Both acceptance links are broken at the verifier trust boundary. This is a **BLOCKER / Escalation Gate**: repair and test the staging boundary, then re-run the scoped verification. Do not treat the current checkboxes in `REQUIREMENTS.md` or the completed roadmap state as evidence that the phase goal has been achieved.

---

_Verified: 2026-08-04T00:54:05Z_
_Verifier: the agent (gsd-verifier)_
