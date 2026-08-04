---
phase: 236-closeout-evidence-reconciliation
verified: 2026-08-04T20:26:14Z
status: gaps_found
score: 8/9 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 7/9
  gaps_closed:
    - "D-05 historical audit verification binds caller-supplied documents to the exact committed input and output snapshot blobs."
    - "The stale Plan 06 baseline is replaced with the finalized ancestor boundary 4aaa3a73 through b6c67ed9."
  gaps_remaining:
    - "The committed-range scope fence uses endpoint-tree diffing and therefore cannot reject a forbidden path changed and restored within either execution range."
  regressions: []
gaps:
  - truth: "One identical allowlist governs the two committed execution ranges, tracked staged/unstaged changes, and untracked non-ignored paths; every other path is rejected."
    status: failed
    reason: "changed_paths_between!/2 calls `git diff --name-only from..to`, which reports only net endpoint tree differences. A non-allowlisted file modified in an intermediate commit and restored before `to` is absent from that collection, so the asserted range can pass without rejecting every forbidden path."
    artifacts:
      - path: "test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs"
        issue: "Lines 375 and 389 consume endpoint-only range results; line 640 implements the collection with `git diff --name-only` rather than the union of each commit's changed paths."
    missing:
      - "Collect and deduplicate per-commit paths (for example, enumerate `git rev-list from..to` and run `git diff-tree --no-commit-id --name-only -r` for each commit), fail on any Git collection error, and compare that union with the existing allowlist."
      - "Add an adversarial fixture or pure helper test where a forbidden path is changed then restored between valid endpoints; the scope fence must fail."
---

# Phase 236: Closeout Evidence Reconciliation Verification Report

**Phase Goal:** Reconcile the four audited SUMMARY declarations and eight stale traceability rows, canonically validate Phases 230/231/232/234, and produce a fresh v1.47 audit without changing product, CI topology, or retained runtime evidence.
**Verified:** 2026-08-04T20:26:14Z
**Status:** gaps_found
**Re-verification:** Yes — after Plan 07 gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | D-01 has exactly the four authorized SUMMARY completion declarations. | ✓ VERIFIED | The focused contract passed and its ownership map requires GATE-01 → 231-11, GATE-04 → 231-06, and TEST-02/03 → 233-05; hostile wrong-owner, extra-ID, duplicate-field, and non-owner mutations are asserted. |
| 2 | D-02 reconciles exactly TEST-01..03 and DX-01..04/DX-06 in the 24-row traceability map. | ✓ VERIFIED | The contract passed its exact ownership/status map and three-source assertions; no Phase 236 requirement IDs were invented. |
| 3 | D-03 lifecycle evidence for 230/231/232/234 is canonical, ordered, and replayable from Git. | ✓ VERIFIED | The contract passed eight tests and recomputes the retained mixed 231 boundary plus isolated 232/234 validator parent, scope, lifecycle, and retained-body checks. |
| 4 | D-04 protected verification, compliant validation, receipts, attestation, audit, and retained evidence preserve the asserted bytes. | ✓ VERIFIED | The contract passed; current SHA-256 values for all six 230–235 VERIFICATION artifacts equal the pinned digests. |
| 5 | The fresh audit reports 24/24 requirements, 6/6 phases, 8/8 integrations, 7/7 flows, Nyquist compliant, and empty blocker arrays. | ✓ VERIFIED | The committed audit/output snapshot is parsed by the passing contract; `historical-verify` independently completed against the fixed 22dfd088/a523575d boundary. |
| 6 | D-05 audit provenance is bound to the committed historical input/output snapshot blobs. | ✓ VERIFIED | `historical_verify!/4` resolves exact full SHAs, reads both blobs with `git show`, byte-compares them with supplied files before decoding, and the standalone suite's wholly forged self-consistent pair is rejected. |
| 7 | The obsolete Plan 06 scope baseline no longer controls the evidence boundary. | ✓ VERIFIED | The contract asserts the ancestor chain from `4aaa3a73` to `b6c67ed9`; the actual endpoint range contains only the four Plan 06 allowlisted paths. |
| 8 | No product, CI-topology, required-check, or retained-runtime-evidence expansion occurred in the final Plan 06/07 execution ranges. | ✓ VERIFIED | Per-commit union inspection of the actual Plan 06 and Plan 07 ranges lists only the two snapshot scripts, the Phase 236 contract test, and the two permitted summaries. |
| 9 | Every non-allowlisted path is rejected across committed execution ranges as the identical allowlist claims. | ✗ FAILED | The contract checks endpoint tree differences only, not all per-commit changes. A transient forbidden mutation can evade the boundary. |

