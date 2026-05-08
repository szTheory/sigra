defmodule Sigra.WebhooksIntegrationTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias Ecto.Changeset
  alias Sigra.Auth
  alias Sigra.ServiceAccounts
  alias Sigra.Test.PostgresRepo
  alias Sigra.Webhooks
  alias Sigra.Webhooks.Signature
  alias Sigra.Workers.WebhookDelivery

  defmodule MockOban do
    def insert(%Ecto.Changeset{} = changeset) do
      job = %{
        args: Ecto.Changeset.get_change(changeset, :args),
        queue: Ecto.Changeset.get_change(changeset, :queue)
      }

      jobs = Process.get(:queued_jobs, [])
      Process.put(:queued_jobs, jobs ++ [job])
      {:ok, job}
    end
  end

  defmodule IntegrationUser do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "webhook_integration_users_97" do
      field :email, :string
      field :hashed_password, :string
      field :display_name, :string
      timestamps(type: :utc_datetime_usec)
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:email, :hashed_password, :display_name])
      |> validate_required([:email, :hashed_password])
      |> unique_constraint(:email, name: :webhook_integration_users_97_email_key)
    end
  end

  defmodule WebhookSubscription do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id

    schema "webhook_integration_subscriptions_97" do
      field :endpoint_url, :string
      field :event_types, {:array, :string}, default: []
      field :enabled, :boolean, default: true
      field :description, :string
      field :signing_secret, :binary
      field :next_signing_secret, :binary
      field :rotation_state, Ecto.Enum,
        values: [:stable, :prepared, :overlap_active, :completed],
        default: :stable

      field :rotation_prepared_at, :utc_datetime_usec
      field :rotation_overlap_started_at, :utc_datetime_usec
      field :rotation_retire_after_at, :utc_datetime_usec
      field :rotation_completed_at, :utc_datetime_usec
      field :rotation_last_changed_by_user_id, :binary_id
      field :signing_secret_fingerprint, :string
      field :next_signing_secret_fingerprint, :string
      timestamps(type: :utc_datetime_usec)
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [
        :endpoint_url,
        :event_types,
        :enabled,
        :description,
        :signing_secret,
        :next_signing_secret,
        :rotation_state,
        :rotation_prepared_at,
        :rotation_overlap_started_at,
        :rotation_retire_after_at,
        :rotation_completed_at,
        :rotation_last_changed_by_user_id,
        :signing_secret_fingerprint,
        :next_signing_secret_fingerprint
      ])
      |> validate_required([:endpoint_url, :event_types, :enabled, :signing_secret])
    end
  end

  defmodule WebhookEvent do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id

    schema "webhook_integration_events_97" do
      field :event_id, :string
      field :type, :string
      field :schema_version, :string
      field :occurred_at, :utc_datetime_usec
      field :payload, :map, default: %{}
      field :actor_id, :binary_id
      field :actor_type, :string
      field :organization_id, :binary_id
      field :request_id, :string
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [
        :event_id,
        :type,
        :schema_version,
        :occurred_at,
        :payload,
        :actor_id,
        :actor_type,
        :organization_id,
        :request_id
      ])
      |> validate_required([:event_id, :type, :schema_version, :occurred_at, :payload])
      |> unique_constraint(:event_id, name: :webhook_integration_events_97_event_id_index)
    end
  end

  defmodule WebhookDeliveryRow do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id

    schema "webhook_integration_deliveries_97" do
      field :delivery_id, :string
      field :status, :string, default: "pending"
      field :attempt_count, :integer, default: 0
      field :endpoint_url, :string
      field :dispatched_at, :utc_datetime_usec
      field :last_attempted_at, :utc_datetime_usec
      field :next_attempt_at, :utc_datetime_usec
      field :last_http_status, :integer
      field :last_error_category, :string
      field :last_error_detail, :string
      field :dead_lettered_at, :utc_datetime_usec
      field :terminal_reason, :string
      field :replayed_from_webhook_delivery_id, :binary_id
      field :replay_root_webhook_delivery_id, :binary_id
      field :replayed_at, :utc_datetime_usec
      field :replayed_by_user_id, :binary_id
      field :replay_source, :string
      belongs_to :webhook_subscription, WebhookSubscription
      belongs_to :webhook_event, WebhookEvent
      has_many :attempts, Sigra.WebhooksIntegrationTest.WebhookDeliveryAttemptRow,
        foreign_key: :webhook_delivery_id
      timestamps(type: :utc_datetime_usec)
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [
        :delivery_id,
        :status,
        :attempt_count,
        :endpoint_url,
        :dispatched_at,
        :last_attempted_at,
        :next_attempt_at,
        :last_http_status,
        :last_error_category,
        :last_error_detail,
        :dead_lettered_at,
        :terminal_reason,
        :replayed_from_webhook_delivery_id,
        :replay_root_webhook_delivery_id,
        :replayed_at,
        :replayed_by_user_id,
        :replay_source,
        :webhook_subscription_id,
        :webhook_event_id
      ])
      |> validate_required([
        :delivery_id,
        :status,
        :attempt_count,
        :endpoint_url,
        :webhook_subscription_id,
        :webhook_event_id
      ])
      |> assoc_constraint(:webhook_subscription)
      |> assoc_constraint(:webhook_event)
      |> unique_constraint(:delivery_id,
        name: :webhook_integration_deliveries_97_delivery_id_index
      )
      |> unique_constraint(:replayed_from_webhook_delivery_id,
        name: :webhook_integration_deliveries_97_replayed_from_unique_index
      )
    end
  end

  defmodule WebhookDeliveryAttemptRow do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id

    schema "webhook_integration_delivery_attempts_97" do
      field :delivery_id, :string
      field :attempt_number, :integer
      field :endpoint_url, :string
      field :started_at, :utc_datetime_usec
      field :finished_at, :utc_datetime_usec
      field :response_status, :integer
      field :retryable, :boolean, default: false
      field :retry_after_seconds, :integer
      field :error_category, :string
      field :error_detail, :string
      field :terminal_reason, :string
      belongs_to :webhook_delivery, Sigra.WebhooksIntegrationTest.WebhookDeliveryRow

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [
        :delivery_id,
        :attempt_number,
        :endpoint_url,
        :started_at,
        :finished_at,
        :response_status,
        :retryable,
        :retry_after_seconds,
        :error_category,
        :error_detail,
        :terminal_reason,
        :webhook_delivery_id
      ])
      |> validate_required([
        :delivery_id,
        :attempt_number,
        :endpoint_url,
        :started_at,
        :retryable
      ])
      |> assoc_constraint(:webhook_delivery)
      |> unique_constraint([:delivery_id, :attempt_number],
        name: :webhook_integration_delivery_attempts_97_delivery_id_attempt_number_index
      )
    end
  end

  defmodule ObanJobRow do
    use Ecto.Schema

    @primary_key {:id, :id, autogenerate: false}
    schema "oban_jobs" do
      field :state, :string
      field :queue, :string
      field :worker, :string
      field :args, :map
      field :max_attempts, :integer
      field :attempt, :integer
      field :priority, :integer
      field :inserted_at, :utc_datetime_usec
      field :scheduled_at, :utc_datetime_usec
    end
  end

  defmodule ServiceAccountRow do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "webhook_integration_service_accounts_100" do
      field :name, :string
      field :scopes, {:array, :string}, default: []
      field :role, :string
      field :token_epoch, :integer, default: 0
      field :revoked_at, :utc_datetime_usec
      field :last_used_at, :utc_datetime_usec
      field :organization_id, :binary_id
      field :created_by_user_id, :binary_id
      timestamps(type: :utc_datetime_usec)
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [
        :name,
        :scopes,
        :role,
        :token_epoch,
        :revoked_at,
        :last_used_at,
        :organization_id,
        :created_by_user_id
      ])
      |> validate_required([:name, :organization_id])
    end
  end

  setup do
    start_supervised!({PostgresRepo, PostgresRepo.default_config()})
    repo = PostgresRepo

    Application.put_env(:sigra, :repo, repo)
    Application.put_env(:sigra, :user_schema, IntegrationUser)
    Application.put_env(:sigra, :secret_key_base, String.duplicate("a", 64))
    Application.put_env(:sigra, :webhooks, webhooks_config())

    on_exit(fn ->
      Application.delete_env(:sigra, :repo)
      Application.delete_env(:sigra, :user_schema)
      Application.delete_env(:sigra, :secret_key_base)
      Application.delete_env(:sigra, :webhooks)
      Application.delete_env(:sigra, :webhook_delivery_requester)
      Application.delete_env(:sigra, :webhook_delivery_oban)
      Process.delete(:queued_jobs)
    end)

    Ecto.Adapters.SQL.query!(repo, ~s|CREATE EXTENSION IF NOT EXISTS "uuid-ossp"|, [])
    ensure_oban_jobs_table!(repo)

    Ecto.Adapters.SQL.query!(
      repo,
      "DROP TABLE IF EXISTS webhook_integration_delivery_attempts_97 CASCADE",
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      "DROP TABLE IF EXISTS webhook_integration_deliveries_97 CASCADE",
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      "DROP TABLE IF EXISTS webhook_integration_events_97 CASCADE",
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      "DROP TABLE IF EXISTS webhook_integration_subscriptions_97 CASCADE",
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      "DROP TABLE IF EXISTS webhook_integration_users_97 CASCADE",
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      "DROP TABLE IF EXISTS webhook_integration_service_accounts_100 CASCADE",
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE webhook_integration_users_97 (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        email text NOT NULL,
        hashed_password text NOT NULL,
        display_name text,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now(),
        CONSTRAINT webhook_integration_users_97_email_key UNIQUE (email)
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE webhook_integration_subscriptions_97 (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        endpoint_url text NOT NULL,
        event_types text[] NOT NULL DEFAULT '{}',
        enabled boolean NOT NULL DEFAULT true,
        description text,
        signing_secret bytea NOT NULL,
        next_signing_secret bytea,
        rotation_state text NOT NULL DEFAULT 'stable',
        rotation_prepared_at timestamp,
        rotation_overlap_started_at timestamp,
        rotation_retire_after_at timestamp,
        rotation_completed_at timestamp,
        rotation_last_changed_by_user_id uuid,
        signing_secret_fingerprint text,
        next_signing_secret_fingerprint text,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE webhook_integration_events_97 (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        event_id text NOT NULL,
        type text NOT NULL,
        schema_version text NOT NULL,
        occurred_at timestamp NOT NULL,
        payload jsonb NOT NULL,
        actor_id uuid,
        actor_type text,
        organization_id uuid,
        request_id text,
        inserted_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      "CREATE UNIQUE INDEX webhook_integration_events_97_event_id_index ON webhook_integration_events_97 (event_id)",
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE webhook_integration_deliveries_97 (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        delivery_id text NOT NULL,
        status text NOT NULL DEFAULT 'pending',
        attempt_count integer NOT NULL DEFAULT 0,
        endpoint_url text NOT NULL,
        dispatched_at timestamp,
        last_attempted_at timestamp,
        next_attempt_at timestamp,
        last_http_status integer,
        last_error_category text,
        last_error_detail text,
        dead_lettered_at timestamp,
        terminal_reason text,
        replayed_from_webhook_delivery_id uuid REFERENCES webhook_integration_deliveries_97(id),
        replay_root_webhook_delivery_id uuid REFERENCES webhook_integration_deliveries_97(id),
        replayed_at timestamp,
        replayed_by_user_id uuid,
        replay_source text,
        webhook_subscription_id uuid NOT NULL REFERENCES webhook_integration_subscriptions_97(id),
        webhook_event_id uuid NOT NULL REFERENCES webhook_integration_events_97(id),
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      "CREATE UNIQUE INDEX webhook_integration_deliveries_97_delivery_id_index ON webhook_integration_deliveries_97 (delivery_id)",
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      "CREATE UNIQUE INDEX webhook_integration_deliveries_97_replayed_from_unique_index ON webhook_integration_deliveries_97 (replayed_from_webhook_delivery_id) WHERE replayed_from_webhook_delivery_id IS NOT NULL",
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      "CREATE INDEX webhook_integration_deliveries_97_replay_root_index ON webhook_integration_deliveries_97 (replay_root_webhook_delivery_id)",
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE webhook_integration_delivery_attempts_97 (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        delivery_id text NOT NULL,
        attempt_number integer NOT NULL,
        endpoint_url text NOT NULL,
        started_at timestamp NOT NULL,
        finished_at timestamp,
        response_status integer,
        retryable boolean NOT NULL DEFAULT false,
        retry_after_seconds integer,
        error_category text,
        error_detail text,
        terminal_reason text,
        webhook_delivery_id uuid REFERENCES webhook_integration_deliveries_97(id),
        inserted_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      "CREATE UNIQUE INDEX webhook_integration_delivery_attempts_97_delivery_id_attempt_number_index ON webhook_integration_delivery_attempts_97 (delivery_id, attempt_number)",
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE webhook_integration_service_accounts_100 (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        name text NOT NULL,
        scopes text[] NOT NULL DEFAULT '{}',
        role text,
        token_epoch integer NOT NULL DEFAULT 0,
        revoked_at timestamp,
        last_used_at timestamp,
        organization_id uuid NOT NULL,
        created_by_user_id uuid,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    %{repo: repo}
  end

  test "register/3 persists one webhook event, one pending delivery per matching subscription, and one initial job per delivery",
       %{
         repo: repo
       } do
    config = config(repo)

    {:ok, sub_one} =
      Webhooks.create_subscription(config, %{
        endpoint_url: "https://one.example.test/hooks",
        event_types: ["user.created"],
        signing_secret: String.duplicate("a", 32)
      })

    {:ok, sub_two} =
      Webhooks.create_subscription(config, %{
        endpoint_url: "https://two.example.test/hooks",
        event_types: ["user.created", "session.created"],
        signing_secret: String.duplicate("b", 32)
      })

    {:ok, _disabled} =
      Webhooks.create_subscription(config, %{
        endpoint_url: "https://disabled.example.test/hooks",
        event_types: ["user.created"],
        enabled: false,
        signing_secret: String.duplicate("c", 32)
      })

    {:ok, _other_event} =
      Webhooks.create_subscription(config, %{
        endpoint_url: "https://other.example.test/hooks",
        event_types: ["session.created"],
        signing_secret: String.duplicate("d", 32)
      })

    assert {:ok, user} =
             Auth.register(
               config,
               %{
                 "email" => "phase97-webhook@example.com",
                 "hashed_password" => "hash",
                 "display_name" => "Phase 97"
               },
               register_opts(request_id: "req_phase97_register")
             )

    assert user.email == "phase97-webhook@example.com"
    assert 1 == repo.aggregate(IntegrationUser, :count)
    assert 1 == repo.aggregate(WebhookEvent, :count)
    assert 2 == repo.aggregate(WebhookDeliveryRow, :count)
    assert 2 == repo.aggregate(ObanJobRow, :count)

    event = repo.one(from(event in WebhookEvent, select: event))

    deliveries =
      repo.all(
        from(delivery in WebhookDeliveryRow,
          order_by: [asc: delivery.endpoint_url],
          select: delivery
        )
      )

    assert event.type == "user.created"
    assert event.schema_version == "2026-05-06"
    assert event.actor_id == user.id
    assert event.actor_type == "user"
    assert event.request_id == "req_phase97_register"
    assert event.payload["id"] == event.event_id
    assert event.payload["type"] == "user.created"
    assert event.payload["schema_version"] == "2026-05-06"
    assert get_in(event.payload, ["data", "object", "email"]) == user.email
    assert get_in(event.payload, ["context", "actor", "id"]) == user.id
    assert get_in(event.payload, ["context", "request", "id"]) == "req_phase97_register"

    assert Enum.map(deliveries, & &1.status) == ["pending", "pending"]

    assert Enum.map(deliveries, & &1.endpoint_url) == [
             "https://one.example.test/hooks",
             "https://two.example.test/hooks"
           ]

    assert Enum.sort(Enum.map(deliveries, & &1.webhook_subscription_id)) ==
             Enum.sort([sub_one.id, sub_two.id])

    assert Enum.all?(deliveries, &(&1.webhook_event_id == event.id))
    assert Enum.all?(deliveries, &is_binary(&1.delivery_id))
    assert Enum.all?(deliveries, &(&1.delivery_id != event.event_id))
    assert Enum.all?(deliveries, &(&1.attempt_count == 0))
    assert Enum.all?(deliveries, &is_nil(&1.last_attempted_at))
    assert Enum.all?(deliveries, &is_nil(&1.next_attempt_at))
    assert Enum.all?(deliveries, &is_nil(&1.dead_lettered_at))

    queued_jobs =
      repo.all(
        from(job in ObanJobRow,
          order_by: [asc: job.id],
          select: %{args: job.args, queue: job.queue, worker: job.worker}
        )
      )

    assert Enum.map(queued_jobs, & &1.args) ==
             Enum.map(deliveries, fn delivery -> %{"delivery_id" => delivery.delivery_id} end)

    assert Enum.all?(queued_jobs, &(&1.queue == "sigra_webhooks"))
    assert Enum.all?(queued_jobs, &(&1.worker == "Sigra.Workers.WebhookDelivery"))
  end

  test "service_account.create uses the same production seam to persist a delivery and initial job", %{
    repo: repo
  } do
    config = config(repo)
    scope = service_account_scope()

    {:ok, _subscription} =
      Webhooks.create_subscription(config, %{
        endpoint_url: "https://service-account.example.test/hooks",
        event_types: ["service_account.created"],
        signing_secret: String.duplicate("s", 32)
      })

    assert {:ok, service_account} =
             ServiceAccounts.create(config, scope, %{
               name: "CI Agent",
               scopes: ["deploy:write"],
               organization_id: scope.active_organization.id
             })

    assert service_account.name == "CI Agent"
    assert 1 == repo.aggregate(ServiceAccountRow, :count)

    assert %WebhookEvent{} = event =
             repo.one!(
               from(event in WebhookEvent,
                 where: event.type == "service_account.created",
                 select: event
               )
             )

    assert %WebhookDeliveryRow{} = delivery =
             repo.one!(
               from(delivery in WebhookDeliveryRow,
                 where: delivery.webhook_event_id == ^event.id,
                 select: delivery
               )
             )

    assert %ObanJobRow{args: %{"delivery_id" => queued_delivery_id}, queue: "sigra_webhooks"} =
             repo.one!(
               from(job in ObanJobRow,
                 where: job.worker == "Sigra.Workers.WebhookDelivery",
                 select: job
               )
             )

    assert queued_delivery_id == delivery.delivery_id
    assert get_in(event.payload, ["data", "object", "name"]) == "CI Agent"
    assert get_in(event.payload, ["data", "object", "organization_id"]) ==
             scope.active_organization.id
  end

  test "a persisted delivery can be queued and consumed by the worker without leaking secret material into job args",
       %{repo: repo} do
    config = config(repo)
    secret = "phase97-signing-secret-material"

    {:ok, _subscription} =
      Webhooks.create_subscription(config, %{
        endpoint_url: "https://receiver.example.test/inbox",
        event_types: ["user.created"],
        signing_secret: secret
      })

    assert {:ok, _user} =
             Auth.register(
               config,
               %{"email" => "worker-ready@example.com", "hashed_password" => "hash"},
               register_opts(request_id: "req_phase97_worker")
             )

    event = repo.one(from(event in WebhookEvent, select: event))
    delivery = repo.one(from(delivery in WebhookDeliveryRow, select: delivery))

    job_changeset = Webhooks.build_delivery_job(config, delivery)

    assert Changeset.get_change(job_changeset, :args) == %{"delivery_id" => delivery.delivery_id}
    assert Changeset.get_change(job_changeset, :queue) == "sigra_webhooks"
    refute inspect(Changeset.get_change(job_changeset, :args)) =~ secret
    assert delivery.status == "pending"
    assert delivery.attempt_count == 0
    assert is_nil(delivery.dispatched_at)

    Application.put_env(:sigra, :webhook_delivery_requester, fn request ->
      send(self(), {:webhook_request, request})
      {:ok, %{status: 202}}
    end)

    assert {:ok, :delivered} =
             WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => delivery.delivery_id}})

    assert_receive {:webhook_request, request}

    headers = Map.new(request.headers)
    timestamp = String.to_integer(headers["Sigra-Webhook-Timestamp"])

    assert request.url == "https://receiver.example.test/inbox"
    assert headers["Content-Type"] == "application/json"
    assert headers["Sigra-Webhook-Id"] == delivery.delivery_id
    assert Jason.decode!(request.body) == event.payload

    assert {:ok, %{delivery_id: delivery_id, timestamp: ^timestamp}} =
             Signature.verify(headers, request.body, secret, now: timestamp, tolerance: 0)

    assert delivery_id == delivery.delivery_id

    updated_delivery =
      repo.get_by!(WebhookDeliveryRow, delivery_id: delivery.delivery_id)

    assert updated_delivery.status == "delivered"
    assert %DateTime{} = updated_delivery.dispatched_at
  end

  test "the evolved delivery summary and attempts ledger are queryable in Postgres", %{repo: repo} do
    config = config(repo)

    {:ok, subscription} =
      Webhooks.create_subscription(config, %{
        endpoint_url: "https://history.example.test/hooks",
        event_types: ["user.created"],
        signing_secret: String.duplicate("z", 32)
      })

    {:ok, user} =
      Auth.register(
        config,
        %{"email" => "history@example.com", "hashed_password" => "hash"},
        register_opts(request_id: "req_phase98_history")
      )

    delivery =
      repo.one!(
        from(delivery in WebhookDeliveryRow,
          where: delivery.webhook_subscription_id == ^subscription.id,
          select: delivery
        )
      )

    attempted_at = DateTime.utc_now() |> DateTime.truncate(:second)
    finished_at = DateTime.add(attempted_at, 3, :second)

    {:ok, updated_delivery} =
      delivery
      |> WebhookDeliveryRow.changeset(%{
        status: "retry_scheduled",
        attempt_count: 1,
        last_attempted_at: attempted_at,
        next_attempt_at: DateTime.add(attempted_at, 60, :second),
        last_http_status: 429,
        last_error_category: "http_backpressure",
        last_error_detail: "receiver requested backoff"
      })
      |> repo.update()

    {:ok, attempt} =
      %WebhookDeliveryAttemptRow{}
      |> WebhookDeliveryAttemptRow.changeset(%{
        delivery_id: updated_delivery.delivery_id,
        attempt_number: 1,
        endpoint_url: updated_delivery.endpoint_url,
        started_at: attempted_at,
        finished_at: finished_at,
        response_status: 429,
        retryable: true,
        retry_after_seconds: 60,
        error_category: "http_backpressure",
        error_detail: "receiver requested backoff",
        webhook_delivery_id: updated_delivery.id
      })
      |> repo.insert()

    fetched_delivery =
      repo.one!(
        from(delivery in WebhookDeliveryRow,
          where: delivery.id == ^updated_delivery.id,
          preload: [:attempts]
        )
      )

    assert user.email == "history@example.com"
    assert fetched_delivery.status == "retry_scheduled"
    assert fetched_delivery.attempt_count == 1
    assert fetched_delivery.last_http_status == 429
    assert fetched_delivery.last_error_category == "http_backpressure"
    assert %DateTime{} = fetched_delivery.next_attempt_at
    assert [persisted_attempt] = fetched_delivery.attempts
    assert persisted_attempt.id == attempt.id
    assert persisted_attempt.attempt_number == 1
    assert persisted_attempt.retryable == true
    assert persisted_attempt.retry_after_seconds == 60
    assert persisted_attempt.terminal_reason == nil
  end

  test "retryable receiver failures keep the auth mutation committed and persist attempt history", %{
    repo: repo
  } do
    Application.put_env(:sigra, :webhook_delivery_oban, MockOban)
    Process.put(:queued_jobs, [])

    {:ok, _subscription} =
      Webhooks.create_subscription(config(repo), %{
        endpoint_url: "https://retry.example.test/hooks",
        event_types: ["user.created"],
        signing_secret: String.duplicate("r", 32)
      })

    {:ok, user} =
      Auth.register(
        config(repo),
        %{"email" => "retry-path@example.com", "hashed_password" => "hash"},
        register_opts(request_id: "req_phase98_retry")
      )

    delivery = repo.one!(from(delivery in WebhookDeliveryRow, select: delivery))

    Application.put_env(:sigra, :webhook_delivery_requester, fn _request ->
      {:ok, %{status: 429, headers: [{"Retry-After", "120"}]}}
    end)

    assert {:ok, :retry_scheduled} =
             WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => delivery.delivery_id}})

    persisted =
      repo.one!(
        from(delivery in WebhookDeliveryRow,
          where: delivery.delivery_id == ^delivery.delivery_id,
          preload: [:attempts]
        )
      )

    assert user.email == "retry-path@example.com"
    assert persisted.status == "retry_scheduled"
    assert persisted.attempt_count == 1
    assert persisted.last_http_status == 429
    assert persisted.last_error_category == "http_backpressure"
    assert %DateTime{} = persisted.next_attempt_at
    assert [attempt] = persisted.attempts
    assert attempt.delivery_id == delivery.delivery_id
    assert attempt.retryable == true
    assert attempt.retry_after_seconds == 120
    assert [%{args: %{"delivery_id" => same_delivery_id}, queue: "sigra_webhooks"}] =
             Process.get(:queued_jobs)
    assert same_delivery_id == delivery.delivery_id
  end

  test "permanent receiver failures dead-letter the delivery in place without breaking auth commits", %{
    repo: repo
  } do
    Application.put_env(:sigra, :webhook_delivery_oban, MockOban)
    Process.put(:queued_jobs, [])

    {:ok, _subscription} =
      Webhooks.create_subscription(config(repo), %{
        endpoint_url: "https://dead-letter.example.test/hooks",
        event_types: ["user.created"],
        signing_secret: String.duplicate("d", 32)
      })

    {:ok, user} =
      Auth.register(
        config(repo),
        %{"email" => "dead-letter@example.com", "hashed_password" => "hash"},
        register_opts(request_id: "req_phase98_dead_letter")
      )

    delivery = repo.one!(from(delivery in WebhookDeliveryRow, select: delivery))

    Application.put_env(:sigra, :webhook_delivery_requester, fn _request ->
      {:ok, %{status: 404}}
    end)

    assert {:ok, :dead_lettered} =
             WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => delivery.delivery_id}})

    persisted =
      repo.one!(
        from(delivery in WebhookDeliveryRow,
          where: delivery.delivery_id == ^delivery.delivery_id,
          preload: [:attempts]
        )
      )

    assert user.email == "dead-letter@example.com"
    assert persisted.status == "dead_lettered"
    assert persisted.attempt_count == 1
    assert %DateTime{} = persisted.dead_lettered_at
    assert persisted.terminal_reason == "http_4xx_permanent"
    assert [attempt] = persisted.attempts
    assert attempt.retryable == false
    assert attempt.response_status == 404
    assert attempt.terminal_reason == "http_4xx_permanent"
    assert [] = Process.get(:queued_jobs)
  end

  test "replay persists a fresh child delivery lineage and queues it once", %{repo: repo} do
    config = config(repo)
    actor_id = Ecto.UUID.generate()

    {:ok, _subscription} =
      Webhooks.create_subscription(config, %{
        endpoint_url: "https://replay.example.test/hooks",
        event_types: ["user.created"],
        signing_secret: String.duplicate("p", 32)
      })

    {:ok, _user} =
      Auth.register(
        config,
        %{"email" => "replay-path@example.com", "hashed_password" => "hash"},
        register_opts(request_id: "req_phase104_replay")
      )

    source = repo.one!(from(delivery in WebhookDeliveryRow, select: delivery))
    attempted_at = DateTime.utc_now() |> DateTime.truncate(:second)

    assert {:ok, %{delivery: dead_lettered}} =
             Webhooks.persist_delivery_outcome(config, source, %{
               attempt_number: 1,
               attempted_at: attempted_at,
               finished_at: attempted_at,
               response_status: 404,
               retryable: false,
               error_category: "http_client_error",
               error_detail: "receiver rejected request",
               terminal_reason: "http_4xx_permanent",
               endpoint_url: source.endpoint_url
             })

    original_job_count = repo.aggregate(ObanJobRow, :count)

    assert {:ok, %{source_delivery: replay_source, replay_delivery: replay_delivery}} =
             Webhooks.replay_delivery(
               config,
               dead_lettered.delivery_id,
               %{user: %{id: actor_id}},
               source: "admin.delivery_detail"
             )

    assert replay_source.id == source.id
    assert replay_delivery.delivery_id != source.delivery_id
    assert replay_delivery.status == "pending"
    assert replay_delivery.attempt_count == 0
    assert replay_delivery.replayed_from_webhook_delivery_id == source.id
    assert replay_delivery.replay_root_webhook_delivery_id == source.id
    assert replay_delivery.replayed_by_user_id == actor_id
    assert replay_delivery.replay_source == "admin.delivery_detail"
    assert %DateTime{} = replay_delivery.replayed_at

    persisted_source =
      repo.one!(
        from(delivery in WebhookDeliveryRow,
          where: delivery.id == ^source.id,
          preload: [:attempts]
        )
      )

    assert persisted_source.status == "dead_lettered"
    assert persisted_source.attempt_count == 1
    assert length(persisted_source.attempts) == 1

    assert repo.aggregate(WebhookDeliveryRow, :count) == 2
    assert repo.aggregate(WebhookDeliveryAttemptRow, :count) == 1
    assert repo.aggregate(ObanJobRow, :count) == original_job_count + 1

    assert %ObanJobRow{args: %{"delivery_id" => queued_delivery_id}} =
             repo.one!(
               from(job in ObanJobRow,
                 order_by: [desc: job.id],
                 limit: 1,
                 select: job
               )
             )

    assert queued_delivery_id == replay_delivery.delivery_id

    assert {:error, :replay_already_exists} =
             Webhooks.replay_delivery(
               config,
               dead_lettered.delivery_id,
               %{user: %{id: actor_id}},
               source: "admin.delivery_detail"
             )
  end

  test "rotation lifecycle persists explicit state, timestamps, actor metadata, and dual-slot truth",
       %{repo: repo} do
    config = config(repo)
    admin_scope = %{user: %{id: Ecto.UUID.generate()}}

    assert {:ok, subscription} =
             Webhooks.create_subscription(config, %{
               endpoint_url: "https://rotate.example.test/hooks",
               event_types: ["user.created"],
               signing_secret: String.duplicate("r", 32)
             })

    assert {:ok, prepared} = Webhooks.prepare_secret(config, subscription.id, scope: admin_scope)
    assert prepared.rotation_state == :prepared
    assert is_binary(prepared.next_signing_secret)
    assert prepared.next_signing_secret != prepared.signing_secret
    assert prepared.rotation_last_changed_by_user_id == admin_scope.user.id
    assert %DateTime{} = prepared.rotation_prepared_at
    assert is_binary(prepared.signing_secret_fingerprint)
    assert is_binary(prepared.next_signing_secret_fingerprint)

    retire_after_at = DateTime.utc_now() |> DateTime.add(1800, :second) |> DateTime.truncate(:second)

    assert {:ok, overlap} =
             Webhooks.start_secret_overlap(config, prepared.id,
               scope: admin_scope,
               retire_after_at: retire_after_at
             )

    assert overlap.rotation_state == :overlap_active
    assert %DateTime{} = overlap.rotation_overlap_started_at
    assert DateTime.compare(overlap.rotation_retire_after_at, retire_after_at) == :eq

    assert {:ok, completed} =
             Webhooks.complete_secret_rotation(config, overlap.id, scope: admin_scope)

    assert completed.rotation_state == :completed
    assert completed.next_signing_secret == nil
    assert completed.rotation_prepared_at == nil
    assert completed.rotation_overlap_started_at == nil
    assert completed.rotation_retire_after_at == nil
    assert completed.next_signing_secret_fingerprint == nil
    assert %DateTime{} = completed.rotation_completed_at

    persisted = repo.get!(WebhookSubscription, completed.id)

    assert persisted.rotation_state == :completed
    assert persisted.signing_secret == prepared.next_signing_secret
    assert persisted.next_signing_secret == nil
    assert persisted.rotation_last_changed_by_user_id == admin_scope.user.id
    assert %DateTime{} = persisted.rotation_completed_at
  end

  test "discard_prepared_secret clears the next slot and rejects out-of-order transitions",
       %{repo: repo} do
    config = config(repo)
    admin_scope = %{user: %{id: Ecto.UUID.generate()}}

    assert {:ok, subscription} =
             Webhooks.create_subscription(config, %{
               endpoint_url: "https://discard.example.test/hooks",
               event_types: ["user.created"],
               signing_secret: String.duplicate("d", 32)
             })

    assert {:error, start_changeset} = Webhooks.start_secret_overlap(config, subscription.id)
    assert errors_on(start_changeset).rotation_state == ["can only start overlap from prepared"]

    assert {:error, complete_changeset} = Webhooks.complete_secret_rotation(config, subscription.id)

    assert errors_on(complete_changeset).rotation_state == [
             "can only complete rotation from overlap_active"
           ]

    assert {:ok, prepared} = Webhooks.prepare_secret(config, subscription.id, scope: admin_scope)
    assert {:ok, discarded} = Webhooks.discard_prepared_secret(config, prepared.id, scope: admin_scope)

    assert discarded.rotation_state == :stable
    assert discarded.signing_secret == subscription.signing_secret
    assert discarded.next_signing_secret == nil
    assert discarded.rotation_prepared_at == nil
    assert discarded.rotation_overlap_started_at == nil
    assert discarded.rotation_retire_after_at == nil
    assert discarded.rotation_completed_at == nil
    assert discarded.next_signing_secret_fingerprint == nil
  end

  defp config(repo) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: IntegrationUser,
      secret_key_base: String.duplicate("a", 64),
      webhooks: webhooks_config(),
      service_accounts: [
        service_account_schema: ServiceAccountRow,
        client_id_prefix: "sigra_sa_",
        client_id_byte_size: 24
      ]
    )
  end

  defp service_account_scope do
    %{
      user: %{id: Ecto.UUID.generate()},
      active_organization: %{id: Ecto.UUID.generate()}
    }
  end

  defp webhooks_config do
    [
      enabled: true,
      webhook_subscription_schema: WebhookSubscription,
      webhook_event_schema: WebhookEvent,
      webhook_delivery_schema: WebhookDeliveryRow,
      webhook_delivery_attempt_schema: WebhookDeliveryAttemptRow,
      oban_queue: "sigra_webhooks",
      signature_tolerance: 300
    ]
  end

  defp register_opts(extra) do
    Keyword.merge(
      [changeset_fn: fn attrs -> IntegrationUser.changeset(%IntegrationUser{}, attrs) end],
      extra
    )
  end

  defp errors_on(%Changeset{} = changeset) do
    Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp ensure_oban_jobs_table!(repo) do
    Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS oban_jobs CASCADE", [])

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE oban_jobs (
        id bigserial PRIMARY KEY,
        state text NOT NULL DEFAULT 'available',
        queue text NOT NULL DEFAULT 'default',
        worker text NOT NULL,
        args jsonb NOT NULL,
        errors jsonb NOT NULL DEFAULT '[]'::jsonb,
        meta jsonb NOT NULL DEFAULT '{}'::jsonb,
        tags text[] NOT NULL DEFAULT '{}',
        attempt integer NOT NULL DEFAULT 0,
        attempted_by text[],
        max_attempts integer NOT NULL DEFAULT 20,
        priority integer NOT NULL DEFAULT 0,
        attempted_at timestamp,
        cancelled_at timestamp,
        completed_at timestamp,
        discarded_at timestamp,
        inserted_at timestamp NOT NULL DEFAULT now(),
        scheduled_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )
  end
end
