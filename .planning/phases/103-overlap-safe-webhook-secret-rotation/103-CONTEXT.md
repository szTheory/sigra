# Phase 103: Overlap-safe webhook secret rotation - Context

**Gathered:** 2026-05-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Make Sigra's webhook signing-secret rotation safe in production by adding an explicit overlap lifecycle, deterministic sender behavior, replay-safe receiver verification, and proof that the full rotation path works without creating a delivery-loss window.

This phase is specifically about outbound webhook signing-secret rollover for the existing Sigra webhook pipeline. It does not broaden the webhook event catalog, redesign retry/dead-letter semantics, add generalized secret-management products, or add replay/redrive controls beyond what Phase 104 will cover.

**Explicitly in scope:**
- subscription metadata for current and next signing secrets plus overlap lifecycle state
- sender behavior during pre-overlap, active overlap, and post-retirement stages
- receiver verification guidance for temporarily-valid multiple secrets
- preserving replay protection across the overlap window
- admin/generated-host UX and proof for the full rotation lifecycle

**Explicitly out of scope:**
- arbitrary N-version secret history as a first-class product surface
- automatic scheduled cutover / retirement jobs
- generalized KMS / HSM integration abstractions
- manual replay controls or redelivery tooling
- changing the `delivery_id` / `event_id` contract established in prior phases

</domain>

<decisions>
## Implementation Decisions

### Rotation lifecycle
- **D-103-01 — Use an explicit dual-slot subscription lifecycle, not a normalized secrets subsystem.** Each subscription should hold the currently active signing secret plus one staged next secret and explicit lifecycle metadata for the overlap window. Do not introduce a separate `webhook_subscription_secrets` table in this phase.
- **D-103-02 — Rotation state must be explicit and operator-readable.** The subscription model should distinguish at least `stable`, `prepared`, and `overlap_active` states rather than inferring rotation from nullable timestamps alone.
- **D-103-03 — Keep lifecycle truth queryable on the subscription record.** The subscription should persist non-secret lifecycle metadata such as state, who initiated the latest transition, when overlap started, and when the old secret becomes eligible for retirement. This should be readable in admin/detail surfaces without reconstructing state from attempt history.
- **D-103-04 — Keep the secret model bounded to “current + next.”** Phase 103 should optimize for one active secret and one staged replacement. Do not generalize into arbitrary concurrent secret versions or a keyring product.

### Sender behavior during overlap
- **D-103-05 — Dual-sign every delivery attempt during the active overlap window.** While overlap is active, Sigra should sign each outbound webhook attempt with both the current and next secret and include both `v1=...` values in `Sigra-Webhook-Signature`.
- **D-103-06 — Use one shared timestamp per attempt across all overlap signatures.** A given delivery attempt should still produce one `Sigra-Webhook-Timestamp`, one `delivery_id`, and multiple signatures over the same canonical string rather than emitting per-secret timestamps.
- **D-103-07 — Pre-overlap and post-retirement stay single-secret.** Before overlap begins, only the current secret signs deliveries. After the operator completes rotation and the old secret is retired, only the next secret signs deliveries.
- **D-103-08 — Do not pin a delivery lineage to one secret version.** Retries that occur during overlap should remain verifiable via all currently active overlap secrets rather than forcing a delivery to stick to the secret that signed its first attempt.

### Verification and replay contract
- **D-103-09 — Replay protection remains keyed strictly to `delivery_id`.** Temporary multi-secret validity must not change the dedupe contract. Receivers should continue treating `delivery_id` as the sole logical delivery key, including across retries and overlap.
- **D-103-10 — Do not add a public key-identifier header in Phase 103.** Sigra should not introduce `kid`-style public metadata or other secret-selection headers. Receivers should verify against candidate secrets and succeed when any valid signature matches.
- **D-103-11 — Multi-secret verification is receiver-local and env-driven.** Generated guidance should default to a receiver holding `current` and `previous` secrets locally and calling `Sigra.Webhooks.Signature.verify/4` with a candidate-secret list. Verification must not depend on a signed hint from the sender to choose the secret.
- **D-103-12 — Timestamp tolerance behavior stays unchanged.** Overlap support must not widen or weaken the existing freshness rules. Stale timestamps remain invalid even if one of the secret digests matches.
- **D-103-13 — Generated-host proof code must not become the public verification contract.** The current example-host trick of resolving a sender-owned secret through delivery context is acceptable only as proof scaffolding. The documented adopter contract remains raw-body verification against receiver-owned secrets.

