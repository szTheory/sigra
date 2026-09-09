---
phase: 235-terminal-ratification-measured-not-read
verified: 2026-09-08T20:48:32Z
status: gaps_found
score: 9/11 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 9/10
  gaps_closed: []
  gaps_remaining:
    - "FAST-01 is not independently proven: the signed 43-row candidate stores a p50 of 466 seconds but omits the source timestamps and pagination/exhaustion evidence needed to prove the population, window, chronology, and queue-inclusive wall duration."
  regressions: []
gaps:
  - truth: "FAST-01 is achieved from one independently authenticated population of at least 10 post-remediation PR runs with queue-inclusive p50 strictly below 720 seconds."
    status: failed
    reason: "Protected run 34272746647 signed 43 derived rows with stored p50 466, but each signed row contains only run_id, url, conclusion, and producer-supplied wall_seconds. The signed subject contains no created_at/updated_at fields or authenticated page identities, counts, and terminal exhaustion marker, so an offline consumer cannot independently establish membership, chronology, completeness, or updated_at-created_at duration."
    artifacts:
      - path: ".planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-GAP-CLOSURE-REMEASUREMENT.json"
        issue: "Authentic but evidentially hollow for the required source proof: the candidate attests derived values rather than the raw bounded population."
      - path: "scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh"
        issue: "validate_population recomputes p50 only from signed wall_seconds; it cannot derive window membership, chronology, duration, or exhaustive population from absent source fields."
      - path: "test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs"
        issue: "The focused test independently sorts producer-supplied wall_seconds, but has the same evidence ceiling as the verifier."
    missing:
      - "A newly authorized protected-main subject retaining created_at and updated_at for every eligible run."
      - "Authenticated pagination evidence with contiguous requested page identities/counts and a terminal exhaustion marker."
      - "Offline verification that derives window membership and queue-inclusive wall_seconds from those signed source fields before calculating p50."
unverified_prohibitions:
  - requirement: FAST-01
    statement: "MUST NOT dispatch before readiness, rerun for a favorable p50, omit non-success conclusions, move the remediation cutoff, weaken the strict threshold, combine populations, or overwrite either historical miss."
    llm_judgment: "No violation is visible in retained repository evidence; exact-once external dispatch history is not independently re-proven here. Human review recommended."
  - requirement: GATE-05
    statement: "MUST NOT couple FAST-01 reconciliation to any downgrade, replacement, or reopening of the protected ownership proof."
    llm_judgment: "No violation is visible: the GATE-05 artifacts and verifier are digest-pinned and the protected proof still passes. Human review recommended because this is a judgment-tier prohibition."
---

# Phase 235: Terminal Ratification — Measured, Not Read Verification Report

**Phase Goal:** The milestone's headline claims are proven from run data, and a maintainer can see exactly what moved and where it landed.
**Verified:** 2026-09-08T20:48:32Z
**Status:** gaps_found
**Re-verification:** Yes — after halted gap plan 235-15

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Terminal measurement semantics retain every conclusion, use queue-inclusive wall duration, stable `{wall_seconds, run_id}` ordering, floor(n/2), and strict `<720`. | ✓ VERIFIED | `ci-run-metrics.test.sh` passed 9/9 checks; focused tests exercise 719/720/721 and terminal conclusions. |
| 2 | FAST-01 is achieved over at least 10 post-change PR runs. | ✗ FAILED | The earlier independently source-proven window is `n=19`, p50 `772`. The newer stored p50 `466` is not independently source-proven. |
| 3 | The original Phase 235 source population is independently authenticated and exhaustively paginated. | ✓ VERIFIED | `235-PROTECTED-RECEIPTS.json` retains total 24, requested pages `[1,2]`, terminal page 2, `exhausted:true`, timestamps, and job manifests; the offline attestation verifier passed. |
| 4 | The fresh Plan 235-15 candidate independently proves its source population, fixed-window membership, chronology, and queue-inclusive durations. | ✗ FAILED | Signed rows contain only `run_id`, `url`, `conclusion`, and `wall_seconds`; source timestamps and pagination/exhaustion evidence are absent. This confirms `235-REVIEW.md` CR-02. |
| 5 | Binding-pole and remediation evidence is retained without rewriting the two historical misses. | ✓ VERIFIED | The contracts retain the 772- and 724-second misses and the retry-free Library/wall improvement from 692→148 and 724→470 seconds. |
| 6 | One committed artifact lists the exact before/after PR, main, and nightly ownership universe. | ✓ VERIFIED | The terminal ledger contains 93 sorted ownership rows derived from the hash-pinned Phase 234 inventory plus the declared non-Playwright universe. |
| 7 | Every GATE-05 row is tied to an executable owner, event eligibility, aggregate, receiver, and protected job receipt. | ✓ VERIFIED | The original protected receipt and `phase_235_terminal_ratification_contract_test.exs` passed; executed and intentionally absent mutations are rejected. |
| 8 | Push and nightly outcomes over the same terminal measurement window are recorded from protected run data. | ✓ VERIFIED | The independently authenticated original window retains push `1 success / 1 non-success` and schedule `0 success / 2 non-success`. |
| 9 | CONTRIBUTING describes current direct owners, aggregates, non-PR signals, and local reproduction. | ✓ VERIFIED | The Phase 235 and Phase 198 contributor contracts pass against `ci.yml`, Mix, and Playwright sources. |
| 10 | SEED-005 and CI-PERF are reconciled, with a durable residual for an unproven or missed FAST-01 claim. | ✓ VERIFIED | Requirements and closeout records keep FAST-01 open, preserve both historical misses, describe the rejected 466-second candidate, and retain the owned residual. |
| 11 | The halted gap plan fails closed instead of treating a signed stored p50 as sufficient proof. | ✓ VERIFIED | FAST-01 is unchecked/Gaps Found; the residual and Plan 235-15 diagnostics explicitly reject closure and prohibit redispatching this attempt. |

