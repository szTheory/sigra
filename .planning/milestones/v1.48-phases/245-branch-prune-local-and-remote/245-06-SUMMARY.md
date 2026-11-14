---
phase: 245-branch-prune-local-and-remote
plan: 06
subsystem: repository-maintenance
tags: [git, remote-refs, force-with-lease, tap, tdd]

# Dependency graph
requires:
  - phase: 245-05
    provides: committed Phase 244 readiness gate and local expected-OID compare-and-delete
provides:
  - Expected-OID lease for origin branch deletion and expected-absence lease for safety publication
  - Terminal race diagnostics with expected and observed identities and no retry
  - Complete 11-test local and remote fixture TAP transcript with each suite run once
affects: [245-07, REPO-04]

# Actuals
actuals:
  tokens: 4907
  tasks: 2
  commits: 4

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Exact remote destination leases close check-then-push races
    - Top-level Node TAP runner owns one invocation of each shell fixture suite and preserves their output as TAP diagnostics

key-files:
  created:
    - .planning/phases/245-branch-prune-local-and-remote/245-GAP-CODE-TESTS.tap
  modified:
    - scripts/maintainers/prune-stale-branches.sh
    - scripts/maintainers/prune-stale-branches.remote.test.sh
    - scripts/maintainers/prune-stale-branches.test.sh
    - scripts/maintainers/prune-stale-branches.test.mjs

key-decisions:
  - "Bind origin deletion to the exact full destination ref and allowlisted OID with force-with-lease; a lease rejection is terminal."
  - "Publish an absent safety ref with an empty expected value lease; never overwrite or retry after a concurrent creation."
  - "Keep the saved TAP transcript at the top-level Node runner, with each local/remote suite invoked once and its fixture logs attached as diagnostics."

patterns-established:
  - "Race shims mutate the bare origin only at the real push boundary and bypass dry-run preflight commands."
  - "Lease failures report expected and observed identities; the TAP transcript retains those failures as successful negative-control evidence."

requirements-completed: []
coverage:
  - id: D1
    description: "Remote deletion and safety publication reject concurrent origin changes atomically and leave the concurrent values intact without retry."
    requirement: REPO-04
    verification:
      - kind: integration
        ref: scripts/maintainers/prune-stale-branches.remote.test.sh
        status: pass
      - kind: other
        ref: .planning/phases/245-branch-prune-local-and-remote/245-GAP-CODE-TESTS.tap
        status: pass
    human_judgment: false
  - id: D2
    description: "The complete local and remote fixture matrix runs once per suite and is saved as valid TAP with 11 passes, zero failures, and zero skips."
    requirement: REPO-04
    verification:
      - kind: unit
        ref: "scripts/maintainers/prune-stale-branches.test.mjs#top-level prune runner invokes local and remote suites once without nesting"
        status: pass
      - kind: other
        ref: "node --test --test-reporter=tap scripts/maintainers/prune-stale-branches.test.mjs"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-09-27
status: complete
---

# Phase 245 Plan 06: Leased remote mutations and complete fixture evidence

**Origin branch deletion now requires the reviewed OID, safety publication requires absence, and the single-run TAP artifact proves both race protections.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-09-28T00:23:02Z
- **Completed:** 2026-09-28T00:43:16Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added an exact `--force-with-lease=<full-ref>:<expected-oid>` to remote branch deletion and an absent-only `--force-with-lease=<full-ref>:` to safety publication.
- Added bare-origin race fixtures. A concurrent safety-ref creation and an advanced deletion target each remain intact after one terminal lease rejection; diagnostics record expected and observed values.
- Removed the remote fixture invocation nested inside the local shell suite. The top-level runner owns exactly one invocation of each suite.
- Saved the full top-level test output at `245-GAP-CODE-TESTS.tap`. It contains 11 passing TAP tests, zero failures, zero skips, and the shell fixture outputs as TAP diagnostics.

## Task Commits

Each task followed a committed RED → GREEN sequence:

1. **Task 1: Lease-protect origin deletion and absent-only safety publication** — RED `2f8f5036` (`test(245-06): guard origin ref lease races`); GREEN `71070404` (`feat(245-06): lease remote ref mutations`).
2. **Task 2: Run every local and remote fixture once and save complete TAP** — RED `9aee5906` (`test(245-06): assert each prune fixture suite runs once`); GREEN `817ba454` (`feat(245-06): capture complete prune fixture TAP`).

## Files Created/Modified

- `scripts/maintainers/prune-stale-branches.sh` — leases origin deletion to the exact ref/OID and safety publication to remote absence; records expected and observed identities on rejection.
- `scripts/maintainers/prune-stale-branches.remote.test.sh` — races a concurrent safety-ref creation and remote-ref advance at the actual push boundary and proves one push attempt per rejected lease.
- `scripts/maintainers/prune-stale-branches.test.sh` — leaves the remote suite to the top-level runner.
- `scripts/maintainers/prune-stale-branches.test.mjs` — checks suite ownership/count and embeds fixture output in TAP diagnostics.
- `.planning/phases/245-branch-prune-local-and-remote/245-GAP-CODE-TESTS.tap` — complete passing run evidence.

## Decisions Made

- The remote lease is based on the explicit reviewed OID, not a tracking ref or an implicitly selected remote-tracking value.
- An absent-only lease protects safety publication even if a concurrent ref points to an ancestor that a normal push could fast-forward.
- The TAP file includes the successful shell fixture output so the remote race outcomes are inspectable from the one top-level run.

## Deviations from Plan

None - followed the plan as written. The test runner also gained a small source-level invariant asserting one top-level call per suite, which directly verifies the plan’s single-run requirement.

## Issues Encountered

- The race shim initially intercepted the dry-run preflight rather than the mutating push. It was corrected to exclude `--dry-run`, and the RED run then reproduced an actual unleased update of the concurrent safety ref before the leases were added.
- The post-plan GSD route update changed `.planning/state.json`, one of the D-01 pinned inputs. The existing readiness receipt correctly failed closed; after committing the state/roadmap updates, readiness was recaptured as `ready` against coherent source commit `7257f232a38591b0044f1b929bba1fc2e9fa83da` with all nine sources pinned.

## TDD Gate Compliance

- Task 1: RED `2f8f5036` precedes GREEN `71070404`; `check tdd-red-evidence` returned `RED_EVIDENCE_OK`. The RED output shows the unleased push changed the newly created remote safety ref to the local source OID.
- Task 2: RED `9aee5906` precedes GREEN `817ba454`; `check tdd-red-evidence` returned `RED_EVIDENCE_OK`. The targeted suite-ownership check passed after removing the nested invocation.
- The final full-run artifact contains 11 passed tests, no failures, and no skipped tests.
- No RED/GREEN gate violations.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 245-06 is complete. Plan 245-07 is next and can use the D-01 readiness gate, local compare-delete, remote leases, and complete test transcript.
- Continue the active `$gsd-execute-phase 245 --gaps-only` run. Plans 245-07 and 245-08 remain; original Plan 245-04 remains halted and excluded. REPO-04 stays pending until final identity audit and phase verification.

---
*Phase: 245-branch-prune-local-and-remote*
*Completed: 2026-09-27*

## Self-Check: PASSED

- Summary parses with `gsd-tools verify-summary`.
- All four RED/GREEN task commits are present, and the saved TAP artifact is nonempty.
