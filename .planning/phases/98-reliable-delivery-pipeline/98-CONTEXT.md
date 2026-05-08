# Phase 98: Reliable delivery pipeline - Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Make Sigra's persisted webhook deliveries operationally trustworthy by extending the Phase 97 event-and-delivery seam with bounded retries, durable attempt history, and visible dead-letter outcomes. This phase decides how failed deliveries are retried, when they stop retrying, what history is preserved, and how terminal failures are represented from persisted state.

**Explicitly in scope:**
- per-subscription event filtering remains the routing gate at delivery time
- bounded retry policy for retryable failures
- durable per-attempt history
- dead-letter state and terminal failure classification
- proving auth and identity operations still succeed while downstream endpoints fail

**Explicitly out of scope:**
- manual replay or resend UX
- separate dead-letter queue product surface
- host-configurable retry-policy knobs
- automatic subscription disablement on repeated delivery failure
- retention/pruning policy beyond leaving the schema ready for later cleanup work

</domain>

<decisions>
## Implementation Decisions

### Retry policy
- **D-98-01 — Sigra owns the delivery retry contract, not raw Oban defaults.** Webhook reliability must be modeled in Sigra's persisted delivery state rather than delegated to generic `oban_jobs` retry semantics. Oban remains the execution engine, but Phase 98 semantics live in `webhook_deliveries` plus attempt history.
- **D-98-02 — Keep each queued delivery execution single-shot.** `Sigra.Workers.WebhookDelivery` should continue to treat each queued run as one delivery attempt, while Sigra itself decides whether to enqueue the next attempt. Do not rely on worker-level `max_attempts` to express the public delivery contract.
- **D-98-03 — Use a fixed bounded retry schedule with six total attempts.** The first queued send is attempt 1. On retryable failure, later attempts follow a documented nominal schedule of `1 minute`, `5 minutes`, `15 minutes`, `1 hour`, and `3 hours`, for six total attempts across roughly four hours.
- **D-98-04 — Retry budget is fixed in v1.22.** Do not expose host-configurable retry counts or backoff curves in Phase 98. A stable built-in policy is the least surprising contract for a library-first auth system.
- **D-98-05 — Retry timing may honor receiver backpressure without changing the attempt budget.** When a retryable response includes `Retry-After` (especially `429`, optionally `503`), Sigra may schedule the next attempt later than the nominal slot, but must not add extra attempts beyond the six-attempt budget.

### Failure classification
- **D-98-06 — Use class-based retryability.** Retry transport failures, DNS/connect/TLS failures, client timeouts, `408`, `429`, and `5xx` responses. Treat other `4xx` responses as terminal client-side failures and dead-letter them immediately.
- **D-98-07 — Local invariant failures are terminal and visible, not silent cancels.** Missing delivery rows, disabled subscriptions, invalid signing secrets, malformed local endpoint state, or other host-side invariants should not consume retry budget, but they must still leave durable terminal state that operators can inspect later.
- **D-98-08 — Fresh signature timestamp per attempt.** Every retry signs a fresh request with a new `Sigra-Webhook-Timestamp`; stable `delivery_id` remains the dedupe key, but each attempt is a new wire send.
- **D-98-09 — Delivery history must distinguish retryable vs terminal outcomes explicitly.** Do not collapse everything into `:transport_error` or generic `failed`. Persist bounded categories that make it obvious whether another retry is pending, whether the receiver returned a permanent client error, or whether the local host misconfigured the webhook pipeline.

