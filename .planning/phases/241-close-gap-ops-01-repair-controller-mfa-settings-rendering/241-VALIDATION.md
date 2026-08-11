---
phase: 241
slug: close-gap-ops-01-repair-controller-mfa-settings-rendering
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-11
---

# Phase 241 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with the generated Phoenix `ConnCase` / `Phoenix.ConnTest` |
| **Config file** | Disposable generated host `config/test.exs` and `test/test_helper.exs` created by the existing smoke harness |
| **Quick run command** | `MIX_ENV=test mix test test/generated_mfa_settings_route_probe_test.exs` inside the generated controller host |
| **Full suite command** | `scripts/ci/passkeys-opt-out-smoke.sh` |
| **Estimated runtime** | ~120 seconds focused; ~15 minutes full smoke |

---

## Sampling Rate

- **After every task commit:** Run the task's focused source-contract or generated-host ExUnit command.
- **After every plan wave:** Run `scripts/ci/passkeys-opt-out-smoke.sh`.
- **Before `$gsd-verify-work`:** The complete four-leg smoke must be green.
- **Max feedback latency:** 15 minutes.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 241-01-01 | 01 | 1 | OPS-01 closure / D-01–D-02 | T-241-03 | Explicit `MFASettingsHTML` dispatch preserves the existing assign contract | source contract | `mix test test/sigra/install/generated_rate_limit_contract_test.exs` | ✅ extend existing | ⬜ pending |
| 241-01-02 | 01 | 1 | OPS-01 closure / D-03–D-06 | T-241-01 / T-241-02 | The authenticated connection's exact persisted session is sudo-fresh and the protected GET returns MFA HTML with status 200 | generated-host integration | `MIX_ENV=test mix test test/generated_mfa_settings_route_probe_test.exs` inside the generated controller host | ❌ W0 | ⬜ pending |
| 241-01-03 | 01 | 1 | D-04 / D-07–D-08 | — | Existing no-live and canonical LiveView lanes retain one readiness-driven, credential-free lifecycle | integration regression | `scripts/ci/passkeys-opt-out-smoke.sh` | ✅ extend existing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/generated_mfa_settings_route_probe_test.exs` in the disposable generated controller host — injected probe for authenticated, exact-session sudo-fresh MFA route rendering.
- [ ] Existing controller smoke wiring — create and run the probe within the established generated-host lifecycle, without fixed sleeps.

---

## Manual-Only Verifications

All phase behaviors have automated verification. Manual UAT is not an accepted substitute for the generated-host route proof.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15 minutes
- [ ] `nyquist_compliant: true` set in frontmatter after validation succeeds

**Approval:** pending
