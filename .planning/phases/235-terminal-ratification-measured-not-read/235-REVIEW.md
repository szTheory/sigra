---
phase: 235-terminal-ratification-measured-not-read
reviewed: 2026-09-08T20:55:10Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh
  - test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 235: Code Review Report

**Reviewed:** 2026-09-08T20:55:10Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Final re-review after commits `5c5910fa` and `4f869877` leaves one genuinely open finding. WR-02 is resolved: the contract requires exactly one GATE-05 checkbox and traceability row, pins SHA-256 for all four retained GATE-05 evidence files and the terminal-ratification offline verifier, and every current digest matches. Earlier CR-01, CR-03, and WR-01 fixes also remain present.

Both offline attestation verifiers succeed and the focused ExUnit file passes all 8 tests. Commit `4f869877` correctly stops treating the 43-row candidate as closure evidence and leaves FAST-01 open. CR-02 nevertheless remains because the existing signed subject still lacks the source rows and pagination evidence required to independently prove the candidate population and its wall durations.

## Narrative Findings (AI reviewer)

### Critical Issues

### CR-02: Signed evidence cannot support the required independent population recomputation

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh:177-210`

**Issue:** The verifier authenticates the exact retained subject and recomputes a median from its stored values, but the signed subject does not contain the evidence needed to independently derive those values. Its top-level keys contain no requested-page list or exhaustion marker, and every run contains only `run_id`, `wall_seconds`, `conclusion`, and `url`; the producer discarded `created_at` and `updated_at` before attestation. The offline checks therefore cannot establish that all eligible API pages were included, that every run started within the closed cutoff/endpoint interval, that chronology is valid, or that queue-inclusive `wall_seconds` equals `updated_at - created_at`. The ExUnit helper at lines 309-377 has the same evidence ceiling.

Commit `4f869877` resolves the resulting status contradiction by retaining FAST-01 as Gaps Found and documenting why this candidate cannot close it. That honest reconciliation prevents unsupported completion but does not satisfy the phase plan's required independently authenticated population or supply the missing evidence.

**Fix:** Capture and attest a new receipt that retains `created_at` and `updated_at` for every run plus sufficient page-manifest evidence (`requested_pages`, page identities/counts, and an authenticated terminal exhaustion marker), or attest the raw API page manifest alongside the derived receipt. Derive membership and each `wall_seconds` value from those signed source fields in both the offline verifier and ExUnit contract before sorting and calculating p50. The current signed subject cannot be retrofitted with these facts without new protected evidence.

---

_Reviewed: 2026-09-08T20:55:10Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
