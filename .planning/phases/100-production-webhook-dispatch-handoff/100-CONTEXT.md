# Phase 100: Production webhook dispatch handoff - Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the broken bridge between Phase 97's persisted `pending` deliveries and Phase 98's async worker pipeline so production auth and identity mutations automatically hand off each newly created delivery into `Sigra.Workers.WebhookDelivery`.

This phase is specifically about the first enqueue and the production handoff boundary. It does not redesign the public payload contract, retry taxonomy, or admin UX surface already shaped in Phases 97, 98, and 99.

**Explicitly in scope:**
- initial enqueue of newly persisted webhook deliveries for production mutation paths
- choosing the durable handoff boundary between outer mutation transaction and first worker job insertion
- keeping job args minimal and aligned with the existing `delivery_id`-only worker contract
- end-to-end proof that a real mutation causes persisted delivery rows to enter the async worker path automatically
- preserving the existing "business mutation succeeds, downstream HTTP happens later" contract

**Explicitly out of scope:**
- retry policy redesign or new attempt-state fields
- admin retrying/dead-letter filter fixes
- generated-host Playwright proof expansion beyond what is needed to prove the Phase 100 handoff
- replay/redrive UX or CLI
- changing the public payload envelope, signature headers, or event catalog

</domain>

<decisions>
## Implementation Decisions

### Durable handoff boundary
- **D-100-01 — Treat initial enqueue as part of the local durable handoff, not a best-effort afterthought.** A mutation has not fully completed the Sigra-owned webhook contract if it persists `pending` deliveries but fails to create the first queue job that is supposed to consume them.
- **D-100-02 — Keep downstream HTTP outside the mutation transaction, but keep initial job creation inside the same local durability boundary.** Remote delivery may fail later without rolling back the mutation; local failure to create the first worker job should not leave orphaned `pending` deliveries behind as the "successful" outcome.
- **D-100-03 — Prefer one transaction owner.** The outer auth or identity transaction remains the only transaction owner; webhook code may append more steps into that transaction but must not create nested `Repo.transaction/1` or `Repo.transact/1` boundaries.

### Enqueue mechanism
- **D-100-04 — Reuse the existing `delivery_id`-only worker contract.** Initial enqueue must continue to schedule `Sigra.Workers.WebhookDelivery` with only the stable `delivery_id` in job args.
- **D-100-05 — Add a reusable library-owned enqueue seam for newly inserted delivery rows.** The codebase already has `dispatch_multi/5` for persistence and `enqueue_delivery/3` for single delivery jobs, but it lacks a reusable bridge that turns the freshly inserted delivery rows inside an outer transaction into initial worker jobs.
- **D-100-06 — Keep queue selection and optional-dependency enforcement centralized in `Sigra.Webhooks` / worker helpers.** Phase 100 should not duplicate queue names or dependency checks at every mutation call site.
- **D-100-07 — Initial enqueue should happen once per persisted delivery row.** One public event may fan out to many subscriptions, and each resulting delivery lineage must receive exactly one initial queue job.

### Caller shape
- **D-100-08 — Preserve existing mutation-call-site ergonomics.** `Sigra.Auth`, `Sigra.Organizations`, and `Sigra.ServiceAccounts` should continue to compose webhook work through append helpers rather than each implementing bespoke post-commit queue code.
- **D-100-09 — Build the handoff close to the existing dispatcher seam.** The missing bridge sits between `Dispatcher.insert_deliveries/4` and `Webhooks.enqueue_delivery/3`, so the plan should extend that area instead of inventing a parallel webhook pipeline module unless a narrow helper module is clearly cleaner.

### Verification stance
- **D-100-10 — Prove the production path, not only helper behavior.** Verification must show a real Sigra mutation creates both persisted delivery state and the first queued worker job automatically.
- **D-100-11 — Cover more than auth registration.** At least one identity mutation path that already appends webhook persistence should be included so the handoff is proven as a reusable library seam, not as an auth-only patch.
- **D-100-12 — Preserve the Phase 98 boundary.** Integration proof should confirm that business mutations still commit even when a later worker execution produces retryable or terminal receiver failures; Phase 100 only changes the first queue handoff.

### the agent's Discretion
- Exact helper/module naming for the new enqueue bridge
- Whether the initial job insertion is expressed via appended `Ecto.Multi` steps, a narrow Oban-wrapper helper, or another transaction-safe pattern that still preserves one transaction owner
- Exact step names and result-shape plumbing for the handoff steps
- Exact distribution of unit versus integration assertions, as long as the production mutation path is explicitly covered

