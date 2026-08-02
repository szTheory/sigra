---
phase: 235-terminal-ratification-measured-not-read
verified: 2026-08-02T19:12:46Z
status: gaps_found
score: 4/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 7/10
  gaps_closed:
    - "The contract now recomputes stored statistics and verifies each stored canonical-output SHA-256."
    - "The contract now requires exact 93-key ownership-universe equality and rejects extra family/event rows."
    - "The contributor topology check now scopes direct owners, aggregate dependencies, and non-PR guards to workflow job blocks."
  gaps_remaining:
    - "The captured population, capture endpoint, run identities, and binding-pole job evidence remain self-asserted rather than source-receipt-bound."
    - "The ownership contract accepts arbitrary owner/receiver/receipt values; the committed ci_gate rows name a non-existent workflow job instead of ci-gate."
  regressions: []
gaps:
  - truth: "The terminal ledger proves its FAST-01 measurement from one immutable, bounded GitHub run population."
    status: failed
    reason: "The contract recalculates values only from mutable ledger data. It never pins capture_endpoint.captured_at or population_sha256, validates retained IDs as source identities, or retains/hash-checks the raw gh run-list response. Changing endpoint, rows, statistics receipt, and digest coherently can produce a different accepted verdict."
    artifacts:
      - path: "test/sigra/planning/phase_235_terminal_ratification_contract_test.exs"
        issue: "validate_capture!/1 only checks status; validate_captured_ledger!/1 only makes run_ids equal mutable runs; population_sha256 is never read."
    missing:
      - "Pin the capture instant and validate it as an ISO-8601 instant."
      - "Commit a canonical raw run-list receipt (or equivalent immutable source receipt), verify its SHA-256, and require positive retained IDs/URLs/events/timestamps to match it."
      - "Add endpoint, source-population, nil/string/invented-ID, and coherent-forgery mutations."
  - truth: "A measured FAST-01 miss has authentic binding-pole evidence tied to the retained PR population."
    status: failed
    reason: "For a miss, validate_verdict!/1 only requires a nonempty receipt whose command embeds its own run_id, any binary digest, and a binary pole name. It does not require the ID to be a retained PR run, validate the URL/digest against retained --jobs output, or compare pole fields to that output."
    artifacts:
      - path: "test/sigra/planning/phase_235_terminal_ratification_contract_test.exs"
        issue: "Lines 741-750 admit a fabricated binding-pole receipt."
    missing:
      - "Retain canonical per-run --jobs output, bind and hash it, require receipt IDs to occur in the retained PR population, and validate URL, selection, job name, conclusion, and duration."
  - truth: "The ownership artifact accurately names the executable lane that carries every affected family on PR, main, and nightly."
    status: failed
    reason: "Exact key coverage is enforced, but each of 93 rows is accepted with only nonempty direct_owner/receiver/receipt strings. The committed ci_gate_aggregate rows name after.direct_owner and receiver ci_gate, whereas the live workflow job is ci-gate. Thus the artifact already contains an inaccurate destination and the contract would admit further fabricated mappings."
    artifacts:
      - path: ".planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json"
        issue: "Three ci_gate_aggregate rows contain ci_gate, not the live ci-gate job identifier."
      - path: "test/sigra/planning/phase_235_terminal_ratification_contract_test.exs"
        issue: "validate_rows!/1 validates only nonempty semantic fields, apart from a library_tests aggregate special case."
    missing:
      - "Correct the ci_gate rows and enforce a declared family/event-to-owner/aggregate/receiver/receipt mapping against parsed workflow job IDs and evidence receipts."
      - "Add wrong-but-plausible owner, receiver, aggregate, and receipt mutation coverage."
---

# Phase 235: Terminal Ratification — Measured, Not Read Verification Report

