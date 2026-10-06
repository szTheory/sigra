---
phase: 245-branch-prune-local-and-remote
plan: 13
subsystem: infra
tags: [git, branch-pruning, worktrees, reference-transactions, runtime-capability]
requires:
  - phase: 245-branch-prune-local-and-remote
    provides: shared coordinator prototype and fail-closed local apply boundary
provides:
  - Exact-runtime symbolic-HEAD capability probe before coordinator install and verify
  - Local deletion gated by the verified shared coordinator lock and owner token
  - Supported and unsupported disposable runtime fixtures with object-retention proof
affects: [245-verification, branch-pruning, linked-worktrees]
actuals:
  tokens: 4265
  tasks: 2
  commits: 0
tech-stack:
  added: []
  patterns: [disposable runtime capability probe, runtime-gated ref mutation]
key-files:
  created:
    - .planning/phases/245-branch-prune-local-and-remote/245-13-TASK1-RED-EVIDENCE.json
    - .planning/phases/245-branch-prune-local-and-remote/245-13-TASK2-RED-EVIDENCE.json
  modified:
    - scripts/maintainers/repo-mutation-coordinator.sh
    - scripts/maintainers/repo-mutation-coordinator.test.sh
    - scripts/maintainers/repo-mutation-coordinator.test.mjs
    - scripts/maintainers/prune-stale-branches.sh
    - scripts/maintainers/prune-stale-branches.test.sh
    - scripts/maintainers/prune-stale-branches.test.mjs
    - .planning/phases/245-branch-prune-local-and-remote/245-VERIFICATION.md
key-decisions:
  - "Probe behavior of the exact Git executable; do not infer hook safety from a version string."
  - "Keep local apply fail-closed on the active Git 2.41.0 build and do not install the coordinator in the project checkout."
patterns-established:
  - "A direct symbolic-HEAD mutation must be rejected in a disposable linked-worktree fixture before install or verify trusts the coordinator."
  - "Local compare-and-delete requires a held coordinator lock and owner token through the expected-OID update-ref."
requirements-completed: []
coverage:
  - id: D1
    description: The exact runtime is probed before coordinator installation or verification.
    requirement: REPO-04
    verification:
      - kind: integration
        ref: scripts/maintainers/repo-mutation-coordinator.test.sh on Git 2.41.0 and Git 2.50.1
        status: pass
      - kind: integration
        ref: isolated cross-runtime install-then-verify fixture
        status: pass
    human_judgment: false
  - id: D2
    description: Local deletion is allowed only under a capability-proven shared coordinator and retains the snapshotted object.
    requirement: REPO-04
    verification:
      - kind: integration
        ref: scripts/maintainers/prune-stale-branches.test.sh on Git 2.41.0 and Git 2.50.1
        status: pass
      - kind: unit
        ref: scripts/maintainers/prune-stale-branches.test.mjs
        status: pass
    human_judgment: false
duration: 25min
completed: 2026-09-28
status: complete
---

# Phase 245 Plan 13: Runtime-Gated Local Pruning Summary

**The coordinator now proves symbolic-HEAD hook coverage for the current Git executable before trusting it, and local deletion proceeds only under that capability-proven lock.**

## Performance

- **Duration:** approximately 25 minutes
- **Started:** 2026-09-28T16:34:00-04:00
- **Completed:** 2026-09-28
- **Tasks:** 2
- **Commits:** 0

## Accomplishments

- Added a disposable linked-worktree probe that uses the current `git` on `PATH` and the exact reference-transaction hook. Installation and verification fail closed before trusting target repository state when direct symbolic `HEAD` changes bypass the hook.
- Replaced the unconditional local-delete stop with a required held coordinator lock and owner token. Existing readiness, PR, live-default, exact-ref/OID, merge-target, worktree-set, and protected-ref checks remain before `update-ref --no-deref -d`.
- Git 2.41.0 refused coordinator installation and local apply without changing the fixture's candidate ref or losing its snapshotted object.
- Git 2.50.1 passed the capability probe, deleted the unchanged eligible fixture branch with the expected-OID guard, rejected a competing worktree attach while the lock was held, and retained the snapshotted object.
- Verification of a fixture installed under Git 2.50.1 was separately rejected under Git 2.41.0; its installed fixture `core.hooksPath` stayed unchanged.
- Kept the active project checkout uninstalled and fail-closed. No project ref, linked-worktree registration, origin ref, PR, or Git configuration was changed.