</decisions>

<specifics>
## Specific Ideas

- The most important distinction is local durable handoff versus remote delivery.
- "Pending delivery row exists" is not enough for an honest production contract if nothing will ever pick it up automatically.
- The repo already has the right pieces:
  - `Dispatcher.dispatch_multi/4` persists events and deliveries
  - `Webhooks.build_delivery_job/3` and `enqueue_delivery/3` define the worker contract
  - `WebhookDelivery.perform/1` already handles success, retry, and dead-letter after a job exists
- The missing piece is the first bridge from "delivery row was inserted" to "worker job exists."

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone framing and gap evidence
- `.planning/PROJECT.md` — v1.22 milestone goals and library-first trust boundary
- `.planning/REQUIREMENTS.md` — `WH-01`, `WH-02`, `WH-03` traceability and scope
- `.planning/ROADMAP.md` — Phase 100 goal, success criteria, and audit-gap framing
- `.planning/STATE.md` — current milestone posture and neighboring phase status
- `.planning/v1.22-MILESTONE-AUDIT.md` — explicit evidence for the missing initial enqueue and broken mutation-to-worker flow

### Prior webhook decisions
- `.planning/phases/97-webhook-subscription-registry-signed-dispatcher-contract/97-CONTEXT.md` — persisted event + delivery seam and async-only contract
- `.planning/phases/97-webhook-subscription-registry-signed-dispatcher-contract/97-RESEARCH.md` — dispatcher composition and worker-ready delivery seam
- `.planning/phases/98-reliable-delivery-pipeline/98-CONTEXT.md` — retry/dead-letter model that Phase 100 must feed
- `.planning/phases/98-reliable-delivery-pipeline/98-RESEARCH.md` — single-shot worker and persisted retry contract
- `.planning/phases/99-admin-and-generated-host-webhook-ux/99-CONTEXT.md` — operator-facing expectations that depend on the handoff being real

### Existing code and tests
- `.planning/AUDIT-ATOMICITY-DEFAULTS.md` — single transaction owner / co-fate defaults
- `.planning/phases/100-production-webhook-dispatch-handoff/100-PATTERNS.md` — current repo analogs and the explicit no-analog gap
- `lib/sigra/webhooks.ex` — enqueue helpers, retry helpers, and delivery outcome persistence
- `lib/sigra/webhooks/dispatcher.ex` — current event + delivery persistence builder
- `lib/sigra/workers/webhook_delivery.ex` — existing single-shot worker and retry re-enqueue behavior
- `lib/sigra/auth.ex` — auth mutation path that appends webhook persistence
- `lib/sigra/organizations.ex` — identity mutation paths that append webhook persistence
- `lib/sigra/service_accounts.ex` — service-account mutation paths that append webhook persistence
- `test/sigra/webhooks_dispatcher_test.exs` — persistence-builder tests
- `test/sigra/webhooks_integration_test.exs` — current end-to-end webhook persistence and worker behavior tests
- `test/sigra/workers/webhook_delivery_test.exs` — worker enqueue/result semantics

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Webhooks.append_dispatch_multi/5` already gives callers a stable way to bolt webhook work onto outer domain multis.
- `Dispatcher.dispatch_multi/4` already returns the inserted delivery rows through a named multi step; Phase 100 can build on that rather than rediscovering the affected deliveries later.
- `Webhooks.build_delivery_job/3` and `enqueue_delivery/3` already centralize queue name, dependency checks, and the minimal job arg shape.
- `WebhookDelivery.perform/1` already proves the post-enqueue side of the pipeline is real.

### Established Patterns
- Sigra prefers library-owned transaction composition over ad hoc side effects.
- Worker jobs should carry only durable identifiers, not secrets or payload bodies.
- Mutation modules compose helpers and keep one outer transaction owner.

### Integration Points
- `Auth.register_user_multi/2`
- organization membership mutations
- service-account create/revoke flows

These are the mutation families whose webhook paths should consume the new initial-enqueue seam once it exists.

</code_context>

<deferred>
## Deferred Ideas

- Fixing Phase 99 query/filter truth bugs
- Generated-host browser proof of delivery history inspection
- Replay/redrive tooling
- Queue dedupe beyond what is needed for a single initial handoff
- Broader planning reconciliation for roadmap/requirements/state artifacts

</deferred>

---

*Phase: 100-production-webhook-dispatch-handoff*
*Context gathered: 2026-05-06*
