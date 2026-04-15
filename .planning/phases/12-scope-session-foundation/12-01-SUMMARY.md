---
phase: 12-scope-session-foundation
plan: 01
subsystem: session
tags: [session, scope, organization, struct, ecto-store]
dependency_graph:
  requires: []
  provides: [active_organization_id-on-session-struct, active_organization_id-ecto-round-trip]
  affects: [phase-14-org-plugs, phase-16-org-liveviews]
tech_stack:
  added: []
  patterns: [nullable-field-extension, map-get-default-nil]
key_files:
  created: []
  modified:
    - lib/sigra/session.ex
    - lib/sigra/session_stores/ecto.ex
    - test/sigra/session_test.exs
    - test/sigra/session_stores/ecto_test.exs
    - test/support/test_user_session.ex
decisions: []
metrics:
  duration_seconds: 278
  completed: "2026-04-12T04:04:13Z"
  tasks_completed: 2
  tasks_total: 2
  tests_added: 7
  files_modified: 5
---

# Phase 12 Plan 01: Session Struct active_organization_id Extension Summary

Nullable `:active_organization_id` field added to `%Sigra.Session{}` struct with full round-trip through `Sigra.SessionStores.Ecto` create and fetch paths -- the library-side write/read half of ORG-SCOPE-02.

## What Changed

### Task 1: Extend %Sigra.Session{} struct (1eef2ff)

Added `:active_organization_id` to three locations in `lib/sigra/session.ex`:
1. `@type t` -- `active_organization_id: binary() | nil` between `:sudo_at` and `:inserted_at`
2. `defstruct` -- `active_organization_id: nil` in keyword form (avoids Pitfall 1: atoms-before-keywords)
3. `## Fields` doc block -- one-line entry documenting the field

Test coverage: 2 new assertions in `test/sigra/session_test.exs` -- explicit value construction and nil default.

### Task 2: Round-trip through SessionStores.Ecto (23aa5a7)

Updated three files:
1. `test/support/test_user_session.ex` -- added `field :active_organization_id, :binary_id` to Mox test schema
2. `lib/sigra/session_stores/ecto.ex` `create/3` -- `active_organization_id: Map.get(metadata, :active_organization_id)` in attrs map
3. `lib/sigra/session_stores/ecto.ex` `to_session/1` -- `active_organization_id: Map.get(record, :active_organization_id)` in struct literal

Test coverage: 5 new assertions in `test/sigra/session_stores/ecto_test.exs`:
- Create with explicit org_id passes through to stored record
- Create without org_id defaults to nil
- Fetch round-trips org_id through to_session/1
- Fetch defaults to nil when field not set on record
- (Plus Mox expectation assertions inside each test)

## Verification

- `mix test test/sigra/session_test.exs` -- 5 tests, 0 failures
- `mix test test/sigra/session_stores/ecto_test.exs` -- 16 tests, 0 failures
- `mix test test/sigra/session_stores/` -- 16 tests, 0 failures (no sibling regressions)
- `mix compile --warnings-as-errors` -- clean

## Invariants Preserved

- `Sigra.SessionStore` behaviour callbacks unchanged (7 callbacks, no signature changes)
- `update_activity/3` and `update_sudo/3` untouched (verified via focused diff)
- Phase 11 `:primary` migration template not modified
- defstruct keyword-form ordering maintained (no bare atom insertion)

## Modification Sites (6 total)

1. `lib/sigra/session.ex` -- `@type t` block
2. `lib/sigra/session.ex` -- `defstruct` block
3. `lib/sigra/session.ex` -- `## Fields` doc block
4. `lib/sigra/session_stores/ecto.ex` -- `create/3` attrs map
5. `lib/sigra/session_stores/ecto.ex` -- `to_session/1` struct literal
6. `test/support/test_user_session.ex` -- Mox test schema

## Deviations from Plan

None -- plan executed exactly as written.

## Known Stubs

None -- no stubs or placeholders introduced.

## Self-Check: PASSED

- [x] `lib/sigra/session.ex` modified with field in type, struct, and docs
- [x] `lib/sigra/session_stores/ecto.ex` modified with create and to_session additions
- [x] `test/support/test_user_session.ex` modified with :binary_id field
- [x] `test/sigra/session_test.exs` modified with 2 new assertions
- [x] `test/sigra/session_stores/ecto_test.exs` modified with 5 new test assertions
- [x] Commit 1eef2ff exists
- [x] Commit 23aa5a7 exists
