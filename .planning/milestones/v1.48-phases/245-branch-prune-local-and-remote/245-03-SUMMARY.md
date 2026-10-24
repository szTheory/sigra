---
phase: 245-branch-prune-local-and-remote
plan: 03
subsystem: repository-maintenance
tags: [git, branch-pruning, exact-refs, github-prs, safety]
requires:
  - phase: 245-01
    provides: fail-closed exact-ref operator and fixture coverage
  - phase: 245-02
    provides: pinned inventories, readiness, complete PR capture, and required safety identities
provides:
  - Exhaustive keep/delete classification for all 111 local-head, local-tracking, and origin-head refs
  - Committed two-ref origin deletion allowlist with exact OID/type and reasons
  - Local no-op classification plus complete local-set and object-readability proofs
affects: [245-04, REPO-04]
actuals:
  tokens: 37909
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns:
    - Exact OID ancestry check against captured origin default plus bidirectional open-PR exclusions
key-files:
  created:
    - .planning/phases/245-branch-prune-local-and-remote/245-BRANCH-DELETE-ALLOWLIST.tsv
    - .planning/phases/245-branch-prune-local-and-remote/245-03-SUMMARY.md
  modified:
    - .planning/phases/245-branch-prune-local-and-remote/245-EVIDENCE.json
    - .planning/phases/245-branch-prune-local-and-remote/245-LOCAL-REFS.tsv
    - .planning/phases/245-branch-prune-local-and-remote/245-ORIGIN-REFS.tsv
    - .planning/phases/245-branch-prune-local-and-remote/245-OPEN-PR-STATE.json
    - .planning/phases/245-branch-prune-local-and-remote/245-02-SUMMARY.md
key-decisions:
  - "An origin branch is eligible only when its exact commit is an ancestor of the captured default-branch OID and no open PR, default-branch, or safety rule protects it."
  - "No empty local or tracking deletion pass is run; the local census has no eligible local heads and neither selected origin candidate has a matching local tracking ref."
  - "Orphaned and divergent tracking identities remain preserved because they are outside the exact paired deletion rows."
patterns-established:
  - "Classify every branch namespace with exact full ref, OID, type, and a fail-closed reason before mutation."
requirements-completed: []
coverage:
  - id: D1
    description: "All captured local-head, local-tracking, and origin-head refs are classified; the exact two-row remote allowlist is committed."
    requirement: REPO-04
    verification:
      - kind: other
        ref: "prune-stale-branches.sh verify-allowlist --snapshot-commit be3d3a7590be1a526139d80f0bcf00128f3969f2 --origin-commit be3d3a7590be1a526139d80f0bcf00128f3969f2"
        status: pass
      - kind: other
        ref: "prune-stale-branches.sh remote --allowlist-commit be3d3a7590be1a526139d80f0bcf00128f3969f2 (report-only; no --apply)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The local no-op is explicit and the committed local ref set and all direct/peeled objects remain intact."
    requirement: REPO-04
    verification:
      - kind: other
        ref: "prune-stale-branches.sh verify-local --snapshot-commit be3d3a7590be1a526139d80f0bcf00128f3969f2"
        status: pass
      - kind: other
        ref: "prune-stale-branches.sh verify-objects --snapshot-commit be3d3a7590be1a526139d80f0bcf00128f3969f2 --origin-commit be3d3a7590be1a526139d80f0bcf00128f3969f2"
        status: pass
    human_judgment: false
metrics:
  duration: 52min
  completed: 2026-09-27
  status: complete
---

# Phase 245 Plan 03: Commit Exact-Name Candidates and Prune Local Branches

**A complete 111-ref classification pins two merged origin candidates and proves the local ref set remains intact.**

## Performance

- **Duration:** 52 minutes
- **Started:** 2026-09-27T19:14:33Z
- **Completed:** 2026-09-27T20:05:43Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments

