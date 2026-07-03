---
phase: 214-debt-robustness-clear
plan: "05"
subsystem: infra
tags: [ci, scripts, git-tags, hex, docs]

requires:
  - phase: 209-judgment-level-page-pass
    provides: persona-JTBD panel schema validator (panel-schema-check.sh) and code-review findings

provides:
  - panel-schema-check.sh retired with committed RETIRED rationale (D-05)
  - DEBT-02 todo closed (WR-01/WR-02/IN-02/IN-03/IN-04 all resolved)
  - git tag v1.20.0 deleted from local and remote (D-13)
  - guides/introduction/contract.md line 9 corrected from 1.20.0 to 1.1.0 (D-13)
  - Hex retire runbook documented for Jon (D-14)

affects: [hex-publishing, dependency-resolution, ci-debt]

tech-stack:
  added: []
  patterns:
    - "Retired scripts stay in-place with a RETIRED comment explaining the retire decision rather than being deleted"

key-files:
  created:
    - .planning/todos/resolved/2026-07-01-phase209-code-review-deferred.md
  modified:
    - scripts/ci/panel-schema-check.sh
    - guides/introduction/contract.md

key-decisions:
  - "DEBT-02 D-05: panel-schema-check.sh retired in-place (not deleted) with RETIRED banner; inputs are frozen v1.42 milestone deliverables that cannot be corrupted by future development"
  - "DEBT-02 D-06/D-07: IN-02/IN-03/IN-04 validator nits and WR-01 residual are won't-fix on the retired script"
  - "DEBT-04 D-13: git tag v1.20.0 deleted local and remote; contract.md line 9 corrected to 1.1.0"
  - "DEBT-04 D-14: mix hex.retire sigra 1.20.0 is a manual runbook step for Jon — cannot be automated in-phase (requires interactive Hex credentials)"

patterns-established:
  - "Retired CI scripts: keep file, add prominent RETIRED comment at top with date, decision phase, and rationale"

requirements-completed:
  - DEBT-02
  - DEBT-04

coverage:
  - id: D1
    description: "panel-schema-check.sh has RETIRED banner comment explaining why it is not wired into CI"
    requirement: DEBT-02
    verification:
      - kind: other
        ref: "grep -c RETIRED scripts/ci/panel-schema-check.sh → 1"
        status: pass
    human_judgment: false
  - id: D2
    description: "DEBT-02 todo (2026-07-01-phase209-code-review-deferred.md) moved to resolved/ with resolution note"
    requirement: DEBT-02
    verification:
      - kind: other
        ref: "ls .planning/todos/resolved/2026-07-01-phase209-code-review-deferred.md → exists"
        status: pass
    human_judgment: false
  - id: D3
    description: "git tag v1.20.0 deleted from local and remote"
    requirement: DEBT-04
    verification:
      - kind: other
        ref: "git tag -l v1.20.0 → empty; git ls-remote origin refs/tags/v1.20.0 → empty"
        status: pass
    human_judgment: false
  - id: D4
    description: "guides/introduction/contract.md line 9 corrected from 1.20.0 to 1.1.0"
    requirement: DEBT-04
    verification:
      - kind: other
        ref: "grep -c 1.20.0 guides/introduction/contract.md → 0; grep 1.1.0 shows corrected line"
        status: pass
    human_judgment: false
  - id: D5
    description: "mix hex.retire runbook documented in SUMMARY.md for Jon to run manually"
    requirement: DEBT-04
    verification: []
    human_judgment: true
    rationale: "Runbook content lives in this SUMMARY — human must confirm the prose is actionable and complete before running"

duration: 3min
completed: 2026-07-03
status: complete
---

# Phase 214 Plan 05: Debt & Robustness Clear — Script Retire + Version Wart Summary

**panel-schema-check.sh retired in-place with DEBT-02 rationale; git tag v1.20.0 deleted local+remote and contract.md corrected to 1.1.0; hex retire runbook documented for Jon**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-07-03T02:01:42Z
- **Completed:** 2026-07-03T02:04:32Z
- **Tasks:** 2
- **Files modified:** 3 (scripts/ci/panel-schema-check.sh, guides/introduction/contract.md, .planning/todos/resolved/2026-07-01-phase209-code-review-deferred.md)

## Accomplishments

