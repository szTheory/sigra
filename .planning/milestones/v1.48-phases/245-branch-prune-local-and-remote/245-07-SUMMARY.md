---
phase: 245-branch-prune-local-and-remote
plan: 07
subsystem: infra/testing
tags: [github, git, ref-safety, pr-identity]
requires:
  - phase: 245-06
    provides: Exact remote ref leases and committed readiness inputs
provides:
  - A pinned live audit for the 11 historical PR base mismatches
  - A fresh verify-prs integrity result with exact command and exit status
affects: [245-08, REPO-04, branch-pruning]
actuals:
  tokens: 18000
  tasks: 2
  commits: 5
tech-stack:
  added: []
  patterns: [Read-only paginated PR identity audit, GitHub API plus exact git ls-remote corroboration]
key-files:
  created:
    - scripts/maintainers/prune-stale-branches-pr-audit.mjs
    - scripts/maintainers/prune-stale-branches-pr-audit.test.mjs
    - .planning/phases/245-branch-prune-local-and-remote/245-07-RED-EVIDENCE.json
    - .planning/phases/245-branch-prune-local-and-remote/245-PR-IDENTITY-AUDIT.json
    - .planning/phases/245-branch-prune-local-and-remote/245-PR-INTEGRITY-VERIFICATION.json
  modified:
    - scripts/maintainers/prune-stale-branches.sh
    - scripts/maintainers/prune-stale-branches.remote.test.sh
key-decisions:
  - "Only the exact 11 baseline-derived historical base mismatches can receive an equality exception, and only when current PR detail, complete inventory, exact GitHub refs, and git ls-remote agree."
  - "Keep all 11 rows unresolved when PR base metadata disagrees with the authoritative current main ref; ancestry does not resolve identity."
patterns-established:
  - "Record current PR identity, pagination, API ref, and ls-remote provenance in separate immutable audit and integrity artifacts."
requirements-completed: []
coverage:
  - id: D1
    description: "A pinned audit records all 11 historical mismatches and their current identity evidence or specific unresolved reasons."
    requirement: REPO-04
    verification:
      - kind: unit
        ref: "node --test scripts/maintainers/prune-stale-branches-pr-audit.test.mjs"
        status: pass
      - kind: integration
        ref: "bash scripts/maintainers/prune-stale-branches.remote.test.sh"
        status: pass
      - kind: other
        ref: "node scripts/maintainers/prune-stale-branches-pr-audit.mjs validate --audit .planning/phases/245-branch-prune-local-and-remote/245-PR-IDENTITY-AUDIT.json"
        status: pass
    human_judgment: false
  - id: D2
    description: "A fresh PR integrity result binds the committed audit and records the blocked verify-prs outcome."
    requirement: REPO-04
    verification:
      - kind: other
        ref: "bash scripts/maintainers/prune-stale-branches.sh verify-prs --pr-state-commit 9c0a6b818d2d58858b5db274cc1cf0a9803f69f5 --identity-audit .planning/phases/245-branch-prune-local-and-remote/245-PR-IDENTITY-AUDIT.json --integrity-output .planning/phases/245-branch-prune-local-and-remote/245-PR-INTEGRITY-VERIFICATION.json (recorded exit 1; expected blocked result)"
        status: pass
      - kind: other
        ref: "node scripts/maintainers/prune-stale-branches-pr-audit.mjs validate-final --audit .planning/phases/245-branch-prune-local-and-remote/245-PR-IDENTITY-AUDIT.json --integrity .planning/phases/245-branch-prune-local-and-remote/245-PR-INTEGRITY-VERIFICATION.json"
        status: pass
    human_judgment: false
duration: 37 min
completed: 2026-09-27
status: complete
---

# Phase 245 Plan 07: Live PR Identity Audit Summary

**A pinned audit records all 11 historical PR base mismatches and keeps the protection gate blocked where live PR metadata disagrees with the exact current `main` ref.**

## Performance

