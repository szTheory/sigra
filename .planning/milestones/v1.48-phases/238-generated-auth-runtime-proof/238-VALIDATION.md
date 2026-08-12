---
phase: 238
slug: generated-auth-runtime-proof
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-05
---

# Phase 238 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `@playwright/test` 1.59.1 with `@axe-core/playwright` |
| **Config file** | `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://127.0.0.1:$PORT npx playwright test tests/generated-auth.spec.ts --project=generated-auth` |
| **Full suite command** | `GITHUB_WORKSPACE="$PWD" scripts/ci/generated-auth-runtime-proof.sh` |
| **Estimated runtime** | Quick source/contract sample: under 60 seconds; full generated-host browser proof: CI-bound |

## Sampling Rate

- **After every task commit:** Run the focused generated-auth Playwright target when its temporary host is available.
- **After every plan wave:** Run the fresh-host harness.
- **Before `$gsd-verify-work`:** Exact-commit CI evidence for the generated-host browser lane must be green.
- **Max feedback latency:** One focused Playwright target; never use watch mode or elapsed-time sleeps.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 238-01-01 | 01 | 0 | AUTH-02 | T-238-01 | Local OIDC start/callback preserves state and PKCE and reaches collision handling. | browser integration | `scripts/ci/generated-auth-runtime-proof.sh --probe-oauth` | ✅ | ✅ green |
| 238-02-01 | 02 | 1 | AUTH-01 | T-238-02 | Registration and confirmation complete through the rendered host and bounded mailbox. | browser integration | `scripts/ci/generated-auth-runtime-proof.sh --spec generated-auth` | ✅ | ✅ green |
| 238-02-02 | 02 | 1 | AUTH-01 | T-238-02 | Password, logout, magic-link, and reset transitions complete in one browser journey. | browser integration | `scripts/ci/generated-auth-runtime-proof.sh --spec generated-auth` | ✅ | ✅ green |
| 238-03-01 | 03 | 2 | AUTH-02, AUTH-03 | T-238-03 | The complete journey includes generated Google collision behavior. | browser integration | `scripts/ci/generated-auth-runtime-proof.sh --spec generated-auth` | ✅ | ✅ green |
| 238-03-02 | 03 | 2 | AUTH-02, AUTH-03 | T-238-03 | Every material auth render has scoped Axe and stable DOM assertions. | browser accessibility | `scripts/ci/generated-auth-runtime-proof.sh --spec generated-auth` | ✅ | ✅ green |
| 238-04-01 | 04 | 3 | AUTH-01, AUTH-02, AUTH-03 | — | Generated-auth specs are isolated in one dedicated Chromium project. | source contract / discovery | `mix test test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` | ✅ | ✅ green |
| 238-04-02 | 04 | 3 | AUTH-01, AUTH-02, AUTH-03 | — | A non-skipping PostgreSQL-backed direct CI lane owns the fresh-host proof. | source contract | `mix test test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` | ✅ | ✅ green |
| 238-05-01 | 05 | 4 | AUTH-01, AUTH-02, AUTH-03 | — | Exact-commit runtime evidence is schema-valid and provider-backed. | evidence receipt | `jq -e '.status == "passed"' 238-EVIDENCE.json` | ✅ | ✅ green — superseded blocked attempt |
| 238-06-01 | 06 | 5 | AUTH-01, AUTH-02, AUTH-03 | — | Retained harness completes all auth requirements on a recorded exact SHA. | evidence + source contract | `mix test test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` | ✅ | ✅ green |
| 238-07-01 | 07 | 6 | AUTH-01, AUTH-02, AUTH-03 | — | Reset, delivery, and rendered session revocation fail closed. | unit + browser discovery | `mix test test/sigra/install/generator_reset_test.exs test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` | ✅ | ✅ green |
| 238-07-02 | 07 | 6 | AUTH-01, AUTH-02, AUTH-03 | — | Fresh correction-SHA receipt ratifies both generated-auth specs. | evidence receipt | `jq -e '.status == "passed" and .job.conclusion == "success"' 238-EVIDENCE.json` | ✅ | ✅ green |
| 238-08-01 | 08 | 7 | AUTH-01, AUTH-02, AUTH-03 | — | Password reset atomically revokes canonical sessions. | unit + browser | `mix test test/sigra/auth_test.exs` | ✅ | ✅ green |
| 238-08-02 | 08 | 7 | AUTH-01, AUTH-02, AUTH-03 | — | Session revocation enforces current-user ownership. | unit + source contract | `mix test test/sigra/auth_test.exs test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` | ✅ | ✅ green |
| 238-08-03 | 08 | 7 | AUTH-01, AUTH-02, AUTH-03 | — | Security-correction SHA has successful immutable runtime evidence. | evidence receipt | `jq -e '.status == "passed" and .run.conclusion == "success"' 238-EVIDENCE.json` | ✅ | ✅ green |
| 238-09-01 | 09 | 8 | AUTH-01, AUTH-02, AUTH-03 | — | Both browser proofs use rendered session revocation without storage shortcuts. | source contract + discovery | `mix test test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` | ✅ | ✅ green |
| 238-09-02 | 09 | 8 | AUTH-01, AUTH-02, AUTH-03 | — | Final browser-correction SHA is recorded as a successful exact-SHA job. | evidence receipt | `jq -e '.status == "passed" and .job.conclusion == "success"' 238-EVIDENCE.json` | ✅ | ✅ green |

## Wave 0 Requirements

- [x] `scripts/ci/generated-auth-runtime-proof.sh` — fresh-host lifecycle, local provider-double configuration, and bounded cleanup.
- [x] `test/example/priv/playwright/tests/generated-auth.spec.ts` — generated B2C browser assertions.
- [x] `test/example/priv/playwright/fixtures/mailbox.ts` — no-sleep confirmation, magic, and reset-link readiness/extraction.
- [x] Playwright project configuration and CI lane/artifacts for the isolated generated-host test.

## Manual-Only Verifications

All phase behaviors have automated verification. Missing local PostgreSQL/browser prerequisites require CI evidence, not human substitution.

## Validation Sign-Off

- [x] All tasks have automated verification or Wave 0 dependencies.
- [x] Sampling continuity: no three consecutive tasks without automated verification.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags or sleep-based browser synchronization.
- [x] Exact-commit CI evidence is captured before setting `nyquist_compliant: true`.

**Approval:** approved 2026-08-10

## Validation Audit 2026-08-10

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

The reconciliation reran 38 focused ExUnit contracts, shell syntax, and
Playwright discovery for the two generated-auth tests. The immutable evidence
receipt records successful workflow run `31287691391`, job `93179989452`, and
exact tested SHA `2450b7e63199641170fb5f6e579001299a09a4ae` for the full `--all`
fresh-host browser proof. All AUTH-01, AUTH-02, and AUTH-03 behaviors therefore
have automated evidence; no manual-only substitution or new test file is needed.
