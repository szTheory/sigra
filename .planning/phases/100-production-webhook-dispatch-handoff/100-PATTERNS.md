# Phase 100: Production Webhook Dispatch Handoff - Pattern Map

**Mapped:** 2026-05-06
**Files analyzed:** 12
**Analogs found:** 11 / 12

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/webhooks.ex` | service | event-driven + request-response | `lib/sigra/webhooks.ex` | exact |
| `lib/sigra/webhooks/dispatcher.ex` | service | event-driven + CRUD | `lib/sigra/webhooks/dispatcher.ex` | exact |
| `lib/sigra/workers/webhook_delivery.ex` | worker | event-driven | `lib/sigra/workers/webhook_delivery.ex` | exact |
| `lib/sigra/auth.ex` | service | request-response + event-driven | `lib/sigra/auth.ex` `register_user_multi/2` | exact |
| `lib/sigra/organizations.ex` | service | CRUD + event-driven | `lib/sigra/organizations.ex` `add_member_multi/5` | exact |
| `lib/sigra/service_accounts.ex` | service | CRUD + event-driven | `lib/sigra/service_accounts.ex` `create/3` / `revoke/3` | exact |
| `lib/sigra/optional_deps.ex` | config/utility | request-response | `lib/sigra/optional_deps.ex` | exact |
| `test/sigra/webhooks_dispatcher_test.exs` | test | event-driven | `test/sigra/webhooks_dispatcher_test.exs` | exact |
| `test/sigra/webhooks_audit_atomicity_test.exs` | test | atomicity | `test/sigra/webhooks_audit_atomicity_test.exs` | exact |
| `test/sigra/webhooks_integration_test.exs` | test | integration + event-driven | `test/sigra/webhooks_integration_test.exs` | exact |
| `test/sigra/webhooks_reliable_delivery_atomicity_test.exs` | test | atomicity | `test/sigra/webhooks_reliable_delivery_atomicity_test.exs` | exact |
| `lib/sigra/webhooks/handoff.ex` or equivalent new helper | utility/service | post-commit handoff | no close analog | none |

## Pattern Assignments

### `lib/sigra/webhooks/dispatcher.ex` (service, event-driven + CRUD)

**Analog:** [lib/sigra/webhooks/dispatcher.ex](/Users/jon/projects/sigra/lib/sigra/webhooks/dispatcher.ex:29)

**Core pure-`Ecto.Multi` builder pattern** (lines 33-55):
```elixir
@spec dispatch_multi(Sigra.Config.t(), String.t(), changes_ref(), keyword()) :: Multi.t()
def dispatch_multi(%Sigra.Config{} = config, event_type, object_ref, opts \\ [])
    when is_binary(event_type) and is_list(opts) do
  validate_event_type!(event_type)

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
end
```

**Parent row then child rows under one transaction owner** (lines 76-137):
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

```elixir
Enum.reduce_while(subscriptions, {:ok, []}, fn subscription, {:ok, deliveries} ->
  attrs = %{
    delivery_id: Ecto.UUID.generate(),
    status: "pending",
    attempt_count: 0,
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

**Planner guidance**
- Copy this shape for any new “append work into outer transaction” helper.
- Do not call `Repo.transaction/1` or `Repo.transact/1` inside the builder.
- Keep step names explicit and namespaced so composed multis stay debuggable.

---

### `lib/sigra/webhooks.ex` (service, request-response + event-driven)

**Analog:** [lib/sigra/webhooks.ex](/Users/jon/projects/sigra/lib/sigra/webhooks.ex:192)

**Append-to-outer-transaction seam** (lines 196-216):
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

**Worker enqueue helper with minimal job args** (lines 224-253):
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

def enqueue_delivery(%Sigra.Config{} = config, delivery_or_id, opts \\ []) when is_list(opts) do
  changeset = build_delivery_job(config, delivery_or_id, opts)
  oban = Keyword.get(opts, :oban, Oban)

  case oban.insert(changeset) do
    {:ok, job} -> {:ok, job}
    {:error, reason} -> {:error, reason}
  end
end
```

**Optional-dependency gate for async-only webhook jobs** (lines 425-430):
```elixir
defp ensure_enabled!(%Sigra.Config{} = config) do
  if enabled?(config) do
    OptionalDeps.ensure_available!(:webhook_delivery, config: config)
  else
    raise ArgumentError, "webhook delivery jobs require config.webhooks[:enabled] == true"
  end
end
```

**Atomic summary + attempt persistence pattern** (lines 291-314):
```elixir
Multi.new()
|> Multi.insert(:attempt, attempt_schema.changeset(struct(attempt_schema), attempt_attrs))
|> Multi.update(:delivery, delivery.__struct__.changeset(delivery, delivery_attrs))
|> repo.transaction()
|> case do
  {:ok, %{attempt: attempt, delivery: updated_delivery}} ->
    {:ok, %{attempt: attempt, delivery: updated_delivery, next_attempt: Map.get(attrs, :next_attempt)}}

  {:error, _step, reason, _changes} ->
    {:error, reason}
end
```

**Planner guidance**
- Reuse `build_delivery_job/3` and `enqueue_delivery/3` as the public handoff boundary.
- If Phase 100 adds a new post-commit helper, that helper should collect `delivery_id`s or job changesets and call this seam only after the outer transaction commits.
- Keep job payloads to `delivery_id` only.

---

### `lib/sigra/auth.ex`, `lib/sigra/organizations.ex`, `lib/sigra/service_accounts.ex` (service callers)

**Analogs:** [lib/sigra/auth.ex](/Users/jon/projects/sigra/lib/sigra/auth.ex:235), [lib/sigra/organizations.ex](/Users/jon/projects/sigra/lib/sigra/organizations.ex:966), [lib/sigra/service_accounts.ex](/Users/jon/projects/sigra/lib/sigra/service_accounts.ex:21)

**`Auth.register_user_multi/2` appends webhook work without taking ownership of the transaction** (lines 240-259 and 262-275):
```elixir
multi =
  Ecto.Multi.new()
  |> Ecto.Multi.insert(:user, changeset_fn.(attrs))
  |> maybe_append_user_created_webhook(opts)
```

```elixir
Webhooks.append_dispatch_multi(
  multi,
  config,
  "user.created",
  {:changes_key, :user},
  step_id: :auth_register_user_created,
  context: fn %{user: user} ->
    Webhooks.context(nil,
      actor: %{type: "user", id: user.id},
      request_id: Keyword.get(opts, :request_id)
    )
  end
)
```

**`Organizations.add_member_multi/5` composes multiple domain steps and webhook append in one multi** (lines 968-994):
```elixir
Multi.new()
|> Multi.run(:add_member_resolve_user, fn _repo, changes ->
  user =
    case user_ref do
      {:changes_key, key} -> Map.fetch!(changes, key)
      %_{} = u -> u
    end

  {:ok, user}
end)
|> Multi.insert(:membership, fn %{add_member_resolve_user: user} ->
  build_membership_changeset(membership_schema, org, user, role)
end)
|> append_webhook(
  config,
  "organization_membership.created",
  {:changes_key, :membership},
  scope,
  step_id: :organization_member_add,
  changes: ["role"]
)
```

**`ServiceAccounts.create/3` and shared append wrapper show the stable caller pattern** (lines 29-40 and 374-381):
```elixir
Multi.new()
|> Multi.insert(:service_account, changeset)
|> append_webhook(config, "service_account.created", {:changes_key, :service_account}, scope,
  step_id: :service_account_create
)
|> append_audit(config, "service_account.create", scope, ...)
|> config.repo.transaction()
```

```elixir
defp append_webhook(multi, config, event_type, object_ref, scope, extra) do
  Webhooks.append_dispatch_multi(
    multi,
    config,
    event_type,
    object_ref,
    Keyword.merge([context: Webhooks.context(scope)], extra)
  )
end
```

**Planner guidance**
- Follow these callers when retrofitting Phase 100 into auth/domain transactions.
- Add webhook handoff by appending to the caller-owned multi, not by having `Dispatcher` transact on its own.
- If a new post-commit queue step is needed, model it as a follow-on seam at the transaction boundary, not inside these builders.

---

### `lib/sigra/workers/webhook_delivery.ex` (worker, event-driven)

**Analog:** [lib/sigra/workers/webhook_delivery.ex](/Users/jon/projects/sigra/lib/sigra/workers/webhook_delivery.ex:1)

**Single-shot worker configuration + dependency enforcement** (lines 12-31):
```elixir
use Oban.Worker,
  queue: :sigra_webhooks,
  max_attempts: 1

@impl Oban.Worker
def new(args, opts) when is_map(args) and is_list(opts) do
  OptionalDeps.ensure_available!(:webhook_delivery, webhook_delivery_context(opts))

  Job.new(
    args,
    Worker.merge_opts(
      __opts__(),
      Keyword.drop(opts, [:config, :webhooks, :dependency_loaded?])
    )
  )
end
```

**Perform path reloads durable state, then persists outcome before any retry enqueue** (lines 34-46, 156-169, 206-239, 260-268):
```elixir
def perform(%Oban.Job{args: %{"delivery_id" => delivery_id}}) when is_binary(delivery_id) do
  config = resolve_config()

  cond do
    not Webhooks.enabled?(config) ->
      {:cancel, :webhooks_disabled}

    true ->
      case load_delivery_context(config, delivery_id) do
        {:ok, bundle} -> dispatch_delivery(config, bundle)
        {:delivery_only, delivery, reason} -> persist_terminal_failure(config, delivery, reason)
        {:orphan, orphan_delivery_id} -> persist_orphan_failure(config, orphan_delivery_id)
      end
  end
end
```

```elixir
case Webhooks.persist_delivery_outcome(config, delivery, attrs) do
  {:ok, %{delivery: updated_delivery, next_attempt: next_retry}} ->
    case maybe_enqueue_retry(config, updated_delivery, next_retry) do
      :ok -> {:ok, retry_result(classification.retryable)}
      {:error, reason} -> {:error, reason}
    end

  {:error, _reason} ->
    {:error, :delivery_update_failed}
end
```

```elixir
defp maybe_enqueue_retry(_config, _delivery, nil), do: :ok

defp maybe_enqueue_retry(config, delivery, _next_retry) do
  oban = Application.get_env(:sigra, :webhook_delivery_oban, Oban)

  case Webhooks.enqueue_delivery(config, delivery, oban: oban) do
    {:ok, _job} -> :ok
    {:error, reason} -> {:error, reason}
  end
end
```

**Planner guidance**
- This is the best existing durable handoff analog in the repo: persist delivery state first, then enqueue the next job from committed state.
- Keep `max_attempts: 1`; retries are library-owned state transitions, not Oban implicit retries.
- If Phase 100 introduces initial post-commit enqueue, mirror this ordering: commit durable rows first, enqueue second.

---

### `lib/sigra/optional_deps.ex` and `lib/sigra/delivery.ex` (config/contrast)

**Analogs:** [lib/sigra/optional_deps.ex](/Users/jon/projects/sigra/lib/sigra/optional_deps.ex:58), [lib/sigra/delivery.ex](/Users/jon/projects/sigra/lib/sigra/delivery.ex:39)

**Canonical optional-dependency enforcement** (lines 58-75):
```elixir
def ensure_available!(feature, context \\ []) do
  spec = feature_spec!(feature)
  context = normalize_context(context)
  enabled? = spec.enabled?.(context.data)
  loaded? = dependency_loaded?(spec, context)

  if spec.enforced? and enabled? and not loaded? do
    raise MissingDependencyError,
      feature: spec.feature,
      dependency: spec.dependency,
      spec: spec.dependency_spec,
      evidence: spec.evidence.(context.data),
      remediation: spec.remediation
  end

  :ok
end
```

**Webhook delivery feature spec** (lines 208-220):
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

**Useful contrast only: do not copy email sync fallback into webhook handoff** (`lib/sigra/delivery.ex` lines 45-80):
```elixir
def deliver_async(email_type, args, opts \\ []) do
  OptionalDeps.ensure_available!(:async_email, async_email_context(opts))
  changeset = build_job(email_type, args, opts)
  oban = Keyword.get(opts, :oban, Oban)

  case oban.insert(changeset) do
    {:ok, job} -> {:ok, job}
    {:error, reason} -> {:error, reason}
  end
end

def build_job(email_type, args, opts \\ []) do
  OptionalDeps.ensure_available!(:async_email, async_email_context(opts))
  queue = Keyword.get(opts, :oban_queue, "sigra_mailer")
  ...
  Sigra.Workers.EmailDelivery.new(job_args, queue: queue)
end
```

**Planner guidance**
- Copy the dependency-enforcement pattern exactly.
- Copy the `build_job` / `insert_job` split as a handoff API shape.
- Do not copy `Sigra.Delivery`’s sync fallback semantics into webhook dispatch.

---

### Tests for handoff, atomicity, and non-fragile verification

#### `test/sigra/webhooks_dispatcher_test.exs`

**Analog:** [test/sigra/webhooks_dispatcher_test.exs](/Users/jon/projects/sigra/test/sigra/webhooks_dispatcher_test.exs:233)

**Composable outer-transaction proof** (lines 233-252):
```elixir
multi =
  Multi.new()
  |> Multi.insert(:user, UserRecord.changeset(%UserRecord{}, %{id: "user-1", email: "user@example.com"}))
  |> Webhooks.append_dispatch_multi(
    config(),
    "user.created",
    {:changes_key, :user},
    step_id: :register,
    context: %{actor: %{type: "user", id: "user-1"}}
  )

assert {:ok, changes} = MockRepo.transaction(multi)
assert changes.user.id == "user-1"
assert length(changes[{:webhook_deliveries, :register}]) == 1
```

**Use for Phase 100**
- Good unit test for “append, don’t transact”.
- Acceptable to assert step keys here because the test is explicitly about the builder contract.

#### `test/sigra/webhooks_audit_atomicity_test.exs`

**Analog:** [test/sigra/webhooks_audit_atomicity_test.exs](/Users/jon/projects/sigra/test/sigra/webhooks_audit_atomicity_test.exs:198)

**Business row + webhook row co-fate proof** (lines 198-245):
```elixir
assert {:ok, user} =
         Auth.register(
           config(repo),
           %{"email" => "webhook-ok@example.com", "hashed_password" => "hash"},
           register_opts()
         )

assert 1 == repo.aggregate(WebhookUser, :count)
assert 1 == repo.aggregate(WebhookEvent, :count)
assert 1 == repo.aggregate(WebhookDelivery, :count)
```

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

**Use for Phase 100**
- Strong model for proving “no nested transaction owner” regressions indirectly.
- Prefer row counts and persisted state over implementation details.

#### `test/sigra/webhooks_integration_test.exs`

**Analog:** [test/sigra/webhooks_integration_test.exs](/Users/jon/projects/sigra/test/sigra/webhooks_integration_test.exs:488)

**Minimal job args + delivery execution proof** (lines 510-546):
```elixir
job_changeset = Webhooks.build_delivery_job(config, delivery)

assert Changeset.get_change(job_changeset, :args) == %{"delivery_id" => delivery.delivery_id}
assert Changeset.get_change(job_changeset, :queue) == "sigra_webhooks"
refute inspect(Changeset.get_change(job_changeset, :args)) =~ secret
```

```elixir
assert {:ok, :delivered} =
         WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => delivery.delivery_id}})

