# Architecture Research — v1.22 Webhooks

## Recommended architecture

1. **Auth operation happens**
   - Sigra completes the business operation first.
2. **Sigra records an internal event/outbox entry**
   - durable local record, separate from remote delivery success
3. **Background worker dispatches deliveries**
   - signs payload
   - POSTs to subscribed endpoint
   - records attempt outcome
4. **Retry / dead-letter policy runs from persisted state**
   - failed deliveries are retried according to policy
   - exhausted deliveries remain inspectable

## Why this architecture matches Sigra

- Sigra already separates library-owned security logic from generated host UX.
- Existing admin surface makes webhook management a natural generated-host feature.
- Existing audit and service-account work suggests adopters will want machine-readable downstream signals, not just internal rows.

## Integration points

- **Audit events**: likely source material for initial event catalog, but webhook events should remain a stable public contract rather than a raw dump of audit rows.
- **Organizations / service accounts**: webhook events should carry org context where applicable.
- **Optional async deps**: webhook dispatch must be explicit about whether Oban or another async path is required when the feature is enabled.

## Suggested build order

1. define public event contract and subscription model
2. implement signing + durable dispatch model
3. implement retries / dead-letter / history
4. wire generated admin and host UX
5. close with end-to-end verification on example/generated hosts
