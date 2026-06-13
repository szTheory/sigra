# [RESOLVED] Two mix-test failures on v1.38-brand-v2 (were branch regressions, NOT pre-existing)

**Status:** RESOLVED 2026-06-13 (fix committed on v1.38-brand-v2 / PR #52).

## Correction to the original diagnosis
These were initially recorded (during Phase 183) as "pre-existing failures on main, byte-identical to merge-base." **That was wrong** — it relied on a stale local `main` pointer (`d0a02f9f`), which is itself a brand-branch commit ("Add auth branding previews and admin polish"), not `origin/main`. Against the real `origin/main` (`d9aefe2f`), both tests PASS. The failures were **regressions introduced on this branch by `d0a02f9f`** and would have shipped to main via PR #52 if not caught.

## What was actually wrong + the fix
1. `test/mix/tasks/sigra.install_test.exs:166` ("renders auth context template") — `d0a02f9f` added a `branding:` block to `core/auth.ex` referencing `<%= app_name %>` and `<%= from_email %>`. The real installer (`lib/mix/tasks/sigra.install.ex`) provides both, but this test's hand-built EEx binding was not updated. **Fix:** added `app_name: "MyApp"` + `from_email: "noreply@example.com"` to the test binding. The template + installer were always correct (no shipping bug).
2. `test/sigra/install/isolation_test.exs:86` — `d0a02f9f` added 3 legitimate core templates (`create_brand_profiles.exs`, `sigra_auth.css`, `sigra_auth_components.ex`). **Fix:** bumped the expected count 49 → 52.

Full root `mix test` now green: 2381 tests, 0 failures.
