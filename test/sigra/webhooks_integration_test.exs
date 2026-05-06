defmodule Sigra.WebhooksIntegrationTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias Ecto.Changeset
  alias Sigra.Auth
  alias Sigra.Test.PostgresRepo
  alias Sigra.Webhooks
  alias Sigra.Webhooks.Signature
  alias Sigra.Workers.WebhookDelivery

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
      timestamps(type: :utc_datetime_usec)
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:endpoint_url, :event_types, :enabled, :description, :signing_secret])
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
    end)

    Ecto.Adapters.SQL.query!(repo, ~s|CREATE EXTENSION IF NOT EXISTS "uuid-ossp"|, [])

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

    %{repo: repo}
  end

  test "register/3 persists one webhook event and one pending delivery per matching subscription",
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

  defp config(repo) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: IntegrationUser,
      secret_key_base: String.duplicate("a", 64),
      webhooks: webhooks_config()
    )
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
end
