---
phase: 219-baseline-recapture-canary-reconciliation
plan: 01
subsystem: testing
tags: [phoenix, heex, liveview, example-host, compile-gate]

# Dependency graph
requires:
  - phase: 218-elevation-wave-nit-cleanup
    provides: mfa_settings_live.ex `<.icon style=...>` call sites (D-02 blocker origin)
provides:
  - "Example icon/1 now declares `attr :rest, :global` and spreads `{@rest}` onto the rendered span"
  - "`mix compile --warnings-as-errors` in test/example exits 0, unblocking every downstream Phase 219 recapture/smoke/parity job"
affects: [219-02, 219-03, 219-04, 219-05, admin-recapture, admin-smoke, admin-parity]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Phoenix HEEx components that accept arbitrary global attributes should declare `attr :rest, :global` and spread `{@rest}`, rather than hand-listing every allowed attribute."]

key-files:
  created: []
  modified:
    - test/example/lib/example_web/components/core_components.ex

key-decisions:
  - "Fixed the durable/recurrence-proof way (`:global` attr + `{@rest}` spread on icon/1) per D-02, instead of stripping the inline `style=` from the two mfa_settings_live.ex call sites."
  - "Left priv/templates/sigra.install/** untouched — this is an example-only fix; no golden fixture rebless triggered."

patterns-established:
  - "Example-only HEEx component fixes that don't touch the installer template surface do not require a golden fixture rebless."

requirements-completed: [RECAP-01]

coverage:
  - id: D1
    description: "Example icon/1 accepts and forwards arbitrary global attributes (style, data-*, aria-*) via attr :rest, :global + {@rest} spread"
    requirement: "RECAP-01"
    verification:
      - kind: other
        ref: "cd test/example && MIX_ENV=dev mix compile --warnings-as-errors"
        status: pass
    human_judgment: false

# Metrics
duration: 5min
completed: 2026-07-09
status: complete
---

# Phase 219 Plan 01: Example icon/1 global-attribute fix Summary

**Added `attr :rest, :global` + `{@rest}` spread to the example host's `icon/1` component, clearing the `mix compile --warnings-as-errors` blocker (D-02) that was killing every downstream Phase 219 recapture/smoke/parity job at the compile step.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-07-09T20:17:07Z
- **Completed:** 2026-07-09T20:21:25Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- `ExampleWeb.CoreComponents.icon/1` now declares `attr :rest, :global` alongside `:name` and `:class`, and spreads `{@rest}` onto the rendered `<span>`.
- `cd test/example && MIX_ENV=dev mix compile --warnings-as-errors` now exits 0 (previously failed with `undefined attribute "style" for component ExampleWeb.CoreComponents.icon/1`, triggered by the two `<.icon style=...>` call sites in `mfa_settings_live.ex:250` and `:328`).
- No changes made under `priv/templates/sigra.install/**`; no golden fixture rebless triggered; `mfa_settings_live.ex` left unchanged (fix is entirely local to `icon/1`).

## Task Commits

Each task was committed atomically:

1. **Task 1: Add :global attr + {@rest} spread to the example icon/1 (D-02)** - `8670b514` (fix)

**Plan metadata:** (this commit, following SUMMARY/STATE/ROADMAP updates)

## Files Created/Modified
- `test/example/lib/example_web/components/core_components.ex` - `icon/1` now declares `attr :rest, :global` and renders `<span class={[@name, @class]} {@rest} />`

## Decisions Made
- Chose the `:global` attribute + `{@rest}` spread approach over stripping `style=` from call sites — durable and recurrence-proof per D-02: any future inline attribute (data-*, aria-*, additional style props) on `<.icon>` call sites will now compile without further icon/1 edits.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- The example host app now compiles cleanly under `--warnings-as-errors`, unblocking Plans 219-02 through 219-05 (recapture/smoke/parity jobs that all run this compile step before Playwright boots).
- No blockers identified for subsequent Phase 219 plans.

---
*Phase: 219-baseline-recapture-canary-reconciliation*
*Completed: 2026-07-09*

## Self-Check: PASSED

- FOUND: test/example/lib/example_web/components/core_components.ex
- FOUND: 8670b514 (task commit)
