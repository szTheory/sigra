---
phase: 240
slug: alpha-operations-rehearsal
status: draft
nyquist_compliant: false
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
| 240-01-01 | 01 | 1 | OPS-01 | T-240-01 | Generated B2C host owns an explicit rate limiter; sensitive controller and LiveView paths are bounded without enumeration leakage. | source contract + generated-host request | `mix test test/sigra/plug/rate_limit_test.exs test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs` | ❌ W0 | ⬜ pending |
| 240-02-01 | 02 | 2 | OPS-01 | T-240-02 | Recipe declares three evidence tiers, host tuple, redaction boundary, and staging-only provider/device proof. | source contract | `mix test test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs` | ❌ W0 | ⬜ pending |
| 240-03-01 | 03 | 2 | OPS-02 | T-240-03 | Fresh generator and loopback-OIDC runtime lanes use no live credentials and reject inherited Google variables. | source contract + script proof | `mix test test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs` — recipe/claim vocabulary, generated limiter ownership, and negative credential assertions.
- [ ] Disposable generated-host request test or probe — bounded exhaustion and distinct limiter prefixes without sleeps or rate-window waits.
- [ ] Contract coverage that marks fixed Cloak/OIDC values as fixtures and rejects live Google, mail, deployment, and GitHub-secret injection.

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