assert headers["Sigra-Webhook-Id"] == delivery.delivery_id
assert Jason.decode!(request.body) == event.payload
assert updated_delivery.status == "delivered"
assert %DateTime{} = updated_delivery.dispatched_at
```

**Retry and dead-letter proof via persisted state, not worker internals** (lines 655-678 and 707-722):
```elixir
assert {:ok, :retry_scheduled} =
         WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => delivery.delivery_id}})

assert persisted.status == "retry_scheduled"
assert persisted.attempt_count == 1
assert [attempt] = persisted.attempts
assert [%{args: %{"delivery_id" => same_delivery_id}, queue: "sigra_webhooks"}] =
         Process.get(:queued_jobs)
```

```elixir
assert {:ok, :dead_lettered} =
         WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => delivery.delivery_id}})

assert persisted.status == "dead_lettered"
assert persisted.attempt_count == 1
assert %DateTime{} = persisted.dead_lettered_at
assert persisted.terminal_reason == "http_4xx_permanent"
```

**Use for Phase 100**
- Best integration precedent for proving handoff behavior.
- Prefer assertions on job args, persisted delivery state, and observable request payloads.

#### `test/sigra/webhooks_reliable_delivery_atomicity_test.exs`

**Analog:** [test/sigra/webhooks_reliable_delivery_atomicity_test.exs](/Users/jon/projects/sigra/test/sigra/webhooks_reliable_delivery_atomicity_test.exs:157)

**Attempt row and summary row atomicity proof** (lines 157-228):
```elixir
assert {:error, %Ecto.Changeset{}} =
         Webhooks.persist_delivery_outcome(config(repo), delivery, %{attempt_number: 1, ...})