### Attempt history model
- **D-98-10 — Use a hybrid history model.** Keep `webhook_deliveries` as the canonical operational row and add a new append-only `webhook_delivery_attempts` child table for forensic truth.
- **D-98-11 — Delivery rows carry denormalized current-state fields.** Extend `webhook_deliveries` with summary fields such as status, attempt count, last attempt timestamps, next attempt time, last HTTP status, last error category, and terminal/dead-letter markers so operator and admin queries stay cheap.
- **D-98-12 — Attempt rows are append-only and authoritative for the timeline.** Each actual send attempt inserts a durable child row rather than overwriting history on the parent delivery. Phase 99 should be able to reconstruct the sequence of attempts without reading queue internals.
- **D-98-13 — Attempt rows snapshot the targeted endpoint and result shape, not secrets.** Persist the attempted endpoint URL, started/finished timestamps, response status when present, retryability classification, optional `Retry-After`, and a short bounded error summary. Do not persist signing secrets or rely on current subscription state to explain old attempts.
- **D-98-14 — Parent summary and child attempt insertion must share one transaction.** Updating `webhook_deliveries` and inserting a `webhook_delivery_attempts` row in separate commits is forbidden; the dashboard view and the audit trail must not diverge.

### Dead-letter behavior
- **D-98-15 — Dead-letter is an in-place terminal delivery state.** Keep the canonical record in `webhook_deliveries` and mark it with a terminal status such as `dead_lettered`; do not move the delivery into a separate dead-letter table or queue in Phase 98.
- **D-98-16 — Dead-letter state includes structured terminal classification.** Add bounded terminal categories and reasons to the delivery row, for example transport, timeout, `http_4xx_permanent`, `http_5xx_exhausted`, local configuration, or local state inconsistency. Free-form text may exist only as a short supplemental detail, not as the primary contract.
- **D-98-17 — Retry exhaustion must be visible without disabling the subscription.** A dead-lettered delivery means this specific event/subscription lineage stopped retrying. It does not automatically disable the subscription or change user intent.
- **D-98-18 — No separate replay subsystem in Phase 98.** The data model should make future manual replay or resend possible, but Phase 98 itself stops at inspectable dead-letter state.

### Cohesion with Phase 97 and Phase 99
- **D-98-19 — Phase 98 extends the Phase 97 persisted seam instead of replacing it.** `webhook_events` remain the stable public payload source, `webhook_deliveries` remain the per-subscription lineage row, and Phase 98 layers retry state and attempt history onto that model.
- **D-98-20 — The future admin UX drives the persistence shape now.** Delivery history must be explainable from Sigra-owned tables alone. Phase 99 should not need to depend on Oban job internals, queue error blobs, or log scraping to show what happened.
- **D-98-21 — Persisted state must answer the operator questions directly.** For any delivery, downstream agents should be able to show: what event was being sent, which endpoint was targeted, how many attempts happened, what the last outcome was, whether another retry is scheduled, and why the delivery dead-lettered if it stopped.

### User preference carried forward
- **D-98-22 — Delegated product/architecture decisions should synthesize to one recommendation set by default.** When the user delegates gray-area decisions, downstream GSD work should do the research, choose the coherent recommendation set, and surface only choices that materially change the public API, security model, or generated-host contract.

### the agent's Discretion
- Exact schema field names for status, attempt-number, and reason columns
- Exact enum values for retryable and terminal categories, as long as they stay bounded and operator-readable
- Whether the next attempt is scheduled by explicit enqueue timestamp fields, Oban `schedule_in`, or a small coordinator helper
- Exact truncation rules for stored error detail text
- Exact indexing strategy for attempt-history queries, as long as Phase 99 can query recent failures cheaply

</decisions>

<specifics>
## Specific Ideas

- Treat webhooks as a durable systems-integration surface, not as generic background jobs.
- Use a nominal six-attempt schedule over roughly four hours because it is easy to explain, bounded, and strong enough to survive common transient outages without turning the library into a multi-day delivery SaaS.
- Preserve one canonical delivery row for the current status and one append-only attempts ledger for the historical timeline.
- Prefer simple failure classes that operators can reason about immediately: retryable transport/backpressure/server failure vs terminal client/local failure.
- Keep the `delivery_id` stable across retries and generate a fresh signature timestamp per attempt.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone framing and requirements
- `.planning/PROJECT.md` — v1.22 milestone goal, DX/product-trust framing, and library-first intent
- `.planning/REQUIREMENTS.md` — `WH-02` requirement framing and explicit out-of-scope list
- `.planning/ROADMAP.md` — Phase 98 goal, dependency shape, and success criteria
- `.planning/STATE.md` — active milestone framing and current workflow position

