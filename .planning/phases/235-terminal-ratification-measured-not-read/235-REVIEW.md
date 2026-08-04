---
phase: 235-terminal-ratification-measured-not-read
reviewed: 2026-08-04T00:35:16Z
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
  critical: 3
  warning: 0
  info: 0
  total: 3
status: issues_found
---

# Phase 235: Code Review Report

**Reviewed:** 2026-08-04T00:35:16Z
**Depth:** standard
**Files Reviewed:** 15
**Status:** issues_found

## Summary

All scoped workflow, shell, and ExUnit sources were read in context. The local shell contracts and scoped ExUnit tests pass, but three production integrity/executability paths are untested and defective: the fresh-window workflow has insufficient Git history for its collector, the gap-closure collector accepts an empty digest set as proof, and one offline verifier can execute a PATH-controlled `sudo` before isolation.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Fresh-window evidence workflow cannot satisfy its collector's Git-history checks

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/.github/workflows/fast-01-remeasurement-evidence.yml:20`

**Issue:** `actions/checkout` uses its default `fetch-depth: 1`, while `capture-fast-01-remeasurement.sh` requires both `git merge-base --is-ancestor "$CUTOFF_SHA" origin/main` and `git show` for commit `a282b3de...` (script lines 25-29). That cutoff predates the checked-out workflow commit, so it is absent from a single-commit clone; the collection fails before producing an attestation subject. The analogous gap-closure workflow already specifies `fetch-depth: 0` for this exact reason.

**Fix:** Fetch the required history before invoking the collector, preferably by making checkout complete:

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
  with:
    fetch-depth: 0
```

Add a workflow-level regression check that runs the collector from a depth-one clone or asserts this workflow retains `fetch-depth: 0`.

### CR-02: Gap-closure collector treats an empty remediation digest map as validated evidence

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/scripts/ci/capture-fast-01-gap-closure.sh:36-39`

**Issue:** The only validation of the remediation receipt's `file_digests` is a loop over `to_entries[]`. A syntactically valid receipt with `"file_digests": {}` makes that loop perform zero checks and succeed. The collector also does not pin the remediation receipt bytes or require the expected four paths/digest format. Consequently a changed or empty receipt can authorize post-cutoff results without proving that the remediation files at the immutable cutoff match the claimed remediation, defeating the script's provenance claim.

**Fix:** Fail closed on an exact, non-empty digest schema and bind it to an immutable expected receipt digest (or hard-code the expected paths and SHA-256 values). For example, have `jq -e` require the exact path set and 64-hex values before the loop, then verify the receipt's SHA-256 against the trusted value:

```bash
jq -e '
  (.file_digests | type == "object") and
  (.file_digests | keys | sort == ["CONTRIBUTING.md", "mix.exs", "test/sigra/planning/phase_198_contributor_dx_contract_test.exs", "test/sigra/planning/phase_233_library_economics_contract_test.exs"]) and
  all(.file_digests[]; type == "string" and test("^[0-9a-f]{64}$"))
' "$REMEDIATION_RECEIPT" >/dev/null || fail "remediation_digest_schema_invalid"
```

### CR-03: Terminal offline verifier's fallback isolation can be replaced through PATH

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/scripts/ci/verify-terminal-ratification-attestation-offline.sh:43-44`

**Issue:** Unlike the matching FAST-01 verifier, this fallback discovers and executes `sudo` through `PATH`. A caller-controlled `sudo` executable can return success for the preflight, become `isolation[0]`, and execute the later verification commands without creating a network namespace. The script will then report `offline_attestation_verified` although its required network isolation was never established. This is particularly unsafe because the verifier is intended to establish provenance trust under adversarial local conditions.

**Fix:** Use an absolute, trusted sudo path and retain the matching cleanup handling already used by the FAST-01 verifier:

```bash
elif test -x /usr/bin/sudo && /usr/bin/sudo -n /usr/bin/unshare --net true >/dev/null 2>&1; then
  isolation=(/usr/bin/sudo -n /usr/bin/unshare --net)
```

Set the cleanup branch for `/usr/bin/sudo` to use `/usr/bin/sudo -n /usr/bin/rm ...`, and add a test that prepends a fake `sudo` to `PATH` and confirms the verifier fails rather than using it.

---

_Reviewed: 2026-08-04T00:35:16Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
