# Phase 104: Failed-delivery replay controls - Context

**Gathered:** 2026-05-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Let operators recover from receiver outages by manually replaying dead-lettered outbound webhook deliveries from Sigra-owned control surfaces, while preserving truthful delivery history and creating an auditable new execution path instead of rewriting the old one.

This phase is specifically about operator-triggered replay/redrive for the existing outbound webhook system. It does not redesign the public webhook payload contract, change receiver-side dedupe rules, add bulk replay workflows, invent a new queue-control product, or broaden webhook delivery into a general automation platform.

**Explicitly in scope:**
- replaying eligible dead-lettered deliveries from Sigra-owned operator surfaces
- preserving the original failed lineage while creating a distinct replay lineage
- strict state guards that reject unsafe replay attempts
- truthful operator history and navigation across original and replayed deliveries
- generated guidance and verification that prove receiver recovery end to end

**Explicitly out of scope:**
- replaying successful deliveries
- replaying in-flight or already-scheduled retry deliveries
- batch replay, endpoint-wide redrive, or incident-run abstractions
- a public/self-service replay UI outside global admin
- a same-phase runtime CLI contract
- changing the receiver contract away from `delivery_id`-based dedupe

</domain>

<decisions>
## Implementation Decisions

### Replay surfaces
- **D-104-01 — Ship replay through admin UI in Phase 104, not a same-phase CLI.** The supported operator surface for Phase 104 should be the existing admin webhook UI. Do not expand the public/operator contract to include a new runtime CLI in the same phase.
- **D-104-02 — Keep the replay engine library-owned underneath the admin surface.** The durable replay state transition should live in `Sigra.Webhooks`, with thin admin action wrappers in `Sigra.Admin.Webhooks.Actions`. LiveViews must not own replay business rules directly.
- **D-104-03 — Failures inbox may expose a narrow replay shortcut, but delivery detail is the authority.** Operators should be able to start recovery quickly from the global failures inbox, while the shared delivery detail page remains the canonical place for eligibility, confirmation, lineage, and forensic truth.

### Replay lineage model
- **D-104-04 — Replay creates a new delivery row, not new attempts on the original row.** Phase 104 should not mutate the original delivery back to `pending` or append replay as attempt `N+1`. Replay is a new delivery lifecycle and must get a new `delivery_id`.
- **D-104-05 — Preserve the original failed lineage as immutable truth.** The original delivery row remains failed or dead-lettered. Replay must create a clearly linked child delivery so operators can see both the failed automatic path and the later manual recovery path.
- **D-104-06 — Use explicit self-linked replay lineage metadata on `webhook_deliveries`.** The replayed child row should record its source delivery through a self-reference such as `replayed_from_webhook_delivery_id`, and Phase 104 should also keep a cheap-to-query root lineage pointer rather than requiring recursive reconstruction for common operator views.
- **D-104-07 — Each replay child starts a fresh attempt ledger.** Automatic attempts remain scoped to one delivery row. A replayed child begins at attempt `1` and owns its own `webhook_delivery_attempts` history.
- **D-104-08 — Record operator-trigger metadata on the replayed child.** The replayed delivery should persist who triggered it, when, and from which Sigra-owned surface so later investigation does not depend on inferred timestamps or external logs.

### Safety and eligibility
- **D-104-09 — Replay is allowed only for dead-lettered deliveries in Phase 104.** Do not allow replay from `pending`, in-flight, `retry_scheduled`, or already-`delivered` states. The current retry state model remains truthful and should not be bypassed by ad hoc manual resend.
- **D-104-10 — Replay eligibility within dead-lettered rows is reason-gated.** Allow replay for receiver-side or fixable configuration outcomes that a human may have repaired, such as retry exhaustion after transport/5xx/backpressure or terminal remote 4xx outcomes where the receiver was corrected. Allow local configuration failures only if live preconditions now pass at replay time.
- **D-104-11 — Truth-gap failures are not replayable.** If Sigra cannot honestly reconstruct the original send context, such as missing delivery dependencies or orphaned terminal issue rows, replay must be rejected with an explicit operator-facing error instead of best-effort guessing.
- **D-104-12 — Block double-submit with Sigra-owned persistence rules, not queue semantics alone.** Phase 104 must prevent two operators from opening concurrent replay paths for the same failed source row. Do not rely on Oban uniqueness as the main safety mechanism.
- **D-104-13 — Replay must re-check current preconditions before inserting the child lineage.** If webhook delivery is disabled, the subscription is disabled, or another required runtime invariant still fails, Sigra should reject the replay explicitly instead of enqueueing a doomed child delivery.

