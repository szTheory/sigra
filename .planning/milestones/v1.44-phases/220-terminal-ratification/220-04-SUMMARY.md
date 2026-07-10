---
phase: 220-terminal-ratification
plan: 04
subsystem: infra
tags: [ci, ship-mechanics, quarantine-pr, canary-guard, release-please, panel-ci-isolation, terminal-ratification]

# Dependency graph
requires:
  - phase: 220-terminal-ratification
    provides: "220-01 cheerio lazy-require fix (D-10), 220-02 runbook D-04 freshness notes, 220-03 220-LIVE-GUARD-CONFIRMATION.md (SC-1 preview evidence) — all cited by this plan's close-readiness record"
  - phase: 219-baseline-recapture-canary-reconciliation
    provides: "the 3-PNG impersonation-banner canary drift this plan's quarantine-PR draft is scoped around"
provides:
  - "220-QUARANTINE-PR-BODY.md: ready-to-paste quarantine PR title/body/checklist isolating the 3-PNG impersonation-banner canary rebirth (D-05..D-08)"
  - "220-CLOSE-READINESS.md: the D-13 handoff record — 4 landed commits, exact deferred ship sequence, SC-1..SC-4 status map, pre-ship re-verify checklist, affirmative SC-4 panel-absence evidence"
affects: [terminal-ship-pr, gsd-ship, gsd-complete-milestone]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Quarantine-PR pattern: isolate a guard-red-by-design baseline rebirth into its own small PR so the primary/terminal PR ships caveat-free"]

key-files:
  created:
    - .planning/phases/220-terminal-ratification/220-QUARANTINE-PR-BODY.md
    - .planning/phases/220-terminal-ratification/220-CLOSE-READINESS.md
  modified: []

key-decisions:
  - "Re-verified PNG drift is still exactly 3 impersonation-banner PNGs (all M) and PR #66 still OPEN immediately before writing both artifacts, per the plan's 7-day research-validity window"
  - "Captured both SC-4 panel-absence proofs (panel-ci-isolation.test.sh PASS 3/3 + zero-match ci.yml run: grep) verbatim in the close-readiness record so the panel half is evidenced, not merely prohibited"
  - "Recorded the 220-VALIDATION.md nyquist_compliant flip as an explicit execution-time-only step gated on live terminal-PR CI greens — not performed in this phase"

patterns-established:
  - "Pattern: a close-readiness/D-13 record separates 'landed on-branch' from 'authoritative on-PR proof pending' per artifact, closing the 216 SC-5 trap at the ship-documentation layer"

requirements-completed: [RATIFY-01]

coverage:
  - id: D1
    description: "Quarantine-PR body draft scoping exactly the 3 impersonation-banner PNGs, with green-required-check/red-non-required-check explanation, D-08 PAT footgun note, and operator scope-check + merge-FIRST checklist"
    requirement: "RATIFY-01"
    verification:
      - kind: other
        ref: "git diff --name-status origin/main...HEAD -- '*.png' -> exactly 3 M impersonation-banner rows"
        status: pass
      - kind: other
        ref: "grep checks on 220-QUARANTINE-PR-BODY.md: impersonation-banner present, PAT/GITHUB_TOKEN/retrigger present, 'Example Playwright smoke' present"
        status: pass
    human_judgment: false
  - id: D2
    description: "Close-readiness record documents the four landed ratification commits, the exact deferred ship sequence, and the no-self-merge/no-archive statement (D-13)"
    requirement: "RATIFY-01"
    verification:
      - kind: other
        ref: "grep checks on 220-CLOSE-READINESS.md: gsd-ship, gsd-complete-milestone, #66, full-branch/merge-commit, NOT squash, SC-1..SC-4, not self-merge phrasing all present"
        status: pass
    human_judgment: false
  - id: D3
    description: "SC-4's panel-absence half is affirmatively evidenced (not merely prohibited): panel-ci-isolation.test.sh PASS + zero-match ci.yml run: grep for panel/loop orchestrator basenames, captured verbatim in the record"
    requirement: "RATIFY-01"
    verification:
      - kind: other
        ref: "bash scripts/ci/panel-ci-isolation.test.sh -> 3 passed, 0 failed, exit 0"
        status: pass
      - kind: other
        ref: "grep -cE 'run:.*admin-panel.sh|run:.*admin-autofix-loop.sh' .github/workflows/ci.yml -> 0"
        status: pass
    human_judgment: false
  - id: D4
    description: "Whether the quarantine-PR draft is sufficiently complete/unambiguous for a future operator to execute without re-deriving anything, and whether the ordered ship sequence is genuinely executable end-to-end, is an editorial/operational judgment"
    requirement: "RATIFY-01"
    verification: []
    human_judgment: true
    rationale: "This plan produces documentation artifacts only (no PR opened/merged, no milestone archived, per D-13's hard prohibition); whether those artifacts are sufficient for the operator to execute the real ship sequence can only be confirmed when that sequence is actually run."

# Metrics
duration: 8min
completed: 2026-07-10
status: complete
---

# Phase 220 Plan 04: Quarantine-PR Body + Close-Readiness Record Summary

