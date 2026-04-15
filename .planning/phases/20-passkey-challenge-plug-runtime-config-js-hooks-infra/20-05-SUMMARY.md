---
phase: 20-passkey-challenge-plug-runtime-config-js-hooks-infra
plan: 05
subsystem: testing
tags: [passkeys, installer, exunit, integration]
requires:
  - phase: 20-03
    provides: GEN-06 passkey hook generation and installer integration coverage
provides:
  - Module-scoped timeout budget for the slow passkeys JS installer integration module
  - Verified default Phase 20 focused subset including GEN-06 without a CLI timeout override
affects: [phase-20-verification, generator, installer-tests]
tech-stack:
  added: []
  patterns: [module-scoped timeout budgeting for slow installer integration tests]
key-files:
  created:
    - .planning/phases/20-passkey-challenge-plug-runtime-config-js-hooks-infra/20-05-SUMMARY.md
  modified:
    - test/sigra/install/features/passkeys_js_test.exs
key-decisions:
  - "Budget the slow `mix sigra.install` coverage with a timeout scoped to `Sigra.Install.Features.PasskeysJsTest`, not a repo-wide ExUnit override."
  - "Keep fixture behavior unchanged because the focused Phase 20 subset passes under the default invocation once the module timeout is explicit."
patterns-established:
  - "Slow installer integration modules should declare their own timeout posture when the real tmp-app path exceeds ExUnit's default 60s budget."
requirements-completed: [GEN-06]
duration: 6min
completed: 2026-04-15
---

# Phase 20 Plan 05: Passkeys JS Verification Budget Summary

**Scoped the passkeys JS installer integration timeout so the real GEN-06 rerun coverage passes under the default focused Phase 20 verifier invocation**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-15T18:02:00Z
- **Completed:** 2026-04-15T18:08:08Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Added an explicit `180_000ms` timeout budget to the slow `Sigra.Install.Features.PasskeysJsTest` integration module.
- Kept the timeout scope local to the passkeys JS installer coverage instead of widening repo-wide ExUnit defaults.
- Re-verified the focused Phase 20 subset, including the real rerun/idempotency installer path, without any CLI `--timeout` override.

## Task Commits

Each task was committed atomically:

1. **Task 1: Set an explicit timeout posture for the slow installer integration path** - `175fd0a` (test)
2. **Task 2: Trim fixture overhead only if it materially improves the default pass path** - `1547932` (test)

## Files Created/Modified

- `test/sigra/install/features/passkeys_js_test.exs` - Adds a module-scoped timeout budget while preserving injection, rerun idempotency, manual fallback, and hook export coverage.
- `.planning/phases/20-passkey-challenge-plug-runtime-config-js-hooks-infra/20-05-SUMMARY.md` - Captures execution results and verification evidence for this plan.

## Decisions Made

- Used a module-level timeout because the whole file is a slow tmp-app installer integration module and the repo already uses scoped module budgets for expensive integration coverage.
- Left `test/support/install_fixture.ex` unchanged because the default-focused verifier subset already passes once the timeout contract is explicit.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- GEN-06 now verifies cleanly in the default focused Phase 20 suite.
- No extra fixture path or helper seam was required, so future installer integration work can keep using the existing real `mix sigra.install` path.

## Self-Check: PASSED

---
*Phase: 20-passkey-challenge-plug-runtime-config-js-hooks-infra*
*Completed: 2026-04-15*
