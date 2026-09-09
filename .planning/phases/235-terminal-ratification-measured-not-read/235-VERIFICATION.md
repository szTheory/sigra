---
phase: 235-terminal-ratification-measured-not-read
verified: 2026-09-09T15:59:27Z
status: human_needed
score: 11/11 must-haves verified
behavior_unverified: 0
overrides_applied: 0
next_action: "Human verification required. Complete the manual tests in the phase's *-UAT.md, then re-run the verify step until status is passed."
next_command: "$gsd-verify-work 235"
re_verification:
  previous_status: gaps_found
  previous_score: 10/11
  gaps_closed:
    - "The source-first offline verifier now preserves every literal terminal conclusion and rejects a success/failure map that collapses cancelled into failure."
  gaps_remaining: []
  regressions: []
unverified_prohibitions:
  - requirement: FAST-01
    statement: "MUST NOT dispatch before readiness, rerun for a favorable p50, omit non-success conclusions, move the remediation cutoff, weaken the strict threshold, combine populations, or overwrite either historical miss."
    llm_judgment: "No violation found: the sealed correlation binds one post-protected-main dispatch, live history has only run 34350618761 after protected SHA 158aca14, literal outcomes are retained, and contracts preserve cutoff, threshold, population, and history. This remains a non-authoritative judgment-tier prohibition."
  - requirement: GATE-05
    statement: "MUST NOT couple FAST-01 reconciliation to any downgrade, replacement, or reopening of the protected ownership proof."
    llm_judgment: "No violation found: the independent verifier passes, the ledger remains exactly 93 rows, and protected receipt/digest guards remain green. This remains a non-authoritative judgment-tier prohibition."
human_verification:
  - test: "Review the FAST-01 dispatch and evidence-history sufficiency judgment."
    expected: "Accept that the sealed singleton dispatch, exhaustive source window, literal-outcome replay, immutable cutoff/threshold, and retained miss history rule out a favorable reroll or evidence substitution."
    why_human: "Repository and GitHub evidence prove observable history, but intent and absence of undisclosed attempts are judgment-tier negative claims."
  - test: "Review the GATE-05 independence judgment."
    expected: "Accept that FAST-01 reconciliation did not downgrade, replace, or reopen the protected 93-row ownership proof."
    why_human: "Digest equality and independent verification prove byte preservation; complete semantic independence is the plan's flagged judgment-tier prohibition."
---

# Phase 235: Terminal Ratification — Measured, Not Read Verification Report

**Phase Goal:** The milestone's headline claims are proven from run data, and a maintainer can see exactly what moved and where it landed.
**Verified:** 2026-09-09T15:59:27Z
**Status:** human_needed
**Re-verification:** Yes — after Plan 235-19 repaired the sole deterministic gap

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Terminal measurement semantics retain every conclusion, use queue-inclusive wall duration, stable `{wall_seconds, run_id}` ordering, `floor(n/2)`, strict `<720`, and exact offline-oracle agreement. | ✓ VERIFIED | `verify-fast-01-source-complete-attestation-offline.sh:48-58` now builds a literal `group_by(.conclusion)` map and compares the complete statistics object at both locations. The 10-run success/failure/cancelled fixture passes; its collapsed map and 720-second mutations fail. |
| 2 | PR wall-clock is below 12 minutes at p50 across at least 10 authenticated post-change PR runs. | ✓ VERIFIED | The signed retained subject contains 52 unique eligible runs, p50 469 seconds, and strict `pass`; the default network-denied verifier succeeds. |
| 3 | The FAST-01 population is source-complete, chronologically bounded, and exhaustively paginated. | ✓ VERIFIED | The signed subject retains pages of 100, 20, and terminal 0 rows with `exhausted: true`; source-first replay and adverse page/timestamp checks pass. |
| 4 | The protected producer landed before measurement, and dispatch is correlated to one protected-main run. | ✓ VERIFIED | Correlation selects run `34350618761` at protected SHA `158aca14b11de13cbc5ab2fdea1bff790cc7ab29`; live workflow history has no sibling/later dispatch on that SHA. |
| 5 | Earlier 772- and 724-second misses and the rejected derived-only 466-second candidate remain immutable history. | ✓ VERIFIED | Focused contracts check all three histories across REQUIREMENTS, the residual, SEED-005, and CI-PERF while recognizing only the authenticated result. |
| 6 | One committed artifact lists the exact before/after PR, main, and nightly ownership universe. | ✓ VERIFIED | `235-TERMINAL-RATIFICATION.json` remains a substantive 93-row ledger derived from the pinned Phase 234 inventory. |
| 7 | Every GATE-05 row has an executable owner, event state, aggregate, receiver, and protected receipt. | ✓ VERIFIED | The independent terminal verifier succeeds; focused contracts reject missing, unexpected, duplicate, stale, receiverless, receiptless, and aggregate-only rows. |
| 8 | Push and nightly outcomes over the same measurement window are recorded alongside PR. | ✓ VERIFIED | The ledger retains push n=2/p50=1439 and schedule n=2/p50=1546, including non-success outcomes. |
| 9 | CONTRIBUTING describes current owners, aggregates, non-PR signals, and local reproduction paths. | ✓ VERIFIED | `CONTRIBUTING.md:11-80` documents `mix ci`, both shard owners and aggregates, the Playwright seam, and push/schedule diagnostics; contracts pass. |
| 10 | SEED-005, CI-PERF, REQUIREMENTS, and the residual reconcile to the same authenticated FAST-01 disposition. | ✓ VERIFIED | All carry cutoff `2026-08-03T21:37:08Z`, endpoint `2026-09-09T12:22:29Z`, n=52, p50=469, run `34350618761`, and fixed verifier path. |
| 11 | GATE-05 remains independently Complete while FAST-01 is reconciled. | ✓ VERIFIED | REQUIREMENTS retains GATE-05 Complete from protected run `30782184713`; the exact 93-row digest contract and independent verifier remain green. |

