---
phase: 235-terminal-ratification-measured-not-read
reviewed: 2026-08-04T00:49:06Z
depth: standard
files_reviewed: 15
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
  - scripts/ci/verify-fast-01-remeasurement-attestation-offline.sh
  - scripts/ci/verify-terminal-ratification-attestation-offline.sh
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

**Reviewed:** 2026-08-04T00:49:06Z
**Depth:** standard
**Files Reviewed:** 15
**Status:** issues_found

## Summary

All prior blockers are resolved in the current sources: the fresh-window workflow fetches full history, the gap-closure collector pins and validates the remediation receipt, and the verifiers no longer resolve `sudo` or `mktemp` through `PATH`. The scoped shell contracts pass, as do all 33 scoped ExUnit tests. However, both offline verifiers still allow the caller to select the pre-isolation staging parent through `TMPDIR`, which permits a concurrent same-user attacker to tamper with verification inputs and output. The new `mktemp` self-tests also do not prove the protected setup path is reached.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Caller-controlled `TMPDIR` controls the verifier's pre-isolation staging root

**Classification:** BLOCKER

**Files:**

- `/Users/jon/projects/sigra/scripts/ci/verify-fast-01-remeasurement-attestation-offline.sh:29-35,63-75`
- `/Users/jon/projects/sigra/scripts/ci/verify-terminal-ratification-attestation-offline.sh:29-35,63-75`

**Issue:** The scripts now select `mktemp` by trusted absolute path, but invoke it with the inherited environment at line 63. `mktemp` honors `TMPDIR`; therefore a caller can choose a same-user-controlled parent for `$work` before the network namespace/sandbox is entered. A concurrent process can modify the copied receipt, bundle, trusted root, or `positive.json` under that parent between the copy/verification/JQ checks, allowing a fabricated local result to satisfy the post-verification JSON policy. This defeats the verifiers' intended hostile-caller integrity boundary even though the executable itself is trusted.

**Fix:** Clear `TMPDIR` (and related temporary-directory overrides) while creating the staging directory, then require the resulting directory to be an owned, non-symlink directory under a fixed trusted parent. For example:

```bash
work="$(env -u TMPDIR -u TMP -u TEMP "$MKTEMP_BIN" -d /tmp/sigra-attestation.XXXXXXXXXX)" \
  || { echo "trusted_staging_creation_failed" >&2; exit 1; }
```

Use an absolute `env` path if it is part of the trust boundary, preserve the existing quoted cleanup, and add a regression test that exports a controlled `TMPDIR` and proves the verifier either rejects it or stages outside it.

## Warnings

### WR-01: `mktemp` regression tests can pass before they exercise the asserted security path

**Classification:** WARNING

**Files:**

- `/Users/jon/projects/sigra/scripts/ci/verify-fast-01-remeasurement-attestation-offline.test.sh:13-16`
- `/Users/jon/projects/sigra/scripts/ci/verify-terminal-ratification-attestation-offline.test.sh:30-36`

**Issue:** Both tests accept any verifier failure (`|| true`) and assert only that the fake binary left no marker. On machines where `gh` is rejected by the whitelist, retained evidence is missing, or network isolation is unavailable, the verifier exits before line 63 and the test passes without executing the trusted `mktemp` path. Reintroducing a PATH-resolved `mktemp` later could therefore remain undetected in those environments.

**Fix:** Run the test with a trusted `gh`/`jq` fixture and minimal retained inputs that reach the staging setup, then assert an observable trusted-staging result (or instrument only the verifier's explicit trusted path) in addition to asserting the fake `mktemp` was not invoked. Fail the test when it exits before that checkpoint.

---

_Reviewed: 2026-08-04T00:49:06Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
