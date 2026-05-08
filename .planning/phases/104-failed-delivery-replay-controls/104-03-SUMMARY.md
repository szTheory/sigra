---
phase: 104-failed-delivery-replay-controls
plan: 03
subsystem: admin-liveview
tags: [webhooks, replay, liveview, failures-inbox, delivery-detail]
requires:
  - phase: 104-failed-delivery-replay-controls
    provides: admin replay action wrapper and replay read models from Plan 02
provides:
  - delivery-detail replay confirmation and lineage rendering
  - failures-inbox replay badges and narrow shortcut affordances
  - subscription-detail replay context in recent history
affects: [phase-104-plan-04, admin-webhook-liveviews, example-live-tests]
tech-stack:
  added: []
  patterns: [delivery-detail as replay authority, row-level replay shortcuts, test-fixture schema backfill]
key-files:
  created:
    - .planning/phases/104-failed-delivery-replay-controls/104-03-SUMMARY.md
  modified:
    - lib/sigra/admin/live/webhook_delivery_show_live.ex
    - lib/sigra/admin/live/webhook_delivery_failures_live.ex
    - lib/sigra/admin/live/webhook_subscription_show_live.ex
    - test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs
    - test/example/test/example_web/live/admin_webhook_failures_live_test.exs
    - test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs
    - test/example/test/support/webhook_admin_live_fixtures.ex
key-decisions:
  - "Delivery detail is the only place that can directly confirm replay; the failures inbox only links or advertises shortcut state."
  - "Replay lineage is rendered separately from the attempt timeline so one delivery lifecycle never absorbs another."
  - "Example LiveView fixtures provision replay columns/indexes on the test table so the operator-facing suite does not depend on external migration state."
patterns-established:
  - "LiveViews consume the replay reason atoms from Plan 02 instead of guessing replayability from ad hoc UI logic."
  - "Subscription detail surfaces replay context only as recent-history hints and routes deep investigation back to shared delivery detail."
requirements-completed: [WH-05]
duration: resumed execution pass
completed: 2026-05-07
---

# Phase 104 Plan 03: Replay UX Summary

Implemented the operator-facing replay UX across the shared delivery detail, failures inbox, and subscription detail surfaces, then verified the example LiveView story end to end.

## Accomplishments

- Added replay confirmation, replay-status copy, and lineage rendering to `WebhookDeliveryShowLive`, including child-link navigation after a replay is queued.
- Added row-level replay badges and replay-child links to `WebhookDeliveryFailuresLive` while keeping the failures page a triage surface rather than a queue-control dashboard.
- Added read-only replay context to subscription recent history and kept replay actions off the subscription detail page.
- Reworked the example-host LiveView fixtures and tests to cover replay lineage, replay confirmation, and narrow inbox shortcuts.

## Verification

PASSED

- `mix compile --warnings-as-errors`
- `cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/live/admin_webhook_delivery_show_live_test.exs test/example_web/live/admin_webhook_failures_live_test.exs test/example_web/live/admin_webhook_subscription_show_live_test.exs --no-color`

## Notes

- The example test fixture now backfills replay columns and indexes onto `webhook_deliveries` in the test database before inserting replay rows, because the example test database may lag behind the new migration during local resumed execution.
- This plan was completed on top of an already dirty worktree, so no isolated task commits were created.
