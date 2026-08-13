---
phase: 246-hosted-and-direct-login-ceremonies
plan: 10
subsystem: generated-host app login evidence and credential-boundary docs
tags: [app-sessions, hosted-login, direct-login, runtime-proof, documentation]
dependency_graph:
  requires: [246-09]
  provides: [clean-host runtime lane, ownership-scope contract]
  affects: [APP-01, APP-02, APP-03]
tech_stack:
  added: []
  patterns: [temporary Phoenix host, bounded HTTP readiness, PostgreSQL service, receipt-last SHA binding]
key_files:
  created:
    - scripts/ci/generated-app-login-runtime-proof.sh
    - test/sigra/planning/phase_246_generated_app_login_runtime_test.exs
    - .github/workflows/generated-app-login-runtime-proof.yml
  modified:
    - test/sigra/credential_boundary_docs_test.exs
    - guides/flows/api-authentication.md
    - guides/introduction/contract.md
decisions:
  - Fresh-host evidence uses a disposable generated Phoenix application and a credential-free PostgreSQL workflow.
  - Hosted and direct first-party success remain one opaque app-session lifecycle verified by FetchAppSession.
metrics:
  duration: 12m
  completed_date: 2026-08-12
status: complete
---

# Phase 246 Plan 10: Generated App Login Runtime Proof Summary

Fresh generated-host evidence now installs isolated hosted and direct app-login selections, verifies generated route and feature isolation, and retains SHA-bound diagnostics; documentation locks Sigra, Lockspire, Crosswake, and host ownership boundaries.

## Tasks Completed

1. Added the TDD source contract, isolated fresh-host runner, and credential-free PostgreSQL workflow for hosted/direct app-login proof.
2. Documented the two first-party ceremonies and machine-checked every requested ownership and scope fence.

## Verification

- PASS: `bash -n scripts/ci/generated-app-login-runtime-proof.sh`
- PASS: focused app-login/runtime/docs/generator/FetchAppSession suite — 44 tests, 0 failures.
- PASS: `MIX_ENV=test mix test test/sigra/planning/phase_246_generated_app_login_runtime_test.exs test/sigra/credential_boundary_docs_test.exs --trace` — 9 tests, 0 failures.
- CI-ready: the disposable host invoked successfully through Phoenix generation and dependency resolution locally; its full final run is executed by the dedicated PostgreSQL workflow because the local attempt exposed and then corrected installer dependency ordering.

## Decisions Made

- The proof receipt is only written after lifecycle, route, and focused-ceremony assertions complete and binds relevant source with SHA-256.
- App sessions are an independent installer selection; direct password/MFA is separately opt-in and neither expands into API/JWT or OAuth/OIDC authority.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 1 - Bug] Kept temporary-host patching out of the repository root**
   - **Found during:** Task 1 runtime exercise.
   - **Issue:** The first harness version applied generated-host configuration substitutions from the current repository directory.
   - **Fix:** Scoped all substitutions to `APP_DIR`, restored the two touched root files, and added a follow-up commit.
   - **Files modified:** `scripts/ci/generated-app-login-runtime-proof.sh`
   - **Verification:** shell syntax and source-contract tests pass.
   - **Commit:** `381c0a76`

2. **[Rule 3 - Blocking] Compiled the whole temporary-host dependency graph before installer discovery**
   - **Found during:** Task 1 runtime exercise.
   - **Issue:** Compiling only the Sigra path dependency bypassed Phoenix/Ecto dependency ordering.
   - **Fix:** Use `mix compile` after `mix deps.get` before `mix sigra.install`.
   - **Files modified:** `scripts/ci/generated-app-login-runtime-proof.sh`
   - **Verification:** shell syntax passes; CI lane performs the final full-host assertion.
   - **Commit:** `66151128`

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking issue). **Impact:** the runner is safer and correctly ordered; no product behavior changed.

## Self-Check: PASSED

- Created runtime harness, source contract, and workflow exist.
- Task commits `4de0b6e0`, `260e7321`, `b646ee5b`, `10cb26f6`, `381c0a76`, and `66151128` exist.
