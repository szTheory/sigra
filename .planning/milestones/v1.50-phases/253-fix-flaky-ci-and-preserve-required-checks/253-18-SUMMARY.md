---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: '18'
subsystem: infra
tags: [python, https, ci, request-accounting, hermetic-tests]
requires:
  - phase: 253
    provides: frozen canary request and time budgets, trusted download-host policy, and canary fixture contract
provides:
  - Measured HTTPS request ledger with pre-I/O charging, response receipts, and terminal stops
  - Typed canary API adapter with explicit page and redirect requests
  - Real local HTTPS subprocess tests and synthetic Git fixture checks
affects: [253 hosted canary execution, ci evidence transport]
actuals:
  tokens: 27044
  tasks: 2
  commits: 3
commits: 3
plan_head_before: 6795727ef8f77ae39b500a57815d24e73eb2910f
plan_head_after: 156d5988336e8e15f50622ecded9dd76c8357920
tech-stack:
  added: [Python standard-library http.client HTTPS transport]
  patterns: [charge-and-fsync before network I/O, typed API routes, explicit bounded page and redirect requests]
key-files:
  created: [scripts/ci/ci-hosted-transport.py]
  modified: [scripts/ci/ci-hosted-transport.test.py, scripts/ci/ci-gate-canary.sh, scripts/ci/ci-gate-canary.test.sh]
key-decisions:
  - "Keep the hosted adapter limited to typed api.github.com routes and explicitly allocated download hosts."
  - "Exercise transport through real local HTTPS sockets while keeping hermetic origins unavailable to live allocations."
patterns-established:
  - "Persist a pending transaction and fsync the ledger before each network request; record the measured status and scrubbed response afterward."
  - "Charge every page and redirect hop as its own request, with no implicit redirect or retry."
requirements-completed: []
coverage:
  - id: D1
    description: "Canary HTTPS transactions are measured, bounded, scrubbed, and stopped on authentication or rate-limit hard stops."
    verification:
      - kind: integration
        ref: "python3 -B scripts/ci/ci-hosted-transport.test.py (14 local HTTPS subprocess tests)"
        status: pass
      - kind: integration
        ref: "bash scripts/ci/ci-gate-canary.test.sh (temporary synthetic Git repository)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Hosted canary behavior has been accepted against GitHub and native hosted jobs."
    verification: []
    human_judgment: true
    rationale: "This plan ran only hermetic local HTTPS and Git fixtures; it made no GitHub requests or hosted dispatches."
duration: 20min
completed: 2026-10-13
status: complete
---

# Phase 253 Plan 18: Measured Hosted HTTPS Transport Summary

**Each canary request now has a durable pre-I/O charge and a scrubbed record of its actual HTTPS response.**

## Performance

- **Duration:** approximately 20 minutes
- **Started:** 2026-10-13
- **Completed:** 2026-10-13
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added a standard-library HTTPS transport that validates typed routes, fsyncs a pending ledger entry before network I/O, records actual status and safe headers, and bounds time, response bytes, pages, and redirect hops.
- Routed canary API, dispatch, polling, and download operations through the transport. Authentication is sent only to `api.github.com`; API calls do not follow redirects, and download hops are individually charged without forwarding credentials.
- Added real local TLS-server tests covering actual statuses, failed connections, concurrent budget exhaustion, all supported redirect statuses, signed-query redaction, pagination, and 401/403/429/core-budget stops. Reworked the canary startup contract to use a temporary synthetic Git repository.
- Preserved the distinction between old unproven command reservations and the new 117-request measured allocation. No live GitHub request or hosted job was run.

## Task Commits

1. **Task 1: HTTPS status and pre-I/O charge RED evidence** - `6a7994dfe` (test)
2. **Task 2: Redirect and hard-stop RED evidence** - `2b3181e74` (test)
3. **Tasks 1–2: measured transport and shell integration** - `156d59883` (feat)

## Files Created/Modified

- `scripts/ci/ci-hosted-transport.py` - Typed HTTPS requests, measured receipts, bounded pagination and redirects, hard stops, and ledger preservation.
- `scripts/ci/ci-hosted-transport.test.py` - Local TLS server and subprocess tests that compare the server journal with durable ledger entries.
- `scripts/ci/ci-gate-canary.sh` - Routes canary transport operations through the measured adapter and sets the new measured request cap to 117.
- `scripts/ci/ci-gate-canary.test.sh` - Runs startup and source identity checks in a temporary fixture repository without relying on active phase ledgers or refs.

## Decisions Made

- Kept route IDs and query keys explicit so callers cannot provide arbitrary API URLs.
- Allowed a local certificate authority only in hermetic test allocations; live allocations reject test-origin and test-certificate fields.
- Did not mark CIREL-02 complete: this plan establishes the transport contract, while the broader required-gate behavior still needs phase-level evidence.

## Deviations from Plan

None. The temporary Git fixture and local HTTPS server were part of the planned acceptance checks.

## Issues Encountered

The Git checkout required elevated permission for repository metadata writes. The implementation and task commits were staged only from the four declared source/test files; unrelated dirty planning state was left untouched.

## User Setup Required

None for local transport tests. A live canary allocation and hosted GitHub verification remain outside this plan's execution.

## Next Phase Readiness

The measured adapter is ready for a separately authorized hosted canary after a frozen live allocation is prepared. These local results do not prove GitHub request counts or native hosted-job outcomes. The historical command request count remains unproven.

## Self-Check: PASSED

The summary file exists, and all three task commits are ancestors of the current branch head.

---
*Phase: 253-fix-flaky-ci-and-preserve-required-checks*
*Completed: 2026-10-13*