**Score:** 11/11 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT.json` | Signed source pages and authoritative output | ✓ VERIFIED | 52 rows, p50 469, exact statistics equality, exhaustive pages, protected provenance. |
| Source-complete attestation and trusted root | Exact-subject provenance | ✓ VERIFIED | Fixed-path network-denied verifier succeeds. |
| `235-FAST-01-SOURCE-COMPLETE-DISPATCH-CORRELATION.json` | Sealed readiness/singleton binding | ✓ VERIFIED | Binds protected SHA, pre/post sets, candidate count 1, and run `34350618761`. |
| `scripts/ci/ci-run-metrics.sh` | Sole membership/statistics authority | ✓ VERIFIED | Substantive and tested; literal outcomes, stable order, median, and strict threshold. |
| `scripts/ci/verify-fast-01-source-complete-attestation-offline.sh` | Independent source-first oracle | ✓ VERIFIED | Shared validator preserves literal keys and exact complete statistics; both modes pass. |
| `phase_235_fast_01_source_complete_contract_test.exs` | Evidence and regression contract | ✓ VERIFIED | 16 active tests, including multi-conclusion positive and collapsed-map adverse fixtures. |
| `235-TERMINAL-RATIFICATION.json` | Single ownership ledger and same-window outcomes | ✓ VERIFIED | Exact-key checked, 93 rows, wired to live topology and protected receipts. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Signed source pages | authoritative metrics result | retained input, timestamps, ordering, statistics | ✓ WIRED | Reconstructs 52 rows and p50 469. |
| Source conclusions | oracle outcomes | literal grouping | ✓ WIRED | Lines 48-56 preserve every key and require equality twice. |
| Authenticated path | shared validator | digest/provenance then shared semantics | ✓ WIRED | Both authenticated and fixture banners are tested. |
| Phase 234 inventory and `ci.yml` | 93 ownership rows | hash, exact keys, owner/event/aggregate/receipt checks | ✓ WIRED | Contract and attestation verifier pass. |
| FAST-01 evidence | four closeout records | exact evidence tuple | ✓ WIRED | All carry the same authenticated result. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| FAST subject | runs/statistics/verdict | Signed GitHub run pages through `ci-run-metrics.sh` | Yes | ✓ FLOWING |
| Offline verifier | oracle runs/statistics/outcomes | Retained signed source rows | Yes | ✓ FLOWING |
| Closeout records | n/p50/run/evidence | Fixed retained subject and verifier | Yes | ✓ FLOWING |
| GATE-05 ledger | `ownership.rows[*]` | Phase 234 inventory, workflow topology, protected receipts | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Metrics semantics | `bash scripts/ci/ci-run-metrics.test.sh` | 11 passed, 0 failed | ✓ PASS |
| Authenticated FAST replay | default offline verifier | `source_complete_offline_attestation_verified` | ✓ PASS |
| Protected GATE-05 | terminal offline verifier | `offline_attestation_verified`; expected adverse errors occurred first | ✓ PASS |
| Literal outcomes/authenticated separation | focused source-complete ExUnit | 16 tests, 0 failures | ✓ PASS |
| Terminal and historical regressions | three other Phase 235 ExUnit files | 31 tests, 0 failures | ✓ PASS |
| Machine-readable predicates | `jq` over both ledgers | n=52/p50=469/exact stats and 93 rows/push+schedule true | ✓ PASS |

### Probe Execution

SKIPPED — no Phase 235 `probe-*.sh` is declared; phase-specific executable contracts are above.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| FAST-01 | All thirteen plans | Under-12-minute p50 over at least 10 post-change PR runs | ✓ SATISFIED | Authenticated n=52/p50=469 plus corrected literal-outcome exact replay. |
| GATE-05 | All thirteen plans | One before/after artifact proves no silent drop | ✓ SATISFIED | Protected run `30782184713`, exact 93-row ledger, verifier, and contracts. |

No Phase 235 requirement is orphaned: every PLAN requirement ID is FAST-01 or GATE-05, and REQUIREMENTS.md maps no additional ID here.

### Test Quality Audit

| Test File | Linked Req | Active | Skipped | Circular | Assertion Level | Verdict |
| --- | --- | ---: | ---: | --- | --- | --- |
| Source-complete ExUnit contract | FAST-01, GATE-05 | 16 | 0 | No | Behavioral/value | ✓ VALID; real shell verifier, literal outcomes, lossy rejection, boundary, provenance, records, GATE immutability. |
| Terminal-ratification ExUnit contract | FAST-01, GATE-05 | active | 0 | No | Behavioral/value | ✓ VALID for ledger and ownership. |
| `ci-run-metrics.test.sh` | FAST-01 | 11 | 0 | No | Behavioral/value | ✓ VALID for source membership and metric semantics. |
| Capture shell contract | FAST-01 | active | 0 | No | Behavioral/value | ✓ VALID for completeness and boundaries. |

Disabled requirement-linked tests: 0. Circular patterns: 0. Insufficient assertions against the repaired must-have: 0.

### Review Finding Re-evaluation

| Finding | Must-have impact |
| --- | --- |
| CR-01 — install-smoke caller-selected deletion | Serious pre-ship safety blocker, but outside the Phase 235 measurement/ownership data flow; no roadmap truth is falsified. |
| CR-02 — verifier `mktemp` cleanup trust | Directly inspected. Serious pre-ship safety defect, but it does not alter the retained subject, provenance output, statistics replay, or ownership proof in the trusted verification environment, so no Phase 235 must-have is falsified. |
| CR-03 — OAuth evidence callback arity | Product defect outside Phase 235 artifacts; no must-have link. |
| WR-01 — fixture accepts incomplete envelope fields | Fixture is weaker than the authoritative input contract, but the roadmap claim uses the digest-pinned authenticated path. Plan 19's required complete statistics equality is enforced. |
| WR-02 — miss-pole validation incomplete | Latent for a miss; authenticated verdict is a pass and requires `binding_poles: null`. |
| WR-03 — stdin source-page seam absent | Production uses the verified file seam; no roadmap truth depends on stdin. |
| WR-04 — raw missing-option diagnostics | Robustness warning without effect on retained proof. |

The advisory review was not treated as a waiver: every finding was traced to the must-have data flow. CR-02 remains a material pre-ship concern even though it does not falsify the phase goal.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | ---: | --- | --- | --- |
| Source-complete offline verifier | 101-113 | Unwhitelisted `mktemp` and unvalidated recursive cleanup | ⚠️ Phase-goal warning; critical pre-ship issue | Proof output is unaffected in the verified environment, but cleanup can target a caller-influenced path. |
| Source-complete offline verifier | 26-58 | Fixture omits some authoritative envelope validation | ⚠️ Warning | Fixture is not a full substitute for the authenticated path; it does prove Plan 19's literal-outcome regression. |

No unreferenced `TBD`, `FIXME`, or `XXX`, disabled linked test, stub, or hollow data path was found in the Plan 19 files.

### Decision Coverage

All 8 trackable CONTEXT decisions are honored by shipped artifacts. This gate is non-blocking.

### Human Verification Required

#### 1. FAST-01 negative-evidence sufficiency

**Test:** Review sealed correlation, protected workflow-dispatch history, exhaustive signed source pages, and immutable prior results.
**Expected:** Accept that these rule out pre-readiness dispatch, favorable reroll, filtered conclusions, changed cutoff/threshold, combined populations, and overwritten history.
**Why human:** The facts are automated, but intent and absence of undisclosed attempts remain explicitly flagged judgment-tier claims.

#### 2. GATE-05 semantic independence

**Test:** Review unchanged ledger/receipt digests, exact 93-row contract, and independent verifier.
**Expected:** Accept that FAST-01 reconciliation did not downgrade, replace, or reopen GATE-05.
**Why human:** Byte preservation is deterministic; complete negative semantic interpretation remains judgment-tier.

### Deferred Items

None. Phase 235 is the final milestone phase.

### Gaps Summary

**No implementation gap remains.** Plan 235-19 closes the literal-outcome blocker and all 11 truths are verified. Status remains `human_needed`, not `passed`, solely because two flagged judgment-tier prohibitions require explicit maintainer resolution.

---

_Verified: 2026-09-09T15:59:27Z_
_Verifier: the agent (gsd-verifier)_
