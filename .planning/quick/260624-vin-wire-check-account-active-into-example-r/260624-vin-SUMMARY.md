---
quick_id: 260624-vin
slug: wire-check-account-active-into-example-r
date: 2026-06-24
status: complete
---

# Wire check_account_active into example :require_authenticated (loop-safe)

Resolves todo `wire-check-account-active-reactivation`.

## What changed
- **`test/example/lib/example_web/user_auth.ex`** — added an exact-request-path
  `exempt_path?/2` guard. `check_account_active/2` now skips its redirect on
  `/users/reactivation` and `/users/log_out`; `require_password_unchanged/2` skips
  on `/users/settings` and `/users/log_out`. Both are now loop-safe.
- **`test/example/lib/example_web/router.ex`** — wired `plug :check_account_active`
  into `pipeline :require_authenticated`, after `:require_authenticated_user`,
  before `:require_mfa`.
- **`test/example/test/example_web/account_active_redirect_test.exs`** (new) —
  deletion-scheduled → `/app` 302s to `/users/reactivation`; deletion-scheduled →
  `/users/reactivation` renders 200 (no-loop regression guard); active → `/app` 200.
- **Template parity** — mirrored the loop-safe guard bodies into
  `priv/templates/sigra.install/core/user_auth.ex` and updated the committed golden
  fixture (`test/fixtures/install_golden/.../user_auth.ex`) byte-for-byte. Router
  wiring stays opt-in for generated hosts (no template router change).

## Incidental bug fixed (separate commit)
`Sigra.Testing.scheduled_deletion_fixture/3` (and `deleted_user_fixture/2`) wrote
microsecond `DateTime`s, but Sigra's generated `deleted_at`/`scheduled_deletion_at`
columns are `:utc_datetime` (second precision) — so `repo.update!` raised
`ArgumentError` the instant either helper ran against a real schema. The path was
never exercised until this todo wired the flow. Truncated to seconds (safe for both
`:utc_datetime` and `:utc_datetime_usec`). Surfaced by the new test on first run.

## Commits
- `08c947b9` — fix(testing): truncate deletion fixture timestamps
- `619f1b12` — feat(example): wire check_account_active (loop-safe) + test
- `1ea02781` — feat(install): mirror guards into generated user_auth + golden fixture

## Verification
- New test: **3 tests, 0 failures**.
- Full example suite: **228 tests, 0 failures** (was 225; +3 new). The `[error]`
  log lines are intentional Jetstream structural-defense logs from existing
  invitation tests, not failures.
- `mix test test/sigra/install/golden_diff_test.exs`: **2 tests, 0 failures** — but
  ONLY after installing the pinned **phx_new 1.8.7** archive (1.8.8 was installed and
  produced the known spurious `config/config.exs` `root_tag_attribute` byte-diff,
  documented in CLAUDE.md; that diff stops the tree-walk before `user_auth.ex`, so
  1.8.7 was required to actually exercise the parity edit). Re-ran on 1.8.7 → green.
- `mix compile --warnings-as-errors`: clean.

## Out of scope (unchanged)
Dave (locked persona) keeps the generic enumeration-safe error. No generator
router-wiring change.
