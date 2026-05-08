# Phase 101: Operator delivery-state truth - Research

**Researched:** 2026-05-06
**Domain:** Phoenix LiveView admin queries for webhook delivery-state truth
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-101-01 — Keep operational truth on `webhook_deliveries`; do not add a second subscription-owned health field.** The operator truth already lives on persisted delivery rows from Phases 97 and 98. Phase 101 should derive list behavior from that source rather than denormalizing `health_status` onto `webhook_subscriptions`. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- **D-101-02 — Apply delivery-state filtering in SQL before pagination.** The subscription index must filter against the derived latest-delivery state inside the query layer before `Flop` pagination runs. Post-pagination Ruby/Elixir filtering is forbidden for operator-truth filters. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- **D-101-03 — Separate configuration state from delivery state explicitly.** `enabled` remains subscription configuration truth from `webhook_subscriptions`. Operator-facing retry/dead-letter filtering represents delivery truth and should be labeled accordingly rather than overloading the word `status`. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- **D-101-04 — Rename the subscription-index filter concept to `Delivery state`.** The UI and query params should make it obvious that the retrying/dead-lettered control is about delivery behavior, not whether the endpoint is enabled or disabled. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- **D-101-05 — `retrying` means retryable in-flight delivery only.** In Phase 101, the retrying view must isolate only persisted retryable current states such as `retry_scheduled`. It must not include `dead_lettered`. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- **D-101-06 — `dead_lettered` means terminal exhausted delivery only.** Terminal dead-letter rows remain distinct from retrying rows across both the subscription index and the failures inbox. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- **D-101-07 — The subscription index headline is driven by the latest delivery row for that subscription.** The row-level operational badge/detail on the subscription list should describe the latest persisted delivery state for that endpoint, not a synthetic worst-ever aggregate over historical deliveries. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- **D-101-08 — Mixed delivery history belongs to failures/detail surfaces, not to a composite subscription headline.** If one subscription has both retrying and dead-lettered deliveries at the same time, the subscription index shows the latest-delivery headline only. The failures inbox and delivery/subscription detail pages remain the authoritative place for the full mixed-state backlog. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- **D-101-09 — Do not collapse mixed history into a sticky worst-state badge.** A historical dead-lettered delivery must not permanently force the subscription index row into `dead_lettered` after newer deliveries have succeeded or moved back into retrying. This would make the list misleading and noisy. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- **D-101-10 — Do not turn the subscription index into a multi-badge incident dashboard.** The list should stay scannable and idiomatic for Sigra’s LiveView admin surfaces. Richer mixed-state truth belongs on dedicated detail and failure pages. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- **D-101-11 — Use a hybrid count model because the two surfaces have different row grain.** The subscription index counts subscriptions. The failures inbox counts delivery rows. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- **D-101-12 — Subscription-index chips reflect latest current delivery state per subscription.** The `Retrying` and `Dead lettered` summary chips on the subscription page count subscriptions whose latest persisted delivery is in that state. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- **D-101-13 — Failures-inbox counts and rows reflect delivery backlog directly.** The failures page is delivery-centric, so its totals, pagination, and filtered results should count delivery rows, not subscriptions. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- **D-101-14 — If the failures surface needs cross-subscription context, expose it as secondary copy only.** Copy such as “20 deliveries across 1 subscription” is acceptable, but the primary count on the failures page remains delivery-row truth. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- **D-101-15 — Follow the existing Sigra admin-query pattern: filter first, decorate second.** The right pattern is the existing `Sigra.Admin.Users.Query` style: perform truthful query filtering first, paginate second, then attach presentation-oriented row decoration. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- **D-101-16 — Summary counts should come from the same semantic base as the page they summarize.** Counts must not be computed from a looser superset than the rows users are looking at. This is a least-surprise rule for all future operator views in this milestone. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- **D-101-17 — Shift routine product/architecture choices left within GSD.** Downstream research, planning, and execution should default to decisive recommendations that preserve operator trust, least surprise, and good DX. Escalate choices to the user only when they materially affect the security model, public/semver contract, or generated-host contract. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]