**Phase Goal:** The milestone's headline claims are proven from run data, and a maintainer can see exactly what moved and where it landed.
**Verified:** 2026-08-02T19:12:46Z
**Status:** gaps_found
**Re-verification:** Yes — after Plan 04 gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | PR wall-clock is under 12 minutes at p50 across at least 10 post-change PR runs. | ✗ FAILED | The ledger reports 19 PR runs and p50 772 seconds; `772 >= 720`. The roadmap permits honest disclosure, but FAST-01 remains Pending in REQUIREMENTS.md. |
| 2 | The FAST-01 result is proven from a fixed, immutable bounded run population. | ✗ FAILED | `population_sha256` has no consumer; lines 554-568 do not pin the endpoint and lines 684-705 bind only self-supplied rows/receipt bytes. |
| 3 | Push and schedule have reliable same-window measured counterparts. | ✗ FAILED | They are recalculated from ledger rows, but those rows share the same unbound endpoint/source-population weakness. |
| 4 | The ownership artifact has the exact declared Playwright/non-Playwright key universe. | ✓ VERIFIED | Focused test passed; lines 611-624 compare the actual MapSet to the 93-key inventory-derived universe and tests reject extra family/event rows. |
| 5 | The ownership artifact accurately states where every affected family landed. | ✗ FAILED | The live job is `ci-gate` (`ci.yml:1522`), while all three `ci_gate_aggregate` rows say `ci_gate`; arbitrary nonempty mappings also pass lines 643-656. |
| 6 | CONTRIBUTING accurately distinguishes direct owners, aggregates, local reproduction, and intentionally non-PR signals. | ✓ VERIFIED | Focused topology tests passed; workflow-scoped checks confirm `library_tests_shard`, `example_playwright_shard`, aggregate `needs`, and both non-PR job guards. |
| 7 | SEED-005 and CI-PERF reconcile the terminal result and the FAST-01 residual is ledger-linked. | ✓ VERIFIED | Both records cite the terminal ledger, 19 runs/772 seconds, the honest miss, and the single pending residual path. |
| 8 | The closeout contract resists contributor-topology contradictions. | ✓ VERIFIED | Lines 845-965 extract named job blocks and reject aggregate-executor and false-PR claims; its contradiction mutations pass. |