- Retired `scripts/ci/panel-schema-check.sh` with a prominent RETIRED banner explaining the retire decision: the inputs are frozen v1.42 milestone deliverables (closed, archived) that cannot be corrupted by future development, making a CI guard over them meaningless (D-05)
- Closed the DEBT-02 todo: moved `2026-07-01-phase209-code-review-deferred.md` to resolved/ with a resolution note — WR-01 already resolved post-merge; WR-02 decided as retire; IN-02/IN-03/IN-04 won't-fix on retired script (D-06, D-07)
- Deleted git tag `v1.20.0` from both local and remote — the stray three-segment milestone tag that Hex misinterpreted as a package version, causing `{:sigra, "~> 1.0"}` to resolve to `1.20.0` instead of `1.1.0` (D-13)
- Corrected `guides/introduction/contract.md` line 9 from `1.20.0` to `1.1.0` (D-13)
- Documented the Hex retire runbook below for Jon to run manually (D-14)

## Task Commits

Each task was committed atomically:

1. **Task 1: Retire panel-schema-check.sh and close DEBT-02 todo** - `058d54e1` (chore)
2. **Task 2: Fix stray v1.20.0 version wart — delete git tag and correct contract.md** - `59c37a9a` (fix)

## Files Created/Modified

- `scripts/ci/panel-schema-check.sh` — RETIRED banner added at top explaining why script is not wired into CI and will not be (frozen deliverables, D-05)
- `guides/introduction/contract.md` — Line 9 corrected: `1.20.0` → `1.1.0` (D-13)
- `.planning/todos/resolved/2026-07-01-phase209-code-review-deferred.md` — Created (moved from pending/) with resolution note

## Hex Retire Runbook (Manual — Jon to run)

The git tag `v1.20.0` has been deleted from local and remote. The Hex registry still lists
`sigra 1.20.0` as a published version. To prevent Hex from resolving `{:sigra, "~> 1.0"}` to
`1.20.0` (which outranks `1.1.0` in Hex version ordering), retire it:

**1. Ensure you have Hex publishing credentials:**
```bash
mix hex.user auth
```

**2. Retire the version (retire, NOT delete — past the grace window for deletion):**
```bash
mix hex.retire sigra 1.20.0 invalid --message "Accidental milestone-version tag; correct version is 1.1.0"
```

**3. Verify retirement:**
```bash
mix hex.info sigra 1.20.0
# Should show "This package has been retired"
```

**Note:** Hex retire marks the version as retired/invalid without removing it. Future dependency
resolution will warn users not to use it and prefer other versions. This cannot be automated
in-phase because it requires interactive Hex credentials.

## Decisions Made

- D-05: Retire `panel-schema-check.sh` in-place with a RETIRED banner comment rather than deleting the file — keeping it documents the retire decision and makes it auditable
- D-06/D-07: IN-02/IN-03/IN-04 validator nits and WR-01 residual are all won't-fix on the retired script — no work required
- D-13: Delete `v1.20.0` git tag (local and remote) and correct `contract.md` line 9 — both automatable in-phase
- D-14: `mix hex.retire sigra 1.20.0` is a manual runbook step for Jon — cannot be automated (requires interactive Hex credentials); DEBT-04 is marked resolved with this runbook tracked

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

**Jon must run the Hex retire command manually.** See the "Hex Retire Runbook" section above.

The git tag deletion is complete (automated). The Hex registry retire requires interactive credentials:
```bash
mix hex.retire sigra 1.20.0 invalid --message "Accidental milestone-version tag; correct version is 1.1.0"
```

## Next Phase Readiness

- DEBT-02 and DEBT-04 closed; Phase 214 all 5 plans complete
- DEBT-01 (Oban enqueue guard) resolved in Phase 214 Plan 01
- DEBT-03 (Phase-200 code-review items) resolved in Phase 214 Plan 02/03
- DEBT-05 (app.css orphaned comment corruption) resolved in Phase 214 Plan 04
- HEALTH-03 (spurious mix test failures) resolved in Phase 214 Plan 04
- Phase 214 is complete; Phase 215 (Terminal Ratification) is next

## Self-Check

- [x] `grep -c "RETIRED" scripts/ci/panel-schema-check.sh` → 1 (FOUND)
- [x] `git tag -l "v1.20.0"` → empty (FOUND — tag deleted)
- [x] `grep -c "1.20.0" guides/introduction/contract.md` → 0 (FOUND — no stale ref)
- [x] `.planning/todos/resolved/2026-07-01-phase209-code-review-deferred.md` → exists (FOUND)
- [x] Commit `058d54e1` exists
- [x] Commit `59c37a9a` exists

## Self-Check: PASSED

---
*Phase: 214-debt-robustness-clear*
*Completed: 2026-07-03*
