# Phase 104: Failed-delivery replay controls - Research

**Researched:** 2026-05-07
**Domain:** Elixir/Phoenix webhook replay controls on top of Sigra's existing persisted delivery pipeline
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

Copied verbatim from `.planning/phases/104-failed-delivery-replay-controls/104-CONTEXT.md`. [VERIFIED: codebase grep]

### Locked Decisions
- **D-104-01 — Ship replay through admin UI in Phase 104, not a same-phase CLI.** The supported operator surface for Phase 104 should be the existing admin webhook UI. Do not expand the public/operator contract to include a new runtime CLI in the same phase.
- **D-104-02 — Keep the replay engine library-owned underneath the admin surface.** The durable replay state transition should live in `Sigra.Webhooks`, with thin admin action wrappers in `Sigra.Admin.Webhooks.Actions`. LiveViews must not own replay business rules directly.
- **D-104-03 — Failures inbox may expose a narrow replay shortcut, but delivery detail is the authority.** Operators should be able to start recovery quickly from the global failures inbox, while the shared delivery detail page remains the canonical place for eligibility, confirmation, lineage, and forensic truth.
- **D-104-04 — Replay creates a new delivery row, not new attempts on the original row.** Phase 104 should not mutate the original delivery back to `pending` or append replay as attempt `N+1`. Replay is a new delivery lifecycle and must get a new `delivery_id`.
- **D-104-05 — Preserve the original failed lineage as immutable truth.** The original delivery row remains failed or dead-lettered. Replay must create a clearly linked child delivery so operators can see both the failed automatic path and the later manual recovery path.
- **D-104-06 — Use explicit self-linked replay lineage metadata on `webhook_deliveries`.** The replayed child row should record its source delivery through a self-reference such as `replayed_from_webhook_delivery_id`, and Phase 104 should also keep a cheap-to-query root lineage pointer rather than requiring recursive reconstruction for common operator views.
- **D-104-07 — Each replay child starts a fresh attempt ledger.** Automatic attempts remain scoped to one delivery row. A replayed child begins at attempt `1` and owns its own `webhook_delivery_attempts` history.
- **D-104-08 — Record operator-trigger metadata on the replayed child.** The replayed delivery should persist who triggered it, when, and from which Sigra-owned surface so later investigation does not depend on inferred timestamps or external logs.
- **D-104-09 — Replay is allowed only for dead-lettered deliveries in Phase 104.** Do not allow replay from `pending`, in-flight, `retry_scheduled`, or already-`delivered` states. The current retry state model remains truthful and should not be bypassed by ad hoc manual resend.
- **D-104-10 — Replay eligibility within dead-lettered rows is reason-gated.** Allow replay for receiver-side or fixable configuration outcomes that a human may have repaired, such as retry exhaustion after transport/5xx/backpressure or terminal remote 4xx outcomes where the receiver was corrected. Allow local configuration failures only if live preconditions now pass at replay time.
- **D-104-11 — Truth-gap failures are not replayable.** If Sigra cannot honestly reconstruct the original send context, such as missing delivery dependencies or orphaned terminal issue rows, replay must be rejected with an explicit operator-facing error instead of best-effort guessing.
- **D-104-12 — Block double-submit with Sigra-owned persistence rules, not queue semantics alone.** Phase 104 must prevent two operators from opening concurrent replay paths for the same failed source row. Do not rely on Oban uniqueness as the main safety mechanism.
- **D-104-13 — Replay must re-check current preconditions before inserting the child lineage.** If webhook delivery is disabled, the subscription is disabled, or another required runtime invariant still fails, Sigra should reject the replay explicitly instead of enqueueing a doomed child delivery.
- **D-104-14 — Keep replay UX consistent with Sigra’s list/detail admin idiom.** The failures inbox stays a delivery-row triage surface; the shared delivery detail page owns the deeper operational truth and confirmation flow; subscription detail remains secondary for read-only “recent deliveries” context, not the primary replay home.
- **D-104-15 — Show replay lineage as delivery history, not queue internals.** On the original delivery page, operators should see any replay children with their status and links. On a replayed child page, operators should see both the immediate parent and the root failed delivery. Do not bury lineage only in audit logs or attempt rows.
- **D-104-16 — Keep the attempt timeline scoped to one delivery.** The UI must not present replay as “attempt 7” or otherwise merge manual recovery into the transport retry timeline for the original delivery.
- **D-104-17 — Operator errors must be explicit and state-specific.** Sigra should tell the operator exactly why replay is rejected, such as “already delivered,” “still in flight,” “already has a scheduled retry,” “replay already exists,” or “delivery context incomplete.”
- **D-104-18 — Verification must prove the full receiver-recovery story.** Phase 104 should show: a delivery fails into dead-letter, the operator inspects truthful history, downstream health is restored, replay creates a new delivery lineage, and the replayed delivery succeeds while the original failed lineage remains visible.
- **D-104-19 — The public receiver contract stays stable.** Replayed deliveries still use Sigra’s normal signed delivery contract and receiver-owned dedupe expectations. Phase 104 must not imply that manual replay changes the published verification boundary.
- **D-104-20 — Shift routine webhook product and architecture choices left within GSD.** Downstream research, planning, and execution should preserve decisive recommendations that optimize for operator trust, least surprise, strong DX, and truthful history. Escalate only changes that materially affect the security model, public webhook contract, semver surface, or generated-host contract.

