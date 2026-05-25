---
phase: 122
slug: enterprise-connection-contract-validation
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-25
---

# Phase 122 — Validation Strategy

> Per-phase validation contract for the enterprise connection model and truthful activation wedge.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit plus generated-host/admin surface tests |
| **Config file** | `test/test_helper.exs` and `test/example/test/test_helper.exs` |
| **Quick run command** | `mix test test/sigra/oauth/assent_oidc_contract_test.exs test/sigra/enterprise_connections/schema_test.exs --max-cases 1` |
| **Full suite command** | `mix test test/sigra/oauth/assent_oidc_contract_test.exs test/sigra/oauth/config_test.exs test/sigra/oauth/strategies_test.exs test/sigra/organizations/context_test.exs test/sigra/organizations/schema_test.exs test/sigra/admin/live/organization_live_test.exs test/sigra/enterprise_connections/context_test.exs test/sigra/enterprise_connections/schema_test.exs test/sigra/enterprise_connections/validation_test.exs test/sigra/enterprise_connections/activation_test.exs test/sigra/admin/live/enterprise_connection_live_test.exs` |
| **Estimated runtime** | ~25 seconds quick path, ~90 seconds full suite once Wave 0 tests exist |

---

## Sampling Rate

- **After every task commit:** Run the smallest relevant `test/sigra/enterprise_connections/*` command plus the existing OIDC contract test when touching protocol validation.
- **After every plan wave:** Run the full enterprise-connection suite and the generated-host/admin surface tests.
- **Before `$gsd-verify-work`:** Full suite must be green.
- **Max feedback latency:** 25 seconds for task-local verification, 90 seconds for wave gates.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 122-01-01 | 01 | 1 | SSO-01 | T-122-01 / T-122-02 | Enterprise connection records stay organization-bound and reject invalid lifecycle transitions. | schema + context | `mix test test/sigra/enterprise_connections/schema_test.exs test/sigra/enterprise_connections/context_test.exs` | ❌ W0 | ⬜ pending |
| 122-01-02 | 01 | 1 | SSO-01 | T-122-02 | OIDC discovery/client configuration validation accepts valid issuer settings and rejects malformed or incomplete inputs. | service/contract | `mix test test/sigra/enterprise_connections/validation_test.exs test/sigra/oauth/assent_oidc_contract_test.exs` | ❌ W0 / ✅ existing OIDC contract | ⬜ pending |
| 122-01-03 | 01 | 1 | SSO-02 | T-122-02 / T-122-03 | Activation fails closed when discovery, endpoints, redirect shape, or required client settings are unusable. | integration | `mix test test/sigra/enterprise_connections/activation_test.exs` | ❌ W0 | ⬜ pending |
| 122-02-01 | 02 | 2 | SSO-01 | T-122-01 | Generated-host/admin surface lets organization admins configure enterprise connections through the intended org-scoped page. | LiveView/controller | `mix test test/sigra/admin/live/enterprise_connection_live_test.exs` | ❌ W0 | ⬜ pending |
| 122-02-02 | 02 | 2 | SSO-02 | T-122-02 / T-122-03 | Operator surface shows truthful draft / validation_failed / active status and never labels invalid settings as active. | LiveView/controller/template | `mix test test/sigra/admin/live/enterprise_connection_live_test.exs test/sigra/oauth/oauth_settings_template_contract_test.exs` | ❌ W0 / ✅ existing template precedent | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/enterprise_connections/schema_test.exs` — schema and state-transition contract for the new enterprise connection model
- [ ] `test/sigra/enterprise_connections/context_test.exs` — org-scoped CRUD/authorization contract
- [ ] `test/sigra/enterprise_connections/validation_test.exs` — discovery and client-setting validation behavior
- [ ] `test/sigra/enterprise_connections/activation_test.exs` — activation refusal / failure-truth contract
- [ ] `test/sigra/admin/live/enterprise_connection_live_test.exs` — generated-host/admin surface truth contract

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None expected if the generated-host/admin surface gets direct test coverage. | SSO-01, SSO-02 | The phase is intentionally bounded to persistence, validation, and operator truth; all critical behaviors should be automatable. | N/A |

---

## Validation Sign-Off

- [x] All planned tasks have automated verification or explicit Wave 0 dependencies.
- [x] Sampling continuity: no three consecutive tasks should land without an automated verify command.
- [x] Wave 0 covers all missing enterprise-connection test references.
- [x] No watch-mode flags.
- [x] Feedback latency target remains under 90 seconds once Wave 0 is added.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending
