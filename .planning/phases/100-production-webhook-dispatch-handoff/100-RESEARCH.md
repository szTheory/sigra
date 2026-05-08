# Phase 100: Production webhook dispatch handoff - Research

**Researched:** 2026-05-06
**Domain:** Durable initial queue handoff for persisted webhook deliveries in Sigra
**Confidence:** HIGH

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WH-01 | Host app can configure outbound webhook subscriptions for Sigra-owned auth and identity events, and Sigra emits a stable signed payload for each delivery with a unique delivery ID, event type, timestamp, and event body suitable for verification by the receiver. | Phase 97 already satisfies persistence, payload, and signature shape; Phase 100 restores the missing automatic start of delivery by creating the first worker job for each persisted delivery. |
| WH-02 | Each webhook subscription can limit which event types it receives, failed deliveries retry with a documented bounded policy, and permanently failed deliveries are retained in a dead-letter state with per-attempt history instead of disappearing silently. | Phase 98 already satisfies retry/dead-letter behavior once a worker job exists; Phase 100 must feed that pipeline automatically from production mutation paths. |
| WH-03 | Generated admin LiveView lets adopters create, enable or disable, rotate, and inspect webhook subscriptions and delivery history, and the generated host gets the minimum wiring needed to expose the feature without reverse-engineering Sigra internals. | Phase 99's operator UX depends on delivery rows actually moving out of `pending` through real worker execution; Phase 100 restores the underlying runtime truth needed for that UX to be honest. |

</phase_requirements>

## Summary

The gap is narrow and explicitly evidenced by the repo. Phase 97's dispatcher persists one public event row and one `pending` delivery row per matching subscription inside the outer mutation transaction, and Phase 98's worker can consume an existing `delivery_id`, classify outcomes, persist attempt history, and schedule later retries. What is missing is the bridge between those two halves: no production mutation path creates the initial `Sigra.Workers.WebhookDelivery` job after the delivery rows are inserted. [VERIFIED: codebase] [VERIFIED: .planning/v1.22-MILESTONE-AUDIT.md]

The best-fitting design is to treat first-job creation as part of the same local durable handoff boundary as event and delivery persistence, while still keeping downstream HTTP outside the mutation transaction. In practical terms: the outer domain multi should append one more webhook-owned step that turns the freshly inserted deliveries into initial worker jobs using the existing `delivery_id`-only contract. If that local queue handoff cannot be created, the mutation should not claim the webhook pipeline was successfully established. This preserves the library-owned contract without coupling business success to receiver availability. [INFERENCE from codebase]

The repo already provides nearly all required building blocks. `Sigra.Webhooks.Dispatcher.dispatch_multi/4` returns inserted delivery rows through explicit step names; `Sigra.Webhooks.build_delivery_job/3` and `enqueue_delivery/3` centralize job construction, queue selection, and optional-dependency enforcement; `Sigra.Workers.WebhookDelivery.perform/1` proves the downstream single-shot worker/retry semantics are already real. The missing artifact is a reusable enqueue bridge for "newly inserted deliveries in an outer transaction", not a new retry system or a new worker design. [VERIFIED: codebase] [VERIFIED: .planning/phases/100-production-webhook-dispatch-handoff/100-PATTERNS.md]

**Primary recommendation:** extend the webhook persistence composition seam so the same outer mutation transaction that inserts `webhook_events` and `webhook_deliveries` also appends first-job creation for every inserted delivery, using the existing `delivery_id`-only worker contract and centralized dependency/queue helpers. Then add integration proof that a real auth mutation and at least one identity mutation both create queued jobs automatically, while later worker failure still leaves the originating mutation committed. [INFERENCE from codebase]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Persist event and delivery rows | Database / Storage | API / Backend | Already owned by `Dispatcher.dispatch_multi/4` and appended into outer domain multis. [VERIFIED: codebase] |
| Initial queue handoff | API / Backend | Database / Storage | The handoff is library-owned behavior that should be composed into the same local durability boundary as the outer mutation. [INFERENCE from codebase] |
| Remote webhook execution | API / Backend | — | Already owned by `Sigra.Workers.WebhookDelivery.perform/1`, outside the request path. [VERIFIED: codebase] |
| Retry/dead-letter lifecycle | API / Backend | Database / Storage | Already handled in Phase 98 once a job exists. [VERIFIED: codebase] |
| Operator visibility | Database / Storage | UI | Phase 99 reads persisted state; it depends on the handoff being real, but does not own it. [VERIFIED: context] |

## Existing Runtime Truth

### What already works
- `Auth.register_user_multi/2`, organization membership flows, and service-account flows already append webhook persistence into outer multis through `Webhooks.append_dispatch_multi/5`. [VERIFIED: codebase]
- `Dispatcher.insert_deliveries/4` persists `pending` delivery rows with generated `delivery_id`s and returns the inserted structs. [VERIFIED: codebase]
- `Webhooks.enqueue_delivery/3` builds and inserts a job carrying only `%{"delivery_id" => ...}` and the configured queue. [VERIFIED: codebase]
- `WebhookDelivery.perform/1` already handles delivery success, retryable 429/5xx/transport failures, terminal 4xx/local failures, attempt persistence, and follow-up retry enqueue. [VERIFIED: codebase]