### Operator UX and history
- **D-104-14 — Keep replay UX consistent with Sigra’s list/detail admin idiom.** The failures inbox stays a delivery-row triage surface; the shared delivery detail page owns the deeper operational truth and confirmation flow; subscription detail remains secondary for read-only “recent deliveries” context, not the primary replay home.
- **D-104-15 — Show replay lineage as delivery history, not queue internals.** On the original delivery page, operators should see any replay children with their status and links. On a replayed child page, operators should see both the immediate parent and the root failed delivery. Do not bury lineage only in audit logs or attempt rows.
- **D-104-16 — Keep the attempt timeline scoped to one delivery.** The UI must not present replay as “attempt 7” or otherwise merge manual recovery into the transport retry timeline for the original delivery.
- **D-104-17 — Operator errors must be explicit and state-specific.** Sigra should tell the operator exactly why replay is rejected, such as “already delivered,” “still in flight,” “already has a scheduled retry,” “replay already exists,” or “delivery context incomplete.”

### Proof and docs
- **D-104-18 — Verification must prove the full receiver-recovery story.** Phase 104 should show: a delivery fails into dead-letter, the operator inspects truthful history, downstream health is restored, replay creates a new delivery lineage, and the replayed delivery succeeds while the original failed lineage remains visible.
- **D-104-19 — The public receiver contract stays stable.** Replayed deliveries still use Sigra’s normal signed delivery contract and receiver-owned dedupe expectations. Phase 104 must not imply that manual replay changes the published verification boundary.

### User preference carried forward
- **D-104-20 — Shift routine webhook product and architecture choices left within GSD.** Downstream research, planning, and execution should preserve decisive recommendations that optimize for operator trust, least surprise, strong DX, and truthful history. Escalate only changes that materially affect the security model, public webhook contract, semver surface, or generated-host contract.

### the agent's Discretion
- Exact replay lineage field names and indexing strategy, as long as parent/root linkage stays cheap to query
- Exact partial-uniqueness or transactional guard mechanism used to prevent concurrent replay children
- Exact admin copy, badges, and layout for replay lineage sections, provided delivery truth stays explicit
- Exact split between failures-inbox shortcut behavior and delivery-detail confirmation UX
- Exact test decomposition across library, admin LiveView, generated-host, and integration lanes

</decisions>

<specifics>
## Specific Ideas

- Strong external lessons to copy:
  - GitHub-style delivery history as the authority for redelivery investigation
  - Stripe/Svix-style distinction between automatic retries and later manual replay
  - explicit operator action instead of hidden queue poking or silent mutation
- Strong external lessons to avoid:
  - mutating failed rows back into active state
  - replaying already-scheduled retries and racing the queue
  - overloading queue internals as the operator contract
  - surprising subscription disablement or auto-removal after failures
- Coherent Sigra replay story:
  - automatic retry path owns `pending` -> `retry_scheduled` -> `dead_lettered`
  - manual replay starts only after that lifecycle has ended
  - replay inserts a new child delivery with a new `delivery_id`
  - the original failed delivery remains visible and linked
- UX preference:
  - quick replay affordance from the failures inbox for incident speed
  - authoritative confirmation and lineage on the shared delivery detail page
  - no subscription-page-first replay workflow in Phase 104
- DX preference:
  - one library replay API with explicit typed failure reasons
  - thin admin wrappers
  - no same-phase CLI surface unless a future milestone explicitly promotes it

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone framing and requirements
- `.planning/PROJECT.md` — v1.23 milestone framing, operator-trust goals, and the user preference to shift routine decisions left within GSD
- `.planning/REQUIREMENTS.md` — `WH-05` requirement and milestone out-of-scope boundaries
- `.planning/ROADMAP.md` — Phase 104 goal, success criteria, and dependency on Phases 98-103
- `.planning/STATE.md` — current milestone continuity and explicit handoff into Phase 104

### Prior webhook decisions
- `.planning/phases/98-reliable-delivery-pipeline/98-CONTEXT.md` — retry/dead-letter state model, append-only attempt history, and explicit deferral of replay from Phase 98
- `.planning/phases/99-admin-and-generated-host-webhook-ux/99-CONTEXT.md` — admin/generated-host webhook UX boundaries and the explicit deferral of replay tooling from Phase 99
- `.planning/phases/100-production-webhook-dispatch-handoff/100-CONTEXT.md` — initial enqueue contract and the durable handoff into worker execution
- `.planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md` — truthful failures inbox semantics and the rule that mixed-state forensic truth belongs on failures/detail surfaces
- `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-CONTEXT.md` — proof expectations and `delivery_id` correlation across operator and receiver evidence
- `.planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md` — current webhook admin action patterns, replay-safe signing contract, and the explicit deferral of replay/redrive controls into Phase 104

