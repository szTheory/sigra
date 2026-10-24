---
phase: 245-branch-prune-local-and-remote
plan: 11
subsystem: testing
tags: [cleanup-audit, git, evidence-validation, tdd]

# Dependency graph
requires:
  - phase: 245-branch-prune-local-and-remote
    provides: signed cleanup-history ledger and committed-source validator
provides:
  - Canonical signed JSON and JSONL event scanning in audit generation and source verification
  - Shared Git global-option matcher for command receipts and output logs
  - Explicit unknown disposition when Git command parsing is ambiguous
affects: [phase-245-verification, cleanup-history-audit]

# Actuals (#2632)
actuals:
  tokens: 6078
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns: ["One Git invocation classifier shared by receipts, logs, and signed history"]

key-files:
  created: []
  modified:
    - scripts/maintainers/validate-milestone-cleanup-audit.mjs
    - scripts/maintainers/validate-milestone-cleanup-audit.test.mjs

key-decisions:
  - "Signed history events are the canonical command sequence; a redundant top-level commands array is ignored."
  - "Unknown Git option syntax is recorded as ambiguous evidence and cannot establish absence."

requirements-completed: []
coverage:
  - id: D1
    description: Signed JSON/JSONL events and committed command sources are scanned for prohibited cleanup commands.
    requirement: REPO-04
    verification:
      - kind: unit
        ref: scripts/maintainers/validate-milestone-cleanup-audit.test.mjs#signed JSON history events are the canonical command sequence
        status: pass
      - kind: unit
        ref: scripts/maintainers/validate-milestone-cleanup-audit.test.mjs#JSONL history event commands are the canonical command sequence
        status: pass
      - kind: unit
        ref: scripts/maintainers/validate-milestone-cleanup-audit.test.mjs#Git global options are recognized in receipts and output logs
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-09-28
status: complete
---

# Phase 245 Plan 11: Cleanup History Command Evidence Summary

**The cleanup audit now scans attested event records and recognizes prohibited Git subcommands after supported global options while preserving ambiguity as unresolved evidence.**

## Performance

- **Duration:** 25 minutes
- **Started:** 2026-09-28T11:33:51Z
- **Completed:** 2026-09-28T11:58:51Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Audit generation and committed-source verification scan the same ordered `history.events` commands in signed JSON and JSONL transcripts.
- A shared Git invocation classifier handles structured argv and command text with supported global options, including `-C`, `--git-dir`, `--work-tree`, `-c`, and `--config-env`.
- Malformed command text and unknown pre-subcommand Git options remain ambiguous; they cannot support `no_occurrence` or a supported aggregate.
- The committed 30-row cleanup ledger remains unchanged: all 30 rows are `unknown`, with aggregate truth `unresolved`.

## Task Commits

1. **Task 1: Scan canonical signed history events and add regressions** - `7bf6094d` (`test(245-11): add cleanup history observer regressions`)
2. **Task 2: Match Git global options and preserve ambiguity** - `93a7685a` (`fix(245-11): scan cleanup commands conservatively`)

**Plan metadata:** Pending summary/state bookkeeping commit.

## Files Modified

- `scripts/maintainers/validate-milestone-cleanup-audit.mjs` - shared parser and observer; repository-aware source reads; unknown status for ambiguous command evidence.
- `scripts/maintainers/validate-milestone-cleanup-audit.test.mjs` - signed JSON/JSONL, global-option, ambiguity, and no-occurrence rejection fixtures using ephemeral test keys and temporary Git repositories.

## Decisions Made

- Signed event records remain canonical; the parser does not rely on a parallel top-level command array.
- Ambiguous Git command syntax is not treated as a confirmed prohibited command, but it prevents a claim that no prohibited command occurred.
- No qualifying recorder evidence was added, so the 30 existing cleanup-history rows remain unknown.

## Deviations from Plan

None - plan executed as written.

## TDD Gate Compliance

- RED evidence was captured and accepted by `gsd-tools check tdd-red-evidence` for the signed JSON event test and the Git global-option test (`RED_EVIDENCE_OK` for both).
- GREEN focused runs passed for both required test-name patterns.
- The full cleanup-audit test suite passed: 21 tests, 0 failures.
- The committed ledger validator passed: 30 rows, 30 unknown, 0 observed, aggregate `unresolved`.

## Next Phase Readiness

Plan 11 is complete. Phase 245 remains incomplete: Plan 09 is still an independent unresolved safety blocker, and no PR identity or cleanup-history evidence was changed here. Do not mark REPO-04 complete based on this plan.

## Self-Check: PASSED

- `245-11-SUMMARY.md` exists at the required phase path.
- Task commits `7bf6094d` and `93a7685a` are present in Git history.
- The Plan 11 working tree is limited to this summary before its metadata commit.

---
*Phase: 245-branch-prune-local-and-remote*
*Completed: 2026-09-28*
