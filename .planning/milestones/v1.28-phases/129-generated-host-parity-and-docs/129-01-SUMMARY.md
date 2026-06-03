---
phase: 129-generated-host-parity-and-docs
plan: 01
subsystem: generated-host
tags: [data-export, account-lifecycle, generator, golden-fixture, phoenix]

requires:
  - phase: 127-versioned-auth-data-export
    provides: Sigra.DataExport.export_auth_data/3 with omission truth
  - phase: 128-account-deletion-lifecycle-truth
    provides: Library-owned deletion lifecycle scheduling and finalization truth
provides:
  - Generated host export_auth_data/2 wrapper delegating to Sigra.DataExport.export_auth_data/3
  - Example app export_auth_data/2 wrapper with sensitive-operation guard
  - Strategy-neutral generated/example/golden deletion lifecycle copy
  - Reblessed install golden fixture matching updated templates
affects: [129-generated-host-parity-and-docs, generated-host, data-lifecycle, install-golden]

tech-stack:
  added: []
  patterns:
    - Thin generated/export wrappers pass repo, user, and schema opts into Sigra.DataExport
    - Core generated export defaults include only always-core schemas and merge caller opts
    - Golden fixture changes are regenerated from templates

key-files:
  created:
    - .planning/phases/129-generated-host-parity-and-docs/129-01-SUMMARY.md
  modified:
    - test/sigra/templates/settings_live_test.exs
    - test/sigra/install/isolation_test.exs
    - priv/templates/sigra.install/core/auth.ex
    - priv/templates/sigra.install/core/settings_live.ex
    - priv/templates/sigra.install/core/reactivation_live.ex
    - priv/templates/sigra.install/core/emails.ex
    - test/example/lib/example/accounts.ex
    - test/example/lib/example_web/live/reactivation_live.ex
    - test/example/lib/example/accounts/emails.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/settings_live.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/reactivation_live.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/emails.ex

key-decisions:
  - "Kept generated core export defaults limited to UserSession, AuditEvent, UserMFACredential, and UserBackupCode."
  - "Left identity_schema, user_passkey_schema, and membership_schema to caller opts or separately generated/gated code."
  - "Kept export payload construction in Sigra.DataExport rather than generated host code."

patterns-established:
  - "Generated host data-export wrappers should be thin delegates over Sigra.DataExport.export_auth_data/3."
  - "Install golden fixture updates must be produced by MIX_ENV=test mix sigra.fixture.rebless_golden."

requirements-completed: [HOST-01]

duration: 11min
completed: 2026-05-27
---

# Phase 129 Plan 01: Generated Host Parity And Docs Summary

**Generated host, example app, and install golden now expose thin Sigra-owned auth export wrappers and strategy-neutral lifecycle copy.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-05-27T09:33:52Z
- **Completed:** 2026-05-27T09:44:46Z
- **Tasks:** 3
- **Files modified:** 13

## Accomplishments

- Added RED template/isolation tests proving generated auth export delegates to `Sigra.DataExport.export_auth_data/3`, core defaults avoid optional schemas, and stale deletion copy is rejected.
- Added generated and example `export_auth_data/2` wrappers that merge caller opts with default schema opts instead of rebuilding payload shape.
- Replaced broad permanent-removal lifecycle copy with configured-strategy wording across templates, example app surfaces, and golden output.
- Reblessed the install golden fixture from templates and verified golden diff parity.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Wave 0 template assertions for export delegation and deletion-copy truth** - `fc1893b` (test)
2. **Task 2: Implement thin generated/example export wrappers and soften lifecycle copy** - `8e8d137` (feat)
3. **Task 3: Rebless and verify install golden parity** - `b5e00a6` (chore)

**Plan metadata:** pending final docs commit

## Files Created/Modified