### Claude's Discretion
- Exact replay lineage field names and indexing strategy, as long as parent/root linkage stays cheap to query
- Exact partial-uniqueness or transactional guard mechanism used to prevent concurrent replay children
- Exact admin copy, badges, and layout for replay lineage sections, provided delivery truth stays explicit
- Exact split between failures-inbox shortcut behavior and delivery-detail confirmation UX
- Exact test decomposition across library, admin LiveView, generated-host, and integration lanes

### Deferred Ideas (OUT OF SCOPE)
- Equivalent runtime CLI or mix task for replay
- Batch replay, endpoint-wide replay, or replay-run entities
- Replaying `retry_scheduled` deliveries with cancel/replace semantics
- Public or tenant-scoped self-service replay surfaces
- Free-form operator notes, incident comments, or approval workflows on replay
- Cross-lineage analytics beyond direct parent/root lineage navigation
- Any contract that preserves the original `delivery_id` across replayed child deliveries
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WH-05 | Maintainer or admin can manually replay a dead-lettered delivery from supported control surfaces while preserving truthful delivery history. | Use a library-owned `Sigra.Webhooks.replay_delivery/4` transaction that inserts a new child delivery row, keeps the source row immutable, reuses `append_delivery_jobs_multi/4` for initial enqueue, records replay metadata on the child, and exposes only thin admin wrappers and LiveView controls. [VERIFIED: codebase grep] |
</phase_requirements>

## Summary

Phase 104 should be planned as a schema-plus-library transaction phase first and a UI phase second. The existing webhook system already has the correct primitives for this: `Sigra.Webhooks.Dispatcher` inserts canonical delivery rows with fresh `delivery_id` values, `Sigra.Webhooks.append_delivery_jobs_multi/4` enqueues persisted deliveries inside a transaction, `Sigra.Workers.WebhookDelivery` treats each delivery row as one bounded retry lifecycle, and the admin delivery/failures pages already read from `webhook_deliveries` plus `webhook_delivery_attempts`. Replay should extend that model, not bypass it. [VERIFIED: codebase grep]

The safest design is: dead-lettered source row stays immutable, replay inserts a new child `webhook_deliveries` row with a fresh `delivery_id`, the child starts at `attempt_count = 0`, and the child is enqueued through the existing delivery-job seam in the same transaction. That keeps the receiver contract stable because Sigra already signs requests from the persisted delivery row and the receiver already dedupes on `delivery_id`; a replay is therefore a new logical delivery, not a new attempt on the old one. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/oban/Oban.Worker.html] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html]

The planning risk is not queueing; it is truthfulness. The plan must include schema changes for lineage and operator metadata, an explicit eligibility/guard API with typed replay errors, DB-backed duplicate prevention, detail/query updates that surface parent/root lineage without merging attempt timelines, and proof that a dead-lettered delivery can be repaired and replayed successfully while the original failure remains visible. [VERIFIED: codebase grep]