**Drafted a ready-to-paste 3-PNG quarantine-PR body (D-05..D-08) and the D-13 close-readiness record documenting the four landed ratification commits, the exact deferred six-step ship sequence, the SC-1..SC-4 status map, and an affirmative (doubly-corroborated) SC-4 panel-absence proof — no PR opened, pushed, or merged; no milestone archived.**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-07-10T02:23:38Z (approx, session continuation)
- **Completed:** 2026-07-10T02:28:27Z
- **Tasks:** 2 completed
- **Files modified:** 2 (both new)

## Accomplishments
- Re-verified the current PNG drift is still exactly the 3 `impersonation-banner` PNGs (all `M`) and PR #66 (`chore(main): release 1.2.0`) is still OPEN — matching CONTEXT/RESEARCH byte-for-byte at execution time
- Wrote `220-QUARANTINE-PR-BODY.md`: a ready-to-paste PR title/body/branch-cut commands isolating the 3-PNG canary rebirth, a plain explanation of why the required `Example Playwright smoke` goes green while the non-required `fast_checks` reds as expected (canary never-allowlistable tripwire), the D-08 `GITHUB_TOKEN`-no-retrigger footgun mitigation (PAT/manual push), an operator scope-check + merge-FIRST checklist, and the non-default fast_checks-red fallback
- Wrote `220-CLOSE-READINESS.md`: the D-13 handoff record listing the four landed ratification commits (D-10 cheerio, D-04 runbook, D-02 live-guard, D-13 this record) with plan/artifact cross-refs, the exact six-step deferred ship sequence (quarantine PR merge-first → release-please PR #66 → terminal full-branch merge-commit PR → `/gsd-ship` → v1.3.0 → `/gsd-complete-milestone`), an SC-1..SC-4 status map distinguishing landed-on-branch from pending-on-PR evidence, a pre-ship re-verify checklist, and an explicit note that the `220-VALIDATION.md` `nyquist_compliant` flip is an execution-time-only step
- Captured SC-4's panel-absence half affirmatively: re-ran `panel-ci-isolation.test.sh` (3 passed, 0 failed) and a direct zero-match grep over `.github/workflows/ci.yml` `run:` lines for the panel/loop orchestrator basenames, both captured verbatim in the close-readiness record

## Task Commits

Each task was committed atomically:

1. **Task 1: Draft the quarantine-PR body + operator checklist (D-05..D-08)** - `9f08c9a6` (docs)
2. **Task 2: Write the close-readiness record (D-13)** - `91d47f92` (docs)

**Plan metadata:** (final commit follows this SUMMARY)

## Files Created/Modified
- `.planning/phases/220-terminal-ratification/220-QUARANTINE-PR-BODY.md` - ready-to-paste PR body, branch-cut commands, D-08 footgun note, operator checklist, non-default fallback
- `.planning/phases/220-terminal-ratification/220-CLOSE-READINESS.md` - D-13 close-readiness record: 4 landed commits, deferred ship sequence, SC status map, affirmative SC-4 panel-absence evidence, pre-ship re-verify checklist

## Decisions Made
- Followed the plan's locked D-05..D-13 exactly: quarantine strategy as the default with the fast_checks-red fallback explicitly labeled non-default; ordered ship sequence exactly matching the coherent-sequence in `220-CONTEXT.md`
- Framed both SC-1 (from `220-LIVE-GUARD-CONFIRMATION.md`) and the cheerio-fix half of SC-4 as "landed on-branch preview, authoritative proof pending on terminal PR" per the 216 SC-5 discipline already established by Plan 03 — did not overclaim either as fully proven
- Explicitly deferred the `220-VALIDATION.md` `nyquist_compliant: true` flip to execution time (gated on live terminal-PR CI greens), per the plan's instruction not to flip it dishonestly now

## Deviations from Plan

None - plan executed exactly as written. Both tasks' automated `<verify>` commands passed on the first attempt.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. The quarantine PR, PR #66 merge, and terminal PR are all deferred operator/`/gsd-ship` actions documented in `220-CLOSE-READINESS.md`.

## Next Phase Readiness

Phase 220 (terminal-ratification) is complete: all 4 plans (220-01..220-04) executed. Per D-13, this phase does NOT self-merge any PR and does NOT archive the milestone. The operator's next actions, in order, are documented in `220-CLOSE-READINESS.md` section (b): open the quarantine PR (via PAT, per D-08), merge it first, merge release-please PR #66, open the terminal v1.44 milestone PR as one full-branch merge-commit PR (rebased), confirm 6/6 green + human sign-off (also the gate for flipping `220-VALIDATION.md`'s `nyquist_compliant`), run `/gsd-ship`, then merge the resulting v1.3.0 release-please PR and run `/gsd-complete-milestone`. No blockers for that sequence; the pre-ship re-verify checklist in `220-CLOSE-READINESS.md` section (d) should be re-run immediately before starting it, since research validity is scoped to 7 days.

---
*Phase: 220-terminal-ratification*
*Completed: 2026-07-10*

## Self-Check: PASSED

- FOUND: .planning/phases/220-terminal-ratification/220-QUARANTINE-PR-BODY.md
- FOUND: .planning/phases/220-terminal-ratification/220-CLOSE-READINESS.md
- FOUND commit: 9f08c9a6 (Task 1)
- FOUND commit: 91d47f92 (Task 2)
