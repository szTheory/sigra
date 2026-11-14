---
phase: 248-exact-source-release-gate
plan: 02
subsystem: release-automation
tags: [github-actions, release-please, ci-gate, changelog, bash]
requires:
  - phase: 248-01
    provides: exact source and successful ci-gate identity checks
provides:
  - Release Please branch push CI source for the exact candidate commit
  - Trusted workflow_run preflight and exact-head squash merge guard
  - Candidate ledger and source-backed changelog content validation
affects: [phase-248-03, phase-248-04, release-automation]
actuals:
  tokens: 7665
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns: [data-only candidate content validation, exact-head guarded merge]
key-files:
  created:
    - .github/workflows/release-pr-automerge.yml
    - scripts/ci/release-candidate-preflight.sh
    - scripts/ci/release-candidate-preflight.test.sh
  modified:
    - .github/workflows/ci.yml
key-decisions:
  - "Correlate the completed push run, current Release Please PR, readiness ledger, and every source claim to the same exact candidate SHA."
  - "Match source claims against individual changelog bullets or paragraphs, with a 40% significant-token threshold, to prevent unrelated notes from combining into a false match."
  - "Fetch candidate CHANGELOG.md through the GitHub contents API as data and repeat all candidate and CI checks immediately before the exact-head merge."
patterns-established:
  - "The privileged workflow runs only trusted default-branch code and never checks out or executes the candidate branch."
  - "Release PR merge uses RELEASE_PLEASE_TOKEN only in the merge step and gh pr merge --match-head-commit."
requirements-completed: [AUTO-01]
coverage:
  - id: D1
    description: Only the single open Release Please PR whose head matches a successful push-triggered ci-gate run is eligible.
    requirement: AUTO-01
    verification:
      - kind: unit
        ref: scripts/ci/release-candidate-preflight.test.sh#candidate identity fixtures
        status: pass
    human_judgment: false
  - id: D2
    description: Candidate notes must include each source-backed summary in its versioned changelog section, with no stranded or duplicate notes.
    requirement: AUTO-01
    verification:
      - kind: unit
        ref: scripts/ci/release-candidate-preflight.test.sh#content and omission fixtures
        status: pass
    human_judgment: false
  - id: D3
    description: The workflow re-reads source CI, candidate identity, and candidate changelog before an exact-head squash merge.
    requirement: AUTO-01
    verification:
      - kind: unit
        ref: scripts/ci/release-candidate-preflight.test.sh#workflow contract
        status: pass
      - kind: other
        ref: actionlint .github/workflows/release-pr-automerge.yml
        status: pass
    human_judgment: false
duration: 50min
completed: 2026-10-08
status: complete
plan_head_before: c06546965
plan_head_after: fa7633498125891c29215e44b718a294dc953f9a
commits: 2
---

# Phase 248 Plan 02: Exact-Head Release PR Merge Summary

**Release Please candidates now pass through source-bound CI and changelog preflight before a fresh, exact-head squash-merge decision.**

## Performance

- **Duration:** approximately 50 minutes
- **Started:** 2026-10-08 (start timestamp was not captured)
- **Completed:** 2026-10-08T19:49:52Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added the Release Please branch to CI’s push trigger while preserving existing pull request CI and `ci-gate` behavior.
- Added a trusted `workflow_run` consumer that validates run, PR, label, repository, base, title, readiness ledger, exact source SHA, and successful `ci-gate` identity.
- Added data-only changelog validation for a unique release section, stranded Unreleased entries, normalized duplicate notes, and all source-backed ledger summaries.
- Added a fresh pre-merge API read and `gh pr merge --squash --match-head-commit`; the release token is scoped to that merge step.
- Added hermetic fixtures for identity failures, ledger binding, each omitted source summary, duplicate/missing content, and workflow merge guards.

## Task Commits

1. **Task 1: Establish an exact-head CI source for the Release Please branch** - `2f5d6f6f690c15c56f0cf7710fa5ff8cebba2b4c`
2. **Task 2: Validate source-backed release notes and guard the exact-head merge** - `fa7633498125891c29215e44b718a294dc953f9a`

## Files Created/Modified

- `.github/workflows/ci.yml` - Added the exact Release Please branch push trigger. Existing unrelated Phase 243 cache edits remain unstaged.
- `.github/workflows/release-pr-automerge.yml` - Added trusted candidate preflight, fresh state validation, and guarded squash merge.
- `scripts/ci/release-candidate-preflight.sh` - Added exact source/run/PR ledger and changelog checks.
- `scripts/ci/release-candidate-preflight.test.sh` - Added 26 hermetic contract cases.

