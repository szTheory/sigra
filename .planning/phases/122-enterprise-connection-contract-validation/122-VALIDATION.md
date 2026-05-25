---
phase: 122
slug: enterprise-connection-contract-validation
status: passed
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-25
updated: 2026-05-25
requirements: [SSO-01, SSO-02]
---

# Phase 122 — Validation Record

> Validation record for the enterprise connection model and truthful activation wedge.
> Phase 122 is complete because the planned Wave 0 enterprise-connection tests now exist and run green against the current head.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit plus generated-host/admin surface tests |
| **Config file** | `test/test_helper.exs` and `test/example/test/test_helper.exs` |
| **Focused lifecycle gate** | `mix test test/sigra/enterprise_connections/schema_test.exs test/sigra/enterprise_connections/context_test.exs test/sigra/enterprise_connections/validation_test.exs test/sigra/enterprise_connections/activation_test.exs test/sigra/oauth/assent_oidc_contract_test.exs` |
| **Operator/install gate** | `mix test --no-compile test/sigra/admin/live/enterprise_connection_live_test.exs test/sigra/install/features/organizations_test.exs test/sigra/install/golden_diff_test.exs` |
| **Observed runtime** | `8 tests, 0 failures` in ~0.3s for the focused lifecycle gate; `67 tests, 0 failures` in ~93.6s for the operator/install gate |

---

## Sampling Rate

- **After every task commit:** Run the smallest relevant `test/sigra/enterprise_connections/*` command plus the OIDC contract test when touching protocol validation.
- **After every plan wave:** Run the focused lifecycle gate, then the operator/install gate.
- **Before `$gsd-verify-work`:** Both gates must be green.
- **Max feedback latency:** ~1 second on warm `--no-compile` task-local checks; ~95 seconds for the full operator/install gate.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 122-01-01 | 01 | 1 | SSO-01 | T-122-01 / T-122-02 | Enterprise connection records stay organization-bound and reject invalid lifecycle transitions. | schema + context | `mix test test/sigra/enterprise_connections/schema_test.exs test/sigra/enterprise_connections/context_test.exs` | `test/sigra/enterprise_connections/schema_test.exs`, `test/sigra/enterprise_connections/context_test.exs` | ✅ green |
| 122-01-02 | 01 | 1 | SSO-01 | T-122-02 | OIDC discovery/client configuration validation accepts valid issuer settings and rejects malformed or incomplete inputs. | service/contract | `mix test test/sigra/enterprise_connections/validation_test.exs test/sigra/oauth/assent_oidc_contract_test.exs` | `test/sigra/enterprise_connections/validation_test.exs`, `test/sigra/oauth/assent_oidc_contract_test.exs` | ✅ green |
| 122-01-03 | 01 | 1 | SSO-02 | T-122-02 / T-122-03 | Activation fails closed when discovery, endpoints, redirect shape, or required client settings are unusable. | integration | `mix test test/sigra/enterprise_connections/activation_test.exs` | `test/sigra/enterprise_connections/activation_test.exs` | ✅ green |
| 122-02-01 | 02 | 2 | SSO-01 | T-122-01 / T-122-05 / T-122-06 | Generated-host/admin surface lets organization admins configure enterprise connections through the intended org-scoped page. | LiveView/template/install | `mix test --no-compile test/sigra/admin/live/enterprise_connection_live_test.exs test/sigra/install/features/organizations_test.exs` | `test/sigra/admin/live/enterprise_connection_live_test.exs`, `test/sigra/install/features/organizations_test.exs` | ✅ green |
| 122-02-02 | 02 | 2 | SSO-02 | T-122-02 / T-122-03 / T-122-05 / T-122-07 | Operator surface shows truthful draft / validation_failed / active status and never labels invalid settings as active. | LiveView/template/golden | `mix test --no-compile test/sigra/admin/live/enterprise_connection_live_test.exs test/sigra/install/golden_diff_test.exs` | `test/sigra/admin/live/enterprise_connection_live_test.exs`, `test/sigra/install/golden_diff_test.exs` | ✅ green |

*Status: ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/sigra/enterprise_connections/schema_test.exs` — schema and state-transition contract for the new enterprise connection model
- [x] `test/sigra/enterprise_connections/context_test.exs` — org-scoped CRUD/authorization contract
- [x] `test/sigra/enterprise_connections/validation_test.exs` — discovery and client-setting validation behavior
- [x] `test/sigra/enterprise_connections/activation_test.exs` — activation refusal / failure-truth contract
- [x] `test/sigra/admin/live/enterprise_connection_live_test.exs` — generated-host/admin surface truth contract

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None. | SSO-01, SSO-02 | All critical persistence, validation, activation, wrapper, and operator-truth behaviors are covered by automated ExUnit/install regression tests in the current head. | N/A |

---

## Validation Sign-Off

- [x] All planned tasks now have automated verification on the current head.
- [x] Sampling continuity: no three consecutive tasks should land without an automated verify command.
- [x] Wave 0 coverage exists for every enterprise-connection test reference that was planned.
- [x] No watch-mode flags.
- [x] Feedback latency is acceptable for both the focused lifecycle gate and the full operator/install gate.
- [x] `nyquist_compliant: true` and `wave_0_complete: true` match the completed verification record.

## Validation Audit 2026-05-25

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Notes:
- The only rerun issue during audit was a stale temp directory collision for `golden_diff_test`; clearing `/var/folders/f3/f0clj9rd2zb85n2c849wcsrc0000gn/T/sigra_golden_130` allowed the suite to pass without code changes.

**Approval:** passed as a truthful Nyquist map for enterprise connection persistence, validation, activation failure, and generated-host operator-surface behavior.