fetched_delivery = repo.get_by!(Delivery, delivery_id: delivery.delivery_id)
assert fetched_delivery.status == "pending"
assert fetched_delivery.attempt_count == 0
assert 1 == repo.aggregate(DeliveryAttempt, :count)
```

```elixir
assert {:error, %Ecto.Changeset{}} =
         Webhooks.persist_delivery_outcome(config(repo), delivery, %{attempt_number: 1, ...})

assert 0 == repo.aggregate(DeliveryAttempt, :count)
assert fetched_delivery.status == "pending"
assert fetched_delivery.attempt_count == 0
```

**Use for Phase 100**
- Copy this shape for any new handoff-state persistence helper.
- It proves atomicity without asserting internal `Multi` step names.

#### `test/sigra/workers/webhook_delivery_test.exs`

**Analog:** [test/sigra/workers/webhook_delivery_test.exs](/Users/jon/projects/sigra/test/sigra/workers/webhook_delivery_test.exs:233)

**Optional-dep enforcement + queue helper proof** (lines 233-247):
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

**Worker outcome tests that stay at behavior level** (lines 250-353):
- Delivered path asserts persisted delivery + attempt data.
- Retryable path asserts exactly one follow-up queued job with same `delivery_id`.
- Permanent failure path asserts no follow-up job.
- Disabled/missing dependency path asserts terminal issue persistence.

**Do not copy** (lines 357-360):
```elixir
source = File.read!("lib/sigra/workers/webhook_delivery.ex")
assert source =~ "queue: :sigra_webhooks"
assert source =~ "max_attempts: 1"
```

That test is useful as a narrow compile-time guard, but it is more implementation-coupled than the row-level and job-level assertions above.

## Shared Patterns

### Outer transaction composition
**Sources:** [lib/sigra/webhooks.ex](/Users/jon/projects/sigra/lib/sigra/webhooks.ex:205), [lib/sigra/auth.ex](/Users/jon/projects/sigra/lib/sigra/auth.ex:240), [lib/sigra/organizations.ex](/Users/jon/projects/sigra/lib/sigra/organizations.ex:971), [lib/sigra/service_accounts.ex](/Users/jon/projects/sigra/lib/sigra/service_accounts.ex:29)

Apply to all Phase 100 domain mutations that need webhook persistence:
```elixir
Multi.new()
|> Multi.insert(...)
|> Webhooks.append_dispatch_multi(config, event_type, {:changes_key, :row}, ...)
```

### Minimal job payloads
**Sources:** [lib/sigra/webhooks.ex](/Users/jon/projects/sigra/lib/sigra/webhooks.ex:226), [lib/sigra/workers/webhook_delivery.ex](/Users/jon/projects/sigra/lib/sigra/workers/webhook_delivery.ex:34), [test/sigra/webhooks_integration_test.exs](/Users/jon/projects/sigra/test/sigra/webhooks_integration_test.exs:510)

Apply to initial enqueue and retry enqueue:
```elixir
Sigra.Workers.WebhookDelivery.new(%{"delivery_id" => delivery_id}, worker_opts)
```

### Optional dependency enforcement
**Sources:** [lib/sigra/optional_deps.ex](/Users/jon/projects/sigra/lib/sigra/optional_deps.ex:58), [lib/sigra/webhooks.ex](/Users/jon/projects/sigra/lib/sigra/webhooks.ex:425), [lib/sigra/workers/webhook_delivery.ex](/Users/jon/projects/sigra/lib/sigra/workers/webhook_delivery.ex:21)

Apply to any new public enqueue/handoff API:
```elixir
OptionalDeps.ensure_available!(:webhook_delivery, config: config)
```

### Persist state first, then enqueue next work
**Sources:** [lib/sigra/workers/webhook_delivery.ex](/Users/jon/projects/sigra/lib/sigra/workers/webhook_delivery.ex:206), [lib/sigra/webhooks.ex](/Users/jon/projects/sigra/lib/sigra/webhooks.ex:293)

Apply to retry scheduling and any new initial post-commit handoff:
```elixir
case Webhooks.persist_delivery_outcome(config, delivery, attrs) do
  {:ok, %{delivery: updated_delivery, next_attempt: next_retry}} ->
    Webhooks.enqueue_delivery(config, updated_delivery, ...)
