# Phase 98: Reliable delivery pipeline - Pattern Map

**Mapped:** 2026-05-06
**Files analyzed:** 11
**Analogs found:** 11 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/webhooks.ex` | service | event-driven | `lib/sigra/webhooks.ex` | exact |
| `lib/sigra/webhooks/dispatcher.ex` | service | event-driven | `lib/sigra/webhooks/dispatcher.ex` | exact |
| `lib/sigra/workers/webhook_delivery.ex` | worker | event-driven | `lib/sigra/workers/webhook_delivery.ex` | exact |
| `lib/sigra/config.ex` | config | request-response | `lib/sigra/config.ex` | exact |
| `lib/sigra/optional_deps.ex` | config | request-response | `lib/sigra/optional_deps.ex` | exact |
| `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs` | migration | CRUD | `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs` | exact |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery.ex` | model | CRUD | `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery.ex` | exact |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery_attempt.ex` | model | append-only | `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_event.ex` | role-match |
| `test/sigra/webhooks_integration_test.exs` | test | event-driven | `test/sigra/webhooks_integration_test.exs` | exact |
| `test/sigra/workers/webhook_delivery_test.exs` | test | event-driven | `test/sigra/workers/webhook_delivery_test.exs` | exact |
| `test/sigra/webhooks_reliable_delivery_atomicity_test.exs` | test | event-driven | `test/sigra/webhooks_audit_atomicity_test.exs` | role-match |

## Pattern Assignments

### `lib/sigra/webhooks.ex` (service, event-driven)

**Analog:** `lib/sigra/webhooks.ex`

**Composable outer-transaction seam** ([`lib/sigra/webhooks.ex`](/Users/jon/projects/sigra/lib/sigra/webhooks.ex:143)):
```elixir
@spec dispatch_multi(Sigra.Config.t(), String.t(), term(), keyword()) :: Multi.t()
def dispatch_multi(%Sigra.Config{} = config, event_type, object_ref, opts \\ [])
    when is_binary(event_type) and is_list(opts) do
  Dispatcher.dispatch_multi(config, event_type, object_ref, opts)
end

@spec append_dispatch_multi(Multi.t(), Sigra.Config.t(), String.t(), term(), keyword()) ::
        Multi.t()
def append_dispatch_multi(
      %Multi{} = multi,
      %Sigra.Config{} = config,
      event_type,
      object_ref,
      opts \\ []
    )
    when is_binary(event_type) and is_list(opts) do
  Multi.append(multi, dispatch_multi(config, event_type, object_ref, opts))
end
```

**Queue seam stays library-owned and delivery-id only** ([`lib/sigra/webhooks.ex`](/Users/jon/projects/sigra/lib/sigra/webhooks.ex:169)):
```elixir
def build_delivery_job(%Sigra.Config{} = config, delivery_or_id, opts \\ [])
    when is_list(opts) do
  ensure_enabled!(config)
  delivery_id = extract_delivery_id!(delivery_or_id)
  queue = Keyword.get(opts, :queue, queue_name(config))

  worker_opts =
    opts
    |> Keyword.drop([:oban, :queue])
    |> Keyword.put(:queue, queue)
    |> Keyword.put(:config, config)

  Sigra.Workers.WebhookDelivery.new(%{"delivery_id" => delivery_id}, worker_opts)
end
```

**Planner guidance:** extend this module for retry enqueue helpers and attempt-summary helpers rather than introducing a parallel delivery API.

---

### `lib/sigra/webhooks/dispatcher.ex` (service, event-driven)

**Analog:** `lib/sigra/webhooks/dispatcher.ex`

**Pure `Ecto.Multi` composition with explicit step names** ([`lib/sigra/webhooks/dispatcher.ex`](/Users/jon/projects/sigra/lib/sigra/webhooks/dispatcher.ex:29)):
```elixir
if Webhooks.enabled?(config) do
  {subscriptions_step, event_step, deliveries_step} = step_names(event_type, opts)

  Multi.new()
  |> Multi.run(subscriptions_step, fn _repo, _changes ->
    {:ok, matching_subscriptions(config, event_type)}
  end)
  |> Multi.run(event_step, fn repo, changes ->
    insert_event(repo, config, event_type, object_ref, changes, opts)
  end)
  |> Multi.run(deliveries_step, fn repo, changes ->
    subscriptions = Map.fetch!(changes, subscriptions_step)
    event = Map.fetch!(changes, event_step)
    insert_deliveries(repo, config, subscriptions, event)
  end)
