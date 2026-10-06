---
phase: 245-branch-prune-local-and-remote
plan: 48
subsystem: repository-audit
tags: [git, github, pr-identity, historical-provenance, repo-04]
requires:
  - phase: 245-46
    provides: D-06 planning preflight for the pinned historical commit and blobs
  - phase: 245-17
    provides: D-07 local Git and GitHub source preflight
provides:
  - Bounded negative source proof for the pinned historical PR baseline
  - Eleven unresolved PR-base identity rows with exact source blockers
affects: [245-verification, REPO-04]
tech-stack:
  added: []
  patterns: ["Historical identity rows require pinned source objects and independent contemporaneous corroboration"]
key-files:
  created:
    - .planning/phases/245-branch-prune-local-and-remote/245-48-SOURCE-GATE.json
    - .planning/phases/245-branch-prune-local-and-remote/245-48-RESULT.json
    - .planning/phases/245-branch-prune-local-and-remote/245-48-SUMMARY.md
  modified: []
key-decisions:
  - "Keep all eleven historical PR-base identity rows unresolved because the pinned commit and two blobs remain unavailable in the recorded D-06 source check."
  - "Keep REPO-04 open and require a new D-06 gate if historical source availability changes."
requirements-completed: []
actuals:
  tokens: 6736
  tasks: 2
  commits: 2
commits: 2
plan_head_before: 1788f29a4bdd8fedd9b66080e86f2fb09fc9dd6e
plan_head_after: e97fb4049550d37f63a1caff889f337c55268c7a
duration: 4min
completed: 2026-10-05
status: complete
---

# Phase 245 Plan 48: Historical PR Source Gate Summary

The recorded D-06 preflight leaves the pinned historical commit and both baseline blobs unavailable, so all 11 PR-base identity rows remain unresolved and REPO-04 stays open.

## Performance

- **Started:** 2026-10-05T22:27:42Z
- **Completed:** 2026-10-05T22:31:46Z
- **Tasks:** 2
- **Files created:** 3
- **Task commits:** 2, measured from the persisted plan ledger

## Accomplishments

- Wrote `245-48-SOURCE-GATE.json` from the committed Plan 46 preflight. It records local `git cat-file -t` exit 128 and GitHub Git API HTTP 404 for commit `9c0a6b818d2d58858b5db274cc1cf0a9803f69f5` and blobs `913e4d0ab10cfa3b4fb42bd4d347d47f5832dc85` and `eb9f3fa848e41578bd6f6d03d375f66207bbc8e9`. No local or GitHub source search was repeated.
- Used PR #219 as the representative gate. Its old recorded base identity cannot be promoted without the pinned historical blobs and independently pinned contemporaneous corroboration of its number, base ref, and base OID.
- Wrote `245-48-RESULT.json` with rows for PR #219 and #266–275. Each row retains its recorded `main` base OID, the old audit disposition, the exact missing source identities, and `disposition=unresolved` with reason `missing_authoritative_historical_commit_and_blobs`.

## Evidence and Scope

The source gate cites the Plan 46 preflight captured at `2026-10-05T20:56:57Z`, plus Plan 14's baseline blocker and Plan 17's source preflight. Its GitHub endpoint fields name the Git commit/blob routes corresponding to the preflight's recorded 404 outcomes. The old integrity audit records the historical row keys, but its current PR and `main` observations are not historical corroboration.

The old audit files remained byte-identical. SHA-256 digests before and after execution:

| Audit | SHA-256 |
|---|---|
| `245-PR-IDENTITY-AUDIT.json` | `5aad409061ed3b28820e3c37873dfabf701759b8725538e671cac790a18abec3` |
| `245-PR-INTEGRITY-VERIFICATION.json` | `8861d39a207145892ce2d95180d8a244b8d077915f6aea9df34e82ab1d0d9e35` |

No PR, ref, object-cleanup, or package operation occurred. The 30-row cleanup-history audit and Plan 47's live admission are separate unresolved work. This plan does not complete Phase 245.

## Verification

- The plan's Task 1 jq acceptance gate passed: pinned commit, two blobs, statuses, representative PR #219, missing provenance, and zero repeated searches.
- The plan's Task 2 jq acceptance gate passed: exactly 11 required PR numbers, all `main` refs and 40-character base OIDs, all unresolved, zero PR/ref mutations, and REPO-04 open.
- An additional jq comparison matched every result row's number, base ref/OID, and prior disposition to the old integrity audit; every row cited the gate's exact three pinned OIDs.
- The two old audit SHA-256 digests matched before and after task commits.

## Task Commits

1. **Task 1: Gate one historical row on its actual pinned source** — `946a7f39` (`docs`)
2. **Task 2: Classify all 11 rows from the source gate** — `e97fb404` (`docs`)

## Decisions Made

The pinned sources remain the only accepted historical baseline. Current PR or `main` ref state cannot establish past base identity. Any changed source state needs a new D-06 gate under the existing acceptance contract.

## Deviations from Plan

None. The blocked result is the plan's specified outcome when the pinned sources remain unavailable.

## Known Stubs

None. The unresolved rows and missing provenance are explicit evidence outcomes.

## Next Phase Readiness

REPO-04 remains open. The 11 historical PR-base rows need the pinned commit, both blobs, and independent contemporaneous corroboration before any row can be resolved. Phase 245 remains in progress.

## Self-Check: PASSED

All three declared files exist. Both task commits exist, and the persisted plan ledger measures two commits. The old audit SHA-256 digests match their recorded values.
