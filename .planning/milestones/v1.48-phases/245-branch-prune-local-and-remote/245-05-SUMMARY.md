---
phase: 245-branch-prune-local-and-remote
plan: 05
subsystem: repository-maintenance
tags: [git, bash, branch-safety, source-provenance, tdd]

# Dependency graph
requires:
  - phase: 244
    provides: verified completion and explicit dispositions for ref-dependent work
provides:
  - D-01 readiness receipt pinned to one committed Phase 244 source set and per-file blob identities
  - Fail-closed readiness validation in all four destructive apply modes, separate from live PR exclusion
  - Atomic local full-ref compare-and-delete with expected and observed OIDs on race failure
affects: [245-06, REPO-04]

# Actuals
actuals:
  tokens: 15977
  tasks: 2
  commits: 4

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Committed readiness predicates carry coherent source-commit and per-artifact blob provenance
    - Local ref deletion uses update-ref compare-and-delete with the preflight OID

key-files:
  created:
    - scripts/maintainers/prune-stale-branches-readiness.mjs
    - .planning/phases/245-branch-prune-local-and-remote/245-READINESS.json
  modified:
    - scripts/maintainers/prune-stale-branches.sh
    - scripts/maintainers/prune-stale-branches.test.mjs
    - scripts/maintainers/prune-stale-branches.test.sh
    - scripts/maintainers/prune-stale-branches.remote.test.sh

key-decisions:
  - "Keep Phase 244 readiness as a committed, source-pinned gate shared by all destructive modes; retain fresh live PR exclusion as a separate guard."
  - "Delete only the exact full local ref when its value still equals the OID accepted at preflight; report expected and observed identities and never retry."

patterns-established:
  - "Readiness fixtures use shared source clones and a local bare origin to exercise the live-PR guard without external calls."
  - "A ref-race fixture moves the target after preflight and asserts the moved ref and snapshotted objects remain readable."

requirements-completed: []
coverage:
  - id: D1
    description: "All destructive apply modes validate committed Phase 244 completion and ref-dependent dispositions from the source-pinned receipt."
    requirement: REPO-04
    verification:
      - kind: unit
        ref: "scripts/maintainers/prune-stale-branches.test.mjs#all apply modes fail closed for missing, dirty, stale, contradictory, and incomplete Phase 244 readiness inputs"
        status: pass
      - kind: other
        ref: "bash scripts/maintainers/prune-stale-branches.sh verify-readiness --repo <repo> --readiness-commit <full-commit>"
        status: pass
    human_judgment: false
  - id: D2
    description: "A local branch moved after preflight survives compare-and-delete, with expected and observed OIDs reported and snapshot objects readable."
    requirement: REPO-04
    verification:
      - kind: unit
        ref: "scripts/maintainers/prune-stale-branches.test.mjs#local compare-and-delete preserves a branch moved after preflight and keeps snapshotted objects readable"
        status: pass
      - kind: unit
        ref: scripts/maintainers/prune-stale-branches.test.sh
        status: pass
    human_judgment: false

duration: 18min
completed: 2026-09-27
status: complete
---

# Phase 245 Plan 05: Source-pinned readiness and local compare-and-delete

**Destructive branch operations now require committed Phase 244 readiness, and local deletion preserves any branch whose OID changes after preflight.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-09-27T23:59:21Z
- **Completed:** 2026-09-28T00:16:51Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added a machine-checked D-01 receipt that records one coherent Phase 244 source commit, each consumed artifact’s blob OID, parsed predicates, and blocked reasons. Missing, dirty, stale, contradictory, or incomplete sources fail closed.
- Applied the D-01 validator to local, tracking, remote, and safety-publication apply modes. The fresh live PR exclusion remains a separate guard.
- Replaced local `git branch -d` with `git update-ref -d <full-ref> <expected-oid>`. A race failure reports both expected and observed OIDs and does not retry.
- Added readiness and race fixtures. The unchanged eligible-branch fixture still deletes only its allowlisted ref and confirms object reachability.

## Task Commits

Each task followed a committed RED → GREEN sequence:

