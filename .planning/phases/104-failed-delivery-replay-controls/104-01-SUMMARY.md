---
phase: 104-failed-delivery-replay-controls
plan: 01
subsystem: webhooks
tags: [webhooks, replay, lineage, schema, generated-host]
requires:
  - phase: 98-reliable-delivery-pipeline
    provides: durable delivery rows, attempt ledger, and async enqueue seam
  - phase: 101-operator-delivery-state-truth
    provides: dead-letter summary truth and admin delivery semantics
provides:
  - library-owned replay transaction with typed guard reasons
  - durable replay lineage columns and unique child guard on delivery rows
  - generated-host schema and migration parity for replay metadata
affects: [phase-104-plan-02, phase-104-plan-03, generated-host-webhooks]
tech-stack:
  added: []
  patterns: [new delivery lineage for replay, transaction-owned enqueue, database-enforced one-child guard]
key-files:
  created:
    - .planning/phases/104-failed-delivery-replay-controls/104-01-SUMMARY.md
    - test/example/lib/example/accounts/webhook_delivery.ex
    - test/example/priv/repo/migrations/20260506170000_create_webhook_tables.exs
  modified:
    - lib/sigra/webhooks.ex
    - lib/sigra/webhooks/dispatcher.ex
    - priv/templates/sigra.install/core/webhook_delivery.ex
    - priv/templates/sigra.install/core/webhook_migration.exs
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery.ex
    - test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs
    - test/sigra/webhooks_replay_test.exs
    - test/sigra/webhooks_integration_test.exs
    - test/sigra/workers/webhook_delivery_test.exs
    - test/sigra/install/generator_wiring_test.exs
key-decisions:
  - "Replay creates a fresh pending child delivery row and never mutates the dead-lettered source back to pending."
  - "Replay eligibility failures are returned as stable atoms so later admin/UI plans can map them directly into operator copy."
  - "Duplicate replay prevention lives on the delivery table via a partial unique index, with a transaction-time precheck for nicer failures."
patterns-established:
  - "Dispatcher now exposes a canonical fresh-delivery insert seam reused by initial fan-out and replay."
  - "Replay lineage lives on the delivery row itself: parent pointer, root pointer, replay timestamp, actor, and source surface."
requirements-completed: [WH-05]
duration: resumed execution pass
completed: 2026-05-07
---

# Phase 104 Plan 01: Replay Lineage Summary

Implemented the durable replay foundation for failed webhook deliveries and verified it end to end at the library, integration, worker, and generator seams.

## Accomplishments

- Added `Sigra.Webhooks.replay_delivery/4` as a library-owned `Ecto.Multi` that loads the source delivery context, enforces dead-letter-only replay, rejects truth-gap and disabled-subscription states, inserts a fresh child delivery row, and enqueues it in the same transaction.
- Reused the delivery insertion seam by extracting canonical pending-delivery attribute/build helpers into `Sigra.Webhooks.Dispatcher`.
- Extended generated-host and installer delivery schemas/migrations with replay lineage fields and a partial unique index on `replayed_from_webhook_delivery_id` to prevent duplicate direct children.
- Locked the contract with focused replay unit coverage, persisted integration coverage, worker regression coverage, and generator-wiring assertions.

## Verification

PASSED

- `mix compile --warnings-as-errors`
- `mix test test/sigra/webhooks_replay_test.exs test/sigra/workers/webhook_delivery_test.exs --no-color`
- `mix test test/sigra/webhooks_integration_test.exs test/sigra/install/generator_wiring_test.exs --no-color`
- `rg -n "replayed_from_webhook_delivery_id|replay_root_webhook_delivery_id|replayed_at|replayed_by_user_id|replay_source|replay_delivery|replay_already_exists|delivery_context_incomplete|subscription_disabled|webhooks_disabled" lib/sigra/webhooks.ex lib/sigra/webhooks/dispatcher.ex test/example/lib/example/accounts/webhook_delivery.ex test/example/priv/repo/migrations/20260506170000_create_webhook_tables.exs priv/templates/sigra.install/core/webhook_delivery.ex priv/templates/sigra.install/core/webhook_migration.exs test/sigra/webhooks_replay_test.exs`

## Notes

- This plan executed against an already dirty worktree, so no safe task-by-task commits were created.
- `mix format` was applied to concrete Elixir source/test files only; EEx templates under `priv/templates/` are intentionally left unformatted because `mix format` cannot parse template syntax directly.
