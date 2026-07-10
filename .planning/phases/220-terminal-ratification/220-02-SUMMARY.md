---
phase: 220-terminal-ratification
plan: 02
subsystem: docs
tags: [runbook, admin-eval-harness, ci, snapshot-canary, terminal-ratification]

requires:
  - phase: 219-baseline-recapture-canary-reconciliation
    provides: branch-scoped recapture dispatch (recapture_branch / release_ref_guard), impersonation-banner canary reconciliation strategy
provides:
  - Three additive orientation notes in guides/reference/admin-eval-runbook.md so a zero-context future agent can distinguish the local eval-harness loop from committed baseline PNG recapture
affects: [220-terminal-ratification, future admin-eval-harness iteration]

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - guides/reference/admin-eval-runbook.md

key-decisions:
  - "D-04: exactly three additive notes landed in one commit — no existing runbook section rewritten (D-03)"

patterns-established: []

requirements-completed: [RATIFY-01]

coverage:
  - id: D1
    description: "admin-eval-runbook.md carries a you-are-here preamble distinguishing the local eval-harness loop (gitignored eval/ bundles) from committed-baseline PNG recapture (CI-native ubuntu/amd64 ONLY, never darwin)"
    requirement: "RATIFY-01"
    verification:
      - kind: other
        ref: "grep -qi 'you are here' guides/reference/admin-eval-runbook.md && grep -qiE 'ubuntu|amd64|ci-native' guides/reference/admin-eval-runbook.md"
        status: pass
    human_judgment: false
  - id: D2
    description: "Runbook notes the merge-boundary impersonation-banner canary-red is EXPECTED and reconciled post-merge, and is NEVER allowlisted"
    requirement: "RATIFY-01"
    verification:
      - kind: other
        ref: "grep -q 'impersonation-banner' guides/reference/admin-eval-runbook.md && grep -qiE 'never[ -]allowlist' guides/reference/admin-eval-runbook.md"
        status: pass
    human_judgment: false
  - id: D3
    description: "Runbook cross-references the branch-scoped recapture dispatch (recapture_branch input / release_ref_guard relaxation)"
    requirement: "RATIFY-01"
    verification:
      - kind: other
        ref: "grep -q 'recapture_branch' guides/reference/admin-eval-runbook.md && grep -q 'release_ref_guard' guides/reference/admin-eval-runbook.md"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-07-10
status: complete
---

# Phase 220 Plan 02: Runbook Freshness Notes Summary

**Added three additive D-04 orientation notes to `guides/reference/admin-eval-runbook.md` (you-are-here preamble, expected canary-red-at-merge-boundary note, branch-scoped recapture cross-ref) with zero deletions from the existing SRE-hallmark runbook.**

## Performance

- **Duration:** ~8 min
- **Tasks:** 1 completed
- **Files modified:** 1

## Accomplishments
- Added a "You Are Here" section near the top of `admin-eval-runbook.md` distinguishing the local eval-harness loop (gitignored `eval/` bundles) from committed baseline PNG recapture (CI-native ubuntu/amd64 only, never darwin), greppable via the phrase "you are here"
- Added a note in the Guard Descriptions section stating the merge-boundary `impersonation-banner` canary going red in `fast_checks` is EXPECTED (never a regression to chase), reconciled post-merge via a quarantine baselines-only PR, and is never allowlisted — using the literal phrase "never allowlisted" co-located with the `impersonation-banner` slug
- Added a one-line cross-reference to the branch-scoped recapture dispatch (`recapture_branch` `workflow_dispatch` input relaxing `release_ref_guard`) right after the JUDGE-CI-01 invariant statement in the Off-CI LLM Panel section
- Confirmed the change is purely additive: `git diff --stat` shows only insertions (33 lines added, 0 removed) — no existing runbook section was rewritten or deleted
- Confirmed `scripts/uat/RUNBOOK.md` (the unrelated UAT-demo runbook) was untouched

## Task Commits

1. **Task 1: Add the three D-04 freshness notes to admin-eval-runbook.md** - `77c9195c` (docs)

**Plan metadata:** committed with STATE.md/ROADMAP.md update (see final commit below)

## Files Created/Modified
- `guides/reference/admin-eval-runbook.md` - three additive orientation notes (you-are-here preamble; expected canary-red-at-merge-boundary note; recapture_branch/release_ref_guard cross-ref)

## Decisions Made
None beyond the plan's locked D-03/D-04 — followed the plan exactly: additive-only, three notes, one commit, no rewrite of existing content, `scripts/uat/RUNBOOK.md` left untouched.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. All four automated verification greps (from the plan's `<verify>` blocks) passed on the first attempt.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

SC-2 (harness runbook usable by a zero-context future agent) is satisfied for this plan's scope. Remaining Phase 220 work (SC-1 live guard confirmation, SC-3 canary quarantine PR, SC-4 cheerio lazy-require fix, and the close-readiness record) proceeds in subsequent plans per the phase's coherent ship sequence (220-CONTEXT.md).

---
*Phase: 220-terminal-ratification*
*Completed: 2026-07-10*

## Self-Check: PASSED

- FOUND: guides/reference/admin-eval-runbook.md
- FOUND: 77c9195c (task commit)
- FOUND: .planning/phases/220-terminal-ratification/220-02-SUMMARY.md
