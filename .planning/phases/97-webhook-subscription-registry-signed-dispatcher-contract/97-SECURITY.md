---
phase: 97
slug: webhook-subscription-registry-signed-dispatcher-contract
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-06
---

# Phase 97 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Domain transaction -> generated host persistence | Sigra appends webhook event and delivery writes to the same outer transaction as auth and account mutations. | Public webhook payload snapshots, event ids, delivery ids, endpoint URLs |
| Host config -> async worker queue | Hosts enable webhooks through config and enqueue only persisted delivery ids into the worker boundary. | `delivery_id`, queue metadata, dependency state |
| Worker -> subscriber endpoint | The delivery worker signs and transmits the persisted JSON payload to third-party webhook receivers. | Raw JSON body, `Sigra-Webhook-*` headers, endpoint URL |
| Receiver verification seam | Receivers validate freshness and authenticity against the exact raw body bytes and shared secret. | Shared secret, delivery id, timestamp, raw body |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-97-01 | Spoofing | `Sigra.Webhooks.Signature` | mitigate | Fixed `Sigra-Webhook-Id`, `Sigra-Webhook-Timestamp`, and `Sigra-Webhook-Signature` headers with `v1` HMAC over `delivery_id.timestamp.raw_body`; verification uses constant-time compare. Evidence: `lib/sigra/webhooks/signature.ex`, `test/sigra/webhooks_signature_test.exs`. | closed |
| T-97-02 | Tampering | Signature verification contract | mitigate | The signature covers the exact raw body bytes on the wire, and verification rejects malformed signatures and stale timestamps outside the configured tolerance window. Evidence: `lib/sigra/webhooks/signature.ex`, `guides/recipes/webhook-verification.md`, `test/sigra/webhooks_signature_test.exs`. | closed |
| T-97-03 | Information Disclosure | Worker/job boundary | mitigate | Oban jobs store only `delivery_id`; the worker reloads payload and signing secret at perform time so raw payload bytes and secrets do not enter the jobs table. Evidence: `lib/sigra/workers/webhook_delivery.ex`, `test/sigra/workers/webhook_delivery_test.exs`, `test/sigra/webhooks_integration_test.exs`. | closed |
| T-97-04 | Denial of Service | Optional dependency and runtime gating | mitigate | Webhook delivery is async-only when enabled, and `OptionalDeps.ensure_available!/2` blocks queue-backed delivery when Oban is unavailable instead of silently degrading to synchronous I/O. Evidence: `lib/sigra/optional_deps.ex`, `lib/sigra/webhooks.ex`, `lib/sigra/workers/webhook_delivery.ex`, `test/sigra/workers/webhook_delivery_test.exs`. | closed |
| T-97-05 | Tampering | Subscription destination policy | mitigate | Subscription validation requires absolute HTTPS URLs except narrow localhost HTTP exceptions for development, reducing insecure outbound delivery configuration. Evidence: `lib/sigra/webhooks.ex`, `test/sigra/webhooks_test.exs`. | closed |
| T-97-06 | Tampering | Transaction co-fate for persisted webhook state | mitigate | Webhook event and delivery rows are appended to the caller transaction so failed delivery persistence rolls back the enclosing domain mutation instead of committing partial state. Evidence: `lib/sigra/webhooks.ex`, `lib/sigra/webhooks/dispatcher.ex`, `test/sigra/webhooks_audit_atomicity_test.exs`. | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

No accepted risks.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-06 | 6 | 6 | 0 | Codex (`$gsd-secure-phase 97`) |

---

## Audit Notes

- Verified current mitigation coverage with `mix test test/sigra/webhooks_signature_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/webhooks_audit_atomicity_test.exs --no-color` -> `15 tests, 0 failures`.
- `mix test test/sigra/webhooks_test.exs --no-color` is currently stale against the added `webhook_delivery_attempt_schema` config requirement. This is a verification gap in the generic CRUD test file, not an open threat in the Phase 97 mitigation set.

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-06
