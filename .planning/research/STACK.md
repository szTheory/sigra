# Stack Research — v1.22 Webhooks

## Recommended stack additions

- **Persistent webhook tables in Sigra-managed schemas**
  - subscription registry
  - event/outbox record
  - delivery-attempt history
- **HMAC-SHA256 signing using OTP crypto**
  - no new third-party signing dependency needed
- **Durable background delivery worker**
  - reuse Sigra's existing Oban-aware operational model where asynchronous delivery is enabled
  - if webhook delivery is configured, background execution should be explicit and testable rather than hidden
- **Generated admin LiveView on existing admin surface**
  - aligns with Sigra's library + generator split and existing organization/admin patterns

## Why this fits Sigra

- Sigra already owns the auth-domain events worth emitting.
- Sigra already has admin and organization UX patterns that a webhook management UI can reuse.
- Sigra already has optional async infrastructure patterns (`delivery_mode`, Oban, `mix sigra.doctor`) that can inform webhook execution semantics.

## Likely implementation surfaces

- library:
  - delivery schema and dispatcher behavior
  - signing module
  - retry / dead-letter orchestration
- generated host:
  - schema/context wrappers
  - admin LiveView and routes
  - configuration examples and doctor coverage

## Constraints

- Do not require adopters to fork generated code for basic webhook use.
- Do not block the original auth transaction on remote endpoint response time.
- Keep signing and verification contract simple and documented.