else
  Multi.new()
end
```

**Parent row then child rows in one transaction owner** ([`lib/sigra/webhooks/dispatcher.ex`](/Users/jon/projects/sigra/lib/sigra/webhooks/dispatcher.ex:76)):
```elixir
attrs = %{
  event_id: event_id,
  type: event_type,
  schema_version: payload["schema_version"],
  occurred_at: normalize_datetime(occurred_at),
  payload: payload,
  actor_id: get_in(context, [:actor, :id]),
  actor_type: get_in(context, [:actor, :type]),
  organization_id: get_in(context, [:organization, :id]),
  request_id: get_in(context, [:request, :id])
}

repo.insert(event_schema.changeset(struct(event_schema), attrs))
```

**Child insert loop pattern for delivery lineage rows** ([`lib/sigra/webhooks/dispatcher.ex`](/Users/jon/projects/sigra/lib/sigra/webhooks/dispatcher.ex:108)):
```elixir
Enum.reduce_while(subscriptions, {:ok, []}, fn subscription, {:ok, deliveries} ->
  attrs = %{
    delivery_id: Ecto.UUID.generate(),
    status: "pending",
    endpoint_url: Map.fetch!(subscription, :endpoint_url),
    webhook_subscription_id: Map.fetch!(subscription, :id),
    webhook_event_id: Map.fetch!(event, :id)
  }

  case repo.insert(delivery_schema.changeset(struct(delivery_schema), attrs)) do
    {:ok, delivery} -> {:cont, {:ok, [delivery | deliveries]}}
    {:error, reason} -> {:halt, {:error, reason}}
  end
end)
```

**Planner guidance:** Phase 98’s parent-summary update plus attempt-row insert should reuse this exact “one Multi owner, no hidden repo calls” shape. If attempt persistence is moved into the worker, keep it as one repo transaction that updates the parent delivery row and inserts the child attempt row together.

---

### `lib/sigra/workers/webhook_delivery.ex` (worker, event-driven)

**Analog:** `lib/sigra/workers/webhook_delivery.ex`

**Worker contract is single-shot, Oban is execution only** ([`lib/sigra/workers/webhook_delivery.ex`](/Users/jon/projects/sigra/lib/sigra/workers/webhook_delivery.ex:12)):
```elixir
use Oban.Worker,
  queue: :sigra_webhooks,
  max_attempts: 1
```

**Perform path resolves persisted state at execution time** ([`lib/sigra/workers/webhook_delivery.ex`](/Users/jon/projects/sigra/lib/sigra/workers/webhook_delivery.ex:34)):
```elixir
def perform(%Oban.Job{args: %{"delivery_id" => delivery_id}}) when is_binary(delivery_id) do
  config = resolve_config()

  cond do
    not Webhooks.enabled?(config) ->
      {:cancel, :webhooks_disabled}

    true ->
      case fetch_delivery_bundle(config, delivery_id) do
        {:ok, bundle} -> dispatch_delivery(config, bundle)
        {:cancel, _reason} = cancel -> cancel
      end
  end
end
```

**Fresh-signature-per-attempt wire send** ([`lib/sigra/workers/webhook_delivery.ex`](/Users/jon/projects/sigra/lib/sigra/workers/webhook_delivery.ex:74)):
```elixir
signed_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)
timestamp = DateTime.to_unix(signed_at)

