---
phase: 98-reliable-delivery-pipeline
plan: 2
subsystem: webhooks
tags: [webhooks, retry-policy, dead-letter, worker, atomicity]
requires:
  - phase: 98-reliable-delivery-pipeline
    provides: persisted delivery summary rows and append-only attempt ledger tables
provides:
  - "Bounded six-attempt retry policy with `Retry-After` delay handling"
  - "Transactional attempt-row plus delivery-summary persistence helpers"
  - "Single-shot worker behavior that records outcomes and schedules retries explicitly"
  - "Rollback proof for attempt/summary co-fate"
affects: [webhook-worker, delivery-history, retry-scheduling, generated-host-admin]
tech-stack:
  added: []
  patterns: [single-shot worker, library-owned retry policy, transactional delivery outcome persistence]
key-files:
  created:
    - lib/sigra/webhooks/retry_policy.ex
    - test/sigra/webhooks_reliable_delivery_atomicity_test.exs
  modified:
    - lib/sigra/webhooks.ex
    - lib/sigra/webhooks/dispatcher.ex
    - lib/sigra/workers/webhook_delivery.ex
    - test/sigra/workers/webhook_delivery_test.exs
key-decisions:
  - "Retry budgeting remains fixed in library code; hosts cannot tune attempt counts or backoff for v1.22."
  - "Every attempt outcome flows through one transactional helper that writes the child attempt row and parent summary together."
  - "Missing parent delivery rows become orphan terminal issue records keyed by `delivery_id` instead of silent cancels."
patterns-established:
  - "Worker `perform/1` stays single-shot and explicit follow-up enqueueing happens only after persisted retry state says another attempt is due."
  - "Atomicity tests should fail one side of the transaction at a time to prove both the child insert and parent summary update roll back together."
requirements-completed: [WH-02]
duration: 1 session
completed: 2026-05-06
---

# Phase 98 Plan 2: Reliable Retry Orchestration Summary

**Sigra now owns bounded webhook retries, dead-letter transitions, and append-only attempt persistence instead of relying on raw Oban retry semantics**

## Performance

- **Duration:** 1 session
- **Completed:** 2026-05-06
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments

- Added `Sigra.Webhooks.RetryPolicy` to encode the six-attempt schedule, retryable/terminal classifications, and `Retry-After` parsing.
- Seeded delivery summary fields in the dispatcher and added transactional `Sigra.Webhooks.persist_delivery_outcome/3` plus orphan terminal-issue persistence.
- Reworked `Sigra.Workers.WebhookDelivery` so each run stays single-shot, records durable success/retry/dead-letter outcomes, and explicitly enqueues the next attempt only when persisted state says to.
- Added focused worker and atomicity tests, then rechecked the broader integration harness to confirm successful deliveries still stamp `dispatched_at`.

## Task Commits

1. **Tasks 1-3 combined: bounded retry policy, transactional persistence, and worker orchestration** - `e993a8d`

## Files Created/Modified

- `lib/sigra/webhooks/retry_policy.ex` - Bounded retry schedule, failure classification, and `Retry-After` parsing.
- `lib/sigra/webhooks.ex` - Transactional delivery outcome helpers and orphan terminal-issue persistence.
- `lib/sigra/webhooks/dispatcher.ex` - Initializes summary-row fields when deliveries are first persisted.
- `lib/sigra/workers/webhook_delivery.ex` - Records attempts, dead-letters terminal outcomes, and schedules follow-up jobs explicitly.
- `test/sigra/workers/webhook_delivery_test.exs` - Covers success, retryable 429, permanent 4xx, disabled subscription, and orphan missing-row behavior.
- `test/sigra/webhooks_reliable_delivery_atomicity_test.exs` - Proves attempt inserts and parent summary updates roll back together.

## Decisions Made

- Preserved `max_attempts: 1` on the Oban worker and moved all retry authority into Sigra-owned tables and helpers.
- Stored retry scheduling outcome as `retry_scheduled` on the parent delivery row rather than inspecting queue-provider retry metadata.
- Used an orphan attempt row with `webhook_delivery_id: nil` for the true missing-parent corruption case so operators still get durable evidence.

## Deviations from Plan

The runtime changes across Tasks 1-3 were too interdependent to split honestly into separate file-isolated commits on this dirty branch because `webhooks.ex` and the worker own the shared seam. They were landed in one combined feature commit after the focused verification loop was green.

## Issues Encountered

- The first worker refactor dropped `dispatched_at` on successful deliveries. The Phase 98 integration harness caught it immediately, and the success persistence path was corrected before completion.

## User Setup Required

None.

## Next Phase Readiness

- Plan `98-03` can extend the real integration harness and docs around a stable persisted reliability contract instead of inventing retry semantics in tests or prose.
- Admin/history work in Phase 99 can read delivery summary rows plus attempt ledger rows directly for operator-visible truth.

## Self-Check

PASSED

- `mix compile --warnings-as-errors`
- `mix test test/sigra/workers/webhook_delivery_test.exs test/sigra/webhooks_reliable_delivery_atomicity_test.exs --no-color`
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs --no-color`
- `rg -n "max_attempts: 1|dead_lettered|retry_scheduled|Retry-After|attempt_number|next_attempt_at|terminal_reason" lib/sigra/webhooks.ex lib/sigra/webhooks/dispatcher.ex lib/sigra/webhooks/retry_policy.ex lib/sigra/workers/webhook_delivery.ex test/sigra/workers/webhook_delivery_test.exs test/sigra/webhooks_reliable_delivery_atomicity_test.exs`

---
*Phase: 98-reliable-delivery-pipeline*
*Completed: 2026-05-06*