- Captured and committed 73 local refs, 359 origin refs, and all 13 open PR identities as the Wave 3 baseline. The inventory matches the post-safety-branch origin capture.
- Classified 3 local heads, 56 origin-tracking branches, and all 52 origin heads with exact refs, OIDs, types, and keep/delete reasons.
- Committed only two remote rows: `refs/heads/brandbook-rail-accent-logo-system` at `093a2a77b3ff13ea17a4cc2a2439a56ddf54c8cd` and `refs/heads/v1.37-auth-branding-admin-polish` at `b9cbb7a7b442f0d04b985c01c30a4a4db24a1d1f`. Both exact commits are ancestors of the captured `refs/heads/main` at `5a00b90d2314bc93f27aec4090b5928018743d1b`, and neither is an open PR head or base.
- Recorded no eligible local-head deletions and no matching tracking refs for the two origin candidates. No local, tracking, or origin ref changed in Wave 3. Unmerged, safety, open-PR, orphaned, and divergent identities remain preserved.
- Verified the committed inventory, D-01 readiness, D-04 safety refs, exact allowlist, current PR identities, local ref set, and all 73 local / 359 origin direct and peeled objects.
- Added a correction to the Plan 02 summary documenting the second required safety branch discovered during the exhaustive D-04 scan and its successful guarded publication/readback.

## Task Commits

1. **Task 1: Commit exact branch classification and allowlist** — `be3d3a75`.
2. **Task 2: Record local no-op and independent verification results** — `5b509fb2`.

**Plan metadata:** committed with this summary and position update.

## Files Created/Modified

- `245-BRANCH-DELETE-ALLOWLIST.tsv` — exact remote candidates; no empty local/tracking passes.
- `245-LOCAL-REFS.tsv`, `245-ORIGIN-REFS.tsv`, and `245-OPEN-PR-STATE.json` — current complete Wave 3 inputs.
- `245-EVIDENCE.json` — exhaustive classification, safety correction, pinned inputs, and verifier results.
- `245-POST-SAFETY-BRANCH-ORIGIN-REFS.tsv` and `245-POST-SAFETY-BRANCH-PR-STATE.json` — independent safety publication readbacks.
- `245-02-SUMMARY.md` — append-only correction to the earlier incomplete D-04 statement.
- `245-03-SUMMARY.md` — this plan result.

## Decisions Made

- Deletion eligibility requires exact ancestry to the captured default-branch OID, no open PR head/base dependency, and no default/safety protection.
- An empty local or tracking allowlist is recorded as a no-op; the helper is not invoked with an empty deletion set.
- Tracking refs without a corresponding selected remote deletion and divergent tracking identities remain unchanged.

## Deviations from Plan

None within Plan 03. Before classification, the exhaustive safety scan corrected a Plan 02 inventory gap by materializing and publishing the second required safety ref. The complete correction and readback are recorded in the Plan 02 follow-up section and `245-EVIDENCE.json`.

## Issues Encountered

The operator rejected one abbreviated commit ID with `snapshot_commit_invalid_oid` before any ref operation. The same verifier was rerun with the full 40-character committed SHA and passed. The live read-only remote guard took several minutes but completed successfully. The GSD roadmap updater skipped the visible Phase 245 row, so the plan checkbox and 3/4 progress row were aligned directly with STATE.md and state.json.

## User Setup Required

None — no external service configuration is required.

## Next Phase Readiness

Wave 3 is complete. Plan 04 is the only remaining plan in Phase 245. Its exact remote candidates and complete pre-prune snapshots are committed; Wave 4 must repeat its live PR/safety/access preflight before any origin deletion.

## Current Checkout Reconciliation (2026-09-29)

The task commit IDs listed above are not resolvable in the active checkout. The summary itself says no local, tracking, or origin ref changed in Wave 3 and that Plan 04 must still run before deletion. Its `requirements-completed` metadata is therefore empty; REPO-04 remains incomplete.

---
*Phase: 245-branch-prune-local-and-remote*
*Plan: 03*
*Completed: 2026-09-27*
