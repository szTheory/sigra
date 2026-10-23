---
phase: 242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1
plan: "02"
subsystem: release-automation
tags: [github-actions, ci, pull-request, provenance, hex]
requires:
  - phase: 242-01
    provides: fixed-target remediation workflow and hermetic verifier
provides:
  - merged default-branch-visible, dispatch-only remediation workflow
  - exact-head CI and default-branch blob provenance for the remediation lane
  - continuation branch rooted at the observed squash merge
affects: [242-03, 242-04, 242-05, 242-06, 242-07, release-automation]
tech-stack:
  added: []
  patterns: [exact-head PR gate, lease-protected clean-candidate repair, default-branch blob proof]
key-files:
  created:
    - .github/workflows/hex-remediate-phantom.yml
    - scripts/ci/hex-remediation-verify.sh
    - scripts/ci/prohibitions/p22-hex-remediation.test.mjs
  modified:
    - scripts/ci/hex-remediation-verify.test.sh
decisions:
  - "Use the observed squash merge SHA as the continuation provenance anchor because repository policy disallows merge commits."
  - "Keep the remediation workflow dispatch-only; no Hex remediation workflow run was dispatched during this plan."
actuals:
  tokens: 7648
  tasks: 2
  commits: 1
plan_head_before: 417130bdc0e69dd102431391cd6cd30bf88b2fa5
requirements-completed: []
coverage:
  - id: D1
    description: Merged default-branch-visible fixed remediation workflow with exact-head CI proof.
    verification:
      - kind: integration
        ref: "PR #255 ci.yml run 35550293589 at 17f946554e8c9df5279e1aa42636b48fea229962"
        status: pass
      - kind: integration
        ref: "origin/main 154dd679 workflow blob 4fd90523499aebde2cd12de9a404eeca5dd9fa44"
        status: pass
    human_judgment: false
  - id: D2
    description: Continuation branch rooted at the observed merged default-branch SHA.
    verification:
      - kind: other
        ref: "agent-242-02-continuation metadata commit directly descends from 154dd679d0bd0fc18b5d2142c8633c3aa9822ec5"
        status: pass
    human_judgment: false
duration: 11h
completed: 2026-09-21
status: complete
---

# Phase 242 Plan 02: Land Fixed Remediation Infrastructure Summary

**The fixed, dispatch-only Hex remediation workflow is merged on `main` behind exact-head CI, with later work anchored to the observed default-branch squash merge rather than an unproven local branch.**

## Performance

- **Duration:** 11h
- **Started:** 2026-09-20T14:25:00Z
- **Completed:** 2026-09-21T01:46:57Z
- **Tasks:** 2/2
- **Files modified:** 7

## Accomplishments

- Re-verified the fixed candidate with the hermetic verifier, p22, the full prohibition suite, Phase 234 action-pinning coverage, and `MIX_ENV=test mix ci` before presenting it to GitHub.
- Rebuilt the candidate directly on current `origin/main` after the initial PR exposed unrelated historical files; PR #255 then contained exactly the seven Plan 01 implementation paths.
- Merged PR #255 after exact-head CI run `35550293589` succeeded at `17f946554e8c9df5279e1aa42636b48fea229962`, then proved `origin/main` merge `154dd679d0bd0fc18b5d2142c8633c3aa9822ec5` holds the byte-identical workflow blob.
- Confirmed GitHub recognizes the workflow on the default branch and that its remediation-run list is empty; this plan did not dispatch it or mutate Hex.
- Created `agent-242-02-continuation` from the observed merge for Plans 03–07.

## Task Commits

1. **Task 1: Freeze the tested infrastructure commit and prove the pre-push gate** - no tracked-file commit; all required local gates passed.
2. **Task 2: Merge the remediation-infrastructure PR and branch from the observed merge** - `17f94655` (feat; clean exact-base candidate), `154dd679` (GitHub squash merge)

## Files Created/Modified

- `.github/workflows/hex-remediate-phantom.yml` - merged dispatch-only, fixed-target remediation lane.
- `scripts/ci/hex-remediation-verify.sh` and `.test.sh` - hermetic public-evidence verifier and self-test.
- `scripts/ci/prohibitions/p22-hex-remediation.test.mjs` plus three fixtures - fixed-scope workflow prohibition guard.

## Decisions Made

- The initial candidate was rebuilt from `origin/main` with only the seven owned paths after PR #255 exposed unrelated history; the repaired candidate was byte-identical for those paths.
- Repository policy disallowed merge commits. With explicit user approval, PR #255 was squash-merged and the observed merge SHA—not candidate ancestry—became the durable continuation provenance anchor.
- REL-03 and REL-04 remain pending: merging the dispatch-only infrastructure intentionally does not claim an external Hex retirement or docs revert.

## Deviations from Plan

### Approved Provenance Deviation

**1. [User-approved merge strategy] Squash merge replaced candidate-ancestry proof**
- **Found during:** Task 2
- **Issue:** GitHub rejected merge commits with HTTP 405 because the repository disallows them; the plan's candidate-ancestor check could not hold under an allowed squash merge.
- **Fix:** Rebuilt the candidate directly on `origin/main`, required exact-head CI, squash-merged PR #255, and anchored continuation work to observed merge `154dd679d0bd0fc18b5d2142c8633c3aa9822ec5` while proving the default-branch workflow blob byte-identical.
- **Verification:** PR #255 head and changed-path proof; CI run `35550293589` success at the clean candidate; post-merge blob comparison and workflow visibility check.

### Auto-fixed Issues

**2. [Rule 3 - Blocking issue] Rebuilt the candidate to remove unrelated PR history**
- **Found during:** Task 2
- **Issue:** The first PR head correctly named the frozen candidate but GitHub's PR diff included unrelated planning and prior-phase files.
- **Fix:** Applied only the seven Plan 01 paths to current `origin/main`, committed clean candidate `17f94655`, re-ran the mandatory gates, and lease-updated the scoped branch.
- **Verification:** GitHub PR #255 files endpoint returned exactly the seven owned paths; exact-head CI succeeded.

## Issues Encountered

- The initial CI watcher detached from the tool process before terminal output. A process check preserved the original watcher and prevented concurrent polling; the final terminal REST evidence confirmed success at the exact repaired head.
- The isolated worktree required local lockfile dependency restoration before `mix ci`; only existing locked dependencies were fetched, and the full suite then passed.

## User Setup Required

None - no secrets, dashboard changes, remediation dispatch, or Hex mutation were needed for this infrastructure landing.

## Next Phase Readiness

`agent-242-02-continuation` is rooted exactly at `origin/main` merge `154dd679`. Plans 03–07 can use that SHA as the public-evidence provenance anchor and may dispatch the now-default-branch-visible workflow only when separately authorized.

## Self-Check: PASSED

- Confirmed the merged workflow exists at `origin/main` with blob `4fd90523499aebde2cd12de9a404eeca5dd9fa44`.
- Confirmed clean candidate `17f94655`, observed merge `154dd679`, and continuation branch `agent-242-02-continuation` (whose parent is the observed merge) exist in Git history.

---
*Phase: 242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1*
*Completed: 2026-09-21*
