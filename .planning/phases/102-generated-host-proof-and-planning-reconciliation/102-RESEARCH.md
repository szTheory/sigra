# Phase 102: Generated-host proof and planning reconciliation - Research

**Researched:** 2026-05-06
**Domain:** Hybrid adopter-proof lane plus planning-truth reconciliation for Sigra webhooks
**Confidence:** HIGH

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WH-03 | Generated admin LiveView lets adopters create, enable or disable, rotate, and inspect webhook subscriptions and delivery history, and the generated host gets the minimum wiring needed to expose the feature without reverse-engineering Sigra internals. | Phase 102 must close the remaining proof gap by combining a real generated-host browser flow with durable receiver-verification artifacts keyed by `delivery_id`, then reconcile the active planning docs so the milestone truth matches the repaired implementation. |

</phase_requirements>

## Summary

Phase 102 should not try to “prove webhooks” with only one lane. The repo now has the sender-side enqueue handoff from Phase 100, truthful delivery-state filtering from Phase 101, generated-host admin wiring from Phase 99, and receiver-setup guidance in the generated docs. What is still missing is one canonical adopter proof that crosses the host boundary honestly enough to show the published contract is usable in practice. Browser-only proof is insufficient because it cannot prove raw-body verification or `delivery_id` dedupe. Artifact-only proof is also insufficient because it can pass while the generated admin story is broken or misleading. The correct shape is the hybrid proof already locked in `102-CONTEXT.md`: one real run, two evidence lanes, correlated by `delivery_id`. [VERIFIED: codebase] [VERIFIED: .planning/phases/102-generated-host-proof-and-planning-reconciliation/102-CONTEXT.md]

The best-fitting event path remains `user.created` triggered through real generated-host registration. The example app already exposes the generated admin webhook surface, the Playwright suite already logs in and creates subscriptions through `/admin/webhooks`, and `Sigra.Auth.register_user_multi/2` is the lowest-ceremony real mutation path that emits a public webhook event. A second browser context should create the user while the admin context remains on the webhook pages, then the proof should correlate the resulting admin-visible delivery with durable receiver-side evidence produced from the same request. [VERIFIED: codebase] [VERIFIED: guides/flows/webhooks.md]

The major missing implementation seam is host-owned receiver verification inside the example app. The repo contains receiver guidance and generated docs, but the example host does not yet expose a real webhook receiver route, `body_reader`, verification controller, or durable receipt model. Phase 102 should introduce a minimal example-host receiver path that:

- captures the raw request body,
- verifies `Sigra-Webhook-Id`, `Sigra-Webhook-Timestamp`, and `Sigra-Webhook-Signature`,
- stores one durable receipt row keyed by `delivery_id`,
- records verification metadata sufficient to prove dedupe and correlate to admin-visible history,
- and returns a fast 202 without pretending Sigra owns downstream automation.

This keeps the proof exactly at the published contract boundary. [INFERENCE from codebase]

There is also a deeper runtime blocker before any end-to-end proof can be honest: the current example-host registration path does not appear to use the config-aware Sigra registration seam that appends the `user.created` webhook dispatch, and the example runtime still has webhooks disabled with no Oban child started. Phase 102 therefore needs an explicit bootstrap slice that:

- makes the example registration path use the webhook-enabled Sigra config,
- enables example-host webhook config for the proof environment,
- starts an Oban supervisor or equivalent real worker runtime for the example app,
- and verifies that a real `user.created` mutation actually produces a queued delivery before browser proof begins.

Without this bootstrap work, the receiver seam and Playwright flow would still be proving a non-runtime path. [VERIFIED: test/example/lib/example/accounts.ex; VERIFIED: test/example/config/config.exs; VERIFIED: test/example/lib/example/application.ex]

