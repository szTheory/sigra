# Plan 34-01 Summary — Smoke seed, VFY-01 Playwright, `--test` slices, CI timeouts

## Outcome

Delivered Phase 34 Plan 01: third seeded user for impersonation, three grep-stable `VFY-01` Playwright groups on `admin-generated.spec.ts`, `audit-export` / `impersonation-controller` smoke targets, `timeout-minutes: 60` + `PLAYWRIGHT_RETRIES` on CI, and Playwright config parsing for `PLAYWRIGHT_RETRIES`.

## Key files

| Path | Change |
| --- | --- |
| `scripts/ci/admin-acceptance-smoke.sh` | `SIGRA_IMPERSONATION_TARGET_EMAIL`, seed user, `--test` cases, help text |
| `test/example/priv/playwright/tests/admin-generated.spec.ts` | VFY-01 describes + helpers + `adminShellHeader` strict-mode fix |
| `test/example/priv/playwright/playwright.config.ts` | Env-driven retries |
| `.github/workflows/ci.yml` | Job timeout + env |
| `priv/templates/sigra.install/core/auth.ex` | `cancel_deletion/2` opts merge (fixes `--warnings-as-errors` on fresh host) |
| `lib/sigra/install/features/core.ex` | Injects `config :app, :sigra_config, ...` for admin LiveViews |
| `lib/sigra/admin/users/query.ex` | `select_row/2` without `passkey_state` when passkeys omitted |
| `test/fixtures/install_golden/tree/config/config.exs` | Golden parity for `:sigra_config` |

## Verification

- `bash -n scripts/ci/admin-acceptance-smoke.sh`
- `cd test/example/priv/playwright && npx playwright test tests/admin-generated.spec.ts --list`
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test audit-export` → exit 0
- Same env `--test impersonation-controller` → exit 0
- Same env `--test all` → exit 0 (5 Playwright tests)
- `mix test test/sigra/install/features/core_test.exs test/sigra/admin/users_actions_test.exs test/sigra/admin/users_query_test.exs`

## Deviations

Support fixes not listed in the original PLAN `files_modified` were required so the smoke path actually boots: `cancel_deletion/2`, `:sigra_config` injection, passkey-less `select_row`, golden fixture, and Playwright strict-mode header disambiguation.

## Self-Check: PASSED