## Validation

The integration tests ran from `/private/tmp/sigra-phase244-plan02-clone`, whose committed baseline at `9002e6ce5c3e28efc3893530954794694198b18f` contains the required Phase 244 source-commit ancestry. The current coordinator/prune source and test files were copied into that isolated checkout for execution. Each integration test created and removed its own disposable repository and temporary bare origin.

- `PATH=/opt/homebrew/bin:$PATH bash scripts/maintainers/repo-mutation-coordinator.test.sh` — passed; Git 2.41.0 rejected installation before target configuration or hook writes.
- `PATH=/usr/bin:$PATH bash scripts/maintainers/repo-mutation-coordinator.test.sh` — passed; Git 2.50.1 proved direct symbolic-HEAD hook coverage and the coordinator mutation fixtures.
- `PATH=/opt/homebrew/bin:$PATH bash scripts/maintainers/prune-stale-branches.test.sh` — passed; the candidate ref and snapshotted object remained intact.
- `PATH=/usr/bin:$PATH bash scripts/maintainers/prune-stale-branches.test.sh` — passed; the fixture deletion, concurrent-attach rejection, and object readback succeeded.
- Coordinator TAP wrapper — 1 passed, 0 failed, 0 skipped.
- Prune TAP wrapper — 11 passed, 0 failed, 0 skipped. It also exercised the remote bare-origin lease suite and malformed/stale/incomplete readiness cases.
- Cleanup-history TAP suite — 29 passed, 0 failed, 0 skipped; the 30 unknown ledger rows remain unresolved.
- Shell syntax checks passed for the coordinator, hook, prune operator, and shell fixtures.
- GSD plan-structure validation returned `valid` for Plan 13.

The red results are recorded in `245-13-TASK1-RED-EVIDENCE.json` and `245-13-TASK2-RED-EVIDENCE.json`. They document the Git 2.41 symbolic-HEAD bypass and the prior unconditional D-05 local-delete stop before the green implementation.

## Decisions Made

- Runtime behavior is the capability test; Git version text is reported only for evidence.
- Git 2.41.0 remains unsupported and fail-closed. The supported Git 2.50.1 result proves the isolated fixture path, not permission to install a coordinator or delete branches in the project checkout.
- The 11 historical PR base-OID disagreements and 30 unknown cleanup-history rows require separate authoritative evidence and remain untouched.

## Deviations from Plan

The readiness integration fixture ran from the existing isolated committed baseline. Copying the active checkout's Phase 244 files into a new commit would not restore the source commits named by their frontmatter and would fail the readiness ancestry contract. No evidence was rewritten to manufacture that lineage.

Changes remain uncommitted because the active checkout has extensive unrelated dirty files and the execution workflow's commit step would create a broader repository risk. Only the task files were edited; no files were staged.

**Total deviations:** 2. **Impact:** validation used the real committed readiness ancestry and all required runtime proofs passed; no production repository mutation or broad commit occurred.

## Issues Encountered

The initial supported-runtime probe exposed a Bash exit-trap bug: a local temp-path variable was no longer available when the trap ran. The probe now stores a subshell-scoped cleanup path, and the supported and unsupported capability fixtures pass.

## User Setup Required

None.

## Next Phase Readiness

Plan 13 is complete, but Phase 245 remains open. The active Git 2.41.0 checkout still refuses coordinator use; the supported result applies only to isolated fixtures. Eleven historical PR base identities and 30 cleanup-history rows remain unresolved, so REPO-04 must remain unchecked. Phase 245 is the final phase currently listed in the roadmap; do not infer a Phase 246 command.

---
*Phase: 245-branch-prune-local-and-remote*
*Completed: 2026-09-28*
