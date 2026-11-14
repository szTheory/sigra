---
phase: 245-branch-prune-local-and-remote
plan: "17"
subsystem: git-maintenance
tags: [git, branch-pruning, github, tdd, admission]
requires:
  - phase: 245-13
    provides: source-pinned Phase 244 readiness and guarded local ref operations
  - phase: 244
    provides: committed Playwright measurement and readiness evidence
provides:
  - Immutable current PR/ref contract and per-mutation verification for the D-07 path
  - Local admission verifier that rejects missing source-backed readiness before coordinator setup or ref mutation
  - Disposable fixtures for current PR/ref drift and admission no-mutation proofs
affects: [245-18, 245-19, branch-pruning]
actuals:
  tokens: 49404
  tasks: 3
  commits: 6
plan_head_before: edee9e9f060e4e93a460d4221879be82ccbe1000
tech-stack:
  added: [Node.js ESM admission verifier]
  patterns: [committed-input blob and SHA-256 pins, exact-ref mutation boundaries, fail-closed readiness admission]
key-files:
  created:
    - scripts/maintainers/prune-stale-branches-admission.mjs
    - scripts/maintainers/prune-stale-branches-admission.test.mjs
    - .planning/phases/245-branch-prune-local-and-remote/245-17-SOURCE-PREFLIGHT.json
  modified:
    - scripts/maintainers/prune-stale-branches-current.mjs
    - scripts/maintainers/prune-stale-branches-current.test.mjs
    - scripts/maintainers/prune-stale-branches.sh
    - scripts/maintainers/prune-stale-branches.test.mjs
    - scripts/maintainers/prune-stale-branches.test.sh
    - scripts/maintainers/prune-stale-branches.remote.test.sh
key-decisions:
  - "Keep production local apply fail-closed while the pinned Phase 244 readiness source commit is unavailable."
  - "Treat the current source preflight as D-07 evidence only; do not use it to close the unresolved historical PR or cleanup audits."
patterns-established:
  - "Verify committed artifact bytes by full commit, path, Git blob, and SHA-256 before using them as mutation authority."
  - "Reject missing readiness evidence before live remote checks or coordinator setup, and persist no-mutation equality in blocked receipts."
requirements-completed: []
coverage:
  - id: D1
    description: Current PR and origin-ref observations are committed, independently refreshed, and guarded around each mutation.
    verification:
      - kind: integration
        ref: "node --test scripts/maintainers/prune-stale-branches-current.test.mjs (3/3 passed)"
        status: pass
      - kind: integration
        ref: "bash scripts/maintainers/prune-stale-branches.test.sh and bash scripts/maintainers/prune-stale-branches.remote.test.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: Local current-mode admission blocks the unavailable Phase 244 source before coordinator setup and ref mutation.
    verification:
      - kind: integration
        ref: "node --test scripts/maintainers/prune-stale-branches-admission.test.mjs scripts/maintainers/prune-stale-branches.test.mjs (13/13 passed)"
        status: pass
      - kind: unit
        ref: "bash -n scripts/maintainers/prune-stale-branches.sh; node --check admission verifier and test"
        status: pass
    human_judgment: false
duration: 88min
completed: 2026-09-29
status: complete
---

# Phase 245 Plan 17: Current PR/ref contract and local admission Summary

**The D-07 current-state path now verifies committed PR/ref evidence at mutation boundaries, while production local deletion stops on the unavailable source-backed Phase 244 readiness commit.**

## Performance

- **Duration:** 88 minutes
- **Started:** 2026-09-29T19:09:09Z
- **Completed:** 2026-09-29T20:37:49Z
- **Tasks:** 3
- **Files modified:** 13

## Accomplishments

- Added a current-state PR and origin-ref contract that does not depend on the unavailable historical 9c0a6b81 baseline or its 11 base-OID equalities.
- Routed current-mode local, remote, tracking, and safety operations through committed evidence checks before and after exact mutations.
- Added local admission over the committed current contract, snapshots, allowlist, and readiness artifact. The pinned readiness source `7257f232a38591b0044f1b929bba1fc2e9fa83da` is unavailable, so production local apply blocks before coordinator setup and any ref change.
- Preserved the historical PR mismatch and cleanup-history records as unresolved. `REPO-04` remains unchecked; Plan 17 performed no production ref mutation.

## Task Commits

1. **Task 1: Prove one current PR/ref capture through immutable verification** — `bb12f46f` (test), `51475e38` (feat)
2. **Task 2: Put current observations on every mutation path** — `9c96c6d4` (test), `21bb8e70` (feat)
3. **Task 3: Admit production local deletion only under shared coordination** — `c84bd75c` (test), `a640833c` (fix)

## Files Created/Modified