**Score:** 4/8 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `.planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json` | Single terminal measurement and ownership source | ⚠️ PARTIAL | Substantive 3,040-line ledger with current data, canonical metric output, and 93 rows; provenance and one live owner are not correct/fail-closed. |
| `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | Fail-closed ledger/topology/closeout contract | ⚠️ PARTIAL | Substantive and executed (13 tests pass), but it omits source-population, binding-pole, and full ownership-semantics enforcement. |
| `CONTRIBUTING.md` | Current CI topology and local reproduction | ✓ VERIFIED | The scoped test and direct workflow inspection agree. |
| `.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md` | Ledger-backed terminal addendum | ✓ VERIFIED | Documents the measured miss and residual without claiming target achievement. |
| `.planning/MILESTONE-ARC.md` | Reconciled CI-PERF outcome | ✓ VERIFIED | Cites the ledger and preserves the FAST-01 miss/residual. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Phase 234 inventory | Terminal ledger | Pinned inventory SHA and exact 93-key cross-product | ✓ WIRED | Test reads the inventory, checks its SHA, and enforces exact key equality. |
| Retained GitHub run data | Terminal ledger | Capture endpoint, run IDs, metadata, canonical metric receipt | ✗ NOT PROVEN | No retained raw source receipt or endpoint/population-hash validation exists. |
| Terminal ledger | Focused contract | Recomputed stats → canonical receipt → digest → verdict | ⚠️ PARTIAL | Internally wired and recomputed, but all inputs can be coherently replaced. |
| Live CI workflow | Ownership ledger | After direct owner, aggregate, and receiver | ✗ NOT_WIRED | Full-row semantics are not checked; `ci_gate` demonstrably does not match `ci-gate`. |
| Live CI workflow | CONTRIBUTING | Owners, aggregates, direct commands, event guards | ✓ WIRED | Named workflow-block extraction and contradiction tests pass. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Terminal ledger | `measurements.*.runs` / statistics | Committed run metadata | No independently bound source receipt | ⚠️ SELF-ASSERTED |
| Terminal ledger | `ownership.rows` | Phase 234 inventory plus workflow/evidence labels | Exact key set flows; semantic destination map is unconstrained | ✗ HOLLOW_MAPPING |
| CONTRIBUTING | CI overview statements | Parsed `ci.yml` job blocks | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Phase 235 terminal contract | `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs --trace` | 13 tests, 0 failures | ✓ PASS — coverage gaps found by source inspection |
| Metric semantics | `bash scripts/ci/ci-run-metrics.test.sh` | 9 passed, 0 failed | ✓ PASS |
| Phase 234 inventory contract | `MIX_ENV=test mix test test/sigra/planning/phase_234_playwright_inventory_contract_test.exs` | 6 tests, 0 failures | ✓ PASS |
| Current owner reconciliation | `jq` direct owners vs `ci.yml` job IDs | `ci_gate` has no matching job; live ID is `ci-gate` | ✗ FAIL |

### Probe Execution

Step 7c: SKIPPED — no Phase 235 probe script or declared probe was found.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| FAST-01 | 235-01, 235-02, 235-03, 235-04 | Under-12-minute PR p50 over at least 10 post-change runs | ✗ BLOCKED | Reported p50 is 772 seconds, not strict `< 720`; additionally the claimed source population/binding-pole proof is not immutable. |
| GATE-05 | 235-01, 235-02, 235-03, 235-04 | One before/after PR/main/nightly ownership artifact with no silently dropped tests | ✗ BLOCKED | Exact row keys pass, but inaccurate/unvalidated destinations mean the artifact cannot prove where work landed. |

Every requirement declared by every Phase 235 PLAN (`FAST-01`, `GATE-05`) is mapped in REQUIREMENTS.md to Phase 235. No orphaned phase requirement was found. No later milestone phase exists to defer these gaps to.

### Review Findings Re-evaluated

| Finding | Verdict | Effect |
| --- | --- | --- |
| CR-01: capture endpoint can move | Confirmed BLOCKER | In scope of Plan 04's immutable-run-population must-have; invalidates run-data proof. |
| CR-02: retained run identities not real/bound | Confirmed BLOCKER | In scope; ledger cannot be traced to GitHub executions. |
| CR-03: binding-pole receipt is unbound | Confirmed BLOCKER | In scope; the required miss diagnosis can be fabricated. |
| WR-01: arbitrary ownership semantics | Confirmed BLOCKER | Although classified Warning by review, it fails a must-have and has an observed `ci_gate`/`ci-gate` contradiction. |
| WR-02: closeout ignores supplied contributor record | Confirmed WARNING | The separate topology test verifies current CONTRIBUTING, but closeout does not itself compose that validation; harden it with a contradiction mutation. |

The three critical findings are not advisory hardening: Plan 04 explicitly promised immutable evidence, a fail-closed ownership contract, and workflow-related topology. They therefore block goal achievement. WR-02 is advisory only; WR-01 is escalated because it produces an observable inaccurate ownership row.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | 554-705 | Endpoint/population hash unused; self-derived run receipts | 🛑 BLOCKER | A coherent forged population can pass. |
| `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | 741-750 | Minimal binding-pole receipt validation | 🛑 BLOCKER | A fabricated diagnosis can pass. |
| `235-TERMINAL-RATIFICATION.json` | `ci_gate_aggregate` rows | `ci_gate` instead of workflow job `ci-gate` | 🛑 BLOCKER | Maintainer is shown an incorrect destination. |
| `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | 765 | `_contributing` ignored by closeout validator | ⚠️ Warning | Closeout composition is weaker than claimed. |

No Phase 235-created file contains an unreferenced `TBD`, `FIXME`, or `XXX` debt marker.

### Gaps Summary

Plan 04 repaired the original internal integrity defects: it recomputes ledger statistics, checks canonical digest bytes, closes the exact ownership key set, and semantically checks the present contributor wording. That is real progress, but it does not make the milestone headline claims proven from run data.

The external evidence boundary remains forgeable, and the ownership artifact currently names a job that does not exist. These are implementation gaps, not human-UAT questions. This is an **Escalation Gate**: a corrective closure plan must bind raw GitHub evidence and each ownership mapping, while preserving the honest 772-second FAST-01 miss.

---

_Verified: 2026-08-02T19:12:46Z_
_Verifier: the agent (gsd-verifier)_
