---
phase: 235-terminal-ratification-measured-not-read
reviewed: 2026-08-03T22:11:30Z
depth: standard
files_reviewed: 18
files_reviewed_list:
  - .github/workflows/fast-01-gap-closure-evidence.yml
  - .github/workflows/fast-01-remeasurement-evidence.yml
  - .github/workflows/terminal-ratification-evidence.yml
  - scripts/ci/capture-fast-01-gap-closure.sh
  - scripts/ci/capture-fast-01-gap-closure.test.sh
  - scripts/ci/capture-fast-01-remeasurement.sh
  - scripts/ci/capture-fast-01-remeasurement.test.sh
  - scripts/ci/capture-terminal-ratification-evidence.sh
  - scripts/ci/capture-terminal-ratification-evidence.test.sh
  - scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh
  - scripts/ci/verify-fast-01-gap-closure-attestation-offline.test.sh
  - scripts/ci/verify-fast-01-remeasurement-attestation-offline.sh
  - scripts/ci/verify-terminal-ratification-attestation-offline.sh
  - scripts/ci/verify-terminal-ratification-attestation-offline.test.sh
  - test/sigra/planning/phase_233_library_economics_contract_test.exs
  - test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs
  - test/sigra/planning/phase_235_fast_01_remeasurement_contract_test.exs
  - test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---

# Phase 235: Code Review Report

**Reviewed:** 2026-08-03T22:11:30Z
**Depth:** standard
**Files Reviewed:** 18
**Status:** issues_found

## Summary

The evidence collectors, workflows, offline verifiers, and contract tests were reviewed in context. The fresh FAST-01 verifier does not implement the trusted-staging boundary used by the other two offline verifiers, allowing caller-controlled temporary-directory state into an operation intended to establish offline provenance. Its test coverage also omits the hostile-environment regression test that protects the corresponding verifiers.

## Critical Issues

### CR-01: Remeasurement verifier trusts caller-controlled temporary staging

**File:** `/Users/jon/projects/sigra/scripts/ci/verify-fast-01-remeasurement-attestation-offline.sh:63`
**Issue:** The verifier creates its working directory with `mktemp -d` while inheriting `TMPDIR`, `TMP`, and `TEMP`, and does not canonicalize or verify the resulting parent, ownership, or mode. This is inconsistent with the gap-closure and terminal verifiers, which clear those variables, force a trusted `/tmp` parent, and verify the staging directory before copying retained inputs. A caller or workflow environment can therefore select the staging location for the supposedly network-denied provenance verification; the verifier's copied receipts, trust root, bundle, and verification outputs are consequently handled in an attacker-selected filesystem boundary.
**Fix:** Establish trusted staging before reading or copying inputs, mirroring the hardened verifiers:

```bash
FIXED_PARENT=$(builtin cd -P -- /tmp && builtin pwd -P) || exit 1
work=$(TMPDIR= TMP= TEMP= /usr/bin/env -i PATH=/usr/bin:/bin TMPDIR= TMP= TEMP= \
  "$MKTEMP_BIN" -d "$FIXED_PARENT/sigra-fast-01.XXXXXX") || exit 1
# then require an owned, non-symlinked mode-0700 directory under FIXED_PARENT
```

## Warnings

### WR-01: No hostile-environment regression test covers the remeasurement verifier

**File:** `/Users/jon/projects/sigra/scripts/ci/verify-fast-01-remeasurement-attestation-offline.sh:63`
**Issue:** Unlike the gap-closure and terminal verifiers, this verifier has no corresponding `verify-fast-01-remeasurement-attestation-offline.test.sh` that shadows commands and supplies hostile `TMPDIR`/`TMP`/`TEMP` values. The missing test allowed CR-01's staging-boundary regression to ship and leaves future hardening unverifiable.
**Fix:** Add a deterministic shell test modeled on `verify-fast-01-gap-closure-attestation-offline.test.sh`; invoke the verifier with hostile PATH and temporary-directory variables, assert its success marker, assert no sentinel command ran, and assert the hostile directory remained unused. Run that test from the required CI workflow.

---

_Reviewed: 2026-08-03T22:11:30Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
