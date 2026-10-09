---
phase: 248-exact-source-release-gate
reviewed: 2026-10-08T23:13:36Z
depth: standard
files_reviewed: 18
files_reviewed_list:
  - .github/workflows/release-please.yml
  - .github/workflows/release-pr-automerge.yml
  - .github/workflows/hex-publish.yml
  - .github/workflows/release-run-observer.yml
  - scripts/ci/release-exact-source.sh
  - scripts/ci/release-exact-source.test.sh
  - scripts/ci/wait-for-ci-gate.sh
  - scripts/ci/wait-for-ci-gate.test.sh
  - scripts/ci/release-candidate-preflight.sh
  - scripts/ci/release-candidate-preflight.test.sh
  - scripts/ci/release-environment-preflight.sh
  - scripts/ci/release-environment-preflight.test.sh
  - scripts/ci/release-receipt.sh
  - scripts/ci/release-receipt.test.sh
  - scripts/ci/release-observer.sh
  - scripts/ci/release-observer.test.sh
  - test/sigra/planning/phase_248_release_gate_contract_test.exs
  - test/sigra/planning/phase_248_release_observer_contract_test.exs
findings:
  critical: 3
  warning: 0
  info: 0
  total: 3
status: issues_found
---

# Phase 248: Code Review Report

**Reviewed:** 2026-10-08T23:13:36Z
**Depth:** standard
**Files Reviewed:** 18
**Status:** issues_found

## Summary

The release gate has exact-source checks, but the manual recovery workflow permits shell injection before validating user inputs. The current GitHub environment configuration also lacks two credentials required by the workflows, so the live release path will fail closed. Finally, a failed gate poll can persist a false CI run identity in the release receipt.

## Critical Issues

### CR-01: Manual dispatch inputs are interpolated into shell source

**Classification:** BLOCKER
**File:** `.github/workflows/hex-publish.yml:75-76`
**Issue:** `inputs.tag` and `inputs.release_version` are expanded directly into a `run:` script before the validation at lines 78-93. A workflow dispatcher can supply shell syntax such as `"; touch /tmp/pwned #`, which executes as part of the script before the intended regex rejects the value. The same raw `release_version` is interpolated into later shell scripts, including version, manifest, and docs checks.
**Fix:** Pass both values through step `env` entries (for example, `INPUT_TAG: ${{ inputs.tag }}` and `INPUT_VERSION: ${{ inputs.release_version }}`), then use `"$INPUT_TAG"` and `"$INPUT_VERSION"` in every `run:` block. Keep expression interpolation in non-shell action inputs separate from shell source.

### CR-02: Required credentials are absent from the live environments

**Classification:** BLOCKER
**File:** `.github/workflows/release-please.yml:94-103`
**Issue:** The Release Please job requires `RELEASE_PLEASE_TOKEN` from the `release-automation` environment, and the publish workflow also requires `HEX_API_KEY` from `hex-publish` at lines 228-239. A live name-only GitHub secret check returned `[]` for `release-automation` and `["HEX_DRY_RUN_API_KEY"]` for `hex-publish`. Repository-level copies do not satisfy `${{ secrets.* }}` after a job binds to an environment, so the preflight blocks Release Please and publication. The dry-run credential is present, but the publish credential is not.
**Fix:** Add `RELEASE_PLEASE_TOKEN` to the `release-automation` environment and `HEX_API_KEY` to `hex-publish`, then verify their names with the existing environment checks before relying on the release lane.

### CR-03: Failed gate receipts can claim the release run as the CI run

**Classification:** BLOCKER
**File:** `.github/workflows/release-please.yml:171-181`
**Issue:** Whenever `wait-for-ci-gate.sh` exits nonzero, this step assigns `GITHUB_RUN_ID` and the current release workflow URL to `GATE_RUN_ID` and `GATE_URL`. The receipt builder then writes those values as the gate run identity. `GITHUB_RUN_ID` identifies the Release Please workflow, not the queried `ci.yml` run, so a failed or timed-out receipt can falsely attribute the gate result to another workflow. The poller's last-run URL is captured only in the error file and is not used here.
**Fix:** Have the poller expose the actual observed CI run identity and URL on failure as well as success. If no CI run was observed, represent the gate identity as unavailable in the receipt schema instead of substituting the release workflow's ID and URL.

---

_Reviewed: 2026-10-08T23:13:36Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