**Primary recommendation:** Implement replay as a `Sigra.Webhooks` transaction that creates one new child delivery row per eligible dead-lettered source row and lets the existing worker pipeline handle the child from there. [VERIFIED: codebase grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Replay eligibility, state guards, and typed failure reasons | API / Backend | Database / Storage | Current business rules already live in `Sigra.Webhooks` and worker classification code, while the UI is intentionally thin. [VERIFIED: codebase grep] |
| Concurrent replay prevention | Database / Storage | API / Backend | Phase context forbids relying on queue uniqueness; the durable guard belongs in the replay insert path plus an index/constraint. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html] [CITED: https://hexdocs.pm/oban/unique_jobs.html] |
| Replay child creation and initial enqueue | API / Backend | Database / Storage | `Dispatcher.insert_deliveries/4` and `append_delivery_jobs_multi/4` already express “persist then enqueue” inside one transaction. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] |
| Delivery lineage persistence | Database / Storage | API / Backend | Parent/root pointers and replay metadata are durable truth read by operator surfaces later. [VERIFIED: codebase grep] |
| Replay controls and confirmation UI | Frontend Server (SSR) | API / Backend | LiveViews should render detail/failures controls, but the mutation boundary stays in `Sigra.Admin.Webhooks.Actions` and `Sigra.Webhooks`. [VERIFIED: codebase grep] |
| Receiver proof after replay | API / Backend | Frontend Server (SSR) | The success proof is still keyed by persisted delivery rows and `delivery_id`, while the admin surface only exposes the history. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] |

## Project Constraints (from CLAUDE.md)

