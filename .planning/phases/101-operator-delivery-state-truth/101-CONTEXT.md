# Phase 101: Operator delivery-state truth - Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix the operator-facing webhook query semantics so the subscription index and failures inbox reflect persisted delivery truth correctly before pagination, without inventing a second conflicting state model.

This phase is specifically about truthful admin filtering, counts, and row semantics for `retrying` and `dead_lettered` views. It does not redesign the webhook contract, retry policy, or overall admin IA already locked in Phases 97 through 100.

**Explicitly in scope:**
- filtering webhook subscription rows by persisted delivery state before pagination
- separating subscription configuration state from delivery operational state
- making `retrying` and `dead_lettered` mean distinct things on both subscription and failures surfaces
- aligning row counts, summary chips, and filtered result sets with the same underlying query truth
- regression coverage for the exact filter leaks found in the milestone audit

**Explicitly out of scope:**
- new delivery states or top-level operator product surfaces beyond the current retrying/dead-lettered scope
- replay/redrive tooling
- denormalizing a new subscription-owned health field
- broader dashboard/analytics work
- generated-host proof expansion beyond what depends on truthful operator query behavior

</domain>

<decisions>
## Implementation Decisions

### Subscription index truth model
- **D-101-01 — Keep operational truth on `webhook_deliveries`; do not add a second subscription-owned health field.** The operator truth already lives on persisted delivery rows from Phases 97 and 98. Phase 101 should derive list behavior from that source rather than denormalizing `health_status` onto `webhook_subscriptions`.
- **D-101-02 — Apply delivery-state filtering in SQL before pagination.** The subscription index must filter against the derived latest-delivery state inside the query layer before `Flop` pagination runs. Post-pagination Ruby/Elixir filtering is forbidden for operator-truth filters.
- **D-101-03 — Separate configuration state from delivery state explicitly.** `enabled` remains subscription configuration truth from `webhook_subscriptions`. Operator-facing retry/dead-letter filtering represents delivery truth and should be labeled accordingly rather than overloading the word `status`.
- **D-101-04 — Rename the subscription-index filter concept to `Delivery state`.** The UI and query params should make it obvious that the retrying/dead-lettered control is about delivery behavior, not whether the endpoint is enabled or disabled.

### Delivery-state semantics
- **D-101-05 — `retrying` means retryable in-flight delivery only.** In Phase 101, the retrying view must isolate only persisted retryable current states such as `retry_scheduled`. It must not include `dead_lettered`.
- **D-101-06 — `dead_lettered` means terminal exhausted delivery only.** Terminal dead-letter rows remain distinct from retrying rows across both the subscription index and the failures inbox.
- **D-101-07 — The subscription index headline is driven by the latest delivery row for that subscription.** The row-level operational badge/detail on the subscription list should describe the latest persisted delivery state for that endpoint, not a synthetic worst-ever aggregate over historical deliveries.

### Mixed-state handling
- **D-101-08 — Mixed delivery history belongs to failures/detail surfaces, not to a composite subscription headline.** If one subscription has both retrying and dead-lettered deliveries at the same time, the subscription index shows the latest-delivery headline only. The failures inbox and delivery/subscription detail pages remain the authoritative place for the full mixed-state backlog.
- **D-101-09 — Do not collapse mixed history into a sticky worst-state badge.** A historical dead-lettered delivery must not permanently force the subscription index row into `dead_lettered` after newer deliveries have succeeded or moved back into retrying. This would make the list misleading and noisy.
- **D-101-10 — Do not turn the subscription index into a multi-badge incident dashboard.** The list should stay scannable and idiomatic for Sigra’s LiveView admin surfaces. Richer mixed-state truth belongs on dedicated detail and failure pages.

### Count semantics
- **D-101-11 — Use a hybrid count model because the two surfaces have different row grain.** The subscription index counts subscriptions. The failures inbox counts delivery rows.
- **D-101-12 — Subscription-index chips reflect latest current delivery state per subscription.** The `Retrying` and `Dead lettered` summary chips on the subscription page count subscriptions whose latest persisted delivery is in that state.
- **D-101-13 — Failures-inbox counts and rows reflect delivery backlog directly.** The failures page is delivery-centric, so its totals, pagination, and filtered results should count delivery rows, not subscriptions.
- **D-101-14 — If the failures surface needs cross-subscription context, expose it as secondary copy only.** Copy such as “20 deliveries across 1 subscription” is acceptable, but the primary count on the failures page remains delivery-row truth.

### Query architecture and codebase fit
- **D-101-15 — Follow the existing Sigra admin-query pattern: filter first, decorate second.** The right pattern is the existing `Sigra.Admin.Users.Query` style: perform truthful query filtering first, paginate second, then attach presentation-oriented row decoration.
- **D-101-16 — Summary counts should come from the same semantic base as the page they summarize.** Counts must not be computed from a looser superset than the rows users are looking at. This is a least-surprise rule for all future operator views in this milestone.

### User preference carried forward
- **D-101-17 — Shift routine product/architecture choices left within GSD.** Downstream research, planning, and execution should default to decisive recommendations that preserve operator trust, least surprise, and good DX. Escalate choices to the user only when they materially affect the security model, public/semver contract, or generated-host contract.