**Score:** 9/11 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `235-FAST-01-GAP-CLOSURE-REMEASUREMENT.json` | Independently replayable fresh measurement subject | ⚠️ HOLLOW | Exists, is signed, and stores 43 rows/p50 466, but lacks raw timestamps and pagination/exhaustion source evidence. |
| `235-FAST-01-GAP-CLOSURE-REMEASUREMENT.attestation.jsonl` + trusted root | Exact-subject protected provenance | ✓ VERIFIED | Network-denied offline verification passes and rejects altered subject, bundle, root, signer, and ref. Provenance authenticates the insufficient subject; it does not add missing fields. |
| `verify-fast-01-gap-closure-attestation-offline.sh` | Independent source and verdict verifier | ⚠️ PARTIAL | Substantive and wired, but can only validate/sort supplied `wall_seconds`; CR-02 cannot be implemented against the retained subject. |
| `phase_235_fast_01_gap_closure_contract_test.exs` | Independent source recomputation and status guard | ⚠️ PARTIAL | Substantive, active, and passing; it correctly keeps FAST-01 open but cannot reconstruct absent source facts. |
| `235-PROTECTED-RECEIPTS.json` + original attestation/root | Complete GATE-05 protected run/job evidence | ✓ VERIFIED | Complete pages, source timestamps, jobs, provenance, and immutable digest pins remain intact. |
| `235-TERMINAL-RATIFICATION.json` | Single before/after ownership and terminal ledger | ✓ VERIFIED | 93 rows, source inventory, original measurements, closeout links, and protected provenance remain substantive and wired. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Fresh attestation bundle | Fresh remeasurement subject | subject digest + signer/ref policy | ✓ WIRED | Exact retained bytes authenticate successfully. |
| Fresh remeasurement subject | FAST-01 verdict | raw source → membership → chronology → duration → p50 | ✗ NOT_WIRED | The chain terminates at producer-supplied `wall_seconds`; the raw source and pagination evidence are absent. |
| Original protected receipt | GATE-05 ownership ledger | attestation + exact inventory + event/job reconciliation | ✓ WIRED | Offline verifier and focused contract both pass. |
| `ci.yml` / Phase 234 inventory | 93 ownership rows | owner/event/aggregate/receipt semantic map | ✓ WIRED | Exact-key and live-job adverse mutations remain covered. |
| Terminal records | REQUIREMENTS.md | fail-closed status reconciliation | ✓ WIRED | FAST-01 remains unchecked/Gaps Found; GATE-05 remains checked/Complete. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Fresh FAST candidate | `runs[*].wall_seconds` / `statistics.p50_seconds` | Signed derived subject | Derived values only; no raw timestamps/pages | ⚠️ STATIC / HOLLOW |
| Original terminal measurement | `measurements.*.runs` | Attested protected workflow-run pages | Yes | ✓ FLOWING |
| GATE-05 ownership | `ownership.rows[*].after` and receipt | Phase 234 inventory + `ci.yml` + protected job manifests | Yes | ✓ FLOWING |
| Closeout records | FAST/GATE status prose | Retained evidence and explicit fail-closed contract | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Fresh offline attestation | `bash scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh` | Exact subject accepted; adverse provenance cases rejected; exit 0 | ✓ PASS |
| Original GATE-05 offline attestation | `bash scripts/ci/verify-terminal-ratification-attestation-offline.sh` | Exact protected subject accepted; adverse cases rejected; exit 0 | ✓ PASS |
| Focused FAST/GATE contracts | `ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test mix test ...phase_235_fast_01_gap_closure_contract_test.exs ...phase_235_terminal_ratification_contract_test.exs` | 29 tests, 0 failures | ✓ PASS |
| FAST collector contract | `bash scripts/ci/capture-fast-01-gap-closure.test.sh` | PASS | ✓ PASS |
| Original protected collector contract | `bash scripts/ci/capture-terminal-ratification-evidence.test.sh` | Exit 0 | ✓ PASS |
| Metrics contract | `bash scripts/ci/ci-run-metrics.test.sh` | 9 passed, 0 failed | ✓ PASS |
| Full planning contracts | `ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test mix test test/sigra/planning/` | 129 tests, 0 failures, 12 skipped | ✓ PASS |