- **Duration:** 37 min
- **Started:** 2026-09-28T00:45:25Z
- **Completed:** 2026-09-28T01:22:08Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Derived exactly PRs #219 and #266–#275 from the immutable Phase 245 baseline at commit `9c0a6b818d2d58858b5db274cc1cf0a9803f69f5`, state blob `913e4d0ab10cfa3b4fb42bd4d347d47f5832dc85`, and evidence blob `eb9f3fa848e41578bd6f6d03d375f66207bbc8e9.
- Captured a complete one-page inventory of 13 open PRs and current detail plus exact base/head API and `git ls-remote` observations for all 11 mismatch rows. The audit ID is `e897a9ea-3808-49bb-8751-1d32207e3424` (commit `adb15816b6ace5aca4392679b3d775c0158bbe47`, blob `4414693790b11c19b93c8d565ab55d2d6ebbe0e8`).
- All 11 PR list/detail records agree with each other, and each head ref is corroborated. Their PR base metadata still reports either `fed35a4a3725d217486f45a571421dbbf5721765` or `f06137b2ac0e9b2094aa1250e3c036b41e997651`, while the exact `main` ref from both independent sources is `5a00b90d2314bc93f27aec4090b5928018743d1b`. Each row is therefore explicitly unresolved.
- Fresh `verify-prs` rechecked the complete open-PR set, all 11 identities, and strict base refs for non-exception PRs. It recorded exit status 1 and blocked with row-specific reasons. Integrity ID: `885c9fd1-5e97-481f-a98b-2bdf9a2c362e` (commit `5fc2e5f891e519df86afa03129a851815a08e3d0`, blob `38970b9ecd70600784a82ddebb3f163c8ebafb68`).
- Kept `245-OPEN-PR-STATE.json`, `245-EVIDENCE.json`, all PRs, and all refs unchanged.

## Task Commits

1. **Task 1: Require a complete one-to-one audit of all 11 historical mismatches** — `01fc4350` (RED fixtures), `6751f278` (audit implementation), `d5dbe0db` (final artifact identity validation).
2. **Task 2: Capture and validate current identity evidence** — `adb15816` (committed live audit), `5fc2e5f8` (committed blocked integrity result).

## Files Created/Modified

- `scripts/maintainers/prune-stale-branches-pr-audit.mjs` — immutable source checks, live capture, fail-closed identity evaluation, and final integrity validation.
- `scripts/maintainers/prune-stale-branches-pr-audit.test.mjs` — 12 deterministic mismatch, provenance, drift, and blocked-result fixtures.
- `scripts/maintainers/prune-stale-branches.sh` — routes audited `verify-prs` calls through a fresh identity comparison and records its exit status.
- `scripts/maintainers/prune-stale-branches.remote.test.sh` — runs the audit fixture suite as part of the remote lifecycle test.
- `.planning/phases/245-branch-prune-local-and-remote/245-07-RED-EVIDENCE.json` — accepted GSD RED evidence for the baseline-derived 11-row behavior.
- `.planning/phases/245-branch-prune-local-and-remote/245-PR-IDENTITY-AUDIT.json` — complete paginated capture and 11 row dispositions.
- `.planning/phases/245-branch-prune-local-and-remote/245-PR-INTEGRITY-VERIFICATION.json` — committed final verification result, exact command, exit status, and reasons.

## Decisions Made

- An historical base mismatch is resolved only when current PR detail, complete current inventory, GitHub exact-ref responses, and `git ls-remote` agree field by field.
- An ancestry or readable historical commit cannot reconcile a disagreement between the current PR base SHA and the exact base ref.

## Deviations from Plan

None. The required deterministic fixtures live in a companion Node test file and are invoked by the planned remote fixture suite.

## TDD Gate Compliance

- **RED:** `node --test --test-name-pattern='derives the exact 11 base mismatch keys' scripts/maintainers/prune-stale-branches-pr-audit.test.mjs` failed on the intended assertion (`0 !== 11`). GSD returned `RED_EVIDENCE_OK` for `245-07-RED-EVIDENCE.json`.
- **GREEN:** The full 12-case Node suite and complete remote lifecycle fixture suite passed.
- **REFACTOR:** None required.

## Issues Encountered

Current PR metadata for all 11 rows still carries historical base OIDs that disagree with the exact current `main` ref. The audit preserves the uncertainty and the final integrity gate blocks the operation with those 11 specific mismatches.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 245-08 can consume the committed audit and blocked integrity result. REPO-04 remains blocked until all 11 current PR base identities are corroborated and the remaining requirement evidence passes.

## Current Checkout Reconciliation (2026-09-29)

The baseline commit and task commit IDs recorded above are not resolvable in the active checkout. Plan 245-14 independently records that the baseline is unavailable locally, rejected by `origin`, and absent from the GitHub commit API. Treat this summary as a record of the prior audit attempt, not proof that its listed commits are integrated into the active branch; the reason for the history mismatch is unknown. REPO-04 is not complete.

---
*Phase: 245-branch-prune-local-and-remote*
*Completed: 2026-09-27*
