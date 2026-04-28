---
phase: 87
plan: 01a
subsystem: testing
tags: [oauth, oidc, test_server, playwright, env-gates]
dependency_graph:
  requires: []
  provides: [oauth-issuer-test-seam, env-gated-example-test-endpoints, playwright-oauth-fixture]
  affects: [phase-87-01b, phase-87-02]
tech_stack:
  added: [test_server]
  patterns: [loopback oidc issuer, runtime env-gated test routes, one-shot TestServer route rearming]
key_files:
  created:
    - test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid1_private.pem
    - test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid1_public.pem
    - test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid2_private.pem
    - test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid2_public.pem
    - test/support/sigra/testing/fixtures/README.md
    - test/example/lib/example_web/controllers/test_db_probe_controller.ex
    - test/example/lib/example_web/controllers/test_oauth_issuer_controller.ex
    - test/example/priv/playwright/fixtures/oauthIssuer.ts
  modified:
    - mix.exs
    - mix.lock
    - test/support/sigra/testing/oauth_issuer.ex
    - test/sigra/testing/oauth_issuer_test.exs
    - test/example/lib/example_web/router.ex
    - test/example/test/example_web/test_endpoints_test.exs
decisions:
  - "Keep the issuer TestServer-backed by rearming one-shot routes from a helper process instead of swapping to a different HTTP stack."
  - "Publish the issuer base URL as 127.0.0.1 to match the plan's loopback-only contract."
metrics:
  duration: session
  completed: 2026-04-28
requirements-completed: [GAUAT-03, GAUAT-04, GAUAT-05, GAUAT-06]
---

# Phase 87 Plan 01a: OAuth Issuer Test Seam Summary

## What shipped

- Added `Sigra.Testing.OAuthIssuer`, a loopback OIDC issuer with discovery, authorize, token, userinfo, and JWKS endpoints backed by `TestServer`.
- Landed the full issuer GREEN suite covering RS256 signing, PKCE rejection, configurable expiration, refresh-token stability toggles, JWKS kid-count rotation, and boolean `email_verified`.
- Added env-gated example-app test endpoints for issuer setup/reset and DB probing, plus the `oauthIssuer.ts` Playwright helper surface that Phase 87-01b binds against.

## Verification

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/testing/oauth_issuer_test.exs --no-color`
- `cd test/example && EXAMPLE_DB_PROBE_ENABLED=0 EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=0 MIX_ENV=test mix test test/example_web/test_endpoints_test.exs --include example_app --no-color`
- `! grep -rEq "accounts\.google\.com|oauth2\.googleapis\.com|googleapis\.com" test/support/sigra/testing/oauth_issuer.ex test/example/priv/playwright/fixtures/oauthIssuer.ts`

## Deviations from plan

- `test_server` 0.1.22 routes are one-shot, so the issuer re-arms each endpoint from a helper process to preserve the planned TestServer-backed design without switching to Bandit or Plug.Cowboy.
- The focused env-gate regression runs from `test/example` rather than the repo root because the example app is its own Mix project.

## Commits

- `6f61ed7` — scaffold oauth issuer test seam
- `34d91c5` — complete oauth issuer green cycle

## Self-Check: PASSED

- Summary file exists.
- Commit hashes `6f61ed7` and `34d91c5` are present in `git log`.
- Focused issuer and env-gate verification commands pass.
