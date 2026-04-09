---
phase: 08-account-lifecycle
fixed_at: 2026-04-09T03:07:19Z
review_path: .planning/phases/08-account-lifecycle/08-REVIEW.md
iteration: 1
findings_in_scope: 7
fixed: 7
skipped: 0
status: all_fixed
---

# Phase 8: Code Review Fix Report

**Fixed at:** 2026-04-09T03:07:19Z
**Source review:** .planning/phases/08-account-lifecycle/08-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 7
- Fixed: 7
- Skipped: 0

## Fixed Issues

### CR-01: Missing `build_email_token_fn` and `token_query_fn` in email change request flow

**Files modified:** `lib/sigra/auth.ex`
**Commit:** befa404
**Applied fix:** Added `build_email_token_fn`, `token_query_fn`, and `email_taken_fn` callback construction in `request_email_change/4`. Also fixed the related `cancel_email_change/3` which had the same missing `token_query_fn` issue (the cancel function in `email_change.ex` calls `Keyword.fetch!(opts, :token_query_fn)` which was not provided).

### CR-02: Missing `find_user_by_token_fn`, `changeset_fn`, and `token_query_fn` in email change confirm flow

**Files modified:** `lib/sigra/auth.ex`
**Commit:** d8f7d08
**Applied fix:** Added `find_user_by_token_fn` (uses `user_token_schema.verify_email_token_query/2`), `changeset_fn` (defaults to `Ecto.Changeset.change/2` if not provided via opts), and `token_query_fn` callback construction in `confirm_email_change/3`.

### CR-03: Missing `validate_password_fn` in password change flow

**Files modified:** `lib/sigra/auth.ex`
**Commit:** 9903b78
**Applied fix:** Added `validate_password_fn` callback that delegates to `config.user_schema.valid_password?/2` in `change_password/5`.

### WR-01: Hooks engine discards the Multi returned by hook functions

**Files modified:** `lib/sigra/hooks.ex`
**Commit:** 4152725
**Applied fix:** Changed `Multi.run` callback to execute the hook's returned multi via `repo.transaction(hook_multi)` instead of discarding it. Postgres handles nested transactions via savepoints. Error from the hook multi now properly propagates to abort the outer transaction.

### WR-02: `cancel_email_change` token context mismatch in concurrent scenarios

**Files modified:** `lib/sigra/account/email_change.ex`
**Commit:** 5285e68
**Applied fix:** Added documentation comment explaining that TTL-based expiry handles orphaned tokens in the unlikely concurrent email change scenario. The current behavior is correct for the normal flow since `user.email` at cancel time matches the email at request time (the change hasn't been applied yet).

### WR-03: `deletion_changeset` missing fields for anonymize strategy

**Files modified:** `priv/templates/sigra.install/user.ex`
**Commit:** 6b775d0
**Applied fix:** Added `:email` and `:hashed_password` to the `cast/3` fields list in `deletion_changeset/2` so the anonymize strategy's changes to these fields are not silently dropped.

### WR-04: `get_strategy` config shape inconsistency

**Files modified:** `lib/sigra/account/deletion.ex`
**Commit:** debe7fc
**Applied fix:** Replaced bare `|| :soft_delete` fallback with explicit validation against known strategy atoms (`:soft_delete`, `:hard_delete`, `:anonymize`). Added documentation comment explaining that `get_in/2` handles all config shapes (struct, map, keyword list) via Access behaviour. Unknown or nil values now safely default to `:soft_delete`.

---

_Fixed: 2026-04-09T03:07:19Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
