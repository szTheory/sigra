---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "58"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, controls, r3]
requires:
  - phase: 253
    provides: 253-57 enumeration-safe library fix
provides:
  - held-readiness positive control with mandatory post-readiness refill
  - email_value_after_ready_was_empty annotation to confirm/falsify debug cause 1
  - offline stage-order contract and static spec pins
affects: [253-59, 253-63]
actuals:
  tokens: 3000
  tasks: 2
  commits: 2
  plan_head_before: 21c6fd9d1
  plan_head_after: d93b1cbf4c205c1f0a2b8e62ea562e8b46e334b0
commits: 2
plan_head_before: 21c6fd9d1
plan_head_after: d93b1cbf4c205c1f0a2b8e62ea562e8b46e334b0
key-files:
  modified:
    - test/example/priv/playwright/helpers/registrationControls.mjs
    - test/example/priv/playwright/tests/admin-eval.spec.ts
    - scripts/ci/ci-registration-control-audit.test.mjs
key-decisions:
  - "refillAfterReady is mandatory (TypeError before any page interaction) so no caller can skip it"
requirements-completed: ["CIREL-01"]
duration: 10min
completed: 2026-10-14
status: complete
---

# Phase 253 Plan 58: Positive control refill Summary

**Held-readiness positive control now re-fills and asserts email/password after LiveView readiness and before submit, and records whether the join wiped the email; collision expectation untouched and both pinned offline.**

## Accomplishments
- `runHeldRegistrationControl` requires `refillAfterReady`; stage order is hold, fill, release, ready, refill, submit, success (annotation `readiness_refill`).
- Spec positive control only: reads email value after ready (annotated as `email_value_after_ready_was_empty`, boolean, no address), re-fills both fields, asserts both with `toHaveValue`.
- Static pins parse the positive and collision test bodies; the pin passes on HEAD and throws on preserved R2 blob 16be503276de.

## Task Commits
1. Task 1 (RED then GREEN, test/helper/spec) - `5e1fcd3f0`
2. Task 2 static pins - `d93b1cbf4`

## Verification
- RED: audit test 2 failures before helper edit (stage order, missing TypeError). GREEN: 7/7 pass.
- Node 20.18.1: ci-playwright-load + ci-registration-control-audit: 23 tests, 23 pass, 0 fail, 0 skipped (16/2/2/2 collection unchanged).
- No Playwright CLI/browser launched. No timeout/retry changes. Collision text unchanged.

## Deviations from Plan
None - plan executed exactly as written.

## Known Stubs
None.

## Remaining gaps
Native confirmation of the wipe observation and positive-control pass belongs to the budgeted 253-63 window. Phase 253 verification stays not_started.

## Self-Check: PASSED
