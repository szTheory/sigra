---
phase: 235-terminal-ratification-measured-not-read
reviewed: 2026-08-03T04:06:17Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - .github/workflows/terminal-ratification-evidence.yml
  - CONTRIBUTING.md
  - scripts/ci/capture-terminal-ratification-evidence.sh
  - scripts/ci/capture-terminal-ratification-evidence.test.sh
  - scripts/ci/verify-terminal-ratification-attestation-offline.sh
  - test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
findings:
  critical: 2
  warning: 0
  info: 0
  total: 2
status: issues_found
---

# Phase 235: Code Review Report

**Reviewed:** 2026-08-03T04:06:17Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

The workflow and offline verifier use appropriately scoped permissions, pinned actions, and an offline verification path. However, the collector can attest an incomplete or unrelated workflow-run population, and the contract validator silently converts inverted run timestamps into zero-duration runs. Both defects invalidate the evidence this phase is meant to protect.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Attested receipt is not bound to the fixed run population

**File:** `scripts/ci/capture-terminal-ratification-evidence.sh:77-99`
**Issue:** The script fetches all workflow-run pages but never compares their IDs to `RUN_IDS`. It independently fetches jobs for the hard-coded IDs, so a response that omits one or more expected runs (or returns a different set) still produces a successful, attestable receipt. The fixture demonstrates this disconnect: it returns workflow-run IDs `1` and `2` while the collector still accepts it and retrieves jobs for all 23 fixed IDs. Thus the provenance attestation can certify a receipt whose claimed workflow population is incomplete or unrelated to its job data.
**Fix:** After validating the runs manifest, flatten `workflow_runs[].id` and require its set (and count) to exactly match `RUN_IDS` before collecting jobs. Derive the job collection IDs from that validated set, or reject any mismatch. Add negative tests for a missing expected ID and an unexpected ID.

### CR-02: Inverted workflow-run timestamps are accepted as zero-duration measurements

**File:** `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs:1378-1395`
**Issue:** `validate_window_bounds!/4` parses both timestamps and checks only the outer window. It never rejects `updated_at < created_at`; `recompute_statistics!/2` then applies `max(DateTime.diff(...), 0)` (lines 1353-1356), converting an invalid negative duration to zero. The source receipt validation also does not impose chronological order (lines 944-966), so a correspondingly altered ledger can pass the contract with fabricated zero-second run durations.
**Fix:** Reject inversions before recomputing statistics, and add a mutation test:

```elixir
if DateTime.compare(updated_at, created_at) == :lt,
  do: raise(ArgumentError, "inverted run timestamps")
```

Apply the same parsed-timestamp validation to source-receipt entries rather than relying on lexical string ordering.

---

_Reviewed: 2026-08-03T04:06:17Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
