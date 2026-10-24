---
phase: 245-branch-prune-local-and-remote
plan: 23
subsystem: infra
tags: [git, readiness, evidence, phase-244, branch-pruning]

requires:
  - phase: 244
    provides: committed verification, final-main Playwright evidence, summaries, and resolved dependency records
provides:
  - Schema-2 Phase 244 readiness evidence that separates immutable source pins from current route observations
  - Regression coverage for schema-2 readiness, strict schema-1 behavior, and admission wiring
  - A verified readiness receipt and machine-readable handoff for Plan 245-24
affects: [phase-245, branch-pruning, readiness-admission]

actuals:
  tokens: 18645
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - Pin immutable evidence by commit, path, blob OID, and SHA-256 while observing mutable route metadata independently
    - Dispatch verification from the committed receipt schema to prevent worktree downgrade

key-files:
  created:
    - scripts/maintainers/prune-stale-branches-readiness.test.mjs
    - .planning/phases/245-branch-prune-local-and-remote/245-23-READINESS.json
    - .planning/phases/245-branch-prune-local-and-remote/245-23-RESULT.json
    - .planning/phases/245-branch-prune-local-and-remote/245-23-HANDOFF.json
  modified:
    - scripts/maintainers/prune-stale-branches-readiness.mjs
    - scripts/maintainers/prune-stale-branches-admission.test.mjs

key-decisions:
  - "Keep schema 1 as the default and preserve its strict historical receipt checks; schema 2 explicitly opts into separate route observations."
  - "Keep REPO-04 open and hand only the remaining Plan 21 Tasks 2-3 to Plan 245-24."

patterns-established:
  - "Readiness receipts pin immutable sources independently from mutable planning route metadata."
  - "Verifier behavior is selected from the committed artifact schema, so worktree edits cannot downgrade verification."

requirements-completed: []
coverage:
  - id: D1
    description: Schema-2 readiness capture and verification preserve all 36 Phase 244 predicates while recording exact current route identities.
    verification:
      - kind: unit
        ref: "node --test --test-concurrency=1 --test-reporter=spec scripts/maintainers/prune-stale-branches-readiness.test.mjs scripts/maintainers/prune-stale-branches-admission.test.mjs (26 passed)"
        status: pass
    human_judgment: false
  - id: D2
    description: The committed production readiness receipt verifies and the handoff references it without replaying halted work or pruning refs.
    verification:
      - kind: integration
        ref: "prune-stale-branches-readiness.mjs verify --repo . --artifact .planning/phases/245-branch-prune-local-and-remote/245-23-READINESS.json --artifact-commit e61432a0248824d14d942c7d4ae2fd428a81ae99 (valid, ready)"
        status: pass
      - kind: other
        ref: "245-23-RESULT.json and 245-23-HANDOFF.json assertions: zero prune operations, REPO-04 open, Plan 21 superseded, next plan 245-24"
        status: pass
    human_judgment: false

duration: 51min
completed: 2026-10-01
status: complete
---

# Phase 245 Plan 23 Summary

**Schema-2 readiness evidence now proves Phase 244 from immutable source pins while tracking current route metadata separately.**

## Performance

- **Duration:** 51 minutes
- **Started:** 2026-10-01T01:29:19.604Z
- **Completed:** 2026-10-01T02:20:19Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added opt-in schema-2 capture and verification while keeping schema 1 as the default with its original strict behavior.
- Pinned eight immutable evidence sources across source commit, artifact commit, HEAD, index, and worktree; recorded the `.planning/state.json` route identities independently across HEAD, index, and worktree; retained and re-evaluated all 36 readiness predicates.
- Added regression tests for route drift, fail-closed source changes, committed-schema dispatch, schema-1 compatibility, and the admission consumer path.
- Rechecked all 24 planning preflight pins, all 29 Plan 22 fetch-proof pins, Phase 244 evidence, the exact `/usr/bin/git` runtime, and the shared mutation coordinator before capturing a ready receipt.
- Committed and independently verified the schema-2 readiness receipt; recorded the route triplet and unchanged historical receipt hashes in the result and handed the remaining work to Plan 245-24.
- Performed zero production ref operations. REPO-04, the 11-row PR mismatch, and the 30-row cleanup-history audit remain unresolved.

## Task Commits

Each task was committed atomically:

1. **Task 1: Verify Phase 244 through pinned evidence and a separately observed current route** — `687073a7` (`feat(245-23): add schema-2 readiness evidence`).
2. **Task 2: Capture the replacement readiness receipt and hand off the halted retry** — `e61432a0` (readiness receipt), `064c40f6` (result and handoff).

**Plan metadata:** the final documentation commit contains this summary and GSD tracking metadata.

**Post-summary test harness follow-up:** `3676390f` raises the disposable admission fixture subprocess timeout from 30 to 60 seconds after a repeated full-suite run exceeded the old limit under load. This changes test timing tolerance only; production behavior is unchanged.

## Files Created/Modified

