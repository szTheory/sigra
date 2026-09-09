---
phase: 235-terminal-ratification-measured-not-read
verified: 2026-09-09T14:49:33Z
status: gaps_found
score: 10/11 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 9/11
  gaps_closed:
    - "FAST-01 now has an authenticated source-complete population: 52 eligible PR runs, wall p50 469 seconds, exhaustive signed source pages, and offline source-first agreement for the retained population."
  gaps_remaining:
    - "The source-first offline verifier does not preserve the authoritative instrument's literal terminal-conclusion outcome map: it collapses every non-success conclusion into failure."
  regressions: []
gaps:
  - truth: "Terminal measurement verification retains and compares every terminal conclusion exactly as emitted by scripts/ci/ci-run-metrics.sh."
    status: failed
    reason: "The authoritative instrument groups outcomes by literal conclusion, but the offline verifier constructs only success and failure buckets. A valid population containing cancelled, timed_out, neutral, or skipped therefore fails source-first verification even though the phase contract explicitly retains all terminal outcomes. This is 235-REVIEW.md CR-01 and is directly in the Plan 16-18 path."
    artifacts:
      - path: "scripts/ci/verify-fast-01-source-complete-attestation-offline.sh"
        issue: "Lines 85-86 map success literally and collapse every other conclusion into failure, contradicting ci-run-metrics.sh line 146."
      - path: "test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs"
        issue: "No verifier-level fixture carries success, failure, and an additional terminal conclusion through full source/instrument equality, so the mismatch is not caught."
    missing:
      - "Build the offline oracle outcome map with the same literal-conclusion group_by/from_entries semantics as ci-run-metrics.sh."
      - "Add an offline-verifier fixture containing at least success, failure, and cancelled and require full statistics equality."
unverified_prohibitions:
  - requirement: FAST-01
    statement: "MUST NOT dispatch before readiness, rerun for a favorable p50, omit non-success conclusions, move the remediation cutoff, weaken the strict threshold, combine populations, or overwrite either historical miss."
    llm_judgment: "The retained correlation and histories show one authorized dispatch and no visible reroll; exact external-history completeness remains a judgment-tier review item."
  - requirement: GATE-05
    statement: "MUST NOT couple FAST-01 reconciliation to any downgrade, replacement, or reopening of the protected ownership proof."
    llm_judgment: "No violation is visible: GATE-05 remains Complete and its protected 93-row proof still passes deterministic verification."
---

# Phase 235: Terminal Ratification — Measured, Not Read Verification Report

**Phase Goal:** The milestone's headline claims are proven from run data, and a maintainer can see exactly what moved and where it landed.
**Verified:** 2026-09-09T14:49:33Z
**Status:** gaps_found
**Re-verification:** Yes — after Plans 235-16 through 235-18 closed the prior source-completeness gap

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Terminal measurement semantics retain every conclusion, use queue-inclusive wall duration, stable `{wall_seconds, run_id}` ordering, floor(n/2), and strict `<720`, and the offline oracle compares the complete result exactly. | ✗ FAILED | `ci-run-metrics.sh` correctly groups literal conclusions, but `verify-fast-01-source-complete-attestation-offline.sh:85-86` rewrites every non-success outcome as `failure`. A synthetic `{success,failure,cancelled}` population produces unequal maps. |
| 2 | PR wall-clock is below 12 minutes at p50 across at least 10 authenticated post-change PR runs. | ✓ VERIFIED | The retained signed subject has 52 unique eligible rows and p50 469 seconds; the current population contains 36 success and 16 failure conclusions. The fixed-path network-denied verifier succeeds for these exact bytes. |
| 3 | The new FAST-01 population is source-complete, chronologically bounded, and exhaustively paginated. | ✓ VERIFIED | Signed pages retain 100, 20, and terminal 0 rows with `exhausted: true`; raw timestamps derive membership and queue-inclusive durations through endpoint `2026-09-09T12:22:29Z`. |
| 4 | The protected evidence producer landed before the authorized measurement, and the dispatch is durably correlated to one protected-main run. | ✓ VERIFIED | Correlation artifact selects exactly run `34350618761` at protected SHA `158aca14b11de13cbc5ab2fdea1bff790cc7ab29`; Plan 16's seven tested blobs are recorded on that protected commit. |
| 5 | Earlier 772- and 724-second misses and the rejected derived-only 466-second candidate remain immutable history. | ✓ VERIFIED | REQUIREMENTS, the residual, SEED-005, CI-PERF, and focused contracts retain all three earlier outcomes while recognizing only the later authenticated result as completion authority. |
| 6 | One committed artifact lists the exact before/after PR, main, and nightly ownership universe. | ✓ VERIFIED | `235-TERMINAL-RATIFICATION.json` contains 93 sorted ownership rows derived from the hash-pinned Phase 234 inventory and declared non-Playwright families. |
| 7 | Every GATE-05 row is tied to an executable owner, event eligibility, aggregate, receiver, and protected receipt. | ✓ VERIFIED | Original protected verifier passes; focused contracts require exactly 93 keys and reject missing, unexpected, duplicate, stale, receiverless, receiptless, and aggregate-only rows. |
| 8 | Push and nightly outcomes over the terminal window are retained alongside the PR result. | ✓ VERIFIED | The terminal ledger retains the same-window push population (n=2, p50=1439) and schedule population (n=2, p50=1546), including non-success outcomes. |
| 9 | CONTRIBUTING describes the current direct owners, aggregates, non-PR signals, and local reproduction paths. | ✓ VERIFIED | Lines 74-80 distinguish `library_tests_shard`, `example_playwright_shard`, terminal aggregates, the Playwright package/config seam, and non-PR diagnostic jobs; contributor contracts pass. |
| 10 | SEED-005, CI-PERF, REQUIREMENTS, and the residual reconcile to the same authenticated FAST-01 disposition. | ✓ VERIFIED | All records cite cutoff `2026-08-03T21:37:08Z`, endpoint `2026-09-09T12:22:29Z`, n=52, p50=469, run `34350618761`, the subject/bundle, and the fixed-path verifier. |
| 11 | GATE-05 remains independently Complete while FAST-01 is reconciled. | ✓ VERIFIED | REQUIREMENTS contains one checked GATE-05 row and one Complete traceability row for protected run `30782184713`; the terminal contract and offline attestation verifier pass. |

