---
phase: 236-closeout-evidence-reconciliation
reviewed: 2026-08-04T16:06:45Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs
findings:
  critical: 2
  warning: 1
  info: 0
  total: 3
status: issues_found
---

# Phase 236: Code Review Report

**Reviewed:** 2026-08-04T16:06:45Z
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

The focused contract passes and its immutable-evidence digest fence is effective for the current files. However, the ownership and three-source checks do not fail closed against several metadata tampering cases that Phase 236 explicitly requires them to reject.

## Critical Issues

### CR-01: Duplicate completion fields bypass exact SUMMARY ownership

**File:** `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs:145-156`
**Issue:** `Regex.run/3` returns only the first `requirements-completed` field in a SUMMARY frontmatter block. Appending a second field with an extra or wrong ID leaves the first valid field intact, so the contract passes despite ambiguous or altered YAML metadata. This violates the required fail-closed rejection of extra completion IDs and wrong ownership.
**Fix:** Use `Regex.scan/3` and require exactly one matching field before parsing it; add an adverse test that appends a second `requirements-completed` line and asserts failure.

### CR-02: Ownership validation ignores declarations in every non-target SUMMARY

**File:** `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs:5-14,129-140`
**Issue:** The contract reads only three hand-picked SUMMARY files. A `GATE-01`, `GATE-04`, `TEST-02`, or `TEST-03` declaration added to any other Phase 231 or 233 SUMMARY is never inspected, so duplicate or wrong-owner declarations pass. The plan and pattern explicitly say not to add these IDs to other summaries.
**Fix:** Load all applicable Phase 231/233 SUMMARY frontmatter, build an inverted ID-to-owner map for the four reconciled IDs, and assert it exactly equals the approved ownership map. Include a mutation that adds one target ID to a non-owner SUMMARY.

## Warnings

### WR-01: Three-source contract check does not bind deterministic contracts to each requirement

**File:** `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs:212-225`
**Issue:** Every reconciled ID passes the deterministic-contract source merely when both unrelated file paths exist. The code neither identifies the owning contract per ID nor asserts that the contract covers that ID; likewise, the verification test pairs any `| ID |` occurrence with any separate `✓ SATISFIED` occurrence. This weakens the claimed per-requirement three-source validation.
**Fix:** Declare an explicit ID-to-contract and ID-to-verification-row mapping, then validate the exact row (including `✓ SATISFIED`) and the matching contract's ID-level assertion or test name for each reconciled requirement.

---

_Reviewed: 2026-08-04T16:06:45Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_

## UI REVIEW COMPLETE
