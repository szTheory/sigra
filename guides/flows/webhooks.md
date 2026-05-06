# Webhooks

Sigra's webhook feature gives you a durable outbound integration
surface for auth and identity events. Subscriptions are stored locally,
business mutations persist a public webhook event row plus one
subscription-specific delivery row per matching receiver, and delivery stays
async-only through `Sigra.Workers.WebhookDelivery`.

## What Sigra ships

| Layer | Owner | What you get |
| --- | --- | --- |
| Library | Sigra | `Sigra.Webhooks`, `Sigra.Webhooks.Signature`, the curated public event catalog, atomic event/delivery persistence, and the async delivery worker. |
| Generated host | You | `webhook_subscriptions`, `webhook_events`, `webhook_deliveries`, and `webhook_delivery_attempts` tables plus thin wrapper functions on your generated accounts context. |

## Subscription contract

Each subscription stores:

- `endpoint_url` for the receiver.
- `event_types` as an explicit list such as `["user.created", "session.revoked"]`.
- `enabled` as the on/off switch for delivery.
- `signing_secret` used to produce `Sigra-Webhook-Signature`.

Sigra does not store wildcard semantics. New event types are not delivered to
old subscriptions unless you edit their explicit `event_types` list.

Endpoint policy is strict by default:

- Production endpoints must use HTTPS.
- Plain HTTP is accepted only for `localhost`, `127.0.0.1`, or `::1`.

## Event catalog

Sigra ships a small public catalog of durable auth facts:

- `user.created`
- `user.updated`
- `user.deleted`
- `session.created`
- `session.revoked`
- `organization_membership.created`
- `organization_membership.updated`
- `organization_membership.deleted`
- `service_account.created`
- `service_account.revoked`

## Payload shape

Every delivery POST body is JSON with the same stable envelope:

```json
{
  "id": "evt_123",
  "type": "user.created",
  "schema_version": "2026-05-06",
  "occurred_at": "2026-05-06T12:30:00Z",
  "data": {
    "object": {
      "id": "user_123",
      "email": "user@example.com",
      "created_at": "2026-05-06T12:30:00Z"
    }
  },
  "context": {
    "actor": {
      "type": "user",
      "id": "user_123"
    },
    "request": {
      "id": "req_123"
    }
  }
}
```

Important identifiers:

- `event_id` is the stable public event identifier stored in
  `webhook_events.event_id` and exposed as payload `id`.
- `delivery_id` is the stable per-subscription delivery identifier stored in
  `webhook_deliveries.delivery_id` and exposed as `Sigra-Webhook-Id`.

One `event_id` can fan out to many `delivery_id` values.

`schema_version` identifies the public payload contract version, not your app
release number.

For `*.updated` events, Sigra may add `data.changes` with public field names
only. Previous values and internal diff structures are not part of the
contract.

## Delivery headers and signature

Each outbound request includes:

- `Sigra-Webhook-Id`
- `Sigra-Webhook-Timestamp`
- `Sigra-Webhook-Signature`

`Sigra-Webhook-Signature` uses a versioned HMAC value such as:

```text
v1=5f0f3e...
```

The canonical signature input is the exact byte sequence:

```text
delivery_id.timestamp.raw_body
```

Where:

- `delivery_id` is the `Sigra-Webhook-Id` header.
- `timestamp` is the `Sigra-Webhook-Timestamp` unix timestamp.
- `raw_body` is the exact JSON byte string sent on the wire.

Receivers must verify against the raw request body bytes, not a decoded and
re-encoded map. See [Webhook Verification](../recipes/webhook-verification.md).

## Async delivery semantics

Sigra persists webhook state before any remote HTTP attempt:

1. Your auth or identity mutation succeeds locally.
2. Sigra writes one `webhook_events` row.
3. Sigra writes one `webhook_deliveries` row per matching enabled
   subscription.
4. Each delivery row starts in `pending`.
5. `Sigra.Workers.WebhookDelivery` signs and POSTs the persisted payload later.

This is intentionally async-only. If webhooks are enabled, Sigra does not
fallback to synchronous request-path delivery.

## Reliability contract

Phase 98 adds bounded delivery reliability on top of the persisted event and
delivery model:

- Each worker run stays single-shot with `max_attempts: 1`.
- Sigra owns the retry budget in persisted state: six total attempts per
  `delivery_id`.
- The nominal retry schedule is 1 minute, 5 minutes, 15 minutes, 1 hour, and
  3 hours after the failed attempt.
- A receiver `Retry-After` header can delay the next slot, but it never adds
  extra attempts beyond that six-attempt budget.
- `webhook_deliveries` is the cheap current-state summary row.
- `webhook_delivery_attempts` is the append-only, authoritative attempt
  timeline.
- Permanent receiver failures and local invariant failures move the delivery to
  in-place `dead_lettered` state on `webhook_deliveries`.

The parent summary row answers:

- current `status`
- `attempt_count`
- `last_attempted_at`
- `next_attempt_at`
- `last_http_status`
- `last_error_category`
- `terminal_reason`

The child attempt ledger answers:

- when each attempt started and finished
- what endpoint was targeted
- what HTTP status or local failure occurred
- whether the attempt was retryable
- what `Retry-After` delay was honored, if any

## Still out of scope

Phase 98 still does not claim:

- manual replay or resend tooling
- automatic subscription disablement
- a separate dead-letter subsystem
- overlapping signing-secret rotation windows

## Generated host wrapper surface

Generated Phoenix hosts get thin context wrappers around the library API:

```elixir
MyApp.Accounts.list_webhook_subscriptions()
MyApp.Accounts.create_webhook_subscription(attrs)
MyApp.Accounts.update_webhook_subscription(subscription, attrs)
MyApp.Accounts.enable_webhook_subscription(subscription)
MyApp.Accounts.disable_webhook_subscription(subscription)
```

Use `Sigra.Webhooks.public_event_types()` to populate event-type checkboxes or
presets in your admin UI.