**Score:** 10/11 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT.json` | Signed raw pages plus authoritative measurement output | ✓ VERIFIED | Substantive: 3 pages, 52 eligible rows, exact statistics, strict pass, protected provenance. |
| `235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT.attestation.jsonl` and trusted root | Exact-subject protected provenance | ✓ VERIFIED | Network-denied fixed-path verification succeeds. |
| `235-FAST-01-SOURCE-COMPLETE-DISPATCH-CORRELATION.json` | Sealed preflight and singleton post-dispatch binding | ✓ VERIFIED | Binds workflow, protected SHA, pre/post sets, candidate count 1, and run `34350618761`. |
| `scripts/ci/ci-run-metrics.sh` | Sole wall-mode membership/statistics authority | ✓ VERIFIED | Substantive and tested; preserves literal outcome keys and all terminal conclusions. |
| `scripts/ci/verify-fast-01-source-complete-attestation-offline.sh` | Independent exact source-first oracle | ✗ PARTIAL | Provenance/current-subject replay succeeds, but its outcome aggregation disagrees with the authority for valid non-success conclusions other than literal `failure`. |
| `phase_235_fast_01_source_complete_contract_test.exs` | Evidence, reconciliation, and GATE isolation contract | ⚠️ PARTIAL | Active and passing, but lacks the verifier-level multi-conclusion assertion needed to catch CR-01. |
| `235-TERMINAL-RATIFICATION.json` | Single 93-row before/after ownership ledger and same-window outcomes | ✓ VERIFIED | Exists, substantive, exact-key checked, wired to live topology and protected receipts. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Signed source pages | authoritative `ci-run-metrics.sh` output | retained input, membership, timestamps, ordering, and statistics | ✓ WIRED | Current subject reconstructs 52 rows and p50 469. |
| Authoritative outcome map | offline source-first oracle | full statistics equality | ✗ PARTIAL | Exact for the current success/failure-only population; breaks for other valid terminal conclusions. |
| Attestation bundle | source-complete subject | repository/signer/ref/workflow/digest policy under network denial | ✓ WIRED | Fixed-path verifier succeeds and adverse provenance cases fail. |
| Source-complete evidence | REQUIREMENTS / residual / SEED-005 / CI-PERF | evidence-gated reconciliation contract | ✓ WIRED | All four record surfaces carry the same authenticated tuple and disposition. |
| Phase 234 inventory and `ci.yml` | 93 ownership rows | hash pin, exact key set, owner/event/aggregate/receipt validation | ✓ WIRED | Original terminal contract and attestation verifier pass. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| FAST source-complete subject | `runs`, `statistics`, `verdict` | Signed GitHub workflow-run pages processed by `ci-run-metrics.sh` | Yes | ✓ FLOWING |
| Offline FAST verifier | oracle `statistics.outcomes` | Signed raw conclusions | Not for the full allowed conclusion domain | ✗ PARTIAL |
| FAST closeout records | n/p50/run/evidence tuple | Fixed retained subject and verifier | Yes | ✓ FLOWING |
| GATE-05 ownership ledger | `ownership.rows[*]` | Phase 234 inventory, live workflow topology, protected job receipts | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Metrics source-page and terminal-conclusion semantics | `bash scripts/ci/ci-run-metrics.test.sh` | 11 passed, 0 failed | ✓ PASS |
| Source-complete collector behavior | `bash scripts/ci/capture-fast-01-gap-closure.test.sh` | PASS | ✓ PASS |
| Source-complete provenance/current replay | `bash scripts/ci/verify-fast-01-source-complete-attestation-offline.sh` | `source_complete_offline_attestation_verified` | ✓ PASS |
| Original GATE-05 provenance | `bash scripts/ci/verify-terminal-ratification-attestation-offline.sh` | `offline_attestation_verified`; expected adverse errors observed | ✓ PASS |
| Focused Phase 235 contracts | `ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test mix test` on four Phase 235 files | 45 tests, 0 failures | ✓ PASS |
| Literal-outcome compatibility | independent jq comparison for `{success,failure,cancelled}` | instrument `{cancelled:1,failure:1,success:1}` vs verifier `{failure:2,success:1}`; unequal | ✗ FAIL |

### Probe Execution

Step 7c: SKIPPED — no Phase 235 `probe-*.sh` is declared. The phase-specific executable contracts are listed above.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| FAST-01 | All twelve Phase 235 plans | Under-12-minute p50 over at least 10 post-change PR runs | ⚠️ SATISFIED FOR RETAINED POPULATION; PHASE BLOCKED | Authenticated current subject proves n=52 and p50=469, but the Plan 16-18 all-terminal-conclusion verifier contract has CR-01. |
| GATE-05 | All twelve Phase 235 plans | One before/after artifact proves no test was silently dropped | ✓ SATISFIED | Protected run `30782184713`, exact 93-row ledger, current requirement rows, offline verifier, and focused contracts pass. |

Every requirement ID declared across all Phase 235 PLAN frontmatter is accounted for. REQUIREMENTS.md maps no additional requirement to Phase 235, so there are no orphaned requirements.

### Test Quality Audit

| Test File | Linked Req | Active | Skipped | Circular | Assertion Level | Verdict |
| --- | --- | ---: | ---: | --- | --- | --- |
| `phase_235_fast_01_source_complete_contract_test.exs` | FAST-01, GATE-05 | active | 0 | No | Behavioral/value | ✗ BLOCKER: does not exercise full verifier equality with an additional literal terminal conclusion |
| `phase_235_terminal_ratification_contract_test.exs` | FAST-01, GATE-05 | active | 0 | No | Behavioral | ✓ VALID for terminal ledger and GATE-05 |
| `ci-run-metrics.test.sh` | FAST-01 | 11 shell contracts | 0 | No | Behavioral/value | ✓ VALID; it exposes the literal conclusion domain the verifier mishandles |
| `capture-fast-01-gap-closure.test.sh` | FAST-01 | active shell suite | 0 | No | Behavioral | ✓ VALID for source-complete capture |

**Disabled tests on requirements:** 0. **Circular patterns detected:** 0. **Insufficient assertions:** 1 blocker in the source-complete offline-verifier seam.

### Review Finding Re-evaluation

| Finding | Scope | Verification verdict |
| --- | --- | --- |
| CR-01 — offline replay rejects valid all-conclusion populations | Direct Plan 16-18 path | Open BLOCKER; independently reproduced from the two implementations. |
| WR-01 — stdin source-page seam absent | Direct Plan 16 path | Warning; production uses a file and retained evidence is unaffected. |
| WR-02 — miss-pole replay validation incomplete | Direct Plan 16 path | Warning; latent because the authenticated result is a pass, but planned miss-branch hardening remains incomplete. |
| WR-03 — ExUnit replay omits full-statistics mutations | Direct Plan 16-18 path | Warning supporting CR-01; tests do not prove the claimed outcome compatibility. |
| CR-02, CR-03, CR-04, WR-04 | Historical diff cross-check | Recorded in `235-REVIEW.md`; not used to score the Phase 235 terminal goal because they are outside Plans 16-18's execution scope. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | ---: | --- | --- | --- |
| `scripts/ci/verify-fast-01-source-complete-attestation-offline.sh` | 85-86 | Independent oracle uses a narrower outcome schema than the authoritative instrument | 🛑 Blocker | A valid retained terminal population may be rejected, contradicting the all-conclusion exact-agreement must-have. |

No unreferenced `TBD`, `FIXME`, or `XXX` marker and no disabled requirement-linked test was found in the direct Phase 235 path.

### Decision Coverage

All 8 trackable `235-CONTEXT.md` decisions are honored by shipped artifacts. This heuristic gate is non-blocking.

### Human Verification Required

None. This is an infrastructure/evidence phase. The remaining gap is deterministic and does not require manual UAT.

### Deferred Items

None. Phase 235 is the final milestone phase, so no later phase clearly owns this gap.

### Gaps Summary

Plans 16-18 close the previous blocker: FAST-01 now has authenticated raw source pages, exhaustive pagination, independent current-population replay, n=52, and p50 469 seconds. GATE-05 remains independently complete with its protected 93-row ownership proof.

The phase still cannot pass because the direct source-complete verifier violates its own all-terminal-conclusion contract. The authoritative tool preserves literal terminal outcomes, while the offline oracle collapses all non-success states into `failure`. The current subject happens to contain only `success` and `failure`, so the positive verifier passes, but the declared evidence path is not correct for the allowed terminal domain. Per the verification gate, CR-01 is a BLOCKER and the canonical status is `gaps_found`.

---

_Verified: 2026-09-09T14:49:33Z_
_Verifier: the agent (gsd-verifier)_