### Operator workflow and admin UX
- **D-103-14 — Use an explicit three-step operator flow: prepare, start overlap, complete rotation.** Sigra should not treat secret rotation as a one-click replace anymore. The recommended admin flow is:
  - prepare a new secret
  - start overlap after the receiver is ready to accept both secrets
  - complete rotation after a real overlap-window delivery verifies successfully
- **D-103-15 — Keep lifecycle transitions operator-driven, not timer-driven.** Phase 103 should avoid background schedulers, auto-cutover, and auto-retirement jobs. Explicit operator actions are less surprising, easier to prove, and better aligned with Sigra’s current admin idioms.
- **D-103-16 — The admin surface should tell the truth about state and required next step.** Subscription detail UX should show the current lifecycle state, what Sigra is signing with right now, what the receiver is expected to do next, and whether the old secret has been retired.
- **D-103-17 — Rotation is not considered safe until a real post-change delivery proves it.** UX and docs should explicitly require at least one real overlap-window delivery and one post-retirement delivery to validate the path. Do not imply that clicking “rotate” or “complete” alone is sufficient proof.

### Proof and verification depth
- **D-103-18 — Phase 103 must prove the full lifecycle end to end.** Verification for this phase should include:
  - a successful pre-rotation delivery
  - a successful overlap-window delivery signed with both secrets
  - a successful post-retirement delivery signed only with the new secret
  - receiver dedupe and history still keyed by `delivery_id`
- **D-103-19 — Proof should correlate operator and receiver evidence on `delivery_id`.** Admin history, receiver receipts, and any artifact bundles should all correlate using the stable delivery identifier rather than inferred time windows.

### User preference carried forward
- **D-103-20 — Shift routine product and architecture decisions left within GSD.** Downstream research, planning, and execution should prefer decisive recommendations that preserve production honesty, least surprise, and strong developer ergonomics. Escalate decisions only when they materially change the security model, public webhook contract, semver surface, generated-host contract, or another similarly high-impact boundary.

### the agent's Discretion
- Exact schema field names for the current/next secret slots and lifecycle metadata
- Whether overlap lifecycle state is modeled as a string enum, atom-backed enum, or equivalent explicit state representation
- Exact admin copy, badge names, and detail-page layout, as long as state and next-step truth remain explicit
- Exact proof artifact format and test decomposition across library, generated-host, and browser/integration lanes
- Whether non-secret secret metadata is represented as fingerprints, masked summaries, or equivalent operator-safe identifiers

</decisions>

<specifics>
## Specific Ideas

- The coherent Sigra model is:
  - `stable`: one active secret, normal delivery
  - `prepared`: next secret staged, but sender still signs only with current
  - `overlap_active`: sender signs every attempt with both secrets
  - `completed`: old secret retired, sender signs only with new
- Keep the receiver ergonomics simple and boring:
  - raw request body verification
  - `delivery_id` dedupe
  - current + previous secret environment variables during overlap
  - no `kid` selection logic
- Strong external lessons to copy:
  - Stripe: bounded overlap with multiple active secrets and one signature per active secret
  - Svix: zero-downtime rotation via multi-signature overlap
  - GitHub: stable delivery identifiers, quick `2xx`, durable delivery history
- Strong external lessons to avoid:
  - one-shot sender secret replacement that creates a race window
  - automatic subscription retirement/disablement surprises
  - using proof-only sender-owned secret lookup as the main adopter contract

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone framing and requirements
- `.planning/PROJECT.md` — v1.23 milestone framing, production-honest operator trust goals, and preference for decisive GSD recommendations
- `.planning/REQUIREMENTS.md` — `WH-04` requirement and out-of-scope boundaries for the milestone
- `.planning/ROADMAP.md` — Phase 103 goal, success criteria, and dependency on Phases 97-102
- `.planning/STATE.md` — current milestone continuity and the explicit next-step handoff into Phase 103 planning

