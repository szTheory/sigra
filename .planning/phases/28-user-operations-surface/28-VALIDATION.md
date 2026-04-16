---
phase: 28
slug: user-operations-surface
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 28 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix LiveViewTest + Playwright |
| **Config file** | `test/test_helper.exs` and `test/example/test_helper.exs` |
| **Quick run command** | `cd test/example && mix test test/example_web/live/admin_user_index_live_test.exs test/example_web/live/admin_user_show_live_test.exs` |
| **Full suite command** | `cd test/example && mix test && npx playwright test --project=mobile` |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd test/example && mix test test/example_web/live/admin_user_index_live_test.exs test/example_web/live/admin_user_show_live_test.exs`
- **After every plan wave:** Run `cd test/example && mix test && npx playwright test --project=mobile`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 28-01-01 | 01 | 0 | USER-01 / USER-02 | T-28-01 | Query params stay validated and org scope is applied before filter execution | LiveView | `cd test/example && mix test test/example_web/live/admin_user_index_live_test.exs` | ❌ W0 | ⬜ pending |
| 28-02-01 | 02 | 0 | USER-03 | T-28-02 | Detail page loads only scope-allowed data and hides unsupported identity data safely | LiveView + integration | `cd test/example && mix test test/example_web/live/admin_user_show_live_test.exs` | ❌ W0 | ⬜ pending |
| 28-03-01 | 03 | 0 | USER-04 | T-28-03 | Revoke-one and revoke-all actions confirm target scope and route through canonical Sigra auth APIs | LiveView + integration | `cd test/example && mix test test/example_web/live/admin_user_show_live_test.exs --only revoke` | ❌ W0 | ⬜ pending |
| 28-04-01 | 04 | 0 | USER-05 | T-28-04 | Mobile layout preserves search, open-user flow, and session actions without desktop-only overflow patterns | Playwright mobile | `cd test/example && npx playwright test tests/admin-user-operations-mobile.spec.ts --project=mobile` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/example/test/example_web/live/admin_user_index_live_test.exs` — list, search, filter, pagination, and scope coverage for USER-01 and USER-02
- [ ] `test/example/test/example_web/live/admin_user_show_live_test.exs` — detail, sessions, security summary, and revocation coverage for USER-03 and USER-04
- [ ] `test/example/tests/admin-user-operations-mobile.spec.ts` — mobile smoke covering USER-05

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
