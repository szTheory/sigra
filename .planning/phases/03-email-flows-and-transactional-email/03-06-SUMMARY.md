---
phase: 03-email-flows-and-transactional-email
plan: 06
subsystem: email-delivery
tags: [oban, worker, async-email, gap-closure]
dependency_graph:
  requires: [03-05]
  provides: [working-email-delivery-worker, worker-runtime-config]
  affects: [lib/sigra/workers/email_delivery.ex, lib/mix/tasks/sigra.install.ex]
tech_stack:
  added: []
  patterns: [application-env-runtime-config, oban-cancel-vs-error, process-dict-test-mocks]
key_files:
  created: []
  modified:
    - lib/sigra/workers/email_delivery.ex
    - test/sigra/workers/email_delivery_test.exs
    - lib/mix/tasks/sigra.install.ex
decisions:
  - "D-22 runtime config: Worker resolves repo/user_schema/email_module/mailer from Application.fetch_env!(:sigra, key) at runtime"
  - "Oban cancel vs error: {:cancel, reason} for non-retryable (user not found, unknown type); {:error, reason} for retryable (mailer failure)"
  - "No module names in job args: T-3-INFRA-01 security -- only email_type, user_id, and minimal metadata stored in jobs table"
metrics:
  duration: "3 minutes"
  completed: "2026-04-07"
  tasks_completed: 2
  tasks_total: 2
  tests_added: 6
  tests_total: 9
  files_modified: 3
---

# Phase 03 Plan 06: EmailDelivery Worker Gap Closure Summary

Wire EmailDelivery Oban worker from stub to working perform/1 that reconstructs emails from job args and delivers via host app's configured mailer, resolving all modules from Application env at runtime.

## What Was Done

### Task 1: Implement EmailDelivery.perform/1 and update tests (TDD)

Replaced the stub `perform/1` (which always returned `{:ok, :delivered}`) with a working implementation:

1. **resolve_config/0** reads `repo`, `user_schema`, `email_module`, `mailer` from `Application.fetch_env!(:sigra, key)` at runtime
2. **User lookup** via `repo.get(user_schema, user_id)` -- returns `{:cancel, :user_not_found}` if nil (Oban will not retry)
3. **Email reconstruction** via `build_email/3` dispatches on `email_type` string to call the appropriate email module function (`confirmation_email/3`, `reset_password_email/2`, `magic_link_email/2`)
4. **Delivery** extracts subject/html_body/text_body from the email struct and calls `mailer.deliver/3`
5. **Error handling**: `{:cancel, reason}` for non-retryable failures, `{:error, reason}` for retryable failures

Tests use inline mock modules with Process dictionary for state control (async: false). 6 new perform/1 test cases cover all paths.

**Commit:** c58b4c8

### Task 2: Add config :sigra application env injection to generator

Added a `config :sigra` block to the install generator's config injection, alongside the existing `config :otp_app, :sigra` block:

```elixir
config :sigra,
  repo: MyApp.Repo,
  user_schema: MyApp.Accounts.User,
  email_module: MyApp.Accounts.Emails,
  mailer: MyApp.Accounts.Mailer
```

Verified that `build_job/3` in `Sigra.Delivery` does NOT pass module names in job args (security: T-3-INFRA-01).

**Commit:** afc4506

## Deviations from Plan

None -- plan executed exactly as written.

## Verification Results

1. `mix compile --warnings-as-errors` -- clean compilation
2. `mix test` -- 362 tests, 0 failures (no regressions)
3. `mix test test/sigra/workers/email_delivery_test.exs --trace` -- 9 tests, 0 failures
4. `grep "Application.fetch_env!(:sigra"` -- 4 config keys resolved from app env
5. `grep "config :sigra,"` -- generator injects worker config block
6. Stub `{:ok, :delivered}` replaced with actual delivery logic

## Known Stubs

None -- the EmailDelivery stub was the gap being closed by this plan.

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Application.fetch_env! (not get_env) | Worker must fail fast if config missing -- silent nil would cause confusing errors downstream |
| {:cancel, reason} for user_not_found | User deleted between enqueue and delivery is permanent -- retrying won't help |
| Process dictionary for test mocks | Simple, no extra deps, appropriate for async: false tests with inline mock modules |
| Separate config :sigra block | Distinct from config :otp_app, :sigra -- the former is for library-internal modules (workers), the latter for the generated auth context |

## Self-Check: PASSED

- All 4 modified/created files exist on disk
- Both task commits (c58b4c8, afc4506) found in git log
- 362 tests pass, 0 failures
