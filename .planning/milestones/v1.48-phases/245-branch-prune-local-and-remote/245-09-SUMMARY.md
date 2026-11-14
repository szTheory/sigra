---
phase: 245-branch-prune-local-and-remote
plan: 09
subsystem: infra
tags: [git, branch-pruning, protected-refs, worktrees, fixtures]
requires:
  - phase: 245-branch-prune-local-and-remote
    provides: committed snapshots, allowlists, readiness, and PR baseline from Plan 08
provides:
  - Captured and fresh live origin default-branch checks on direct deletion paths
  - Exact safety-publication destination checks
  - Fail-closed local deletion when linked-worktree registration cannot be atomically coordinated
affects: [245-branch-prune-local-and-remote, branch-prune]
actuals:
  tokens: 6857
  tasks: 0
  commits: 2
  plan_head_before: 653dd28428cbcd3b136d48ff11388c8d4e2c1ded
tech-stack:
  added: []
  patterns: [fresh origin/HEAD checks at mutation boundaries, fail-closed worktree guard]
key-files:
  created: [.planning/phases/245-branch-prune-local-and-remote/245-09-SUMMARY.md]
  modified:
    - scripts/maintainers/prune-stale-branches.sh
    - scripts/maintainers/prune-stale-branches.test.sh
    - scripts/maintainers/prune-stale-branches.remote.test.sh
key-decisions:
  - "Keep local apply fail-closed because Git cannot atomically lock linked-worktree registration with ref deletion."
  - "Do not mark REPO-04 complete; the unchanged-eligible local deletion criterion remains unsatisfied."
patterns-established:
  - "Apply-time default identity must be freshly read from origin immediately before any deletion."
requirements-completed: []
coverage:
  - id: D1
    description: Direct deletion paths enforce captured and current live default-branch exclusions, and safety publication accepts only approved destinations.
    requirement: REPO-04
    verification:
      - kind: integration
        ref: "scripts/maintainers/prune-stale-branches.remote.test.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: An unchanged eligible local branch can be deleted while linked-worktree registration remains race-safe.
    requirement: REPO-04
    verification: []
    human_judgment: true
    rationale: "Git exposes no demonstrated atomic coordinator for the worktree registry and ref transaction; local apply intentionally stops before deletion."
duration: 30min
completed: 2026-09-28
status: halted
---

# Phase 245 Plan 09: Protected Ref Apply Guards Summary

**Direct apply paths validate captured and live default identities and approved safety destinations; local deletion remains disabled until a shared worktree/ref coordinator can be proven.**

## Performance

- **Duration:** approximately 30 minutes
- **Started:** 2026-09-28T09:03:00Z
- **Stopped:** 2026-09-28T09:33:00Z
- **Tasks fully completed:** 0 of 2
- **Files modified:** 3 source/test files, plus this summary

## Work Completed

- Added shared ref normalization and protected-ref checks that compare deletion candidates against the committed snapshot default and a fresh `git ls-remote --symref origin HEAD` result.
- Applied the guards to local, remote, and tracking deletion paths; the direct remote fixture exercises a candidate that becomes the live origin default.
- Restricted safety publication to the named D-04 destinations and expected object kind, with a fixture for an unapproved destination.
- Recorded the merge-target ref/OID and worktree set during local preflight, then rechecked them before the apply boundary.
- Kept local apply fail-closed with `local_worktree_registration_not_atomically_guardable`. Git's ref transaction can coordinate ref identities, but no tested Git-supported transaction also locks linked-worktree registration. Deleting after a worktree-list check would leave a race window.

## Validation

- Root reported the local fixture, remote fixture, and named outer local test passing after commit `9698abff`.
- The fixtures use temporary repositories and a temporary bare origin. No production refs or pull requests were changed.
- An earlier attempt to run the outer suite was time-boxed while investigating inherited remote configuration and the update-ref transaction. Root reran the named fixtures successfully after those fixes.

## Unresolved Plan Criteria

- Task 2's required unchanged-eligible local deletion is intentionally unsatisfied. Keeping local apply fail-closed means that fixture must not claim successful deletion.
- The linked-worktree predicate is not atomically bound to ref deletion. A shared coordinator with a verifiable Git-supported lock is required before local deletion can safely be enabled.
- Plan 09 is halted, not complete. REPO-04 remains incomplete, Plan 04 remains halted, and the previously recorded 11 PR identity disagreements and 30 cleanup-history evidence gaps remain unchanged.

## Commits

- `9698abff` — protected-ref checks, fixture updates, and fail-closed local worktree handling
- The summary is committed separately after the implementation commit.

## Next Phase Readiness

Do not rerun Plan 09 automatically. Resume only after a shared coordinator can be proven or the local deletion requirement is explicitly redesigned. Phase 245 remains active; its existing PR-identity and cleanup-history evidence blockers remain open.

---
*Phase: 245-branch-prune-local-and-remote*
*Status: halted, 2026-09-28*
