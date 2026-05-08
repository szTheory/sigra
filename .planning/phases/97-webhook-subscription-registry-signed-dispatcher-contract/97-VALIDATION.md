---
phase: 97
slug: webhook-subscription-registry-signed-dispatcher-contract
status: completed
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-06
---

# Phase 97 — Validation Strategy

> Audited Nyquist validation record for the executed Phase 97 work.
> Derived from `97-0*-PLAN.md`, `97-0*-SUMMARY.md`, the checked-in tests/docs, and the 2026-05-06 verification run.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, install-golden fixtures, targeted grep/docs checks |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/sigra/webhooks_test.exs --max-failures 1 --no-color` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~20s for touched-module loop; ~120s full Postgres suite |

---

## Sampling Rate

- **After every task commit:** Run the touched-task command from the map below.
- **After wave 0 (`97-01`):** Run `MIX_ENV=test mix test test/sigra/webhooks_test.exs test/sigra/config_test.exs test/sigra/install/generator_wiring_test.exs --no-color && MIX_ENV=test mix compile --warnings-as-errors`.
- **After wave 1 (`97-02`):** Run `MIX_ENV=test mix test test/sigra/webhooks_payload_test.exs test/sigra/webhooks_event_catalog_test.exs --no-color && MIX_ENV=test mix compile --warnings-as-errors`.
- **After wave 2 (`97-03`):** Run `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_dispatcher_test.exs test/sigra/webhooks_audit_atomicity_test.exs --no-color`.
- **After wave 3 (`97-04`):** Run `MIX_ENV=test mix test test/sigra/webhooks_signature_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/install/features/core_post_instructions_test.exs --no-color`.
- **After wave 4 (`97-05`) / before `$gsd-verify-work`:** Run `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs test/sigra/install/generator_wiring_test.exs --no-color`, then grep the docs for the exact receiver contract.
- **Before `$gsd-verify-work`:** Full suite green on Postgres and `mix compile --warnings-as-errors`.
- **Max feedback latency:** ~20 seconds quick loop, ~120 seconds full suite.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 97-01-01 | 01 | 0 | WH-01 | T-97-01 | `:webhooks` config and optional-dep gating stay explicit and warning-clean | unit | `MIX_ENV=test mix test test/sigra/config_test.exs --no-color && MIX_ENV=test mix compile --warnings-as-errors` | ✅ yes | ✅ green |
| 97-01-02 | 01 | 0 | WH-01 | T-97-02 | Generated storage model exists for subscriptions, events, and deliveries with stable ids | fixture/grep | `rg -n "webhook_subscriptions|webhook_events|webhook_deliveries|webhook_delivery_attempts" test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_*.ex test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery_attempt.ex` | ✅ yes | ✅ green |
| 97-01-03 | 01 | 0 | WH-01 | T-97-03 / T-97-04 | Subscription CRUD persists explicit `event_types`, `enabled`, and endpoint policy semantics | unit | `MIX_ENV=test mix test test/sigra/webhooks_test.exs --no-color` | ✅ yes | ✅ green |
| 97-02-01 | 02 | 1 | WH-01 | T-97-05 | Public event catalog is curated and stable rather than audit-shaped | unit | `MIX_ENV=test mix test test/sigra/webhooks_event_catalog_test.exs --no-color` | ✅ yes | ✅ green |
| 97-02-02 | 02 | 1 | WH-01 | T-97-06 | Payload envelope and serializers expose only public contract fields | unit | `MIX_ENV=test mix test test/sigra/webhooks_payload_test.exs --no-color` | ✅ yes | ✅ green |
| 97-03-01 | 03 | 2 | WH-01 | T-97-07 / T-97-08 | Domain mutations persist one public event row plus per-subscription pending delivery rows before remote delivery | unit/integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_dispatcher_test.exs --no-color` | ✅ yes | ✅ green |
| 97-03-02 | 03 | 2 | WH-01 | T-97-09 | Persisted webhook state shares fate with the outer mutation when enabled | atomicity | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_audit_atomicity_test.exs --no-color` | ✅ yes | ✅ green |
| 97-04-01 | 04 | 3 | WH-01 | T-97-10 | Signature helper implements exact headers and canonical input with constant-time compare | unit | `MIX_ENV=test mix test test/sigra/webhooks_signature_test.exs --no-color` | ✅ yes | ✅ green |
| 97-04-02 | 04 | 3 | WH-01 | T-97-11 | Async worker seam is explicit and does not promise Phase 98 retry/dead-letter policy | unit | `MIX_ENV=test mix test test/sigra/workers/webhook_delivery_test.exs --no-color` | ✅ yes | ✅ green |
| 97-04-03 | 04 | 3 | WH-01 | T-97-12 | Install/runtime hints surface the async requirement honestly | unit/docs | `MIX_ENV=test mix test test/sigra/install/features/core_post_instructions_test.exs --no-color` | ✅ yes | ✅ green |
| 97-05-01 | 05 | 4 | WH-01 | T-97-13 | Receiver docs match the exact header, raw-body, and tolerance contract | docs/grep | `rg -n "Sigra-Webhook-|body_reader|secure_compare|delivery_id|event_id|schema_version" guides/flows/webhooks.md guides/recipes/webhook-verification.md` | ✅ yes | ✅ green |
| 97-05-02 | 05 | 4 | WH-01 | T-97-14 | Integration proof covers subscription creation through persisted event/delivery rows and worker-ready dispatch | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs --no-color` | ✅ yes | ✅ green |
| 97-05-03 | 05 | 4 | WH-01 | T-97-15 | Generated-host wrappers and fixture wiring remain coherent with the webhook surface | integration | `MIX_ENV=test mix test test/sigra/install/generator_wiring_test.exs --no-color` | ✅ yes | ✅ green |

