---
phase: 97-webhook-subscription-registry-signed-dispatcher-contract
plan: 3
subsystem: webhooks
tags: [webhooks, persistence, outbox, atomicity, auth-integration]
requires: [97-01, 97-02]
provides:
  - "Composable dispatcher multi that persists webhook events plus per-subscription pending deliveries"
  - "Webhook persistence hooks for selected auth, account, organization-membership, and service-account mutations"
  - "Postgres-backed rollback proof showing webhook persistence shares fate with the outer domain transaction"
affects: [webhook-dispatch, auth-registration, account-lifecycle, memberships, service-accounts]
tech-stack:
  added: []
  patterns: [ecto-multi append, durable outbox rows, explicit step ids, transaction co-fate]
key-files:
  created:
    - lib/sigra/webhooks/dispatcher.ex
    - test/sigra/webhooks_dispatcher_test.exs
    - test/sigra/webhooks_audit_atomicity_test.exs
  modified:
    - lib/sigra/webhooks.ex
    - lib/sigra/auth.ex
    - lib/sigra/account.ex
    - lib/sigra/organizations.ex
    - lib/sigra/service_accounts.ex
key-decisions:
  - "Dispatcher persistence stays library-owned and composable through `Sigra.Webhooks.append_dispatch_multi/5` rather than hiding nested transactions."
  - "Subscription matching is explicit: only enabled rows whose `event_types` include the exact public event name receive pending deliveries."
  - "Webhook persistence failures return normal transaction errors and roll back the outer mutation instead of crashing or partially committing."
patterns-established:
  - "Future event sources should append webhook persistence via explicit step ids so Multi keys stay collision-free."
  - "Webhook context should be built through `Sigra.Webhooks.context/2` so payload actor/org/request metadata stays normalized."
requirements-completed: [WH-01]
duration: 1 session
completed: 2026-05-06
---

# Phase 97 Plan 3: Durable Dispatch Summary

**Dispatcher persistence plus transaction-safe auth and identity hooks**

## Performance

- **Duration:** 1 session
- **Completed:** 2026-05-06
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments

- Added `Sigra.Webhooks.Dispatcher` to build the public webhook event row plus one pending delivery row per matching enabled subscription.
- Extended `Sigra.Webhooks` with `matching_subscriptions/2`, `dispatch_multi/4`, `append_dispatch_multi/5`, and `context/2` so callers can compose durable webhook persistence into existing outer transactions.
- Hooked selected lifecycle mutations into the durable seam:
  `Sigra.Auth.register/3`, `Sigra.Account.confirm_email_change/3`, `Sigra.Account.execute_deletion/3`, organization membership add/remove/role-change flows, and service-account create/revoke flows.
- Hardened `Sigra.Auth.register/3` so failures from later webhook steps return normal errors instead of crashing on unmatched multi results.
- Added unit coverage for dispatcher matching/composition and Postgres-backed rollback proof showing a failed delivery insert rolls back the user insert and webhook event row together.

## Files Created/Modified

- `lib/sigra/webhooks/dispatcher.ex` - Pure Multi builder for subscription lookup, event persistence, and delivery fan-out.
- `lib/sigra/webhooks.ex` - Public composition helpers and normalized payload context builder.
- `lib/sigra/auth.ex` - User-registration webhook persistence and safe error propagation.
- `lib/sigra/account.ex` - Email-confirmation and account-deletion webhook hooks.
- `lib/sigra/organizations.ex` - Membership lifecycle webhook hooks plus optional webhook config plumbing.
- `lib/sigra/service_accounts.ex` - Service-account create/revoke webhook hooks.
- `test/sigra/webhooks_dispatcher_test.exs` - Dispatcher matching, persistence, and outer-transaction composition coverage.
- `test/sigra/webhooks_audit_atomicity_test.exs` - Postgres-backed co-fate tests for webhook persistence inside registration.

## Decisions Made

- The dispatcher persists the public payload contract from Plan 02 directly into the event row so later delivery/signature code does not need to rebuild payloads from domain structs.
- Delivery rows remain separate from event rows and keep distinct `delivery_id` and `webhook_event_id` values for future retry/history work.
- Organization hooks accept an optional `%Sigra.Config{}` or resolver for webhook wiring so generated hosts can opt in without changing the library’s existing config shape elsewhere.

## Deviations from Plan

None in behavior. Verification uncovered one correctness gap in `Sigra.Auth.register/3` error handling, and the implementation was tightened before completion.

## User Setup Required

None.

## Next Phase Readiness

- Plan 04 can now enqueue and execute async delivery from persisted `webhook_events` and `webhook_deliveries` rows without redesigning transaction ownership.
- The signature/worker phase can treat the persisted payload as the contract of record.

## Self-Check

PASSED

- `mix compile --warnings-as-errors`
- `mix test test/sigra/webhooks_dispatcher_test.exs --no-color`
- `mix test test/sigra/webhooks_audit_atomicity_test.exs --no-color`
- `rg -n "webhook_event|webhook_delivery|event_id|delivery_id|pending" lib/sigra test/sigra/webhooks_*`

---
*Phase: 97-webhook-subscription-registry-signed-dispatcher-contract*
*Completed: 2026-05-06*
