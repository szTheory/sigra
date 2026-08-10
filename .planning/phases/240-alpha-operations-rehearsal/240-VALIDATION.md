---
phase: 240
slug: alpha-operations-rehearsal
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-10
---

# Phase 240 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Mox; generated-host browser proof uses Playwright |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/sigra/plug/rate_limit_test.exs test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs` |
| **Full suite command** | `mix test` (requires local PostgreSQL) |
| **Estimated runtime** | ~60 seconds for targeted tests |

---

## Sampling Rate

- **After every task commit:** Run the targeted command above; run the bounded fresh-host proof when templates or CI scripts change.
- **After every plan wave:** Run `mix test` with PostgreSQL available.
- **Before `$gsd-verify-work`:** Full suite and both independent no-secrets evidence lanes must be green.
- **Max feedback latency:** 60 seconds for targeted checks.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 240-05-01 | 05 | 0 | OPS-01 | T-240-W0-01 | Generated ownership and resolved flow-map behaviors exist as active RED contracts before implementation. | ExUnit contract scaffolds | `mix format --check-formatted test/sigra/install/generated_rate_limit_contract_test.exs test/sigra/install/generated_rate_limit_context_test.exs` | ❌ W0 | ⬜ pending |
| 240-05-02 | 05 | 0 | OPS-01, OPS-02 | T-240-W0-02 | Operator evidence, no-secret lanes, and local-only coverage semantics exist as active RED contracts before implementation. | ExUnit source-contract scaffolds | `mix format --check-formatted test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs test/sigra/planning/phase_240_no_secrets_ci_test.exs` | ❌ W0 | ⬜ pending |
| 240-01-01 | 01 | 1 | OPS-01 | T-240-01 | Fresh B2C output owns Hammer end to end and one real POST path denies N+1 with generic 429/Retry-After. | generated source contract + fresh-host bounded request | `mix test test/sigra/install/generated_rate_limit_contract_test.exs test/sigra/plug/rate_limit_test.exs && scripts/ci/passkeys-opt-out-smoke.sh` | ❌ W0 (240-05) | ⬜ pending |
| 240-02-01 | 02 | 2 | OPS-01 | T-240-05 | Controller-IP and LiveView/context mail limits use independent keys and preserve non-enumerating outcomes. | generated source/context contract | `mix test test/sigra/install/generated_rate_limit_context_test.exs test/sigra/install/generated_rate_limit_contract_test.exs` | ❌ W0 (240-05) | ⬜ pending |
| 240-02-02 | 02 | 2 | OPS-01 | T-240-08 | Generated limiter output remains exact and idempotent. | installer golden + idempotency | `mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs` | ✅ | ⬜ pending |
| 240-03-01 | 03 | 2 | OPS-01, OPS-02 | T-240-09 | Recipe declares three evidence tiers, literal host tuple, redaction boundary, and staging-only provider/device proof. | documentation source contract | `mix test test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs && mix docs --warnings-as-errors` | ❌ W0 (240-05) | ⬜ pending |
| 240-04-01 | 04 | 2 | OPS-02 | T-240-13 | Fresh generator and loopback-OIDC runtime lanes remain independent, use no live credentials, reject inherited Google variables, and prove the exact local-only coverage declaration. | CI source contract + script syntax | `mix test test/sigra/planning/phase_240_no_secrets_ci_test.exs test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs && bash -n scripts/ci/passkeys-opt-out-smoke.sh scripts/ci/generated-auth-runtime-proof.sh` | ❌ W0 (240-05) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Wave 0 Plan `240-05-PLAN.md` creates every artifact below; Plans 01-04 depend on it directly.

- [ ] `test/sigra/install/generated_rate_limit_contract_test.exs` — generated ownership, threshold, Retry-After precision, and fresh-host tracer contract.
- [ ] `test/sigra/install/generated_rate_limit_context_test.exs` — complete flow map, independent prefixes/keys, and non-enumerating context outcomes.
- [ ] `test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs` — recipe tiers, literal tuple, host-only gates, redaction, and Doctor claim boundary.
- [ ] `test/sigra/planning/phase_240_no_secrets_ci_test.exs` — separate lane topology, disposable fixture labels, inherited Google unsetting, and negative credential/claim assertions.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real Google authorization, controlled-recipient confirmation/reset/magic-link delivery, and HTTPS hosted-browser return on a physical iPhone. | OPS-02 | Requires adopter-controlled credentials, provider tenancy, public TLS/proxy, and a physical device; CI must not contain those secrets or claim this proof. | Record an outcome-only, redacted host staging receipt for each required gate; exclude secrets, token-bearing URLs, mail bodies, and provider payloads. |

---

## Validation Sign-Off

- [ ] All tasks have automated verification or Wave 0 dependencies.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags or rate-window sleeps.
- [ ] Feedback latency < 60 seconds for targeted checks.
- [ ] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending
