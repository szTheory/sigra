---
phase: 240-alpha-operations-rehearsal
fixed_at: 2026-08-10T19:00:00-04:00
source_verification: .planning/phases/240-alpha-operations-rehearsal/240-VERIFICATION.md
status: implementation_complete_runtime_environment_blocked
fix_commit: 7db4ea04
---

# Phase 240 Verification Fix

Commit `7db4ea04` closes the two implementation gaps reported by re-verification.

## Fixed gaps

- Every fresh host in `passkeys-opt-out-smoke.sh` now runs `MIX_ENV=dev mix deps.get` immediately after `mix sigra.install`, before assertions, the generated B2C request probe, or compilation. The B2C OAuth leg refreshes again after OAuth generation so every injected dependency remains checked.
- `generated-auth-runtime-proof.sh` now writes and runs a disposable generated-host LiveView integration test. It submits the canonical B2C registration LiveView at its configured bound, asserts the generic N+1 outcome, and checks the generated Hammer key is denied with a positive remaining window. The test uses no timing wait and runs after test-database migration.
- `GeneratedRateLimitContractTest` locks both contracts: moving/removing the post-install dependency refresh or removing the LiveView event/Hammer exhaustion proof fails the focused suite.

## Verification

- PASS: `bash -n scripts/ci/passkeys-opt-out-smoke.sh scripts/ci/generated-auth-runtime-proof.sh`
- PASS: `MIX_ENV=test mix test test/sigra/install/generated_rate_limit_contract_test.exs test/sigra/install/generated_rate_limit_context_test.exs test/sigra/plug/rate_limit_test.exs` — 31 tests, 0 failures.
- PASS: `MIX_ENV=test mix test test/sigra/install/generated_rate_limit_contract_test.exs test/sigra/install/generated_rate_limit_context_test.exs test/sigra/plug/rate_limit_test.exs test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs test/sigra/planning/phase_240_no_secrets_ci_test.exs test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` — 56 tests, 0 failures.
- PASS: `git diff --check`.

## Runtime prerequisite

The exact generated-host scripts require PostgreSQL. This workstation’s configured test endpoint, `127.0.0.1:53988`, returned `no response` from `pg_isready`, so the database-backed smoke and generated LiveView probe could not be run locally. CI must execute the declared scripts with PostgreSQL available; no runtime pass is claimed here.