**Score:** 8/9 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` | Fail-closed ownership, traceability, preservation, lifecycle, provenance, and scope contract | ⚠️ PARTIAL | Substantive, wired, and its eight tests pass; its committed-range collection is insufficient for the all-paths scope truth. |
| `scripts/planning/phase-236-audit-snapshot.exs` | Historical verifier bound to exact committed input/output blobs | ✓ VERIFIED | Lines 57–70 pin both SHAs, load fixed blobs, and compare caller bytes before JSON handling. |
| `scripts/planning/phase-236-audit-snapshot-test.exs` | Forged replacement-pair regression | ✓ VERIFIED | Lines 117–145 build a wholly self-consistent reduced pair and assert historical verification fails. |
| `236-AUDIT-INPUT-SNAPSHOT.json` and `236-AUDIT-OUTPUT-SNAPSHOT.json` | Committed source/output audit boundary | ✓ VERIFIED | Positive `historical-verify` completed successfully and validates the fixed Git blobs, manifest linkage, and audit digest. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Historical verifier | Fixed input/output snapshots | `git show` followed by byte equality before decode | ✓ WIRED | Proven by direct source inspection and forged-pair test. |
| Validation replay ledger | 230/231/232/234 Git lifecycle evidence | Direct-parent, diff-tree, blob, and lifecycle assertions | ✓ WIRED | Exercised by the focused Phase 236 contract. |
| Plan 06/07 committed ranges | Identical scope allowlist | `changed_paths_between!/2` | ✗ NOT FAIL-CLOSED | Endpoint-only `git diff --name-only` misses transient changed-and-restored paths. |
| Current worktree | Identical scope allowlist | tracked and untracked collectors | ✓ WIRED | Current worktree was clean; collectors are explicit and share `@scope_allowlist`. |

### Data-Flow Trace (Level 4)

Not applicable: these are repository-evidence contracts rather than dynamic data-rendering artifacts.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Full reconciliation/replay/provenance contract | `MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` | 8 tests, 0 failures | ✓ PASS |
| Historical fixed-blob boundary | `elixir scripts/planning/phase-236-audit-snapshot.exs historical-verify … 22dfd088… a523575d…` | `historical audit boundary verified e25714…` | ✓ PASS |
| Snapshot suite, including forged pair | `elixir scripts/planning/phase-236-audit-snapshot-test.exs` | 3 tests, 0 failures | ✓ PASS |
| Formatting and whitespace | `mix format --check-formatted …` and `git diff --check` | exit 0 | ✓ PASS |
| Committed range rejects every forbidden path | Source inspection of `changed_paths_between!/2` | endpoint-only diff cannot observe a restored intermediate mutation | ✗ FAIL |

### Probe Execution

SKIPPED — Phase 236 has no mapped requirement IDs or probe predicate; none was fabricated.

### Requirements Coverage

Phase 236 declares `requirements: []` in every plan, and ROADMAP/REQUIREMENTS map no requirement ID to it. This is an evidence-closeout phase; no IDs or probes were fabricated.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` | 375, 389, 640 | Endpoint-only range diff used as an all-changes scope fence | 🛑 BLOCKER | A forbidden path can be modified and restored inside a range without being rejected. |

### Gaps Summary

Plan 07 correctly closed the previous fixed-blob provenance and stale-baseline gaps. The remaining scope issue is not an old REVIEW finding: current code at `changed_paths_between!/2` still uses `git diff --name-only from..to`. That command proves only the difference between endpoint trees, while the Plan 07 must-have requires rejection of every non-allowlisted path changed during the execution range.

The actual Plan 06/07 histories contain only allowed paths when inspected commit-by-commit, but a fail-closed boundary must detect the prohibited case, not merely pass the current benign history. Replace the collector with a fail-closed per-commit path union and add a changed-then-restored adversarial regression before re-verification. No later milestone phase specifically defers this boundary repair, so it remains a blocking escalation-gate item.

---

_Verified: 2026-08-04T20:26:14Z_
_Verifier: the agent (gsd-verifier)_
