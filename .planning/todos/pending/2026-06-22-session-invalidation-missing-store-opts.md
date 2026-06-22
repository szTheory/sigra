---
id: session-invalidation-missing-store-opts
created: 2026-06-22
source: 260622-nft (email-change confirmation fix — discovered the same bug in sibling flows)
severity: bug
area: lib/sigra/account/password_change.ex, lib/sigra/account/deletion.ex (+ auth.ex wiring)
---

# Session invalidation crashes in password-change and account-deletion flows

While fixing email-change confirmation (260622-nft) I found the SAME shipped bug in
two sibling flows: they invalidate sessions via `session_store.delete_all_for_user/2`
but pass only `except_token` (or `[]`) — the Ecto store
(`Sigra.SessionStores.Ecto.delete_all_for_user/2`) requires `:repo` + `:session_schema`
and does `Keyword.fetch!(opts, :repo)`, so it **raises** when the real (default) store
is used.

Broken call sites (identical pattern, never integration-tested against the real store):
- `lib/sigra/account/password_change.ex:172` — `delete_all_for_user(user.id, except_token: except_token)`
- `lib/sigra/account/deletion.ex:397` — `delete_all_for_user(user.id, [])`

Their auth.ex wiring (`change_password` ~2369, deletion ~2425) passes
`session_store: get_session_store(config)` but never the store opts — same as
`confirm_email_change` did before the fix.

## Fix (mirror what 260622-nft did for email-change, commit c2ab16f1)
- In `auth.ex`, thread store opts via `session_store_and_opts(config, opts)` →
  pass `session_store:` + `session_store_opts:` into the account module opts (for the
  change_password and deletion paths).
- In `password_change.ex` `maybe_invalidate_sessions` and `deletion.ex`
  `revoke_sessions`, forward `Keyword.get(opts, :session_store_opts, [])` (+ except_token
  where applicable) to `delete_all_for_user`, exactly like
  `email_change.ex` `maybe_invalidate_sessions` now does.

## Coverage (the reason this is a separate task)
Each flow needs its own integration test against the REAL Ecto store asserting the
mutation succeeds AND other sessions are deleted (and the current one is preserved on
password change). Add to the example suite:
- password change ("sign out other sessions") → other UserSession rows gone, current kept.
- account deletion / reactivation → sessions revoked.

## Note
Email-change is already fixed + covered (260622-nft). These two are the remaining
instances of the same root cause; they were out of scope for the reported email-change
bug but should be fixed before relying on D-07 session invalidation in those flows.
