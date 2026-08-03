---
phase: 235-terminal-ratification-measured-not-read
plan: 04
subsystem: ci-evidence
tags: [fast-01, gate-05, exunit, github-actions, terminal-ratification]
requires:
  - phase: 235-03
    provides: terminal ledger, closeout record, and contributor CI overview
provides:
  - Receipt-bound recomputation of every retained terminal measurement
  - Exact 93-key ownership-universe validation from the Phase 234 inventory
  - Workflow-scoped contributor topology and contradiction checks
affects: [ci-efficiency, fast-01, gate-05, contributor-documentation]
tech-stack:
  added: []
  patterns: [canonical JSON receipt hashing, exact MapSet ownership reconciliation, scoped workflow/prose topology validation]
key-files:
  created: []
  modified:
    - .planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json
    - test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
    - CONTRIBUTING.md
key-decisions:
  - "FAST-01 remains an honest miss: recomputed retained PR evidence is 19 runs with a 772-second p50, strictly above the 720-second target."
  - "Terminal measurement receipts retain the canonical pretty JSON bytes, including their trailing newline, and SHA-256 digests bind those exact bytes."
  - "GATE-05 ownership is an exact 93-key cross-product of the pinned Phase 234 inventory, declared non-Playwright families, and three terminal events."
  - "Contributor topology is accepted only as unique whole CI-overview statements that agree with scoped direct-owner, aggregate, and diagnostic workflow blocks."
metrics:
  duration: 10min
  tasks_completed: 3
  files_modified: 3
completed: 2026-08-02
status: complete
---

# Phase 235 Plan 04: Terminal Ratification Summary

**Terminal CI claims are now recomputed from retained runs, bound to canonical receipt bytes, closed to the exact ownership universe, and resistant to contradictory contributor prose.**

## Accomplishments

- Recomputed each event's queue-inclusive duration statistics from retained timestamps and every terminal conclusion; verified canonical receipt bytes and lowercase SHA-256 digests.
- Kept the measured FAST-01 result honest: 19 PR runs, p50 772 seconds, 13 success / 6 non-success, strict status `miss`.
- Derived and enforced the exact 93-key family/spec/event ownership universe from the pinned Phase 234 inventory and declared non-Playwright families.
- Validated direct-owner commands, aggregate `needs` relationships, aggregate non-execution, and exact non-PR diagnostic guards from individual CI workflow blocks.
- Reworked the CI overview into four unique, mechanically checked topology statements and added contradiction mutations that preserve legacy tokens.

## Task Commits

1. **Task 1 RED: Forgeable terminal evidence contract** — `b3882080`
2. **Task 1 GREEN: Receipt-bound metric recomputation** — `23e54fda`
3. **Task 2 RED: Extend ownership outside the reviewed universe** — `71254fea`
4. **Task 2 GREEN: Exact ownership-key equality** — `a80a3e9d`
5. **Task 3 RED: Contradict contributor topology prose** — `64c53bf9`
6. **Task 3 GREEN: Scope contributor claims to workflow topology** — `dfe47fa1`
7. **Edge coverage: nil/empty populations and median boundaries** — `5088082c`

## Verification

- `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` — pass (13 tests)
- `bash scripts/ci/ci-run-metrics.test.sh` — pass (9 checks)
- `MIX_ENV=test mix test test/sigra/planning/phase_234_playwright_inventory_contract_test.exs test/sigra/planning/phase_198_contributor_dx_contract_test.exs` — pass (12 tests)
- `MIX_ENV=test mix test test/sigra/planning/` — pass (108 tests, 12 skipped)

## Decisions Made

- Preserve the existing immutable measurement window and single FAST-01 residual; no GitHub query, workflow timing change, or unrelated todo work was introduced.
- Treat a canonical receipt as a literal pretty JSON array with one statistics object and its trailing newline, matching the existing committed digests.
- Reject ownership additions and documentation contradictions at the contract boundary rather than relying on token presence or implied review.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Tracking consistency] Reconciled stale Phase 235 roadmap metadata**
- **Found during:** Plan closeout
- **Issue:** The roadmap still declared three Phase 235 plans, so its automatic progress updater could not represent the completed gap-closure Plan 04 or the final 4/4 count.
- **Fix:** Added the Plan 04 wave, corrected the plan count/progress row, and recorded the GATE-05 traceability completion while preserving FAST-01 as the owned measured residual.
- **Files modified:** `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`
- **Commit:** `1c693dd9`

## Known Stubs

None.

## Self-Check: PASSED

- All three key artifacts exist and the seven task/coverage commits are present in Git history.
- No security-relevant network, authentication, file-access, or schema surface was added.
