---
phase: 98-reliable-delivery-pipeline
plan: 1
subsystem: webhooks
tags: [webhooks, reliability, generator, migration, persisted-state]
requires:
  - phase: 97-webhook-subscription-registry-signed-dispatcher-contract
    provides: durable webhook event and delivery rows, generated-host config seam, async worker baseline
provides:
  - "Validated webhook delivery-attempt schema seam in Sigra config/runtime helpers"
  - "Generated-host migration and schemas for delivery summary rows plus append-only attempt history"
  - "Installer templates and golden fixture coverage for the evolved webhook storage contract"
  - "Postgres-backed integration harness coverage for the expanded Phase 98 tables"
affects: [webhook-delivery, install-generator, generated-host, docs-fixtures]
tech-stack:
  added: []
  patterns: [generated-host contract parity, append-only attempt ledger, golden fixture rebless]
key-files:
  created:
    - priv/templates/sigra.install/core/webhook_migration.exs
    - priv/templates/sigra.install/core/webhook_delivery_attempt.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery_attempt.ex
    - test/sigra/webhooks_integration_test.exs
  modified:
    - lib/sigra/config.ex
    - lib/sigra/webhooks.ex
    - lib/sigra/install/features/core.ex
    - priv/templates/sigra.install/core/auth.ex
    - test/fixtures/install_golden/STDOUT.txt
    - test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs
key-decisions:
  - "Retry-state persistence stays generated-host owned: one summary row on `webhook_deliveries`, one append-only ledger on `webhook_delivery_attempts`."
  - "The installer must emit the webhook migration/schema set directly rather than relying on fixture-only drift."
  - "Golden install fixtures were reblessed from actual installer output instead of hand-editing byte-for-byte drift."
patterns-established:
  - "Any generated-host contract change must update both installer templates and the golden fixture barrier in the same slice."
  - "Integration harness assertions should query Sigra-owned delivery tables directly so later retry logic can extend the same proof."
requirements-completed: [WH-02]
duration: 1 session
completed: 2026-05-06
---

# Phase 98 Plan 1: Persisted Delivery Contract Summary

**Webhook delivery summary rows, append-only attempt ledger wiring, and generated-host install output now agree on the Phase 98 persisted reliability model**

## Performance

- **Duration:** 1 session
- **Completed:** 2026-05-06
- **Tasks:** 4
- **Files modified:** 15

## Accomplishments

- Added `webhook_delivery_attempt_schema` to the validated webhook config seam and exposed `Sigra.Webhooks.delivery_attempt_schema!/1` for later runtime orchestration.
- Evolved the generated webhook migration and generated schemas so `webhook_deliveries` acts as the operator summary row while `webhook_delivery_attempts` holds append-only history and orphan terminal issue context.
- Wired the install generator to emit the webhook migration/schema files for fresh installs, then reblessed the golden fixture and normalized STDOUT so `golden_diff_test` reflects real installer output.
- Extended the Postgres-backed integration harness so Phase 98 can create and query the expanded delivery tables before retry orchestration lands.

## Task Commits

1. **Task 1: Extend the webhook config and schema lookup seam for attempt history** - `2254fef`
2. **Task 2: Evolve the generated migration into the Phase 98 persisted reliability model** - `d0d8bbb`
3. **Task 3: Add generated schemas and generated-wrapper wiring for delivery summary and append-only attempts** - `b5bb5ce`
4. **Task 4: Update the Wave 0 Postgres integration harness for the evolved tables** - `df5a04f`

## Files Created/Modified

- `lib/sigra/config.ex` - Validates the new `webhook_delivery_attempt_schema` key.
- `lib/sigra/webhooks.ex` - Exposes runtime lookup for the delivery-attempt schema.
- `lib/sigra/install/features/core.ex` - Emits webhook migration/schema templates and installer guidance for webhook queue setup.
- `priv/templates/sigra.install/core/webhook_*.ex*` - Generated-host webhook migration and schema templates.
- `priv/templates/sigra.install/core/auth.ex` - Generated wrapper config and webhook helper surface.
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts*.ex` - Reblessed generated-host fixture output.
- `test/fixtures/install_golden/STDOUT.txt` - Reblessed normalized installer stdout.
- `test/sigra/install/generator_wiring_test.exs` - Covers the attempt schema and evolved fixture contract.
- `test/sigra/webhooks_integration_test.exs` - Postgres-backed proof for the expanded Phase 98 tables.

## Decisions Made

- Kept dead-letter state on `webhook_deliveries` rather than introducing a separate terminal-state table.
- Preserved a raw `delivery_id` on attempt rows so later worker code can record orphan terminal issues even if the parent row is missing.
- Treated installer output drift as a correctness issue in the generator, not just a fixture mismatch.

## Deviations from Plan

One corrective addition: the plan named generated schemas and golden snapshots, but verification exposed that fresh installs did not emit the webhook files at all. The fix required adding the missing installer template wiring before the golden fixture could be updated honestly.

## Issues Encountered

- `golden_diff_test` failed after the fixture/schema changes because the installer had no webhook template entries. Adding the templates and reblessing the golden fixture resolved the mismatch.

## User Setup Required

None.

## Next Phase Readiness

- Plan `98-02` can now build retry scheduling and durable attempt persistence on top of explicit summary/ledger tables without inventing new storage.
- Fresh generated hosts and the repo fixture baseline now agree on the persisted delivery contract, so later retry behavior can be tested against real install output.

## Self-Check

PASSED

- `mix compile --warnings-as-errors`
- `mix test test/sigra/install/generator_wiring_test.exs --no-color`
- `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs --no-color`
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs --no-color`

---
*Phase: 98-reliable-delivery-pipeline*
*Completed: 2026-05-06*