headers =
  Signature.headers(Map.fetch!(delivery, :delivery_id), raw_body, secret,
    timestamp: timestamp
  )
  |> Map.put("Content-Type", "application/json")
  |> Enum.to_list()
```

**Current outcome buckets are terse and library-owned** ([`lib/sigra/workers/webhook_delivery.ex`](/Users/jon/projects/sigra/lib/sigra/workers/webhook_delivery.ex:99)):
```elixir
case requester.(request) do
  {:ok, %{status: status}} when is_integer(status) and status >= 200 and status < 300 ->
    {:ok, status}
  {:ok, %{status: status}} when is_integer(status) ->
    {:error, {:http_error, status}}
  {:error, _reason} ->
    {:error, :transport_error}
  _other ->
    {:error, :transport_error}
end
```

**Invariant-cancel fetch path** ([`lib/sigra/workers/webhook_delivery.ex`](/Users/jon/projects/sigra/lib/sigra/workers/webhook_delivery.ex:144)):
```elixir
with delivery when not is_nil(delivery) <-
       repo.get_by(delivery_schema, delivery_id: delivery_id),
     subscription when not is_nil(subscription) <-
       repo.get(subscription_schema, Map.fetch!(delivery, :webhook_subscription_id)),
     true <- Map.get(subscription, :enabled, false),
     event when not is_nil(event) <-
       repo.get(event_schema, Map.fetch!(delivery, :webhook_event_id)) do
  {:ok, %{delivery: delivery, subscription: subscription, event: event}}
else
  nil -> {:cancel, :delivery_dependency_missing}
  false -> {:cancel, :subscription_disabled}
end
```

**Planner guidance:** keep `perform/1` single-send. Add retry scheduling and attempt persistence around this seam, not via `max_attempts`. Phase 98 terminal local invariants should become durable delivery states instead of disappearing as `{:cancel, ...}` only.

---

### `lib/sigra/config.ex` (config, request-response)

**Analog:** `lib/sigra/config.ex`

**Webhook config is a fixed, documented NimbleOptions surface** ([`lib/sigra/config.ex`](/Users/jon/projects/sigra/lib/sigra/config.ex:723)):
```elixir
webhooks: [
  type: :keyword_list,
  default: [],
  doc: "Outbound webhook options.",
  keys: [
    enabled: [type: :boolean, default: false, ...],
    webhook_subscription_schema: [type: {:or, [:atom, nil]}, default: nil, ...],
    webhook_event_schema: [type: {:or, [:atom, nil]}, default: nil, ...],
    webhook_delivery_schema: [type: {:or, [:atom, nil]}, default: nil, ...],
    oban_queue: [type: :string, default: "sigra_webhooks", ...],
    oban_concurrency: [type: :pos_integer, default: 10, ...],
    signature_tolerance: [type: :pos_integer, default: 300, ...]
  ]
]
```

**Planner guidance:** if Phase 98 adds any config at all, keep it narrow, nested under `:webhooks`, and validated here. The phase context explicitly says retry policy is fixed in v1.22, so prefer no new host knobs unless a field is required for schema-module wiring.

---

### `lib/sigra/optional_deps.ex` (config, request-response)

**Analog:** `lib/sigra/optional_deps.ex`

**Feature registry entry for enforced optional dependency** ([`lib/sigra/optional_deps.ex`](/Users/jon/projects/sigra/lib/sigra/optional_deps.ex:208)):
```elixir
webhook_delivery: %{
  feature: :webhook_delivery,
  dependency: :oban,
  dependency_spec: "~> 2.17",
  dependency_modules: [Oban],
  support_tier: :phase_95,
  enforced?: true,
  doctor?: true,
  compile_warning?: :when_enabled,
  remediation: InstallCore.optional_dependency_remediation(:webhook_delivery),
  enabled?: fn context -> webhook_delivery_enabled?(context) end,
  evidence: fn context -> webhook_delivery_evidence(context) end
}
```

**Enablement and doctor evidence stay declarative** ([`lib/sigra/optional_deps.ex`](/Users/jon/projects/sigra/lib/sigra/optional_deps.ex:383)):
```elixir
defp webhook_delivery_enabled?(context) do
  webhooks_config =
    case Map.get(context, :webhooks) do
      webhooks when is_list(webhooks) -> webhooks
      _other -> config_value(context, :webhooks, [])
    end

  Keyword.get(webhooks_config, :enabled, false)
