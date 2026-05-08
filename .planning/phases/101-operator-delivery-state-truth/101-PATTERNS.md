# Phase 101: Operator delivery-state truth - Pattern Map

**Mapped:** 2026-05-06
**Files analyzed:** 7 target files
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/admin/webhooks/query.ex` | query/service | request-response | `lib/sigra/admin/users/query.ex` | role-match |
| `lib/sigra/admin/webhooks/failures.ex` | query/service | request-response | `lib/sigra/admin/users/query.ex` | role-match |
| `lib/sigra/admin/live/webhook_subscriptions_index_live.ex` | LiveView/component | request-response | `lib/sigra/admin/live/users_index_live.ex` | role-match |
| `lib/sigra/admin/live/webhook_delivery_failures_live.ex` | LiveView/component | request-response | `lib/sigra/admin/live/webhook_delivery_show_live.ex` | partial |
| `test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs` | test | request-response | `test/example/test/example_web/live/admin_user_index_live_test.exs` | role-match |
| `test/example/test/example_web/live/admin_webhook_failures_live_test.exs` | test | request-response | `test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs` | partial |
| `test/example/test/support/webhook_admin_live_fixtures.ex` | test utility | CRUD | `test/example/test/support/webhook_admin_live_fixtures.ex` | exact |

## Pattern Assignments

### `lib/sigra/admin/webhooks/query.ex` (query/service, request-response)

**Primary analog:** [lib/sigra/admin/users/query.ex](/Users/jon/projects/sigra/lib/sigra/admin/users/query.ex:126)

**Imports and query-module shape** from [lib/sigra/admin/users/query.ex](/Users/jon/projects/sigra/lib/sigra/admin/users/query.ex:126)
```elixir
@spec list_users(map(), Scope.t(), map() | keyword() | nil) ::
        {:ok, {[row()], Flop.Meta.t(), map()}} | {:error, Flop.Meta.t()}
def list_users(config, %Scope{} = admin_scope, params \\ %{}) do
  hooks = Hooks.resolve(config)

  with {:ok, normalized} <- normalize_params(params),
       {:ok, %Flop{} = flop} <- Flop.validate(to_flop_params(normalized), for: Params) do
    helpers = helpers(config, hooks, admin_scope)
    base_query = base_query(config, admin_scope, helpers)
    filtered_query = apply_filters(base_query, flop.filters || [], helpers)
    pagination_flop = %Flop{flop | filters: []}

    meta = Flop.meta(filtered_query, pagination_flop, for: Params, repo: config.repo)
```

**Copy this architecture, not the current webhook implementation.** Today [lib/sigra/admin/webhooks/query.ex](/Users/jon/projects/sigra/lib/sigra/admin/webhooks/query.ex:69) paginates first and then post-filters rows:
```elixir
query =
  from(subscription in subscription_schema, as: :subscription)
  |> apply_filters(normalized)

rows =
  query
  |> Flop.query(pagination_flop, for: Params)
  |> config.repo.all()
  |> attach_latest_deliveries(config)
  |> maybe_filter_status(Map.get(normalized, "status"))
  |> Enum.map(&row_from_result/1)
```

**Current reusable asset:** latest-delivery selection already exists in [lib/sigra/admin/webhooks/query.ex](/Users/jon/projects/sigra/lib/sigra/admin/webhooks/query.ex:127)
```elixir
latest_by_subscription =
  from(delivery in delivery_schema,
    where: delivery.webhook_subscription_id in ^subscription_ids,
    order_by: [
      asc: delivery.webhook_subscription_id,
      desc: delivery.inserted_at,
      desc: delivery.id
    ],
    distinct: delivery.webhook_subscription_id
  )
