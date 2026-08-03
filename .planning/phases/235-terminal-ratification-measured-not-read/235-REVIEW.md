---
phase: 235-terminal-ratification-measured-not-read
reviewed: 2026-08-03T20:38:50Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - .github/workflows/fast-01-remeasurement-evidence.yml
  - .github/workflows/terminal-ratification-evidence.yml
  - scripts/ci/capture-fast-01-remeasurement.sh
  - scripts/ci/capture-fast-01-remeasurement.test.sh
  - scripts/ci/capture-terminal-ratification-evidence.sh
  - scripts/ci/capture-terminal-ratification-evidence.test.sh
  - scripts/ci/verify-fast-01-remeasurement-attestation-offline.sh
  - scripts/ci/verify-terminal-ratification-attestation-offline.sh
  - test/sigra/planning/phase_235_fast_01_remeasurement_contract_test.exs
  - test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
findings:
  critical: 2
  warning: 0
  info: 0
  total: 2
status: issues_found
---

# Phase 235: Code Review Report

**Reviewed:** 2026-08-03T20:38:50Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

The evidence collectors, provenance verifiers, and their contract tests were reviewed. Two fail-closed guarantees are incomplete: malformed skipped-job chronology can enter an attested receipt, and the event-guard contract can certify a job that is actually excluded from an event.

## Narrative Findings (AI reviewer)

## Blockers

### BL-01: Skipped jobs with inverted timestamps are accepted into the attested receipt

**File:** `scripts/ci/capture-terminal-ratification-evidence.sh:131`

**Issue:** The skipped-job branch accepts any string `started_at` and `completed_at` without checking their order. Therefore, a response containing `completed_at` before `started_at` passes validation and is emitted into the provenance-attested receipt. The collector test deliberately supplies and accepts this impossible state at `scripts/ci/capture-terminal-ratification-evidence.test.sh:61,86`, so the regression is protected rather than detected. This undermines the receipt's claim to retain chronologically valid job evidence.

**Fix:** If a skipped job supplies both timestamps, parse and require `completed_at >= started_at`; otherwise require both values to be null (or explicitly define and validate the supported partial-null form). Add a test that the inverted skipped-job fixture fails.

### BL-02: Event-guard validation treats exclusion conditions as executable

**File:** `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs:981-1004`

**Issue:** `event_condition_allows?/2` only extracts `github.event_name == ...` predicates. A guard such as `github.event_name != 'pull_request'` yields no predicates and returns `true`, so `validate_ownership_semantics!/2` will certify the job as executable for a pull-request ownership row even though GitHub skips it. This lets a protected ownership regression pass the phase contract test.

**Fix:** Replace the heuristic with a deliberately limited parser/evaluator that handles both `==` and `!=` predicates (and `&&`/`||`), failing closed for unsupported expressions. Add a mutation test that inserts `if: github.event_name != 'pull_request'` into an executed direct owner and asserts rejection.

---

_Reviewed: 2026-08-03T20:38:50Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
