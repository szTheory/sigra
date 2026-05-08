---
phase: 101
slug: operator-delivery-state-truth
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-06
---

# Phase 101 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `101-CONTEXT.md`, `101-RESEARCH.md`, and the executable plan set.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, Postgres-backed Sigra admin query tests, Example `Phoenix.LiveViewTest` |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs --no-color` |
| **Wave merge smoke** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs test/example/test/example_web/live/admin_webhook_failures_live_test.exs --no-color && MIX_ENV=test mix compile --warnings-as-errors` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs test/example/test/example_web/live/admin_webhook_failures_live_test.exs --no-color && MIX_ENV=test mix compile --warnings-as-errors` |
| **Estimated runtime** | ~20-40 seconds quick loop, ~60-90 seconds full focused phase suite |

---

## Sampling Rate

- **After every task commit:** Run the task-level automated verify command from the touched plan.
- **After Plan 01 / wave 1:** Run `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs --no-color && MIX_ENV=test mix compile --warnings-as-errors`.
- **After Plan 02 / wave 2:** Run the wave merge smoke command above.
- **Before `$gsd-verify-work`:** Run the full suite command and confirm the codebase emits only canonical `delivery_state` params at the LiveView boundary.
- **Max feedback latency:** ~40 seconds for the query loop, ~90 seconds for the focused phase suite.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 101-01-01 | 01 | 1 | WH-02, WH-03 | Library regressions prove SQL-before-pagination, latest-delivery-wins semantics, canonical `delivery_state` normalization, and row/count alignment | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs --no-color` | ✅ extend | ⬜ pending |
| 101-01-02 | 01 | 1 | WH-02, WH-03 | Query modules own delivery-state filtering and same-base subscription/failures counts without post-pagination status hacks | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs --no-color && MIX_ENV=test mix compile --warnings-as-errors` | ✅ extend | ⬜ pending |
| 101-02-01 | 02 | 2 | WH-02, WH-03 | Example-host regressions prove `delivery_state` params, strict retrying/dead-letter partitioning, latest-delivery truth, and page-pressure filtering | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs test/example/test/example_web/live/admin_webhook_failures_live_test.exs --no-color` | ✅ extend | ⬜ pending |
| 101-02-02 | 02 | 2 | WH-02, WH-03 | LiveViews consume query-owned counts, emit only `delivery_state` params, and keep failures counts delivery-row based | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs test/example/test/example_web/live/admin_webhook_failures_live_test.exs --no-color && MIX_ENV=test mix compile --warnings-as-errors` | ✅ extend | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| WH-02 | Retrying and dead-lettered operator surfaces match the persisted worker-state model without blended semantics | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs test/example/test/example_web/live/admin_webhook_failures_live_test.exs --no-color` | ✅ extend |
| WH-03 | Subscription index filters, rows, chips, and params reflect latest-delivery truth before pagination | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs --no-color` | ✅ extend |
| WH-03 | Canonical operator contract is `delivery_state`, with legacy `status` accepted only as an input alias at normalization | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs test/example/test/example_web/live/admin_webhook_failures_live_test.exs --no-color` | ✅ extend |

---

## Wave 0 Requirements

No separate Wave 0 scaffold is required. The phase extends existing Sigra admin query and example-host LiveView tests, and each plan begins with runnable automated verification in already-existing test files.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| _(none)_ | — | Phase 101 should be fully automatable; the defect is query/UI-contract truth, not a human-witness flow. | — |

*All planned Phase 101 behaviors have automated verification targets.*

---

## Validation Sign-Off

- [x] All tasks have runnable automated verify commands
- [x] Sampling continuity: no 3 consecutive tasks without automated verification
- [x] No standalone Wave 0 scaffold remains
- [x] No watch-mode flags
- [ ] Feedback latency < 40s for quick loop, < 90s for full focused phase suite
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
