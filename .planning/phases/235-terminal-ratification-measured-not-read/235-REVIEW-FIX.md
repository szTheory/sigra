---
phase: 235
fixed_at: 2026-08-03T14:20:00Z
review_path: /Users/jon/projects/sigra/.planning/phases/235-terminal-ratification-measured-not-read/235-REVIEW.md
iteration: 3
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 235: Code Review Fix Report

**Fixed at:** 2026-08-03T14:20:00Z
**Source review:** `/Users/jon/projects/sigra/.planning/phases/235-terminal-ratification-measured-not-read/235-REVIEW.md`
**Iteration:** 3

**Summary:**

- Findings in scope: 2
- Fixed: 2
- Skipped: 0

## Fixed Issues

### CR-01: Fixed run allowlist rejects the actual retained population

**Files modified:** `scripts/ci/capture-terminal-ratification-evidence.sh`, `scripts/ci/capture-terminal-ratification-evidence.test.sh`
**Commit:** `33874623`
**Status:** fixed and machine-verified
**Applied fix:** The collector now validates the exact 24 fetched workflow-run IDs, retains `30723701267` in the canonical receipt, and explicitly excludes only that terminal-ratification `workflow_dispatch` run from the exact 23-run measurement/job universe. The hermetic regression fixture proves both exact populations and that no jobs manifest is retrieved for the excluded run.
**Verification:** `bash -n`, `git diff --check`, and `scripts/ci/capture-terminal-ratification-evidence.test.sh` passed.

### CR-02: Attested receipt is not cryptographically or semantically bound to the ledger being ratified

**Files modified:** `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs`
**Commit:** `bd5e868a`
**Status:** fixed and machine-verified
**Applied fix:** The contract now hashes the protected receipt against `protected_provenance.subject_sha256`, normalizes all protected `pull_request`, `push`, and `schedule` run fields, requires exact equality with every ledger measurement run, and requires complete two-page job manifests for every measured run. Mutation regressions reject altered protected run fields and incomplete jobs manifests.
**Verification:** `elixir` parse check, direct protected-versus-ledger normalized-population comparison, `git diff --check`, and `scripts/ci/verify-terminal-ratification-attestation-offline.sh` passed. The orchestrator ran the focused Phase 235 suite in the primary worktree: 20 tests, 0 failures.

## Closure Remediations

- `3c553f0d` and `44838c03` wire the retained offline proof and PATH-shadow self-test into the required `fast_checks` CI lane.
- `d0133045` pins the attested producer workflow SHA in the offline policy and ledger contract.
- The final targeted review reports `status: clean` with 0 critical, warning, or informational findings.

---

_Fixed: 2026-08-03T14:20:00Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 3_