## Decisions Made

- Candidate changelog content is fetched from the exact PR head as data; candidate code is never checked out or executed in the privileged workflow.
- Source-backed claims are matched independently against each changelog entry so multiple unrelated entries cannot combine to satisfy one claim.
- The readiness ledger’s `source_selection.selected_source_sha` is a valid reviewed base SHA; `final_readiness.source_sha`, `final_validation.checked.pr_head_sha`, source rows, and CI run rows bind to the candidate head/run. The actual ledger may omit the optional `candidate_summary_only_unreleased` field; absence is accepted, while explicit `true` is rejected.

## Verification

- `bash scripts/ci/release-candidate-preflight.test.sh` - 26 passed, 0 failed.
- `actionlint -shellcheck=0 .github/workflows/ci.yml .github/workflows/release-pr-automerge.yml` - passed.
- `actionlint .github/workflows/release-pr-automerge.yml` - passed.
- `git diff --check` on the scoped Plan02 files - passed.
- Confirmed `HEAD:.github/workflows/ci.yml` contains `branches: [main, release-please--branches--main]`. The only current unstaged diff in that workflow is inherited Phase243/Playwright cache work and was not included in either Plan02 commit.

## Issues Encountered

- A read-only run of the new preflight against candidate `0e773d3614a242e4fbcdd34c418ecb8a307703d6`, CI run `37819712610`, the current readiness ledger, and the candidate’s CHANGELOG correctly fails on the second source-backed summary: the versioned note does not cover malformed-link handling and stale-error clearing. No candidate files or remote state were changed. The guarded workflow will leave the PR open until the candidate changelog covers that claim and the candidate receives new exact-head CI evidence.
- Plain `actionlint` on the inherited `ci.yml` reports existing ShellCheck warnings in unrelated jobs; both changed workflows passed actionlint syntax validation with ShellCheck disabled, and the new merge workflow passed plain actionlint.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Bound each ledger claim to the final candidate source and CI run**
- **Found during:** Task 2
- **Issue:** The initial jq expression did not bind per-row source SHA to the final readiness source, and the reviewed base SHA is distinct from the candidate SHA.
- **Fix:** Validate the selected base SHA as a full SHA, then bind the final readiness source, checked PR head, each claim source, and each claim CI run to the candidate and successful run.
- **Files modified:** `scripts/ci/release-candidate-preflight.sh`
- **Verification:** Source mismatch fixture rejected; valid base/candidate split fixture accepted.
- **Committed in:** `fa7633498125891c29215e44b718a294dc953f9a`

**2. [Rule 3 - Blocking issue] Accepted the actual optional-ledger-field shape**
- **Found during:** Task 2
- **Issue:** The finalized ledger omits `candidate_summary_only_unreleased`; requiring an explicit false value rejected the real ledger despite its ready status.
- **Fix:** Treat an absent flag as false and reject an explicit true value.
- **Files modified:** `scripts/ci/release-candidate-preflight.sh`, `scripts/ci/release-candidate-preflight.test.sh`
- **Verification:** Fixture with the field omitted passes; explicit true remains rejected by the gate.
- **Committed in:** `fa7633498125891c29215e44b718a294dc953f9a`

**Total deviations:** 2 auto-fixed (1 bug, 1 schema compatibility issue)
**Impact on plan:** Kept the gate aligned with the actual final ledger schema and exact candidate identity without weakening fail-closed behavior.

## Next Phase Readiness

Plan02 implementation and hermetic verification are complete. The current release candidate is not content-valid under this new gate because one source-backed summary is insufficient; later release automation will fail closed until the candidate content and exact-head CI evidence are refreshed. No merge, tag, or publish was performed.

## Self-Check: PASSED

- Summary file exists at the planned path.
- Both Task 1 (`2f5d6f6f690c15c56f0cf7710fa5ff8cebba2b4c`) and Task 2 (`fa7633498125891c29215e44b718a294dc953f9a`) commits are ancestors of HEAD.
- The persisted Plan02 range from `c06546965` to `fa7633498125891c29215e44b718a294dc953f9a` contains exactly two task commits.

---
*Phase: 248-exact-source-release-gate*
*Completed: 2026-10-08*
