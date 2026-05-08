---
status: complete
mode: shift-left
phase: 97-webhook-subscription-registry-signed-dispatcher-contract
source:
  - 97-01-SUMMARY.md
  - 97-02-SUMMARY.md
  - 97-03-SUMMARY.md
  - 97-04-SUMMARY.md
  - 97-05-SUMMARY.md
started: 2026-05-06T00:00:00Z
updated: 2026-05-06T00:00:00Z
human_steps_required: 0
automation_deferred: []
---

## Current Test

[testing complete]

## Automation Map

### 1. Webhook Foundation Contract
expected: `Sigra.Config`, `Sigra.OptionalDeps`, and `Sigra.Webhooks` expose explicit webhook config, dependency gating, and subscription CRUD/validation with generated-host schema support.
evidence:
- `mix compile --warnings-as-errors`
- `mix test test/sigra/webhooks_test.exs --no-color`
- `mix test test/sigra/config_test.exs --no-color`
- `mix test test/sigra/optional_deps_test.exs --no-color`
- `mix test test/sigra/install/generator_wiring_test.exs --no-color`
result: pass

### 2. Public Event Catalog And Payload Contract
expected: The public webhook catalog is curated and stable, and payload builders/serializers expose only the documented public envelope and object fields.
evidence:
- `mix test test/sigra/webhooks_event_catalog_test.exs --no-color`
- `mix test test/sigra/webhooks_payload_test.exs --no-color`
result: pass

### 3. Durable Event And Delivery Persistence
expected: Selected lifecycle mutations persist one public webhook event plus one pending delivery per matching enabled subscription, and those writes share fate with the outer transaction.
evidence:
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_dispatcher_test.exs --no-color`
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_audit_atomicity_test.exs --no-color`
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs --no-color`
result: pass

### 4. Signed Async Delivery Worker
expected: The webhook worker enforces the async-only optional dependency boundary, signs `delivery_id.timestamp.raw_body` into the fixed `Sigra-Webhook-*` header contract, and marks successful deliveries durably.
evidence:
- `mix test test/sigra/webhooks_signature_test.exs --no-color`
- `mix test test/sigra/workers/webhook_delivery_test.exs --no-color`
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs --no-color`
result: pass

### 5. Receiver Docs And Generated-Host Wiring
expected: The checked-in docs and generated-host fixture match the implementation contract for headers, raw-body capture, dedupe identifiers, queue wiring, and tolerance settings.
evidence:
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/install/generator_wiring_test.exs --no-color`
- `rg -n "Sigra-Webhook-|body_reader|delivery_id|event_id|schema_version|pending" guides/flows/webhooks.md guides/recipes/webhook-verification.md test/sigra/webhooks_integration_test.exs`
result: pass

## Tests

### 1. Webhook Foundation Contract
expected: `Sigra.Config`, `Sigra.OptionalDeps`, and `Sigra.Webhooks` expose explicit webhook config, dependency gating, and subscription CRUD/validation with generated-host schema support.
result: pass

### 2. Public Event Catalog And Payload Contract
expected: The public webhook catalog is curated and stable, and payload builders/serializers expose only the documented public envelope and object fields.
result: pass

### 3. Durable Event And Delivery Persistence
expected: Selected lifecycle mutations persist one public webhook event plus one pending delivery per matching enabled subscription, and those writes share fate with the outer transaction.
result: pass

### 4. Signed Async Delivery Worker
expected: The webhook worker enforces the async-only optional dependency boundary, signs `delivery_id.timestamp.raw_body` into the fixed `Sigra-Webhook-*` header contract, and marks successful deliveries durably.
result: pass

### 5. Receiver Docs And Generated-Host Wiring
expected: The checked-in docs and generated-host fixture match the implementation contract for headers, raw-body capture, dedupe identifiers, queue wiring, and tolerance settings.
result: pass

## Summary

total: 5
passed: 5
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

none
