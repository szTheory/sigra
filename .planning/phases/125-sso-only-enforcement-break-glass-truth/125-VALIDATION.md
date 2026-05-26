---
phase: 125
slug: sso-only-enforcement-break-glass-truth
status: passed
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-26
updated: 2026-05-26
requirements: [ENF-01]
---

# Phase 125 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit in two lanes: root library tests plus the `test/example` Phoenix app test harness |
| **Config file** | `test/test_helper.exs` and `test/example/test/test_helper.exs` |
| **Quick run command** | `mix test test/sigra/auth_org_selection_test.exs` for root auth/session work, or `cd test/example && mix test --include example_app test/example_web/controllers/session_controller_test.exs` for generated-host work |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` and `cd test/example && MIX_ENV=test mix test --include example_app` |
| **Estimated runtime** | ~90 seconds |

---

## Sampling Rate

- **After every task commit:** Run the smallest touched-lane smoke test plus any new policy-specific file created in that lane.
- **After every plan wave:** Run all touched root-library tests and all touched `test/example` tests with `--include example_app`.
- **Before `$gsd-verify-work`:** Full root suite and full example-app suite must both be green.
- **Max feedback latency:** 30 seconds for task-level smoke lanes; ~90 seconds only for full-suite gates.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 125-01-01 | 01 | 1 | ENF-01 | T-125-01 / T-125-02 | Org-owned policy and explicit break-glass exemptions cannot be confused with enterprise connection state or membership role | unit/liveview | `cd test/example && mix test --include example_app test/example_web/live/organization_settings_live_test.exs` | ✅ planned | ⬜ pending |
| 125-02-01 | 02 | 2 | ENF-01 | T-125-03 / T-125-04 | Non-exempt password logins are denied before `auth.login.success` and before any session is created | unit/integration | `mix test test/sigra/auth_org_selection_test.exs test/sigra/auth_test.exs` | ✅ planned | ⬜ pending |
| 125-02-02 | 02 | 2 | ENF-01 | T-125-05 / T-125-06 | Password-reset request and completion remain available only for explicit break-glass users under SSO-only enforcement | unit/integration | `mix test test/sigra/auth_test.exs` | ✅ planned | ⬜ pending |
| 125-03-01 | 03 | 3 | ENF-01 | T-125-07 / T-125-08 | Generated-host login and recovery surfaces route denied users back to enterprise sign-in, keep exempt users on password-only recovery, and avoid passkey/magic-link bypasses | controller/integration | `cd test/example && mix test --include example_app test/example_web/controllers/session_controller_test.exs test/example_web/controllers/enterprise_sso_controller_test.exs` | ✅ planned | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Add root-library tests covering SSO-only allow/deny decisions, no `session.create` on denial, and typed audit metadata for denied password auth.
- [ ] Add root-library tests covering password-reset request/reset gating for exempt vs non-exempt users.
- [ ] Add `test/example` live-view coverage for organization settings enterprise policy controls and break-glass safety rails.
- [ ] Update example controller tests to prove denied local auth returns to enterprise sign-in and exempt users still have password recovery.
- [ ] Ensure every example-app verification command includes `--include example_app`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Operator legibility of the enterprise settings page when connection state and SSO-only policy state coexist | ENF-01 | Rendered UX review is needed to confirm the policy is clearly distinct from connection validation/activation state | Start the example app, open organization settings, and verify the page distinguishes connection status, SSO-only enablement, and explicit break-glass membership without implying hidden local-auth fallback |
| Denied-user recovery copy on login/reset surfaces | ENF-01 | Copy must be truthful and bounded without leaking account details or suggesting unsupported auth methods | Trigger one denied password login and one denied reset flow for a non-exempt user, then confirm the UI points to enterprise sign-in and does not advertise magic-link or passkey as break-glass |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s for per-task smoke lanes
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** passed on 2026-05-26 after current-head root, example-host, and installer reruns.