*Status: ✅ green · ❌ red · ⚠️ flaky*

---

## Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| WH-01 | Host configures webhook subscriptions with explicit event scope, enabled state, and endpoint validation | unit | `MIX_ENV=test mix test test/sigra/webhooks_test.exs --no-color` | ✅ audited green |
| WH-01 | Public webhook payload envelope is stable and resource-oriented | unit | `MIX_ENV=test mix test test/sigra/webhooks_payload_test.exs test/sigra/webhooks_event_catalog_test.exs --no-color` | ✅ audited green |
| WH-01 | Domain mutations persist public event + per-subscription pending deliveries before remote delivery | unit/integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_dispatcher_test.exs test/sigra/webhooks_audit_atomicity_test.exs --no-color` | ✅ audited green |
| WH-01 | Signed async delivery seam is explicit and dependency-honest | unit | `MIX_ENV=test mix test test/sigra/webhooks_signature_test.exs test/sigra/workers/webhook_delivery_test.exs --no-color` | ✅ audited green |
| WH-01 | Receiver docs and integration proof match the implementation contract | docs + integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs --no-color && rg -n "Sigra-Webhook-|body_reader" guides/flows/webhooks.md guides/recipes/webhook-verification.md` | ✅ audited green |

---

## Wave 0 Requirements

- [x] `lib/sigra/webhooks.ex` exists with real subscription CRUD and validation APIs, not just scaffolding.
- [x] `test/sigra/webhooks_test.exs` exists and covers explicit `event_types`, `enabled`, and endpoint policy semantics.
- [x] `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs` exists.
- [x] Generated schemas for subscription/event/delivery/attempt rows exist under `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/`.
- [x] No new test framework is required beyond ExUnit/Postgres/install-golden patterns already present in the repo.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| _(none)_ | — | Phase 97 should be fully automatable; receiver proof is doc + integration based rather than human-witness based. | — |

*All planned Phase 97 behaviors have automated verification targets.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers the subscription CRUD gap plus new webhook file prerequisites
- [x] No watch-mode flags
- [x] Feedback latency < 20s for quick loop, < 120s for full suite
- [x] `nyquist_compliant: true` set in frontmatter when execution closes

**Approval:** approved

## Validation Audit 2026-05-06

| Metric | Count |
|--------|-------|
| Gaps found | 1 |
| Resolved | 1 |
| Escalated | 0 |

### Evidence

- `MIX_ENV=test mix compile --warnings-as-errors`
- `MIX_ENV=test mix test test/sigra/webhooks_test.exs test/sigra/config_test.exs test/sigra/install/generator_wiring_test.exs test/sigra/webhooks_payload_test.exs test/sigra/webhooks_event_catalog_test.exs test/sigra/webhooks_signature_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/install/features/core_post_instructions_test.exs --no-color`
  Result: `131 tests, 0 failures`
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_dispatcher_test.exs test/sigra/webhooks_audit_atomicity_test.exs test/sigra/webhooks_integration_test.exs --no-color`
  Result: `10 tests, 0 failures`
- `rg -n "Sigra-Webhook-|body_reader|secure_compare|delivery_id|event_id|schema_version" guides/flows/webhooks.md guides/recipes/webhook-verification.md`
- `rg -n "webhook_subscriptions|webhook_events|webhook_deliveries|webhook_delivery_attempts" test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_*.ex test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery_attempt.ex`

### Gap Resolved

- Updated [test/sigra/webhooks_test.exs](/Users/jon/projects/sigra/test/sigra/webhooks_test.exs) to include the now-required `webhook_delivery_attempt_schema` in its stub config and expected validation error text, eliminating stale Phase 97 test drift.
