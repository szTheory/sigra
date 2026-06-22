---
quick_id: 260622-nft
title: "Fix email-change confirmation always failing (invalid/expired)"
date: 2026-06-22
status: in-progress
---

# Quick Task 260622-nft — Fix email-change confirmation

## Bug
Changing email at `/users/settings` → clicking the confirm link always shows
"This confirmation link is invalid or has expired." Confirmation can NEVER succeed.
Shipped bug in the generated token-schema query → affects **every** `mix sigra.install`
host app. Only mock-based unit tests existed, so it was never caught.

Root cause (`priv/templates/sigra.install/core/user_token.ex` `verify_email_token_query/2`,
called by `lib/sigra/auth.ex:2305` with `"change:"`):
1. `by_token_and_context_query` does EXACT `context == "change:"` — never matches the stored
   `"change:<old-email>"`.
2. `where: token.sent_to == user.email` — for change tokens `sent_to` is the NEW email while
   `user.email` is still OLD at confirm time → always false.

Full approved plan: `/Users/jon/.claude/plans/i-got-an-error-eager-hamming.md`.

## Tasks (atomic commits)

### Task 1 — Fix + mirrors (one commit)
Add a dedicated change-context head ABOVE the existing `verify_email_token_query/2`:
```elixir
def verify_email_token_query(token, "change:" <> _) do
  case Base.url_decode64(token, padding: false) do
    {:ok, decoded_token} ->
      hashed_token = Sigra.Token.hash_token(decoded_token)
      query =
        from token in __MODULE__,
          join: user in assoc(token, :user),
          where: token.token == ^hashed_token,
          where: like(token.context, "change:%"),
          where: token.inserted_at > ago(@change_email_validity_in_days, "day"),
          where: token.sent_to == user.pending_email,
          select: user
      {:ok, query}
    :error -> :error
  end
end
```
- files: `priv/templates/sigra.install/core/user_token.ex` (template),
  `test/fixtures/install_golden/tree/.../user_token.ex` (mirror byte-for-byte),
  `test/example/lib/example/accounts/user_token.ex` (mirror).
- `lib/sigra/auth.ex` UNCHANGED (call-site stays `verify_email_token_query(token, "change:")`,
  matched by the new head — upgrade-safe, no crash on `deps.update`).
- verify: example + golden compile; golden_diff stays green (only the new head added).
- done: change tokens verify by prefix + `sent_to == pending_email`.

### Task 2 — Regression coverage (one commit)
- `test/example/test/example/accounts/email_change_test.exs` (NEW): real Repo round-trip —
  request → `{:ok,_,token}` → confirm → assert email switched + pending nil; single-use
  (2nd confirm → :error); negatives (garbage, expired, a `confirm`/`reset_password` token
  must NOT confirm via this path).
- `test/example/test/example_web/live/settings_live_test.exs` (NEW): drive
  `~p"/users/settings/confirm-email/#{token}"` → flash "Your email has been updated." +
  DB change; bad token → "invalid or has expired" + no change.
- verify: `cd test/example && mix test` green; the round-trip test fails pre-fix, passes post-fix.

## Verification
- `cd test/example && mix test` (full suite + 2 new files) → 0 failures.
- `mix test test/sigra/install/golden_diff_test.exs` + vault_promotion green (fixture mirrored).
- Manual: change email in demo → click link → "Your email has been updated."

## Scope
- Installer template + golden mirror + example + 2 tests. `lib/sigra/auth.ex` unchanged.
- Follow-up (note, not this task): CHANGELOG/upgrade note that existing hosts must regenerate
  their `user_token.ex` to get the fix.
