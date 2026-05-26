---
phase: 126
slug: generated-host-proof-diagnostics-docs
status: passed
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-26
updated: 2026-05-26
requirements: [OPS-01]
---

# Phase 126 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, Phoenix ConnTest/integration, installer template assertions, Playwright, grep gates |
| **Config file** | `test/test_helper.exs`, `test/example/test/test_helper.exs`, `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `mix test test/sigra/enterprise_connections/validation_test.exs test/sigra/enterprise_connections/activation_test.exs test/sigra/enterprise_routing/discovery_test.exs test/sigra/oauth/enterprise_callback_test.exs test/sigra/oauth/enterprise_reconciliation_test.exs test/sigra/auth_test.exs test/sigra/auth/login_and_lockout_audit_atomicity_test.exs && cd test/example && MIX_ENV=test mix test --include example_app test/example_web/integration/enterprise_sso_routing_flow_test.exs test/example_web/integration/enterprise_sso_reconciliation_flow_test.exs test/example_web/controllers/session_controller_test.exs` |
| **Full suite command** | `mix test test/sigra/enterprise_connections/validation_test.exs test/sigra/enterprise_connections/activation_test.exs test/sigra/enterprise_routing/discovery_test.exs test/sigra/oauth/enterprise_callback_test.exs test/sigra/oauth/enterprise_reconciliation_test.exs test/sigra/auth_test.exs test/sigra/auth/login_and_lockout_audit_atomicity_test.exs test/sigra/install/features/organizations_test.exs test/sigra/admin/live/enterprise_connection_live_test.exs && cd test/example && MIX_ENV=test mix test --include example_app test/example_web/integration/enterprise_sso_routing_flow_test.exs test/example_web/integration/enterprise_sso_reconciliation_flow_test.exs test/example_web/controllers/session_controller_test.exs test/example_web/live/organization_settings_live_test.exs && cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/admin-generated.spec.ts --project=chromium && rg -n "enterprise|SSO-only|break-glass|SCIM|hosted control plane|opinionated authz|Proved|Did Not Prove" guides/flows/oauth.md docs/uat-ci-coverage.md .planning/phases/126-generated-host-proof-diagnostics-docs/126-VERIFICATION.md` |
| **Estimated runtime** | ~180 seconds |

---

## Sampling Rate

- **After every task commit:** Run the smallest task-local command from the plan.
- **After every plan wave:** Run the full suite command for all completed waves.
- **Before `$gsd-verify-work`:** Full suite must be green.
- **Max feedback latency:** 180 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 126-01-01 | 01 | 1 | OPS-01 | T-126-01 / T-126-02 | Setup, routing, reconciliation, and enforcement each map to bounded machine-readable enterprise outcomes. | unit | `mix test test/sigra/enterprise_connections/validation_test.exs test/sigra/enterprise_connections/activation_test.exs test/sigra/enterprise_routing/discovery_test.exs test/sigra/oauth/enterprise_callback_test.exs test/sigra/oauth/enterprise_reconciliation_test.exs test/sigra/auth_test.exs test/sigra/auth/login_and_lockout_audit_atomicity_test.exs` | ✅ | ⬜ pending |
| 126-01-02 | 01 | 1 | OPS-01 | T-126-03 | Root proof and audit assertions show representative stage failures without inventing a new telemetry surface. | unit | `mix test test/sigra/oauth/enterprise_callback_test.exs test/sigra/oauth/enterprise_reconciliation_test.exs test/sigra/auth/login_and_lockout_audit_atomicity_test.exs` | ✅ | ⬜ pending |
| 126-02-01 | 02 | 2 | OPS-01 | T-126-04 / T-126-05 | Example-host happy path proves canonical org entry, callback landing, and organization truth. | integration | `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/integration/enterprise_sso_routing_flow_test.exs test/example_web/integration/enterprise_sso_reconciliation_flow_test.exs` | ✅ | ⬜ pending |
| 126-02-02 | 02 | 2 | OPS-01 | T-126-06 | Representative denied-path behavior remains truthful and routes users back to enterprise sign-in without false success. | controller + liveview | `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/controllers/session_controller_test.exs test/example_web/live/organization_settings_live_test.exs` | ✅ | ⬜ pending |
| 126-02-03 | 02 | 2 | OPS-01 | T-126-07 | One bounded browser lane proves generated-host enterprise wiring on real served routes. | browser | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/admin-generated.spec.ts --project=chromium` | ✅ | ⬜ pending |
| 126-03-01 | 03 | 3 | OPS-01 | T-126-08 | Installer output stays aligned with example/generated-host enterprise surfaces. | installer | `mix test test/sigra/install/features/organizations_test.exs test/sigra/admin/live/enterprise_connection_live_test.exs` | ✅ | ⬜ pending |
| 126-03-02 | 03 | 3 | OPS-01 | T-126-09 | Canonical docs state bounded enterprise scope, troubleshooting stages, and non-goals explicitly. | docs/grep | `rg -n "Enterprise sign-in|setup|routing|reconciliation|enforcement|SCIM|hosted control plane|opinionated authz" guides/flows/oauth.md docs/uat-ci-coverage.md` | ✅ | ⬜ pending |
| 126-04-01 | 04 | 4 | OPS-01 | T-126-10 | Phase-local verification artifact records exact evidence and Proved / Did Not Prove boundaries. | docs/grep | `rg -n "Proved|Did Not Prove|OPS-01|generated-host|enterprise" .planning/phases/126-generated-host-proof-diagnostics-docs/126-VERIFICATION.md` | ❌ W0 | ⬜ pending |
| 126-04-02 | 04 | 4 | OPS-01 | T-126-11 | Active planning truth points maintainers to the authoritative closeout surface without widening milestone claims. | docs/grep | `rg -n "Phase 126|OPS-01|generated-host proof|enterprise docs" .planning/PROJECT.md .planning/STATE.md .planning/ROADMAP.md docs/uat-ci-coverage.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or existing test infrastructure
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references through existing test lanes
- [x] No watch-mode flags
- [x] Feedback latency < 180s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** passed on 2026-05-26 after current-head proof reruns and fixture reconciliation.
