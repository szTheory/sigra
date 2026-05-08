---
phase: 104
slug: failed-delivery-replay-controls
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-07
---

# Phase 104 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `104-CONTEXT.md`, `104-RESEARCH.md`, and the executable plan set.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, Phoenix LiveViewTest, generator fixture assertions, Playwright |
| **Config file** | `test/test_helper.exs`, `config/test.exs`, `test/example/mix.exs`, `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_replay_test.exs test/sigra/admin/webhooks_test.exs --no-color` |
| **Wave merge smoke** | `MIX_ENV=test mix compile --warnings-as-errors && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_replay_test.exs test/sigra/webhooks_integration_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/admin/webhooks_test.exs test/sigra/install/generator_wiring_test.exs test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs test/example/test/example_web/live/admin_webhook_failures_live_test.exs test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs --no-color` |
| **Full suite command** | `MIX_ENV=test mix compile --warnings-as-errors && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_replay_test.exs test/sigra/webhooks_integration_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/admin/webhooks_test.exs test/sigra/install/generator_wiring_test.exs test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs test/example/test/example_web/live/admin_webhook_failures_live_test.exs test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs test/example/test/example_web/controllers/sigra_webhook_controller_test.exs test/example/test/example_web/accounts_webhook_proof_test.exs --no-color && cd test/example/priv/playwright && EXAMPLE_DB_PROBE_ENABLED=1 CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= npx playwright test tests/admin-generated.spec.ts --project=admin-generated` |
| **Estimated runtime** | ~30-60 seconds quick loop, ~90-180 seconds focused full phase gate including browser proof |

---

## Sampling Rate

