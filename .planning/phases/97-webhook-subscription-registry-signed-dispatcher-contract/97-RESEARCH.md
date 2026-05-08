# Phase 97: Webhook subscription registry + signed dispatcher contract - Research

**Researched:** 2026-05-06
**Status:** Ready for planning

## Summary

Phase 97 should establish a durable webhook foundation without pretending delivery reliability is solved in the same slice. The strongest fit for Sigra is an outbox-first design: auth and identity mutations persist a public webhook event row and per-subscription pending delivery rows inside the same local transaction, then an async library-owned worker signs and dispatches those deliveries later. This preserves auth-path reliability, keeps the public contract explicit, and gives Phase 98 a stable persisted model to extend with retries and dead-letter handling.

The codebase already has the building blocks needed for this approach:

- pure `Ecto.Multi` composition and audit-co-fate patterns in `Sigra.Auth`, `Sigra.Organizations`, and `Sigra.Audit`
- optional-dependency enforcement and doctor-facing honesty in `Sigra.OptionalDeps`
- explicit async worker seams in `Sigra.Workers.EmailDelivery` and `Sigra.Workers.AccountDeletion`
- signing and constant-time comparison primitives in `Sigra.Token`

The main missing precedent is a public serializer boundary. Sigra has operator-facing presenters, but no existing external webhook payload module. Phase 97 should introduce that boundary deliberately rather than leaking audit rows or generated schemas as the public contract.

## Recommendations

### 1. Persistence model

Use three generated-host schemas with library orchestrators:

- `WebhookSubscription`
  - durable registry row
  - fields: `endpoint_url`, `enabled`, `event_types`, `signing_secret`, optional descriptive metadata
  - concrete event list only; no wildcard storage semantics
- `WebhookEvent`
  - append-only public event/outbox row
  - fields: stable `event_id`, `type`, `schema_version`, `occurred_at`, serialized public payload snapshot, contextual ids
- `WebhookDelivery`
  - per-subscription delivery lineage row
  - fields: stable `delivery_id`, `webhook_event_id`, `webhook_subscription_id`, state (`pending` for Phase 97), signed-at / dispatched-at placeholders, last error placeholder fields that Phase 98 can extend

This split matches the roadmap and context constraints:

- event ids and delivery ids stay distinct
- auth transaction can persist one event and fan out many deliveries
- Phase 98 can add retries and history on the same delivery rows instead of replacing the model

### 2. Public contract shape

Use an explicit serializer seam under a new namespace, for example:

- `Sigra.Webhooks.EventSerializer`
- `Sigra.Webhooks.Payload`
- resource-specific serializers such as `Sigra.Webhooks.Serializers.User`

Recommended envelope:

```json
{
  "id": "evt_...",
  "type": "user.created",
  "schema_version": "2026-05-06",
  "occurred_at": "2026-05-06T12:34:56Z",
  "data": {
    "object": { ... }
  },
  "context": {
    "actor": { "type": "user", "id": "..." },
    "organization": { "id": "..." },
    "request": { "id": "..." }
  }
}
```

Guidance:

- persist the public payload snapshot, not a pointer to live mutable data
- treat serializers as external contracts, not convenience wrappers around Ecto structs
- include narrow `changes` hints only for `*.updated` events and only for public field names
- keep day-one catalog factual and low-noise: user lifecycle, session lifecycle, organization membership lifecycle, service-account lifecycle

### 3. Signing contract

Introduce a dedicated signing helper such as `Sigra.Webhooks.Signature` with a narrow API:

- `sign(delivery_id, timestamp, raw_body, secret)`
- `verify(headers, raw_body, secret, opts \\ [])`

Recommended wire contract from context:

- `Sigra-Webhook-Id`
- `Sigra-Webhook-Timestamp`
- `Sigra-Webhook-Signature`

Signature input:

- `delivery_id.timestamp.raw_body`

Algorithm:

