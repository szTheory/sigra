---
phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard
plan: 08
subsystem: ci-evidence
tags: [github-actions, gh, jq, bash, final-head, contributor-ci]
requires:
  - phase: 241-07
    provides: bounded p18 document-range scanner repair requiring final-SHA CI proof
provides:
  - fail-closed collector for one exact ci.yml pull-request run
  - hermetic GitHub API-shape coverage and pre-proof final-head closeout contract
affects: [phase-241-verification, GitHub Actions evidence]
actuals:
  tokens: 4991
  tasks: 3
  commits: 2
  plan_head_before: de9145daec2c94dab9043524ec8df94f7fb9d567
tech-stack:
  added: []
  patterns: [fixed-selector GitHub collector, terminal pagination proof, same-SHA external receipt]
key-files:
  created:
    - scripts/ci/capture-phase-241-final-head.sh
    - scripts/ci/capture-phase-241-final-head.test.sh
    - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-08-SUMMARY.md
  modified:
    - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-01-EVIDENCE.md
key-decisions:
  - "Precommit every tracked closeout artifact before final-SHA capture; the receipt itself is an external PR comment."
  - "Treat a stale Threadline build as a clean-rebuild prerequisite, never as an environmental waiver."
requirements-completed: [DEBT-01, SURF-04]
coverage:
  - id: D1
    description: Fail-closed same-SHA ci.yml collector with required library and p18 job/step proof.
    requirement: DEBT-01
    verification:
      - kind: integration
        ref: bash scripts/ci/capture-phase-241-final-head.test.sh
        status: pass
    human_judgment: false
  - id: D2
    description: Fresh-build Threadline and exact contributor-alias proof.
    requirement: DEBT-01
    verification:
      - kind: integration
        ref: MIX_ENV=test mix clean && MIX_ENV=test mix test test/sigra/audit/forwarders/threadline_test.exs && MIX_ENV=test mix ci
        status: pass
    human_judgment: false
  - id: D3
    description: External machine-readable final-HEAD CI receipt.
    requirement: SURF-04
    verification:
      - kind: other
        ref: evidence PR sigra.phase-241-final-head/1 comment
        status: unknown
    human_judgment: false
duration: pending external proof
completed: 2026-09-19
status: complete
---

# Phase 241 Plan 08: Final-HEAD Contributor CI Receipt Summary

**A fixed-selector collector and hermetic API corpus bind the exact contributor alias and p18 guard to one final-SHA PR receipt without a post-proof commit.**

## Accomplishments

- Added a fixed-repository `ci.yml` collector that rejects non-matching SHA/event/status/conclusion, partial pagination, duplicate/missing jobs, and failed required steps.
- Added hermetic `gh`-stub coverage for success, identity, run/job/step failure modes, pagination exhaustion, low quota, and 403/429 hard stops.
- Rebuilt Sigra from clean test artifacts (177 files) and passed all six Threadline cases before the exact, unfiltered `MIX_ENV=test mix ci` alias.
- Replaced the stale PENDING claim with an external receipt contract. No tracked file may be changed after the evidence SHA is frozen.

## Task Commits

1. **Task 1: End-to-end final-head collector** — `6420fde4` (feat)
2. **Task 2: Fresh-build proof and closeout contract** — pre-proof commit follows this summary.
3. **Task 3: External receipt** — no tracked commit; success is the PR comment only.

## Decisions Made

- The final receipt contains only public repository/run/job/step/rate-limit metadata, never credentials or environment output.
- The summary is deliberately committed before capture: modifying it afterwards would change the SHA the receipt must prove.

## External Completion Condition

This pre-proof summary is not the evidence claim. Completion requires exactly one evidence-PR
`sigra.phase-241-final-head/1` JSON comment whose SHA is this commit's eventual HEAD and whose
run, Library tests shard alias step, Library tests aggregator, and Fast checks p18 guard are all
successful. Task 3 performs no tracked write.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 1 - Bug] Corrected shell-local and jq predicate scoping in the collector**
- **Found during:** Task 1 hermetic success-path run.
- **Issue:** Bash evaluated same-line `local` references before initialization, and the terminal-page jq predicate measured the manifest rather than the final jobs array.
- **Fix:** Initialized locals separately and scoped the terminal-array length predicate explicitly.
- **Verification:** `bash scripts/ci/capture-phase-241-final-head.test.sh` passes all 58 assertions.
- **Committed in:** `6420fde4`.

## Known Stubs

None.

## Self-Check: PASSED (pre-proof artifacts)

The collector, hermetic test, evidence contract, summary, and Task 1 commit exist. The external
receipt is intentionally pending until the frozen evidence branch PR run completes; no success
claim is made in this file.