1. **Task 1: Pin D-01 readiness to the committed Phase 244 completion set** — RED `1df3f0b8` (`test(245-05): reject self-asserted prune readiness`); GREEN `be59dd0f` (`feat(245-05): pin pruning to committed Phase 244 readiness`).
2. **Task 2: Compare-and-delete the exact local ref per D-02** — RED `a40f399d` (`test(245-05): guard local compare-delete race`); GREEN `a3b2ad90` (`feat(245-05): add atomic local ref compare-delete`).

**Execution metadata:** `469638be` (`docs(245): start gap plan execution`).

## Files Created/Modified

- `scripts/maintainers/prune-stale-branches-readiness.mjs` — evaluates Phase 244 source predicates and emits/validates the pinned receipt.
- `scripts/maintainers/prune-stale-branches.sh` — gates all apply modes on readiness and compare-deletes the exact local ref by expected OID.
- `scripts/maintainers/prune-stale-branches.test.mjs` — adds forged, valid, invalid-source, and concurrent-ref-move coverage.
- `scripts/maintainers/prune-stale-branches.test.sh` and `scripts/maintainers/prune-stale-branches.remote.test.sh` — adapt fixtures to shared source clones with a local bare origin.
- `.planning/phases/245-branch-prune-local-and-remote/245-READINESS.json` — committed source-pinned D-01 receipt.

## Decisions Made

- Readiness stays bound to a single committed Phase 244 source set, with a separate blob identity for each source.
- Local compare failure is terminal. The operation reports the expected OID and the ref value observed after rejection, and never adopts a fresh OID for retry.

## Deviations from Plan

### Auto-fixed Issues

**1. Extracted the readiness evaluator into a dedicated module and adapted shell fixtures**
- **Found during:** Task 1 (readiness validator and fixtures)
- **Issue:** The source predicate parsing needed direct unit coverage, while the existing apply fixtures used a synthetic repository that could not exercise the live PR guard consistently.
- **Fix:** Added `prune-stale-branches-readiness.mjs`; updated the existing shell fixtures to use shared source clones and a local bare origin with a deterministic `gh` stub.
- **Files modified:** `scripts/maintainers/prune-stale-branches-readiness.mjs`, `scripts/maintainers/prune-stale-branches.test.sh`, `scripts/maintainers/prune-stale-branches.remote.test.sh`, `scripts/maintainers/prune-stale-branches.test.mjs`.
- **Verification:** Full Node fixture suite and targeted readiness tests passed.
- **Committed in:** `be59dd0f` (Task 1 GREEN commit).

---

**Total deviations:** 1 implementation-support adjustment (helper extraction and fixture adaptation).
**Impact on plan:** Required to test each readiness predicate and apply gate deterministically; no product scope added.

## Issues Encountered

- The new race test first demonstrated that `git branch -d` deleted a ref moved after preflight. Replacing it with expected-OID `git update-ref -d` made the test pass.
- The full Node regression run took about 3m48s because the local and remote fixture suites each execute a large repository scan; all tests passed.

## TDD Gate Compliance

- Task 1: RED commit `1df3f0b8` precedes GREEN commit `be59dd0f`; the RED evidence checker returned `RED_EVIDENCE_OK`.
- Task 2: RED commit `a40f399d` precedes GREEN commit `a3b2ad90`; `check tdd-red-evidence` returned `RED_EVIDENCE_OK`, then the focused test passed.
- No RED/GREEN gate violations.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 245-05 is complete. Plan 245-06 is the next gap-closure plan and depends on this plan’s readiness gate and compare-and-delete behavior.
- Continue the active `$gsd-execute-phase 245 --gaps-only` run with Plans 06–08. The halted original Plan 245-04 remains excluded. REPO-04 is still pending; Phase 245 verification and milestone-wide cleanup-history claims are deferred until the remaining gap plans complete.

---
*Phase: 245-branch-prune-local-and-remote*
*Completed: 2026-09-27*

## Self-Check: PASSED

- Summary file exists and parses successfully with `gsd-tools verify-summary`.
- All four RED/GREEN task commits are present in the current history.