Planning reconciliation should stay moderate, not archival. The active truth surface that must be coherent after Phase 102 is `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and the relevant validation/verification docs for the webhook milestone. The repo does not need a full rewrite of every historical artifact, but it does need the current milestone docs to stop disagreeing about what is complete, what is proven, and what evidence exists. The highest-value reconciliation work is therefore:

1. backfill or finalize the phase-level verification/validation artifacts that current milestone closure depends on,
2. update roadmap and requirements traceability to reflect actual post-gap-closure status,
3. refresh `STATE.md` so session continuity no longer contradicts the authoritative milestone story,
4. rerun or replace the milestone closeout evidence so no hidden human interpretation is required. [VERIFIED: .planning/v1.22-MILESTONE-AUDIT.md]

**Primary recommendation:** split Phase 102 into three plans:

1. add the example-host receiver verification seam and durable proof-artifact model,
2. extend the generated-host proof lane so one real run yields browser evidence plus correlated sender/receiver artifacts,
3. reconcile roadmap/requirements/state/validation/verification docs and re-close the milestone against the new evidence.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Raw-body capture and signature verification | Generated host | Library | The host owns the receiver boundary, but should use `Sigra.Webhooks.Signature.verify/4` as the published contract implementation. |
| Durable proof receipt keyed by `delivery_id` | Generated host | Database / Storage | Phase 102 needs adopter-owned verification artifacts, not only Sigra-owned delivery rows. |
| Canonical end-to-end trigger path | Library-owned mutation + generated host browser | — | `user.created` through real registration is already the least-surprise event path. |
| Operator-visible delivery history | Sigra admin LiveViews | Database / Storage | Phase 99/101 already provide the admin truth surface to pair with receiver evidence. |
| Planning-truth reconciliation | Planning docs | Verification artifacts | The milestone closeout must rely on explicit updated artifacts, not session memory. |

## Existing Runtime Truth

### What already works
- The example app exposes generated-host admin webhook routes, create flow, failures view, delivery detail, and subscription detail. [VERIFIED: test/example/lib/example_web/router.ex; VERIFIED: test/example/priv/playwright/tests/admin-generated.spec.ts]
- `guides/recipes/webhook-verification.md` and the generated `docs/webhook_receiver_setup.md` template already define the exact receiver contract: raw body, `body_reader`, signature verification, and dedupe by `delivery_id`. [VERIFIED: guides/recipes/webhook-verification.md; VERIFIED: priv/templates/sigra.install/admin/webhook_receiver_setup.md]
- `Sigra.Auth.register_user_multi/2` appends the real `user.created` webhook emission path. [VERIFIED: lib/sigra/auth.ex]
- The example host already persists webhook subscriptions, events, deliveries, and attempts, so admin-side delivery history is available for correlation. [VERIFIED: test/example/lib/example/accounts/*.ex]

### What is missing
- No example-host webhook receiver route, controller, or `body_reader` module currently exists. [VERIFIED: codebase]
- No durable receiver-side receipt artifact exists for proving verification and dedupe. [VERIFIED: codebase]
- The current example registration seam is not obviously proof-ready for `user.created`, because the current registration call path does not use the config-aware webhook dispatch seam. [VERIFIED: test/example/lib/example/accounts.ex]
- The example runtime leaves webhooks disabled and does not start Oban, so no real async delivery worker path exists yet for the generated-host proof environment. [VERIFIED: test/example/config/config.exs; VERIFIED: test/example/lib/example/application.ex]
- The Playwright generated-host spec stops after subscription creation and basic failures-page navigation. It does not trigger a real event or correlate a delivery to receiver evidence. [VERIFIED: test/example/priv/playwright/tests/admin-generated.spec.ts]
- The active milestone docs still disagree about completion state and proof coverage. [VERIFIED: .planning/ROADMAP.md; VERIFIED: .planning/REQUIREMENTS.md; VERIFIED: .planning/STATE.md; VERIFIED: .planning/v1.22-MILESTONE-AUDIT.md]

## Recommended Design Shape

### Pattern 1: Add a minimal host-owned webhook receipt seam in the example app
**What:** Introduce an example-host webhook controller, router scope, `WebhookBodyReader`, and a durable `WebhookReceipt`-style schema or equivalent receipt store keyed by `delivery_id`.
**Why it fits:** It matches the published receiver contract and gives Phase 102 a trustworthy adopter-owned evidence lane without inventing product features. [INFERENCE from codebase]

### Pattern 2: Bootstrap the example runtime before proving the adopter flow
**What:** Fix the example registration seam, enable webhook config for the proof environment, and start a real worker runtime.
**Why it fits:** Phase 102 cannot prove a runtime path that is still disabled or bypassed in the example host. [VERIFIED: codebase]

### Pattern 3: Keep proof correlation on `delivery_id`
**What:** Every artifact from browser, admin history, delivery rows, and receiver receipts should expose or record the same `delivery_id`.
**Why it fits:** The published contract already treats `delivery_id` as the stable per-subscription dedupe and correlation key. [VERIFIED: guides/flows/webhooks.md; VERIFIED: guides/recipes/webhook-verification.md]

### Pattern 4: Use a second browser actor for the trigger mutation
**What:** Keep the admin operator session intact while a separate actor performs registration.
**Why it fits:** It mirrors the real adopter story and avoids coupling “trigger” and “observe” into one brittle browser session. [VERIFIED: 102-CONTEXT.md]

### Pattern 5: Generate durable proof artifacts outside the browser DOM
**What:** Persist or export proof artifacts from the example receiver and sender state as files or database-backed evidence, then let the browser lane verify the operator-facing view.
**Why it fits:** Browser assertions alone are too weak for signature-verification truth, but they are still necessary for the generated-host UX claim. [INFERENCE from context]

### Pattern 6: Reconcile only the active truth set
**What:** Update milestone and phase artifacts that current closeout depends on, not every archived historical note.
**Why it fits:** The phase explicitly rejects full retrospective normalization. [VERIFIED: 102-CONTEXT.md]

## Anti-Patterns to Avoid

- Treating the generated-host browser lane as sufficient proof of the signed receiver contract.
- Inventing synthetic ping/test-event semantics or replay tooling.
- Building a full inbound-webhooks feature instead of a narrow proof receiver.
- Correlating evidence by timestamps or guessed payload contents instead of `delivery_id`.
- Rewriting every archived v1.22 planning artifact when only the active truth surface matters.

## Verification Strategy

### Must-have automated proof
- Example-host receiver tests for raw-body capture, signature verification, stale/invalid signature rejection, and dedupe by `delivery_id`.
- Example-host runtime/bootstrap proof that registration emits a queued webhook delivery under real config and worker startup.
- One real end-to-end proof path that creates a subscription, triggers `user.created`, confirms admin delivery history, and confirms a matching receiver receipt.
- Targeted verification or evidence-export command that surfaces the correlated `delivery_id`, event type, receiver verification result, and admin-visible delivery status.
- Planning-document checks proving `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and the updated validation/verification files no longer tell conflicting stories.

