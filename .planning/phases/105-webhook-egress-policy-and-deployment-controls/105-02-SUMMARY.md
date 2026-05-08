---
phase: 105-webhook-egress-policy-and-deployment-controls
plan: 02
subsystem: admin-webhooks
tags: [webhooks, admin, operator-truth, generated-host]
requires:
  - phase: 105-webhook-egress-policy-and-deployment-controls
    provides: endpoint policy engine and truthful local denial persistence from Plan 01
provides:
  - delivery-detail policy read model
  - failures-inbox policy metadata
  - generated-host endpoint policy callback seam across example, template, and golden fixture
affects: [phase-105-plan-03, admin-webhook-detail, admin-webhook-failures, generated-host-webhooks]
tech-stack:
  added: []
  patterns: [normalized operator policy payload, generated-host seam parity]
key-files:
  created:
    - .planning/phases/105-webhook-egress-policy-and-deployment-controls/105-02-SUMMARY.md
  modified:
    - lib/sigra/admin/webhooks/detail.ex
    - lib/sigra/admin/webhooks/failures.ex
    - priv/templates/sigra.install/core/auth.ex
    - test/example/lib/example/accounts.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex
    - test/sigra/admin/webhooks_test.exs
    - test/sigra/install/generator_wiring_test.exs
key-decisions:
  - "Operator-facing policy state is derived directly from persisted delivery fields, not inferred from UI copy."
  - "Generated hosts expose a default webhook_endpoint_policy/1 seam but leave enforcement timing and truth persistence in the library."
  - "Failures rows expose narrow policy metadata instead of forcing callers to parse raw error strings."
patterns-established:
  - "Delivery detail returns a normalized policy payload with blocked flag, stable reason, and operator-safe detail."
  - "Example app, installer template, and golden fixture stay aligned for webhook endpoint policy wiring."
requirements-completed: [WH-06]
duration: resumed execution pass
completed: 2026-05-07
---

# Phase 105 Plan 02: Operator Truth And Host Seam Summary

Implemented the operator-facing read-model contract for blocked webhook destinations and shipped the generated-host callback seam adopters use to customize policy without forking Sigra internals.

## Accomplishments

- Extended `Sigra.Admin.Webhooks.Detail.load_delivery!/3` with a normalized `policy` payload for local policy denials.
- Extended `Sigra.Admin.Webhooks.Failures.list_deliveries/3` with `policy_reason` and `policy_detail` metadata on blocked rows.
- Added `webhook_endpoint_policy/1` plus `endpoint_policy: &__MODULE__.webhook_endpoint_policy/1` wiring to the example app, installer template, and golden fixture.
- Added admin and generator regressions that fail if blocked-delivery truth or callback seam parity disappears.

## Verification

PASSED

- `mix compile --warnings-as-errors`
- `CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs test/sigra/install/generator_wiring_test.exs --no-color`

## Notes

- This plan executed on a dirty worktree, so no atomic task commits were created.
- The generated-host callback seam defaults to `:ok`; deployment-specific denials remain host-owned code in the wrapper, not library forks.
