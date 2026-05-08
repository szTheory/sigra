---
phase: 98
slug: reliable-delivery-pipeline
status: completed
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-06
---

# Phase 98 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Sourced from `98-CONTEXT.md`, `98-RESEARCH.md`, and the executable plan set.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, Postgres-backed integration tests, generated install-golden fixtures, targeted docs/grep checks |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/sigra/workers/webhook_delivery_test.exs --max-failures 1 --no-color` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/webhooks_reliable_delivery_atomicity_test.exs test/sigra/install/generator_wiring_test.exs test/sigra/install/golden_diff_test.exs --no-color && MIX_ENV=test mix compile --warnings-as-errors` |
| **Estimated runtime** | ~20s quick loop, ~90-150s full focused phase suite |

---

## Sampling Rate

- **After every task commit:** Run the task-level automated verify command from the touched plan.
- **After wave 0 (`98-01`):** Run `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs test/sigra/install/generator_wiring_test.exs test/sigra/install/golden_diff_test.exs --no-color && MIX_ENV=test mix compile --warnings-as-errors`.
- **After wave 1 (`98-02`):** Run `MIX_ENV=test mix test test/sigra/workers/webhook_delivery_test.exs test/sigra/webhooks_reliable_delivery_atomicity_test.exs --no-color && MIX_ENV=test mix compile --warnings-as-errors`.
- **After wave 2 (`98-03`) / before `$gsd-verify-work`:** Run the full suite command above, then grep the docs for the exact retry/dead-letter contract.
- **Before `$gsd-verify-work`:** Focused phase suite green on Postgres and `mix compile --warnings-as-errors`.
- **Max feedback latency:** ~20 seconds quick loop, ~150 seconds focused full phase loop.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 98-01-01 | 01 | 0 | WH-02 | Generated webhook migration evolves `webhook_deliveries` into a summary row and adds `webhook_delivery_attempts` ledger | fixture/grep | `rg -n "webhook_delivery_attempts|attempt_count|next_attempt_at|dead_lettered_at|terminal_reason" test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs` | ✅ new | ✅ green |
| 98-01-02 | 01 | 0 | WH-02 | Generated schemas, wrapper exposure, and install-golden snapshots match the evolved runtime delivery-state contract | unit/integration | `MIX_ENV=test mix test test/sigra/install/generator_wiring_test.exs test/sigra/install/golden_diff_test.exs --no-color && MIX_ENV=test mix compile --warnings-as-errors` | ✅ new | ✅ green |
| 98-01-03 | 01 | 0 | WH-02 | Postgres-backed persistence harness proves summary-row plus append-only history shape is coherent | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs --no-color` | ✅ extend | ✅ green |
| 98-02-01 | 02 | 1 | WH-02 | Retry policy is fixed, bounded, and explicit, including `Retry-After` delay handling without budget expansion | unit/grep | `MIX_ENV=test mix compile --warnings-as-errors && rg -n "Retry-After|1 minute|5 minutes|15 minutes|1 hour|3 hours|408|429|5xx" lib/sigra/webhooks/retry_policy.ex lib/sigra/webhooks.ex lib/sigra/workers/webhook_delivery.ex` | ✅ new | ✅ green |
| 98-02-02 | 02 | 1 | WH-02 | Worker requester seam surfaces response headers needed to persist `Retry-After` on attempt rows | unit | `MIX_ENV=test mix test test/sigra/workers/webhook_delivery_test.exs --no-color` | ✅ extend | ✅ green |
| 98-02-03 | 02 | 1 | WH-02 | Success, retryable failure, terminal 4xx, and local invariant failures including missing-row orphan persistence update durable state transactionally | unit | `MIX_ENV=test mix test test/sigra/workers/webhook_delivery_test.exs test/sigra/webhooks_reliable_delivery_atomicity_test.exs --no-color` | ✅ extend | ✅ green |
| 98-03-01 | 03 | 2 | WH-02 | Integration proof covers both auth and at least one identity mutation while endpoint failures do not break the originating commit | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs --no-color` | ✅ extend | ✅ green |
| 98-03-02 | 03 | 2 | WH-02 | Docs state the exact six-attempt contract, stable `delivery_id`, fresh per-attempt timestamp/signature, and dead-letter non-goals honestly | docs/grep | `rg -n "six total attempts|1 minute|5 minutes|15 minutes|1 hour|3 hours|Retry-After|delivery_id|dead-letter|manual replay" guides/flows/webhooks.md guides/recipes/webhook-verification.md` | ✅ extend | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| WH-02 | Only matching subscriptions receive delivery lineage rows and retry state from persisted routing decisions | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs --no-color` | Wave 0/2 (EXTEND) |
| WH-02 | Retryable outcomes append attempt history, update delivery summary, persist optional `Retry-After`, and explicitly schedule one next attempt | unit + integration | `MIX_ENV=test mix test test/sigra/workers/webhook_delivery_test.exs --no-color && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs --no-color` | Wave 1/2 (EXTEND) |
| WH-02 | Terminal `4xx` and local invariant failures, including missing-row corruption, persist durable terminal state without silent disappearance | unit + integration | `MIX_ENV=test mix test test/sigra/workers/webhook_delivery_test.exs test/sigra/webhooks_reliable_delivery_atomicity_test.exs --no-color && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs --no-color` | Wave 1/2 (EXTEND) |
| WH-02 | Auth and identity mutations still succeed while downstream endpoints fail, and docs explain the durable retry/dead-letter contract honestly | integration + docs | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs --no-color && rg -n "Retry-After|delivery_id|dead-letter" guides/flows/webhooks.md guides/recipes/webhook-verification.md` | Wave 2 (EXTEND) |

---

## Wave 0 Requirements

- [x] Generated webhook migration evolves delivery summary and attempt history surfaces.
- [x] Generated webhook attempt schema exists and is exposed coherently.
- [x] Postgres-backed integration harness understands the evolved Phase 98 tables.
- [x] No new test framework is required beyond ExUnit/Postgres/install-golden patterns already present in the repo.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| _(none)_ | — | Phase 98 should be fully automatable; operator truth is a persisted-state and docs contract, not a human-witness flow. | — |

*All planned Phase 98 behaviors have automated verification targets.*

---

## Validation Sign-Off

- [x] All tasks have an automated `verify` command or a Wave 0 dependency
- [x] Sampling continuity: no 3 consecutive tasks without automated verification
- [x] Wave 0 covers schema evolution, generated-host contract, and integration harness prerequisites
- [x] No watch-mode flags
- [x] Feedback latency < 20s for quick loop, < 150s for focused full phase suite
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
- `MIX_ENV=test mix test test/sigra/workers/webhook_delivery_test.exs test/sigra/webhooks_reliable_delivery_atomicity_test.exs --no-color`
  Result: passed during Phase 98 execution and remained green after the Phase 100 enqueue repair.
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs --no-color`
  Result: passed with production-path enqueue proof added in Phase 100.
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_dispatcher_test.exs test/sigra/webhooks_audit_atomicity_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/webhooks_integration_test.exs --no-color`
  Result: passed as recorded in `100-01-SUMMARY.md` and `100-02-SUMMARY.md`.
- `rg -n "six total attempts|1 minute|5 minutes|15 minutes|1 hour|3 hours|Retry-After|delivery_id|dead-letter|manual replay" guides/flows/webhooks.md guides/recipes/webhook-verification.md`

### Gap Resolved

- Phase 98's original runtime gap was the missing production initial enqueue discovered by the v1.22 audit. Phase 100 repaired that handoff, turning the existing retry/dead-letter machinery into a fully verified end-to-end delivery pipeline without changing the Phase 98 contract.
