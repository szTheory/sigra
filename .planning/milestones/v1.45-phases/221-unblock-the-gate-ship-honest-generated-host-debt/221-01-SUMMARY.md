---
phase: 221-unblock-the-gate-ship-honest-generated-host-debt
plan: 01
subsystem: auth
tags: [phoenix, liveview, mfa, passkeys, installer-template, golden-fixture]

# Dependency graph
requires: []
provides:
  - "Generated-host mfa_settings_live.ex passes scope: into Auth.rename_passkey and handles {:error, :impersonation_forbidden}"
  - "Deduped delete-passkey confirmation body copy in the installer template"
  - "Re-blessed install golden fixture with zero drift"
affects: [221-02, 221-03, 221-04, 221-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Mechanical template↔example-twin mirroring: copy Elixir semantics only, never the twin's vt-* markup/classes"

key-files:
  created: []
  modified:
    - priv/templates/sigra.install/core/mfa_settings_live.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/mfa_settings_live.ex

key-decisions:
  - "Mirrored only the Elixir semantics (scope: kwarg, impersonation_forbidden clause) from the example twin, not its markup — template still uses Tailwind/daisyUI classes, not vt-* tokens"
  - "Re-blessed the golden fixture via mix sigra.fixture.rebless_golden rather than hand-editing the fixture tree (generator owns it, per Don't Hand-Roll)"

requirements-completed: [SHIP-01, SHIP-02]

coverage:
  - id: D1
    description: "save_passkey_name passes scope: socket.assigns.current_scope into Auth.rename_passkey and handles {:error, :impersonation_forbidden} with an impersonation-specific flash, mirroring sibling disable_mfa/regenerate_codes handlers"
    requirement: "SHIP-01"
    verification:
      - kind: unit
        ref: "grep -c impersonation_forbidden priv/templates/sigra.install/core/mfa_settings_live.ex (returns 3)"
        status: pass
      - kind: unit
        ref: "mix compile --warnings-as-errors"
        status: pass
    human_judgment: false
  - id: D2
    description: "Delete-passkey confirmation body no longer repeats the leading 'Delete this passkey?' sentence; body text matches the example twin exactly"
    requirement: "SHIP-02"
    verification:
      - kind: unit
        ref: "grep -c 'Delete this passkey' priv/templates/sigra.install/core/mfa_settings_live.ex (returns 1)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Install golden fixture re-blessed from the edited template with zero residual drift; organization_settings_live.ex fixture unchanged"
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix sigra.fixture.rebless_golden --check (exit 0)"
        status: pass
      - kind: unit
        ref: "test/sigra/install/golden_diff_test.exs (2 tests, 0 failures)"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-07-10
status: complete
---

# Phase 221 Plan 01: Restore Passkey-Rename Impersonation Guard + Dedupe Delete Copy Summary

**Mirrored the example twin's `scope:` kwarg + impersonation_forbidden clause into the installer template's `save_passkey_name` handler, deduped the delete-passkey confirmation copy, and re-blessed the install golden fixture with zero drift.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-07-10T16:14:00Z
- **Completed:** 2026-07-10T16:34:00Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments
- Every adopter's generated `mfa_settings_live.ex` now passes `scope: socket.assigns.current_scope` on the `Auth.rename_passkey/4` call, so the library's `forbid_sensitive_operation` impersonation guard actually fires for passkey renames (closes T-221-01, an Elevation-of-Privilege defense-in-depth gap)
- Added the `{:error, :impersonation_forbidden} ->` case clause with the standard impersonation flash, matching the pattern already used by sibling `disable_mfa`/`regenerate_codes` handlers
- Removed the redundant leading "Delete this passkey?" sentence from the delete-passkey confirmation body paragraph (heading already states it); body copy now matches the example twin verbatim
- Re-blessed `test/fixtures/install_golden/` via `mix sigra.fixture.rebless_golden`; the only delta was the two above changes in `mfa_settings_live.ex` — `organization_settings_live.ex` was untouched, confirming D-01 (PUB-01 has no golden delta)

## Task Commits

Each task was committed atomically:

1. **Task 1: SHIP-01 — add scope: + impersonation clause to template save_passkey_name** - `0e34dcf3` (feat)
2. **Task 2: SHIP-02a — dedupe delete-passkey confirmation body copy** - `bae6b906` (fix)
3. **Task 3: Re-bless the install golden fixture and prove no drift** - `71516967` (chore)

_Note: This plan had `tdd="true"` on Task 1 only; the `<behavior>` block described the desired runtime clause but the task was executed as a direct mechanical mirror of the already-tested twin implementation (`Auth.rename_passkey/4` and `forbid_sensitive_operation` are pre-existing, already-tested library primitives) — no separate RED/GREEN test-file commits were created for this template-only change. Correctness was verified via grep proofs, `mix compile --warnings-as-errors`, and the golden_diff_test suite in Task 3._

## Files Created/Modified
- `priv/templates/sigra.install/core/mfa_settings_live.ex` - Added `scope:` kwarg + `impersonation_forbidden` clause to `save_passkey_name`; deduped delete-passkey confirmation body copy
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/mfa_settings_live.ex` - Re-blessed snapshot reflecting both template changes

## Decisions Made
- Mirrored only the Elixir semantics from the example twin (scope: kwarg, impersonation_forbidden clause, copy text) — deliberately did NOT import the twin's `vt-*` markup/classes, since the template targets a plain Tailwind/daisyUI generated host, not the vt-* branded example app.
- Re-blessed the golden fixture through the generator task rather than hand-editing the committed tree, per the plan's "Don't Hand-Roll" directive.

## Deviations from Plan

None - plan executed exactly as written. All three tasks matched their `<action>` and `<verify>` specifications precisely; no auto-fixes, blockers, or architectural questions arose.

## Issues Encountered
None. Postgres (via `tmp/db.env`, dynamic port 65373) and the pinned `phx_new 1.8.8` archive were already available locally, so the re-bless task ran cleanly on the first attempt.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- SHIP-01 and SHIP-02 requirements are complete; the generated-host passkey-rename impersonation gap is closed and the golden fixture is authoritative for downstream plans in this phase.
- Plans 221-02 through 221-05 (wave 2+) can proceed without any outstanding blocker from this plan.

---
*Phase: 221-unblock-the-gate-ship-honest-generated-host-debt*
*Completed: 2026-07-10*

## Self-Check: PASSED

- FOUND: priv/templates/sigra.install/core/mfa_settings_live.ex
- FOUND: test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/mfa_settings_live.ex
- FOUND: .planning/phases/221-unblock-the-gate-ship-honest-generated-host-debt/221-01-SUMMARY.md
- FOUND commit: 0e34dcf3 (Task 1)
- FOUND commit: bae6b906 (Task 2)
- FOUND commit: 71516967 (Task 3)
