---
phase: 123
slug: org-aware-enterprise-routing
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-25
---

# Phase 123 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit in two lanes: root library tests plus the `test/example` Phoenix app test harness |
| **Config file** | `test/test_helper.exs` and `test/example/test/test_helper.exs` |
| **Quick run command** | `mix test test/sigra/enterprise_connections/context_test.exs test/sigra/enterprise_connections/activation_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test && (cd test/example && mix test)` |
| **Estimated runtime** | ~90 seconds |

---

## Sampling Rate

- **After every task commit:** Run the smallest touched-lane command (`mix test ...` for library changes, `cd test/example && mix test ...` for generated-host changes)
- **After every plan wave:** Run both the new library routing tests and the new example-app routing/callback tests
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 123-01-01 | 01 | 1 | SSO-03 | T-123-01/T-123-02 | Generic discovery only auto-routes on one exact verified unique domain match, and enterprise authorize binds the resolved org tuple into signed state plus mirrored session context | unit/integration | `mix test test/sigra/enterprise_routing/discovery_test.exs test/sigra/oauth/oauth_test.exs` | ✅ planned | ⬜ pending |
| 123-01-02 | 01 | 1 | SSO-03 | T-123-03/T-123-04 | Callback revalidates bound `organization_id`, `connection_id`, and `routing_source` before session creation and preserves first-session org truth | integration | `mix test test/sigra/oauth/enterprise_callback_test.exs test/sigra/auth_org_selection_test.exs` | ✅ planned | ⬜ pending |
| 123-02-01 | 02 | 2 | SSO-03 | T-123-06/T-123-07 | Template-owned login and enterprise controller surfaces expose bounded discovery and canonical org entry before OIDC | installer feature | `mix test test/sigra/install/features/organizations_test.exs` | ✅ planned | ⬜ pending |
| 123-03-01 | 03 | 3 | SSO-03 | T-123-10/T-123-11 | Example-app controller flow redirects generic discovery into `/organizations/:org/sso` and keeps enterprise retry handling in the same mode | controller | `(cd test/example && mix test test/example_web/controllers/session_controller_test.exs test/example_web/controllers/enterprise_sso_controller_test.exs)` | ✅ planned | ⬜ pending |
| 123-03-02 | 03 | 3 | SSO-03 | T-123-12 | Successful enterprise login preserves session org truth and shows correct org context on first authenticated request | example-app integration/smoke | `(cd test/example && mix test test/example_web/integration/enterprise_sso_routing_flow_test.exs)` | ✅ planned | ⬜ pending |
| 123-04-01 | 04 | 4 | SSO-03 | T-123-13/T-123-14 | Installer and golden coverage catch drift between generated templates and the committed example app | regression | `mix test test/sigra/install/features/organizations_test.exs test/sigra/install/golden_diff_test.exs` | ✅ planned | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/sigra/enterprise_routing/discovery_test.exs` - created by Plan `123-01` Task 1 for exact-match, duplicate-match, disabled or pending or wildcard rejection matrix
- [x] `test/sigra/oauth/enterprise_callback_test.exs` - created by Plan `123-01` Task 2 for signed-state plus session revalidation contract before session creation
- [x] `test/example/test/example_web/controllers/enterprise_sso_controller_test.exs` - created by Plan `123-03` Task 1 for explicit org entry and same-mode recovery UI and controller behavior
- [x] `test/example/test/example_web/integration/enterprise_sso_routing_flow_test.exs` - created by Plan `123-03` Task 2 for end-to-end org discovery to callback to hydrated scope proof

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Lightweight org-truth copy before redirect and on enterprise retry/error states | SSO-03 | Copy quality and disclosure boundaries are easier to assess in rendered browser output than a single string assertion | Start the example app, visit the generic enterprise entry and an org-scoped SSO route, trigger both success-path redirect and bounded failure states, and confirm the page names the explicit organization only after org context is known |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 90s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