- **After every task commit:** Run the task-level automated verify command from the touched plan.
- **After Plan 01 / wave 1:** Run `MIX_ENV=test mix compile --warnings-as-errors && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_replay_test.exs test/sigra/webhooks_integration_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/install/generator_wiring_test.exs --no-color`.
- **After Plan 02 / wave 2:** Run `MIX_ENV=test mix compile --warnings-as-errors && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs test/sigra/install/generator_wiring_test.exs --no-color`.
- **After Plan 03 / wave 3:** Run the wave merge smoke command above.
- **Before `$gsd-verify-work`:** Run the full suite command and confirm the replay evidence bundle exists under `.planning/uat-evidence/v1.23/webhook-delivery-replay/`.
- **Max feedback latency:** ~60 seconds for focused library/admin loops, ~180 seconds for the focused full phase gate including Playwright.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 104-01-01 | 01 | 1 | WH-05 | Library regressions prove replay creates a fresh child delivery, preserves immutable source truth, rejects unsafe states, and keeps child attempts scoped to the new row | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_replay_test.exs test/sigra/webhooks_integration_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/install/generator_wiring_test.exs --no-color` | ✅ extend/create | ⬜ pending |
| 104-01-02 | 01 | 1 | WH-05 | Replay persistence adds lineage metadata, durable duplicate-child prevention, and transaction-owned enqueue with stable reason atoms | integration | `MIX_ENV=test mix compile --warnings-as-errors && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_replay_test.exs test/sigra/webhooks_integration_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/install/generator_wiring_test.exs --no-color` | ✅ extend/create | ⬜ pending |
| 104-02-01 | 02 | 2 | WH-05 | Admin wrappers authorize once, delivery/failures read models expose truthful replay lineage and eligibility, and generated-host wrapper parity stays aligned | integration | `CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs test/sigra/install/generator_wiring_test.exs --no-color` | ✅ extend | ⬜ pending |
| 104-02-02 | 02 | 2 | WH-05 | Admin/read-model implementation keeps replay library-owned, exposes authoritative lineage maps, and preserves failures inbox as delivery-row truth | integration | `MIX_ENV=test mix compile --warnings-as-errors && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs test/sigra/install/generator_wiring_test.exs --no-color` | ✅ extend | ⬜ pending |
| 104-03-01 | 03 | 3 | WH-05 | LiveView regressions prove delivery detail owns replay confirmation and lineage truth, failures shortcut stays narrow, and subscription detail remains context-only | integration | `CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs test/example/test/example_web/live/admin_webhook_failures_live_test.exs test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs --no-color` | ✅ extend | ⬜ pending |
| 104-03-02 | 03 | 3 | WH-05 | LiveView implementation keeps replay lineage separate from attempt history and maps stable replay reason atoms into explicit operator copy | integration | `MIX_ENV=test mix compile --warnings-as-errors && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs test/example/test/example_web/live/admin_webhook_failures_live_test.exs test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs --no-color` | ✅ extend | ⬜ pending |
| 104-04-01 | 04 | 4 | WH-05 | Example-host proof seam preserves receiver verification and `delivery_id` dedupe while correlating source and replay child deliveries | integration | `CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example/test/example_web/controllers/sigra_webhook_controller_test.exs test/example/test/example_web/accounts_webhook_proof_test.exs --no-color` | ✅ extend | ⬜ pending |
| 104-04-02 | 04 | 4 | WH-05 | Docs and browser proof demonstrate fail -> inspect -> repair -> replay -> succeed with durable evidence keyed by source and replay child delivery ids | browser/integration | `MIX_ENV=test mix compile --warnings-as-errors && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example/test/example_web/controllers/sigra_webhook_controller_test.exs test/example/test/example_web/accounts_webhook_proof_test.exs --no-color && cd test/example/priv/playwright && EXAMPLE_DB_PROBE_ENABLED=1 CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= npx playwright test tests/admin-generated.spec.ts --project=admin-generated && cd /Users/jon/projects/sigra && test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/README.md && test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json && rg -n '"source_delivery_id"|"replay_delivery_id"|"root_delivery_id"|"receiver_verification"|"screenshots"' .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json && rg -n "source delivery id|replay delivery id|root delivery id|receiver verification|screenshot" .planning/uat-evidence/v1.23/webhook-delivery-replay/README.md` | ✅ extend | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| WH-05 | Eligible dead-lettered deliveries replay into a fresh child row with immutable source truth, explicit lineage metadata, and durable duplicate prevention | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_replay_test.exs test/sigra/webhooks_integration_test.exs test/sigra/workers/webhook_delivery_test.exs --no-color` | ✅ extend/create |
| WH-05 | Admin runtime surfaces expose replay authorization, eligibility, lineage, and state-specific errors without moving policy into LiveView | integration | `CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs test/example/test/example_web/live/admin_webhook_failures_live_test.exs test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs --no-color` | ✅ extend |
| WH-05 | Published guidance and proof preserve the receiver contract: replay child gets a fresh `delivery_id`, while receiver dedupe remains keyed on `delivery_id` | browser/integration | `CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example/test/example_web/controllers/sigra_webhook_controller_test.exs test/example/test/example_web/accounts_webhook_proof_test.exs --no-color && cd test/example/priv/playwright && EXAMPLE_DB_PROBE_ENABLED=1 CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= npx playwright test tests/admin-generated.spec.ts --project=admin-generated && cd /Users/jon/projects/sigra && rg -n '"source_delivery_id"|"replay_delivery_id"|"root_delivery_id"|"receiver_verification"|"screenshots"' .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json` | ✅ extend |

---

## Wave 0 Requirements

No separate Wave 0 scaffold is required. The phase extends existing Sigra library, admin, generated-host, and Playwright proof infrastructure, and each plan begins with runnable automated verification in existing or explicitly-created test files.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Replay copy on delivery detail and failures cards communicates blocked states clearly without implying queue internals or hidden history | WH-05 | Product-language clarity is easier to judge in rendered UI than from string assertions alone | Open the example admin delivery detail and failures inbox for eligible, blocked, and already-replayed rows; confirm the copy explains why replay is allowed or blocked and that lineage is rendered separately from the attempt timeline. |

---

## Validation Sign-Off

- [x] All tasks have runnable automated verify commands
- [x] Sampling continuity: no 3 consecutive tasks without automated verification
- [x] No standalone Wave 0 scaffold remains
- [x] No watch-mode flags
- [x] Evidence bundle gate is explicit for the replay proof lane
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
