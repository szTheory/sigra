---
phase: 27-admin-access-foundation
plan: 1
subsystem: auth
tags: [installer, phoenix, liveview, admin, feature-manifest]
requires:
  - phase: 26-retroactive-v1-1-verification-closeout
    provides: v1.1 closeout and current installer baseline
provides:
  - default-on admin installer feature registration with --no-admin opt-out
  - generated host admin policy and shell template seams
  - admin template ownership coverage in installer tests
affects: [phase-27-plan-02, admin-runtime, installer]
tech-stack:
  added: []
  patterns: [additive installer feature, host-owned policy seam, router live_session injection]
key-files:
  created:
    - lib/sigra/install/features/admin.ex
    - lib/sigra/admin/policy.ex
    - priv/templates/sigra.install/admin/policy.ex
    - priv/templates/sigra.install/admin/router_injection.ex
    - priv/templates/sigra.install/admin/components/admin_shell.ex
    - test/sigra/install/features/admin_test.exs
  modified:
    - lib/mix/tasks/sigra.install.ex
    - test/sigra/install/features/coverage_test.exs
    - test/sigra/install/purely_additive_test.exs
key-decisions:
  - "Admin is a first-class installer feature enabled by default and omitted only via --no-admin."
  - "The generated host app owns only the admin policy module and shell component; long-lived runtime stays library-owned."
  - "Admin router wiring uses normal Phoenix scopes and live_session blocks rather than forward."
patterns-established:
  - "Installer features can add host-owned boundary files without leaking ownership into sibling features."
  - "Coverage ownership tests must include injection templates and any new feature subdirectory."
requirements-completed: [ADMIN-01, ADMIN-02]
duration: 4 min
completed: 2026-04-16
---

# Phase 27 Plan 1: Admin Access Foundation Summary

**Default-on admin installer scaffolding with an explicit host policy seam, router mount fragment, and ownership-tested admin templates**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-16T19:04:14Z
- **Completed:** 2026-04-16T19:08:19Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- Registered admin as a default-on installer feature with `--no-admin` opt-out wiring in `mix sigra.install`.
- Added the new `Sigra.Install.Features.Admin` manifest plus generated host policy, shell, and router fragment templates.
- Extended installer coverage so every template under `priv/templates/sigra.install/admin/` has a pinned feature owner.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create admin installer manifest tests and ownership guards** - `214eb48` (test)
2. **Task 2: Implement the default-on admin feature manifest and generated host boundary files** - `e9d5da2` (feat)

## Files Created/Modified
- `lib/mix/tasks/sigra.install.ex` - Registers the admin feature, switch, default option, and binding flag.
- `lib/sigra/install/features/admin.ex` - Defines the additive admin installer manifest.
- `lib/sigra/admin/policy.ex` - Provides the behaviour referenced by the generated host policy.
- `priv/templates/sigra.install/admin/policy.ex` - Generates the explicit host-owned admin policy contract.
- `priv/templates/sigra.install/admin/router_injection.ex` - Injects `/admin` and `/admin/organizations/:org` router scopes with `live_session`.
- `priv/templates/sigra.install/admin/components/admin_shell.ex` - Generates the host-owned admin shell seam with required scope copy anchors.
- `test/sigra/install/features/admin_test.exs` - Pins default-on admin enablement, file ownership, and router fragment expectations.
- `test/sigra/install/features/coverage_test.exs` - Adds the admin template subtree to feature ownership coverage.
- `test/sigra/install/purely_additive_test.exs` - Keeps the additive installer invariant valid now that admin is in `@features`.

## Decisions Made
- Added `Sigra.Admin.Policy` now because the generated host policy references it directly; leaving that behaviour undefined would generate a broken host seam.
- Kept the router fragment on plain Phoenix scopes plus `live_session` blocks so the phase preserves the future Plug/LiveView enforcement boundary.
- Left admin runtime modules out of this plan; Plan 27-02 owns authorization and runtime enforcement.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added the minimal admin feature skeleton during Task 1**
- **Found during:** Task 1
- **Issue:** The new admin installer tests could not run at all until the admin feature module and owned templates existed on disk.
- **Fix:** Added `Sigra.Install.Features.Admin` plus the initial admin templates in the same task so the focused suite could execute and prove ownership.
- **Files modified:** `lib/sigra/install/features/admin.ex`, `priv/templates/sigra.install/admin/policy.ex`, `priv/templates/sigra.install/admin/router_injection.ex`, `priv/templates/sigra.install/admin/components/admin_shell.ex`
- **Verification:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/features/admin_test.exs test/sigra/install/features/coverage_test.exs --max-failures 1`
- **Committed in:** `214eb48`

**2. [Rule 2 - Missing Critical] Added the library behaviour seam for generated admin policy**
- **Found during:** Task 2
- **Issue:** The generated host policy template referenced `Sigra.Admin.Policy`, but that behaviour module did not exist in the library.
- **Fix:** Added `lib/sigra/admin/policy.ex` and updated the additive invariant test to accept Admin as a single `@features` entry.
- **Files modified:** `lib/sigra/admin/policy.ex`, `test/sigra/install/purely_additive_test.exs`
- **Verification:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/features/admin_test.exs test/sigra/install/features/coverage_test.exs test/sigra/install/purely_additive_test.exs --max-failures 1`
- **Committed in:** `e9d5da2`

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 missing critical)
**Impact on plan:** Both fixes were required to keep the installer contract runnable and to avoid generating an invalid host policy seam. Scope stayed within Plan 27-01.

## Issues Encountered
None

## Known Stubs

- `priv/templates/sigra.install/admin/policy.ex:14` - `platform_admin?/1` intentionally returns `false` with a TODO because the host app must define explicit platform-admin rules.
- `priv/templates/sigra.install/admin/policy.ex:22` - `admin_org_ids/1` intentionally returns `[]` with a TODO because org-admin scope remains host-owned and explicit.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Ready for Plan 27-02 to add library-owned admin authorization, resolved admin scope, and Plug/LiveView enforcement.
- The installer now produces the host-owned policy and shell seams that later runtime work will call into.

## Self-Check: PASSED

- Found `.planning/phases/27-admin-access-foundation/27-admin-access-foundation-01-SUMMARY.md`
- Found commit `214eb48`
- Found commit `e9d5da2`
