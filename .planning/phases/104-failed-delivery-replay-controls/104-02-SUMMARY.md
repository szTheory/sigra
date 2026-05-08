---
phase: 104-failed-delivery-replay-controls
plan: 02
subsystem: admin-webhooks
tags: [webhooks, replay, admin, read-models, generated-host]
requires:
  - phase: 104-failed-delivery-replay-controls
    provides: replay transaction, lineage columns, and duplicate-child guard from Plan 01
provides:
  - thin admin replay action wrapper over Sigra.Webhooks.replay_delivery/4
  - delivery detail replay lineage and eligibility read model
  - failures inbox replay shortcut metadata and generated-host wrapper parity
affects: [phase-104-plan-03, admin-webhook-detail, admin-webhook-failures, generated-host-admin]
tech-stack:
  added: []
  patterns: [thin admin mutation seam, persisted replay eligibility reasons, generated-host wrapper parity]
key-files:
  created:
    - .planning/phases/104-failed-delivery-replay-controls/104-02-SUMMARY.md
  modified:
    - lib/sigra/admin/webhooks/actions.ex
    - lib/sigra/admin/webhooks/detail.ex
    - lib/sigra/admin/webhooks/failures.ex
    - test/example/lib/example/accounts.ex
    - priv/templates/sigra.install/core/auth.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex
    - test/sigra/admin/webhooks_test.exs
    - test/sigra/install/generator_wiring_test.exs
key-decisions:
  - "Kept replay as a globally authorized admin action that delegates directly to the library transaction instead of re-implementing mutation logic in read models or wrappers."
  - "Exposed replay eligibility as stable reason atoms on the delivery/failures read models so later LiveViews can render truthful operator copy without inferring state from UI conditions."
  - "Scoped failures inbox replay metadata to row-level shortcut needs only: replayable flag, rejection reason, and existing child link."
patterns-established:
  - "Delivery detail now returns replay parent/root/children alongside the existing per-delivery attempt timeline."
  - "Example app, installer template, and golden fixture wrappers stay aligned for admin replay entrypoints."
requirements-completed: [WH-05]
duration: resumed execution pass
completed: 2026-05-07
---

# Phase 104 Plan 02: Admin Replay Seams Summary

Implemented the admin-facing replay seam on top of the Plan 01 library contract and verified the shared read models plus generated-host wrappers.

## Accomplishments

- Added `Sigra.Admin.Webhooks.Actions.replay_delivery/4` as a thin global-admin wrapper over `Sigra.Webhooks.replay_delivery/4`.
- Extended `Sigra.Admin.Webhooks.Detail.load_delivery!/3` with replay parent/root/children loading plus stable replay eligibility reasons while keeping attempt timelines scoped to one delivery row.
- Extended `Sigra.Admin.Webhooks.Failures.list_deliveries/3` with replay shortcut metadata and dead-letter replay-child visibility without turning the inbox into a second mutation engine.
- Added `replay_admin_webhook_delivery/3` wrapper parity across the example app, installer template, and golden fixture surfaces.

## Verification

PASSED

- `mix compile --warnings-as-errors`
- `mix test test/sigra/admin/webhooks_test.exs --no-color`
- `mix test test/sigra/install/generator_wiring_test.exs --no-color`
- `rg -n "replay_delivery|replayable|replay_reason|replay_children|replay_root|replay_parent|replay_admin_webhook_delivery" lib/sigra/admin/webhooks/actions.ex lib/sigra/admin/webhooks/detail.ex lib/sigra/admin/webhooks/failures.ex test/example/lib/example/accounts.ex priv/templates/sigra.install/core/auth.ex test/sigra/admin/webhooks_test.exs`

## Notes

- This plan was completed on top of an already dirty worktree, so no atomic task commits were created.
- `mix format` was applied to concrete Elixir files only; the EEx installer template remains unformatted by `mix format` because template syntax is not directly parseable by the formatter.
