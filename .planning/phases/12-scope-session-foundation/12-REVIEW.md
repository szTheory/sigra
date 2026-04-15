---
phase: 12-scope-session-foundation
reviewed: 2026-04-11T18:45:00Z
depth: standard
files_reviewed: 22
files_reviewed_list:
  - lib/sigra/session.ex
  - lib/sigra/session_stores/ecto.ex
  - lib/sigra/install/features/core.ex
  - priv/templates/sigra.install/core/add_active_organization_id_to_user_sessions.exs
  - priv/templates/sigra.install/core/scope.ex
  - priv/templates/sigra.install/core/user_session.ex
  - UPGRADE-v1.2.md
  - test/example/lib/example/accounts/scope.ex
  - test/example/lib/example/accounts/user_session.ex
  - test/example/priv/repo/migrations/20260410125243_add_active_organization_id_to_user_sessions.exs
  - test/example/test/example_web/smoke/session_active_org_round_trip_test.exs
  - test/fixtures/install_golden/STDOUT.txt
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/scope.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/user_session.ex
  - test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_add_active_organization_id_to_user_sessions.exs
  - test/sigra/install/features/core_test.exs
  - test/sigra/install/isolation_test.exs
  - test/sigra/install/scope_template_fields_test.exs
  - test/sigra/install/scope_template_invariants_test.exs
  - test/sigra/install/templates_layout_test.exs
  - test/sigra/session_stores/ecto_test.exs
  - test/sigra/session_test.exs
  - test/support/test_user_session.ex
findings:
  critical: 1
  warning: 1
  info: 2
  total: 4
status: issues_found
---

# Phase 12: Code Review Report

**Reviewed:** 2026-04-11T18:45:00Z
**Depth:** standard
**Files Reviewed:** 22
**Status:** issues_found

## Summary

Phase 12 adds the `active_organization_id` field to the session struct, Ecto store, generated schemas/templates, and migration. The implementation is clean and well-tested, with thorough coverage including golden-diff fixtures, reserved-field invariant tests, isolation boundary tests, and E2E round-trip tests. The new field flows correctly through `create/3`, `fetch/2`, and `to_session/1`.

One critical bug was found in pre-existing code (`to_session/1` silently drops the `mfa_pending` session type), which was not introduced by Phase 12 but is in scope since the function was modified to add the `active_organization_id` mapping. One warning about a fragile boolean expression pattern. Two minor info items.

## Critical Issues

### CR-01: `to_session/1` silently converts `"mfa_pending"` sessions to `:standard`

**File:** `lib/sigra/session_stores/ecto.ex:148-154`
**Issue:** The `to_session/1` type conversion handles `"standard"` and `"remember_me"` explicitly but falls through to `_ -> :standard` for any other string. Since `mfa_pending` sessions are stored as the string `"mfa_pending"` in the database (see `lib/sigra/workers/token_cleanup.ex:98`), they are silently converted to `:standard` when fetched. This defeats MFA enforcement: `Sigra.Plug.RequireMFA` checks `session.type == :mfa_pending` to redirect to the MFA challenge page, and `Sigra.Auth` line 1109 filters out `:mfa_pending` sessions from listings. With `to_session/1` converting the type to `:standard`, an MFA-pending session would bypass the MFA challenge entirely -- the user would be treated as fully authenticated without completing the second factor.

This bug predates Phase 12 but is in the modified file and directly affects session security.

**Fix:**
```elixir
type =
  case record.type do
    "standard" -> :standard
    "remember_me" -> :remember_me
    "mfa_pending" -> :mfa_pending
    type when is_atom(type) -> type
    _ -> :standard
  end
```

## Warnings

### WR-01: `delete/2` uses `&&` for sequencing side effects

**File:** `lib/sigra/session_stores/ecto.ex:70`
**Issue:** The expression `repo.delete!(record) && :ok` uses boolean short-circuit for sequencing. If `repo.delete!/1` returns a falsy value (which it should not per Ecto's contract, but defensive code should not rely on return value truthiness for correctness), the function would return `false` instead of `:ok`. More importantly, this is a non-idiomatic Elixir pattern that hides intent -- it looks like a boolean check but is actually sequencing a side effect.

**Fix:**
```elixir
record ->
  repo.delete!(record)
  :ok
```

## Info

### IN-01: Scope template has two functions with identical behavior

**File:** `priv/templates/sigra.install/core/scope.ex:38-51`
**Issue:** `for_user/1` and `new/1` have identical implementations (both construct `%__MODULE__{user: user}` and handle `nil`). The `@doc` for `new/1` says "Used by Sigra plugs" which suggests it exists as an internal API entry point, but having two identical public functions may confuse developers customizing their generated code. Consider whether `new/1` can delegate to `for_user/1` or if a `@doc false` annotation would clarify intent.

**Fix:** Add `@doc false` to `new/1` if it is only meant for internal Sigra plug use, or have `new/1` delegate: `def new(user), do: for_user(user)`.

### IN-02: Migration template does not add an index on `active_organization_id`

**File:** `priv/templates/sigra.install/core/add_active_organization_id_to_user_sessions.exs:1-9`
**Issue:** The ALTER migration adds the `active_organization_id` column but no index. If Phase 14 or later queries sessions by `active_organization_id` (e.g., "find all sessions scoped to org X"), a sequential scan would be required. This is not a bug today since no code queries by this column yet, but is worth noting for when the org-switching plugs land.

**Fix:** No action needed now. When Phase 14 adds queries filtering by `active_organization_id`, add a corresponding index migration.

---

_Reviewed: 2026-04-11T18:45:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
