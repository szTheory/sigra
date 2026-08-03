---
phase: 235
fixed_at: 2026-08-03T20:47:10Z
review_path: .planning/phases/235-terminal-ratification-measured-not-read/235-REVIEW.md
iteration: 2
findings_in_scope: 3
fixed: 2
skipped: 1
status: partial
---

# Phase 235: Code Review Fix Report

**Fixed at:** 2026-08-03T20:47:10Z
**Source review:** `.planning/phases/235-terminal-ratification-measured-not-read/235-REVIEW.md`
**Iteration:** 2

**Summary:**

- Findings in scope: 3
- Fixed: 2
- Skipped: 1

## Fixed Issues

### BL-01: Skipped jobs with inverted timestamps are accepted into the attested receipt

**Files modified:** `scripts/ci/capture-terminal-ratification-evidence.sh`, `scripts/ci/capture-terminal-ratification-evidence.test.sh`
**Commit:** 4d070d62
**Applied fix:** Skipped jobs must now have both timestamps null or both valid strings in chronological order. The collector contract includes an inverted skipped-job fixture that must fail.
**Verification:** `bash -n` passed for the collector and its test; `bash scripts/ci/capture-terminal-ratification-evidence.test.sh` passed.

### BL-02: Event-guard validation treats exclusion conditions as executable

**Files modified:** `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs`
**Commit:** 9ab0e7a2
**Applied fix:** Replaced the positive-match heuristic with a limited evaluator for `==`/`!=` event predicates and `&&`/`||`, rejecting unsupported atoms. Added a mutation test for a direct owner excluded from `pull_request`.
**Verification:** Elixir parsed the contract successfully with `Code.string_to_quoted!/1`. The focused ExUnit contract could not run because this worktree has no declared Mix dependencies; it requires human verification after dependencies are restored.

## Skipped Issues

### WR-01: FAST-01 retained-attestation verifier is never run

**File:** `scripts/ci/verify-fast-01-remeasurement-attestation-offline.sh:85`
**Reason:** Deferred: Phase 235 Plan 10 decision D-08 explicitly forbids altering `ci.yml`, adding a new gate, or changing CI topology during measured reconciliation.
**Original issue:** The retained FAST-01 provenance verifier is not invoked by repository automation, so regressions to its receipt, trust-root, signer, source-ref, or network-isolation checks can land undetected.
**Recommended future action:** Add a required CI step, alongside the terminal provenance verification, to run `bash scripts/ci/verify-fast-01-remeasurement-attestation-offline.sh`. Add a hermetic PATH-shadowing/runtime self-test for that verifier as well, so CI proves it rejects an untrusted `gh` executable before running the retained-evidence check.

---

_Fixed: 2026-08-03T20:47:10Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 2_
