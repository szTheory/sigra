---
phase: 124
slug: jit-provisioning-safe-reconciliation
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-25
---

# Phase 124 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit in two lanes: root library tests plus the `test/example` Phoenix app test harness |
| **Config file** | `test/test_helper.exs` and `test/example/test/test_helper.exs` |
| **Quick run command** | `mix test test/sigra/oauth/enterprise_callback_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` and `cd test/example && MIX_ENV=test mix test --include example_app` |
| **Estimated runtime** | ~90 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/oauth/enterprise_callback_test.exs` plus any new reconciliation-focused root test file touched by the task.
- **After every plan wave:** Run the relevant example-app controller and integration tests with `--include example_app` plus the touched root-library reconciliation tests.
- **Before `$gsd-verify-work`:** Full root suite and full example-app suite must both be green.
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 124-01-01 | 01 | 1 | JIT-01 | T-124-01 / T-124-02 | Enterprise reconciliation reuses existing identity, membership, and invitation substrate before any normal session is created | unit/integration | `mix test test/sigra/oauth/enterprise_callback_test.exs test/sigra/oauth/enterprise_reconciliation_test.exs` | ✅ planned | ⬜ pending |
| 124-01-02 | 01 | 1 | JIT-02 | T-124-03 / T-124-04 | Ambiguous or conflicting enterprise matches return typed refusal outcomes and create no normal signed-in session | unit/integration | `mix test test/sigra/oauth/enterprise_reconciliation_test.exs` | ✅ planned | ⬜ pending |
| 124-02-01 | 02 | 2 | SSO-04 | T-124-05 / T-124-06 | Successful enterprise login persists first-session `active_organization_id` truth and preserves enterprise routing context in session/audit metadata | integration | `mix test test/sigra/oauth/enterprise_callback_test.exs test/sigra/auth_org_selection_test.exs` | ✅ planned | ⬜ pending |
| 124-03-01 | 03 | 3 | SSO-04 | T-124-07 / T-124-08 | Example-app callback honors org-compatible `return_to`, otherwise falls back to `/organizations`, and unsafe outcomes do not redirect as success | controller/integration | `cd test/example && mix test --include example_app test/example_web/controllers/enterprise_sso_controller_test.exs test/example_web/integration/enterprise_sso_reconciliation_flow_test.exs` | ✅ planned | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/oauth/enterprise_reconciliation_test.exs` - cover exact existing-identity membership reuse, exact invite consumption, first-time JIT membership creation, duplicate-match refusal, and idempotent replay.
- [ ] `test/example/test/example_web/integration/enterprise_sso_reconciliation_flow_test.exs` - prove org-compatible `return_to`, `/organizations` fallback, and no session on unsafe outcomes.
- [ ] Update `test/example/test/example_web/controllers/enterprise_sso_controller_test.exs` - replace the current organization-settings redirect expectation with the Phase 124 redirect contract.
- [ ] Ensure all example-app verification commands include `--include example_app`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Lightweight success/fixup copy for first JIT membership creation, active-org switch, and bounded unsafe enterprise outcomes | SSO-04, JIT-02 | The copy needs a rendered-page review to confirm it is truthful, low-leak, and does not masquerade as a completed sign-in | Start the example app, run one happy-path enterprise login that creates or switches membership, then trigger one ambiguous or conflicting callback outcome and confirm the UI distinguishes success from bounded recovery without exposing sensitive internals |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 90s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
