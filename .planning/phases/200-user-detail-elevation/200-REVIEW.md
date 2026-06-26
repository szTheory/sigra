---
phase: 200-user-detail-elevation
reviewed: 2026-06-25T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - lib/sigra/admin/live/user_sessions_live.ex
  - lib/sigra/admin/live/user_show_live.ex
  - priv/templates/sigra.install/admin/router_injection.ex
  - test/example/lib/example_web/router.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex
  - test/sigra/admin/glossary_test.exs
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts
findings:
  critical: 3
  warning: 3
  info: 2
  total: 8
status: issues_found
---

# Phase 200: Code Review Report

**Reviewed:** 2026-06-25
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Phase 200 extracted the per-user session revoke flow out of `UserShowLive` into a
new lib-owned `Sigra.Admin.Live.UserSessionsLive` mounted at
`/admin/users/:id/sessions` (and the org-scoped equivalent), recomposed
`UserShowLive` into a calmer read-only identity surface with a "Manage sessions"
link-out, wired the new route across the three router files in lockstep, and added
a Playwright checkpoint for the new page.

The **authorization design is sound**: the new route sits inside the same
`live_session` with the `Sigra.LiveView.AdminScope` `on_mount` guard, and both
`Detail.load!/3` and `Actions.revoke_session/4` re-derive the user under the
admin scope (`Authorizer.authorize_organization!` / membership subquery), so an
org-scoped admin cannot load or act on a user outside their org. The **router
lockstep is clean** — identical insertions in both the global and org scopes of
all three router files.

However, the phase **changed `UserShowLive`'s rendered DOM and removed its event
handlers without updating the existing host-app test suite or the @smoke
Playwright operations spec that exercise the old behavior**. Three test artifacts
in `test/example/` still assert against strings and events that no longer exist,
which will break CI. These are the BLOCKERs below. A pre-existing
defense-in-depth gap in token-scoped revocation was carried over and is noted as a
warning.

## Critical Issues

### CR-01: ExUnit `admin_user_show_live_test.exs` still drives removed revoke handlers and renamed DOM

**File:** `test/example/test/example_web/live/admin_user_show_live_test.exs:33,39,60-99,153,160`
**Issue:** The phase removed the `open_revoke_session`, `open_revoke_all_sessions`,
`cancel_confirm`, and `confirm_action` `handle_event/3` clauses from
`UserShowLive` (now only in `UserSessionsLive`) and changed the rendered copy, but
this test file was **not touched in the phase** (`git diff` confirms zero changes).
It will now fail in several places:

- Lines 33/39: asserts the detail page renders `"Identity &amp; Status"` (kicker)
  and `"Danger Zone"` in order. The new render uses kicker `"User"`
  (`user_show_live.ex:47`) and heading `"Danger zone"` (lowercase z,
  `user_show_live.ex:213`). `html_offset/2` returns `nil` for the missing strings,
  so `assert Enum.all?(positions, fn {_label, position} -> is_integer(position) end)`
  (line 43) fails.
- Lines 78/90: `render_click(view, :open_revoke_session, ...)` and
  `:open_revoke_all_sessions` against `UserShowLive` will raise — those handlers no
  longer exist on this LiveView.
- Lines 153/160: `assert html =~ "Danger Zone"` fails (now `"Danger zone"`); line
  160 then compares `html_offset(..., "Danger Zone")` (which is `nil`) with `>`,
  raising `ArgumentError`.