### Prior webhook decisions
- `.planning/phases/97-webhook-subscription-registry-signed-dispatcher-contract/97-CONTEXT.md` — public signing contract, stable `delivery_id`, and the explicit deferral of overlap windows from Phase 97
- `.planning/phases/98-reliable-delivery-pipeline/98-CONTEXT.md` — retry model, fresh timestamp per attempt, and durable delivery/attempt semantics
- `.planning/phases/99-admin-and-generated-host-webhook-ux/99-CONTEXT.md` — admin/generated-host webhook UX intent and operator surface boundaries
- `.planning/phases/100-production-webhook-dispatch-handoff/100-CONTEXT.md` — repaired async handoff contract so Phase 103 can assume real production dispatch
- `.planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md` — operator-truth model and delivery-state surface expectations
- `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-CONTEXT.md` — generated-host proof model, `delivery_id` correlation, and the preference for least-surprise contract proof

### Existing webhook implementation seams
- `lib/sigra/webhooks.ex` — current subscription mutations and one-shot `rotate_secret/2` behavior
- `lib/sigra/webhooks/signature.ex` — current versioned signature contract, multi-signature parsing, and candidate-secret verification support
- `lib/sigra/webhooks/dispatcher.ex` — persisted delivery creation and stable `delivery_id` model
- `lib/sigra/workers/webhook_delivery.ex` — actual send-attempt behavior and where overlap signing will be enforced

### Generated-host and admin surfaces
- `lib/sigra/admin/webhooks/actions.ex` — current admin mutation boundary for secret actions
- `lib/sigra/admin/live/webhook_subscription_show_live.ex` — current operator copy and one-shot rotate flow that Phase 103 supersedes
- `guides/flows/webhooks.md` — published webhook product contract and current out-of-scope wording for overlap windows
- `guides/recipes/webhook-verification.md` — raw-body verification, timestamp tolerance, and `delivery_id` dedupe guidance that Phase 103 extends
- `test/example/lib/example/accounts/webhook_subscription.ex` — current single-secret generated-host schema seam
- `test/example/lib/example_web/controllers/sigra_webhook_controller.ex` — current proof receiver seam that must remain distinct from the public adopter contract
- `test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs` — current admin UX expectations that Phase 103 will intentionally change
- `test/example/priv/playwright/tests/admin-generated.spec.ts` — generated-host proof lane to extend across the full rotation lifecycle

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Webhooks.Signature.verify/4` already accepts either one secret or a list of candidate secrets and already parses multiple signatures from the header.
- The existing webhook contract already has the right replay primitive: stable `delivery_id` across retries with fresh timestamps per attempt.
- The generated-host proof lane already correlates sender and receiver evidence and can be expanded for lifecycle proof rather than replaced.
- Sigra’s admin surfaces already follow list/detail patterns, which fit explicit rotation-state surfaces better than a wizard-heavy flow.

### Established Patterns
- Sigra favors explicit persisted truth over inferred runtime behavior.
- Sigra prefers library-owned security logic with thin generated-host wrappers.
- Operator-facing surfaces are expected to be truthful and unsurprising rather than automation-heavy.
- Replay and queue semantics are already modeled at the delivery level, not through mutable endpoint magic.

### Integration Points
- Subscription schema and changeset evolution around the existing single `signing_secret`
- Admin action surface for new `prepare`, `start overlap`, and `complete` mutations
- Webhook worker signing logic during overlap
- Generated receiver docs and example-host proof receiver updates for dual-secret verification
- Proof artifacts and tests that correlate pre-overlap, overlap, and post-retirement deliveries

</code_context>

<deferred>
## Deferred Ideas

- Generalized secret-history timeline or normalized secret-version tables
- Scheduler-driven cutover or auto-retirement
- KMS/HSM-backed secret-management abstractions
- Public key-identifier (`kid`) or secret-selection headers
- Replay/redrive controls and manual resend flows — Phase 104
- Broader endpoint health or auto-disable policy changes

</deferred>

---

*Phase: 103-overlap-safe-webhook-secret-rotation*
*Context gathered: 2026-05-07*