### Existing webhook implementation seams
- `lib/sigra/webhooks.ex` — delivery persistence helpers, enqueue seam, and the right home for a library-owned replay API
- `lib/sigra/webhooks/dispatcher.ex` — canonical insertion shape for new delivery rows
- `lib/sigra/workers/webhook_delivery.ex` — current single-shot worker semantics, retry/dead-letter behavior, and why replay must not race `retry_scheduled`
- `lib/sigra/webhooks/signature.ex` — stable receiver verification contract and `delivery_id` semantics

### Existing admin/operator surfaces
- `lib/sigra/admin/webhooks/actions.ex` — global-admin mutation boundary pattern to extend for replay
- `lib/sigra/admin/webhooks/detail.ex` — current delivery/subscription detail loaders and recent-deliveries seam
- `lib/sigra/admin/webhooks/failures.ex` — delivery-row failures query truth
- `lib/sigra/admin/live/webhook_delivery_failures_live.ex` — failures inbox triage surface
- `lib/sigra/admin/live/webhook_delivery_show_live.ex` — shared delivery detail surface that should own replay authority
- `lib/sigra/admin/live/webhook_subscription_show_live.ex` — existing high-risk detail-page mutation idiom and current “recent deliveries” positioning

### Existing docs and proof surfaces
- `guides/flows/webhooks.md` — published operator contract and current non-goal wording for replay tooling
- `guides/recipes/webhook-verification.md` — receiver-owned verification and `delivery_id` dedupe contract that replay must preserve
- `test/example/priv/playwright/tests/admin-generated.spec.ts` — generated-host browser proof seam to extend for replay story
- `test/sigra/webhooks_integration_test.exs` — persisted webhook delivery and worker integration seam
- `test/sigra/workers/webhook_delivery_test.exs` — retry/dead-letter worker behavior and safety expectations
- `test/sigra/admin/webhooks_test.exs` — admin webhook truth surfaces and likely replay regression seam

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Webhooks.Dispatcher.insert_deliveries/4` already provides the canonical way to insert fresh delivery rows with new `delivery_id` values.
- `Sigra.Webhooks.append_delivery_jobs_multi/4` already provides a transaction-owned way to enqueue new delivery rows once they exist.
- `Sigra.Admin.Webhooks.Actions` already demonstrates the right thin-wrapper mutation pattern for global-admin-safe webhook actions.
- `Sigra.Admin.Webhooks.Detail.load_delivery!/3` and the shared delivery LiveView already give Phase 104 a natural authority page for replay lineage and confirmation.
- `Sigra.Admin.Webhooks.Failures` and `WebhookDeliveryFailuresLive` already provide the correct delivery-row incident inbox where replay shortcuts can surface.

### Established Patterns
- Sigra prefers explicit persisted truth over inferred queue behavior.
- High-risk operator actions live on detail pages with explicit confirmation, not as hidden worker or controller side effects.
- Generated hosts own thin wrappers and routes; long-lived runtime behavior remains library-owned.
- `delivery_id` is the stable cross-boundary proof key for one delivery lifecycle, not a generic message family identifier.

### Integration Points
- Delivery-row schema evolution under the generated host webhook delivery schema/migration
- Library replay insertion and guard logic in `Sigra.Webhooks`
- Admin action wrapper additions in `Sigra.Admin.Webhooks.Actions`
- Failures inbox and shared delivery LiveView updates for replay affordances and lineage visibility
- Integration, admin, and generated-host proof coverage for fail -> inspect -> repair -> replay -> succeed

</code_context>

<deferred>
## Deferred Ideas

- Equivalent runtime CLI or mix task for replay
- Batch replay, endpoint-wide replay, or replay-run entities
- Replaying `retry_scheduled` deliveries with cancel/replace semantics
- Public or tenant-scoped self-service replay surfaces
- Free-form operator notes, incident comments, or approval workflows on replay
- Cross-lineage analytics beyond direct parent/root lineage navigation
- Any contract that preserves the original `delivery_id` across replayed child deliveries

</deferred>

---

*Phase: 104-failed-delivery-replay-controls*
*Context gathered: 2026-05-07*
