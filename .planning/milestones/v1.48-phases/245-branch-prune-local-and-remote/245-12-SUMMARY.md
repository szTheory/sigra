---
phase: 245-branch-prune-local-and-remote
plan: 12
subsystem: infra
tags: [git, branch-pruning, worktrees, reference-transactions, fixtures]
requires:
  - phase: 245-branch-prune-local-and-remote
    provides: committed branch inventories, exact deletion allowlists, and fail-closed prune paths
provides:
  - Shared common-directory coordinator prototype for hook-mediated ref transactions
  - Explicitly fail-closed local prune path pending per-build hook capability verification
affects: [245-verification, branch-pruning, linked-worktrees]
actuals:
  tokens: 12000
  tasks: 2
  commits: 6
tech-stack:
  added: []
  patterns: [common-directory mutation gate, prepared reference-transaction hook, owner-token ref admission]
key-files:
  created:
    - scripts/maintainers/repo-mutation-coordinator.sh
    - scripts/maintainers/repo-mutation-reference-transaction
    - scripts/maintainers/repo-mutation-coordinator.test.sh
    - scripts/maintainers/repo-mutation-coordinator.test.mjs
  modified:
    - scripts/maintainers/prune-stale-branches.sh
    - scripts/maintainers/prune-stale-branches.test.mjs
    - scripts/maintainers/prune-stale-branches.test.sh
    - scripts/maintainers/prune-stale-branches.remote.test.sh
key-decisions:
  - "D-05 remains fail-closed unless the installed shared hook and every registered worktree's effective hooks path verify cleanly."
  - "Never automatically reclaim stale coordinator locks or transaction leases."
patterns-established:
  - "Hook-mediated ref mutations share a short atomic admission gate and a common-directory owner lock."
  - "Local prune stops before expected-OID deletion until the active Git build's hook coverage is proven."
requirements-completed: []
coverage:
  - id: D1
    description: A shared coordinator gates hook-mediated mutations, but direct symbolic-HEAD enforcement depends on the Git build.
    requirement: REPO-04
    verification:
      - kind: integration
        ref: scripts/maintainers/repo-mutation-coordinator.test.sh
        status: fail
      - kind: unit
        ref: scripts/maintainers/repo-mutation-coordinator.test.mjs
        status: pass
    human_judgment: false
  - id: D2
    description: Local prune remains disabled until all linked-worktree mutations are covered by the verified coordinator.
    requirement: REPO-04
    verification:
      - kind: integration
        ref: scripts/maintainers/prune-stale-branches.test.sh
        status: fail
      - kind: integration
        ref: scripts/maintainers/prune-stale-branches.remote.test.sh
        status: pass
      - kind: unit
        ref: scripts/maintainers/prune-stale-branches.test.mjs
        status: pass
    human_judgment: false
duration: 84min
completed: 2026-09-28
status: halted
---

# Phase 245 Plan 12: Shared Ref Coordinator Summary

**Plan 12 produced a shared coordinator prototype, but direct symbolic-HEAD coverage differs by Git build. Local pruning remains fail-closed.**

## Performance

- **Duration:** approximately 84 minutes
- **Started:** 2026-09-28T13:15:04-04:00
- **Completed:** 2026-09-28T14:39:18-04:00
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments

- Added a Git-common-directory lock, atomic admission gate, transaction leases, owner token, and shared `reference-transaction` hook for branch refs and symbolic `HEAD` updates.
- Preserved and verified pre-existing hooks, checked every registered worktree's effective hook path, and made missing, stale, inconsistent, overridden, or unchainable state fail closed. Stale coordinator state is never reclaimed automatically.
- Wired local apply to the shared coordinator, then restored the D-05 fail-closed stop before `update-ref` when runtime hook coverage was not proven.
- Added fixtures for owner-authorized mutations, blocked worktree attachment, object retention, hook chaining, inventory enforcement, installer preflight, and Git-build-specific symbolic-HEAD behavior.

## Task Commits

1. **Task 1: Build and prove the shared coordinator** - `d004f1ed` (RED), `54848bb4` (GREEN)
2. **Task 2: Integrate the coordinator into local pruning** - `a173847c` (RED), `4d100ae4` (GREEN)
3. **Installer preflight hardening** - `80344931` (RED), `9002e6ce` (GREEN)

**Plan metadata:** `cf8fbed0` (plan); summary/state closeout follows.

## Validation

The prescribed disposable-repository suite passed on `/usr/bin/git` 2.50.1 after the fail-closed correction:

```text
bash -n [six coordinator/prune shell files]
bash scripts/maintainers/repo-mutation-coordinator.test.sh
bash scripts/maintainers/prune-stale-branches.test.sh
bash scripts/maintainers/prune-stale-branches.remote.test.sh
node --test --test-reporter=tap scripts/maintainers/prune-stale-branches.test.mjs
```

Coordinator, local fail-closed, and remote bare-origin fixtures passed. The prune TAP wrapper passed 11/11; the cleanup-audit TAP suite passed 29/29. The coordinator fixture reported `symbolic_head=gated-by-hook` on Git 2.50.1. On the active checkout's `/opt/homebrew/bin/git` 2.41.0, the same test reported `symbolic_head=bypassed-hook`; the installed hook does not provide the required guarantee on that build. The main checkout also cannot produce committed Phase 244 readiness because its prerequisite evidence remains dirty, so its integration fixture correctly refuses the stale/uncommitted receipt.

All mutations occurred in temporary repositories. The project checkout's coordinator was not installed, and no production branch, origin ref, pull request, or object store was changed.

## Decisions Made

- Keep the production checkout fail-closed until an operator explicitly installs and verifies the coordinator there; this plan installs it only in disposable fixtures.
- Treat unknown/stale lock or lease state as an operator-reconciliation requirement, never an automatic cleanup opportunity.

## Deviations from Plan

One in-scope safety refinement was added after review: installation now preflights every registered worktree before changing shared hook configuration, and refuses a per-worktree `core.hooksPath` override without publishing the hook. Its regression was recorded RED then GREEN. No other deviations.

## Issues Encountered

The plan's central acceptance gap remains open: Git 2.41.0 permits direct `git symbolic-ref HEAD` under the coordinator lock, while Git 2.50.1 blocks it. The coordinator installer does not yet perform a runtime capability probe, so the active build cannot safely enable local apply.

## Next Phase Readiness

Plan 12 does not close D-05 and is marked halted. The next GSD action is `$gsd-plan-phase 245 --gaps` to plan a per-build capability probe and preserve fail-closed behavior on unsupported Git. Phase 245 also retains 11 historical PR base mismatches and 30 unknown cleanup-history rows; Plans 245-04 and 245-09 remain halted, and REPO-04 stays open.

---
*Phase: 245-branch-prune-local-and-remote*
*Completed: 2026-09-28*