- `test/sigra/templates/settings_live_test.exs` - Adds raw template assertions for export wrapper delegation, core schema defaults, and lifecycle copy truth.
- `test/sigra/install/isolation_test.exs` - Adds core export default isolation coverage for optional schema keys.
- `priv/templates/sigra.install/core/auth.ex` - Adds generated `export_auth_data/2` and always-core `default_auth_export_opts/0`.
- `priv/templates/sigra.install/core/settings_live.ex` - Replaces overbroad account deletion copy with configured-strategy wording.
- `priv/templates/sigra.install/core/reactivation_live.ex` - Replaces permanent-removal scheduled deletion copy.
- `priv/templates/sigra.install/core/emails.ex` - Replaces finalized deletion email copy with configured-strategy wording.
- `test/example/lib/example/accounts.ex` - Adds guarded example `export_auth_data/2` with example-specific optional schemas.
- `test/example/lib/example_web/live/reactivation_live.ex` - Mirrors strategy-neutral reactivation copy.
- `test/example/lib/example/accounts/emails.ex` - Mirrors strategy-neutral finalized deletion email copy.
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex` - Reblessed generated export wrapper evidence.
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/settings_live.ex` - Reblessed settings copy evidence.
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/reactivation_live.ex` - Reblessed reactivation copy evidence.
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/emails.ex` - Reblessed email copy evidence.

## Decisions Made

- Core generated defaults intentionally omit `identity_schema`, `user_passkey_schema`, and `membership_schema` so missing optional generators still surface as `Sigra.DataExport` omissions.
- The example app may pass `UserPasskey` and `OrganizationMembership` because those modules exist in `test/example`; it does not pass `identity_schema` because no `Example.Accounts.UserIdentity` module exists.
- Generated lifecycle wrappers remain thin delegates to the library-owned lifecycle contract.

## Verification

- `mix test test/sigra/templates/settings_live_test.exs test/sigra/install/isolation_test.exs --max-failures 1` - passed, 48 tests, 0 failures.
- `MIX_ENV=test mix sigra.fixture.rebless_golden && mix test test/sigra/install/golden_diff_test.exs test/sigra/templates/settings_live_test.exs test/sigra/install/isolation_test.exs --max-failures 1` - passed, 50 tests, 0 failures.
- `mix test test/sigra/templates/settings_live_test.exs test/sigra/install/isolation_test.exs test/sigra/install/golden_diff_test.exs --max-failures 1` - passed, 50 tests, 0 failures.
- `mix format --check-formatted test/sigra/templates/settings_live_test.exs test/sigra/install/isolation_test.exs test/example/lib/example/accounts.ex test/example/lib/example_web/live/settings_live.ex test/example/lib/example_web/live/reactivation_live.ex test/example/lib/example/accounts/emails.ex` - passed.
- `mix format --check-formatted ... priv/templates/sigra.install/core/*.ex ...` - failed because raw EEx templates start with placeholders such as `defmodule <%= context_module %> do`, which `mix format` parses as invalid Elixir outside the generator render step.

## Deviations from Plan

None - plan implementation executed as written.

## Issues Encountered

- The plan-level format command includes raw EEx template files. Running it exactly failed with `SyntaxError` on `priv/templates/sigra.install/core/auth.ex:1:13` before formatter checks could run. The generated/non-template `.ex` and `.exs` files were checked separately and passed.

## Known Stubs

None in files modified by this plan.

## Threat Flags

None. The plan's threat register already covered the modified generated-host export boundary, optional schema defaults, lifecycle copy, and install golden fixture.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

`HOST-01` is satisfied for generated templates, the example app, and the install golden fixture. Documentation parity is covered by Plan 02.

---
*Phase: 129-generated-host-parity-and-docs*
*Completed: 2026-05-27*

## Self-Check: PASSED

- Found `.planning/phases/129-generated-host-parity-and-docs/129-01-SUMMARY.md`.
- Found all 13 modified source/test/golden files.
- Found task commit `fc1893b`.
- Found task commit `8e8d137`.
- Found task commit `b5e00a6`.
