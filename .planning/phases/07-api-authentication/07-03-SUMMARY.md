---
phase: 07-api-authentication
plan: 03
subsystem: api-auth-integration
tags: [fetch-bearer, auth-delegation, token-cleanup, testing-helpers, email-notification]
dependency_graph:
  requires: [07-01, 07-02]
  provides: [fetch-bearer-auto-detect, auth-api-token-crud, auth-jwt-delegation, token-cleanup-api, testing-api-helpers]
  affects: [lib/sigra/plug/fetch_bearer.ex, lib/sigra/auth.ex, lib/sigra/workers/token_cleanup.ex, lib/sigra/testing.ex, lib/sigra/email_templates.ex]
tech_stack:
  added: []
  patterns: [auto-detection-by-format, delegation-pattern, testing-fixtures]
key_files:
  created: []
  modified:
    - lib/sigra/plug/fetch_bearer.ex
    - lib/sigra/auth.ex
    - lib/sigra/workers/token_cleanup.ex
    - lib/sigra/testing.ex
    - lib/sigra/email_templates.ex
    - test/sigra/plug/fetch_bearer_test.exs
    - test/sigra/workers/token_cleanup_test.exs
    - test/sigra/testing_test.exs
decisions:
  - "FetchBearer prefix check runs before eyJ check (D-38) to prevent opaque tokens from being routed to JWT verifier"
  - "Auth.create_api_token wraps email delivery in try/rescue for UndefinedFunctionError graceful degradation"
  - "api_refresh context added to TokenCleanup with 30-day TTL matching JWT refresh token default"
metrics:
  duration: "6m 33s"
  completed: "2026-04-08T23:59:47Z"
  tasks_completed: 2
  tasks_total: 2
  tests_added: 38
  tests_total: 924
---

# Phase 7 Plan 3: HTTP Pipeline Integration Summary

FetchBearer rewritten for auto-detection of opaque vs JWT tokens, Auth module extended with API token CRUD and JWT delegation, TokenCleanup extended for revoked API tokens and refresh tokens, testing helpers added for both token types, email notification wired for token creation.

## What Was Done

### Task 1: Rewrite FetchBearer with auto-detection and scope assignment
- **Rewrote** `lib/sigra/plug/fetch_bearer.ex` from simple `token_verifier` delegation to config-based auto-detection
- Auto-detects token type: prefix match (opaque) -> eyJ check (JWT) -> fallback (opaque)
- Assigns `current_scope` with `auth_method`, `token_scopes`, and `token_id`
- Skips processing when `current_scope` already assigned (D-53)
- Accepts `:config` (Sigra.Config) and `:scope_module` options
- **Commit:** `425527a`

### Task 2: Auth delegation, TokenCleanup, Testing helpers, Email notification
- **Extended** `lib/sigra/auth.ex` with 8 new public functions:
  - `create_api_token/3` with email notification on success (D-62)
  - `revoke_api_token/2`, `revoke_all_api_tokens/2`, `list_api_tokens/3`, `list_api_scopes/1`
  - `generate_jwt_tokens/3`, `refresh_jwt/2`, `revoke_jwt_refresh/2`
- **Extended** `lib/sigra/workers/token_cleanup.ex`:
  - Added `cleanup_revoked_api_tokens/1` for revoked/expired API tokens past retention
  - Added `cleanup_refresh_tokens/2` for superseded JWT refresh tokens
  - Added `"api_refresh"` to `@contexts_and_ttls` with 30-day TTL
- **Extended** `lib/sigra/testing.ex` with 11 new helpers:
  - API token: `create_api_token/3`, `put_bearer_token/2`, `put_api_token/2`, `assert_token_revoked/2`, `assert_scope_denied/1`, `expired_api_token_fixture/3`, `revoked_api_token_fixture/3`, `scoped_api_token_fixture/4`
  - JWT: `generate_jwt/3`, `expired_jwt/3`, `jwt_with_scopes/3`
- **Extended** `lib/sigra/email_templates.ex` with `api_token_created_email/2` callback
- **Commit:** `611e5f6`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Auth email delivery graceful degradation**
- **Found during:** Task 2
- **Issue:** If the email module doesn't implement `api_token_created_email/2` (optional callback added in this plan), calling it would crash `create_api_token`
- **Fix:** Wrapped email delivery in `try/rescue UndefinedFunctionError` to degrade gracefully
- **Files modified:** `lib/sigra/auth.ex`

## Verification

- `mix test test/sigra/plug/fetch_bearer_test.exs test/sigra/workers/token_cleanup_test.exs test/sigra/testing_test.exs --seed 0` -- 50 tests, 0 failures
- `mix test --seed 0` -- 924 tests, 0 failures (full suite, no regressions)

## Self-Check: PASSED

- All 8 modified files exist on disk
- Commit 425527a found (Task 1)
- Commit 611e5f6 found (Task 2)
- 924 tests pass, 0 failures