- HMAC-SHA256 using OTP crypto
- versioned header format: `v1=...`
- constant-time compare through `Sigra.Token.secure_compare/2`

Receiver ergonomics to preserve in docs/tests:

- exact raw-body verification requirements
- stale timestamp behavior with default 300s tolerance
- duplicate delivery dedupe by stable `delivery_id`
- malformed vs stale vs digest-mismatch cases documented clearly

### 4. Dispatcher seam

Do not model webhooks after `Sigra.Delivery`'s `:auto` fallback behavior. Email can degrade to sync delivery; webhooks cannot become an auth-path side effect without violating the Phase 97 contract.

Recommended seam:

- `Sigra.Webhooks.dispatch_multi/…`
  - pure `Ecto.Multi` builder that inserts event row + pending delivery rows
- `Sigra.Webhooks.enqueue_delivery/…` or worker `new/2`
  - explicit async handoff
- `Sigra.Workers.WebhookDelivery`
  - library-owned Oban worker for outbound POST delivery

Dependency posture:

- feature disabled: no Oban requirement
- feature enabled: async worker infrastructure is mandatory and should fail fast through `Sigra.OptionalDeps`
- `mix sigra.doctor` should eventually surface webhook dependency state the same way Phase 95 does for other optional features

### 5. Module boundaries

Recommended Phase 97 implementation surface:

- `lib/sigra/webhooks.ex`
  - public CRUD and orchestration API
- `lib/sigra/webhooks/dispatcher.ex`
  - event persistence + delivery fan-out multi builder
- `lib/sigra/webhooks/signature.ex`
  - signing and verification helpers
- `lib/sigra/workers/webhook_delivery.ex`
  - async outbound dispatcher worker
- `lib/sigra/config.ex`
  - `:webhooks` NimbleOptions section
- `lib/sigra/optional_deps.ex`
  - new enforced webhook async feature spec

Generated host surfaces locked by this phase:

- migration creating webhook tables
- generated schemas for subscription, event, and delivery rows
- host wrapper APIs where needed for future admin UX

### 6. Build order

Recommended implementation sequence for planning:

1. Config + schema + migration foundation
2. Public payload serializers + event catalog constants
3. Atomic event/delivery persistence builders composed into auth-domain writes
4. Signing helper + async worker + optional-dep enforcement
5. Test matrix and receiver-facing docs for the contract

This order minimizes rework because Phases 98 and 99 depend on the persisted model and public contract more than on retry mechanics.

## Planning-Critical Risks

### Public contract drift

If payloads are assembled ad hoc inside workers or auth flows, internal schema churn will leak into the external API. Mitigation: require explicit serializer modules and persist the serialized snapshot.

### Hidden sync fallback

If webhook dispatch inherits email's `:auto` semantics, auth operations may silently start depending on remote endpoint behavior. Mitigation: no sync fallback when webhooks are enabled.

### Event catalog bloat

If Sigra exposes raw audit actions, it will overfit internal implementation details and create noisy low-trust webhooks. Mitigation: curated public catalog with stable resource nouns.

### Weak dedupe story

If only event ids are exposed, per-subscription retries become ambiguous. Mitigation: distinct stable `event_id` and `delivery_id`; sign the delivery id.

## Open Choices That Actually Matter

These should be resolved in planning, not postponed into implementation:

- exact config key layout under `:webhooks`
- exact naming and ownership of serializer modules
- whether pending deliveries are inserted directly in auth-path multis or through a single dispatcher builder composed into those multis

These do not require another discuss loop because they do not alter the already-locked public contract:

- exact module names
- queue names
- exact table/index names
- whether event family names use `organization_membership.*` or the closest existing noun

## Output for Planner

Phase 97 planning should produce a small number of executable plans that cover:

- foundation and generated schema/migration work
- contract and persistence wiring
- worker/signature/optional-dep seams
- tests and docs proving the public verification contract

## RESEARCH COMPLETE
