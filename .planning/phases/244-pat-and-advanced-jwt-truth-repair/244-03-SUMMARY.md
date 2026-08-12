---
phase: 244-pat-and-advanced-jwt-truth-repair
plan: 03
subsystem: auth
tags: [personal-access-token, generator, phoenix, csrf, sudo, postgres]
requires:
  - phase: 244-pat-and-advanced-jwt-truth-repair
    provides: "Owner-constrained PAT revocation and scope validation"
provides:
  - "Browser/CSRF/sudo-gated PAT self-management routes"
  - "Fresh API-only host runtime proof for PAT authentication and rejected mutation invariants"
affects: [PAT-01, PAT-02]
key-files:
  created:
    - test/sigra/planning/phase_244_generated_auth_runtime_proof_test.exs
  modified:
    - lib/sigra/install/features/core.ex
    - priv/templates/sigra.install/core/auth.ex
    - priv/templates/sigra.install/core/auth_api_token.ex
    - priv/templates/sigra.install/core/api_token_controller.ex
    - priv/templates/sigra.install/core/user_api_token.ex
    - test/sigra/install/api_token_generator_test.exs
key-decisions:
  - "PAT management is browser-session-only and derives ownership only from current_scope.user."
  - "Fresh-host proof uses an isolated PostgreSQL database and real generated router requests."
metrics:
  tasks: 2
  files: 6
status: complete
---

# Phase 244 Plan 03: PAT Browser Lifecycle Summary

**Generated API-only hosts now create and authenticate PATs, while browser CSRF and fresh-sudo gates protect owner-bound self-management.**

## Accomplishments

- Moved PAT list/create/revoke routes behind browser, authenticated, and sudo pipelines; no bearer-management route remains.
- Generated owner-bound delegates and schema configuration needed for real PAT persistence.
- Added a disposable fresh-host proof that installs twice, migrates, compiles, authenticates a PAT with `FetchAPIToken`, and executes generated browser routes.
- Proved unauthenticated, missing/invalid-CSRF, and stale-sudo mutations leave the owner PAT row set unchanged.

## Task Commits

1. Task 1 — `8e38cb98`, `75258cfb`
2. Task 2 — `985e5e60`

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/install/api_token_generator_test.exs test/sigra/api_token_test.exs --trace` — 99 tests, 0 failures.
- `source tmp/db.env && MIX_ENV=test mix test test/sigra/planning/phase_244_generated_auth_runtime_proof_test.exs --only phase_244_api --trace` — 1 test, 0 failures (40.8s).

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 1 - Generator correctness] Bound the emitted UserAPIToken schema and added its required changeset contract so fresh hosts can persist PATs.
2. [Rule 3 - Runtime harness] Used canonical Phoenix/Gettext bootstrap, explicit disposable PostgreSQL endpoint/config, and isolated database names for deterministic fresh-host proof.

## Known Stubs

None.

## Threat Flags

None. The implementation narrows PAT management to existing browser security gates.

## Self-Check: PASSED

Verified task commits and all planned generated/runtime test files.
