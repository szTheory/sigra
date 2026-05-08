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
- `signing_secret` as the current active secret.
- `next_signing_secret` when a rotation is prepared.
- `rotation_state` plus overlap timestamps and operator metadata for the
  `stable -> prepared -> overlap_active -> completed` lifecycle.

Sigra does not store wildcard semantics. New event types are not delivered to
old subscriptions unless you edit their explicit `event_types` list.

Endpoint policy is strict by default:

- Production endpoints must use HTTPS.
- Plain HTTP is accepted only for `localhost`, `127.0.0.1`, or `::1`.
- Sigra evaluates endpoint policy twice: once when a subscription is saved,
  and again immediately before the worker sends the request.
- Hostnames are resolved at delivery time and every resolved A/AAAA answer must
  pass the policy check. Mixed public/private answers are blocked.
- Blocked deliveries persist as `last_error_category = "local_policy_error"`
  with stable reasons such as `blocked_private_ip`, `blocked_link_local_ip`,
  `blocked_metadata_ip`, `dns_resolution_failed`, or `policy_denied`.
- Generated hosts can add deployment-specific rules through
  `webhook_endpoint_policy/1` without forking Sigra internals.

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

During an active overlap window the same header carries multiple comma-separated
`v1=...` values, one for each currently valid signing secret. Sigra does not
emit a `kid` or any other sender-selected secret hint.

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

## Rotation lifecycle

Phase 103 makes secret rotation overlap-safe:

1. `prepare` stages one next secret while Sigra still signs with the current
   secret only.
2. `start overlap` makes Sigra sign each delivery with both the current and
   next secret.
3. `complete rotation` retires the old secret and keeps only the promoted
   secret active.

Replay protection does not change during this window. Receivers still dedupe
strictly on `delivery_id`, and timestamp tolerance stays unchanged.

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

## Manual replay semantics

Phase 104 adds one recovery path for failed deliveries:

- Replay is an admin-owned action only in Sigra's admin surfaces.
- Replay applies only to eligible `dead_lettered` source rows.
- Replay creates a brand-new child `webhook_deliveries` row with a fresh
  `delivery_id`.
- The original failed source row stays immutable and visible in admin history.
- The replay child starts a fresh attempt ledger at `attempt_count = 0`.
- Receiver dedupe does not change: receivers still key strictly on
  `delivery_id`.

That means the same public event can now appear in admin history as one failed
source delivery plus one replay child delivery. This is truthful lineage, not
an in-place retry reset.

## Still out of scope

Sigra still does not claim:

- a CLI or public API replay contract in this phase
- automatic subscription disablement
- a separate dead-letter subsystem
- arbitrary N-version secret history or scheduler-driven cutover

## Generated host wrapper surface

Generated Phoenix hosts get thin context wrappers around the library API:

```elixir
MyApp.Accounts.list_webhook_subscriptions()
MyApp.Accounts.create_webhook_subscription(attrs)
MyApp.Accounts.update_webhook_subscription(subscription, attrs)
MyApp.Accounts.enable_webhook_subscription(subscription)
MyApp.Accounts.disable_webhook_subscription(subscription)
MyApp.Accounts.webhook_endpoint_policy(context)
```

Use `Sigra.Webhooks.public_event_types()` to populate event-type checkboxes or
presets in your admin UI.

## Generated host setup path

If you install Sigra's admin feature, generated hosts also get
`docs/webhook_receiver_setup.md`. Treat that file as the host-owned checklist
for wiring the receiver route, raw request body capture, `delivery_id` dedupe,
and the prepare -> overlap -> complete rotation lifecycle.