### Likely file groups
- Example host receiver seam:
  - `test/example/config/config.exs`
  - `test/example/lib/example/application.ex`
  - `test/example/lib/example_web/router.ex`
  - `test/example/lib/example_web/controllers/*`
  - `test/example/lib/example_web/*body_reader*.ex`
  - `test/example/lib/example/accounts/*`
  - `test/example/priv/repo/migrations/*`
  - `test/example/test/example_web/controllers/*`
- Hybrid proof lane:
  - `test/example/priv/playwright/tests/admin-generated.spec.ts`
  - `test/example/priv/playwright/helpers/*`
  - supporting example-host test or artifact-export code
- Planning reconciliation:
  - `.planning/ROADMAP.md`
  - `.planning/REQUIREMENTS.md`
  - `.planning/STATE.md`
  - `.planning/phases/98-*/98-VALIDATION.md`
  - `.planning/phases/99-*/99-VALIDATION.md`
  - `.planning/phases/102-*/102-VERIFICATION.md` and related phase docs as needed

## Planning Implications

- Plan 01 should establish the example runtime bootstrap and receiver proof seam first; without that, later browser proof is only cosmetic.
- Plan 02 should consume Plan 01 and produce the hybrid proof in one canonical `user.created` flow.
- Plan 03 should consume the new evidence and reconcile the planning truth surface, including any required verification backfill for milestone closeout.

## Evidence Used

- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/v1.22-MILESTONE-AUDIT.md`
- `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-CONTEXT.md`
- `.planning/phases/99-admin-and-generated-host-webhook-ux/99-CONTEXT.md`
- `.planning/phases/100-production-webhook-dispatch-handoff/100-CONTEXT.md`
- `.planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md`
- `guides/flows/webhooks.md`
- `guides/recipes/webhook-verification.md`
- `priv/templates/sigra.install/admin/webhook_receiver_setup.md`
- `test/example/priv/playwright/tests/admin-generated.spec.ts`
- `test/example/lib/example/accounts.ex`
- `test/example/lib/example_web/router.ex`
- `lib/sigra/auth.ex`

---

*Phase: 102-generated-host-proof-and-planning-reconciliation*
*Research completed: 2026-05-06*