### Prior webhook contract and research
- `.planning/phases/97-webhook-subscription-registry-signed-dispatcher-contract/97-CONTEXT.md` — locked Phase 97 contract decisions that Phase 98 must extend, not replace
- `.planning/phases/97-webhook-subscription-registry-signed-dispatcher-contract/97-RESEARCH.md` — outbox-first delivery model and risks that informed Phase 97
- `.planning/research/SUMMARY.md` — webhook milestone table stakes and watch-outs
- `.planning/research/ARCHITECTURE.md` — recommended persisted-state architecture and build order
- `.planning/research/FEATURES.md` — reliability feature table stakes including retry, dead-letter, and per-attempt visibility
- `.planning/research/PITFALLS.md` — webhook failure-mode cautions and operator-surface pitfalls

### Receiver and public-contract docs
- `guides/flows/webhooks.md` — public webhook contract, async-only posture, and Phase 97 non-goals
- `guides/recipes/webhook-verification.md` — receiver-side contract, dedupe expectations, and timestamp/signature behavior

### Existing code and tests
- `.planning/AUDIT-ATOMICITY-DEFAULTS.md` — transaction-discipline defaults relevant to parent-summary plus attempt-row co-fate
- `lib/sigra/webhooks.ex` — public webhook API seam and queue helper entry points
- `lib/sigra/webhooks/dispatcher.ex` — persisted event plus delivery fan-out seam from Phase 97
- `lib/sigra/workers/webhook_delivery.ex` — current single-attempt worker behavior that Phase 98 will extend
- `lib/sigra/config.ex` — current `:webhooks` config surface and optional-dependency posture
- `lib/sigra/optional_deps.ex` — dependency-enforcement patterns for webhook delivery
- `test/sigra/webhooks_integration_test.exs` — Postgres-backed proof of Phase 97 persisted pending deliveries
- `test/sigra/workers/webhook_delivery_test.exs` — current worker result semantics and queue expectations
- `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs` — generated-host table shape that Phase 98 must evolve coherently

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Webhooks` already centralizes public helpers, queue selection, and config validation; Phase 98 should extend this module rather than introducing a second delivery API.
- `Sigra.Workers.WebhookDelivery` already owns the wire-send step and keeps job args limited to `delivery_id`; this is the right place for one-attempt execution, not for hidden multi-attempt policy.
- `Sigra.OptionalDeps` and `Sigra.Config` already make webhook delivery explicit and async-only; retry/history behavior should preserve that same operational honesty.

### Established Patterns
- Sigra prefers library-owned durable state over hidden side effects or best-effort fallbacks.
- Transactional co-fate between related writes is already a project default; delivery summaries and attempt rows should follow the same rule.
- Generated-host UX depends on explicit, inspectable host tables rather than queue-provider internals.

### Integration Points
- `webhook_deliveries` is already the canonical per-subscription lineage row and should become the operator summary row.
- A new `webhook_delivery_attempts` schema/table should hang off `webhook_deliveries` and be queryable for Phase 99 detail views.
- Future admin history in Phase 99 will read from Sigra-owned tables, so planners should not lean on Oban's `errors` array or worker attempt metadata as the primary source of truth.

</code_context>

<deferred>
## Deferred Ideas

- Manual replay/redrive workflows and UI
- Host-configurable retry schedules or policy overrides
- Automatic subscription disablement after repeated terminal failures
- Separate dead-letter queue/table subsystem
- Long-term retention/pruning policy and cleanup jobs for delivered/dead-letter history
- Broader retryable `4xx` allowlists beyond `408` and `429`

</deferred>

---

*Phase: 98-reliable-delivery-pipeline*
*Context gathered: 2026-05-06*