- Use `Req` for HTTP requests; do not introduce `HTTPoison`, `Tesla`, or `:httpc`. [VERIFIED: codebase grep]
- Use Phoenix/LiveView conventions already established by the project, including `<Layouts.app ...>` and standard `<.input>` / `<.icon>` helpers when UI changes reach HEEx templates. [VERIFIED: codebase grep]
- Use `Ecto.Changeset.get_field/2` and avoid struct access patterns that violate the project’s Ecto/Elixir rules. [VERIFIED: codebase grep]
- Use `start_supervised!/1` in tests and avoid `Process.sleep/1`. [VERIFIED: codebase grep]
- `mix test` is the repo’s real validation lane; `test/test_helper.exs` excludes no default tags and requires a live Postgres at `localhost:5432` with `postgres/postgres`. [VERIFIED: codebase grep]
- `CLAUDE.md` says to run `mix precommit` when done, but `mix help precommit` currently fails because no such task exists in this repo; the planner should rely on explicit `mix test` commands unless another phase adds that alias. [VERIFIED: codebase grep]

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Ecto | `3.13.5` in `mix.lock`; current Hex release shown as `3.13.5` | Build the replay transaction, precondition checks, and changeset-backed error surfaces. | The repo already uses `Ecto.Multi` and changeset transactions for webhook persistence, and official docs position `Ecto.Multi` for grouped repo operations. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] |
| Ecto SQL | `3.13.5` in `mix.lock`; current Hex release shown as `3.13.5` | Add lineage columns and the replay-concurrency index in generated migrations and example migrations. | Ecto SQL migration docs explicitly support partial indexes with `:where`, which is the standard way to express “unique when not null” replay lineage guards. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html] |
| Oban | repo lock `2.21.1`; Hex latest is `2.22.1` as of 2026-04-30 | Execute replay children using the existing async worker contract. | The repo already stores only `delivery_id` in jobs and already enqueues fresh jobs transactionally; Phase 104 should reuse that contract instead of inventing a second queue path. Stay on the repo lock for this phase unless you deliberately scope an upgrade. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/oban/Oban.Worker.html] [VERIFIED: hex.pm registry] |
| Phoenix LiveView | `1.1.28` in `mix.lock`; current Hex release shown as `1.1.28` | Add replay controls and lineage rendering on existing admin delivery/failures/detail pages. | Current webhook operator surfaces are LiveViews already, and the phase context explicitly keeps replay in the existing admin UI rather than adding a CLI. [VERIFIED: codebase grep] [VERIFIED: hex.pm registry] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Flop | `0.26.3` in `mix.lock`; current Hex package page shows `0.26.3` | Keep failures inbox filtering/pagination truthful if replay-related filters or counts expand. | Reuse the existing failures/query normalization pattern instead of hand-rolling list state. [VERIFIED: codebase grep] [VERIFIED: hex.pm registry] |
| Flop Phoenix | `0.26.0` in `mix.lock`; current Hex release shown as `0.26.0` | Preserve the current admin list/filter ergonomics if replay affordances add URL-driven filter states. | Use only if the plan adds query parameters or summary chips to existing views. [VERIFIED: codebase grep] [VERIFIED: hex.pm registry] |
| Req | `0.5.17` current Hex release; already present in lockfile transitively | Honor the project’s preferred HTTP-client rule if any replay-proof helpers or receiver fixtures need outbound requests outside the existing worker seam. | Do not add a second HTTP client. The existing project instruction explicitly prefers Req. [VERIFIED: codebase grep] [VERIFIED: hex.pm registry] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| DB-backed replay guard on `webhook_deliveries` | Oban job uniqueness only | Oban uniqueness still returns `{:ok, job}` when an equivalent job already exists, so it is not a sufficient truth contract for “replay already exists.” [CITED: https://hexdocs.pm/oban/unique_jobs.html] |
| Child delivery lineage row | Reusing the source row and setting it back to `pending` | This would destroy the current parent summary truth and merge manual recovery into the automatic retry timeline, which Phase 104 explicitly forbids. [VERIFIED: codebase grep] |
| Thin admin wrapper over `Sigra.Webhooks` | LiveView-owned replay logic | Existing admin mutation patterns keep global-admin authorization in `Sigra.Admin.Webhooks.Actions` and business rules in library modules; deviating here would make testing and generated-host parity worse. [VERIFIED: codebase grep] |

**Installation:**
```bash
# No new dependencies are required for Phase 104.
mix deps.get
```

**Version verification:** `mix.exs` currently pins `{:ecto, "~> 3.12"}`, `{:ecto_sql, "~> 3.12"}`, `{:phoenix_live_view, "~> 1.1"}`, `{:flop, "~> 0.26.3"}`, `{:flop_phoenix, "~> 0.26.0"}`, and optional `{:oban, "~> 2.17"}`; `mix.lock` resolves those to `3.13.5`, `3.13.5`, `1.1.28`, `0.26.3`, `0.26.0`, and `2.21.1` respectively. Hex shows Ecto `3.13.5`, Phoenix LiveView `1.1.28`, Flop `0.26.3`, Flop Phoenix `0.26.0`, and Req `0.5.17` as current, while Oban has moved to `2.22.1` on 2026-04-30. Plan this phase against the repo’s locked versions, not the latest Oban release. [VERIFIED: codebase grep] [VERIFIED: hex.pm registry]

## Architecture Patterns

### System Architecture Diagram

```text
Operator opens failures inbox or delivery detail
  -> LiveView renders delivery row + replay eligibility badges
  -> "Replay" action posts to Sigra.Admin.Webhooks.Actions.replay_delivery/...
  -> Action authorizes global admin and delegates to Sigra.Webhooks.replay_delivery/...
  -> Sigra.Webhooks transaction loads source delivery + subscription + event
  -> Decision point: source status == dead_lettered? current config valid? context complete? existing child already present?
     -> no: return typed replay error for the LiveView to render truthfully
     -> yes:
        -> insert child webhook_deliveries row with fresh delivery_id, parent pointer, root pointer, and operator metadata
        -> enqueue child via append_delivery_jobs_multi/4 in the same transaction
        -> worker sends child delivery through existing Signature + RetryPolicy + WebhookDelivery pipeline
        -> admin detail loaders show source row, child row, root lineage, and separate attempt ledgers
        -> receiver verifies normal signed request and dedupes on the new child delivery_id
```

The existing persisted-delivery architecture already separates event row, delivery summary row, attempt ledger, and async worker; replay should add lineage metadata to that graph rather than replacing any tier. [VERIFIED: codebase grep]

### Recommended Project Structure
```text
lib/
├── sigra/webhooks.ex                 # replay API, guards, transaction, typed errors
├── sigra/admin/webhooks/actions.ex   # thin admin wrapper entrypoint
├── sigra/admin/webhooks/detail.ex    # delivery/subscription lineage loaders
├── sigra/admin/webhooks/failures.ex  # failures inbox replay affordance data
└── sigra/admin/live/                 # delivery detail + failures UI updates only

priv/templates/sigra.install/core/
├── webhook_migration.exs             # lineage columns + replay guard index
└── webhook_delivery.ex               # generated schema fields/constraints

test/
├── sigra/webhooks_integration_test.exs
├── sigra/workers/webhook_delivery_test.exs
└── sigra/admin/webhooks_test.exs
```

This matches the repo’s existing “library-owned runtime, thin generated/admin seams” rule and the Phase 104 context. [VERIFIED: codebase grep]

### Pattern 1: Replay As A New Delivery Lineage
**What:** Insert a new `webhook_deliveries` row for replay, linked to the source row and root row, then enqueue that new row using the existing delivery-job seam. [VERIFIED: codebase grep]

**When to use:** Every time an eligible dead-lettered delivery is replayed, including replaying a previously replayed child that dead-lettered again. [VERIFIED: .planning/phases/104-failed-delivery-replay-controls/104-CONTEXT.md]

**Example:**
```elixir
# Source: local repo pattern + Ecto.Multi docs
Multi.new()
|> Multi.run(:source_delivery, fn repo, _changes -> load_replay_source(repo, config, delivery_id) end)
|> Multi.run(:replay_guard, fn repo, %{source_delivery: source} -> ensure_replayable(repo, config, source) end)
|> Multi.insert(:replay_delivery, fn %{source_delivery: source} ->
  delivery_schema.changeset(struct(delivery_schema), %{
    delivery_id: Ecto.UUID.generate(),
    status: "pending",
    attempt_count: 0,
    endpoint_url: source.endpoint_url,
    webhook_subscription_id: source.webhook_subscription_id,
    webhook_event_id: source.webhook_event_id,
    replayed_from_webhook_delivery_id: source.id,
    replay_root_webhook_delivery_id: source.replay_root_webhook_delivery_id || source.id,
    replay_triggered_at: DateTime.utc_now(),
    replay_triggered_by_user_id: actor_id,
    replay_triggered_from_surface: "admin.delivery_detail"
  })
end)
|> Sigra.Webhooks.append_delivery_jobs_multi(config, :replay_delivery)
```
[VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html]

### Pattern 2: DB-Enforced “One Child Per Source” Guard
**What:** Add a uniqueness rule on `replayed_from_webhook_delivery_id` for non-null values and still perform an explicit transaction-time precheck so the UI can return a typed “replay already exists” error before the constraint bubbles. [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html]

**When to use:** Always in the replay insert path; this is the durable answer to concurrent operator clicks. [VERIFIED: .planning/phases/104-failed-delivery-replay-controls/104-CONTEXT.md]

**Example:**
```elixir
# Source: Ecto migration docs
create unique_index(
  :webhook_deliveries,
  [:replayed_from_webhook_delivery_id],
  where: "replayed_from_webhook_delivery_id IS NOT NULL",
  name: :webhook_deliveries_replayed_from_unique_index
)
```
[CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html]

### Pattern 3: Thin Admin Mutation Surface
**What:** Add one new action wrapper in `Sigra.Admin.Webhooks.Actions`, then let LiveViews only open confirmations and render result messages. [VERIFIED: codebase grep]

**When to use:** For both the delivery-detail authority action and any narrow failures-inbox shortcut. [VERIFIED: codebase grep]

**Example:**
```elixir
@spec replay_delivery(map(), Scope.t(), binary(), keyword()) ::
        {:ok, struct()} | {:error, term()}
def replay_delivery(config, %Scope{} = admin_scope, delivery_id, opts \\ []) do
  Authorizer.authorize_global!(admin_scope)
  Sigra.Webhooks.replay_delivery(config, delivery_id, Keyword.put(opts, :scope, admin_scope.scope))
end
```
[VERIFIED: codebase grep]

### Anti-Patterns to Avoid
- **Mutating the source row back to `pending`:** This breaks the dead-letter truth model that Phases 98 and 101 established. [VERIFIED: codebase grep]
- **Appending replay as attempt `N+1`:** The worker and admin detail surfaces treat attempts as one delivery lifecycle; merging replay into attempts would falsify operator history. [VERIFIED: codebase grep]
- **Treating Oban uniqueness as the replay lock:** Official Oban docs make duplicate inserts look successful, which is not the contract Phase 104 needs. [CITED: https://hexdocs.pm/oban/unique_jobs.html]
- **Replaying `retry_scheduled` rows:** That races the built-in retry scheduler and violates the phase’s dead-letter-only rule. [VERIFIED: .planning/phases/104-failed-delivery-replay-controls/104-CONTEXT.md]
- **Changing receiver dedupe to `event_id`:** Sigra’s published contract is still `delivery_id`-based dedupe, including across retries and replayed deliveries. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix/live_view.html]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Replay de-duplication | Queue-only uniqueness or in-memory locks | Ecto transaction + unique index on lineage pointer | The durable truth must survive multiple nodes and concurrent clicks. [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html] [CITED: https://hexdocs.pm/oban/unique_jobs.html] |
| Replay execution path | A second worker or ad hoc HTTP resend function | Existing `Sigra.Workers.WebhookDelivery` job contract | The worker already knows how to sign, classify, persist attempts, and re-enqueue retries for a delivery row. [VERIFIED: codebase grep] |
| Delivery history | Custom replay log table or merged attempt trail | Existing `webhook_deliveries` summary row + `webhook_delivery_attempts` ledger | The repo already treats the parent row as current truth and attempt rows as append-only forensic history. [VERIFIED: codebase grep] |
| Receiver behavior | New replay headers or alternate dedupe keys | Existing signature and `delivery_id` contract | Public docs already define the receiver boundary; Phase 104 explicitly keeps it stable. [VERIFIED: codebase grep] |

**Key insight:** Phase 104 is mostly a composition problem, not a greenfield subsystem. The planner should extend `webhook_deliveries`, `Sigra.Webhooks`, and existing admin detail/query paths instead of introducing new queue, audit, or receiver concepts. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Replaying rows that are not truly terminal
**What goes wrong:** Operators can create a manual replay while automatic retries are still pending. [VERIFIED: .planning/phases/104-failed-delivery-replay-controls/104-CONTEXT.md]
**Why it happens:** The current worker already owns retry scheduling through `retry_scheduled` and `next_attempt_at`, so a naive UI-only replay button can bypass the real state machine. [VERIFIED: codebase grep]
**How to avoid:** Gate replay strictly on `status == "dead_lettered"` plus current preconditions. [VERIFIED: codebase grep]
**Warning signs:** The source row still has `next_attempt_at` set, or the UI offers replay for `retry_scheduled` rows. [VERIFIED: codebase grep]

### Pitfall 2: Losing the original truth when the replay succeeds
**What goes wrong:** A replay appears to “fix” the original row instead of creating a new lineage entry. [VERIFIED: .planning/phases/104-failed-delivery-replay-controls/104-CONTEXT.md]
**Why it happens:** The current detail page only loads one delivery row plus attempts, so it is tempting to reuse the existing row instead of teaching the loader about lineage. [VERIFIED: codebase grep]
**How to avoid:** Keep the source row immutable and extend detail loaders with parent/root/children relations. [VERIFIED: codebase grep]
**Warning signs:** Delivered replay proof exists, but the original `dead_lettered_at` or `attempt_count` vanished. [VERIFIED: codebase grep]

### Pitfall 3: Letting the UI own replay policy
**What goes wrong:** Failures inbox and delivery detail start disagreeing about what is replayable. [VERIFIED: codebase grep]
**Why it happens:** Current LiveViews already open modal confirmations for other actions, so it is easy to push business checks there. [VERIFIED: codebase grep]
**How to avoid:** Return typed replay errors from `Sigra.Webhooks` and render them from both surfaces. [VERIFIED: codebase grep]
**Warning signs:** Separate `if` logic appears in `webhook_delivery_failures_live.ex` and `webhook_delivery_show_live.ex`. [VERIFIED: codebase grep]

### Pitfall 4: Assuming the source delivery context is always replayable
**What goes wrong:** Sigra replays rows whose subscription is now disabled, whose event row is missing, or whose original failure was a local truth gap. [VERIFIED: codebase grep]
**Why it happens:** `WebhookDelivery.perform/1` currently persists terminal local failures when dependencies are missing, so replay must re-check those same invariants before insert. [VERIFIED: codebase grep]
**How to avoid:** Load source delivery, subscription, and event inside the replay transaction and reject any missing or disabled dependency. [VERIFIED: codebase grep]
**Warning signs:** Replay code copies raw IDs without repo lookups. [VERIFIED: codebase grep]

### Pitfall 5: Forgetting generated-host artifacts
**What goes wrong:** The library supports replay lineage, but generated schemas and migrations cannot store the new fields. [VERIFIED: codebase grep]
**Why it happens:** The generated `WebhookDelivery` schema and `webhook_migration.exs` template currently have no replay lineage columns at all. [VERIFIED: codebase grep]
**How to avoid:** Plan library, template, example app, and tests together. [VERIFIED: codebase grep]
**Warning signs:** Only `lib/sigra/` changes are planned for a feature that needs persisted lineage. [VERIFIED: codebase grep]

## Code Examples

Verified patterns from official sources and the current repo:

### Transaction-Owned Replay Insert
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Multi.html
Multi.new()
|> Multi.run(:source, fn repo, _changes -> load_source(repo, delivery_id) end)
|> Multi.insert(:child, child_changeset)
|> Sigra.Webhooks.append_delivery_jobs_multi(config, :child)
|> config.repo.transaction()
```
[CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] [VERIFIED: codebase grep]

### Partial Unique Index For Non-Null Parent Pointer
```elixir
# Source: https://hexdocs.pm/ecto_sql/Ecto.Migration.html
create unique_index(
  :webhook_deliveries,
  [:replayed_from_webhook_delivery_id],
  where: "replayed_from_webhook_delivery_id IS NOT NULL"
)
```
[CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html]

### Existing Job Contract To Reuse
```elixir
# Source: local repo
Sigra.Workers.WebhookDelivery.new(%{"delivery_id" => delivery_id}, queue: "sigra_webhooks")
```
[VERIFIED: codebase grep]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Automatic retries only, no manual replay control | Operator-triggered replay should create a new delivery lifecycle after the automatic lifecycle ends | Planned for Phase 104 on top of the Phase 98/100 pipeline | Operators get recovery control without falsifying retry history. [VERIFIED: codebase grep] |
| One delivery row represented one retry lifecycle only | A replayed child row should form a lineage chain of delivery lifecycles linked by parent/root pointers | Planned for Phase 104 | The UI can show truthful forensic history across multiple recovery attempts. [VERIFIED: .planning/phases/104-failed-delivery-replay-controls/104-CONTEXT.md] |
| Secret rotation changed a single current secret | Phase 103 already established overlap-safe multi-signature rotation while keeping `delivery_id`-based replay protection | Completed 2026-05-07 in Phase 103 | Replay should inherit the current signing contract unchanged and must not add a new receiver rule. [VERIFIED: codebase grep] |

**Deprecated/outdated:**
- Same-row resend or “attempt 7” semantics: outdated for Sigra because the worker, attempt ledger, and admin detail pages are already built around one delivery row per retry lifecycle. [VERIFIED: codebase grep]
- Queue-internal truth as the operator contract: outdated because Phases 98, 100, and 101 already moved operator truth into Sigra-owned tables. [VERIFIED: codebase grep]

## Assumptions Log

All claims in this research were verified from the codebase or cited from official documentation/current package registry pages. No user confirmation is needed for an assumption before planning.

## Open Questions (RESOLVED)

1. **Should replay emit an explicit audit event in addition to replay metadata on the child row?**
   - What we know: Phase 104 requires an auditable new execution path, and the context explicitly requires operator metadata on the replay child. [VERIFIED: .planning/phases/104-failed-delivery-replay-controls/104-CONTEXT.md]
   - What's unclear: None of the listed webhook admin modules currently expose a separate replay-specific audit log seam in the code read for this phase. [VERIFIED: codebase grep]
   - Resolution: Phase 104 will treat replay-child metadata plus visible lineage on admin surfaces as the required audit baseline. A dedicated replay audit event is explicitly deferred unless implementation finds an existing lightweight audit seam that fits without widening scope or changing the public/generated-host contract. [VERIFIED: codebase grep]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Mix compile/test for library and example host | ✓ | `1.19.5` | — |
| Erlang/OTP | Elixir runtime for tests | ✓ | `28` | — |
| Mix | Compile/test/docs workflow | ✓ | bundled with Elixir | — |
| PostgreSQL | `mix test` and webhook integration/admin tests | ✓ | `14.17`; `pg_isready` reports localhost `accepting connections` | Docker one-liner in `CLAUDE.md` if local service is absent. [VERIFIED: codebase grep] |
| Node.js | Example-host browser proof and any Playwright lane | ✓ | `v22.14.0` | — |
| npm | Example-host browser tooling | ✓ | `11.1.0` | — |
| Docker | Fast local Postgres fallback | ✓ | `29.4.1` | Existing local Postgres also works. [VERIFIED: codebase grep] |

**Missing dependencies with no fallback:**
- None. [VERIFIED: local command probes]

**Missing dependencies with fallback:**
- None at research time. [VERIFIED: local command probes]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit with Ecto-backed integration tests and example-host/browser adjuncts. [VERIFIED: codebase grep] |
| Config file | `test/test_helper.exs`. [VERIFIED: codebase grep] |
| Quick run command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/admin/webhooks_test.exs -x` [VERIFIED: codebase grep] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` [VERIFIED: codebase grep] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WH-05 | Dead-lettered delivery can be replayed into a new child row with preserved source truth and successful child delivery | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs -x` | ✅ |
| WH-05 | Replay rejects unsafe states and truth-gap conditions with explicit reasons | unit/integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/workers/webhook_delivery_test.exs test/sigra/webhooks_integration_test.exs -x` | ✅ |
| WH-05 | Admin failures/detail surfaces expose replay affordances and lineage truth without merging attempts | admin integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs -x` | ✅ |
| WH-05 | Generated-host / operator proof shows fail -> inspect -> repair -> replay -> succeed | browser/integration | existing example-host Playwright lane plus receiver proof artifacts; exact command not confirmed in the listed files | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/workers/webhook_delivery_test.exs -x`
- **Per wave merge:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs test/sigra/admin/webhooks_test.exs`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] Add replay-specific integration coverage to `test/sigra/webhooks_integration_test.exs` for source dead-letter -> replay child pending -> child success while source remains dead-lettered. [VERIFIED: codebase grep]
- [ ] Add replay guard and lineage assertions to `test/sigra/admin/webhooks_test.exs`. [VERIFIED: codebase grep]
- [ ] Add example-host/browser proof coverage for the recovery story if Phase 104 must satisfy success criterion 4 inside the milestone’s generated-host evidence lane. [VERIFIED: .planning/phases/104-failed-delivery-replay-controls/104-CONTEXT.md]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Replay is a maintainer/admin operation, not an end-user auth flow. [VERIFIED: .planning/phases/104-failed-delivery-replay-controls/104-CONTEXT.md] |
| V3 Session Management | no | Existing admin sessions are outside this phase’s main responsibility. [VERIFIED: codebase grep] |
| V4 Access Control | yes | `Sigra.Admin.Authorizer.authorize_global!/1` remains the mutation gate in `Sigra.Admin.Webhooks.Actions`. [VERIFIED: codebase grep] |
| V5 Input Validation | yes | Ecto changesets plus typed replay guards in `Sigra.Webhooks` should validate lineage fields and state transitions. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Changeset.html] |
| V6 Cryptography | yes | Replayed children must continue to use `Sigra.Webhooks.Signature` and `:crypto`-backed HMAC signing with a fresh `delivery_id`. [VERIFIED: codebase grep] |

