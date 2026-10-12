---
phase: 252-measure-current-ci
plan: 02
subsystem: ci-observability
tags: [bash, jq, github-actions, artifacts, evidence]
requires: [252-01]
provides:
  - Fixed-cutoff, 30-day CI populations separated by PR, main push and schedule.
  - Interrupted snapshot bundles with verified request and selection ledgers for offline replay.
  - Bounded artifact and failed-job-log intake with source checks and redaction.
affects: [252-measure-current-ci]
actuals:
  tokens: 16479
  tasks: 3
  commits: 3
commits: 3
plan_head_before: e25aa58ce6976dfacf5bbd31e9dbd675a73a6f56
plan_head_after: 73f864abf34b178ad166614d7ac66c40d31c5e17
tech-stack:
  added: []
  patterns:
    - Reuse one request guard for API pages, retries, artifact/log downloads and every redirect hop.
    - Retain only digest-checked timing JSON and redacted text logs from selected failed runs.
key-files:
  created: []
  modified:
    - scripts/ci/ci-run-metrics.sh
    - scripts/ci/ci-run-metrics.test.sh
key-decisions:
  - Keep workflow_dispatch and release-branch pushes outside the three primary measurement cohorts.
  - Preserve expired, mismatched, unavailable or unsafe artifact inputs as diagnostics instead of timing rows.
patterns-established:
  - Replay validates request, selection and population file hashes before reporting a snapshot.
  - Redirected downloads are explicit GETs to the exact HTTPS host allowlist; signed URLs remain transient.
requirements-completed: []
coverage:
  - id: P02-T1
    description: Collect separate bounded event populations and source-backed workload classifications.
    requirement: CIMEAS-01
    verification:
      - kind: integration
        ref: "scripts/ci/ci-run-metrics.test.sh#Test U"
        status: pass
    human_judgment: false
  - id: P02-T2
    description: Enforce request limits, interrupted recovery, concurrent locking and offline replay.
    requirement: CIMEAS-01
    verification:
      - kind: integration
        ref: "scripts/ci/ci-run-metrics.test.sh#Tests V and W"
        status: pass
    human_judgment: false
  - id: P02-T3
    description: Bind artifact bytes to their producing run, validate redirects and ZIP limits, and redact failed logs.
    requirement: CIMEAS-02
    verification:
      - kind: integration
        ref: "scripts/ci/ci-run-metrics.test.sh#Tests U and Y"
        status: pass
    human_judgment: false
duration: 28min
completed: 2026-10-12
status: complete
---

# Phase 252 Plan 02: Measure bounded current CI populations

**The collector now preserves three distinct 30-day run cohorts, interrupted selection state, and source-bound artifact/log evidence without recording signed download URLs.**

## Performance

- **Duration:** 28 minutes
- **Started:** 2026-10-12T17:45:25Z
- **Completed:** 2026-10-12T18:13:40Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- Collected PR, main-branch push, and scheduled runs separately using one frozen UTC cutoff. Each event keeps its API total, selected run IDs, literal outcomes, and capped/exhausted state. Manual dispatch and release pushes stay in separate records.
- Captured attempt-scoped jobs and PR changed paths. Docs-only and full workload labels require the saved paths, the run's `changes.docs_only` value, and observed skip states; missing evidence remains unknown.
- Made snapshot staging exclusive and final publication atomic. Signals retain a synced request ledger, selected IDs, and an incomplete manifest; complete and incomplete snapshots can replay offline after hash checks.
- Applied the shared request/time/core guard to API reads, downloads, retries, and each validated redirect GET. Artifact intake verifies producing run, source SHA, expiry, and API digest before extraction; extraction rejects unsafe paths/types and members over 64 MiB, 512 MiB total expansion, or 10,000 entries.
- Retained failed-job logs only after credential and signed-URL redaction. Sanitized artifact metadata and request categories keep signed URLs out of the bundle.
- Kept all previous collector modes working. The hermetic suite passed 37 tests with no live GitHub requests.

## Task Commits

1. **Task 1: Collect three event populations and all attempts under the fixed snapshot window** — `915577fd1` (test), `77cb4cbb7` (feat)
2. **Tasks 2–3: Enforce interruption-safe budgets and retain source-bound artifact/log evidence** — `73f864abf` (feat)

## Files Modified

- `scripts/ci/ci-run-metrics.sh` — finite window collection, replay integrity, redirect/download guard, artifact provenance, ZIP validation, and log redaction.
- `scripts/ci/ci-run-metrics.test.sh` — event/window fixtures, interruption and lock cases, valid/invalid redirects, artifact and ZIP provenance, and secret-redaction checks.

## Decisions Made

- `workflow_dispatch` and release-branch pushes remain visible but are excluded from the PR, main-push, and schedule denominators.
- Missing or expired artifacts and unavailable diagnostics remain explicit unknowns; they do not change the run's original outcome.
- Phase requirements remain pending until Phase 252's full population measurement and phase-level verification.

## Deviations from Plan

None. Implementation and tests stayed within the planned collector seam. No package installation, live baseline collection, CI dispatch, or hosted mutation was performed.

## Verification

- `bash -n scripts/ci/ci-run-metrics.sh scripts/ci/ci-run-metrics.test.sh` — passed.
- `bash scripts/ci/ci-run-metrics.test.sh` — 37 passed, 0 failed.
- The fixture collector used stubbed GitHub and curl clients. No live population was collected; that belongs to Plan 06.

## Self-Check: PASSED

- The summary file exists at the requested phase path.
- Task commits `915577fd1`, `77cb4cbb7`, and `73f864abf` are ancestors of the current branch.

## Remaining Phase Work

Plans 252-03 through 252-06 and phase-level verification remain. Requirements CIMEAS-01 and CIMEAS-02 were not marked complete here.