### the agent's Discretion
- Exact subquery / join strategy for selecting the latest delivery row per subscription
- Exact query helper/module factoring for shared count logic
- Exact badge copy and microcopy, as long as `enabled` and delivery state stay visibly distinct
- Exact regression-test shape across library and example-host LiveView coverage

</decisions>

<specifics>
## Specific Ideas

- Recommended coherent model for Sigra:
  - subscription list = endpoint-management surface
  - row headline = latest delivery state for that subscription
  - failures inbox = delivery backlog / incident surface
  - delivery and subscription detail pages = full forensic truth
- Label the list filter `Delivery state`, not generic `Status`, so operators are never asked to guess whether the filter means endpoint config or delivery health.
- Treat old dead letters like delivery-history truth, not like a permanent endpoint scarlet letter.
- Keep the index readable; do not add a composite “retrying + dead-lettered + enabled” badge stack as the primary representation.
- Lessons to carry forward from successful webhook products:
  - Stripe gets this mostly right by separating endpoint pages from per-event delivery/attempt history and by showing future retry timing on delivery-specific views.
  - GitHub treats failures as delivery history and redelivery work, not as a blended endpoint-owned status system.
  - Shopify is a useful warning: delivery metrics and troubleshooting matter, but automatic subscription removal after repeated failures is the kind of surprising operator behavior Sigra should avoid copying.
  - Svix reinforces the same architecture boundary: endpoints, messages, and attempts are related but not collapsed into one confusing state model.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone framing and gap evidence
- `.planning/PROJECT.md` — v1.22 operator-trust and DX framing
- `.planning/REQUIREMENTS.md` — `WH-02` and `WH-03` traceability
- `.planning/ROADMAP.md` — Phase 101 goal and success criteria
- `.planning/STATE.md` — current milestone continuity
- `.planning/v1.22-MILESTONE-AUDIT.md` — exact defects this phase closes

### Prior webhook decisions
- `.planning/phases/97-webhook-subscription-registry-signed-dispatcher-contract/97-CONTEXT.md` — persisted event/delivery contract and delivery IDs
- `.planning/phases/98-reliable-delivery-pipeline/98-CONTEXT.md` — retry/dead-letter state model and attempt history
- `.planning/phases/99-admin-and-generated-host-webhook-ux/99-CONTEXT.md` — admin UX intent and operator surfaces
- `.planning/phases/100-production-webhook-dispatch-handoff/100-CONTEXT.md` — confirms this phase is about operator truth, not enqueue handoff

### Existing code and query patterns
- `lib/sigra/admin/webhooks/query.ex` — current subscription-index query defect
- `lib/sigra/admin/webhooks/failures.ex` — current failures-inbox query defect
- `lib/sigra/admin/live/webhook_subscriptions_index_live.ex` — current list/filter/chip semantics
- `lib/sigra/admin/live/webhook_delivery_failures_live.ex` — current retrying/dead-letter failures surface
- `lib/sigra/admin/live/webhook_subscription_show_live.ex` — subscription detail surface that can own richer mixed-state truth
- `lib/sigra/admin/live/webhook_delivery_show_live.ex` — shared delivery detail and attempt timeline
- `lib/sigra/admin/users/query.ex` — established Sigra pattern for filter-first, paginate-second query architecture

### Existing regression surfaces
- `test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs` — list/filter truth coverage
- `test/example/test/example_web/live/admin_webhook_failures_live_test.exs` — failures-inbox truth coverage

### Existing webhook docs
- `guides/flows/webhooks.md` — webhook operator and contract framing
- `guides/recipes/webhook-verification.md` — receiver-side verification boundary

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Admin.Users.Query` already demonstrates the right architectural pattern for applying truthful filters before pagination.
- `Sigra.Admin.Webhooks.Query` already attaches one latest delivery per subscription, which means the repo is structurally close to the correct Phase 101 model.
- `Sigra.Admin.Webhooks.Failures` already treats the failures page as delivery-row based, which is the right grain for backlog triage once the retrying filter is fixed.
- `WebhookSubscriptionShowLive` and `WebhookDeliveryShowLive` already provide dedicated places for richer mixed-state detail, so the index does not need to become overloaded.

### Established Patterns
- Sigra prefers explicit list/detail admin flows over dashboard-heavy abstraction.
- Persisted delivery rows are the operational source of truth; UI should read from them instead of maintaining a second drift-prone health model.
- Flop-backed admin surfaces are expected to derive truthful result sets in-query, not via post-processing hacks.

### Integration Points
- Subscription-index query logic should be fixed in `lib/sigra/admin/webhooks/query.ex`
- Failures-inbox query logic should be fixed in `lib/sigra/admin/webhooks/failures.ex`
- LiveView copy and chips in the webhook index/failures pages should align with the new query semantics
- Example-host LiveView tests should lock the truth model so future phases do not regress it

</code_context>

<deferred>
## Deferred Ideas

- Broader top-level filters for other terminal classes such as HTTP 4xx permanent or local configuration failures
- Dashboard-style aggregate health analytics
- Replay/redrive controls from UI or CLI
- Denormalized endpoint health fields for scale optimization without measured need
- Generated-host proof expansion beyond the operator-truth fixes required for this phase

</deferred>

---

*Phase: 101-operator-delivery-state-truth*
*Context gathered: 2026-05-06*
