---
phase: 07-api-authentication
plan: 01
subsystem: api-token-core
tags: [api-tokens, scopes, plugs, ecto-types, config]
dependency_graph:
  requires: [sigra-token, sigra-config, sigra-telemetry, sigra-error]
  provides: [api-token-crud, scope-registry, require-scopes-plug, string-list-type]
  affects: [config, error, telemetry, error-handler]
tech_stack:
  added: []
  patterns: [cursor-pagination, prefix-tokens, scope-registry, sha256-hash-storage]
key_files:
  created:
    - lib/sigra/api_token.ex
    - lib/sigra/api_token/scope_registry.ex
    - lib/sigra/ecto/types/string_list.ex
    - lib/sigra/plug/require_scopes.ex
    - test/sigra/api_token_test.exs
    - test/sigra/api_token/scope_registry_test.exs
    - test/sigra/ecto/types/string_list_test.exs
    - test/sigra/plug/require_scopes_test.exs
  modified:
    - lib/sigra/config.ex
    - lib/sigra/error.ex
    - lib/sigra/telemetry.ex
    - lib/sigra/plug/error_handler.ex
decisions:
  - "Prefix derived from otp_app when not explicitly set: {otp_app}_sk_"
  - "Token hash is SHA-256 of full raw_key including prefix, not just random part"
  - "Cursor pagination uses Base64-encoded inserted_at|id for opacity"
  - "ScopeRegistry validates format via regex before checking registry membership"
metrics:
  duration: ~10 min
  completed: 2026-04-08
  tasks_completed: 2
  tasks_total: 2
  test_count: 132
  files_created: 8
  files_modified: 4
---

# Phase 7 Plan 1: API Token Core Infrastructure Summary

API token CRUD, scope registry, RequireScopes plug, StringList Ecto type, config extensions, error types, and telemetry events -- all library-side building blocks for opaque API token authentication.

## Task Results

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Config, StringList, ScopeRegistry, Errors, Telemetry | `2778e56` (RED), `e1e0e39` (GREEN) | config.ex, string_list.ex, scope_registry.ex, error.ex, telemetry.ex |
| 2 | APIToken module and RequireScopes plug | `e03815a` (RED), `953adbe` (GREEN) | api_token.ex, require_scopes.ex |

## What Was Built

### Config Extensions
- Added `api_token:` section with 10 options: prefix, custom_scopes, write_implies_read, require_expiry, max_ttl, cleanup_retention, activity_update_threshold, default/max_page_size, api_token_schema
- Added `jwt:` section with 9 options: enabled, algorithm, issuer, access/refresh_ttl, refresh, claims_builder, verify_epoch, private_key
- Both sections validated via NimbleOptions with secure defaults

### StringList Ecto Type
- Custom type for MySQL/SQLite databases lacking native array columns
- Round-trips lists through comma-separated strings
- Handles nil as empty list on load

### ScopeRegistry
- 8 built-in scopes: profile, sessions, api_tokens, mfa (read/write each)
- Custom scope registration via config
- Format validation: `resource:action` regex + wildcard `*` special case
- Validates format first, then registry membership

### APIToken Module
- `create/3`: Prefix + random token generation, SHA-256 hash storage, scope/expiry validation
- `verify/2`: Hash lookup, revoked/expired rejection, throttled last_used_at updates via Task
- `revoke/2`: Soft-delete individual token
- `revoke_all/2`: Bulk revoke via update_all query
- `list_active/3`: Cursor-based pagination with configurable page sizes
- `can?/2`: AND/OR scope checking with wildcard support
- `list_scopes/1`: Delegates to ScopeRegistry
- Prefix validated to prevent JWT collision (eyJ prefix blocked)

### RequireScopes Plug
- Route-level scope enforcement
- Session-authenticated users bypass scope checks (D-21)
- AND mode (default) and OR mode (`:match` option)
- Wildcard `*` scope passes all checks
- Passes required_scopes and provided_scopes to error handler
- Halts conn and delegates to error handler on failure

### Error Types
- `TokenRevoked`: revoked API token or JWT refresh token
- `InsufficientScope`: valid token lacks required scopes
- `MFARequired`: JWT login requires MFA verification
- Safe messages for all three error codes
- ErrorHandler type extended with new error atoms

### Telemetry Events
- 4 API token events: create, verify, revoke, revoke_all
- 4 JWT events: generate, verify, refresh, refresh_reuse_detected
- JWT refresh reuse detection added to security events
- Public `api_token_events/0` and `jwt_events/0` accessor functions

## Deviations from Plan

None -- plan executed exactly as written.

## Verification

- 132 plan-related tests pass (32 StringList/ScopeRegistry + 66 config/error + 34 APIToken/RequireScopes)
- 873 total tests pass (full suite, zero failures)
- `mix compile --warnings-as-errors` passes clean

## Known Stubs

None -- all modules are fully implemented with real logic.

## Self-Check: PASSED

All 8 created files verified present. All 4 commits verified in git log.
