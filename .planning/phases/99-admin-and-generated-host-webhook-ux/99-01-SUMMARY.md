---
phase: 99-admin-and-generated-host-webhook-ux
plan: 01
subsystem: webhooks
tags: [webhooks, admin, liveview, generated-host, thin-wrappers]
requires:
  - phase: 97-webhook-subscription-registry-signed-dispatcher-contract
    provides: "Subscription, delivery, and attempt persistence seams"
  - phase: 98-reliable-delivery-pipeline
    provides: "Summary-row delivery state and attempt-ledger history"
provides:
  - "Global-admin webhook query, detail, action, and failures seams for later LiveViews"
  - "Public Sigra webhook helpers for subscription lookup, reveal, and one-way secret rotation"
  - "Thin generated-host delegates that expose the admin webhook seam without duplicating policy"
affects: [admin-webhooks-ui, generated-host-router, webhook-docs]
tech-stack:
  added: []
  patterns: [summary-first admin reads, global-admin action seam, thin generated delegates]
key-files:
  created:
    - lib/sigra/admin/webhooks/query.ex
    - lib/sigra/admin/webhooks/detail.ex
    - lib/sigra/admin/webhooks/actions.ex
    - lib/sigra/admin/webhooks/failures.ex
    - test/sigra/admin/webhooks_test.exs
  modified:
    - lib/sigra/webhooks.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex
key-decisions:
  - "Admin list and failures queries read `webhook_deliveries` summary rows first and reserve `webhook_delivery_attempts` for delivery drill-down only."
  - "Secret reveal and rotation stay explicit admin actions routed through `Sigra.Webhooks` helpers instead of generated-host direct repo access."
  - "Generated-host account delegates remain thin wrappers over Sigra-owned admin seams."
patterns-established:
  - "Future webhook LiveViews should consume `Sigra.Admin.Webhooks.*` modules rather than query webhook tables inline."
  - "Subscription-level secret operations should flow through explicit reveal and rotate helpers so UI copy stays honest about the one-active-secret contract."
requirements-completed: [WH-03]
duration: 1 session
completed: 2026-05-06
---

# Phase 99 Plan 01: Admin Webhook Seam Summary

**Global-admin webhook query, detail, mutation, and generated-host delegate seams for the Phase 99 UI**

## Performance

- **Duration:** 1 session
- **Completed:** 2026-05-06
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Added `Sigra.Admin.Webhooks.Query`, `Detail`, `Failures`, and `Actions` so later LiveViews can stay on library-owned reads and mutations.
- Added focused coverage proving summary-first list reads, attempt-ledger drill-down, explicit `event_types` persistence, and reveal/rotate secret behavior.
- Extended `Sigra.Webhooks` and the generated install-golden account wrapper with thin helpers for lookup, reveal, rotation, and admin webhook delegation.

## Task Commits

1. **Task 1: Create focused library tests for webhook admin queries and actions** - `742d6c5` (`test(99-01): add failing test for webhook admin seams`)
2. **Task 2: Implement summary-first webhook admin read modules** - `df86d76` (`feat(99-01): add admin webhook query and detail seams`)
3. **Task 3: Implement admin-safe webhook mutations and thin generated-host delegates** - `056db8c` (`feat(99-01): add admin webhook action helpers and delegates`)

## Files Created/Modified

- `lib/sigra/admin/webhooks/query.ex` - URL-driven admin subscription index query backed by summary delivery rows.
- `lib/sigra/admin/webhooks/detail.ex` - Shared subscription and delivery detail loaders with recent history and ordered attempts.
- `lib/sigra/admin/webhooks/failures.ex` - Global retrying/dead-letter inbox query contract.
- `lib/sigra/admin/webhooks/actions.ex` - Global-admin-safe create, update, enable, disable, reveal, and rotate actions.
- `lib/sigra/webhooks.ex` - Public lookup, reveal, and rotate helpers reused by admin seams.
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex` - Thin generated-host delegates for admin webhook reads and mutations.
- `test/sigra/admin/webhooks_test.exs` - Focused regression coverage for the Phase 99 Plan 01 contract.

## Decisions Made

- Reused `Sigra.Webhooks` as the canonical place for subscription lookup and secret lifecycle helpers instead of duplicating those concerns in admin modules.
- Kept the generated-host surface limited to delegates so later router and LiveView work can depend on one policy source.

## Deviations from Plan

None in behavior. A compile warning surfaced during the final helper slice and was removed before completion.

## Issues Encountered

`mix compile --warnings-as-errors` initially failed on an unused alias in `Sigra.Admin.Webhooks.Actions`; removing the alias restored the compile gate without changing behavior.

## User Setup Required

None.

## Next Phase Readiness

- Plans `99-02` and `99-03` can now build subscription and failures LiveViews on stable library-owned query/detail/action contracts.
- Router, nav, and docs work can treat the generated-host wrapper as a thin integration layer rather than a second webhook policy surface.

## Self-Check

PASSED

- `mix compile --warnings-as-errors`
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs --no-color`
- `rg -n "defmodule Sigra\\.Admin\\.Webhooks\\.(Query|Detail|Actions|Failures)|delivery_id|attempts|rotate|reveal|event_types" lib/sigra/admin/webhooks/*.ex lib/sigra/webhooks.ex test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex test/sigra/admin/webhooks_test.exs`

---
*Phase: 99-admin-and-generated-host-webhook-ux*
*Completed: 2026-05-06*
