---
phase: 245-branch-prune-local-and-remote
plan: "22"
subsystem: testing
tags: [git, fetch, refs, object-preservation, tdd]

# Dependency graph
requires:
  - phase: 245-20
    provides: repaired current-contract transition used by the dependent retry
provides:
  - passing proof for exact object acquisition without local ref or FETCH_HEAD updates
  - mandatory fetch-isolation prerequisite for Plan 245-21
affects: [245-21, REPO-04]

# Actuals
actuals:
  tokens: 19877
  tasks: 2
  commits: 6

# Tech tracking
tech-stack:
  added: []
  patterns:
    - disposable mapped-origin fixtures compare complete refs, symbolic HEAD, and FETCH_HEAD bytes
    - exact-object acquisition is separated from tracking-ref mutation

key-files:
  created:
    - scripts/maintainers/verify-object-fetch-isolation.mjs
    - scripts/maintainers/verify-object-fetch-isolation.test.mjs
    - .planning/phases/245-branch-prune-local-and-remote/245-22-FETCH-PROOF.json
    - .planning/phases/245-branch-prune-local-and-remote/245-22-TASK1-RED-EVIDENCE.json
    - .planning/phases/245-branch-prune-local-and-remote/245-22-TASK1B-RED-EVIDENCE.json
  modified: []

key-decisions:
  - "Use a disposable bare origin and checkout with the normal configured fetch map; fetch the exact advertised object using an empty ref map and no destination."
  - "Require the old origin/gh-pages tracking OID, complete ref inventory, symbolic HEAD, and FETCH_HEAD bytes to remain unchanged while the new object becomes readable."
  - "Accept the superseded Plan 21 preflight-era digest only after revalidating its wave, Plan 20 and Plan 22 dependencies, and fetch-proof prerequisite; keep every other input and runtime pin exact."

patterns-established:
  - "A passing fetch proof records the complete before/after fixture state, not just the fetch exit code."
  - "A changed or missing ref, duplicate ref name, unreadable object, changed symbolic HEAD, or changed FETCH_HEAD blocks the proof."

requirements-completed: []

coverage:
  - id: D1
    description: "The exact advertised object becomes readable without changing local refs, symbolic HEAD, FETCH_HEAD, or the old tracking OID."
    requirement: REPO-04
    verification:
      - kind: unit
        ref: "scripts/maintainers/verify-object-fetch-isolation.test.mjs#configured origin fetch obtains the exact object without changing refs, symbolic HEAD or FETCH_HEAD in both states"
        status: pass
      - kind: other
        ref: "node scripts/maintainers/verify-object-fetch-isolation.mjs --output .planning/phases/245-branch-prune-local-and-remote/245-22-FETCH-PROOF.json plus the Plan 22 jq and dependency checks"
        status: pass
    human_judgment: false

# Metrics
duration: 21min
completed: 2026-09-30
status: complete
---

# Phase 245 Plan 22: Source-only exact-object fetch proof

**Disposable mapped-origin fixtures prove the exact object can be fetched while the old tracking ref, full ref inventory, symbolic HEAD, and FETCH_HEAD remain unchanged.**

## Performance

- **Duration:** 21 min
- **Started:** 2026-09-30T21:55:13Z
- **Completed:** 2026-09-30T22:15:49Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added a runner that creates and removes a disposable bare origin and checkout, then exercises the exact pinned Git fetch command against an advertised `gh-pages` object absent from the checkout.
- Verified both sentinel-present and absent `FETCH_HEAD` cases. Each case proves the object changed from unreadable to readable while all local ref rows, symbolic HEAD, FETCH_HEAD bytes or absence, and the original `origin/gh-pages` tracking OID remained unchanged.
- Revalidated all 29 pinned source records, the Git path/version/SHA-256, the prior Plan 21 receipt digests, and the Plan 21 dependency on this proof. No production ref operation occurred.

## Task Commits

1. **Task 1: Prove source-only object fetch in a disposable mapped-origin fixture**
   - RED `c4e3e9ca` — failing behavior and fail-closed expectations.
   - GREEN `4b127f1e` — fixture runner and primary proof checks.
   - RED `e3c56adb` — assert the old tracking-ref baseline explicitly.
   - GREEN `a60dbc9a` — enforce and record that baseline.
2. **Task 2: Record the proof and enforce Plan 21's retry dependency**
   - `fa23ad17` — passing machine-readable proof.

**Plan metadata:** committed separately after summary validation.

## Files Created

- `scripts/maintainers/verify-object-fetch-isolation.mjs` — validates preflight pins and runs two isolated exact-object fetch fixtures.
- `scripts/maintainers/verify-object-fetch-isolation.test.mjs` — checks both successful FETCH_HEAD states and blocked verdicts for failed or mutating cases.
- `.planning/phases/245-branch-prune-local-and-remote/245-22-FETCH-PROOF.json` — records runtime, source-pin checks, exact command, prior receipt identities, and full fixture comparisons.
- `.planning/phases/245-branch-prune-local-and-remote/245-22-TASK1-RED-EVIDENCE.json` and `245-22-TASK1B-RED-EVIDENCE.json` — validated RED evidence for both TDD cycles.

## Decisions Made

- The fixture advances its bare origin after cloning so the exact new object is demonstrably absent before fetch while the checkout retains the old tracking ref.
- Plan 21's current plan digest differs from the planning preflight's earlier digest. The proof records that mismatch as superseded only after confirming the current plan is wave 16, depends on Plans 20 and 22, and requires this proof. The remaining preflight inputs, all 29 committed pins, runtime identity, and prior receipt digests match.
- The historical 11-row PR mismatch and 30-row cleanup-history audit remain unresolved; this fixture does not resolve either.

## Deviations from Plan

The ready planning preflight captured Plan 21 before its Plan 22 dependency was added. The runner keeps this digest difference visible and accepts that one superseded input only when the current dependency checks pass. All other planning-input digests and every pinned source/runtime check remain exact.

## Issues Encountered

- The first RED-evidence record used field names the GSD checker does not accept. After converting it to the documented camelCase schema, both RED records returned `RED_EVIDENCE_OK` before their implementation commits.
- The first execution proof blocked on the stale Plan 21 digest. The runner was updated to preserve and validate that known dependency change rather than treating the old planning snapshot as current.

## TDD Gate Compliance

- Both RED runs failed the named fixture behavior assertion and passed `gsd-tools check tdd-red-evidence` with `RED_EVIDENCE_OK` before the corresponding GREEN commits.
- `node --test scripts/maintainers/verify-object-fetch-isolation.test.mjs` passed all 7 tests after implementation.
- The production proof and exact Plan 21 dependency checks passed; both fixture cases report zero ref, symbolic HEAD, and FETCH_HEAD changes.

## User Setup Required

None.

## Next Phase Readiness

Plan 21 can now begin its fresh retry preflight using this committed proof and the unchanged blocked receipts. It must rebaseline the current checkout and live sources before any contract or ref operation. REPO-04 remains open until Plan 21's independent gates pass. Plan 16 remains blocked by halted Plan 14, and the two historical audits remain unresolved.

---
*Phase: 245-branch-prune-local-and-remote*
*Completed: 2026-09-30*

## Self-Check: PASSED

- The summary verifies against the GSD schema.
- The runner, tests, proof, and both RED evidence records are present.
- Both RED evidence records pass the GSD classifier; the focused suite passes 7/7 tests.
- The two proof cases pass the exact object-readability, ref, tracking-ref, symbolic HEAD, and FETCH_HEAD invariants.
- All five task commits are present after the plan-head baseline; no production refs were changed.