- `scripts/maintainers/prune-stale-branches-readiness.mjs` — schema-2 capture/verification and committed-schema dispatch.
- `scripts/maintainers/prune-stale-branches-readiness.test.mjs` — schema-2 route and failure regression cases.
- `scripts/maintainers/prune-stale-branches-admission.test.mjs` — admission wiring and exact readiness pin coverage.
- `.planning/phases/245-branch-prune-local-and-remote/245-23-READINESS.json` — committed schema-2 readiness receipt.
- `.planning/phases/245-branch-prune-local-and-remote/245-23-RESULT.json` — feasibility, evidence, route, and zero-operation result.
- `.planning/phases/245-branch-prune-local-and-remote/245-23-HANDOFF.json` — explicit continuation scope for Plan 245-24.

## Decisions Made

- Schema 1 remains the default so existing receipts retain their prior strict identity requirements; schema 2 must be requested explicitly.
- Mutable route metadata is recorded separately and cannot replace the committed Phase 244 verification and supporting evidence.
- Plan 21 remains halted and superseded. Plan 245-24 should reissue only Tasks 2-3 using the new readiness receipt; Plan 19's admitted deletion is counted once and neither Plan 19 nor Plan 21 is replayed.
- REPO-04 remains open until the remaining phase work and evidence are complete.

## Deviations from Plan

### Auto-fixed Issues

**1. Fail-closed committed-schema dispatch guard**
- **Found during:** Task 1 review of schema downgrade behavior.
- **Issue:** A modified worktree artifact could otherwise select schema-1 verification even when its committed receipt used schema 2.
- **Fix:** Select verifier behavior from the committed receipt schema and add a regression test for worktree downgrade.
- **Files modified:** `scripts/maintainers/prune-stale-branches-readiness.mjs`, `scripts/maintainers/prune-stale-branches-readiness.test.mjs`.
- **Verification:** Full prescribed suites passed with 26 tests and zero failures.
- **Committed in:** `687073a7`.

**2. Serialized disposable-repository test execution**
- **Found during:** Task 1 test execution.
- **Issue:** Default test concurrency stalled while tests created disposable Git repositories.
- **Fix:** Run both prescribed test files with `--test-concurrency=1` for deterministic completion.
- **Files modified:** None beyond the planned test changes.
- **Verification:** Both suites completed: 26 passed, 0 failed.

**3. Wider subprocess timeout for disposable admission fixtures**
- **Found during:** Post-summary verification.
- **Issue:** A tampered schema-2 admission case exceeded its 30-second subprocess limit in the combined rerun, although it passed in isolation.
- **Fix:** Increased the admission test helper's child-process timeout to 60 seconds; no sleeps or production code changes.
- **Files modified:** `scripts/maintainers/prune-stale-branches-admission.test.mjs`.
- **Verification:** The updated admission test file passed 6/6. The combined suite had passed 26/26 before this timeout-only adjustment; later combined and standalone readiness reruns were interrupted after producing no final summary.
- **Committed in:** `3676390f`.

**Total deviations:** 3 auto-fixed (1 correctness guard, 2 deterministic test invocation/harness adjustments).
**Impact on plan:** The changes support the planned fail-closed behavior and repeatable verification; the follow-up only widens the test harness timeout.

## Issues Encountered

- The sandbox initially denied the coordinator's `.git` write needed for the exact-path evidence commits. The reviewed escalation was approved; commits then succeeded under the shared coordinator with exact paths. Coordinator status returned free with zero transaction leases.
- A later combined test rerun did not produce a final summary after the readiness file began. It was interrupted; the updated admission file passed independently (6/6), and the unchanged readiness tests were covered by the earlier complete 26/26 run.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 245-23 is complete. Phase 245 remains active; do not run phase verification or mark the phase complete from this `--gaps-only` slice.
- Plan 245-24 is the next gap plan. It must reissue only Plan 21 Tasks 2-3 using the committed schema-2 readiness receipt and fresh D-06/current-source captures.
- Keep Plan 19's one admitted deletion counted once; do not replay Plan 19 or Plan 21. REPO-04 remains open, Plan 16 remains blocked by halted Plan 14, and the historical 11-row PR mismatch and 30-row cleanup-history audit remain unresolved.

## Self-Check: PASSED

- The schema-2 receipt's helper verification passed against its exact committed artifact identity.
- The 24-record preflight and 29-record Plan 22 fetch proof were rechecked; no production ref operation occurred.
- The result and handoff validations passed, including `REPO-04: open`, `prune_ref_operations: 0`, and `next_plan: 245-24`.
- The combined readiness/admission suite passed 26/26 at plan completion; after the test-only timeout follow-up, the admission suite passed 6/6. The later combined/readiness-only reruns were interrupted without a final report.
- Phase 245 post-wave schema, codebase-drift, and UI safety hooks passed or were explicitly skipped as inapplicable; no phase-level verification ran.
- The three task/evidence commits exist with exact intended paths, and preserved historical receipt hashes match.

---
*Phase: 245-branch-prune-local-and-remote*
*Completed: 2026-10-01*
