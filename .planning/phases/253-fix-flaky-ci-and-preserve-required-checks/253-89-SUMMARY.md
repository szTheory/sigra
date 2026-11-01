---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "89"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, disposition, not-reproduced, r6]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: 253-83 R5 controls 22/22, 253-84 open acceptance evidence
provides:
  - "--create-target-disposition, --record-target-disposition-approval and --verify-load-acceptance E --require-target-disposition runner modes"
  - "Committed, hash-bound, human-approved not_reproduced disposition for the CIREL-01 registration target"
affects: [253-90, 253-91, 253-92, 253-93, 253-94]
actuals:
  tokens: 30000
  tasks: 3
  commits: 4
plan_head_before: 42ee29e6503e855b7e214563e403a8858eaf80cd
plan_head_after: 2b6edc70b1edd8c7716dc535d8a1d67c9cb90db7
tech-stack:
  added: []
  patterns: ["RED receipt committed before implementation", "committed-in-HEAD + byte-equal readback with injectable git deps"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-TARGET-DISPOSITION-RED.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-TARGET-DISPOSITION.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-TARGET-DISPOSITION-APPROVAL.json
  modified:
    - scripts/ci/ci-registration-recovery.mjs
    - scripts/ci/ci-registration-recovery.test.mjs
key-decisions:
  - "Task 1: approve (Jon, via orchestrator AskUserQuestion, 2026-10-14). Verbatim option text: Approve (Recommended). No note."
  - "CIREL-01 recorded partial, satisfied false; ROADMAP SC-1 no-flake clause does not apply; disposition is never automatic."
requirements-completed: []
duration: 40min
completed: 2026-10-14
status: complete
---

# Phase 253 Plan 89: Target disposition Summary

**An approved, committed not_reproduced disposition for the CIREL-01 registration target, plus a `--require-target-disposition` predicate that exits 0 only on an accepted target or that exact approved record.**

## Task outcomes

1. **Task 1 (checkpoint:decision): approve.** Resolved by the orchestrator before this run: approve (Jon, via orchestrator AskUserQuestion, 2026-10-14). Orchestrator pre-checks: `--stage progress` exit 0, `--require-target-accepted` exit 3, evidence sha256 f95393e3...fc7. Decision text recorded: `Approve (Recommended)`.
2. **Task 2 (tracer, TDD): done.**
   - RED: 8 new `disposition:` tests against the unchanged runner, exit 1, 7 failing, 1 passing (the argv-combination test already failed closed through the existing usage fallthrough). Receipt `...TARGET-DISPOSITION-RED.json` committed in `edebfbcad`, before the implementation.
   - GREEN: `c61c3035b`. Full runner suite in the foreground under Node 20.18.1: 229 tests, 229 pass, 0 fail (221 pre-existing, unedited, plus 8 new).
3. **Task 3 (auto): done.** Disposition `501ae407a`, approval `2b6edc70b`, each committed alone.

## Predicate results (real records)

| Command | Exit |
|---|---|
| `--verify-load-acceptance E --require-target-disposition` | 0 (route: disposition) |
| `--verify-load-acceptance E --require-target-accepted` | 3 |
| `--verify-load-acceptance E --stage complete --require-target-accepted` | 3 |
| `--verify-load-acceptance E --stage progress` | 0 |

## Hashes

- Acceptance evidence: f95393e39c2fc7d039556d627429de4a61af37a7aae69b9f40afbd0ef4988fc7 (unchanged)
- Disposition: 6afcc1a77b604bee7438195f3bc70e67336753afe345ea157c6c9c275d87a140
- Approval: d7d566641da2d5e1c7d5e951adb6e7d53c88f2a32ff8da4f324b64df11c27b0e
- state.json: 70229 bytes; config.json sha256 8e312f6c... unchanged; scripts/ci/__pycache__ absent.

## Commits

- `edebfbcad` test(253-89): RED receipt and tests
- `c61c3035b` feat(253-89): predicate and record modes
- `501ae407a` docs(253-89): disposition record
- `2b6edc70b` docs(253-89): approval record

## Deviations from Plan

None - plan executed exactly as written. (Task 1 was resolved by the orchestrator rather than by a checkpoint return, per the dispatch instructions.)

## Remaining gaps

- CIREL-01 stays partial: its "reproduced and fixed" clause is unmet. Whole-phase verification will likely show SC-1/CIREL-01 as a gap; closing the milestone with it is Jon's later decision. REQUIREMENTS.md not amended.
- The `--require-target-disposition` argv form accepts only the bare form (`E --require-target-disposition`); combining it with `--require-target-accepted` or `--stage` is a usage error.
- Out-of-scope follow-ups, not acted on: the `:pending_email` change-email path review for the 253-57 unsafe_unique enumeration leak class; whole-phase verification after 253; re-applying the Claude-tier config after 253 (orchestrator-owned); the latent R2-path annotation double count at ~:2357.

## Known Stubs

None.

## Self-Check: PASSED
