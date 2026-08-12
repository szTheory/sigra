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
| **Quick run command** | `MIX_ENV=test mix test test/sigra/install/api_token_generator_test.exs test/sigra/install/features/core_test.exs test/sigra/api_token_test.exs test/sigra/api_token/scope_registry_test.exs test/sigra/jwt_test.exs test/sigra/jwt/refresh_token_test.exs test/sigra/jwt/signer_test.exs` |
| **Full suite command** | `MIX_ENV=test mix ci` |
| **Estimated runtime** | Focused unit contracts under 30 seconds; generated-host and Postgres gates longer and environment-dependent |

## Sampling Rate

- **After every task commit:** Run the touched focused test plus the quick contract set where practical.
- **After every plan wave:** Run affected Postgres integration tests and both independent generated-host lanes.
- **Before `$gsd-verify-work`:** `MIX_ENV=test mix ci` must be green in an environment with PostgreSQL and `phx_new`; otherwise preserve a fail-closed diagnostic and do not claim the unavailable evidence.
- **Max feedback latency:** 30 seconds for unit/source contracts; generated-host runtime evidence is a bounded phase gate.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 244-01-01 | 01 | 1 | PAT-01 | generator coupling | `--api` emits a complete explicit PAT host without JWT dependency | generator + fresh-host | focused generator lane | ❌ W0 | ⬜ pending |
| 244-02-01 | 02 | 2 | PAT-02 | cross-account revoke / recursive bearer management | browser+CSRF+sudo management derives owner from Scope and validates scopes | unit + integration | PAT library/controller/browser suite | ❌ W0 | ⬜ pending |
| 244-03-01 | 03 | 1 | JWT-01 | algorithm/type/audience confusion | mandatory JWT claims and header type fail closed; `aud` scalar/array membership works | unit | JWT and signer suites | partial | ⬜ pending |
| 244-04-01 | 04 | 2 | JWT-02 | client-selected authority | generated JWT seam has host-selected scopes and no password exchange route | generator + fresh-host | independent JWT host lane | ❌ W0 | ⬜ pending |
| 244-05-01 | 05 | 2 | JWT-02 | refresh replay race | audit-on/off rotation and reuse are one transaction; double refresh yields one winner | Postgres concurrency | refresh atomicity/cofate suite | partial | ⬜ pending |

## Wave 0 Requirements

- [ ] Independent Phase 244 `--api` and `--jwt` generated-host runtime lanes.
- [ ] Negative generator assertions for cross-feature artifacts, routes, and configuration.
- [ ] PAT owner-constrained revoke and browser/CSRF/sudo integration tests.
- [ ] JWT required-claim, `typ`, issuer, scalar/array audience, algorithm, `nbf`, and reserved-claim tests.
- [ ] Audit-off rollback and deterministic concurrent refresh-family tests using Postgres barriers and no sleeps.

## Manual-Only Verifications

All phase behaviors have automated verification. No human UAT is required.

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or Wave 0 dependencies.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers every missing reference above.
- [ ] No watch-mode flags or sleeps.
- [ ] Focused feedback latency remains under 30 seconds.
- [ ] `nyquist_compliant: true` set after execution evidence exists.

**Approval:** pending
