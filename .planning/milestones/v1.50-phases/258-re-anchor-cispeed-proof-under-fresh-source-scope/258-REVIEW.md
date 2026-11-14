---
phase: 258-re-anchor-cispeed-proof-under-fresh-source-scope
reviewed: 2026-11-08T18:16:48Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - scripts/ci/ci_metrics_security.py
  - scripts/ci/ci-repaired-comparison.py
  - scripts/ci/ci-repaired-comparison.test.py
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
  necessity: 0
status: issues_found
---

# Phase 258: Code Review Report

**Reviewed:** 2026-11-08T18:16:48Z  
**Depth:** standard  
**Files Reviewed:** 3  
**Status:** issues_found

## Summary

Reviewed the Task1 changes against the three preserved pre-edit files. Their original hashes and sizes match `PRE-EDIT-BASELINE.json`. The new terminal verifier checks receipt hashes and numeric spend caps, but it does not check the current attempt's request times against the authorized windows or fixed deadline. It can accept an out-of-window attempt as valid. This does not invalidate the already generated proposal or its source binding; it makes terminal-verifier results untrustworthy until corrected. The previous terminal-reader body is also unreachable after the new return.

## Critical Issues

### CR-01: BLOCKER — Terminal verification accepts requests outside the authorized time window

**File:** `scripts/ci/ci-repaired-comparison.py:6249-6370, 6380-6420, 6777-6785`
**Classification:** BLOCKER
**Issue:** The new invoked-attempt verification path validates the ledger hash chain and recomputes request, mutation, workload, and runner totals, then checks numeric caps. It never parses the current attempt's `at_utc` values or checks `phase258_budget.first_request_reserved_at_utc`, the 45-minute preparation deadline, `outer.reserved_at_utc`, or the fixed phase deadline. The time checks added elsewhere in this delta apply only to the prior Recovery08 reconciliation. As a result, a hash-bound current ledger with requests outside its authorized window can still produce `terminal_receipts_valid` and a derived terminal classification, including `pass`.
**Fix:** In terminal verification, validate the current ledger's reservation/start/deadline fields and every request timestamp against the preparation and measurement windows and the fixed deadline. Also bind the outer receipt's reservation time and timeout to those same values before returning a valid terminal status.

## Warnings

### WR-01: WARNING — Previous terminal verifier remains unreachable

**File:** `scripts/ci/ci-repaired-comparison.py:6779-6915`
**Classification:** WARNING
**Issue:** The new verifier returns at line 6779. The prior stage-outer verifier below it is therefore unreachable, despite retaining a second classification and spend-validation implementation in the production module. This leaves two competing implementations visible to maintainers, while only the earlier branch can affect results.
**Fix:** Remove the unreachable historical implementation from the production module or move it into a clearly named historical fixture/document so it cannot be mistaken for active verification logic.

---

_Reviewed: 2026-11-08T18:16:48Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
