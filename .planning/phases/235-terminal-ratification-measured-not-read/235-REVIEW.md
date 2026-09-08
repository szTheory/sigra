---
phase: 235-terminal-ratification-measured-not-read
reviewed: 2026-09-08T20:34:59Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh
  - test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---

# Phase 235: Code Review Report

**Reviewed:** 2026-09-08T20:34:59Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Re-review of commit `9a5ced28` confirms that CR-01, CR-03, and WR-01 are resolved: the retained trust root is digest-pinned, population mutations now invoke the population validator directly, and the independent helper accepts all supported terminal conclusions without requiring a failure. The exact retained subject verifies and all 8 focused ExUnit tests pass.

CR-02 remains a ship blocker. The actual signed receipt contains only `run_id`, `wall_seconds`, `conclusion`, and `url` per run and has no pagination manifest, timestamps, or exhaustion proof, so the offline verifier still cannot independently establish population completeness, window membership, chronology, or queue-inclusive wall durations. WR-02 also remains: exact-line occurrence counts are stronger than substring checks but do not prove the GATE-05 material is byte-identical or rule out an additional contradictory record.

## Narrative Findings (AI reviewer)

### Critical Issues

### CR-02: Signed evidence cannot support the required independent population recomputation

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh:177-210`

**Issue:** The verifier authenticates the exact retained subject and recomputes its median, but the subject does not contain the evidence needed to independently derive that population. Its top-level keys have no requested-page list or exhaustion marker, and each run contains only `run_id`, `wall_seconds`, `conclusion`, and `url`; `created_at` and `updated_at` were discarded before attestation. Therefore lines 199-209 can validate only producer-supplied values. They cannot prove that all eligible API pages were included, that every run started within the closed cutoff/endpoint interval, that `updated_at >= created_at`, or that each queue-inclusive `wall_seconds` value equals `updated_at - created_at`. The ExUnit helper at lines 291-359 has the same evidence ceiling.

This is not cured by the successful Sigstore check: provenance shows that the fixed protected workflow signed these bytes, while the plan separately requires the offline verifier and test to independently validate complete pagination, chronology, fixed bounds, and duration recomputation. The current receipt makes that required second proof impossible.

**Fix:** Produce and attest a new receipt that retains `created_at` and `updated_at` for every run plus sufficient page-manifest evidence (`requested_pages`, page identities/counts, and an authenticated terminal exhaustion marker), or attest the raw page manifest alongside the derived receipt. The offline verifier and ExUnit helper must derive membership and `wall_seconds` from those signed source fields before sorting and computing p50. Because those facts are absent from the existing signed subject, source-only validator changes cannot remediate this finding.

### Warnings

### WR-02: GATE-05 “byte-exact” non-regression remains weaker than its claim

**Classification:** WARNING

**File:** `/Users/jon/projects/sigra/test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs:222-242`

**Issue:** Commit `9a5ced28` now requires the two expected GATE-05 lines to occur exactly once, which prevents duplicate copies of those exact strings. It still does not compare the GATE-05 material with baseline bytes or a pinned digest. An additional contradictory GATE-05 checkbox/traceability row, or a change to other GATE-05 provenance text, can coexist with the two expected lines and leave this test green. The test therefore does not establish its named or planned byte-exact non-regression guarantee.

**Fix:** Extract the complete canonical GATE-05 block and compare it byte-for-byte with a pinned fixture/digest, or assert that these are the only GATE-05 checkbox and traceability records and separately pin all associated provenance text covered by the immutability requirement.

---

_Reviewed: 2026-09-08T20:34:59Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
