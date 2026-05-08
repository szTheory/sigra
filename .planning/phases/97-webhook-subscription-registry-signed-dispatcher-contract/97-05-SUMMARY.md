# Plan 97-05 Summary

## Implementation

- Added [guides/flows/webhooks.md](/Users/jon/projects/sigra/guides/flows/webhooks.md) with the Phase 97 feature contract: explicit subscription semantics, public event catalog, payload envelope, `event_id` vs `delivery_id`, `Sigra-Webhook-*` headers, canonical signature input, async-only delivery posture, and out-of-scope retry/history limits.
- Added [guides/recipes/webhook-verification.md](/Users/jon/projects/sigra/guides/recipes/webhook-verification.md) with a Plug/Phoenix receiver recipe covering `body_reader`, raw-body preservation, `Sigra.Webhooks.Signature.verify/4`, constant-time comparison, timestamp tolerance, and delivery-id dedupe.
- Added [test/sigra/webhooks_integration_test.exs](/Users/jon/projects/sigra/test/sigra/webhooks_integration_test.exs) with Postgres-backed proof that `Auth.register/3` persists one public webhook event row plus one `pending` delivery row per matching enabled subscription, and that the persisted delivery can be queued and consumed by `Sigra.Workers.WebhookDelivery` without leaking secret material into job args.
- Extended the generated-host proof in [test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex) and [test/sigra/install/generator_wiring_test.exs](/Users/jon/projects/sigra/test/sigra/install/generator_wiring_test.exs) so the golden accounts context exposes the explicit webhook event catalog and the wiring test asserts queue/tolerance config plus wrapper delegates.
- Fixed [lib/sigra/workers/webhook_delivery.ex](/Users/jon/projects/sigra/lib/sigra/workers/webhook_delivery.ex) to stamp `dispatched_at` at microsecond precision, matching the generated webhook delivery schema's `:utc_datetime_usec` contract surfaced by the new integration proof.

## Verification

- `mix compile --warnings-as-errors`
  - Result: passed
- `mix test test/sigra/webhooks_integration_test.exs --no-color`
  - Result: `2 tests, 0 failures`
- `mix test test/sigra/install/generator_wiring_test.exs --no-color`
  - Result: `34 tests, 0 failures`
- `rg -n "Sigra-Webhook-|body_reader|delivery_id|event_id|schema_version|pending" guides/flows/webhooks.md guides/recipes/webhook-verification.md test/sigra/webhooks_integration_test.exs`
  - Result: passed and matched the expected contract markers in docs and integration proof
