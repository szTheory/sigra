---
phase: 239-hosted-session-interop
plan: "06"
subsystem: hosted-session-interop
tags: [crosswake, sigra, evidence, exunit, postgres, security]
requires:
  - phase: 239-hosted-session-interop
    provides: "Immutable Crosswake release proof, fresh host binding, and evidence-only hosted returns"
provides:
  - "Bounded automation-first proof that runs the release/scope contract and complete database-backed adapter suite"
  - "Exact-SHA machine-readable interop receipt with ordered Wave 0 outcomes and explicit unresolved dispositions"
affects: [crosswake-consumption, b2c-alpha, phase-239-verification]
tech-stack:
  added: []
  patterns: ["Write a phase receipt only after bounded deterministic commands succeed", "Keep external release provenance and local execution outcomes separate but cross-referenced"]
key-files:
  created:
    - scripts/ci/hosted-session-interop-proof.sh
    - test/sigra/planning/phase_239_hosted_session_interop_test.exs
    - .planning/phases/239-hosted-session-interop/239-INTEROP-EVIDENCE.json
  modified: []
key-decisions:
  - "The final receipt preserves XW-01/XW-02 unresolved fallback assumptions and descriptor-less unverified prohibitions instead of claiming them as verified."
  - "The proof runner requires the repository-managed PostgreSQL environment and uses a per-command alarm bound without polling or manual verification."
metrics:
  duration: "3m"
  completed: 2026-08-10
  tasks_completed: 2
  files_modified: 3
status: complete
---

# Phase 239 Plan 06: Hosted Session Interop Seal Summary

**A bounded local proof now seals the fail-closed SIGRA-to-Crosswake session boundary with exact source provenance, database-backed outcomes, and an honest machine-readable receipt.**

## Accomplishments

- Added a fast ExUnit contract that rejects malformed or reordered Wave 0 evidence, release/dependency/recipe drift, coverage-declaration drift, and host-boundary regressions.
- Added an executable, timeout-bounded proof runner which requires the configured PostgreSQL environment, runs the fast contract and complete adapter suite, and writes evidence only after all commands pass.
- Captured `239-INTEROP-EVIDENCE.json` for SIGRA `78a86f75338730792f7d156fc91819023e57d15d`, Crosswake `crosswake_sigra` `0.1.3` at `70edb8077894fd09d4376591782b511c9d8be664`, including the Wave 0 proof digest and all four ordered external command outcomes.

## Task Commits

1. **Task 1: Lock the source, release, and scope contract** - `3ed6ac93` (TDD RED), `78a86f75` (GREEN)
2. **Task 2: Run the full proof and record exact-SHA evidence** - `8c61b35f`

## Verification

- `scripts/ci/hosted-session-interop-proof.sh` — passed: formatting contract, 4 fast ExUnit assertions, and the complete 14-test database-backed adapter suite.
- `MIX_ENV=test mix test test/sigra/planning/phase_239_hosted_session_interop_test.exs` — passed (4 tests).
- `bash -n scripts/ci/hosted-session-interop-proof.sh` and `shellcheck -x scripts/ci/hosted-session-interop-proof.sh` — passed.
- Receipt schema check — passed: exact full SHA, four Wave 0 command records, zero local statuses, XW-01/XW-02, D-01 through D-06, unresolved assumptions, flagged-unverified prohibitions, and `detected: false` API declaration are present.

## Decisions Made

- The receipt distinguishes executed deterministic evidence from unresolved descriptor-less planning rows, retaining the latter as `unresolved` or `unverified`.
- PostgreSQL remains an explicit required environment; a missing service cannot create a pass-shaped receipt.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Started the repository-managed ephemeral PostgreSQL service.**
- **Found during:** Task 1 RED verification.
- **Issue:** The saved test database port was unavailable, preventing the database-backed adapter suite from running.
- **Fix:** Ran `scripts/db/up.sh`, then used its generated `tmp/db.env` for deterministic verification.
- **Files modified:** None tracked.
- **Verification:** The complete adapter suite passed through the bounded proof runner.

**2. [Rule 3 - Blocking] Marked the proof runner executable.**
- **Found during:** Task 2 proof invocation.
- **Issue:** The new runner had mode `100644`, so its documented direct command could not execute.
- **Fix:** Applied executable mode `100755` and reran the full proof.
- **Files modified:** `scripts/ci/hosted-session-interop-proof.sh`.
- **Verification:** Direct runner invocation, `bash -n`, and ShellCheck pass.

**Total deviations:** 2 auto-fixed (2 Rule 3).
**Impact on plan:** Both fixes were necessary for the authorized deterministic proof; no product scope changed.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed the proof runner, fast contract, and exact-SHA evidence receipt exist.
- Confirmed task commits `3ed6ac93`, `78a86f75`, and `8c61b35f` exist in Git history.