### Known Threat Patterns for Elixir/Phoenix + Ecto + Oban Webhook Replay

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unauthorized operator-triggered replay | Elevation of Privilege | Keep replay behind global-admin authorization and thin action wrappers. [VERIFIED: codebase grep] |
| Double-submit creates two replay children for one source | Tampering | Transaction precheck plus DB uniqueness on parent lineage pointer. [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html] |
| Replay of a truthful-gap or disabled-subscription row | Tampering | Re-load source delivery, event, and subscription inside the replay transaction and reject missing/disabled dependencies. [VERIFIED: codebase grep] |
| Receiver misclassifies replay as duplicate retry | Repudiation | Use a fresh child `delivery_id`; keep receiver contract explicitly keyed to `delivery_id` rather than `event_id`. [VERIFIED: codebase grep] |
| UI hides the original failure after replay success | Repudiation | Preserve immutable source row and render parent/root/child lineage explicitly on detail pages. [VERIFIED: codebase grep] |

## Sources

### Primary (HIGH confidence)
- Local codebase files read in this session — webhook runtime, admin surfaces, tests, migrations, and phase context. [VERIFIED: codebase grep]
- https://hexdocs.pm/ecto/Ecto.Multi.html — transaction composition, `run/3`, and grouped repo operations. [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html]
- https://hexdocs.pm/ecto_sql/Ecto.Migration.html — partial unique index support via `:where`. [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html]
- https://hexdocs.pm/oban/Oban.Worker.html — existing worker/job contract shape. [CITED: https://hexdocs.pm/oban/Oban.Worker.html]
- https://hexdocs.pm/oban/unique_jobs.html — uniqueness semantics and why they are insufficient as the primary replay guard. [CITED: https://hexdocs.pm/oban/unique_jobs.html]
- https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html — LiveView event handling model for thin admin controls. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html]
- Hex package pages / versions for current releases:
  - https://hex.pm/packages/phoenix_live_view
  - https://hex.pm/packages/phoenix/versions
  - https://hex.pm/packages/oban/versions
  - https://hex.pm/packages/flop
  - https://hex.pm/packages/flop_phoenix/versions
  - https://hex.pm/packages/req [VERIFIED: hex.pm registry]

### Secondary (MEDIUM confidence)
- https://www.postgresql.org/docs/13/indexes-partial.html — partial-index rationale at the database layer; used only to reinforce the Ecto migration guidance. [CITED: https://www.postgresql.org/docs/13/indexes-partial.html]

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - the repo’s actual dependencies are known from `mix.exs`/`mix.lock`, and current package versions were verified against Hex. [VERIFIED: codebase grep] [VERIFIED: hex.pm registry]
- Architecture: HIGH - replay plugs directly into existing persisted delivery, worker, and admin seams already present in the codebase. [VERIFIED: codebase grep]
- Pitfalls: HIGH - each listed pitfall maps to locked Phase 104 decisions or to current webhook code behavior. [VERIFIED: codebase grep]

**Research date:** 2026-05-07
**Valid until:** 2026-06-06
