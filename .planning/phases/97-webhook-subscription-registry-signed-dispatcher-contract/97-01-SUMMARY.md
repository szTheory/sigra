---
phase: 97-webhook-subscription-registry-signed-dispatcher-contract
plan: 1
subsystem: webhooks
tags: [webhooks, config, migration, generated-host, foundation]
requires: []
provides:
  - "Validated `:webhooks` config surface with generated schema module references and async queue knobs"
  - "Webhook optional-dependency enforcement wired to explicit host enablement evidence"
  - "Library-owned subscription CRUD/validation plus generated host migration, schemas, and wrappers"
affects: [config, optional-dependencies, generated-host, webhook-subscriptions]
tech-stack:
  added: []
  patterns: [library-owned orchestration, generated-host schema ownership, explicit async-only webhook posture]
key-files:
  created:
    - lib/sigra/webhooks.ex
    - test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_subscription.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_event.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery.ex
    - test/sigra/webhooks_test.exs
  modified:
    - lib/sigra/config.ex
    - lib/sigra/optional_deps.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex
    - test/sigra/config_test.exs
    - test/sigra/optional_deps_test.exs
    - test/sigra/install/generator_wiring_test.exs
key-decisions:
  - "Webhooks stay disabled by default, but enabling them becomes an explicit async-only contract backed by Oban dependency checks."
  - "The generated host owns three stable tables and schemas: subscriptions, public webhook events, and per-subscription deliveries."
  - "Subscription validation is library-owned and enforces explicit event types, HTTPS-by-default endpoints, and minimum secret length."
patterns-established:
  - "Later webhook plans should consume `Sigra.Webhooks.public_event_types/0` and schema lookup helpers instead of re-declaring config keys."
  - "Generated-host wrappers should expose thin `Sigra.Webhooks` delegates rather than reimplementing policy in host code."
requirements-completed: [WH-01]
duration: 1 session
completed: 2026-05-06
---

# Phase 97 Plan 1: Webhook Foundation Summary

**Webhook config, generated storage, and subscription CRUD foundation**

## Performance

- **Duration:** 1 session
- **Completed:** 2026-05-06
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments

- Added the top-level `:webhooks` config surface to `Sigra.Config` with explicit generated schema references, queue settings, and signature tolerance.
- Extended `Sigra.OptionalDeps` with a `:webhook_delivery` enforced feature so enabled webhooks fail honestly when async infrastructure is unavailable.
- Added `Sigra.Webhooks` as the library-owned subscription API with event-type normalization, HTTPS-by-default endpoint validation, and enable/disable helpers.
- Added generated-host migration, schemas, and context wrappers for `webhook_subscriptions`, `webhook_events`, and `webhook_deliveries`.
- Added verification coverage for webhook config defaults, optional dependency behavior, generator wiring, and subscription CRUD/validation.

## Task Commits

1. **Plan 01 foundation work** - `6b8ef36` (`feat`)

## Files Created/Modified

- `lib/sigra/config.ex` - Added validated webhook config surface and struct typing/defaults.
- `lib/sigra/optional_deps.ex` - Added enforced webhook async dependency contract and host-proven evidence helpers.
- `lib/sigra/webhooks.ex` - Added library-owned subscription CRUD, schema lookup helpers, and validation policy.
- `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs` - Added generated webhook subscriptions/events/deliveries migration.
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_*.ex` - Added generated host schemas for subscription, event, and delivery rows.
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex` - Added generated config wiring and thin webhook wrapper functions.
- `test/sigra/webhooks_test.exs` - Added library-level verification for subscription validation and CRUD behavior.
- `test/sigra/config_test.exs` - Added webhook config default/override validation coverage.
- `test/sigra/optional_deps_test.exs` - Added webhook optional-dependency coverage.
- `test/sigra/install/generator_wiring_test.exs` - Added generated-host wiring and migration assertions.

## Decisions Made

- Webhook enablement uses explicit host config proof (`config.webhooks[:enabled]`) rather than speculation.
- Public webhook delivery remains async-only from day one; there is no `:auto` or sync fallback semantics in the config contract.
- Signing secrets are modeled as required protected data in generated schemas and never treated as optional metadata.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `gsd-sdk query` helpers were unavailable in this environment, so plan discovery and execution used the checked-in phase files directly.
- Parallel `mix test` invocations contended on the build lock, so verification was completed by polling each session to completion rather than rerouting the work.

## User Setup Required

None for disabled mode. Hosts that later set `webhooks: [enabled: true]` must also provide Oban.

## Next Phase Readiness

- Plan 02 can now freeze the public event catalog and payload envelope against stable config and schema seams.
- Later persistence and worker plans can rely on the subscription/event/delivery table names and generated wrapper API staying stable.

## Self-Check

PASSED

- `mix compile --warnings-as-errors`
- `mix test test/sigra/webhooks_test.exs --no-color`
- `mix test test/sigra/config_test.exs --no-color`
- `mix test test/sigra/install/generator_wiring_test.exs --no-color`
- `mix test test/sigra/optional_deps_test.exs --no-color`
- `rg -n "webhooks|webhook_subscription|webhook_event|webhook_delivery" lib/sigra/config.ex lib/sigra/optional_deps.ex test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex test/fixtures/install_golden/tree/priv/repo/migrations`
- Verified commit `6b8ef36` in `git log --oneline --max-count=1`

---
*Phase: 97-webhook-subscription-registry-signed-dispatcher-contract*
*Completed: 2026-05-06*
