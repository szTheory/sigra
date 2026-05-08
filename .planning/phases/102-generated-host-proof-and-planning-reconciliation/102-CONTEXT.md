# Phase 102: Generated-host proof and planning reconciliation - Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Convert the webhook milestone's generated-host story from partial proof to full adopter evidence, then reconcile the active planning artifacts so the milestone's truth surface matches the repaired implementation.

This phase is specifically about proving the real adopter flow end to end and restoring planning honesty after Phases 100 and 101 repaired the broken enqueue and operator-state gaps. It does not redesign the webhook contract, retry model, event catalog, or admin information architecture already locked in Phases 97 through 101.

**Explicitly in scope:**
- one canonical generated-host proof for `create subscription -> trigger real Sigra event -> observe signed delivery -> inspect delivery history`
- evidence that crosses the host boundary honestly enough to prove the published webhook contract is usable by adopters
- choosing the representative real event path for that proof
- deciding how much planning reconciliation is required after gap closure
- encoding the user's preference that routine product and architecture choices should be resolved inside GSD by default unless they materially change an important contract

**Explicitly out of scope:**
- expanding the browser proof into a matrix across every webhook event family
- turning the example host into a full demo receiver application with business automation
- replay/redrive UX, synthetic ping events, or new webhook product capabilities
- retroactive normalization of every historical planning artifact when those artifacts are no longer part of the current authoritative truth set

</domain>

<decisions>
## Implementation Decisions

### Proof shape
- **D-102-01 — Use a hybrid proof model.** The generated-host browser lane proves the adopter-facing admin path, but browser state is not the authority for webhook contract truth.
- **D-102-02 — Contract truth must come from durable artifacts produced by the same real run.** Phase 102 proof should pair the browser flow with library-owned and host-owned evidence such as persisted delivery/attempt state plus receiver-verification artifacts.
- **D-102-03 — Browser-only proof is insufficient.** It can prove WH-03 UX wiring, but it cannot honestly prove raw-body signature handling, host-boundary verification, or the signed-request contract.
- **D-102-04 — Backend/artifact-only proof is also insufficient.** It can prove sender-side truth, but it can still pass while the generated-host admin story is broken or misleading.
- **D-102-05 — Keep strict lane ownership.** Browser evidence owns generated-host UX and visibility; artifacts own sender/receiver truth. Avoid duplicating the same assertions in both lanes.

### Trigger flow
- **D-102-06 — Use one canonical real-event proof path, not one proof per event family.** The generated-host proof is responsible for proving the adopter story, while event-family breadth remains covered by lower-level Sigra tests.
- **D-102-07 — The canonical proof event is `user.created`.** Trigger it through real generated-host registration because it is the lowest-ceremony, least-surprising real path already aligned with the webhook admin UX and current test surfaces.
- **D-102-08 — Prefer a second browser context or equivalent isolation for the trigger action.** The admin operator session should stay intact while a separate actor performs the real registration event that emits the webhook.
- **D-102-09 — Do not introduce synthetic ping or test-event semantics for this phase.** The proof must exercise a real Sigra-owned public event path.

### Evidence depth
- **D-102-10 — Prove the receiver-verification boundary, not downstream business automation.** Phase 102 should show that a host-owned receiver captured the raw request, verified the published signature contract, and deduped by `delivery_id`.
- **D-102-11 — Admin-visible delivery history remains part of the proof, but not the whole proof.** The operator should be able to inspect the resulting delivery from the generated admin surface and correlate it with receiver-side verification evidence.
- **D-102-12 — `delivery_id` is the canonical cross-boundary proof key.** Proof artifacts should correlate on the stable delivery identifier rather than on inferred timestamps or event payload coincidence.
- **D-102-13 — Stop at the published webhook contract.** Sigra does not need to prove arbitrary receiver-side business logic, queueing, or host-domain side effects to satisfy this phase.