end
```

**Planner guidance:** reuse this registry instead of ad hoc `Code.ensure_loaded?` checks scattered through retry helpers. If Phase 98 introduces a new worker/helper seam, it should still key off `:webhook_delivery`, not a new dependency feature.

---

### `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs` (migration, CRUD)

**Analog:** `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs`

**Existing generated-host webhook table style** ([`test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs`](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs:18)):
```elixir
create table(:webhook_events, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :event_id, :string, null: false
  add :type, :string, null: false
  add :schema_version, :string, null: false
  add :occurred_at, :utc_datetime_usec, null: false
  add :payload, :map, null: false, default: %{}
  ...
  timestamps(type: :utc_datetime_usec, updated_at: false)
end
```

**Current delivery-table foreign key and index shape** ([`test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs`](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs:36)):
```elixir
create table(:webhook_deliveries, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :delivery_id, :string, null: false
  add :status, :string, null: false, default: "pending"
  add :endpoint_url, :string, null: false
  add :dispatched_at, :utc_datetime_usec
  add :webhook_subscription_id,
      references(:webhook_subscriptions, type: :binary_id, on_delete: :delete_all),
      null: false
  add :webhook_event_id,
      references(:webhook_events, type: :binary_id, on_delete: :delete_all),
      null: false
  timestamps(type: :utc_datetime_usec)
end
```

**Planner guidance:** add `webhook_delivery_attempts` in this migration style: `:binary_id` PK/FKs, `utc_datetime_usec`, explicit indexes, and `on_delete: :delete_all` from parent delivery to attempt ledger. Extend `webhook_deliveries` with denormalized status/attempt summary fields rather than introducing a second parent table.

---

### `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery.ex` (model, CRUD)

**Analog:** `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery.ex`

**Generated host schema + changeset conventions** ([`test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery.ex`](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery.ex:15)):
```elixir
schema "webhook_deliveries" do
  field :delivery_id, :string
  field :status, :string, default: "pending"
  field :endpoint_url, :string
  field :dispatched_at, :utc_datetime_usec

  belongs_to :webhook_subscription, SigraInstallGoldenTmp.Accounts.WebhookSubscription
  belongs_to :webhook_event, SigraInstallGoldenTmp.Accounts.WebhookEvent

  timestamps(type: :utc_datetime_usec)
end
```

**Required-field and FK constraint pattern** ([`test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery.ex`](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery.ex:27)):
```elixir
delivery
|> cast(attrs, [
  :delivery_id,
  :status,
  :endpoint_url,
  :dispatched_at,
  :webhook_subscription_id,
  :webhook_event_id
])
|> validate_required([
  :delivery_id,
  :status,
  :endpoint_url,
  :webhook_subscription_id,
  :webhook_event_id
])
|> assoc_constraint(:webhook_subscription)
|> assoc_constraint(:webhook_event)
|> unique_constraint(:delivery_id)
```

**Planner guidance:** extend this schema with summary columns and `has_many :webhook_delivery_attempts`. Keep the changeset explicit; do not rely on `cast_assoc` for the attempt ledger in worker code.

---

### `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery_attempt.ex` (model, append-only)

**Analog:** `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_event.ex`

**Append-only timestamp style to copy** ([`test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_event.ex`](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_event.ex:15)):
```elixir
schema "webhook_events" do
  field :event_id, :string
  field :type, :string
  field :schema_version, :string
  field :occurred_at, :utc_datetime_usec
  field :payload, :map, default: %{}
  ...
  timestamps(type: :utc_datetime_usec, updated_at: false)
end
```

**Planner guidance:** model attempts like an append-only ledger, closer to `webhook_events` than to mutable delivery rows:
- use `timestamps(type: :utc_datetime_usec, updated_at: false)`
- make each row immutable history for one wire send
- include `belongs_to :webhook_delivery`
- keep bounded fields for classification, HTTP status, retryability, endpoint snapshot, and short error detail

**Secondary analog:** [`test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery.ex`](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery.ex:21)) for FK declarations and `assoc_constraint/1`.

---

### `test/sigra/webhooks_integration_test.exs` (test, event-driven)

**Analog:** `test/sigra/webhooks_integration_test.exs`

**Persisted async-state integration harness** ([`test/sigra/webhooks_integration_test.exs`](/Users/jon/projects/sigra/test/sigra/webhooks_integration_test.exs:136)):
```elixir
setup do
  start_supervised!({PostgresRepo, PostgresRepo.default_config()})
  repo = PostgresRepo

  Application.put_env(:sigra, :repo, repo)
  Application.put_env(:sigra, :user_schema, IntegrationUser)
  Application.put_env(:sigra, :secret_key_base, String.duplicate("a", 64))
  Application.put_env(:sigra, :webhooks, webhooks_config())
  ...
  Ecto.Adapters.SQL.query!(repo, ~s|CREATE EXTENSION IF NOT EXISTS "uuid-ossp"|, [])
  ...
end
```

**Schema-in-test pattern for end-to-end persisted rows** ([`test/sigra/webhooks_integration_test.exs`](/Users/jon/projects/sigra/test/sigra/webhooks_integration_test.exs:56)):
```elixir
defmodule WebhookEvent do
  use Ecto.Schema
  import Ecto.Changeset
  ...
end

defmodule WebhookDeliveryRow do
  use Ecto.Schema
  import Ecto.Changeset
  ...
end
```

**Queue + perform + persisted row assertions** ([`test/sigra/webhooks_integration_test.exs`](/Users/jon/projects/sigra/test/sigra/webhooks_integration_test.exs:372)):
```elixir
job_changeset = Webhooks.build_delivery_job(config, delivery)

assert Changeset.get_change(job_changeset, :args) == %{"delivery_id" => delivery.delivery_id}
assert Changeset.get_change(job_changeset, :queue) == "sigra_webhooks"
refute inspect(Changeset.get_change(job_changeset, :args)) =~ secret

Application.put_env(:sigra, :webhook_delivery_requester, fn request ->
  send(self(), {:webhook_request, request})
  {:ok, %{status: 202}}
end)

assert {:ok, :delivered} =
         WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => delivery.delivery_id}})
