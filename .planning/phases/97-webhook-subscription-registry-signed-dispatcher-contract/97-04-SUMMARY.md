---
phase: 97-webhook-subscription-registry-signed-dispatcher-contract
plan: 4
subsystem: webhooks
tags: [webhooks, signature, worker, oban, optional-deps]
requires: [97-01, 97-02, 97-03]
provides:
  - "Executable HMAC signature helper for the Phase 97 webhook header contract"
  - "Oban-backed async webhook delivery worker with explicit dependency gating"
  - "Installer/runtime guidance that makes the async queue requirement visible"
affects: [webhook-signatures, webhook-worker, optional-dependencies, install-guidance]
tech-stack:
  added: []
  patterns: [dual worker module fallback, versioned hmac header, async-only delivery, dependency-honest enqueue]
key-files:
  created:
    - lib/sigra/webhooks/signature.ex
    - lib/sigra/workers/webhook_delivery.ex
    - test/sigra/webhooks_signature_test.exs
    - test/sigra/workers/webhook_delivery_test.exs
  modified:
    - lib/sigra/webhooks.ex
    - lib/sigra/optional_deps.ex
    - lib/sigra/install/features/core.ex
key-decisions:
  - "Each request signs `delivery_id.timestamp.raw_body` and emits fixed `Sigra-Webhook-*` headers under a versioned `v1=` signature scheme."
  - "Webhook delivery remains async-only: enqueueing is blocked by `OptionalDeps.ensure_available!/2` when hosts enable webhooks without Oban."
  - "Jobs store only `delivery_id`; the worker reloads delivery, event payload, and signing secret at perform time so raw payloads and secrets do not enter the jobs table."
patterns-established:
  - "Receiver documentation and future verification helpers should consume `Sigra.Webhooks.Signature` rather than duplicating canonicalization logic."
  - "Worker-side HTTP dispatch uses an injected requester hook for tests while defaulting to `:httpc` in production."
requirements-completed: [WH-01]
duration: 1 session
completed: 2026-05-06
---

# Phase 97 Plan 4: Signature + Worker Summary

**Async delivery seam, fixed signing contract, and dependency-honest worker gating**

## Performance

- **Duration:** 1 session
- **Completed:** 2026-05-06
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Added `Sigra.Webhooks.Signature` to centralize header names, canonical string construction, versioned HMAC signing, and tolerance-based verification with constant-time comparison.
- Added `Sigra.Workers.WebhookDelivery` in the same dual-module pattern as other optional Oban workers: the Oban-backed branch performs async delivery, and the stub branch raises the tagged missing-dependency error on enqueue.
- Updated webhook library helpers so delivery enqueueing checks the `:webhook_delivery` optional-dependency contract before creating runnable jobs.
- Extended install/runtime messaging and optional-deps remediation so hosts enabling webhooks get explicit guidance about adding Oban and configuring the `sigra_webhooks` queue.
- Added focused tests for signature canonicalization/verification and worker behavior, including async gating, signed outbound requests, and safe classification of transport/http failures.

## Files Created/Modified

- `lib/sigra/webhooks/signature.ex` - Canonical string builder, header helper, signer, and verifier for the webhook contract.
- `lib/sigra/workers/webhook_delivery.ex` - Async-only delivery worker that loads persisted state, signs the raw JSON payload, issues the HTTP request, and marks deliveries delivered.
- `lib/sigra/webhooks.ex` - Delivery enqueue helper now enforces the optional-dependency boundary explicitly.
- `lib/sigra/optional_deps.ex` - Webhook-delivery remediation now points at the webhook-specific install guidance.
- `lib/sigra/install/features/core.ex` - Added webhook-delivery remediation and post-install guidance for the `sigra_webhooks` queue.
- `test/sigra/webhooks_signature_test.exs` - Contract tests for header names, canonical input, signature parsing, and tolerance failures.
- `test/sigra/workers/webhook_delivery_test.exs` - Worker tests for dependency gating, signed dispatch, and failure handling.

## Decisions Made

- The signature timestamp is represented as unix seconds in the header contract and validated against an explicit tolerance window.
- Delivery jobs are single-attempt in Phase 97; retry/dead-letter semantics remain deferred to later work instead of being implied prematurely.
- The worker updates durable delivery state only after a successful 2xx HTTP response and treats non-2xx or transport failures as explicit worker errors rather than synchronous fallbacks.

## Deviations from Plan

None.

## User Setup Required

None.

## Next Phase Readiness

- Plan 05 can now document the exact receiver verification contract and write integration proof against the real persisted rows plus worker-ready dispatch seam.
- Future retry/history work has stable header names, raw-body signing rules, and a dedicated async worker boundary to build on.

## Self-Check

PASSED

- `mix compile --warnings-as-errors`
- `mix test test/sigra/webhooks_signature_test.exs --no-color`
- `mix test test/sigra/workers/webhook_delivery_test.exs --no-color`
- `mix test test/sigra/install/features/core_post_instructions_test.exs --no-color`
- `rg -n "Sigra-Webhook-(Id|Timestamp|Signature)|delivery_id\\.timestamp\\.raw_body|ensure_available!" lib/sigra test/sigra`

---
*Phase: 97-webhook-subscription-registry-signed-dispatcher-contract*
*Completed: 2026-05-06*
