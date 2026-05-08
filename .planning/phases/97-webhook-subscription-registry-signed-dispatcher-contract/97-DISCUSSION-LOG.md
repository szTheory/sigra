# Phase 97: Webhook subscription registry + signed dispatcher contract - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-06
**Phase:** 97-webhook-subscription-registry-signed-dispatcher-contract
**Areas discussed:** event catalog, payload contract, signature contract, subscription model, dispatch seam

---

## Event catalog

| Option | Description | Selected |
|--------|-------------|----------|
| Curated resource-oriented auth catalog with stable snapshots | Small public catalog, public resource serializers, async durable events | ✓ |
| Thin notification catalog | `type` + ids only; consumers fetch more data later | |
| Audit/flow-oriented catalog | Mirror internal audit-style auth events and flow branches | |

**User's choice:** Delegated to agent; locked the curated resource-oriented catalog.
**Notes:** Recommendation emphasized stable public auth/identity facts, not audit-row leakage and not fetch-later-by-default. Initial families kept narrow and factual.

---

## Payload contract

| Option | Description | Selected |
|--------|-------------|----------|
| Thin fact envelope | Minimal payload, assumes canonical fetch API | |
| Stable domain envelope + public object snapshot | Stable envelope, self-contained public snapshot, public context objects | ✓ |
| Snapshot + change hints | Snapshot plus narrow `changes` metadata for update events | |
| CloudEvents wrapper | Generic event wrapper around Sigra-specific data | |

**User's choice:** Delegated to agent; locked stable envelope + public snapshot.
**Notes:** `changes` may be added only as a narrow list of public field names on update events. No previous values, no raw audit metadata, no direct Ecto/audit serialization.

---

## Signature contract

| Option | Description | Selected |
|--------|-------------|----------|
| Body-only HMAC | Single signature header over raw body only | |
| Timestamp + payload HMAC | Stripe-like timestamp plus body signature | |
| Signed envelope with id/timestamp/signature headers | Versioned HMAC over delivery id, timestamp, and raw body | ✓ |

**User's choice:** Delegated to agent; locked the signed-envelope contract.
**Notes:** Uses `Sigra-Webhook-Id`, `Sigra-Webhook-Timestamp`, and `Sigra-Webhook-Signature`; replay awareness and rotation support are part of the contract, not optional add-ons.

---

## Subscription model

| Option | Description | Selected |
|--------|-------------|----------|
| Broad wildcard subscription | One broad "all events" scope, including future additions | |
| Explicit event selection | Every subscription stores an explicit chosen event list | |
| Hybrid preset model | UI presets expand to an explicit stored event list | ✓ |
| Per-event normalized rules | Heavier rule engine with future filter slots | |

**User's choice:** Delegated to agent; locked the hybrid preset model.
**Notes:** Stored scope is always concrete. Admin UX can offer presets and "all current events", but never future-expanding wildcard semantics.

---

## Dispatch seam

| Option | Description | Selected |
|--------|-------------|----------|
| Enqueue / outbox only | Persist events only; define dispatch later | |
| Pluggable dispatcher behaviour | Host-extensible transport abstraction | |
| Immediate direct delivery | Persist and send remote HTTP directly from the auth path or immediately after | |
| Hybrid persisted event + delivery records with library-owned async dispatcher | Persist business mutation, event row, and pending delivery rows first; dispatch async from durable state | ✓ |

**User's choice:** Delegated to agent; locked the hybrid persisted seam.
**Notes:** Webhooks enabled should require honest async infrastructure; no sync fallback and no remote HTTP inside the auth transaction.

---

## the agent's Discretion

- Exact serializer module names and queue names
- Exact Ecto enum/status field names
- Exact object field lists within the locked public-contract boundaries
- HTTP client and worker-module organization

## Deferred Ideas

- Replay/resend UX and dead-letter operations
- Secret overlap rotation windows
- High-noise security-signal webhooks
- Generalized custom host-domain event publishing