```

**Use as the source for a SQL-side subquery/join.** Phase 101 should preserve this “latest row per subscription” truth, but move it before `Flop.query/3`.

**Counts pattern to copy** from [lib/sigra/admin/users/query.ex](/Users/jon/projects/sigra/lib/sigra/admin/users/query.ex:152)
```elixir
@spec summary_counts(map(), Scope.t()) :: map()
def summary_counts(config, %Scope{} = admin_scope) do
  ...
  %{
    total: repo.aggregate(base, :count, :id),
    confirmed:
      repo.aggregate(where(base, [user: user], not is_nil(user.confirmed_at)), :count, :id),
```

**Planner guidance:** move webhook subscription summary counts into this query module style so row truth and chip truth share the same filtered/latest-delivery base.

### `lib/sigra/admin/webhooks/failures.ex` (query/service, request-response)

**Primary analog:** [lib/sigra/admin/users/query.ex](/Users/jon/projects/sigra/lib/sigra/admin/users/query.ex:131)

**Keep:** normalize params, authorize, build one base query, compute `Flop.meta/4`, then attach display-only data after pagination. Current shape already matches that pattern at [lib/sigra/admin/webhooks/failures.ex](/Users/jon/projects/sigra/lib/sigra/admin/webhooks/failures.ex:61).

**Defect to correct in-place:** `retrying` currently means “no extra filter” at [lib/sigra/admin/webhooks/failures.ex](/Users/jon/projects/sigra/lib/sigra/admin/webhooks/failures.ex:92)
```elixir
defp maybe_filter_status(query, nil), do: query
defp maybe_filter_status(query, "retrying"), do: query

defp maybe_filter_status(query, status) do
  where(query, [delivery: delivery], delivery.status == ^status)
end
```

**Keep as reusable base:** the attention backlog scope at [lib/sigra/admin/webhooks/failures.ex](/Users/jon/projects/sigra/lib/sigra/admin/webhooks/failures.ex:68)
```elixir
query =
  from(delivery in delivery_schema, as: :delivery)
  |> where([delivery: delivery], delivery.status in ^@attention_statuses)
  |> apply_filters(normalized)
```

**Decorator pattern to preserve:** subscription lookup happens after row selection at [lib/sigra/admin/webhooks/failures.ex](/Users/jon/projects/sigra/lib/sigra/admin/webhooks/failures.ex:112)
```elixir
Enum.map(deliveries, fn delivery ->
  %{delivery: delivery, subscription: Map.get(subscriptions_by_id, delivery.webhook_subscription_id)}
end)
```

**Planner guidance:** implement strict `retry_scheduled` filtering in-query, but keep the delivery-row grain and post-query subscription decoration.

### `lib/sigra/admin/live/webhook_subscriptions_index_live.ex` (LiveView/component, request-response)

**Primary analog:** [lib/sigra/admin/live/users_index_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/users_index_live.ex:35)

**Handle-params pattern to copy:** query module owns rows and counts; LiveView just assigns results.
From [lib/sigra/admin/live/users_index_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/users_index_live.ex:35)
```elixir
with {:ok, {rows, meta, normalized}} <- Query.list_users(config, admin_scope, params) do
  {:noreply,
   socket
   |> assign(:rows, rows)
   |> assign(:meta, meta)
   |> assign(:summary_counts, Query.summary_counts(config, admin_scope))
   |> assign(:current_params, normalized)}
```

**Current anti-pattern to remove:** [lib/sigra/admin/live/webhook_subscriptions_index_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_subscriptions_index_live.ex:52) calls the list query, but counts are recomputed in the LiveView by loading all subscriptions and all latest deliveries at [lib/sigra/admin/live/webhook_subscriptions_index_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_subscriptions_index_live.ex:484).

**Filter UI pattern to preserve:** URL-driven form state with hidden pagination/sort params at [lib/sigra/admin/live/webhook_subscriptions_index_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_subscriptions_index_live.ex:193)
```heex
<form method="get" action={subscriptions_index_path()} ...>
  ...
  <input type="hidden" name="page_size" value={Map.get(@current_params, "page_size", "25")} />
  <input type="hidden" name="order_by" value={Map.get(@current_params, "order_by", "inserted_at")} />
  <input type="hidden" name="order_direction" value={Map.get(@current_params, "order_direction", "desc")} />
</form>
```

**Current label conflict:** the select mixes config and delivery states in one `Status` control at [lib/sigra/admin/live/webhook_subscriptions_index_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_subscriptions_index_live.ex:12)
```elixir
@status_options [
  {"Any", ""},
  {"Enabled", "enabled"},
  {"Disabled", "disabled"},
  {"Retrying", "retrying"},
  {"Dead lettered", "dead_lettered"}
]
```

**Keep row rendering semantics:** config badge and latest-delivery badge are already visually separate at [lib/sigra/admin/live/webhook_subscriptions_index_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_subscriptions_index_live.ex:347)
```heex
<span class={status_badge_class(row.subscription.enabled)}>{enabled_label(row.subscription.enabled)}</span>
<span :if={row.latest_delivery} class={delivery_badge_class(row.latest_delivery.status)}>
  {delivery_status_label(row.latest_delivery.status)}
</span>
```

**Planner guidance:** rename the filter concept in this file to `Delivery state`, keep `enabled` as independent row/config truth, and move summary count logic into `Sigra.Admin.Webhooks.Query`.

### `lib/sigra/admin/live/webhook_delivery_failures_live.ex` (LiveView/component, request-response)

**Primary analog:** [lib/sigra/admin/live/webhook_delivery_show_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_delivery_show_live.ex:24) for status copy and `return_to`; current file itself already matches the standard `handle_params` flow.

**Keep:** `Failures.list_deliveries/3` as the source of truth, with normalized params assigned back to the view at [lib/sigra/admin/live/webhook_delivery_failures_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_delivery_failures_live.ex:24).

**Keep status language:** from [lib/sigra/admin/live/webhook_delivery_failures_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_delivery_failures_live.ex:118)
```elixir
defp human_status("retry_scheduled"), do: "Retrying"
defp human_status("dead_lettered"), do: "Dead lettered"
```

**Shared drill-down integration point:** failures rows should continue linking to the delivery detail page with `return_to`, matching [lib/sigra/admin/live/webhook_delivery_failures_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_delivery_failures_live.ex:113) and [lib/sigra/admin/live/webhook_delivery_show_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_delivery_show_live.ex:24).

**Planner guidance:** if the failures page gains counts or secondary copy, keep delivery-row truth primary and use the delivery detail surface for forensic depth.

### `test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs` (test, request-response)

**Primary analog:** [test/example/test/example_web/live/admin_user_index_live_test.exs](/Users/jon/projects/sigra/test/example/test/example_web/live/admin_user_index_live_test.exs:10)

**Keep test style:** `ConnCase` + `Phoenix.LiveViewTest` + fixture imports from [test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs](/Users/jon/projects/sigra/test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs:1)
```elixir
use ExampleWeb.ConnCase, async: false

import Phoenix.LiveViewTest
import ExampleWeb.ConnCaseHelpers
import Example.WebhookAdminLiveFixtures
```

**URL-state regression pattern to copy:** the user index verifies return URLs and preserved params at [test/example/test/example_web/live/admin_user_index_live_test.exs](/Users/jon/projects/sigra/test/example/test/example_web/live/admin_user_index_live_test.exs:27). Use the same idea for webhook delivery-state filters if links or pagination behavior change.

**Current webhook fixture shape:** [test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs](/Users/jon/projects/sigra/test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs:19)
```elixir
healthy = webhook_subscription_fixture(...)
retrying = webhook_subscription_fixture(...)

_healthy_delivery = webhook_delivery_fixture(healthy, %{status: "delivered", ...})
_retrying_delivery = webhook_delivery_fixture(retrying, %{status: "retry_scheduled", ...})
```

**Gap this test should close in Phase 101:** it currently proves a basic retrying filter at [test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs](/Users/jon/projects/sigra/test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs:49), but it does not prove:
- pre-pagination SQL filtering
- latest-delivery-wins semantics
- `retrying` excluding `dead_lettered`
- summary chips using the same latest-delivery truth as rows

### `test/example/test/example_web/live/admin_webhook_failures_live_test.exs` (test, request-response)

**Primary analog:** same file for the page shell, plus [test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs](/Users/jon/projects/sigra/test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs:40) for delivery-specific fixture setup.

**Current fixture pattern:** [test/example/test/example_web/live/admin_webhook_failures_live_test.exs](/Users/jon/projects/sigra/test/example/test/example_web/live/admin_webhook_failures_live_test.exs:13)
```elixir
_delivered = webhook_delivery_fixture(subscription, %{status: "delivered", ...})
_retrying = webhook_delivery_fixture(subscription, %{status: "retry_scheduled", ...})
_dead_letter = webhook_delivery_fixture(subscription, %{status: "dead_lettered", ...})
```

**Current bug evidence is already encoded here:** `status=retrying` still expects both retrying and dead-letter rows at [test/example/test/example_web/live/admin_webhook_failures_live_test.exs](/Users/jon/projects/sigra/test/example/test/example_web/live/admin_webhook_failures_live_test.exs:37)
```elixir
|> live("/admin/webhooks/failures?status=retrying")

assert html =~ "delivery-retrying"
assert html =~ "delivery-dead-letter"
```

**Planner guidance:** replace this expectation with strict status partitioning and add a companion assertion for `status=dead_lettered`.

### `test/example/test/support/webhook_admin_live_fixtures.ex` (test utility, CRUD)

**Primary reusable asset:** [test/example/test/support/webhook_admin_live_fixtures.ex](/Users/jon/projects/sigra/test/example/test/support/webhook_admin_live_fixtures.ex:35)

**Subscription fixture pattern**
```elixir
def webhook_subscription_fixture(attrs \\ %{}) do
  defaults = %{
    endpoint_url: "https://example.com/webhooks/#{System.unique_integer([:positive])}",
    description: "Webhook subscription #{System.unique_integer([:positive])}",
    enabled: true,
    signing_secret: String.duplicate("s", 32),
    event_types: ["user.created"]
  }
```

**Delivery fixture pattern with deterministic ordering support** from [test/example/test/support/webhook_admin_live_fixtures.ex](/Users/jon/projects/sigra/test/example/test/support/webhook_admin_live_fixtures.ex:52)
```elixir
inserted_at = Map.get(attrs, :inserted_at, ~U[2026-05-06 09:00:00Z])
...
|> Repo.insert!()
|> then(fn delivery ->
  from(d in WebhookDelivery, where: d.id == ^delivery.id)
  |> Repo.update_all(set: [inserted_at: inserted_at, updated_at: inserted_at])
```

**Planner guidance:** use explicit `inserted_at` overrides to build latest-delivery ordering regressions and page-boundary leaks.

## Shared Patterns

### Filter First, Decorate Second
**Source:** [lib/sigra/admin/users/query.ex](/Users/jon/projects/sigra/lib/sigra/admin/users/query.ex:131)
**Apply to:** `lib/sigra/admin/webhooks/query.ex`, `lib/sigra/admin/webhooks/failures.ex`
```elixir
filtered_query = apply_filters(base_query, flop.filters || [], helpers)
pagination_flop = %Flop{flop | filters: []}

meta = Flop.meta(filtered_query, pagination_flop, for: Params, repo: config.repo)

rows =
  filtered_query
  |> Flop.query(pagination_flop, for: Params)
  |> ...
  |> decorate_rows(...)
```

### LiveView Owns Rendering, Query Module Owns Counts
**Source:** [lib/sigra/admin/live/users_index_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/users_index_live.ex:39), [lib/sigra/admin/users/query.ex](/Users/jon/projects/sigra/lib/sigra/admin/users/query.ex:152)
**Apply to:** `lib/sigra/admin/live/webhook_subscriptions_index_live.ex`

### Latest Delivery Is the Row Headline
**Source:** [lib/sigra/admin/webhooks/query.ex](/Users/jon/projects/sigra/lib/sigra/admin/webhooks/query.ex:127), [lib/sigra/admin/live/webhook_subscriptions_index_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_subscriptions_index_live.ex:359)
**Apply to:** subscription index row semantics, subscription summary counts
```elixir
order_by: [
  asc: delivery.webhook_subscription_id,
  desc: delivery.inserted_at,
  desc: delivery.id
],
distinct: delivery.webhook_subscription_id
```

### Mixed-State History Belongs on Detail Pages
**Source:** [lib/sigra/admin/live/webhook_subscription_show_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_subscription_show_live.ex:175), [lib/sigra/admin/live/webhook_delivery_show_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_delivery_show_live.ex:46)
**Apply to:** planner should keep the index/failures surfaces scannable and use detail pages for full backlog/attempt truth.

### Regression Fixtures Must Control `inserted_at`
**Source:** [test/example/test/support/webhook_admin_live_fixtures.ex](/Users/jon/projects/sigra/test/example/test/support/webhook_admin_live_fixtures.ex:64)
**Apply to:** all new Phase 101 tests covering latest-delivery ordering and pre-pagination leaks.

## No Analog Found

| File/Concern | Role | Data Flow | Reason |
|---|---|---|---|
| Shared helper for “latest delivery per subscription” as a composable subquery reused by list and summary counts | utility/query helper | request-response | Current code only has ad hoc in-memory `attach_latest_deliveries/2` and a LiveView-local `summary_counts/1`; no existing reusable helper module. |
| Existing regression test that proves `retrying` excludes `dead_lettered` on either surface | test | request-response | Current failures test asserts the opposite, and the subscription test does not encode the distinction. |
| Existing regression test that proves delivery-state filtering happens before pagination | test | request-response | No current webhook test uses enough rows plus `page_size`/ordering to catch this leak. |
| Existing failures-page count/chip pattern at delivery-row grain | LiveView/query | request-response | Current failures LiveView has no summary counts yet, so planner must derive any new count work from users query patterns plus webhook delivery semantics. |

## Metadata

**Analog search scope:** `lib/sigra/admin/**/*`, `test/example/test/example_web/live/**/*`, `test/example/test/support/**/*`

**Nearby analogs read:**
- [lib/sigra/admin/live/users_index_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/users_index_live.ex:1)
- [lib/sigra/admin/live/webhook_subscription_show_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_subscription_show_live.ex:1)
- [lib/sigra/admin/live/webhook_delivery_show_live.ex](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_delivery_show_live.ex:1)
- [test/example/test/example_web/live/admin_user_index_live_test.exs](/Users/jon/projects/sigra/test/example/test/example_web/live/admin_user_index_live_test.exs:1)
- [test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs](/Users/jon/projects/sigra/test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs:1)
- [test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs](/Users/jon/projects/sigra/test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs:1)

**Key patterns identified:**
- Admin list queries should filter in SQL, then paginate, then decorate rows.
- LiveViews should assign normalized params and query-owned counts, not recompute truth in the LiveView.
- Webhook operator truth is already modeled on persisted delivery rows; detail pages own mixed-history depth.
