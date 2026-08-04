---
phase: 235-terminal-ratification-measured-not-read
plan: 12
subsystem: testing
tags: [github-actions, evidence, fast-01, rate-limit, attestation]
requires:
  - phase: 235-11
    provides: "Protected remediation merge cutoff and immutable two-PR receipt"
provides:
  - "A cutoff-bound post-remediation collector with immutable-blob and old-population rejection"
  - "An honest seven-run readiness record without a FAST-01 verdict"
  - "An input-free main-only protected producer for a future independent population"
affects: [235-13, fast-01-measurement]
tech-stack:
  added: []
  patterns:
    - "Validate historical receipt digests against their cutoff Git blobs, never against later main"
    - "Keep readiness evidence non-authoritative until a protected n>=10 subject exists"
key-files:
  created:
    - "scripts/ci/capture-fast-01-gap-closure.sh"
    - "scripts/ci/capture-fast-01-gap-closure.test.sh"
    - ".github/workflows/fast-01-gap-closure-evidence.yml"
    - ".planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-GAP-CLOSURE-READINESS.json"
  modified:
    - "test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs"
    - ".planning/phases/235-terminal-ratification-measured-not-read/235-COVERAGE.md"
key-decisions:
  - "The two-PR receipt digest is verified at remediation cutoff 54c33e9, not against later evidence-only main."
  - "Seven independent terminal PR rows are insufficient_population; FAST-01 remains open with null statistics and verdict."
patterns-established:
  - "Protected evidence workflows are manual, main-ref-only producers isolated from ci.yml and aggregate topology."
requirements-completed: []
coverage:
  - id: D1
    description: "Post-remediation collection rejects altered cutoff blobs, old receipt IDs, bad pagination, rate-limit failures, and strict-threshold mutations."
    requirement: FAST-01
    verification:
      - kind: integration
        ref: "scripts/ci/capture-fast-01-gap-closure.test.sh"
        status: pass
      - kind: unit
        ref: "test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs"
        status: pass
    human_judgment: false
  - id: D2
    description: "Main-only protected producer can attest a future exact independent subject without dispatching it during this plan."
    requirement: FAST-01
    verification:
      - kind: other
        ref: "actionlint .github/workflows/fast-01-gap-closure-evidence.yml"
        status: pass
    human_judgment: false
duration: 10min
completed: 2026-08-03
status: complete
---

# Phase 235 Plan 12: Post-remediation readiness boundary Summary

**A cutoff-authenticated post-remediation collector records seven independent terminal PR runs honestly, while a separate protected producer remains undispatched.**

## Performance

- **Duration:** 10 min
- **Tasks:** 2/2
- **Files modified:** 6
- **Live evidence:** one readiness collection; no protected workflow dispatch.

## Accomplishments

- Bound collection to protected remediation merge `54c33e904155a454255952666711c882afdd06e4` and its immutable blobs, excluding all IDs from the prior 13-run receipt.
- Retained `235-FAST-01-GAP-CLOSURE-READINESS.json` with seven exact terminal PR rows, `insufficient_population`, and null statistics/verdict.
- Added a manual, main-only, least-privilege attestation workflow that requires a future independent n>=10 subject before attestation/upload.

## Task Commits

1. **Task 1: Trace one post-remediation run page into honest readiness** - `6546ec06` (feat)
2. **Task 2: Put the independent collector behind protected-main attestation** - `fe7b7e76` (feat)

## Decisions Made

- The receipt’s `file_digests` are bound to the immutable PR #195 remediation cutoff. The later PR #196 evidence merge is verified as a distinct main ancestry step, rather than falsifying history by rewriting receipt digests to current main.
- Plan 13 remains blocked by its n>=10 precondition; this plan created no qualifying workflow run and claimed no FAST-01 outcome.

## Deviations from Plan

### Approved precondition adaptation

- **Found during:** Task 1
- **Issue:** The original wording expected receipt digests to match current `origin/main`; PR #196 intentionally changed the receipt-validator contract after PR #195’s cutoff under the approved two-PR design.
- **Fix:** Verified every receipt digest against the corresponding Git blob at `population_cutoff.sha`, proved cutoff ancestry/timestamp and its later-than-old-endpoint relation, and retained the later protected evidence merge separately.
- **Impact:** Evidence is strengthened without claiming the later validator existed at the remediation cutoff.

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected receipt hash argument order in the focused ExUnit contract.**
- **Found during:** Task 2 verification
- **Fix:** Used `:crypto.hash(:sha256, receipt_bytes)` before hexadecimal encoding.
- **Verification:** focused contract suite passed.
- **Committed in:** `fe7b7e76`

## Issues Encountered

Focused ExUnit emitted existing local Postgrex connection-refused logs while its four planning tests still completed successfully; no database-backed test was required by this contract.

## Next Phase Readiness

The protected workflow exists but was not dispatched. The captured population is seven, below the required ten, so `FAST-01` remains explicitly unmet and Plan 13 must not run until its independent-population precondition is satisfied.

## Self-Check: PASSED

- Task commits `6546ec06` and `fe7b7e76` exist.
- Collector suite, focused ExUnit contracts, `ci-run-metrics` suite, workflow lint, and readiness-schema assertion passed.
- No known stubs, unrun verification, or new threat surface beyond the documented GitHub evidence workflow.
