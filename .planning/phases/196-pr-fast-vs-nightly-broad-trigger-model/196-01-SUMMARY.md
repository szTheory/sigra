---
phase: 196-pr-fast-vs-nightly-broad-trigger-model
plan: 01
subsystem: infra
tags: [ci, github-actions, workflow, schedule, cron, pull-request, nightly]

# Dependency graph
requires:
  - phase: 194-caching-correctness-micro-job-consolidation
    provides: "fast_checks job, ci-gate aggregator, required-check surface (5 lane names in ruleset 14941512)"
  - phase: 195-test-suite-performance-partition-async-dep-off-slim
    provides: "library_tests shard/aggregator shape, ubuntu-latest runner policy"
provides:
  - "PR-fast vs nightly-broad trigger model in ci.yml: schedule cron added, 5 exhaustive jobs gated off PR path, ci-gate skip-tolerant"
  - "workflow_dispatch.inputs.force_fail_probe for nightly lane self-test verification"
affects:
  - "196-02 (MAINTAINING.md doc updates, phase_51 test re-anchor)"
  - "196-03 (VERIFICATION doc)"
  - "196-04 (MAINTAINING.md probe runbook)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Job-level if: github.event_name != 'pull_request' for whole-job PR exclusion (not step-level gating)"
    - "schedule: cron '30 4 * * *' (04:30 UTC, avoids playwright-github-pages.yml 45 6 slot)"
    - "Skip-tolerant ci-gate: result != success && result != skipped (tolerates skipped needs without weakening real-failure detection)"
    - "workflow_dispatch inputs.force_fail_probe boolean for nightly probe without a separate workflow"

key-files:
  created: []
  modified:
    - ".github/workflows/ci.yml"

key-decisions:
  - "Job-level if: github.event_name != 'pull_request' used for all 5 moved jobs (not step-level gating) — whole-job removal for non-required jobs"
  - "Gate condition is != 'pull_request' not == 'schedule' so main pushes + release-dispatch retain full coverage (D-03)"
  - "ci-gate skip-tolerant for skipped (D-09): upgade_smoke and generated_admin_playwright_smoke become skipped on PRs; real failure/cancelled stays red"
  - "forced-failure probe hosted in passkeys_manual_fallback_smoke (needs-free, nightly-gated) so release_ref_guard cannot pre-empt it"
  - "Live ruleset 14941512 re-read at execution (D-12): 5 contexts confirmed, enforcement: active, no 6th/renamed context"
  - "5 required-check lane name: strings byte-identical and unconditional; install_golden_contract + library_tests_dep_off kept on PR"

patterns-established:
  - "Job-level if: github.event_name != 'pull_request': the canonical pattern for moving a non-required job off the PR path while keeping it on schedule/main/dispatch"
  - "Skip-tolerant ci-gate loop: && result != 'skipped' addition to tolerate conditionally-skipped needs without disabling real-failure detection"

requirements-completed: [CRIT-02, CRIT-03]

# Metrics
duration: 4min
completed: 2026-06-20
status: complete
---

# Phase 196 Plan 01: PR-Fast vs Nightly-Broad Trigger Model Summary

**Single atomic ci.yml edit adds schedule cron at 04:30 UTC, gates 5 exhaustive jobs off PR path with job-level event_name != 'pull_request', and makes ci-gate skip-tolerant for the two moved-and-needed jobs**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-06-20T16:01:58Z
- **Completed:** 2026-06-20T16:06:05Z
- **Tasks:** 3 (1 read-only + 2 editing)
- **Files modified:** 1

## Accomplishments

- Live ruleset 14941512 re-read and confirmed: exactly 5 required-check contexts, enforcement: active, no 6th/renamed context
- Added `schedule: - cron: '30 4 * * *'` (nightly, avoiding the existing `45 6` slot from playwright-github-pages.yml)
- Added `workflow_dispatch.inputs.force_fail_probe` boolean input for nightly self-test probe (D-14)
- Added job-level `if: github.event_name != 'pull_request'` to all 5 moved jobs: `upgrade_smoke`, `passkeys_manual_fallback_smoke`, `install_matrix`, `passkeys_opt_out_smoke`, `generated_admin_playwright_smoke`
- Added forced-failure probe step inside `passkeys_manual_fallback_smoke` (the only moved needs-free job, preventing release_ref_guard pre-emption)
- Made ci-gate result loop skip-tolerant: `result != "success" && result != "skipped"` so PRs don't go red when upgrade_smoke/generated_admin_playwright_smoke are skipped

## Ground Truth Evidence (Task 1 — D-12 mandatory)

Live ruleset 14941512 required_status_checks contexts (sorted):

```
Example HTTP smoke (boot + curl critical routes)
Example Playwright smoke (full lifecycle)
Example unit smoke (ExUnit + ConnTest)
Install smoke (fresh phx.new + sigra.install)
Library tests
```

Enforcement: `active`. No 6th context. No renamed context. These 5 names were NOT touched in Task 2 — they carry no event_name gate and their job `name:` strings are byte-identical.

## Task Commits

Each task was committed atomically:

1. **Task 1: Re-read live ruleset (read-only)** - no commit (evidence-only)
2. **Tasks 2+3: Add schedule cron + gate 5 moved jobs + ci-gate skip-tolerant** - `8eca0dbc` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `/Users/jon/projects/sigra/.github/workflows/ci.yml` - Schedule cron, workflow_dispatch inputs, 5 job-level if gates, forced-failure probe step, ci-gate skip-tolerant loop condition

## Decisions Made

- Used `cron: '30 4 * * *'` (04:30 UTC) for the new schedule trigger — recommended by RESEARCH §5, avoids the `45 6` slot in playwright-github-pages.yml
- Hosted forced-failure probe in `passkeys_manual_fallback_smoke` (no `needs:` key, so release_ref_guard cannot pre-empt; per PATTERNS.md §2 recommendation)
- Bundled Tasks 2 and 3 into one commit since they are causally coherent — D-09 (skip-tolerant ci-gate) exists only because D-02 (job moves) produces `skipped` needs

## Deviations from Plan

None — plan executed exactly as written. The forced-failure probe (D-14) was included as part of the workflow_dispatch.inputs work in Task 2, consistent with PATTERNS.md §2 and CONTEXT.md D-14.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- ci.yml PR-fast vs nightly-broad trigger model is complete; 5 moved jobs skip on PRs and run on nightly schedule/main/dispatch
- Plan 02 should: re-anchor phase_51 contract test (D-15), verify phase_58 slicer (D-16), update MAINTAINING.md (D-13/D-14)
- Phase contract tests (phase_51, phase_58) must be verified against this edited ci.yml

## Self-Check

## Self-Check: PASSED

- `.github/workflows/ci.yml`: FOUND (modified)
- `196-01-SUMMARY.md`: FOUND (created)
- Commit `8eca0dbc`: FOUND in git log
- YAML validation: PASSED
