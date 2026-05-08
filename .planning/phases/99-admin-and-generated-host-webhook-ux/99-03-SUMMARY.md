---
phase: 99-admin-and-generated-host-webhook-ux
plan: 03
subsystem: webhooks
tags: [webhooks, admin, failures, delivery-history, liveview]
requires:
  - phase: 99-admin-and-generated-host-webhook-ux
    provides: "Plan 01 admin webhook failures/detail seam"
provides:
  - "Global failures inbox for retrying and dead-lettered deliveries"
  - "Shared delivery drill-down with current status and ordered attempt timeline"
affects: [admin-webhooks-ui, operations]
tech-stack:
  added: []
  patterns: [summary-first failures inbox, shared delivery detail page, sanitized return_to]
requirements-completed: [WH-03]
duration: resumed execution pass
completed: 2026-05-06
---

# Phase 99 Plan 03: Failures And Delivery History Summary

Implemented and verified the delivery-history half of the admin webhook UX without turning the feature into queue introspection or manual replay tooling.

## Accomplishments

- Added a global failures inbox LiveView that stays focused on retrying and dead-letter attention states.
- Added a shared delivery detail LiveView that renders current delivery status plus ordered attempt history.
- Preserved the plan contract around summary-first list reads, shared drill-down, and sanitized navigation back-links.

## Key Files

- `lib/sigra/admin/live/webhook_delivery_failures_live.ex`
- `lib/sigra/admin/live/webhook_delivery_show_live.ex`
- `test/example/test/example_web/live/admin_webhook_failures_live_test.exs`
- `test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs`

## Verification

PASSED

- `cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/live/admin_webhook_failures_live_test.exs test/example_web/live/admin_webhook_delivery_show_live_test.exs --no-color`

## Notes

- This summary was completed from a resumed execution pass against an existing dirty working tree.
- No new task-by-task commits were created in this pass; the implementation already existed and was validated to green.
