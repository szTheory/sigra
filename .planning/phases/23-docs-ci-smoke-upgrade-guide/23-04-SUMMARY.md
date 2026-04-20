---
phase: 23-docs-ci-smoke-upgrade-guide
plan: 04
subsystem: testing
tags: [credo, conventions, multi-tenancy, dx-09]
requires:
  - phase: 23-01
    provides: explicit docs and upgrade-guide posture for phase 23
provides:
  - narrow custom Credo enforcement for obvious unscoped org reads in lib/sigra
  - explicit DX-09 outcome text anchored to for_org/2 discipline
affects: [CONVENTIONS.md, Credo, tenant-scope enforcement]
tech-stack:
  added: []
  patterns: [custom Credo checks guarded by Code.ensure_loaded?, narrow schema-specific linting]
key-files:
  created:
    - lib/sigra/credo/no_unscoped_org_query_in_lib.ex
    - test/sigra/credo/no_unscoped_org_query_in_lib_test.exs
  modified:
    - .credo.exs
    - CONVENTIONS.md
key-decisions:
  - "Shipped DX-09 as a narrow Credo rule because the scoped implementation and focused tests fit comfortably under the 300-line budget."
  - "Kept the rule intentionally limited to obvious direct Repo.all/one/get/get_by schema calls so for_org/2 remains the primary tenant-scope contract."
patterns-established:
  - "New Sigra Credo checks should reuse the existing guarded module + .credo.exs requires wiring."
  - "DX-09 enforcement language in docs must state whether linting is shipped or conventions remain the only path."
requirements-completed: [DX-09]
duration: 2min
completed: 2026-04-16
---

# Phase 23 Plan 04: DX-09 narrow Credo enforcement and explicit shipped outcome summary

**DX-09 now ships as a bounded Credo check for obvious unscoped org queries, with `CONVENTIONS.md` explicitly recording that `for_org/2` remains the primary scoping discipline.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-16T16:19:30Z
- **Completed:** 2026-04-16T16:21:05Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added `Sigra.Credo.NoUnscopedOrgQueryInLib` as a narrow defense-in-depth check for direct `Repo.all/one/get/get_by` calls on known org-scoped schemas in `lib/sigra/**`.
- Wired the new check into `.credo.exs` using the existing custom-Credo loading pattern and proved it with focused ExUnit coverage.
- Recorded the shipped DX-09 outcome in `CONVENTIONS.md` so future contributors cannot infer the wrong enforcement posture.

## Task Commits

1. **Task 1: Run the DX-09 scoped-Credo spike against the existing custom-check infrastructure**
   - `9843523` `test(23-04): add failing tenant-scope credo spike tests`
   - `6e0514d` `feat(23-04): ship narrow unscoped org query credo check`
2. **Task 2: Record the DX-09 outcome explicitly in conventions and prove it automatically**
   - `a76f144` `docs(23-04): record DX-09 shipped credo outcome`

## Files Created/Modified

- `lib/sigra/credo/no_unscoped_org_query_in_lib.ex` - New custom Credo rule for obvious unscoped org reads.
- `test/sigra/credo/no_unscoped_org_query_in_lib_test.exs` - Focused RED/GREEN coverage for shipped and exempt cases.
- `.credo.exs` - Loads and enables the new Sigra Credo rule.
- `CONVENTIONS.md` - Adds the explicit DX-09 outcome section and keeps `for_org/2` as the primary discipline.

## Decisions Made

- Shipped the Credo path instead of the fallback because the rule and its focused tests stayed within the DX-09 300-line threshold.
- Limited the matcher to direct schema arguments and documented `skip_org_check: true` exceptions to avoid implying broader query-proof guarantees than the rule can actually enforce.

## Deviations from Plan

None - plan executed on the shipped-check branch exactly as intended.

## Issues Encountered

- The first rule implementation reused the repo-call arity lookup in a boolean expression and crashed the walker with `BadBooleanError`; the matcher was corrected before the task verification run.
- Directly aliased schema names were not flagged on the first pass; the matcher was narrowed to known schema suffixes so aliased and fully qualified forms are both covered by the focused tests.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- DX-09 is explicit in both tooling and conventions, so later docs and CI work can treat tenant-scope linting as shipped defense-in-depth.
- No blockers were introduced in the owned file set.

## Self-Check: PASSED

- Found `lib/sigra/credo/no_unscoped_org_query_in_lib.ex`
- Found `test/sigra/credo/no_unscoped_org_query_in_lib_test.exs`
- Found commit `9843523`
- Found commit `6e0514d`
- Found commit `a76f144`
