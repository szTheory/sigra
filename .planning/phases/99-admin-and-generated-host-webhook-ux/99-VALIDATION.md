---
phase: 99
slug: admin-and-generated-host-webhook-ux
status: completed
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-06
---

# Phase 99 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit on Elixir `1.19.5` plus Example `Phoenix.LiveViewTest`; Playwright `@playwright/test ^1.48.0` for browser parity |
| **Config file** | `test/test_helper.exs`; `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/admin/webhooks_test.exs --no-color` |
| **Wave merge smoke** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/admin/webhooks_test.exs test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs test/example/test/example_web/live/admin_webhook_failures_live_test.exs test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs --no-color && mix test test/sigra/install/generator_wiring_test.exs test/sigra/install/golden_diff_test.exs --no-color` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test && cd test/example/priv/playwright && npx playwright test tests/admin-generated.spec.ts --project=admin-generated` |
| **Estimated runtime** | ~180 seconds |

---

## Sampling Rate

- **After every task commit:** Run the targeted ExUnit file for the touched LiveView, query, or action module plus any affected generator test.
- **After every plan wave:** Run the wave-merge smoke lane for admin library tests, Example LiveView tests, and generator parity checks.
- **Before `$gsd-verify-work`:** Full suite must be green.
- **Max feedback latency:** 60 seconds for wave smoke, 180 seconds reserved for the final phase gate

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 99-01-01 | 01 | 1 | WH-03 | T-99-01 / T-99-02 / T-99-03 | Library-owned admin query/action tests lock summary-first reads, explicit event lists, and intentional secret handling before implementation | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/admin/webhooks_test.exs --no-color` | ✅ created in task | ✅ green |
| 99-02-01 | 02 | 2 | WH-03 | T-99-04 / T-99-05 / T-99-06 | Subscription index/detail LiveViews stay URL-driven, preserve explicit event scopes, and reveal secrets only through explicit detail-page actions | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs --no-color` | ✅ created in task | ✅ green |
| 99-03-01 | 03 | 2 | WH-03 | T-99-07 / T-99-08 / T-99-09 | Failures inbox and shared delivery detail remain summary-first, sanitize `return_to`, and avoid queue-internals drift | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example/test/example_web/live/admin_webhook_failures_live_test.exs test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs --no-color` | ✅ created in task | ✅ green |
| 99-04-01 | 04 | 3 | WH-03 | T-99-10 / T-99-11 | Generated-host router and admin shell expose only the supported global webhook pages and stay in parity across template/example/golden outputs | integration | `mix test test/sigra/install/generator_wiring_test.exs test/sigra/install/golden_diff_test.exs --no-color` | ✅ existing files | ✅ green |
| 99-05-01 | 05 | 4 | WH-03 | T-99-12 / T-99-13 / T-99-14 | Generated receiver setup docs and browser parity prove the real adopter path with host-owned verification guidance and no synthetic webhook semantics | browser smoke | `mix test test/sigra/install/generator_wiring_test.exs test/sigra/install/golden_diff_test.exs --no-color && cd test/example/priv/playwright && npx playwright test tests/admin-generated.spec.ts --project=admin-generated` | ✅ existing spec and generated fixture paths | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

No separate Wave 0 scaffold is required after revision. Each first task now creates its test file and ends with a runnable automated command in the same task, satisfying the Nyquist contract without an extra bootstrap plan.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Receiver setup copy stays contractual and does not imply unsupported replay, ping, wildcard, or dual-secret overlap semantics | WH-03 | Product-language accuracy is easier to judge from rendered copy than from a single assertion string | Open the subscription detail page in the example app, review setup and rotation callouts, and confirm they mention raw-body verification, `delivery_id` dedupe, and immediate sender-side secret replacement without overlap |

---

## Validation Sign-Off

- [x] All tasks have runnable `<automated>` verify commands
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] No standalone Wave 0 scaffold remains
- [x] No watch-mode flags
- [x] Feedback latency < 60s for wave smoke
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved

## Validation Audit 2026-05-06

| Metric | Count |
|--------|-------|
| Gaps found | 2 |
| Resolved | 2 |
| Escalated | 0 |

### Evidence

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs --no-color`
- `CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs test/example/test/example_web/live/admin_webhook_failures_live_test.exs test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs --no-color`
- `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4000 EXAMPLE_DB_PROBE_ENABLED=1 SIGRA_PLATFORM_ADMIN_EMAIL=platform-admin+phase102@example.test SIGRA_ORG_ADMIN_EMAIL=org-admin+phase102@example.test SIGRA_IMPERSONATION_TARGET_EMAIL=impersonation-target+phase102@example.test npx playwright test tests/admin-generated.spec.ts --project=admin-generated`
  Result: `6 passed` after the Phase 101 filter repair and Phase 102 canonical-proof extension.

### Gaps Resolved

- Phase 101 repaired the subscription-index and failures-inbox delivery-state truth defects that left Phase 99's operator views misleading.
- Phase 102 extended the generated-host proof from partial navigation coverage into a real `create subscription -> trigger user.created -> inspect delivery history` adopter path with durable correlated evidence.