### Claude's Discretion

- Exact subquery / join strategy for selecting the latest delivery row per subscription. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- Exact query helper/module factoring for shared count logic. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- Exact badge copy and microcopy, as long as `enabled` and delivery state stay visibly distinct. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- Exact regression-test shape across library and example-host LiveView coverage. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]

### Deferred Ideas (OUT OF SCOPE)

- Broader top-level filters for other terminal classes such as HTTP 4xx permanent or local configuration failures. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- Dashboard-style aggregate health analytics. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- Replay/redrive controls from UI or CLI. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- Denormalized endpoint health fields for scale optimization without measured need. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- Generated-host proof expansion beyond the operator-truth fixes required for this phase. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WH-02 | Failed deliveries retry with a bounded policy and permanently failed deliveries stay inspectable in dead-letter state. [VERIFIED: .planning/REQUIREMENTS.md] | Keep failures inbox delivery-row based and make `retrying` = `retry_scheduled` only, `dead_lettered` = terminal only, so operator views match the persisted worker state model. [VERIFIED: .planning/ROADMAP.md; VERIFIED: lib/sigra/admin/webhooks/failures.ex] |
| WH-03 | Generated admin UX must let operators inspect truthful delivery history and failure state. [VERIFIED: .planning/REQUIREMENTS.md] | Move subscription delivery-state filtering into SQL before `Flop` pagination, separate config `enabled` from operational delivery state, and lock regressions in library plus example-host LiveView tests. [VERIFIED: .planning/ROADMAP.md; VERIFIED: lib/sigra/admin/webhooks/query.ex; VERIFIED: test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs] |
</phase_requirements>

## Summary

The current subscription index is not truthful because `Sigra.Admin.Webhooks.Query.list_subscriptions/3` paginates subscriptions first, then attaches latest deliveries in memory, then applies the `"status"` filter with `Enum.filter/2`; its `"retrying"` branch also includes `dead_lettered`. [VERIFIED: lib/sigra/admin/webhooks/query.ex]

The current failures inbox is closer to the right grain, but `Sigra.Admin.Webhooks.Failures.list_deliveries/3` starts from both attention states and leaves the `"retrying"` branch as a no-op, so `?status=retrying` still returns dead-lettered rows. [VERIFIED: lib/sigra/admin/webhooks/failures.ex]

The existing subscription summary chips are also computed outside the query contract with full-table loads in the LiveView, which means the planner should treat counts and row filtering as one query-semantics problem, not two separate UI problems. [VERIFIED: lib/sigra/admin/live/webhook_subscriptions_index_live.ex]

