---
phase: "214"
plan: "02"
subsystem: auth-security, admin-liveview
status: complete
tags: [security, session, idor, refactor, admin]
dependency_graph:
  requires: []
  provides: [session-ownership-guard, session-helper-promotion]
  affects:
    - lib/sigra/auth.ex
    - lib/sigra/admin/components.ex
    - lib/sigra/admin/live/user_sessions_live.ex
    - lib/sigra/admin/live/user_show_live.ex
    - lib/sigra/admin/live/users_index_live.ex
    - test/sigra/auth_test.exs
tech_stack:
  added: []
  patterns:
    - session-ownership-guard-in-library-layer
    - promoted-shared-helpers-via-import
key_files:
  created: []
  modified:
    - lib/sigra/auth.ex
    - lib/sigra/admin/components.ex
    - lib/sigra/admin/live/user_sessions_live.ex
    - lib/sigra/admin/live/user_show_live.ex
    - lib/sigra/admin/live/users_index_live.ex
    - test/sigra/auth_test.exs
    - .planning/todos/pending/2026-06-25-phase200-code-review-deferred.md
decisions:
  - Guard in delete_session/3 not SessionStores.Ecto.delete/2 — keeps @callback delete/2 signature unchanged, protects all callers
  - scope_copy/1 not promoted to Components — context-specific copy text ("Global audit explorer" vs "Global user operations") conflicts with existing defp copies in audit_index_live.ex, audit_user_live.ex, branding_live.ex; users_index_live.ex all import Components
  - pluralize/2 removed from users_index_live.ex as well (same conflict pattern discovered during promotion)
  - Silent no-op on user_id mismatch — not logged, identical :ok return to "already gone" (defense in depth, T-214-02-02)
  - Remove both assign(:return_to, nil) in mount AND assign(:return_to, return_to) in handle_params — return_to stays a pure local variable
metrics:
  duration: "~20 minutes"
  completed: "2026-07-02"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 7
---

# Phase 214 Plan 02: Session Ownership Guard + Helper Promotion Summary

Hardened `Sigra.Auth.delete_session/3` against horizontal privilege/IDOR on session tokens by inserting a user_id ownership guard at the library API layer, and promoted four shared session render helpers from both LiveViews into `Sigra.Admin.Components` while removing the unused `@return_to` socket assign.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add user_id guard to delete_session/3; deny-path test | 2ba35c15 | lib/sigra/auth.ex, test/sigra/auth_test.exs |
| 2 | Promote helpers to Components; drop @return_to | 463504e5 | lib/sigra/admin/components.ex, user_sessions_live.ex, user_show_live.ex, users_index_live.ex |

## What Was Built

### Task 1 — D-08/D-09: user_id Ownership Guard in delete_session/3

Inserted a `user_id_constraint` check inside the `Telemetry.span` callback in `Sigra.Auth.delete_session/3`:

- `opts[:user_id]` absent (nil) → proceeds unchanged (self-logout backward compat)
- `opts[:user_id]` present and matches `session.user_id` → deletes as before
- `opts[:user_id]` present but mismatches → silent no-op, returns `:ok`, session row survives (foreign-token IDOR protection)
- `opts[:user_id]` present but session not found → silent no-op, returns `:ok` (already gone)

The guard uses `session_store.fetch/2` (existing `@callback fetch/2`) to read the session's owner before deciding whether to call `session_store.delete/2`. No change to `@callback delete/2` signature. The admin path (`Actions.revoke_session/4` → `Sigra.Auth.revoke_session/3` → `delete_session/3`) already passes `user_id: user.id` from a scope-checked load, so the guard fires there automatically.

Added three regression tests to `test/sigra/auth_test.exs`:
- Deny-path: foreign user_id → :ok, session survives (MockSessionStore.fetch called, delete NOT called)
- Allow-path: matching user_id → delete called normally
- Not-found-path: session already gone → :ok, no crash

All 70 auth tests pass.

### Task 2 — D-10/D-11: Helper Promotion + @return_to Cleanup

Promoted four session render helpers from private copies in `user_sessions_live.ex` and `user_show_live.ex` into public `def` functions in `Sigra.Admin.Components`:

- `session_type/1` — converts session type to string
- `activity_value/1` — formats DateTime as "YYYY-MM-DD HH:MM" or "Not available"
- `relative_activity/1` — coarse recency string ("just now", "Xm ago", etc.) or nil
- `pluralize/2` — "1 label" / "N labels"

Both LiveViews already `import Sigra.Admin.Components` at line 6 — no import change needed. Private copies of these four removed from both LiveViews.

Removed `assign(:return_to, nil)` from `user_sessions_live.ex` mount/3 and `assign(:return_to, return_to)` from `handle_params/3`. The `return_to` value is now purely a local variable used only to compute `@admin_breadcrumbs` before being discarded.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] scope_copy/1 not promoted to Sigra.Admin.Components**

- **Found during:** Task 2, first compile after promoting all five helpers
- **Issue:** The plan specified promoting `scope_copy/1`, but `audit_index_live.ex`, `audit_user_live.ex`, `branding_live.ex`, and `users_index_live.ex` all `import Sigra.Admin.Components` AND have their own `defp scope_copy/1` with different context-specific copy text ("Global audit explorer", "Global auth/email profile"). Elixir raises a compile error: "imported Sigra.Admin.Components.scope_copy/1 conflicts with local function".
- **Fix:** Retained `defp scope_copy/1` in `user_sessions_live.ex` and `user_show_live.ex`. Not promoted to Components. The session-render-specific copy text ("Organization-scoped user operations for {name}" / "Global user operations") is not generic enough to be a shared default. Documented in component module comment.
- **Files modified:** lib/sigra/admin/components.ex (no scope_copy)
- **Commit:** 463504e5

**2. [Rule 2 — Missing critical fix] users_index_live.ex pluralize/2 also removed**

- **Found during:** Task 2, second compile after scope_copy fix
- **Issue:** `users_index_live.ex` also has `defp pluralize(1, singular)` / `defp pluralize(count, singular)` at lines 646-647 and also `import Sigra.Admin.Components` — same import-conflict pattern.
- **Fix:** Removed the two private `defp pluralize` clauses from `users_index_live.ex`. The promoted version in Components is functionally identical (different parameter name `label` vs `singular` is cosmetic only).
- **Files modified:** lib/sigra/admin/live/users_index_live.ex
- **Commit:** 463504e5

## Verification

```
mix compile --warnings-as-errors  → clean (Generated sigra app)
mix test test/sigra/auth_test.exs → 70 tests, 0 failures
defp session_type/activity_value/relative_activity/pluralize → zero in both LiveViews
def session_type/activity_value/relative_activity/pluralize → all in components.ex
assign(:return_to, ...) → zero matches in user_sessions_live.ex
```

## Threat Surface Scan

| Flag | File | Description |
|------|------|-------------|
| mitigation_applied: T-214-02-01 | lib/sigra/auth.ex | user_id ownership guard closes horizontal privilege / IDOR on session tokens for all delete_session/3 callers |

## Self-Check: PASSED

- [x] lib/sigra/auth.ex modified with guard — file exists and confirmed
- [x] test/sigra/auth_test.exs contains deny-path test — 70 tests, 0 failures
- [x] lib/sigra/admin/components.ex has session_type/activity_value/relative_activity/pluralize
- [x] user_sessions_live.ex and user_show_live.ex have zero defp copies of those four helpers
- [x] Commits 2ba35c15 and 463504e5 confirmed in git log