- `scripts/maintainers/prune-stale-branches-current.mjs` — captures and verifies committed current PR/ref observations.
- `scripts/maintainers/prune-stale-branches-current.test.mjs` — exercises complete and drifted current-contract fixtures.
- `scripts/maintainers/prune-stale-branches.sh` — guards each current-mode mutation and checks local admission before coordinator setup.
- `scripts/maintainers/prune-stale-branches-admission.mjs` — checks pinned inputs, D-01 readiness, candidate identity, runtime, and coordinator state.
- `scripts/maintainers/prune-stale-branches-admission.test.mjs` — proves the missing-source branch blocks without coordinator or ref changes.
- `scripts/maintainers/prune-stale-branches.test.mjs`, `scripts/maintainers/prune-stale-branches.test.sh`, and `scripts/maintainers/prune-stale-branches.remote.test.sh` — disposable local and bare-origin regression fixtures.
- `.planning/phases/245-branch-prune-local-and-remote/245-17-SOURCE-PREFLIGHT.json` — records the ready current checkout/GitHub/origin source preflight.

## Verification

- `node --test scripts/maintainers/prune-stale-branches-current.test.mjs` — 3/3 passed.
- `bash scripts/maintainers/prune-stale-branches.test.sh` — passed, including the supported-runtime local deletion fixture, competing-worktree rejection, and snapshot object proof.
- `bash scripts/maintainers/prune-stale-branches.remote.test.sh` — passed all 12 audit subtests and its exact-ref, lease, safety, and readback scenarios.
- `node --test scripts/maintainers/prune-stale-branches-admission.test.mjs scripts/maintainers/prune-stale-branches.test.mjs` — 13/13 passed in 429 seconds.
- `node --check` on the admission verifier and test, `bash -n` on the operator and local shell suite, and `git diff --check` — passed.
- The blocked receipt names `d01_readiness_source_commit_unavailable:7257f232a38591b0044f1b929bba1fc2e9fa83da` and records identical refs, worktrees, and repository config before and after admission. The local `--apply` fixture reports the same blocker and leaves the candidate unchanged.

## Decisions Made

- Keep local production apply fail-closed until the readiness receipt can authenticate its cited Phase 244 source commit.
- Keep the D-07 current-state contract separate from unresolved historical records; a passing current fixture cannot close `REPO-04`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Repaired disposable Phase 244 source fixtures**
- **Found during:** Task 2 verification
- **Issue:** The test repositories contained a readiness JSON that cited a source commit without the required committed Phase 244 source blobs, so valid fixture paths failed the production fail-closed validator.
- **Fix:** Updated the disposable fixtures to commit the required source blobs and readiness predicates; left the production readiness validator unchanged.
- **Files modified:** `scripts/maintainers/prune-stale-branches.test.mjs`, `scripts/maintainers/prune-stale-branches.test.sh`, `scripts/maintainers/prune-stale-branches.remote.test.sh`
- **Verification:** Current-contract tests and both local and remote shell suites passed; the full local Node wrapper later passed as part of the 13-test Task 3 command.
- **Committed in:** `21bb8e70`

**2. [Rule 1 - Bug] Fixed admission CLI stage duplicate detection**
- **Found during:** Task 3 GREEN
- **Issue:** The default `admission` stage was mistaken for an explicitly supplied `--stage`, rejecting the verification command before checking readiness.
- **Fix:** Track only explicitly supplied CLI arguments when detecting duplicates.
- **Files modified:** `scripts/maintainers/prune-stale-branches-admission.mjs`
- **Verification:** Admission fixture and full declared Task 3 command passed.
- **Committed in:** `a640833c`

### Verification Runtime Deviation

The Task 2 combined `current.test.mjs` plus local `.test.mjs` invocation did not finish in its initial runner window. The current-contract suite passed 3/3 separately; focused local cases and shell suites passed, and the exact local Node wrapper completed later within the Task 3 acceptance command. The Task 3 combined command completed in 429 seconds with 13/13 passing tests.

**Total deviations:** 2 auto-fixed issues; 1 earlier combined-runner delay resolved by constituent and later full local-wrapper runs.
**Impact on plan:** No production gate was weakened, and all Plan 17 task acceptance evidence is available.

## Issues Encountered

- The repository contains a `status: ready` Phase 244 readiness artifact whose cited source commit is absent from this checkout. Admission correctly treats the artifact as unauthenticated and blocks; no coordinator was installed in the failing fixture.
- The active Git runtime and complete mutation-entrypoint pinning were not proven by Plan 17. The admission gate remains fail-closed, leaving local production deletion for a later plan after its gates pass.
- The GSD roadmap progress handler returned `missing_phase_details` even though Phase 245 has a roadmap section. Updated only Plan 17's checklist item and the Phase 245 progress row manually; unrelated pre-existing planning edits remain untouched and unstaged.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 18 may capture the fresh committed snapshot inputs required by Plan 19.
- Plan 19 must retain the source-backed D-01 blocker and must not mutate production refs unless its own complete admission gates pass.
- `REPO-04` remains unchecked, and the historical 11-row PR mismatch and 30-row cleanup-history audits remain unresolved.

## Self-Check: PASSED

- Summary file exists at the required phase path.
- All six task commit hashes are present in repository history.
- No placeholder, TODO, or FIXME stubs were found in Plan 17 changed implementation and fixture files.

---
*Phase: 245-branch-prune-local-and-remote*
*Completed: 2026-09-29*