This is a host-app test that runs in CI (per CLAUDE.md, every test runs in CI).
**Fix:** Update `admin_user_show_live_test.exs` to match the new `UserShowLive`
contract (kicker `"User"`, heading `"Danger zone"`, no revoke buttons / "Manage
sessions" link instead) and move the revoke-confirmation assertions to a new
`UserSessionsLive` test. Recommended: add `test/example/.../admin_user_sessions_live_test.exs`
covering the moved revoke flow (open dialog, confirm, scope-safety, org-scope
authorization), since the new LiveView currently has **no ExUnit coverage at all**.

### CR-02: @smoke Playwright `admin-user-operations.spec.ts` revokes sessions on the detail page that no longer has revoke controls

**File:** `test/example/priv/playwright/tests/admin-user-operations.spec.ts:72-140`
**Issue:** The `@smoke search -> filter -> open user -> revoke session keeps scope
visible` test stays on `/admin/users/:id` (line 104) and expects per-row
`Revoke session` buttons plus the old confirm copy
`"Revoke this session for ${targetEmail}? This signs them out of that browser or device."`
(line 119). After this phase the detail page's session table has no Action column
and no revoke buttons (`user_show_live.ex:91-113` — Type/IP/Last activity only),
and that confirm copy no longer exists anywhere (the new `UserSessionsLive` copy is
`"The user will be signed out of this session immediately..."`).

Concretely: `revokeSession.count()` is `0`, so the `while` loop (line 128) never
runs and no session is revoked; then `await expect(page.getByText('No active
sessions')).toBeVisible()` (line 139) FAILS because the user still has active
sessions. This spec was not updated in the phase. Because it is tagged `@smoke`, it
gates merges.
**Fix:** Repoint this test at the new `/admin/users/:id/sessions` page (or assert
the detail page now shows a "Manage sessions" link and move the revoke journey to a
sessions-page test), and update the expected confirm copy to the new
`UserSessionsLive` strings.

### CR-03: New `UserSessionsLive` has no ExUnit / authorization regression test

**File:** `lib/sigra/admin/live/user_sessions_live.ex:1-324` (no corresponding test)
**Issue:** This phase moved a security-sensitive, destructive mutation (revoke
session / revoke all sessions for an arbitrary user) onto a brand-new route, yet
the only coverage is a single Playwright screenshot checkpoint
(`admin-checkpoints.spec.ts:234-248`) that merely asserts the "Revoke all sessions"
button is visible — it never confirms a revoke succeeds, never confirms an
org-scoped admin is forbidden from loading/revoking a user outside their org, and
never confirms scope is preserved. For an OWASP-first auth library, the
authorization boundary on a new destructive admin route must have explicit
deny-path coverage. The behavior is correct in the code (`Detail.load_user!` /
`Authorizer.authorize_organization!`), but it is untested, so a future refactor can
silently drop the check.
**Fix:** Add an ExUnit test (host-app `admin_user_sessions_live_test.exs` and/or a
lib-level test) that asserts: (a) revoke session + revoke all succeed and reload the
detail; (b) an org-scoped admin loading `/admin/organizations/:other/users/:id/sessions`
for a user outside their org gets `:not_found`/forbidden; (c) the scope ribbon /
breadcrumbs reflect the active scope.

## Warnings

### WR-01: Session deletion is not bound to the authorized `user_id` (defense-in-depth gap, carried over)

**File:** `lib/sigra/admin/live/user_sessions_live.ex:73-74` →
`lib/sigra/admin/users/actions.ex:11-20` → `lib/sigra/auth.ex:1496` (`delete_session/3`)
→ `lib/sigra/session_stores/ecto.ex:64-71`
**Issue:** `confirm_action` for `:revoke_session` passes the client-supplied
`hashed_token` (decoded from `phx-value-token`) into
`Actions.revoke_session(config, admin_scope, detail.user.id, token)`. `Actions`
authorizes that `detail.user.id` is in scope (good), and forwards `user_id` to
`Sigra.Auth.revoke_session`, but `delete_session/3` then deletes purely by
`get_by(schema, hashed_token: hashed_token)` — the `user_id` is used only for the
audit row, never as a deletion constraint. So the deletion is not actually bound to
the authorized user. A scoped admin who knows the `hashed_token` of a session
belonging to a different user/tenant could revoke it. Exploitability is limited
because the page only surfaces hashed_tokens for in-scope sessions, so the attacker
must already know a foreign token — hence WARNING, not BLOCKER. The pattern is
pre-existing (carried over verbatim from the old `UserShowLive`), but this phase
re-homes and re-blesses it on a new route, so it is in scope to harden.
**Fix:** Constrain the delete to the authorized user, e.g. add an `owner_user_id`
opt to `delete_session/`session store `delete/2` and `where: s.user_id == ^user_id`
so a token mismatch is a no-op rather than a cross-user revoke. Minimal change:
verify in `Actions.revoke_session` that `hashed_token` belongs to a session in
`Sigra.Auth.list_sessions(config, user.id)` before calling revoke.

### WR-02: `Base.url_decode64!/2` on client-controlled token can crash the LiveView

**File:** `lib/sigra/admin/live/user_sessions_live.ex:44`
**Issue:** `token: Base.url_decode64!(encoded_token, padding: false)` decodes the
client-supplied `phx-value-token` with the raising (`!`) variant inside the
`open_revoke_session` handler. A malformed value (anyone who can push events on this
authenticated admin socket) raises `ArgumentError` and crashes/reconnects the
LiveView process. Impact is bounded to an authenticated admin disrupting their own
session, but it is unhandled client input in a security-sensitive handler.
Pre-existing pattern, carried over.
**Fix:** Use `Base.url_decode64/2` and pattern-match:
```elixir
def handle_event("open_revoke_session", %{"token" => encoded_token}, socket) do
  case Base.url_decode64(encoded_token, padding: false) do
    {:ok, token} ->
      {:noreply, assign(socket, :confirm_action, %{type: :revoke_session, token: token, ...})}
    :error ->
      {:noreply, put_flash(socket, :error, "Invalid session reference.")}
  end
end
```

### WR-03: Org-scoped `return_to` sanitizer accepts cross-org paths

**File:** `lib/sigra/admin/live/user_sessions_live.ex:234-240`
**Issue:** `sanitize_return_to/3` accepts any path starting with `/admin/users` or
`/admin/organizations/` (line 235). For an org-scoped admin of org A, a crafted
`?return_to=/admin/organizations/org-B/users` passes the prefix check and is used as
the "Users" breadcrumb href, so a back-link can point at a different tenant's
scope. Compare `UserShowLive.sanitize_return_to/2` (`user_show_live.ex:239-247`),
which is stricter — it only accepts the exact users-index path for the active scope
via `users_index_path?/2`. The new sessions sanitizer is looser than the page it
links back to. This is a UX/scope-confusion issue rather than an access-control
bypass (the destination route still enforces its own admin scope), but it is
inconsistent with the established pattern and the phase's stated scope-safety goal.
**Fix:** Reuse the same scope-aware validation as `UserShowLive`
(`users_index_path?/2` for the active scope) instead of a broad `String.starts_with?`
prefix list, so an org-A admin cannot carry an org-B return_to.

## Info

### IN-01: `@return_to` assigned but unused in `UserSessionsLive` render

**File:** `lib/sigra/admin/live/user_sessions_live.ex:19,34`
**Issue:** `:return_to` is assigned to the socket and consumed by
`sessions_breadcrumbs/3`, but the value stored on the socket as `@return_to` is
never referenced in the `render/1` template (no back link or form uses it). The
breadcrumb already receives `return_to` as a local. The socket assign is harmless
but superfluous.
**Fix:** Either drop the `:return_to` socket assign (keep only the local passed to
`sessions_breadcrumbs`) or add the intended back/cancel link that uses it.

### IN-02: Duplicated session-rendering helpers across the two LiveViews

**File:** `lib/sigra/admin/live/user_sessions_live.ex:211-232` and
`lib/sigra/admin/live/user_show_live.ex:368-423`
**Issue:** `session_type/1`, `activity_value/1`, `relative_activity/1`,
`pluralize/2`, `scope_copy/1`, and the session-table markup are now duplicated
verbatim in both `UserSessionsLive` and `UserShowLive` (the detail page still
renders a 3-row session preview). Drift between the two copies (e.g. timestamp
format) would be silent. Not a bug, but the design system already centralizes
shared admin UI in `Sigra.Admin.Components`.
**Fix:** Promote the shared session-row formatting helpers and/or the session-table
markup into `Sigra.Admin.Components` (or a small shared module) and call from both
LiveViews to keep the preview and the full page coherent.

---

_Reviewed: 2026-06-25_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
