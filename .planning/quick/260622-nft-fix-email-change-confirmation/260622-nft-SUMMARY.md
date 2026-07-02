---
quick_id: 260622-nft
status: complete
date: 2026-06-22
---

# Fix: email-change confirmation always failed ("invalid or has expired")

## Bug (reproducible, shipped, affects every host app)
Changing email at `/users/settings` then clicking the confirmation link always showed
"This confirmation link is invalid or has expired." Confirmation could never succeed.
Only mock-based unit tests existed, so the real verify path was never exercised.

## Root cause — THREE chained defects (the plan found only the first; debugging found all)
1. **Verify-query mismatch** (planned). `auth.ex confirm_email_change` looks up the user
   via `verify_email_token_query(token, "change:")`, but the generated query matched the
   context EXACTLY (`context == "change:"`, never `"change:<old-email>"`) and required
   `sent_to == user.email` (change tokens set `sent_to = NEW` while `email` is still OLD).
2. **Double-encoded hashed tokens** (root cause). `Sigra.Token.generate_hashed_token/0`
   already returns a base64 STRING + the SHA-256 of the underlying bytes, but the generated
   `build_hashed_token/3` re-encoded that string — so the link carried a double-encoded
   token while `verify_*` decodes once → the hash could NEVER match. (Verified by byte
   sizes: 58 → decode → 43 → decode → 32; `sha256(decode_twice) == stored`.) This broke
   **every** `build_hashed_token` token — email-change AND magic-link.
3. **Session invalidation crash**. `EmailChange.do_confirm` invalidates sessions (D-07)
   but called `delete_all_for_user/2` with only `except_token`; the Ecto store requires
   `:repo` + `:session_schema` (`Keyword.fetch!` → raise).

## Fix (3 commits)
- **`10441805`** — dedicated `verify_email_token_query(token, "change:" <> _)` head:
  prefix-match context (`like "change:%"`) + `sent_to == user.pending_email`. Generic head
  (confirm/reset, `sent_to == user.email`) untouched; `auth.ex` call-site unchanged
  (upgrade-safe). Template + example + golden fixture (byte-mirrored).
- **`c2ab16f1`** — (2) `build_hashed_token/3` uses the encoded string as-is (template +
  example + golden); (3) `confirm_email_change` threads `session_store_opts` via
  `session_store_and_opts/2` and `email_change.ex maybe_invalidate_sessions` forwards them
  (lib-only).
- **`0fb59516`** — tests.

## Verification
- New tests (both fail pre-fix, pass post-fix):
  - `test/example/test/example/accounts/email_change_test.exs` — real Repo round-trip:
    request → confirm switches email + clears `pending_email`; single-use; rejects
    malformed / expired / wrong-context (magic-link) tokens.
  - `test/example/test/example_web/live/settings_live_test.exs` — E2E over
    `/users/settings/confirm-email/:token`: valid token applies + persists; invalid token
    → "invalid or has expired" flash, email unchanged.
- **Full example suite: 223 tests, 0 failures** (216 + 7) — no regression from the
  `build_hashed_token` / `auth.ex` / `email_change.ex` changes (magic-link included).
- Library `email_change_test` + `vault_promotion_test`: pass. `golden_diff_test` fails
  ONLY on the pre-existing phx_new 1.8.8-vs-1.8.7 `config/config.exs` `root_tag_attribute`
  drift — my `user_token.ex` template change matched the golden fixture byte-for-byte.

## Scope notes
- `user_token.ex` changes touch the installer template (+ golden mirror) — correct
  location, the bug lives in generated code. Existing host apps must regenerate
  `user_token.ex` to get the fix (CHANGELOG/upgrade note recommended).
- `auth.ex` + `account/email_change.ex` are library-only (no golden impact).
- **Deferred (filed todo `session-invalidation-missing-store-opts`):** the IDENTICAL
  session-opts bug exists in `password_change.ex` + `deletion.ex` (same `delete_all_for_user`
  pattern). Out of scope for the reported email-change bug; each needs its own coverage.
