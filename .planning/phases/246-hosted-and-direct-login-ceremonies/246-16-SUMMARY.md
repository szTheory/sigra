---
phase: 246-hosted-and-direct-login-ceremonies
plan: 16
subsystem: auth
tags: [elixir, ecto, postgresql, hosted-login, app-sessions, concurrency]
requires:
  - phase: 246-15
    provides: atomic digest-only hosted approval consumption
provides:
  - Stable generated approval-digest unique constraint for prefixed and unprefixed app-session hosts
  - Deterministic PostgreSQL race proof for a single signed hosted continuation
affects: [hosted-login, app-sessions, generated-app-sessions]
tech_stack:
  added: []
  patterns: [named Ecto unique constraint, generated migration parsing, ready/go PostgreSQL barriers]
key_files:
  created: []
  modified:
    - priv/templates/sigra.install/app_sessions/app_sessions_migration.exs
    - test/sigra/install/app_sessions_generator_test.exs
    - test/sigra/app_login/concurrency_test.exs
decisions:
  - Generated approval-digest indexes use user_app_login_attempts_approval_digest_index so the library can normalize replay consistently across adapters and prefixes.
metrics:
  duration: 12m
  completed: 2026-08-13
status: complete
---

# Phase 246 Plan 16: Generated Approval Digest and Concurrency Proof Summary

Generated app-session hosts now enforce the library's one-time hosted-approval digest with a stable constraint name, backed by a real PostgreSQL barrier race that permits exactly one code and one session family.

## Tasks Completed

1. Added an explicit `user_app_login_attempts_approval_digest_index` to both generated migration branches and covered digest-only schema fields, rendered migration parsing, and feature-selection independence.
2. Added a ready/go PostgreSQL concurrency proof for two approvals of one signed continuation, including one-time hosted-code exchange and replay rejection.

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/install/app_sessions_generator_test.exs test/sigra/install/features/core_test.exs --trace` — passed (41 tests).
- `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login/concurrency_test.exs --trace` — passed (3 tests); the focused concurrency suite was also run three consecutive times successfully.
- `mix format --check-formatted test/sigra/install/app_sessions_generator_test.exs test/sigra/app_login/concurrency_test.exs` — passed.
- Generated prefixed PostgreSQL, unprefixed PostgreSQL, and unprefixed adapter migration sources are parsed with `Code.string_to_quoted/1` in the generator test; direct formatting is not applicable to the EEx migration template.
- `git diff --check` — passed.
- No project schema-drift contract was present.

## Decisions Made

- Use one explicit approval-digest index name in both migration branches to match `Sigra.AppLogin`'s changeset constraint name.
- Test the concurrent approval outcome as a multiset, never by choosing a winner.

## TDD Gate Compliance

Task 1 recorded RED then GREEN commits. Task 2 is an integration-evidence task over Plan 246-15's already-present approval implementation; its initial focused test passed after the disposable PostgreSQL service was started, so no additional production implementation commit was needed.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- Verified all three modified plan files exist.
- Verified task commits `6b10ffda`, `3bdcc83d`, and `ecb1dfc8` exist in git history.
