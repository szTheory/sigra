---
created: 2026-06-25T00:00:00.000Z
status: pending
title: harden token-scoped session revocation + de-dupe admin session helpers (Phase 200 deferred review findings)
area: admin-ui
files:
  - lib/sigra/auth.ex
  - lib/sigra/session_stores/ecto.ex
  - lib/sigra/admin/users/actions.ex
  - lib/sigra/admin/live/user_sessions_live.ex
  - lib/sigra/admin/live/user_show_live.ex
  - lib/sigra/admin/components.ex
source: 200-REVIEW.md (WR-01, IN-01, IN-02)
---

## Why deferred

Phase 200's code review (`.planning/phases/200-user-detail-elevation/200-REVIEW.md`)
surfaced one warning and two info findings that were intentionally NOT fixed inline
during execution. CR-01/CR-02/CR-03/WR-02/WR-03 were fixed in-phase (commits
`146708e6`, `19a7d0f6`, `2b38afa7`, `f9f77913`, `0b914f89`). These three remain:

### WR-01 — Session deletion not bound to authorized `user_id` (defense-in-depth)
`Sigra.Auth.delete_session/3` → `Sigra.SessionStores.Ecto` deletes purely by
`hashed_token`; `user_id` is audit-only, never a deletion constraint. A scoped admin
who already knows a *foreign* session's `hashed_token` could revoke it. Exploitability
is limited (the page only surfaces in-scope hashed tokens), hence WARNING not BLOCKER.
**Pre-existing** pattern carried over from the old `UserShowLive`, but Phase 200
re-homed and re-blessed it on the new `/admin/users/:id/sessions` route.

**Why deferred:** touches the security-critical session-store / `Sigra.Auth` public API
(library code shipped to host apps via `mix deps.update`) — needs its own design pass
re: backward-compat of `delete_session/3`'s signature and the session store
`delete/2` behaviour. Not a guess-fix candidate mid-execution.

**Suggested fix:** constrain the delete to the authorized user — add `where: s.user_id == ^user_id`
to the store delete (token mismatch becomes a no-op), or verify in
`Actions.revoke_session/4` that `hashed_token ∈ Sigra.Auth.list_sessions(config, user.id)`
before calling revoke. Add a deny-path test (admin cannot revoke a foreign token).

### IN-02 — Duplicated session-rendering helpers across the two LiveViews
`session_type/1`, `activity_value/1`, `relative_activity/1`, `pluralize/2`,
`scope_copy/1`, and the session-table markup are duplicated verbatim in both
`UserSessionsLive` and `UserShowLive` (the detail page still renders a 3-row preview).
Silent drift risk. Promote into `Sigra.Admin.Components` (or a shared module) and call
from both — keeps the preview and full page coherent. (Relates to the admin
"same job → same component" coherence milestone.)

### IN-01 — Unused `@return_to` socket assign in `UserSessionsLive`
`:return_to` is assigned to the socket (`user_sessions_live.ex:19,34`) but never read in
`render/1`; the breadcrumb already takes `return_to` as a local. Either drop the socket
assign or wire the intended back/cancel link that uses it. Trivial cleanup.

## How to apply

Pick up in a future admin-UI hardening / coherence pass. WR-01 should be scoped as its
own small security task (with a deny-path regression test) given it touches shipped lib
API; IN-01/IN-02 can ride along as cleanup. See `[[project_sigra_admin_coherence_milestone]]`.
