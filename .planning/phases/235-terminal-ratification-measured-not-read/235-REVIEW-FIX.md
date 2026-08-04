---
phase: 235
fixed_at: 2026-08-04T00:46:00Z
review_path: /Users/jon/projects/sigra/.planning/phases/235-terminal-ratification-measured-not-read/235-REVIEW.md
iteration: 2
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 235: Code Review Fix Report

**Fixed at:** 2026-08-04T00:46:00Z
**Source review:** `/Users/jon/projects/sigra/.planning/phases/235-terminal-ratification-measured-not-read/235-REVIEW.md`
**Iteration:** 2

**Summary:**

- Findings in scope: 4
- Fixed: 4
- Skipped: 0

## Fixed Issues

### CR-01: Fresh-window evidence workflow cannot satisfy its collector's Git-history checks

**Files modified:** `.github/workflows/fast-01-remeasurement-evidence.yml`, `test/sigra/planning/phase_235_fast_01_remeasurement_contract_test.exs`
**Commit:** `8160a8a8`
**Applied fix:** Configured checkout with full Git history and locked the requirement in the workflow contract test.

### CR-02: Gap-closure collector treats an empty remediation digest map as validated evidence

**Files modified:** `scripts/ci/capture-fast-01-gap-closure.sh`, `scripts/ci/capture-fast-01-gap-closure.test.sh`, `test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs`
**Commit:** `6b8fe46f`
**Applied fix:** Pinned the remediation receipt bytes and rejected digest maps unless they contain the exact expected paths and SHA-256 values.

### CR-03: Terminal offline verifier's fallback isolation can be replaced through PATH

**Files modified:** `scripts/ci/verify-terminal-ratification-attestation-offline.sh`, `scripts/ci/verify-terminal-ratification-attestation-offline.test.sh`, `test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs`
**Commit:** `f33b3645`
**Applied fix:** Replaced PATH-based sudo resolution with the trusted `/usr/bin/sudo` path, added matching cleanup, and covered a shadowed-sudo path.

### CR-01 (iteration 2): Offline verifiers execute a PATH-controlled `mktemp` before isolation

**Files modified:** `scripts/ci/verify-fast-01-remeasurement-attestation-offline.sh`, `scripts/ci/verify-terminal-ratification-attestation-offline.sh`, `scripts/ci/verify-fast-01-remeasurement-attestation-offline.test.sh`, `scripts/ci/verify-terminal-ratification-attestation-offline.test.sh`
**Commit:** `498bd264`
**Applied fix:** Removed PATH-based `realpath` resolution, choose `/usr/bin/mktemp` or `/bin/mktemp` only, fail closed when neither exists, and use absolute system paths for setup and cleanup commands. Both verifier self-tests prepend a malicious `mktemp` and prove it is never executed.
**Verification:** `bash -n` and both runtime self-tests passed. The scoped ExUnit command could not start because required Mix dependencies are absent in this isolated worktree.

---

_Fixed: 2026-08-04T00:46:00Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 2_
