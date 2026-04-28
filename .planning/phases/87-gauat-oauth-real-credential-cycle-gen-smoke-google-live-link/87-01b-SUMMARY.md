---
phase: 87
plan: 01b
subsystem: oauth
tags: [oauth, install-smoke, playwright, ci, docs]
dependency_graph:
  requires: [oauth-issuer-test-seam]
  provides: [oauth-smoketest-task, oauth-playwright-lane, oauth-install-smoke, oauth-controller-coverage]
  affects: [phase-87-02]
tech_stack:
  added: [bandit-test-runtime, oauth-playwright-specs]
  patterns: [controller-flash-preservation, configurable-example-base-url, ci-evidence-bundle]
key_files:
  modified:
    - mix.exs
    - mix.lock
    - lib/mix/tasks/sigra.oauth.smoketest.ex
    - lib/sigra/oauth/smoketest.ex
    - docs/oauth-google-setup.md
    - scripts/ci/install-smoke.sh
    - .github/workflows/ci.yml
    - test/example/config/config.exs
    - test/example/lib/example/accounts.ex
    - test/example/lib/example_web/controllers/oauth_controller.ex
    - test/example/lib/example_web/controllers/session_controller.ex
    - test/example/lib/example_web/controllers/session_html.ex
    - test/example/lib/example_web/controllers/settings_html.ex
    - test/example/lib/example_web/user_auth.ex
    - test/example/priv/playwright/tests/oauth-register.spec.ts
    - test/example/priv/playwright/tests/oauth-link.spec.ts
    - test/example/priv/playwright/tests/oauth-email-match.spec.ts
    - test/example/test/example_web/oauth_controller_test.exs
decisions:
  - "Make the example app's OAuth base URL configurable via SIGRA_EXAMPLE_URL so local browser runs can avoid whatever is already bound to :4000."
  - "Preserve flash across session renewal and render flash groups on both login and settings pages so OAuth-link success/error states are test-visible."
  - "Handle authenticated email-match callbacks by completing the link immediately instead of redirecting the signed-in user back through /users/log_in."
metrics:
  duration: session
  completed: 2026-04-28
requirements-completed: [GAUAT-03, GAUAT-04, GAUAT-05, GAUAT-06]
---

# Phase 87 Plan 01b Summary

## What shipped

- Added the adopter-side `mix sigra.oauth.smoketest --provider=google` task and runtime, plus `docs/oauth-google-setup.md`.
- Extended `scripts/ci/install-smoke.sh` and `.github/workflows/ci.yml` so the greenfield OAuth generator path runs `mix test`, writes `.planning/uat-evidence/v1.20/oauth-gen/transcript.log`, uploads the artifact bundle, and promotes it on `v*` tags.
- Landed the three OAuth Playwright specs (`oauth-register`, `oauth-link`, `oauth-email-match`) plus controller coverage for the callback edge cases.
- Fixed the example app surfaces the specs exposed: configurable base URL for local OAuth loops, flash rendering/preservation on login and settings, and direct linking for already-authenticated users.

## Verification

- `MIX_ENV=test mix test test/sigra/install/oauth_smoketest_task_test.exs --no-color`
- `MIX_ENV=test mix test test/sigra/testing/oauth_issuer_test.exs --no-color`
- `cd test/example && CLOAK_KEY='MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=' MIX_ENV=test mix test test/example_web/oauth_controller_test.exs --include example_app --no-color`
- `CLOAK_KEY='MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=' GITHUB_WORKSPACE=$(pwd) scripts/ci/install-smoke.sh`
- `cd test/example/priv/playwright && CI=1 SIGRA_EXAMPLE_URL='http://localhost:4010' npx playwright test tests/oauth-register.spec.ts tests/oauth-link.spec.ts tests/oauth-email-match.spec.ts --project=chromium --reporter=line`

## Notes

- Local phase-close SHA: `367a164`.
- The GAUAT-05 baseline file used for the hero evidence copy is `test/example/priv/playwright/tests/oauth-link.spec.ts-snapshots/oauth-link-disabled-tooltip-chromium.png`.
- No GitHub Actions run URL exists yet for `367a164`; Plan 87-02 can generate local evidence on disk, but CI provenance remains pending until that SHA is pushed.

## Commits

- `481de08` — add oauth smoketest task
- `1ab2692` — extend oauth install smoke
- `ecc5203` — scaffold example app oauth surface
- `d871735` — wire example oauth login and settings
- `367a164` — add oauth playwright workflow lane

## Self-Check: PASSED (local)

- Summary file exists.
- Focused smoketest, controller, install-smoke, and Playwright verification commands pass locally.
- Remaining provenance gap is external only: GitHub Actions has not yet run on `367a164`.