```

**Planner guidance:** extend this file or mirror its structure for “persisted async state” proofs: initial pending row, worker execution, attempt ledger row inserted, parent summary updated, next attempt scheduled or terminal state set.

---

### `test/sigra/workers/webhook_delivery_test.exs` (test, event-driven)

**Analog:** `test/sigra/workers/webhook_delivery_test.exs`

**Lightweight mock-repo worker harness** ([`test/sigra/workers/webhook_delivery_test.exs`](/Users/jon/projects/sigra/test/sigra/workers/webhook_delivery_test.exs:82)):
```elixir
defmodule MockRepo do
  def get_by(Delivery, delivery_id: delivery_id) do
    Process.get({:delivery, delivery_id})
  end

  def get(Subscription, id) do
    Process.get({:subscription, id})
  end

  def get(Event, id) do
    Process.get({:event, id})
  end

  def update(%Changeset{} = changeset) do
    delivery = Changeset.apply_changes(changeset)
    Process.put({:updated_delivery, delivery.delivery_id}, delivery)
    {:ok, delivery}
  end
end
```

**Dependency hard-fail and queue assertions** ([`test/sigra/workers/webhook_delivery_test.exs`](/Users/jon/projects/sigra/test/sigra/workers/webhook_delivery_test.exs:132)):
```elixir
assert_raise MissingDependencyError, fn ->
  WebhookDelivery.new(%{"delivery_id" => "del_1"},
    webhooks: [enabled: true],
    dependency_loaded?: fn _spec -> false end
  )
