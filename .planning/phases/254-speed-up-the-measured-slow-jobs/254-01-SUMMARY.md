---
phase: 254-speed-up-the-measured-slow-jobs
plan: "01"
subsystem: testing
tags: [ci, source-readiness, profiling, playwright, postgres]
requires:
  - phase: 252-measure-current-ci
    provides: Frozen comparison contract, baseline archive and saved runner evidence
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: Current report, setup-diagnostic and transfer behavior to identify in the profile
provides:
  - Offline preflight that verifies frozen commits, refs, workflow and workload blobs against the archive
  - Source-bound local preparation profiles for admin_behavior and non_admin_smoke
affects: [254-speed-up-the-measured-slow-jobs]
tech-stack:
  added: []
  patterns: [Exact Git-object digest checks, action-source command extraction, bounded task-local profiling]
key-files:
  created:
    - scripts/ci/ci-baseline-source-preflight.mjs
    - scripts/ci/ci-baseline-source-preflight.test.mjs
    - scripts/ci/ci-prep-profile.mjs
    - scripts/ci/ci-prep-profile.test.mjs
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-SOURCE-READINESS.json
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-PREP-PROFILE.json
  modified: []
key-decisions:
  - "Use only retained refs and frozen archive digests as source-readiness evidence; do not infer hosted cache or image readiness."
  - "Measure preparation in cold, task-local checkouts and keep unavailable hosted internals and instrumentation overhead visible."
patterns-established:
  - "A dependent CI optimization plan can check the exact frozen source identities before doing implementation work."
  - "Preparation step failures retain their exit and duration even when cleanup recovery succeeds."
requirements-completed: []
requirements-supported: [CISPEED-01, CISPEED-02]
coverage:
  - id: D1
    description: Frozen source preflight checks both exact commits, retained refs, tree, archive, workflow and six workload file digests.
    requirement: CISPEED-01
    verification:
      - kind: unit
        ref: scripts/ci/ci-baseline-source-preflight.test.mjs
        status: pass
      - kind: other
        ref: "node scripts/ci/ci-baseline-source-preflight.mjs --root . --contract .planning/phases/252-measure-current-ci/252-COMPARISON-CONTRACT.json --bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --output /tmp/254-source-check.json --check-only"
        status: pass
      - kind: integration
        ref: "scripts/ci/ci-run-metrics.sh --verify-baseline against the frozen bundle"
        status: pass
    human_judgment: false
  - id: D2
    description: Source-bound preparation timing records cover both bottleneck scopes and preserve unknown hosted timings and instrumentation disclosures.
    requirement: CISPEED-02
    verification:
      - kind: unit
        ref: scripts/ci/ci-prep-profile.test.mjs
        status: pass
      - kind: other
        ref: .planning/phases/254-speed-up-the-measured-slow-jobs/254-PREP-PROFILE.json
        status: pass
    human_judgment: false
actuals:
  tokens: 20523
  tasks: 2
  commits: 2
plan_head_before: 645c11e6923b6b28b22285d55ff0a4b43ee7e83b
plan_head_after: 97ea576614f2dcb00686030e635e5aa8be074846
metrics:
  duration: 49m
  completed: 2026-10-23
  status: complete
---

# Phase 254 Plan 01: Frozen-source preflight and preparation profile Summary

**The frozen Phase 252 inputs now pass a fresh offline check, and both slow browser-job preparation paths have source-bound component timings.**

## Performance

- **Duration:** approximately 49 minutes
- **Started:** approximately 2026-10-23 12:10 EDT
- **Completed:** 2026-10-23 12:59 EDT
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Verified application commit `d4dcc1939bd1f1590f6ca01d55b861e31acc745f` and producer commit `cc8cd273bfe8bbbfbab6b33564efdede4d9f0d17` through their retained refs. Both resolve to tree `bcda2b1eb386bdbaaf1bde2b6f034e0c7ee74452`; the bundle SHA-256 is `95334957b5b05494028ec72be5c95ee00e9ed4328e53fa78b35264c482a5af30`. The workflow and all six declared workload file digests matched, and the existing baseline replay verifier returned ready.
- Measured `admin_behavior` on Node 20.18.1 with Playwright 1.59.1: dependency fetch 2.0s, compilation 19.3s, database create/migrate/seeds 2.9s, `npm ci` 1.2s, Chromium preparation 27.7s, readiness 1.1s, followed by successful route warming.
- Measured `non_admin_smoke` with the same toolchain: dependency fetch 2.1s, compilation 20.0s, database create/migrate/seeds 3.0s, `npm ci` 1.2s, Chromium and WebKit preparation 36.5s, readiness 1.1s, followed by successful route warming.
- Bound both profiles to source commit `588497a4db5a5ab09ebb7e150f059f09f838943e`, the current action/workflow hashes, cold task-local caches, and the separate browser selections. Saved GitHub evidence exposes a 60-second outer composite boot step; it does not expose setup-beam or cache-restore internal durations. The frozen baseline cache-hit vector, reporter identities and overhead disclosures remain separate from local timings.

