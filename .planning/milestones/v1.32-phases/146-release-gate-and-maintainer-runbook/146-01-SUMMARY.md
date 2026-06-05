---
phase: 146-release-gate-and-maintainer-runbook
plan: 01
subsystem: infra
tags: [github-actions, release-please, hex, ci]
requires:
  - phase: 145-1-0-contract-and-release-truth
    provides: Release truth baseline and one-time release-as 1.0.0 posture
provides:
  - CI workflow_dispatch release-ref gate reruns on canonical CI jobs
  - Release Please publish path with tag/version/manifest/source_ref and package truth checks
  - Manual Hex recovery workflow with strict input validation and mirrored publish evidence
affects: [maintainer-runbook, release-operations, ci-evidence]
tech-stack:
  added: []
  patterns: [release-ref evidence reruns, release truth cross-checks, package unpack assertions]
key-files:
  created: [.planning/phases/146-release-gate-and-maintainer-runbook/146-01-SUMMARY.md]
  modified:
    - .github/workflows/ci.yml
    - .github/workflows/release-please.yml
    - .github/workflows/hex-publish.yml
key-decisions:
  - "Reused existing CI workflow and job identities for release-ref evidence instead of introducing a parallel release-only CI workflow."
  - "Mirrored release-truth, docs, package-inspection, dry-run, publish, and Hex visibility checks in both default and manual recovery publish paths."
patterns-established:
  - "Release automation must prove tag/version/manifest/source_ref alignment before publish."
  - "Manual recovery accepts only v<release_version> tag or commit SHA and blocks malformed inputs pre-checkout."
requirements-completed: [REL1-02, REL1-03]
duration: 3min
completed: 2026-05-31
---

# Phase 146 Plan 01: Release Gate And Maintainer Runbook Summary

**Canonical CI release-ref reruns plus deterministic publish/recovery workflows with version-ref-package truth and Hex visibility evidence**

## Performance

- **Duration:** 3 min
- **Started:** 2026-05-31T16:18:59Z
- **Completed:** 2026-05-31T16:20:43Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added `workflow_dispatch` to canonical CI so maintainers can rerun release evidence on tag refs (`gh workflow run "CI" --ref v1.0.0`) without duplicating CI.
- Hardened `release-please.yml` with explicit tag/version, manifest, and `source_ref` truth checks plus docs-warning and package-unpack assertions before publish.
- Hardened `hex-publish.yml` with strict manual input validation and mirrored release checks, package inspection, and Hex visibility polling.

## Task Commits

1. **Task 146-01-01: Make the canonical CI gates runnable on a release ref without creating a parallel workflow** - `e05eba7` (chore)
2. **Task 146-01-02: Harden the default publish and manual recovery workflows around release truth, package inspection, and visibility** - `74dadfb` (feat)

## Files Created/Modified
- `.github/workflows/ci.yml` - Added manual dispatch trigger and release-ref evidence guidance while preserving existing `main` push/PR filters and canonical job ids.
- `.github/workflows/release-please.yml` - Added release truth checks, docs gate, unpacked package assertions, and retained dry-run/publish/Hex visibility flow.
- `.github/workflows/hex-publish.yml` - Added manual input validation, mirrored release truth checks, docs gate, package assertions, and Hex visibility verification.

## Decisions Made
- Reuse canonical CI and stable job IDs as the release evidence surface.
- Keep both publish paths behaviorally aligned on correctness checks before publish.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 01 deliverables are complete and verified; Phase 146 Plan 02 can now reference these workflows as the enforced release-gate truth surface.

## Verification Commands Run

- `bash -lc 'set -euo pipefail; rg -n "^  workflow_dispatch:$" .github/workflows/ci.yml; rg -n "gh workflow run \"CI\" --ref v1\.0\.0|release-ref evidence path" .github/workflows/ci.yml; rg -n "^  install_golden_contract:|^  library_tests:|^  library_tests_dep_off:|^  install_smoke:|^  example_http_smoke:|^  example_playwright_smoke:|^  generated_admin_playwright_smoke:" .github/workflows/ci.yml; rg -n "^  push:$|^  pull_request:$|branches: \[main\]" .github/workflows/ci.yml'`
- `bash -lc 'set -euo pipefail; rg -n "tag_name.*version|release-please-manifest|source_ref: \"v#\{@version\}\"|mix docs --warnings-as-errors|mix hex.build --unpack --output sigra-hex-inspect|Verify version on Hex\.pm" .github/workflows/release-please.yml; rg -n "Validate manual release inputs|release-please-manifest|source_ref: \"v#\{@version\}\"|mix docs --warnings-as-errors|mix hex.build --unpack --output sigra-hex-inspect|Verify version on Hex\.pm" .github/workflows/hex-publish.yml'`
- `bash -lc 'set -euo pipefail; rg -n "^  workflow_dispatch:$" .github/workflows/ci.yml; rg -n "gh workflow run \"CI\" --ref v1\.0\.0" .github/workflows/ci.yml; rg -n "tag_name.*version|release-please-manifest|source_ref: \"v#\{@version\}\"|mix docs --warnings-as-errors|mix hex.build --unpack --output sigra-hex-inspect|Verify version on Hex\.pm" .github/workflows/release-please.yml; rg -n "Validate manual release inputs|release-please-manifest|source_ref: \"v#\{@version\}\"|mix docs --warnings-as-errors|mix hex.build --unpack --output sigra-hex-inspect|Verify version on Hex\.pm" .github/workflows/hex-publish.yml'`

## Self-Check: PASSED

- Found summary file: `.planning/phases/146-release-gate-and-maintainer-runbook/146-01-SUMMARY.md`
- Found task commit `e05eba7` in git history
- Found task commit `74dadfb` in git history