```

### Atomicity-first tests
**Sources:** [test/sigra/webhooks_audit_atomicity_test.exs](/Users/jon/projects/sigra/test/sigra/webhooks_audit_atomicity_test.exs:198), [test/sigra/webhooks_reliable_delivery_atomicity_test.exs](/Users/jon/projects/sigra/test/sigra/webhooks_reliable_delivery_atomicity_test.exs:157)

Apply to all new handoff logic:
- Assert final persisted rows and counts.
- Force failures at schema/DB boundaries.
- Avoid asserting internal `Multi` shape unless the helper contract itself is the subject of the test.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/sigra/webhooks/handoff.ex` or equivalent post-commit helper | utility/service | post-commit handoff | The repo has pure `Multi` builders and worker-side durable retry handoff, but no reusable “enqueue after outer transaction commit” helper or after-commit callback seam yet. |

## Metadata

**Analog search scope:** `lib/sigra/webhooks*.ex`, `lib/sigra/workers/*.ex`, `lib/sigra/auth.ex`, `lib/sigra/organizations.ex`, `lib/sigra/service_accounts.ex`, `lib/sigra/delivery.ex`, `lib/sigra/optional_deps.ex`, `test/sigra/**/*webhook*test.exs`, prior phase artifacts under `.planning/phases/97-*`, `98-*`, `99-*`

**Files scanned:** 20+

**Pattern extraction date:** 2026-05-06