**Primary recommendation:** Build a SQL-level latest-delivery subquery per subscription, join it into the subscription index before `Flop.meta/4` and `Flop.query/3`, rename the operator filter to `delivery_state`, and move summary counts into query helpers that use the same semantic base as the rows. [VERIFIED: lib/sigra/admin/webhooks/query.ex; VERIFIED: lib/sigra/admin/users/query.ex; CITED: https://www.postgresql.org/docs/current/queries-select-lists.html; CITED: https://hexdocs.pm/ecto/3.13.5/aggregates-and-subqueries.html]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Latest delivery selection per subscription | API / Backend | Database / Storage | Truth comes from persisted `webhook_deliveries`, and the filter leak is in Ecto query code, not LiveView rendering. [VERIFIED: lib/sigra/admin/webhooks/query.ex] |
| Failures inbox status isolation | API / Backend | Database / Storage | The broken `"retrying"` behavior is a backend query predicate issue over delivery rows. [VERIFIED: lib/sigra/admin/webhooks/failures.ex] |
| Delivery-state labels and chips | Frontend Server (SSR) | API / Backend | LiveViews render labels and chips, but they must consume query-owned semantics instead of inventing them locally. [VERIFIED: lib/sigra/admin/live/webhook_subscriptions_index_live.ex; VERIFIED: lib/sigra/admin/live/webhook_delivery_failures_live.ex] |
| Mixed-state forensic detail | Frontend Server (SSR) | API / Backend | Existing detail pages already own richer history views, so Phase 101 should keep the index simple. [VERIFIED: lib/sigra/admin/live/webhook_subscription_show_live.ex; VERIFIED: lib/sigra/admin/live/webhook_delivery_show_live.ex] |

## Project Constraints (from CLAUDE.md)

- Sigra’s blessed path is Phoenix `1.8+`, Ecto `3.x`, and PostgreSQL-first behavior, so a Postgres-backed Ecto query solution is aligned with project direction. [VERIFIED: CLAUDE.md]
- Security-critical and behavioral truth should stay library-owned; generated hosts should remain thin wrappers and tests should be comprehensive, AAA-style, flat, and self-contained. [VERIFIED: CLAUDE.md]
- Local `mix test` requires a live Postgres on `localhost:5432` with `postgres` / `postgres`; tests are not silently skipped when the database is absent. [VERIFIED: CLAUDE.md]
- The user explicitly asked to write the research file directly, which satisfies the CLAUDE workflow bypass rule for direct repo edits. [VERIFIED: CLAUDE.md; VERIFIED: conversation context]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix | `1.8.5` | Admin LiveView routes and SSR rendering. [VERIFIED: mix.lock] | Existing admin surfaces already live here; Phase 101 is a query-truth fix, not a framework change. [VERIFIED: lib/sigra/admin/live/webhook_subscriptions_index_live.ex] |
| Phoenix LiveView | `1.1.28` | URL-driven admin list/detail UX. [VERIFIED: mix.lock] | Current webhook surfaces already use `handle_params/3` and deep-linkable filters. [VERIFIED: lib/sigra/admin/live/webhook_subscriptions_index_live.ex; VERIFIED: lib/sigra/admin/live/webhook_delivery_failures_live.ex] |
| Ecto / Ecto SQL | `3.13.5` | SQL query composition, subqueries, and pagination base queries. [VERIFIED: mix.lock] | Official Ecto docs support ordered subqueries and window/subquery composition, which is the right place to fix latest-row semantics. [CITED: https://hexdocs.pm/ecto/3.13.5/aggregates-and-subqueries.html; CITED: https://hexdocs.pm/ecto/3.13.5/Ecto.Query.html] |
| Flop | `0.26.3` | Pagination and meta over filtered queries. [VERIFIED: mix.lock] | Sigra’s existing `Users.Query` pattern already uses `Flop.meta` and `Flop.query` on a filtered base query. [VERIFIED: lib/sigra/admin/users/query.ex] |
| PostgreSQL | local `14.17`; project is Postgres-first. [VERIFIED: `psql --version`; VERIFIED: CLAUDE.md] | Deterministic latest-row selection via ordered `DISTINCT ON` semantics. [CITED: https://www.postgresql.org/docs/current/queries-select-lists.html] | The repo is already Postgres-only in practice for test/runtime expectations. [VERIFIED: CLAUDE.md] |

### Alternatives Rejected

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SQL latest-delivery join before pagination | Keep `attach_latest_deliveries/2` plus `Enum.filter/2` after `Flop.query/3` | Rejected because it leaks rows across pages and makes `Flop.meta` lie about filtered result sets. [VERIFIED: lib/sigra/admin/webhooks/query.ex] |
| Latest delivery headline per subscription | Sticky worst-ever aggregate state | Rejected because Context decision D-101-09 explicitly forbids permanent dead-letter scarring after newer deliveries change state. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md] |
| Delivery-row failures inbox | Subscription-level failure inbox | Rejected because the failures surface is already delivery-row based and the phase decisions require delivery-row counts there. [VERIFIED: lib/sigra/admin/webhooks/failures.ex; VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md] |
| Ordered `distinct` subquery | Window-function ranking subquery | Rejected for this phase because the repo already uses the ordered `distinct` pattern for latest deliveries, and Postgres `DISTINCT ON` is sufficient when ordering is deterministic. [VERIFIED: lib/sigra/admin/webhooks/query.ex; CITED: https://www.postgresql.org/docs/current/queries-select-lists.html] |

## Architecture Patterns

### System Architecture Diagram

```text
Browser filter params
  -> WebhookSubscriptionsIndexLive.handle_params/3
  -> Admin.Webhooks.Query.normalize_params/1
  -> subscriptions + latest_delivery subquery join
  -> delivery_state / enabled / q predicates
  -> Flop.meta + Flop.query
  -> row decoration
  -> HTML rows + subscription-grain chips

Browser filter params
  -> WebhookDeliveryFailuresLive.handle_params/3
  -> Admin.Webhooks.Failures.normalize_params/1
  -> delivery-row base query
  -> retrying/dead_lettered predicate
  -> Flop.meta + Flop.query
  -> attach subscription context
  -> HTML rows (+ optional delivery-row counts)
```

### Recommended Project Structure

```text
lib/sigra/admin/webhooks/
├── query.ex       # subscription-grain latest-delivery query + summary counts
└── failures.ex    # delivery-grain failures query + optional counts

lib/sigra/admin/live/
├── webhook_subscriptions_index_live.ex  # filter label/copy only; no semantic counting logic
└── webhook_delivery_failures_live.ex    # delivery-state filter UI only

test/
├── sigra/admin/webhooks_test.exs
└── example/test/example_web/live/*.exs
```

### Pattern 1: Filter Before Paginate, Decorate After

**What:** Build the latest-delivery relation in SQL, join it into the subscription query, apply `delivery_state` and `enabled` predicates there, then paginate, then map rows for presentation. [VERIFIED: lib/sigra/admin/users/query.ex; VERIFIED: lib/sigra/admin/webhooks/query.ex]

**When to use:** Any operator-facing subscription list that claims delivery-state truth. [VERIFIED: .planning/ROADMAP.md]

**Example:**

```elixir
# Source: lib/sigra/admin/webhooks/query.ex + Postgres DISTINCT ON docs
latest_delivery_query =
  from d in delivery_schema,
    order_by: [
      asc: d.webhook_subscription_id,
      desc: d.inserted_at,
      desc: d.id
    ],
    distinct: d.webhook_subscription_id

base_query =
  from s in subscription_schema,
    as: :subscription,
    left_join: ld in subquery(latest_delivery_query),
    on: ld.webhook_subscription_id == s.id

filtered_query =
  base_query
  |> maybe_filter_q(params["q"])
  |> maybe_filter_enabled(params["enabled"])
  |> maybe_filter_delivery_state(params["delivery_state"])
```

### Pattern 2: Keep Failures Delivery-Centric

**What:** Start from `webhook_deliveries`, keep the base scope to attention states, and narrow `"retrying"` to `retry_scheduled` instead of treating it as “all attention states.” [VERIFIED: lib/sigra/admin/webhooks/failures.ex]

**When to use:** The failures inbox and any future backlog/incident surface. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]

### Anti-Patterns to Avoid

- **Post-pagination filtering:** It makes the current page truthful only by accident and leaves `Flop.meta` inconsistent with visible rows. [VERIFIED: lib/sigra/admin/webhooks/query.ex]
- **Semantic duplication in LiveView counts:** The current `summary_counts/1` duplicates latest-delivery logic outside the query module and should be moved behind a query helper. [VERIFIED: lib/sigra/admin/live/webhook_subscriptions_index_live.ex]
- **Overloaded `status` copy:** The subscription page currently mixes enabled/disabled configuration with delivery-state filtering under the same word, which conflicts with D-101-03 and D-101-04. [VERIFIED: lib/sigra/admin/live/webhook_subscriptions_index_live.ex; VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Latest row per subscription | In-memory attach-and-filter pass | Ordered Ecto subquery joined before pagination | The current in-memory pass is the exact regression source. [VERIFIED: lib/sigra/admin/webhooks/query.ex] |
| Subscription health truth | New denormalized `health_status` column | Existing `webhook_deliveries` latest-row semantics | Context D-101-01 forbids a second truth model. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md] |
| Cross-surface counts | Ad hoc LiveView scans | Query helpers per row grain | Counts and rows must come from the same semantic base. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md; VERIFIED: lib/sigra/admin/live/webhook_subscriptions_index_live.ex] |

**Key insight:** Phase 101 is not a badge-copy bug; it is a query-contract bug, so the fix belongs in query modules first and LiveView copy second. [VERIFIED: lib/sigra/admin/webhooks/query.ex; VERIFIED: lib/sigra/admin/webhooks/failures.ex]

## Common Pitfalls

### Pitfall 1: Filtering the Wrong Grain

**What goes wrong:** The subscription page leaks or hides rows because it filters after one page of subscriptions has already been selected. [VERIFIED: lib/sigra/admin/webhooks/query.ex]

**Why it happens:** Latest delivery is attached only after `Flop.query/3`, so pagination never sees the delivery-state predicate. [VERIFIED: lib/sigra/admin/webhooks/query.ex]

**How to avoid:** Treat latest delivery as part of the SQL relation, not as a presentation decoration. [VERIFIED: lib/sigra/admin/users/query.ex; CITED: https://hexdocs.pm/ecto/3.13.5/aggregates-and-subqueries.html]

### Pitfall 2: Treating `retrying` as “attention”

**What goes wrong:** `?status=retrying` shows dead-lettered rows on both surfaces. [VERIFIED: lib/sigra/admin/webhooks/query.ex; VERIFIED: lib/sigra/admin/webhooks/failures.ex]

**Why it happens:** Both modules currently define retrying too loosely. [VERIFIED: lib/sigra/admin/webhooks/query.ex; VERIFIED: lib/sigra/admin/webhooks/failures.ex]

**How to avoid:** Hard-code `retrying -> retry_scheduled` and `dead_lettered -> dead_lettered` in query predicates and tests. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]

### Pitfall 3: Counts That Summarize a Different Universe

**What goes wrong:** Chips can stay numerically plausible while rows are wrong, which erodes operator trust. [VERIFIED: lib/sigra/admin/live/webhook_subscriptions_index_live.ex]

**Why it happens:** Counts are computed in separate code from the listing query. [VERIFIED: lib/sigra/admin/live/webhook_subscriptions_index_live.ex]

**How to avoid:** Put subscription summary counts in `Sigra.Admin.Webhooks.Query` and derive them from the same latest-delivery base query used for rows. [VERIFIED: lib/sigra/admin/users/query.ex]

## Code Examples

### Subscription Summary Counts From the Same Base

```elixir
# Source: lib/sigra/admin/users/query.ex pattern + Phase 101 decisions
def summary_counts(config, %Scope{} = admin_scope) do
  base = base_query(config, admin_scope)

  %{
    total: repo.aggregate(base, :count, :id),
    enabled: repo.aggregate(where(base, [subscription: s], s.enabled == true), :count, :id),
    disabled: repo.aggregate(where(base, [subscription: s], s.enabled == false), :count, :id),
    retrying:
      repo.aggregate(where(base, [..., latest_delivery: ld], ld.status == "retry_scheduled"), :count, :id),
    dead_lettered:
      repo.aggregate(where(base, [..., latest_delivery: ld], ld.status == "dead_lettered"), :count, :id)
  }
end
```

### Failures Inbox Truth Predicate

```elixir
# Source: lib/sigra/admin/webhooks/failures.ex
defp maybe_filter_status(query, nil), do: query
defp maybe_filter_status(query, "retrying"),
  do: where(query, [delivery: d], d.status == "retry_scheduled")
defp maybe_filter_status(query, "dead_lettered"),
  do: where(query, [delivery: d], d.status == "dead_lettered")
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Filter subscription delivery state in memory after pagination | Filter against SQL latest-delivery relation before pagination | Phase 101 recommendation for 2026-05-06. [VERIFIED: .planning/ROADMAP.md] | Restores truthful rows and truthful `Flop.meta`. [VERIFIED: lib/sigra/admin/webhooks/query.ex] |
| Use generic `Status` wording on subscription filter | Use `Delivery state` wording while keeping `enabled` as separate config state | Phase 101 decision D-101-04. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md] | Reduces operator confusion between config state and operational state. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md] |

## Contract Decision

- **Adopt `delivery_state` as the canonical query param and UI contract for Phase 101.**
- **Accept legacy `status` only as a temporary input alias at the query-normalization boundary.**
- **Never emit `status` back to callers, LiveViews, or tests once normalized.**

Rationale:
- This preserves operator-facing clarity required by D-101-03 and D-101-04.
- It avoids breaking existing deep links abruptly while still giving execution one unambiguous target.
- It keeps the compatibility concern localized to normalization code instead of spreading mixed semantics across query, LiveView, and test layers.

Execution implication:
- Query modules may accept `status` on input, but they must collapse it immediately into canonical `delivery_state`.
- LiveViews, hidden inputs, path builders, and regression tests should use only `delivery_state`.

**Deprecated/outdated:**

- The current `"retrying"` behavior in both webhook query modules is outdated for this milestone because it conflates retryable and terminal states. [VERIFIED: lib/sigra/admin/webhooks/query.ex; VERIFIED: lib/sigra/admin/webhooks/failures.ex]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Keeping a temporary `status` param alias while the UI moves to `delivery_state` is the least disruptive rollout. [ASSUMED] | Contract Decision | Low; Phase 101 would need a deliberate breaking-link migration instead of normalization-only compatibility handling. |
| A2 | `test/test_helper.exs` remains the effective test bootstrap, even though Phase 101 verification can run directly against target files. [ASSUMED] | Validation Architecture | Low; only affects documentation precision, not implementation shape. |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `mix` | Elixir test and compile commands | ✓ [VERIFIED: `command -v mix`] | OTP `28` runtime reported by `mix --version`. [VERIFIED: `mix --version`] | — |
| PostgreSQL CLI | Local DB verification | ✓ [VERIFIED: `command -v psql`] | `14.17`. [VERIFIED: `psql --version`] | — |
| Docker | Disposable local Postgres if needed | ✓ [VERIFIED: `command -v docker`] | `29.4.1`. [VERIFIED: `docker --version`] | Use any existing local Postgres on `localhost:5432`. [VERIFIED: CLAUDE.md] |

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with Phoenix LiveView tests. [VERIFIED: test file contents] |
| Config file | `test/test_helper.exs` is standard, but Phase 101 evidence can be driven directly from target test files. [VERIFIED: repo structure; ASSUMED] |
| Quick run command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs` [VERIFIED: CLAUDE.md; VERIFIED: test/sigra/admin/webhooks_test.exs] |
| Full phase command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs test/example/test/example_web/live/admin_webhook_failures_live_test.exs` [VERIFIED: test file paths] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WH-02 | Failures inbox `retrying` excludes dead-lettered rows and `dead_lettered` excludes retrying rows. [VERIFIED: .planning/ROADMAP.md] | integration | `mix test test/sigra/admin/webhooks_test.exs` | ✅ [VERIFIED: test/sigra/admin/webhooks_test.exs] |
| WH-03 | Subscription index filters on latest delivery state before pagination and keeps counts/chips aligned with subscription grain. [VERIFIED: .planning/ROADMAP.md] | integration + LiveView | `mix test test/sigra/admin/webhooks_test.exs test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs` | ✅ [VERIFIED: test paths] |
| WH-03 | Example host failures page shows only truthful delivery rows for the selected delivery state. [VERIFIED: .planning/ROADMAP.md] | LiveView | `mix test test/example/test/example_web/live/admin_webhook_failures_live_test.exs` | ✅ [VERIFIED: test path] |

### Wave 0 Gaps

- Add a library-level regression proving page-size `1` cannot hide a later matching subscription when `delivery_state=retrying`; the current tests do not cover the pagination leak directly. [VERIFIED: existing tests in test/sigra/admin/webhooks_test.exs]
- Update example-host failures LiveView assertions so `status=retrying` excludes dead-lettered rows; the current test expects the buggy behavior. [VERIFIED: test/example/test/example_web/live/admin_webhook_failures_live_test.exs]
- Update library failures-query assertions so `status=retrying` expects only `retry_scheduled`; the current test expects both rows. [VERIFIED: test/sigra/admin/webhooks_test.exs]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Phase 101 does not change login or identity proofing. [VERIFIED: scope docs] |
| V3 Session Management | no | Phase 101 does not change session state. [VERIFIED: scope docs] |
| V4 Access Control | yes | Continue using existing admin scope authorization before query execution. [VERIFIED: lib/sigra/admin/webhooks/query.ex; VERIFIED: lib/sigra/admin/webhooks/failures.ex] |
| V5 Input Validation | yes | Keep `normalize_params/1` + `Flop.validate/2` on query params. [VERIFIED: lib/sigra/admin/webhooks/query.ex; VERIFIED: lib/sigra/admin/webhooks/failures.ex] |
| V6 Cryptography | no | No signature or secret-handling behavior changes are in scope. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Misleading operator state causing incorrect incident response | Repudiation | Derive UI state from persisted delivery rows only, with tested SQL predicates. [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md; VERIFIED: lib/sigra/admin/webhooks/query.ex] |
| Admin filter parameter abuse | Tampering | Authorize scope first and validate params through Flop before query execution. [VERIFIED: lib/sigra/admin/webhooks/query.ex; VERIFIED: lib/sigra/admin/webhooks/failures.ex] |

## Sources

### Primary (HIGH confidence)

- `lib/sigra/admin/webhooks/query.ex` - current subscription filter defect and post-pagination filtering. [VERIFIED: codebase grep]
- `lib/sigra/admin/webhooks/failures.ex` - current failures inbox filter defect. [VERIFIED: codebase grep]
- `lib/sigra/admin/live/webhook_subscriptions_index_live.ex` - current summary-chip logic and overloaded status copy. [VERIFIED: codebase grep]
- `lib/sigra/admin/users/query.ex` - existing Sigra filter-first, paginate-second pattern. [VERIFIED: codebase grep]
- `test/sigra/admin/webhooks_test.exs` - current library-level assertions, including tests that encode the buggy behavior. [VERIFIED: codebase grep]
- `test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs` and `test/example/test/example_web/live/admin_webhook_failures_live_test.exs` - current example-host regression surfaces. [VERIFIED: codebase grep]
- `mix.lock` and `mix.exs` - repo-locked framework versions. [VERIFIED: codebase grep]
- `CLAUDE.md` - project constraints and local test prerequisites. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)

- https://www.postgresql.org/docs/current/queries-select-lists.html - `DISTINCT ON` keeps the first ordered row per group, which matches the recommended latest-delivery subquery approach. [CITED: PostgreSQL docs]
- https://hexdocs.pm/ecto/3.13.5/aggregates-and-subqueries.html - Ecto subqueries are the documented way to preserve order/distinct semantics before outer query operations. [CITED: Ecto docs]
- https://hexdocs.pm/ecto/3.13.5/Ecto.Query.html - Ecto supports subqueries and ordered query composition for the recommended query shape. [CITED: Ecto docs]

### Tertiary (LOW confidence)

- None. [VERIFIED: source review]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - Versions and framework usage were verified from `mix.lock`, `mix.exs`, and the codebase. [VERIFIED: mix.lock; VERIFIED: mix.exs]
- Architecture: HIGH - The defect and the correct local pattern are both directly visible in Sigra query modules and context decisions. [VERIFIED: lib/sigra/admin/webhooks/query.ex; VERIFIED: lib/sigra/admin/webhooks/failures.ex; VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md]
- Pitfalls: HIGH - The exact leak conditions are called out in the milestone audit and reproduced by current code/tests. [VERIFIED: .planning/v1.22-MILESTONE-AUDIT.md; VERIFIED: test/sigra/admin/webhooks_test.exs; VERIFIED: test/example/test/example_web/live/admin_webhook_failures_live_test.exs]

**Research date:** 2026-05-06
**Valid until:** 2026-06-05
