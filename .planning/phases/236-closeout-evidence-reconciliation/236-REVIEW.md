---
phase: 236-closeout-evidence-reconciliation
reviewed: 2026-08-04T19:38:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs
  - scripts/planning/phase-236-audit-snapshot.exs
  - scripts/planning/phase-236-audit-snapshot-test.exs
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 236: Code Review Report

**Reviewed:** 2026-08-04T19:38:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

The Phase 236 contract and snapshot tests execute successfully (7 and 3 tests respectively), but the new historical verifier does not bind its supplied JSON documents to the Git objects it claims to authenticate. Consequently, a caller can forge a self-consistent input/output pair that the verifier accepts for the recorded commits, so it cannot serve as a trustworthy historical audit boundary.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Historical verifier trusts uncommitted caller-supplied snapshot documents

**File:** `scripts/planning/phase-236-audit-snapshot.exs:53-62, 85-119`

**Issue:** `historical_verify!/4` reads both `input_path` and `output_path` directly from caller-controlled paths, then only proves that each document is internally self-consistent. It never reads or byte-compares the input snapshot committed at `freeze_commit` nor the output snapshot committed at `audit_commit`. An attacker can therefore supply an input with an empty (or selectively reduced) `files` list, a correctly recomputed `manifest_sha256`, the required claim-limit text, and an empty resolver list; they can pair it with an output that repeats that manifest hash and the real audit blob digest. The ancestry and commit-scope assertions still pass, as do all subsequent checks, while the verifier has skipped the historical source evidence it is supposed to establish. The existing adversarial test only mutates fields in copies of the real documents and misses this replacement attack.

**Fix:** Make the verifier derive both documents from fixed repository paths and the supplied, resolved commits, for example `git_show!(freeze_commit, @input_snapshot_path)` and `git_show!(audit_commit, @output_snapshot_path)`. If file arguments must remain for a diagnostic mode, byte-compare them to those Git objects before decoding and reject any mismatch. Add a test that passes a fully forged but internally valid manifest/output pair (including `files: []`) and asserts that verification fails.

---

_Reviewed: 2026-08-04T19:38:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
