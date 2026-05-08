---
phase: 104-failed-delivery-replay-controls
plan: 04
subsystem: generated-host-proof
tags: [webhooks, replay, docs, generated-host, proof, delivery-id]
requires:
  - phase: 104-failed-delivery-replay-controls
    provides: replay admin UX, lineage rendering, and replay read models from Plans 01-03
provides:
  - published replay guidance for public and generated-host docs
  - receiver proof harness controls for fail-after-verify and replay lineage correlation
  - canonical generated-host browser proof plus durable evidence bundle
affects: [wh-05, generated-host-webhook-proof, admin-generated-playwright]
tech-stack:
  added: []
  patterns: [receiver dedupe stays on delivery_id, dead-letter replay proof bundle, retry-budget dead-letter handoff]
key-files:
  created:
    - .planning/phases/104-failed-delivery-replay-controls/104-04-SUMMARY.md
    - .planning/uat-evidence/v1.23/webhook-delivery-replay/README.md
    - .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json
  modified:
    - guides/flows/webhooks.md
    - guides/recipes/webhook-verification.md
    - priv/templates/sigra.install/admin/webhook_receiver_setup.md
    - test/example/lib/example/accounts.ex
    - test/example/lib/example_web/controllers/sigra_webhook_controller.ex
    - test/example/lib/example_web/controllers/test_db_probe_controller.ex
    - test/example/test/example_web/controllers/sigra_webhook_controller_test.exs
    - test/example/test/example_web/accounts_webhook_proof_test.exs
    - test/example/priv/playwright/tests/admin-generated.spec.ts
    - test/example/priv/playwright/helpers/adminArtifacts.ts
    - lib/sigra/workers/webhook_delivery.ex
    - lib/sigra/webhooks.ex
    - test/sigra/workers/webhook_delivery_test.exs
key-decisions:
  - "The generated-host proof stays receiver-owned: verification still records receipts by delivery_id, and replay is proven as a fresh child delivery rather than a special receiver-side code path."
  - "Retry-budget exhaustion now dead-letters the summary row immediately instead of leaving the delivery stuck in retry_scheduled after the sixth failed attempt."
  - "The browser proof keys off the durable replay-child signal rendered on delivery detail rather than a transient success flash."
patterns-established:
  - "Generated-host proof bundles correlate source and replay child deliveries with screenshots plus receiver verification timestamps."
  - "Admin replay proof uses the existing DB-probe seam to toggle receiver failure/health and drain the webhook queue deterministically."
requirements-completed: [WH-05]
duration: resumed execution pass
completed: 2026-05-07
---

# Phase 104 Plan 04: Replay Proof and Docs Summary

Closed WH-05 by publishing the replay contract honestly, fixing the retry-budget dead-letter handoff, and proving the full fail -> inspect -> repair -> replay -> succeed path in the generated host.

## Accomplishments

- Updated public and generated-host webhook docs so replay is described as an admin-owned recovery action that creates a fresh child `delivery_id` while preserving the original failed row and receiver dedupe semantics.
- Extended the example receiver proof seam with test-only receiver mode controls, receipt correlation helpers, and proof-bundle queries that expose source/replay/root delivery lineage plus receiver verification timestamps.
- Fixed webhook retry-budget exhaustion so the sixth failed attempt transitions the delivery summary row to `dead_lettered` instead of leaving it stuck in `retry_scheduled`.
- Updated the generated-host Playwright proof to run the canonical recovery story end to end and emit a durable evidence bundle under `.planning/uat-evidence/v1.23/webhook-delivery-replay/`.

## Verification

PASSED

- `mix compile --warnings-as-errors`
- `mix test test/sigra/workers/webhook_delivery_test.exs --no-color`
- `cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/controllers/sigra_webhook_controller_test.exs test/example_web/accounts_webhook_proof_test.exs --no-color`
- `cd test/example/priv/playwright && EXAMPLE_DB_PROBE_ENABLED=1 SIGRA_EXAMPLE_URL=http://localhost:4000 CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= npx playwright test tests/admin-generated.spec.ts --project=admin-generated`
- `test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/README.md`
- `test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json`

## Notes

- `gsd-sdk query` was unavailable during this execution pass, so phase bookkeeping was updated manually after verification.
- The generated-host Playwright lane required deterministic admin/org seed fixtures in the example test database to match its expected runtime contract.
