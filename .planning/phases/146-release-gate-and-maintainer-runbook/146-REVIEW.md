---
phase: 146-release-gate-and-maintainer-runbook
reviewed: 2026-05-31T17:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - .github/workflows/ci.yml
  - .github/workflows/hex-publish.yml
  - .github/workflows/release-please.yml
  - docs/NEXT-STEPS-MANUAL.md
  - docs/ga-evidence.md
  - docs/release-runbook-v1-0.md
findings:
  critical: 2
  warning: 1
  info: 0
  total: 3
status: issues_found
---

# Phase 146: Code Review Report

**Reviewed:** 2026-05-31T17:00:00Z  
**Depth:** standard  
**Files Reviewed:** 6  
**Status:** issues_found

## Summary

Reviewed the Phase 146 workflow/docs release gate changes with focus on shell correctness, fail-closed behavior, release input validation, and docs/workflow consistency. I found two blocker-level release-integrity issues and one warning-level validation robustness issue.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Release-Ref Evidence Path Is Not Enforced (Fail-Open)

**Classification:** BLOCKER  
**File:** `.github/workflows/ci.yml:4-10`, `.github/workflows/ci.yml:23-997`, `docs/release-runbook-v1-0.md:8-23`  
**Issue:** The runbook declares release gates must be proven on a `release tag`, but `CI` permits `workflow_dispatch` without any guard that the run is actually on `refs/tags/v*`. A maintainer can run from `main` and still collect green gate runs, which breaks the release-ref trust model.
**Fix:**
```yaml
# Add an early guard job and make all release-evidence jobs depend on it.
release_ref_guard:
  runs-on: ubuntu-latest
  if: ${{ github.event_name == 'workflow_dispatch' }}
  steps:
    - name: Require release tag ref for manual release evidence
      run: |
        set -euo pipefail
        case "${GITHUB_REF}" in
          refs/tags/v*) ;;
          *)
            echo "Manual CI release-evidence runs must use refs/tags/v*; got ${GITHUB_REF}"
            exit 1
            ;;
        esac
```

### CR-02: Manual Recovery Publish Accepts Arbitrary SHA Without Provenance Check

**Classification:** BLOCKER  
**File:** `.github/workflows/hex-publish.yml:12-19`, `.github/workflows/hex-publish.yml:40-57`, `docs/release-runbook-v1-0.md:77-82`  
**Issue:** `hex-publish` accepts any syntactically valid SHA (`^[0-9a-fA-F]{7,40}$`) but does not verify that SHA corresponds to the intended release tag/version provenance. That permits publishing from an arbitrary commit as long as `mix.exs` and manifest happen to match, which weakens supply-chain integrity for a “manual recovery” path.
**Fix:**
```bash
set -euo pipefail
input_ref="${{ inputs.tag }}"
input_version="${{ inputs.release_version }}"
expected_tag="v${input_version}"

git fetch --tags --force
tag_commit="$(git rev-list -n1 "${expected_tag}")"
input_commit="$(git rev-parse "${input_ref}^{commit}")"

if [ "${input_commit}" != "${tag_commit}" ]; then
  echo "Ref ${input_ref} does not resolve to ${expected_tag} (${tag_commit})"
  exit 1
fi
```

## Warnings

### WR-01: Version Checks Use Regex-Matching Instead of Exact/Validated SemVer

**Classification:** WARNING  
**File:** `.github/workflows/hex-publish.yml:85-87`, `.github/workflows/release-please.yml:101-103`, `.github/workflows/hex-publish.yml:16-19`  
**Issue:** Version verification relies on `grep` regex matching and does not validate `release_version` format. In manual dispatch, metacharacters (for example `1.0.0.*`) can produce false-positive matches. This is avoidable fragility in a release gate.
**Fix:**
```bash
set -euo pipefail
v="${{ inputs.release_version }}"
[[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]] || {
  echo "Invalid release_version: $v"
  exit 1
}
grep -nF "@version \"${v}\"" mix.exs
```

---

_Reviewed: 2026-05-31T17:00:00Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
