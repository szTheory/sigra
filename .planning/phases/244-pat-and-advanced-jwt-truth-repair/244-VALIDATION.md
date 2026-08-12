---
phase: 244
slug: pat-and-advanced-jwt-truth-repair
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-12
---

# Phase 244 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Mox; `Sigra.Test.PostgresCase`; generated-host compile/runtime harness |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/sigra/install/features/core_test.exs test/sigra/install/api_token_generator_test.exs test/sigra/api_token_test.exs test/sigra/api_token/scope_registry_test.exs test/sigra/jwt_test.exs test/sigra/jwt/refresh_token_test.exs test/sigra/jwt/signer_test.exs test/sigra/jwt_refresh_audit_cofate_test.exs` |
| **Full suite command** | `MIX_ENV=test mix ci` |
| **Estimated runtime** | Focused unit contracts under 30 seconds; generated-host and Postgres gates longer and environment-dependent |

## Sampling Rate

- **After every task commit:** Run the touched focused test plus the quick contract set where practical.
- **After Wave 3:** Run the API-only fresh-host lane, including real-router PAT browser management denials and unchanged-row assertions.
- **After Wave 5:** Run both independent generated-host lanes together to re-prove cross-feature absence and repeat-install behavior.
- **After Wave 6:** Run the complete focused contract set, Postgres refresh concurrency proof, and both generated-host lanes.
- **Before `$gsd-verify-work`:** `MIX_ENV=test mix ci` must be green in an environment with PostgreSQL and `phx_new`; otherwise preserve a fail-closed diagnostic and do not claim the unavailable evidence.
- **Max feedback latency:** 30 seconds for unit/source contracts; generated-host runtime evidence is a bounded phase gate.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 244-01-01 | 01 | 1 | PAT-01, JWT-01, JWT-02 | T-244-01..04 | API/JWT selection is disjoint across files, injections, config, routes, instructions, and repeat install | generator source contract | `MIX_ENV=test mix test test/sigra/install/features/core_test.exs test/sigra/install/api_token_generator_test.exs --trace` | existing; update | ⬜ pending |
| 244-02-01 | 02 | 2 | PAT-02 | T-244-05..08 | owner-constrained revoke and server allowlist enforce empty/single/invalid scope and idempotent denial | Postgres integration | `MIX_ENV=test mix test test/sigra/api_token_test.exs --trace` | existing; update | ⬜ pending |
| 244-03-01 | 03 | 3 | PAT-02 | T-244-09..11 | generated PAT management routes use browser/authenticated/sudo and owner-required delegates | generator + library contract | `MIX_ENV=test mix test test/sigra/install/api_token_generator_test.exs test/sigra/api_token_test.exs --trace` | existing; update | ⬜ pending |
| 244-03-02 | 03 | 3 | PAT-01, PAT-02 | T-244-09..12 | fresh API host installs twice, authenticates PATs, and real-router valid/CSRF/auth/sudo paths prove mutation or pre-mutation halt | generated-host runtime + browser integration | `MIX_ENV=test mix test test/sigra/planning/phase_244_generated_auth_runtime_proof_test.exs --only phase_244_api --trace` | ❌ W0 | ⬜ pending |
| 244-04-01 | 04 | 4 | JWT-01, JWT-02 | T-244-13..17 | configured signer precedes typ; mandatory claims, scalar/array audience, optional nbf, and reserved claims fail closed | unit contract | `MIX_ENV=test mix test test/sigra/jwt_test.exs test/sigra/jwt/signer_test.exs --trace` | existing; update | ⬜ pending |
| 244-05-01 | 05 | 5 | JWT-01, JWT-02 | T-244-18..21 | fresh JWT-only host uses host-policy issuance and strict verification without PAT/password/request-authority residue | generated-host runtime | `MIX_ENV=test mix test test/sigra/install/api_token_generator_test.exs test/sigra/planning/phase_244_generated_auth_runtime_proof_test.exs --trace` | ❌ W0 | ⬜ pending |
| 244-06-01 | 06 | 6 | JWT-02 | T-244-22..25 | audit-on/off refresh classification, rotation, reuse revoke, rollback, and double-refresh serialize in one transaction | Postgres co-fate + concurrency | `MIX_ENV=test mix test test/sigra/jwt_refresh_audit_cofate_test.exs --trace` | existing; update | ⬜ pending |

## Wave 0 Requirements

- [ ] Independent Phase 244 `--api` and `--jwt` generated-host runtime lanes.
- [ ] Negative generator assertions for cross-feature artifacts, routes, and configuration.
- [ ] PAT owner-constrained revoke plus real generated endpoint/router/controller tests for valid, unauthenticated, missing/invalid-CSRF, and stale-sudo list/create/revoke; rejected mutation rows remain unchanged.
- [ ] JWT required-claim, `typ`, issuer, scalar/array audience, algorithm, `nbf`, and reserved-claim tests.
- [ ] Audit-off rollback and deterministic concurrent refresh-family tests using Postgres barriers and no sleeps.

## Manual-Only Verifications

All phase behaviors have automated verification. No human UAT is required.

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or Wave 0 dependencies.
- [ ] All seven actual task IDs across six waves match PLAN frontmatter and task commands.
- [ ] Sampling continuity: every task has an automated verification command.
- [ ] Wave 0 covers every missing reference above.
- [ ] No watch-mode flags or sleeps.
- [ ] Focused feedback latency remains under 30 seconds.
- [ ] `nyquist_compliant: true` set after execution evidence exists.

**Approval:** pending
