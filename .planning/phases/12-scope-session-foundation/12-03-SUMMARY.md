---
phase: 12-scope-session-foundation
plan: 03
subsystem: generator-templates
tags: [scope, session, templates, reserved-fields, invariant-test]
dependency_graph:
  requires: []
  provides: [scope-org-fields, session-org-column, impersonating-from-reservation, upgrade-doc]
  affects: [phase-14-plugs, phase-16-liveviews, v1.2-impersonation]
tech_stack:
  added: []
  patterns: [template-invariant-test, reserved-field-contract, compile-and-introspect-testing]
key_files:
  created:
    - test/sigra/install/scope_template_invariants_test.exs
    - test/sigra/install/scope_template_fields_test.exs
    - UPGRADE-v1.2.md
  modified:
    - priv/templates/sigra.install/core/scope.ex
    - priv/templates/sigra.install/core/user_session.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/scope.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/user_session.ex
decisions:
  - "Compile-and-introspect test path works cleanly (no fallback to second source-grep needed)"
  - "Golden fixture files updated alongside templates to keep golden diff test green"
metrics:
  duration: 18m
  completed: "2026-04-12T04:17:18Z"
  tasks_completed: 2
  tasks_total: 2
---

# Phase 12 Plan 03: Scope + Session Template Extensions Summary

Extended generated Scope and UserSession templates with org/impersonation fields, locked reserved field with invariant test, created UPGRADE-v1.2.md contract skeleton.

## One-liner

Scope defstruct extended to 4 fields (user, active_organization, membership, impersonating_from) with compile-and-introspect invariant test enforcing the v1.2 reservation contract.

## What Was Done

### Task 1: Extend scope.ex and user_session.ex templates (2c62328)

- Added 3 new fields to Scope defstruct: `active_organization: nil`, `membership: nil`, `impersonating_from: nil`
- Updated `@type t` with all 4 fields: `struct() | nil` for org/membership (Phase 13 tightens), `%User{} | nil` for impersonating_from
- Added `## Reserved fields` section to `@moduledoc` citing UPGRADE-v1.2.md
- Added inline doc comment above defstruct for v1.2 reservation
- Added `field :active_organization_id, :binary_id` to UserSession schema between `:sudo_at` and `belongs_to`
- Updated golden fixture files to match (both scope.ex and user_session.ex)
- TDD: wrote 5-test scope_template_fields_test.exs (RED: 4 failures, GREEN: 0 failures)
- `for_user/1` and `new/1` remain arity-1 (D-08 preserved)

### Task 2: Invariant test (D-11) + UPGRADE-v1.2.md (D-12) (addfbfb)

- Created `scope_template_invariants_test.exs` with 2 assertions:
  1. Source-level grep: confirms `impersonating_from: nil` in template source
  2. Compile-and-introspect: EEx-evaluates template, pre-compiles dummy User module, `Code.compile_string` on rendered source, asserts `:impersonating_from in Map.keys(struct)`
- Both failure messages cite UPGRADE-v1.2.md
- Created UPGRADE-v1.2.md skeleton at project root with 3 sections: Reserved fields in v1.1, v1.2 population contract (TBD), If you need to remove a reserved field (TBD)
- Compile-and-introspect path worked cleanly -- no fallback needed

## Decisions Made

1. **Compile-and-introspect test works**: The `Code.compile_string` approach for Test 2 worked without issues. No fallback to second source-grep was needed. The dummy `TestApp.Accounts.User` module pre-compilation pattern (Pitfall 7) resolved cleanly.
2. **Golden fixtures updated**: The golden diff test (`golden_diff_test.exs`) compares generated output byte-for-byte. Both fixture files were updated in the same commit as the template changes to keep the test green.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Golden diff test failure from template changes**
- **Found during:** Task 1 verification
- **Issue:** The golden diff test compares generated files byte-for-byte against fixtures. Template changes caused `golden_diff_test.exs` to fail (335 tests, 1 failure).
- **Fix:** Updated both golden fixture files (`scope.ex` and `user_session.ex` under `test/fixtures/install_golden/tree/`) to match the new template output.
- **Files modified:** `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/scope.ex`, `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/user_session.ex`
- **Commit:** 2c62328

## Sanity Check Results

**Manual sanity check performed:** Temporarily removed `impersonating_from: nil` from scope.ex defstruct. Both invariant tests failed:
- Test 1 (source-grep): Failed with "See UPGRADE-v1.2.md at the project root for the contract"
- Test 2 (compile-and-introspect): Failed with CompileError (struct key missing from type spec)
- Field restored, both tests green again.

## Verification Results

- `mix test test/sigra/install/scope_template_invariants_test.exs` -- 2 tests, 0 failures
- `mix test test/sigra/install/scope_template_fields_test.exs` -- 5 tests, 0 failures
- `mix test test/sigra/install/` -- 335 tests, 0 failures
- EEx template render smoke test -- OK for both templates
- `UPGRADE-v1.2.md` exists at project root
- `mix compile --warnings-as-errors` -- clean

## Self-Check: PASSED

All 8 files verified present. Both commit hashes (2c62328, addfbfb) found in git log.
