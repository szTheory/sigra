---
phase: 28
slug: user-operations-surface
status: complete
nyquist_compliant: true
wave_0_complete: true
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
| **Quick run command** | `cd test/example && mix test test/example_web/live/admin_user_index_live_test.exs test/example_web/live/admin_user_show_live_test.exs --max-failures 1 && cd priv/playwright && npx playwright test tests/admin-user-operations.spec.ts --project=mobile --grep @smoke` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test && cd test/example && mix test && cd priv/playwright && npx playwright test tests/admin-user-operations.spec.ts --project=mobile --project=chromium` |
| **Estimated runtime** | ~25 seconds quick / ~120 seconds full |

---

## Sampling Rate

- **After every task commit:** Run `cd test/example && mix test test/example_web/live/admin_user_index_live_test.exs test/example_web/live/admin_user_show_live_test.exs --max-failures 1` and, for browser-touching work, `cd test/example/priv/playwright && npx playwright test tests/admin-user-operations.spec.ts --project=mobile --grep @smoke`
- **After every plan wave:** Run `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test && cd test/example && mix test && cd priv/playwright && npx playwright test tests/admin-user-operations.spec.ts --project=mobile --project=chromium`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 25 seconds for task checks, ~120 seconds for wave gates

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 28-01-01 | 01 | 1 | USER-01 / USER-02 | T-28-01 | Dependency and hook contract compile cleanly before any user-list runtime code is added | compile | `mix deps.get && mix compile` | n/a | ✅ green |
| 28-01-02 | 01 | 1 | USER-01 / USER-02 | T-28-02 | Example app exposes a concrete display-name source and host hook provider for admin-user resolution | example compile | `cd test/example && mix ecto.migrate && mix compile` | n/a | ✅ green |
| 28-02-01 | 02 | 2 | USER-01 / USER-02 | T-28-04 / T-28-05 | Search, organization-membership lookup, filters, sort, and pagination stay scope-safe and URL-addressable | library | `mix test test/sigra/admin/users_query_test.exs --max-failures 1` | n/a | ✅ green |
| 28-02-02 | 02 | 2 | USER-01 / USER-02 / USER-05 | T-28-05 / T-28-06 | List UI preserves quick filters, more-filters controls, and mobile/desktop parity over the same query contract | LiveView | `cd test/example && mix test test/example_web/live/admin_user_index_live_test.exs test/example_web/live/admin_user_filters_live_test.exs --max-failures 1` | n/a | ✅ green |
| 28-03-01 | 03 | 3 | USER-03 / USER-04 | T-28-07 / T-28-08 | Detail assembler and session actions stay scope-safe, use canonical revoke APIs, and prove audit emission for revoke actions | library | `mix test test/sigra/admin/users_actions_test.exs --max-failures 1 && rg -n "audit|revoke_session|revoke_all_sessions" test/sigra/admin/users_actions_test.exs` | n/a | ✅ green |
| 28-03-02 | 03 | 3 | USER-03 / USER-04 | T-28-08 / T-28-09 | Detail LiveView preserves section order, return context, revoke UX, and global-to-org pivot behavior | LiveView | `cd test/example && mix test test/example_web/live/admin_user_show_live_test.exs --max-failures 1` | n/a | ✅ green |
| 28-04-01 | 04 | 4 | USER-05 | T-28-10 / T-28-11 | Mobile preserves the fast smoke path per task in the real browser flow | Playwright | `cd test/example/priv/playwright && npx playwright test tests/admin-user-operations.spec.ts --project=mobile --grep @smoke` | n/a | ✅ green |
| 28-04-02 | 04 | 4 | USER-05 | T-28-10 / T-28-12 | Wave gate proves both mobile and desktop browser behavior and finalizes the validation artifact | Playwright + docs | `cd test/example/priv/playwright && npx playwright test tests/admin-user-operations.spec.ts --project=mobile --project=chromium && cd /Users/jon/projects/sigra && rg -n "wave_0_complete: true|nyquist_compliant: true" .planning/phases/28-user-operations-surface/28-VALIDATION.md` | n/a | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/example/test/example_web/live/admin_user_index_live_test.exs` — list, search, filter, pagination, and scope coverage for USER-01 and USER-02
- [x] `test/example/test/example_web/live/admin_user_filters_live_test.exs` — operational filter and organization-membership lookup coverage for USER-01 and USER-02
- [x] `test/example/test/example_web/live/admin_user_show_live_test.exs` — detail, sessions, security summary, and revocation coverage for USER-03 and USER-04
- [x] `test/example/priv/playwright/tests/admin-user-operations.spec.ts` — mobile and desktop smoke covering USER-05

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency <= 25s for task checks and ~120s only at wave gates
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** complete
