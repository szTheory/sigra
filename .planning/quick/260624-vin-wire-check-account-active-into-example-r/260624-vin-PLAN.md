---
quick_id: 260624-vin
slug: wire-check-account-active-into-example-r
date: 2026-06-24
status: planned
---

# Wire check_account_active into example :require_authenticated pipeline (loop-safe)

## Goal
Deletion-scheduled personas (Frank/Grace) auto-redirect to `/users/reactivation`
instead of landing on `/app`. Wire the defined-but-unwired
`ExampleWeb.UserAuth.check_account_active/2` into the `:require_authenticated`
pipeline, with exempt-path guards so it (and the also-unwired
`require_password_unchanged/2`) can't redirect-loop.

Resolves todo `wire-check-account-active-reactivation`.

## Tasks

### Task 1 — Loop-safe guards + pipeline wiring (example) + tests
**Files:** `test/example/lib/example_web/user_auth.ex`,
`test/example/lib/example_web/router.ex`,
`test/example/test/example_web/account_active_redirect_test.exs` (new)

- `check_account_active/2`: pass through (no redirect/halt) when
  `conn.request_path` is `/users/reactivation` or `/users/log_out`; else keep the
  existing `deleted_at` → redirect to `/users/reactivation`.
- `require_password_unchanged/2`: pass through when `conn.request_path` is
  `/users/settings` or `/users/log_out`; else keep existing redirect. (Loop-safe
  only — NOT wired into a pipeline.)
- Router `pipeline :require_authenticated`: add `plug :check_account_active` after
  `plug :require_authenticated_user`, before `plug :require_mfa` (scope assigned first).
- New conn test: deletion-scheduled → GET `/app` → 302 `/users/reactivation`;
  deletion-scheduled → GET `/users/reactivation` → 200 (no loop); active → GET
  `/app` → 200.

**Verify:** `cd test/example && source ../../tmp/db.env && MIX_ENV=test mix test
test/example_web/account_active_redirect_test.exs`; full example suite green;
`mix compile --warnings-as-errors`.

### Task 2 — Template parity (loop-safe guards only) + golden fixture
**Files:** `priv/templates/sigra.install/core/user_auth.ex`,
`test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/user_auth.ex`

- Mirror the two guard bodies into the template (NOT router wiring — generated
  hosts keep `check_account_active` opt-in).
- Update the committed golden fixture to match byte-for-byte.

**Verify:** `mix test test/sigra/install/golden_diff_test.exs`.

## Out of scope
Dave (locked persona) keeps the generic enumeration-safe error. No generator
router-wiring change.