end

assert {:ok, %{args: %{"delivery_id" => "del_1"}, queue: "sigra_webhooks"}} =
         Webhooks.enqueue_delivery(config(), delivery, oban: MockOban)
```

**Behavioral outcome buckets** ([`test/sigra/workers/webhook_delivery_test.exs`](/Users/jon/projects/sigra/test/sigra/workers/webhook_delivery_test.exs:197)):
```elixir
assert {:cancel, :subscription_disabled} =
         WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => "del_1"}})

assert {:error, {:http_error, 500}} =
         WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => "del_1"}})

assert {:error, :transport_error} =
         WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => "del_1"}})
```

**Planner guidance:** keep this file as the fast unit seam for classification logic: retryable vs terminal HTTP buckets, invariant failures, and the exact next action returned after one attempt.

---

### `test/sigra/webhooks_reliable_delivery_atomicity_test.exs` (test, event-driven)

**Primary analog:** `test/sigra/webhooks_audit_atomicity_test.exs`

**Rollback proof for outer transaction co-fate** ([`test/sigra/webhooks_audit_atomicity_test.exs`](/Users/jon/projects/sigra/test/sigra/webhooks_audit_atomicity_test.exs:225)):
```elixir
assert {:error, %Ecto.Changeset{} = changeset} =
         Auth.register(
           config(repo),
           %{"email" => "webhook-roll@example.com", "hashed_password" => "hash"},
           register_opts()
         )

assert %{endpoint_url: ["can't be blank"]} = errors_on(changeset)
assert 0 == repo.aggregate(WebhookUser, :count)
assert 0 == repo.aggregate(WebhookEvent, :count)
assert 0 == repo.aggregate(WebhookDelivery, :count)
```

**Secondary analog:** `test/sigra/jwt_refresh_audit_cofate_test.exs`

**Fault-injection pattern with `CHECK` + telemetry + rollback assertions** ([`test/sigra/jwt_refresh_audit_cofate_test.exs`](/Users/jon/projects/sigra/test/sigra/jwt_refresh_audit_cofate_test.exs:220)):
```elixir
ALTER TABLE audit_events
ADD CONSTRAINT jwt_refresh_cofate_happy_guard CHECK (action <> 'api.jwt_refresh')

assert {:error, :jwt_refresh_aborted} = JWT.refresh(cfg, raw_refresh, opts)
assert_receive {:telemetry, [:sigra, :audit, :log_safe_error], %{count: 1},
                %{action: "api.jwt_refresh", reason: :constraint_violation}}

assert count(repo, "jwt_refresh_cofate_user_tokens") == before_tokens
assert count_where(repo, "audit_events", "action = 'api.jwt_refresh'") == 0
```

**Tertiary analog:** `test/sigra/service_accounts_audit_atomicity_test.exs`

**“No partial row” post-rollback assertion style** ([`test/sigra/service_accounts_audit_atomicity_test.exs`](/Users/jon/projects/sigra/test/sigra/service_accounts_audit_atomicity_test.exs:281)):
```elixir
assert {:error, :service_account_aborted} =
         Sigra.ServiceAccounts.create(sigra_config(repo), scope, %{...})