## Task Commits

1. **Task 1: Resolve the frozen source from contract through Git and archive to a ready/blocked result** - `588497a4d` (`feat`)
2. **Task 2: Measure the actual preparation path and retain component costs** - `97ea57661` (`feat`)

## Files Created/Modified

- `scripts/ci/ci-baseline-source-preflight.mjs` and its test - verifies exact frozen source identities and fails closed on mismatches.
- `scripts/ci/ci-prep-profile.mjs` and its test - extracts preparation commands and browser selection from the checked action/workflow, runs them in disposable checkouts, records elapsed times and exits, and cleans up scoped resources.
- `.planning/phases/254-speed-up-the-measured-slow-jobs/254-SOURCE-READINESS.json` - fresh ready source result.
- `.planning/phases/254-speed-up-the-measured-slow-jobs/254-PREP-PROFILE.json` - both real local profiles and explicitly unknown hosted/internal costs.

## Decisions Made

- The source preflight validates exact Git objects and the existing archive verifier. A synthetic fixture can exercise blocking behavior but cannot emit an actual-ready record.
- Local profiles use task-local Mix, Hex, npm and browser cache locations, plus distinct database names and ports. This run prepared browser binaries only; it did not invoke Playwright tests or introduce browser retries.
- Native GitHub timings remain labeled as outer composite timing or unknown. Reporter/setup/transfer costs and unmeasured instrumentation overhead are not estimated or subtracted from any target.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preserve cleanup failures and recover scoped database cleanup**
- **Found during:** Task 2
- **Issue:** `mix ecto.drop` returned exit 1 because the dev compile-time endpoint configuration differs from runtime configuration, and the initial profiler incorrectly let the scope report success.
- **Fix:** Preserve the Mix command exit and duration, then run a database-name-scoped `dropdb --if-exists` recovery. The final runs recorded recovery exit 0, confirmed the server stopped, and found no remaining Phase 254 databases.
- **Files modified:** `scripts/ci/ci-prep-profile.mjs`, `scripts/ci/ci-prep-profile.test.mjs`, `.planning/phases/254-speed-up-the-measured-slow-jobs/254-PREP-PROFILE.json`
- **Verification:** Profile assertions, local PostgreSQL database query, and recorded cleanup status.
- **Committed in:** `97ea57661`

**2. [Rule 2 - Security] Keep seeded demo credentials out of retained logs**
- **Found during:** Task 2
- **Issue:** Successful seed command output includes demo login credentials.
- **Fix:** Omit successful command log excerpts; redact email-adjacent credentials, labeled secrets and GitHub token shapes from any failure excerpt. Keep command exits, durations and log hashes.
- **Files modified:** `scripts/ci/ci-prep-profile.mjs`, `scripts/ci/ci-prep-profile.test.mjs`, `.planning/phases/254-speed-up-the-measured-slow-jobs/254-PREP-PROFILE.json`
- **Verification:** Redaction regression test and scan of the retained profile for known demo credentials and token forms.
- **Committed in:** `97ea57661`

**Total deviations:** 2 auto-fixed (1 bug, 1 security safeguard)
**Impact on plan:** Both changes keep subprocess failures visible and ensure the diagnostic leaves no database or credentials in its retained profile.

## Issues Encountered

- The frozen source baseline was ready; no dependent implementation blocker remains.
- `mix ecto.drop` fails its compile-environment check in the local dev configuration. The profile retains that failure and records successful scoped cleanup recovery rather than hiding the failed command.
- The saved GitHub job record does not split setup-beam or cache restoration out of its 60-second outer composite step. These internal durations remain unknown.
- This is development evidence only. No hosted comparison, warm-cache compatibility result, speed improvement or renewed acceptance allowance is claimed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The fresh source result is `ready`; the source-readiness gate permits dependent Phase 254 plans to proceed.
- Both bottleneck scopes have local preparation measurements. Treat the reported costs as observations from this machine, not as hosted acceptance results. Hosted cache/image readiness and internal setup-beam/cache timings remain unproven.

## Self-Check: PASSED

- All six plan output files exist.
- Task commits `588497a4d` and `97ea57661` are ancestors of the current branch.
- The two final local profiles report `profiled`, and server/database/cache cleanup evidence is present.

---
*Phase: 254-speed-up-the-measured-slow-jobs*
*Completed: 2026-10-23*
