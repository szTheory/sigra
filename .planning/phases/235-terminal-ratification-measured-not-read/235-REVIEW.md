---
phase: 235-terminal-ratification-measured-not-read
reviewed: 2026-08-03T20:46:10Z
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
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Phase 235: Code Review Report

**Reviewed:** 2026-08-03T20:46:10Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

The BL-01 fix is effective: the terminal collector rejects skipped jobs unless both timestamps are null or both are chronological timestamps. The BL-02 fix is also effective: the condition evaluator correctly rejects a direct job guarded away from `pull_request` rather than treating `!=` as executable. The supplied collector tests and both focused ExUnit contract files pass.

One provenance verifier remains unreachable from repository automation: no workflow invokes the FAST-01 offline verifier. Consequently, later breakage of its receipt, trust-root, signer, source-ref, or network-isolation checks can land without any required check detecting it.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: FAST-01 retained-attestation verifier is never run

**File:** `scripts/ci/verify-fast-01-remeasurement-attestation-offline.sh:85`
**Issue:** This verifier contains the only offline positive and adversarial validation of the retained FAST-01 provenance, but no workflow in `.github/workflows/` invokes it (nor is there a self-test equivalent to the terminal verifier's required-`fast_checks` invocation). The manual evidence workflow only creates and attests a subject. Its successful completion therefore does not prove that the retained bundle, trusted root, expected digest, signer workflow, and main-ref policy are still independently verifiable. A regression in this script or its retained inputs will remain undetected until someone runs it manually.
**Fix:** Add a required CI step, alongside the terminal provenance verification, to run `bash scripts/ci/verify-fast-01-remeasurement-attestation-offline.sh`. Add a hermetic PATH-shadowing/runtime self-test for that verifier as well, so CI proves it rejects an untrusted `gh` executable before running the retained-evidence check.

---

_Reviewed: 2026-08-03T20:46:10Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