assert count_rows(repo, "sa_atomicity_service_accounts") == before_count
assert count_rows(repo, "audit_events") == 0
```

**Planner guidance:** use this test class for the new parent-summary plus attempt-row transaction. Inject a DB failure on the attempt insert or summary update and assert neither side commits.

## Shared Patterns

### Transactional Co-Fate

**Sources:**
- [`lib/sigra/auth.ex`](/Users/jon/projects/sigra/lib/sigra/auth.ex:236)
- [`lib/sigra/webhooks/dispatcher.ex`](/Users/jon/projects/sigra/lib/sigra/webhooks/dispatcher.ex:41)
- [`test/sigra/webhooks_audit_atomicity_test.exs`](/Users/jon/projects/sigra/test/sigra/webhooks_audit_atomicity_test.exs:225)

**Copy this pattern:**
```elixir
Ecto.Multi.new()
|> Ecto.Multi.insert(:user, changeset_fn.(attrs))
|> Webhooks.append_dispatch_multi(config, "user.created", {:changes_key, :user}, ...)
|> repo.transact()
```

**Apply to:** worker-side attempt persistence. The delivery parent update and the append-only attempt insert should happen in the same repo transaction owned by one orchestrator function.

### Oban Seam

**Sources:**
- [`lib/sigra/workers/webhook_delivery.ex`](/Users/jon/projects/sigra/lib/sigra/workers/webhook_delivery.ex:12)
- [`lib/sigra/webhooks.ex`](/Users/jon/projects/sigra/lib/sigra/webhooks.ex:175)

**Copy this pattern:**
```elixir
use Oban.Worker, queue: :sigra_webhooks, max_attempts: 1
Sigra.Workers.WebhookDelivery.new(%{"delivery_id" => delivery_id}, worker_opts)
```

**Apply to:** keep Oban as single-execution transport. Phase 98 retry sequencing should enqueue future work explicitly instead of increasing worker `max_attempts`.

### Append-Only Ledger Shape

**Sources:**
- [`test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_event.ex`](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_event.ex:15)
- [`lib/sigra/audit.ex`](/Users/jon/projects/sigra/lib/sigra/audit.ex:269)

**Copy this pattern:**
```elixir
schema "..." do
  ...
  timestamps(type: :utc_datetime_usec, updated_at: false)
end

Ecto.Multi.insert(multi, step, fn changes ->
  attrs = build_attrs(...)
  Changeset.changeset(struct(schema), attrs, opts)
end)
```

**Apply to:** `webhook_delivery_attempts` should be immutable history rows with `updated_at: false`, inserted one-per-attempt.

### Config And Optional Dependency Enforcement

**Sources:**
- [`lib/sigra/config.ex`](/Users/jon/projects/sigra/lib/sigra/config.ex:723)
- [`lib/sigra/optional_deps.ex`](/Users/jon/projects/sigra/lib/sigra/optional_deps.ex:208)

**Copy this pattern:**
```elixir
webhooks: [type: :keyword_list, default: [], keys: [...]]

OptionalDeps.ensure_available!(:webhook_delivery, webhook_delivery_context(opts))
```

**Apply to:** any new helper that schedules retries or depends on Oban-backed execution should reuse existing `:webhook_delivery` enforcement and existing `:webhooks` config nesting.

### Telemetry Only After Commit

**Source:** [`lib/sigra/audit.ex`](/Users/jon/projects/sigra/lib/sigra/audit.ex:275)

**Copy this pattern:**
```elixir
{:ok, changes} = repo.transaction(multi)
Sigra.Audit.emit_telemetry_from_changes(changes, [:audit_step])
```

**Apply to:** if Phase 98 emits telemetry for delivery attempts or dead-letter transitions, do it from the success branch after DB commit.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/sigra/webhooks/retry_policy.ex` | utility | event-driven | No standalone retry-policy module exists yet; keep logic near `Sigra.Workers.WebhookDelivery` or `Sigra.Webhooks` unless planning explicitly introduces one. |

## Metadata

**Analog search scope:** `lib/sigra`, `test/sigra`, `test/fixtures/install_golden/tree`
**Files scanned:** 18
**Pattern extraction date:** 2026-05-06

## PATTERN MAPPING COMPLETE

Phase 98 pattern mapping is ready for the planner.
