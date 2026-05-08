---
phase: 105-webhook-egress-policy-and-deployment-controls
plan: 01
subsystem: webhooks
tags: [webhooks, egress-policy, ssrf, worker, validation]
requires:
  - phase: 98-reliable-delivery-pipeline
    provides: durable delivery rows, retry semantics, and async worker execution
provides:
  - shared endpoint policy evaluator for subscription-save and worker-send time
  - truthful local policy failure persistence with stable terminal reasons
  - resolver and callback seams for deterministic tests and deployment-specific policy
affects: [phase-105-plan-02, phase-105-plan-03, generated-host-webhooks]
tech-stack:
  added: []
  patterns: [dual enforcement, resolve-all-A-AAAA, truthful local denial persistence]
key-files:
  created:
    - .planning/phases/105-webhook-egress-policy-and-deployment-controls/105-01-SUMMARY.md
    - lib/sigra/webhooks/endpoint_policy.ex
  modified:
    - lib/sigra/config.ex
    - lib/sigra/webhooks.ex
    - lib/sigra/webhooks/retry_policy.ex
    - lib/sigra/workers/webhook_delivery.ex
    - test/sigra/webhooks_test.exs
    - test/sigra/workers/webhook_delivery_test.exs
key-decisions:
  - "Subscription-save validation and worker-send validation both route through the same endpoint policy engine."
  - "Blocked destinations persist as local policy failures instead of synthetic HTTP or transport failures."
  - "Hostname evaluation requires every resolved A/AAAA answer to pass, so mixed public/private answers fail closed."
patterns-established:
  - "Generated hosts can inject deployment-specific denials through config.webhooks[:endpoint_policy] while the library keeps timing and persistence ownership."
  - "Tests use endpoint_resolver seams for deterministic hostname classification without live DNS dependency."
requirements-completed: [WH-06]
duration: resumed execution pass
completed: 2026-05-07
---

# Phase 105 Plan 01: Endpoint Policy Core Summary

Implemented the core webhook endpoint policy engine, wired it into both subscription validation and worker execution, and verified truthful blocked-delivery persistence.

## Accomplishments

- Added `Sigra.Webhooks.EndpointPolicy` for strict URI parsing, embedded-credential rejection, A/AAAA resolution, and special-address blocking.
- Routed `Sigra.Webhooks.subscription_changeset/3` through the shared policy engine so unsafe endpoints fail with changeset-visible errors.
- Added a pre-send policy gate to `Sigra.Workers.WebhookDelivery` and classified denials as `local_policy_error` with stable terminal reasons.
- Extended test coverage for write-time denials, mixed-answer hostname evaluation, callback denials, and blocked-vs-allowed worker behavior.

## Verification

PASSED

- `mix compile --warnings-as-errors`
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_test.exs test/sigra/workers/webhook_delivery_test.exs --no-color`

## Notes

- This plan executed on a dirty worktree, so no atomic task commits were created.
- The local `gsd-sdk` install in this workspace does not expose the documented `query` subcommands, so phase tracking automation was handled manually.