### Probe Execution

Step 7c: SKIPPED — no Phase 235 `probe-*.sh` is declared. All phase-specific executable contracts are listed above.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| FAST-01 | 235-01 through 235-08, 235-15 | Under-12-minute p50 over at least 10 post-change PR runs | ✗ BLOCKED | Original authoritative p50 is 772; newer signed p50 466 lacks independent source-population proof. |
| GATE-05 | 235-01 through 235-08, 235-15 | One before/after artifact proves no test was silently dropped | ✓ SATISFIED | Original protected run `30782184713`, exact 93-row ledger, offline verifier, contract tests, and current digest pins pass. |

Every requirement ID declared by every Phase 235 PLAN is accounted for. REQUIREMENTS.md maps no additional requirement to Phase 235, so there are no orphaned requirements. No later milestone phase exists to defer the FAST-01 gap.

### Test Quality Audit

| Test File | Linked Req | Active | Skipped | Circular | Assertion Level | Verdict |
| --- | --- | ---: | ---: | --- | --- | --- |
| `phase_235_fast_01_gap_closure_contract_test.exs` | FAST-01, GATE-05 | 8 | 0 | No | Value/behavioral | ⚠️ INSUFFICIENT for FAST-01 source proof; valid fail-closed status guard and GATE-05 digest pinning |
| `phase_235_terminal_ratification_contract_test.exs` | FAST-01, GATE-05 | 21 | 0 | No | Behavioral | ✓ VALID for the original protected window and GATE-05 |
| `capture-fast-01-gap-closure.test.sh` | FAST-01 | active shell suite | 0 | No | Behavioral | ✓ VALID for collector behavior, but it cannot retrofit missing fields into the already signed candidate |

**Disabled tests on requirements:** 0. **Circular expected-value generation:** 0. **Insufficient assertions/evidence:** 1 blocker — fresh FAST assertions operate on derived rows rather than an independent raw-source oracle.

### Review Finding Re-evaluation

| Finding | Current verdict | Evidence |
| --- | --- | --- |
| CR-02 — signed evidence cannot support independent population recomputation | Open — BLOCKER | The exact signed candidate still has no source timestamps or pagination/exhaustion manifest. Passing signature and p50 checks do not supply those facts. |
| WR-02 — GATE-05 byte-exact non-regression weaker than claimed | Closed in current tree | The post-review contract pins SHA-256 values for the protected subject, bundle, trusted root, terminal ledger, and offline verifier, and requires exactly one canonical GATE-05 requirement and traceability row. The focused test passes. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | ---: | --- | --- | --- |
| `scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh` | 177 | Authenticated derived-value validation without authenticated source population | 🛑 Blocker | A valid signature and recomputed stored p50 can be mistaken for independent FAST-01 proof. Current status handling correctly refuses that conclusion. |

No unreferenced `TBD`, `FIXME`, or `XXX` marker and no disabled requirement test was found in the checked Phase 235 implementation files.

### Decision Coverage

All 8 trackable CONTEXT.md decisions are honored by shipped artifacts. This gate is non-blocking.

### Human Verification Required

None. This is an evidence/infrastructure phase, and the remaining failure is deterministically observable from the signed schema. The two descriptor-less judgment-tier prohibitions remain explicitly flagged in frontmatter for maintainer review; neither is silently treated as verified.

### Gaps Summary

GATE-05 remains independently satisfied: the original attested receipt, 93-row ownership ledger, event/job execution proof, contributor topology, and immutable pins all pass.

Phase 235 still fails its complete goal because FAST-01 lacks acceptable proof. The signed candidate's stored `466`-second p50 is not evidence of a complete bounded queue-inclusive population by itself. CR-02 is directly observable and remains a **BLOCKER**. A future gap plan must change the protected subject schema before dispatch, retain authenticated raw timestamps and pagination/exhaustion evidence, then perform one newly authorized measurement. The halted 235-15 attempt must not be resumed or reinterpreted.

---

_Verified: 2026-09-08T20:48:32Z_
_Verifier: the agent (gsd-verifier)_
