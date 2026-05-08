# Phase 98: Reliable delivery pipeline - Research

**Researched:** 2026-05-06
**Domain:** Reliable outbound webhook delivery on persisted state in Elixir/Ecto/Oban [VERIFIED: codebase]
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
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

### Deferred Ideas (OUT OF SCOPE)
- Manual replay/redrive workflows and UI
- Host-configurable retry schedules or policy overrides
- Automatic subscription disablement after repeated terminal failures
- Separate dead-letter queue/table subsystem
- Long-term retention/pruning policy and cleanup jobs for delivered/dead-letter history
- Broader retryable `4xx` allowlists beyond `408` and `429`
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WH-02 | Each webhook subscription can limit which event types it receives, failed deliveries retry with a documented bounded policy, and permanently failed deliveries are retained in a dead-letter state with per-attempt history instead of disappearing silently. | Use the existing Phase 97 per-subscription fan-out gate in `Sigra.Webhooks.Dispatcher.matching_subscriptions/2`, keep `Sigra.Workers.WebhookDelivery` single-shot, add `webhook_delivery_attempts`, denormalized delivery summary fields, fixed six-attempt scheduling, and dead-letter state on the parent delivery row. [VERIFIED: codebase] [CITED: https://hexdocs.pm/oban/Oban.Job.html] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] |
</phase_requirements>

## Summary

Phase 97 already gives Sigra the correct starting point for reliable delivery: auth and identity mutations can atomically persist a public `webhook_events` row plus one `webhook_deliveries` row per matching subscription before any remote HTTP work begins. That seam is already wired into `Sigra.Auth.register_user_multi/2`, `Sigra.Organizations`, and `Sigra.ServiceAccounts`, and Phase 97 tests already prove those writes share fate with the outer business transaction. [VERIFIED: codebase]

The current reliability gap is narrow and explicit. `Sigra.Workers.WebhookDelivery` performs one HTTP attempt, marks the delivery `delivered` on 2xx, returns terse `{:error, {:http_error, status}}` or `{:error, :transport_error}` on failure, and is configured with `max_attempts: 1`. That matches the Phase 97 contract but leaves no persisted retry schedule, no durable attempt ledger, and no visible dead-letter semantics. [VERIFIED: codebase]

Oban should stay the execution engine, not the product contract. Official Oban docs confirm that failed jobs automatically move through `retryable` and eventually `discarded` using Oban-managed backoff and `max_attempts`, while official Ecto docs confirm `Ecto.Multi.run/3`, `append/2`, and `Repo.transact/2` are the correct primitives for co-fating dynamic writes in one transaction. For Phase 98, that means Sigra should keep worker runs single-shot and express all public retry semantics in Sigra-owned tables plus explicit re-enqueueing. [CITED: https://hexdocs.pm/oban/error_handling.html] [CITED: https://hexdocs.pm/oban/job_lifecycle.html] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]

**Primary recommendation:** Keep `Sigra.Workers.WebhookDelivery` at one real attempt per job, add an append-only `webhook_delivery_attempts` table plus denormalized summary fields on `webhook_deliveries`, and let Sigra explicitly enqueue the next scheduled attempt from persisted classification state instead of delegating retry policy to raw Oban defaults. [VERIFIED: codebase] [CITED: https://hexdocs.pm/oban/Oban.Job.html]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Event-to-subscription routing | API / Backend | Database / Storage | Matching happens in `Sigra.Webhooks.Dispatcher.matching_subscriptions/2` before delivery rows are inserted, and subscription scope is persisted in host tables. [VERIFIED: codebase] |
| Auth/identity mutation success | API / Backend | Database / Storage | Auth and identity contexts own the outer `Ecto.Multi` and must commit business rows plus webhook rows without waiting on remote endpoints. [VERIFIED: codebase] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] |
| Delivery summary state | Database / Storage | API / Backend | `webhook_deliveries` is already the per-subscription lineage row and Phase 98 decisions require it to become the operator summary row. [VERIFIED: codebase] |
| Attempt-by-attempt forensic history | Database / Storage | API / Backend | Phase 98 locks an append-only child ledger and requires parent summary + child attempt insertion in one transaction. [VERIFIED: context] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] |
| Retry scheduling and execution | API / Backend | Database / Storage | Oban executes jobs, but Sigra owns when another attempt should be enqueued and why. [VERIFIED: context] [CITED: https://hexdocs.pm/oban/Oban.Job.html] |
| Dead-letter visibility | Database / Storage | API / Backend | The dead-letter contract is an in-place terminal state on `webhook_deliveries`, not a separate queue product. [VERIFIED: context] |
| Receiver authentication | API / Backend | — | Fresh per-attempt signatures are built in `Sigra.Webhooks.Signature` and `Sigra.Workers.WebhookDelivery.build_request/3`. [VERIFIED: codebase] |

## Project Constraints (from CLAUDE.md)

- Sigra’s blessed path is Phoenix 1.8+ with Ecto 3.x, and PostgreSQL is the primary database. [VERIFIED: CLAUDE.md]
- Security-critical behavior should keep OWASP-grade defaults and avoid unnecessary new dependencies when existing project patterns already solve the problem. [VERIFIED: CLAUDE.md]
- Tests should be comprehensive, AAA-style, flat, and self-contained. [VERIFIED: CLAUDE.md]
- Local and CI expectations are aligned: `mix test` requires a live Postgres on `localhost:5432` and there are no default tag exclusions hiding failures. [VERIFIED: CLAUDE.md] [VERIFIED: test/test_helper.exs]
- Repo edits are being made under an explicit GSD workflow because the user asked for a phase artifact directly. [VERIFIED: CLAUDE.md]

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Ecto / Ecto SQL | `~> 3.12` in `mix.exs`; `3.13.5` in `mix.lock` | Atomic mutation composition for parent delivery summary plus child attempt rows. | Sigra already composes webhook persistence with outer auth multis, and official docs support `Multi.run/3`, `append/2`, and `Repo.transact/2` for this exact co-fate pattern. [VERIFIED: mix.exs/mix.lock] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] |
| Oban | `~> 2.17` in `mix.exs`; `2.21.1` in `mix.lock` | Queue-backed single-shot execution and scheduled re-enqueueing. | The repo already treats webhook transport as async-only with Oban as an optional but enforced dependency when enabled, and official docs provide `schedule_in`, uniqueness, and job-state semantics without requiring Sigra to expose raw Oban retry behavior. [VERIFIED: mix.exs/mix.lock] [VERIFIED: codebase] [CITED: https://hexdocs.pm/oban/Oban.Job.html] [CITED: https://hexdocs.pm/oban/job_lifecycle.html] |
| Jason | `1.4.4` in `mix.lock` | Exact JSON serialization of persisted payload snapshots for signing and sending. | The current worker signs and sends the raw `Jason.encode/1` body from persisted `event.payload`; Phase 98 should preserve that exact-body contract across retries. [VERIFIED: mix.lock] [VERIFIED: codebase] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| OTP `:httpc` / `:inets` / `:ssl` | OTP 28 locally; stdlib/runtime | Existing outbound HTTP transport and TLS bootstrap. | Keep for Phase 98 unless transport requirements expand beyond current needs; reliability semantics belong in persisted state, not in swapping HTTP clients mid-phase. [VERIFIED: codebase] [VERIFIED: local environment] |
| `Sigra.Webhooks.Signature` | repo module | Fresh per-attempt HMAC headers with stable `delivery_id` and fresh timestamp. | Reuse on every retry attempt; do not persist secrets or precomputed signatures. [VERIFIED: codebase] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Sigra-owned retry contract | Raw Oban `max_attempts` + default backoff | Rejected because Phase 98 explicitly locks public semantics into `webhook_deliveries` plus attempt history, while Oban docs show its default contract is automatic retry/discard state inside `oban_jobs`. [VERIFIED: context] [CITED: https://hexdocs.pm/oban/error_handling.html] [CITED: https://hexdocs.pm/oban/job_lifecycle.html] |
| In-place dead-letter on `webhook_deliveries` | Separate dead-letter table or queue | Rejected because Phase 98 explicitly keeps one canonical delivery lineage row and defers replay/subsystem work. [VERIFIED: context] |
| Explicit scheduled re-enqueue | Worker-level retries via `{:error, reason}` | Rejected because worker-level retries hide product semantics in queue internals and do not populate the Sigra-owned attempt ledger or summary contract. [VERIFIED: context] [CITED: https://hexdocs.pm/oban/error_handling.html] |

**Installation:** No new dependency is required for Phase 98 beyond the existing stack already declared in [`mix.exs`](/Users/jon/projects/sigra/mix.exs:1). Hosts enabling webhooks still need Oban configured because webhook delivery remains async-only. [VERIFIED: mix.exs] [VERIFIED: codebase]

**Version verification:** `mix.exs` currently constrains `oban` to `~> 2.17` and `ecto` / `ecto_sql` to `~> 3.12`, while `mix.lock` resolves them to `2.21.1` and `3.13.5`. Current official docs consulted during this research were Oban `v2.22.1` and Ecto `v3.13.6`. [VERIFIED: mix.exs/mix.lock] [CITED: https://hexdocs.pm/oban/Oban.Job.html] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html]

## Architecture Patterns

### System Architecture Diagram

```text
Auth / identity mutation
  -> outer Ecto.Multi in Sigra.Auth / Organizations / ServiceAccounts
  -> append Phase 97 webhook event + delivery fan-out
  -> Repo.transact commits business row + webhook rows together
  -> Oban job inserted with only delivery_id
  -> Sigra.Workers.WebhookDelivery loads delivery + subscription + event
  -> sign fresh request with stable delivery_id + fresh timestamp
  -> POST persisted payload snapshot
  -> classify outcome
     -> delivered: update delivery summary + insert success attempt row
     -> retryable: update delivery summary + insert failed attempt row + enqueue next scheduled attempt
     -> terminal/local invariant: update delivery summary to dead_lettered + insert terminal attempt row
  -> Phase 99 admin/history reads only Sigra-owned webhook tables
```

### Recommended Project Structure

```text
lib/sigra/webhooks/                 # public helpers, dispatcher, signature, outcome classification
lib/sigra/workers/                  # single-shot webhook worker + enqueue helpers
test/sigra/                         # unit, integration, and atomicity proofs for webhook delivery
test/fixtures/install_golden/tree/  # generated-host schema/migration contract
guides/flows/                       # public sender contract
guides/recipes/                     # receiver verification guidance
```

### Pattern 1: Single-Shot Worker, Sigra-Owned Retry Policy
**What:** The worker executes exactly one wire attempt per queued job; Sigra decides whether another attempt exists by updating persisted delivery state and explicitly enqueuing the next scheduled job. [VERIFIED: context] [VERIFIED: codebase]
**When to use:** Every webhook attempt in Phase 98. [VERIFIED: context]
**Example:**
```elixir
# Source: https://hexdocs.pm/oban/Oban.Job.html
# Pattern adapted to Sigra's fixed six-attempt policy
next_job =
  Sigra.Workers.WebhookDelivery.new(
    %{"delivery_id" => delivery.delivery_id},
    schedule_in: {5, :minutes},
    unique: [period: {6, :hours}, fields: [:worker, :args], states: :incomplete]
  )
```

### Pattern 2: Parent Summary + Attempt Row in One Transaction
**What:** Update `webhook_deliveries` and insert a `webhook_delivery_attempts` row inside the same `Repo.transact/2` call. [VERIFIED: context] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html]
**When to use:** Every attempt result, including local invariant failures that never hit the wire. [VERIFIED: context]
**Example:**
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Multi.html
Ecto.Multi.new()
|> Ecto.Multi.update(:delivery, delivery_changeset)
|> Ecto.Multi.insert(:attempt, attempt_changeset)
|> Repo.transact()
```

### Pattern 3: Keep Delivery Summary Denormalized, Keep Attempts Append-Only
**What:** `webhook_deliveries` answers “what is the current state now?” while `webhook_delivery_attempts` answers “what happened over time?”. [VERIFIED: context]
**When to use:** Schema design, query design, and Phase 99 UI planning. [VERIFIED: context]
**Example:** Use parent fields for `status`, `attempt_count`, `next_attempt_at`, `last_http_status`, `last_error_category`, and `dead_lettered_at`; use child rows for `attempt_number`, `started_at`, `finished_at`, `endpoint_url`, `response_status`, `retry_after_seconds`, and truncated detail text. [VERIFIED: context] [VERIFIED: codebase]

### Pattern 4: Classification Before Scheduling
**What:** Normalize requester results into bounded categories before touching persistence or scheduling. [VERIFIED: context]
**When to use:** Inside `Sigra.Workers.WebhookDelivery.perform/1` after a request returns or a local invariant fails. [VERIFIED: context] [VERIFIED: codebase]
**Example:** `2xx => delivered`; `408|429|5xx|transport timeout/tls/connect => retryable`; other `4xx => dead_lettered`; missing local rows or invalid signing secret => terminal local-state/configuration, with missing delivery rows persisted as orphan issue records keyed by `delivery_id` so they do not disappear. [VERIFIED: context]

### Anti-Patterns to Avoid
- **Raw Oban semantics as public product contract:** Official Oban retries/discards are useful internals, but Phase 98 explicitly forbids making them the source of truth. [VERIFIED: context] [CITED: https://hexdocs.pm/oban/error_handling.html]
- **Separate commits for summary and attempt rows:** This violates D-98-14 and creates dashboards that disagree with the forensic timeline. [VERIFIED: context]
- **Silent `{:cancel, reason}` for local invariant failures:** Current worker cancels disabled subscriptions and missing rows; Phase 98 requires those outcomes to persist visible terminal state instead, including an orphan persisted issue when the parent delivery row is unexpectedly missing. [VERIFIED: codebase] [VERIFIED: context]
- **Receiver-side filtering as the only gate:** Routing must stay subscription-scoped before delivery rows are created. [VERIFIED: codebase] [VERIFIED: requirements]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Public retry semantics | Ad hoc timers or sleeps inside `perform/1` | Oban scheduled jobs plus Sigra-owned persisted delivery policy | Sleeps tie worker occupancy to backoff time and hide the contract outside the database. [CITED: https://hexdocs.pm/oban/Oban.Job.html] [VERIFIED: context] |
| Transactional co-fate | Separate `Repo.update` then `Repo.insert` calls | `Ecto.Multi` + `Repo.transact/2` | Ecto’s transaction primitives already model ordered, abort-on-error writes and are already used in Sigra’s webhook persistence path. [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] [VERIFIED: codebase] |
| Attempt history | Log scraping or Oban `errors` as the operator surface | `webhook_delivery_attempts` child table | Oban stores worker execution errors for jobs, but Phase 98 requires Sigra-owned history independent of queue internals. [CITED: https://hexdocs.pm/oban/error_handling.html] [VERIFIED: context] |
| Duplicate attempt suppression | Custom side table keyed by event only | Oban unique jobs keyed by `delivery_id` args across incomplete states | Official Oban uniqueness already supports `fields`, `keys`, `states`, and `schedule_in` for delivery-lineage jobs. [CITED: https://hexdocs.pm/oban/unique_jobs.html] [CITED: https://hexdocs.pm/oban/Oban.Job.html] |

**Key insight:** The hard part in this phase is not HTTP POSTing; it is making current state, retry intent, and historical truth converge in one inspectable persisted model. [VERIFIED: context] [VERIFIED: codebase]

## Common Pitfalls

### Pitfall 1: Letting queue internals define product semantics
**What goes wrong:** The system “works” operationally, but operators can only explain failures by reading `oban_jobs` state or logs. [VERIFIED: context]
**Why it happens:** Oban already has retryable/discarded states, so it is tempting to stop there. [CITED: https://hexdocs.pm/oban/job_lifecycle.html]
**How to avoid:** Persist Sigra-owned delivery summary and attempt rows for every outcome. [VERIFIED: context]
**Warning signs:** A Phase 99 screen would need Oban `errors`, `scheduled_at`, or state strings to explain a webhook delivery. [VERIFIED: context]

### Pitfall 2: Consuming retry budget on local invariant failures
**What goes wrong:** Missing rows, disabled subscriptions, or invalid signing secrets keep retrying even though no future attempt can succeed. [VERIFIED: context]
**Why it happens:** Current worker returns `{:cancel, reason}` for some local failures and does not persist them. [VERIFIED: codebase]
**How to avoid:** Classify local invariant/configuration failures as visible terminal states that do not schedule another attempt. [VERIFIED: context]
**Warning signs:** Delivery rows remain `pending` after a worker reported `{:cancel, :subscription_disabled}` or `{:cancel, :invalid_signing_secret}`. [VERIFIED: codebase]

### Pitfall 3: Divergent parent and child history
**What goes wrong:** The delivery summary says one thing while the attempts ledger says another. [VERIFIED: context]
**Why it happens:** Summary update and attempt insertion happen in separate commits or one path forgets one side. [VERIFIED: context]
**How to avoid:** Use one `Repo.transact/2` boundary per attempt outcome. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]
**Warning signs:** `attempt_count` does not equal the number of child rows, or `dead_lettered_at` exists without a terminal attempt row. [VERIFIED: context]

### Pitfall 4: Breaking auth success when endpoints fail
**What goes wrong:** User registration or identity mutations start failing because webhook delivery was coupled to remote endpoint success instead of local persistence only. [VERIFIED: requirements] [VERIFIED: codebase]
**Why it happens:** Delivery HTTP work drifts into the auth-path transaction or retry logic mutates outer transaction semantics. [VERIFIED: codebase]
**How to avoid:** Keep Phase 97’s outbox-first seam intact and verify failed endpoints only affect post-commit delivery rows and attempts. [VERIFIED: codebase] [VERIFIED: context]
**Warning signs:** A failing endpoint causes `Auth.register/3`, `Organizations.remove_member/3`, or `ServiceAccounts.revoke/3` to return an error after local validations already passed. [VERIFIED: codebase]

## Code Examples

Verified patterns from official sources:

### Compose webhook persistence into outer domain work
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Multi.html
outer_multi
|> Ecto.Multi.append(Sigra.Webhooks.dispatch_multi(config, "user.created", {:changes_key, :user}))
|> Repo.transact()
```

### Schedule one explicit future retry
```elixir
# Source: https://hexdocs.pm/oban/Oban.Job.html
Sigra.Workers.WebhookDelivery.new(
  %{"delivery_id" => delivery_id},
  schedule_in: {15, :minutes}
)
```

### Protect against duplicate queued retries for the same delivery lineage
```elixir
# Source: https://hexdocs.pm/oban/unique_jobs.html
Sigra.Workers.WebhookDelivery.new(
  %{"delivery_id" => delivery_id},
  schedule_in: {1, :hour},
  unique: [fields: [:worker, :args], states: :incomplete, period: {6, :hours}]
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Fire-and-forget or sync fallback webhook calls | Outbox-first persistence followed by async execution | Locked in Phase 97 on 2026-05-06. [VERIFIED: PROJECT.md] [VERIFIED: codebase] | Auth and identity success stay independent from endpoint availability. [VERIFIED: requirements] |
| Queue engine retry policy as the only truth | Product-owned retry schedule plus queue-backed execution | Required by Phase 98 decisions on 2026-05-06. [VERIFIED: context] | Operators can inspect delivery semantics from Sigra tables without reading Oban internals. [VERIFIED: context] |
| One mutable delivery row only | Summary row plus append-only attempt ledger | Required by D-98-10..14 on 2026-05-06. [VERIFIED: context] | Phase 99 gets cheap list views and accurate forensic timelines. [VERIFIED: context] |

**Deprecated/outdated:**
- Relying on `max_attempts` + automatic Oban backoff as the public delivery contract is outdated for this phase because the locked decisions explicitly move semantics into Sigra-owned persistence. [VERIFIED: context] [CITED: https://hexdocs.pm/oban/error_handling.html]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Keeping OTP `:httpc` for Phase 98 is sufficient because the phase’s core risk is persisted reliability semantics, not HTTP-client feature breadth. [ASSUMED] | Standard Stack | If wrong, later implementation may need a transport swap to support richer timeout/header handling. |

## Resolved Implementation Choice

1. **Persist only `Retry-After` from response headers in Phase 98.**
   - Resolution: The Phase 98 contract requires status, retryability, optional `Retry-After`, and bounded error detail, but does not require broader response-header capture. [VERIFIED: context]
   - Decision: Change the requester/response seam enough to surface response headers so `Retry-After` can be parsed, persisted on attempt rows, and used to delay the next scheduled attempt without expanding the six-attempt budget. [VERIFIED: requirements] [VERIFIED: context]
   - Deferred: Any broader response-header capture remains out of scope for `WH-02` and can be revisited only if a later operator or replay feature needs it. [VERIFIED: requirements]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / Mix | library compile and tests | ✓ | Elixir 1.19.5 / Mix 1.19.5 | — [VERIFIED: local environment] |
| PostgreSQL server on `localhost:5432` | webhook integration and atomicity tests | ✓ | accepting connections; local binaries `14.17` | Docker can start disposable Postgres if needed. [VERIFIED: local environment] [VERIFIED: CLAUDE.md] |
| Oban dependency in host app | async webhook delivery when webhooks are enabled | ✓ in repo deps | `2.21.1` locked | None when feature is enabled; webhook delivery stays async-only. [VERIFIED: mix.lock] [VERIFIED: codebase] |
| Docker | disposable local Postgres for test runs | ✓ | 29.4.1 | Existing local Postgres also works. [VERIFIED: local environment] |

**Missing dependencies with no fallback:**
- None for research. For implementation verification, a host with webhooks enabled still has no supported synchronous fallback if Oban is absent. [VERIFIED: codebase]

**Missing dependencies with fallback:**
- None. [VERIFIED: local environment]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit on Mix/Elixir. [VERIFIED: test/test_helper.exs] |
| Config file | [`test/test_helper.exs`](/Users/jon/projects/sigra/test/test_helper.exs:1), [`config/test.exs`](/Users/jon/projects/sigra/config/test.exs:1) |
| Quick run command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/webhooks_integration_test.exs test/sigra/webhooks_audit_atomicity_test.exs -x` [VERIFIED: codebase] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` [VERIFIED: CLAUDE.md] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WH-02.1 | Only matching subscriptions get delivery rows for an event type. [VERIFIED: requirements] | integration | `... mix test test/sigra/webhooks_integration_test.exs -x` | ✅ |
| WH-02.2 | Retryable outcomes create an attempt row, update delivery summary, and enqueue exactly one next scheduled attempt. [VERIFIED: requirements] | unit + integration | `... mix test test/sigra/workers/webhook_delivery_test.exs test/sigra/webhooks_integration_test.exs -x` | ❌ Wave 0 |
| WH-02.3 | Terminal `4xx` and local invariant failures dead-letter in place without further retries. [VERIFIED: requirements] | unit + integration | `... mix test test/sigra/workers/webhook_delivery_test.exs test/sigra/webhooks_integration_test.exs -x` | ❌ Wave 0 |
| WH-02.4 | Auth and identity mutations still succeed while downstream endpoints fail, and persisted history reflects failure/retry/dead-letter. [VERIFIED: roadmap] | integration | `... mix test test/sigra/webhooks_audit_atomicity_test.exs` plus new path-specific specs | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/workers/webhook_delivery_test.exs -x` [VERIFIED: codebase]
- **Per wave merge:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/webhooks_integration_test.exs test/sigra/webhooks_audit_atomicity_test.exs` [VERIFIED: codebase]
- **Phase gate:** Full suite green before `/gsd-verify-work`. [VERIFIED: config.json]

### Wave 0 Gaps
- [ ] `test/sigra/workers/webhook_delivery_test.exs` — add retryable vs terminal classification, `Retry-After`, dead-letter summary updates, and next-attempt enqueue proofs. [VERIFIED: codebase]
- [ ] `test/sigra/webhooks_integration_test.exs` — add persisted `webhook_delivery_attempts` coverage and summary-query assertions. [VERIFIED: codebase]
- [ ] New integration spec covering a real auth path plus a failing endpoint requester so local mutation success and delivery failure history are proven together. [VERIFIED: roadmap] [VERIFIED: codebase]
- [ ] New identity-path spec for at least one non-auth mutation already wired to webhooks, such as organization membership or service-account revoke. [VERIFIED: codebase]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Keep webhook failures post-commit so registration/authentication success is not coupled to endpoint availability. [VERIFIED: requirements] [VERIFIED: codebase] |
| V3 Session Management | yes | Session-related webhook events must remain observational only; retries must not mutate session success semantics. [VERIFIED: guides/flows/webhooks.md] [VERIFIED: requirements] |
| V4 Access Control | no | Phase 98 changes delivery reliability, not authorization policy; admin access control belongs to Phase 99 generated UX. [VERIFIED: roadmap] |
| V5 Input Validation | yes | Validate endpoint URLs, bounded status categories, attempt counters, and summary-state transitions through Ecto changesets and explicit classification code. [VERIFIED: codebase] |
| V6 Cryptography | yes | Reuse `Sigra.Webhooks.Signature` HMAC signing with fresh per-attempt timestamp; never hand-roll alternate digest logic. [VERIFIED: codebase] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Duplicate retry jobs for one `delivery_id` | Tampering / DoS | Use Oban unique job options keyed on worker + args across incomplete states for scheduled retries. [CITED: https://hexdocs.pm/oban/unique_jobs.html] |
| Replay or receiver-side dedupe failure | Repudiation | Keep stable `delivery_id` across retries and document receiver dedupe on `delivery_id`, not `event_id`. [VERIFIED: guides/recipes/webhook-verification.md] |
| SSRF or unsafe endpoint targeting | Information Disclosure / Tampering | Keep current HTTPS-or-localhost endpoint validation in place; broader egress controls remain future `WH-06`, so do not widen scope in Phase 98. [VERIFIED: codebase] [VERIFIED: requirements] |
| Secret leakage into queue or history tables | Information Disclosure | Continue storing only `delivery_id` in job args and never persist signing secrets or full signature material in attempts. [VERIFIED: codebase] [VERIFIED: context] |
| Failure-state drift between summary and history | Repudiation | Co-fate parent summary updates and child attempt inserts in one DB transaction. [VERIFIED: context] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] |

## Sources

### Primary (HIGH confidence)
- [`lib/sigra/webhooks.ex`](/Users/jon/projects/sigra/lib/sigra/webhooks.ex:1) - public webhook API, queue helper, config helpers. [VERIFIED: codebase]
- [`lib/sigra/webhooks/dispatcher.ex`](/Users/jon/projects/sigra/lib/sigra/webhooks/dispatcher.ex:1) - persisted subscription matching and event/delivery fan-out. [VERIFIED: codebase]
- [`lib/sigra/workers/webhook_delivery.ex`](/Users/jon/projects/sigra/lib/sigra/workers/webhook_delivery.ex:1) - single-shot worker semantics and current failure handling. [VERIFIED: codebase]
- [`lib/sigra/auth.ex`](/Users/jon/projects/sigra/lib/sigra/auth.ex:243), [`lib/sigra/organizations.ex`](/Users/jon/projects/sigra/lib/sigra/organizations.ex:984), [`lib/sigra/service_accounts.ex`](/Users/jon/projects/sigra/lib/sigra/service_accounts.ex:31) - existing auth/identity webhook integration points. [VERIFIED: codebase]
- [`test/sigra/webhooks_integration_test.exs`](/Users/jon/projects/sigra/test/sigra/webhooks_integration_test.exs:1), [`test/sigra/workers/webhook_delivery_test.exs`](/Users/jon/projects/sigra/test/sigra/workers/webhook_delivery_test.exs:1), [`test/sigra/webhooks_audit_atomicity_test.exs`](/Users/jon/projects/sigra/test/sigra/webhooks_audit_atomicity_test.exs:1) - current proof surface and gaps. [VERIFIED: codebase]
- [`mix.exs`](/Users/jon/projects/sigra/mix.exs:1), [`mix.lock`](/Users/jon/projects/sigra/mix.lock:1) - dependency constraints and locked versions. [VERIFIED: codebase]
- https://hexdocs.pm/ecto/Ecto.Multi.html - `run/3`, `append/2`, and transaction composition. [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html]
- https://hexdocs.pm/ecto/Ecto.Repo.html - `Repo.transact/2` semantics and failure shape. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]
- https://hexdocs.pm/oban/error_handling.html - default retries, backoff, and discard behavior. [CITED: https://hexdocs.pm/oban/error_handling.html]
- https://hexdocs.pm/oban/Oban.Job.html - `schedule_in`, uniqueness options, and job states. [CITED: https://hexdocs.pm/oban/Oban.Job.html]
- https://hexdocs.pm/oban/unique_jobs.html - uniqueness states, conflict handling, and replace options. [CITED: https://hexdocs.pm/oban/unique_jobs.html]
- https://hexdocs.pm/oban/job_lifecycle.html - state transitions and terminal job states. [CITED: https://hexdocs.pm/oban/job_lifecycle.html]

### Secondary (MEDIUM confidence)
- None.

### Tertiary (LOW confidence)
- None beyond the explicitly logged assumption.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - the phase can stay on the repo’s existing Ecto/Oban/Jason stack, and those choices are directly verified in code plus official docs. [VERIFIED: codebase] [CITED: https://hexdocs.pm/oban/Oban.Job.html]
- Architecture: HIGH - the persisted outbox seam, auth/identity integration points, and locked Phase 98 decisions are all explicit in local artifacts. [VERIFIED: codebase] [VERIFIED: context]
- Pitfalls: HIGH - the main regressions are visible from the current worker code, official Oban semantics, and the roadmap requirement to keep auth success independent from endpoint failure. [VERIFIED: codebase] [CITED: https://hexdocs.pm/oban/error_handling.html] [VERIFIED: roadmap]

**Research date:** 2026-05-06
**Valid until:** 2026-06-05 for local code facts; re-check official Oban/Ecto docs if implementation starts after dependency upgrades. [VERIFIED: codebase] [CITED: https://hexdocs.pm/oban/Oban.Job.html]

## RESEARCH COMPLETE