### What is missing
- No production code path calls the enqueue helper for the initial persisted deliveries created by domain mutations. [VERIFIED: codebase]
- The current integration tests prove persistence and prove worker behavior when called manually, but they do not prove "mutation commit automatically creates queued worker jobs" in the live production path. [VERIFIED: codebase]

## Recommended Design Shape

### Pattern 1: Append initial enqueue work into the existing webhook seam
**What:** Extend the existing webhook composition seam so the inserted delivery rows produced by `Dispatcher.dispatch_multi/4` feed a follow-up step that creates the first queue jobs. [INFERENCE from codebase]
**Why it fits:** The dispatcher already has the exact delivery structs needed for enqueue, and callers already rely on `append_dispatch_multi/5` as the stable integration point. [VERIFIED: codebase]
**Why not caller-specific code:** Repeating enqueue logic in `Auth`, `Organizations`, and `ServiceAccounts` would duplicate queue/dependency concerns and risk drift. [INFERENCE from codebase]

### Pattern 2: Preserve the `delivery_id`-only worker contract
**What:** Keep initial job payloads minimal and identical to retry jobs: only `delivery_id`, queue, and optional schedule metadata if truly needed. [VERIFIED: codebase]
**Why it fits:** This preserves the existing security and durability model: the job table never stores secrets or raw payload data. [VERIFIED: codebase]

### Pattern 3: Treat enqueue failure as local handoff failure, not remote receiver failure
**What:** Distinguish between "cannot create the first local worker job" and "worker later fails to deliver to receiver." [INFERENCE from codebase]
**Why it fits:** The roadmap and audit gap define the missing initial enqueue as the broken contract. Downstream HTTP failure is explicitly allowed later; local handoff failure is not the same class of failure. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/v1.22-MILESTONE-AUDIT.md]

### Pattern 4: Verify both auth and identity callers
**What:** Add integration coverage that proves the reusable seam works for at least one auth mutation and one identity mutation already using webhook persistence. [INFERENCE from codebase]
**Why it fits:** The seam is shared; proving only auth registration would leave the rest of the milestone exposed to call-site drift. [VERIFIED: codebase]

## Anti-Patterns to Avoid

- **Best-effort post-commit enqueue loops in each caller:** this would leave mutation modules duplicating queue logic and make the handoff contract inconsistent.
- **Nested transactions inside webhook helpers:** this would violate the repo's single-owner transaction discipline.
- **Changing the worker contract to carry payload bodies or secrets:** the current design intentionally reloads persisted state at execution time.
- **Treating manual `WebhookDelivery.perform/1` invocation as proof of production handoff:** Phase 100 must prove the real mutation path queues the first job automatically.

## Verification Strategy

### Must-have automated proof
- Integration test: auth registration persists event + delivery rows and automatically queues exactly one job per matching delivery.
- Integration test: at least one identity mutation path does the same.
- Unit/integration assertion: queued job args remain `%{"delivery_id" => ...}` only.
- Regression proof: later retry and dead-letter behavior still works once the initial job exists.

### Good candidate files
- `test/sigra/webhooks_integration_test.exs` — strongest place for end-to-end handoff proof with `MockOban`
- `test/sigra/webhooks_dispatcher_test.exs` — possible home for lower-level enqueue-bridge assertions if the seam is added inside the dispatcher/webhooks layer
- `test/sigra/workers/webhook_delivery_test.exs` — keep focused on worker behavior, not first-handoff production wiring

## Planning Implications

- The plan should likely split into:
  1. library handoff seam design and implementation
  2. caller integration across shared mutation paths
  3. end-to-end verification proving automatic queue handoff
- The highest-risk design decision is not naming; it is deciding where the initial enqueue lives so it is reusable, transaction-safe, and consistent with the existing trust boundary.

## Evidence Used

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/v1.22-MILESTONE-AUDIT.md`
- `.planning/phases/97-webhook-subscription-registry-signed-dispatcher-contract/97-CONTEXT.md`
- `.planning/phases/98-reliable-delivery-pipeline/98-CONTEXT.md`
- `.planning/phases/99-admin-and-generated-host-webhook-ux/99-CONTEXT.md`
- `.planning/phases/100-production-webhook-dispatch-handoff/100-PATTERNS.md`
- `lib/sigra/webhooks.ex`
- `lib/sigra/webhooks/dispatcher.ex`
- `lib/sigra/workers/webhook_delivery.ex`
- `lib/sigra/auth.ex`
- `lib/sigra/organizations.ex`
- `lib/sigra/service_accounts.ex`
- `test/sigra/webhooks_integration_test.exs`
- `test/sigra/workers/webhook_delivery_test.exs`

---

*Phase: 100-production-webhook-dispatch-handoff*
*Research completed: 2026-05-06*
