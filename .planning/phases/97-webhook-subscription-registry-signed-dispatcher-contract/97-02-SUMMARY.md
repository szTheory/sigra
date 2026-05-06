---
phase: 97-webhook-subscription-registry-signed-dispatcher-contract
plan: 2
subsystem: webhooks
tags: [webhooks, public-contract, serializer, event-catalog]
requires: [97-01]
provides:
  - "Canonical public event-name registry for the Phase 97 day-one catalog"
  - "Stable envelope builder with explicit context and optional update-change hints"
  - "Resource-specific serializers that expose public snapshots instead of internal structs"
affects: [webhook-payloads, public-contract, serializers]
tech-stack:
  added: []
  patterns: [explicit serializer boundary, persisted public snapshot, stable webhook envelope]
key-files:
  created:
    - lib/sigra/webhooks/event_catalog.ex
    - lib/sigra/webhooks/payload.ex
    - lib/sigra/webhooks/serializers/user.ex
    - lib/sigra/webhooks/serializers/session.ex
    - lib/sigra/webhooks/serializers/organization_membership.ex
    - lib/sigra/webhooks/serializers/service_account.ex
    - test/sigra/webhooks_event_catalog_test.exs
    - test/sigra/webhooks_payload_test.exs
  modified:
    - lib/sigra/webhooks.ex
key-decisions:
  - "The webhook catalog is resource-oriented and curated rather than mirroring audit action names."
  - "Payloads persist a stable envelope with ISO8601 timestamps and `data.object` snapshots."
  - "Update events may include a narrow `data.changes` list, but serializers never leak private fields or raw internal metadata."
patterns-established:
  - "Future dispatch code should resolve serializers and resources through `Sigra.Webhooks.EventCatalog` rather than inventing event metadata inline."
  - "Webhook payload construction should go through `Sigra.Webhooks.Payload.build/3` so docs, persistence, and signatures share one contract."
requirements-completed: [WH-01]
duration: 1 session
completed: 2026-05-06
---

# Phase 97 Plan 2: Public Contract Summary

**Canonical event catalog, envelope builder, and public serializers**

## Performance

- **Duration:** 1 session
- **Completed:** 2026-05-06
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Added `Sigra.Webhooks.EventCatalog` as the single source of truth for the public day-one webhook event list and serializer lookup.
- Added `Sigra.Webhooks.Payload.build/3` to emit the stable envelope with `id`, `type`, `schema_version`, `occurred_at`, `data.object`, optional `data.changes`, and public context fields.
- Added explicit serializers for users, sessions, organization memberships, and service accounts with narrow public field sets.
- Rewired `Sigra.Webhooks.public_event_types/0` to the catalog so validation and later dispatch paths use one registry.
- Added tests proving the curated catalog and proving internal-only fields like password hashes, tokens, and audit metadata do not leak into webhook payloads.

## Task Commits

1. **Plan 02 payload-contract work** - `d5dc0cd` (`feat`)

## Files Created/Modified

- `lib/sigra/webhooks/event_catalog.ex` - Canonical event registry with resource and serializer metadata.
- `lib/sigra/webhooks/payload.ex` - Stable envelope builder and context normalization logic.
- `lib/sigra/webhooks/serializers/*.ex` - Public snapshot serializers for the Phase 97 resource families.
- `lib/sigra/webhooks.ex` - `public_event_types/0` now delegates to the canonical event catalog.
- `test/sigra/webhooks_event_catalog_test.exs` - Contract tests for the curated event registry.
- `test/sigra/webhooks_payload_test.exs` - Contract tests for envelope shape, context, change hints, and non-leakage.

## Decisions Made

- `schema_version` is pinned centrally in the payload builder so persisted payloads and docs can evolve deliberately rather than implicitly.
- Context remains narrow and public: actor type/id, organization id, and request id only when explicitly known.
- Serializer output uses persisted snapshots rather than fetch-later pointers or raw Ecto dumps.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- None beyond ordinary build-lock contention during test startup.

## User Setup Required

None.

## Next Phase Readiness

- Plan 03 can now persist and fan out webhook event rows using a stable contract instead of assembling payloads ad hoc inside auth flows.
- Phase 97 docs and signature work can reference one exact wire contract.

## Self-Check

PASSED

- `mix compile --warnings-as-errors`
- `mix test test/sigra/webhooks_payload_test.exs --no-color`
- `mix test test/sigra/webhooks_event_catalog_test.exs --no-color`
- `rg -n "user\\.created|session\\.created|organization_membership|service_account|schema_version|occurred_at" lib/sigra/webhooks test/sigra/webhooks_*`
- Verified commit `d5dc0cd` in `git log --oneline --max-count=1`

---
*Phase: 97-webhook-subscription-registry-signed-dispatcher-contract*
*Completed: 2026-05-06*