### Planning reconciliation strictness
- **D-102-14 — Use moderate reconciliation strictness.** After gap-closure work, Sigra must bring the active planning truth set back into alignment without requiring full retrospective normalization of every historical artifact.
- **D-102-15 — The authoritative truth set for this phase is `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and the relevant validation/verification artifacts.** No current authoritative document should make a stale or conflicting claim after Phase 102 closes.
- **D-102-16 — Backfill validation/verification only where it changes the current user-facing or milestone-level truth.** Especially for Phases 98, 99, and 102, the evidence trail should match the repaired milestone story.
- **D-102-17 — Known residual gaps must be stated explicitly.** Do not rely on undocumented human interpretation to explain what is still missing or intentionally deferred.

### User preference carried forward
- **D-102-18 — Shift routine product and architecture choices left within GSD by default.** Downstream research, planning, and execution should prefer decisive recommendations and only escalate choices that materially alter the security model, public webhook contract, semver surface, generated-host contract, or another similarly high-impact boundary.
- **D-102-19 — Optimize for least surprise, production honesty, and strong developer ergonomics over maximal ceremony.** Favor proof and artifact shapes that a Phoenix/Plug/Ecto adopter would find unsurprising and trustworthy.

### the agent's Discretion
- Exact artifact formats for receiver-verification evidence, as long as they are durable, reviewer-friendly, and keyed by `delivery_id`
- Exact split of Playwright, LiveView, integration, and artifact-generation work across plans
- Exact wording and placement of any planning closeout notes, provided the active truth set becomes coherent
- Exact host-side receipt model for the proof lane, provided it demonstrates raw-body verification and dedupe without turning into unsupported business automation

</decisions>

<specifics>
## Specific Ideas

- The strongest Phase 102 story is:
  - admin creates a `user.created` subscription in the generated host
  - a separate actor registers a new user through the generated host
  - Sigra emits a real signed webhook delivery
  - the generated admin surface shows the resulting delivery/history
  - a host-owned receiver artifact proves raw-body capture, signature verification, and `delivery_id` dedupe
- This should feel more like Stripe/Svix operator truth than like a screenshot-driven demo:
  - endpoint management and delivery history are visible to the operator
  - receiver verification is explicit
  - the proof stops before pretending Sigra owns downstream business automation
- Lessons to preserve from successful webhook systems:
  - Stripe: raw-body verification and per-delivery visibility are the trust surface
  - GitHub: stable delivery identifiers and quick-ack/async processing are good defaults
  - Shopify: rich delivery diagnostics are useful, but automatic subscription removal is too surprising for Sigra's contract
  - Svix: endpoints, deliveries, and attempts should remain distinct concepts
- The generated-host proof should stay understandable to adopters:
  - "I can create the subscription"
  - "A real Sigra action triggers a delivery"
  - "I can inspect it in admin"
  - "My receiver can verify and dedupe it using the documented contract"

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone framing and gap evidence
- `.planning/PROJECT.md` — production-honest milestone framing and the preference for decisive recommendations unless a major contract changes
- `.planning/REQUIREMENTS.md` — `WH-03` mapping plus current traceability state across phases 97–102
- `.planning/ROADMAP.md` — Phase 102 goal, success criteria, and dependency on Phases 99–101
- `.planning/STATE.md` — current continuity note and current mismatch risk between state and milestone artifacts
- `.planning/v1.22-MILESTONE-AUDIT.md` — exact gap-closure framing for generated-host proof and planning drift

### Prior webhook decisions
- `.planning/phases/97-webhook-subscription-registry-signed-dispatcher-contract/97-CONTEXT.md` — public event catalog, signed delivery contract, and explicit rejection of synthetic wildcard thinking
- `.planning/phases/98-reliable-delivery-pipeline/98-CONTEXT.md` — retry/dead-letter/attempt-history model and durable delivery state
- `.planning/phases/99-admin-and-generated-host-webhook-ux/99-CONTEXT.md` — admin UX intent, real-event preference, and generated-host boundary
- `.planning/phases/100-production-webhook-dispatch-handoff/100-CONTEXT.md` — production enqueue handoff and real mutation-to-worker contract
- `.planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md` — operator-truth model and delivery-state semantics

### Current milestone evidence surfaces
- `.planning/phases/98-reliable-delivery-pipeline/98-VALIDATION.md` — current validation gap that Phase 102 reconciliation must account for
- `.planning/phases/99-admin-and-generated-host-webhook-ux/99-VALIDATION.md` — current validation draft and claimed browser proof lane
- `.planning/phases/100-production-webhook-dispatch-handoff/100-01-SUMMARY.md` — evidence that initial enqueue was repaired
- `.planning/phases/101-operator-delivery-state-truth/101-01-SUMMARY.md` — evidence that operator filtering truth was repaired

### Receiver contract and generated-host proof surfaces
- `guides/flows/webhooks.md` — public webhook flow, event/delivery model, and receiver expectations
- `guides/recipes/webhook-verification.md` — raw-body verification, signature contract, and `delivery_id` dedupe guidance
- `test/example/priv/playwright/tests/admin-generated.spec.ts` — current generated-host browser proof seam that must be expanded beyond create-and-navigate

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Auth.register_user_multi/2` already provides the best low-ceremony real event path for `user.created`.
- The generated-host webhook admin route and create flow already exist in `test/example/priv/playwright/tests/admin-generated.spec.ts`; Phase 102 should extend this seam rather than invent a separate proof harness.
- Sigra’s receiver guidance already documents the right host boundary: raw-body capture with `Plug.Parsers` `:body_reader`, signature verification, and dedupe by `delivery_id`.
- Persisted delivery and attempt rows already provide a stable operator-truth surface for correlating browser-visible history with proof artifacts.

### Established Patterns
- Thin generated-host wrappers over library-owned runtime behavior
- Real event paths over synthetic test-only contracts
- Durable local truth before remote side effects
- URL-driven admin/operator surfaces backed by persisted state rather than queue internals

### Integration Points
- Generated admin subscription creation and delivery-history inspection
- Generated host registration flow as the canonical `user.created` trigger
- Host-owned receiver verification seam using raw request bytes and documented signature helpers
- Planning artifact reconciliation across roadmap, requirements, state, and per-phase validation/verification docs

</code_context>

<deferred>
## Deferred Ideas

- Additional generated-host E2E proofs for org-scoped or service-account event families
- Replay/redrive UX or CLI
- Synthetic ping/test-event support
- Full retrospective normalization of every historical milestone artifact when those artifacts do not affect the current authoritative truth set
- Rich receiver-side business-processing demos beyond verification and dedupe

</deferred>

---

*Phase: 102-generated-host-proof-and-planning-reconciliation*
*Context gathered: 2026-05-06*
