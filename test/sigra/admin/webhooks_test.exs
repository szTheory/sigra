defmodule Sigra.Admin.WebhooksTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias Sigra.Admin.Scope
  alias Sigra.Admin.Webhooks.{Actions, Detail, Failures, Query}
  alias Sigra.Test.PostgresRepo
  alias Sigra.Webhooks

  defmodule AdminUser do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "admin_webhooks_users_99" do
      field :email, :string
      field :display_name, :string
      timestamps(type: :utc_datetime_usec)
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:email, :display_name])
      |> validate_required([:email])
      |> unique_constraint(:email, name: :admin_webhooks_users_99_email_key)
    end
  end

  defmodule WebhookSubscription do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id

    schema "admin_webhooks_subscriptions_99" do
      field :endpoint_url, :string
      field :event_types, {:array, :string}, default: []
      field :enabled, :boolean, default: true
      field :description, :string
      field :signing_secret, :binary

      has_many :webhook_deliveries, Sigra.Admin.WebhooksTest.WebhookDelivery

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

    schema "admin_webhooks_events_99" do
      field :event_id, :string
      field :type, :string
      field :schema_version, :string
      field :occurred_at, :utc_datetime_usec
      field :payload, :map, default: %{}
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:event_id, :type, :schema_version, :occurred_at, :payload])
      |> validate_required([:event_id, :type, :schema_version, :occurred_at, :payload])
      |> unique_constraint(:event_id, name: :admin_webhooks_events_99_event_id_index)
    end
  end

  defmodule WebhookDelivery do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id

    schema "admin_webhooks_deliveries_99" do
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

      belongs_to :webhook_subscription, Sigra.Admin.WebhooksTest.WebhookSubscription
      belongs_to :webhook_event, Sigra.Admin.WebhooksTest.WebhookEvent
      has_many :attempts, Sigra.Admin.WebhooksTest.WebhookDeliveryAttempt

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
      |> unique_constraint(:delivery_id, name: :admin_webhooks_deliveries_99_delivery_id_index)
    end
  end

  defmodule WebhookDeliveryAttempt do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id

    schema "admin_webhooks_delivery_attempts_99" do
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

      belongs_to :webhook_delivery, Sigra.Admin.WebhooksTest.WebhookDelivery

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
        name: :admin_webhooks_delivery_attempts_99_delivery_id_attempt_number_index
      )
    end
  end

  setup do
    start_supervised!({PostgresRepo, PostgresRepo.default_config()})
    repo = PostgresRepo

    on_exit(fn ->
      Application.delete_env(:sigra, :repo)
      Application.delete_env(:sigra, :user_schema)
      Application.delete_env(:sigra, :secret_key_base)
      Application.delete_env(:sigra, :webhooks)
    end)

    Application.put_env(:sigra, :repo, repo)
    Application.put_env(:sigra, :user_schema, AdminUser)
    Application.put_env(:sigra, :secret_key_base, String.duplicate("s", 64))
    Application.put_env(:sigra, :webhooks, webhooks_config())

    recreate_tables!(repo)

    {:ok, repo: repo, config: config(repo), admin_scope: global_admin_scope()}
  end

  test "list_subscriptions normalizes URL params and reads delivery summary rows first", %{
    config: config,
    admin_scope: admin_scope
  } do
    healthy = subscription_fixture(config, %{description: "Healthy endpoint"})
    retrying = subscription_fixture(config, %{description: "Retrying endpoint", enabled: false})

    _older_delivery =
      delivery_fixture(config, healthy, %{
        delivery_id: "del_old",
        status: "delivered",
        attempt_count: 1,
        last_http_status: 204,
        inserted_at: ~U[2026-05-05 10:00:00Z]
      })

    _newer_delivery =
      delivery_fixture(config, healthy, %{
        delivery_id: "del_new",
        status: "retry_scheduled",
        attempt_count: 3,
        last_http_status: 500,
        next_attempt_at: ~U[2026-05-06 12:05:00Z],
        inserted_at: ~U[2026-05-06 12:00:00Z]
      })

    _retrying_delivery =
      delivery_fixture(config, retrying, %{
        delivery_id: "del_retry",
        status: "dead_lettered",
        attempt_count: 5,
        last_error_category: "http_error",
        terminal_reason: "retries_exhausted",
        inserted_at: ~U[2026-05-06 09:00:00Z]
      })

    assert {:ok, {rows, meta, normalized}} =
             Query.list_subscriptions(config, admin_scope, %{
               "page" => "1",
               "page_size" => "10",
               "status" => "retrying",
               "enabled" => "false",
               "q" => "retrying"
             })

    assert meta.current_page == 1
    assert normalized["status"] == "retrying"
    assert normalized["enabled"] == false
    assert normalized["q"] == "retrying"

    assert [
             %{
               subscription: %{id: retrying_id},
               latest_delivery: %{delivery_id: "del_retry", status: "dead_lettered"},
               delivery_summary: %{attempt_count: 5, terminal_reason: "retries_exhausted"}
             }
           ] = rows

    assert retrying_id == retrying.id
  end

  test "load_subscription and shared delivery detail use summary rows plus ordered attempts", %{
    config: config,
    admin_scope: admin_scope
  } do
    subscription = subscription_fixture(config, %{description: "Detail endpoint"})

    delivery =
      delivery_fixture(config, subscription, %{
        delivery_id: "del_detail",
        status: "retry_scheduled",
        attempt_count: 2,
        last_http_status: 502,
        next_attempt_at: ~U[2026-05-06 15:30:00Z],
        inserted_at: ~U[2026-05-06 14:00:00Z]
      })

    attempt_fixture(config, delivery, %{
      attempt_number: 1,
      response_status: 500,
      retryable: true,
      started_at: ~U[2026-05-06 14:01:00Z]
    })

    attempt_fixture(config, delivery, %{
      attempt_number: 2,
      response_status: 502,
      retryable: true,
      started_at: ~U[2026-05-06 14:05:00Z]
    })

    assert %{subscription: %{id: subscription_id}, recent_deliveries: [recent_delivery]} =
             Detail.load_subscription!(config, admin_scope, subscription.id)

    assert subscription_id == subscription.id
    assert recent_delivery.delivery_id == "del_detail"
    assert recent_delivery.status == "retry_scheduled"
    assert recent_delivery.attempt_count == 2

    assert %{delivery: %{delivery_id: "del_detail"}, attempts: attempts} =
             Detail.load_delivery!(config, admin_scope, "del_detail")

    assert Enum.map(attempts, & &1.attempt_number) == [2, 1]
  end

  test "list_failures only returns retrying and dead-letter summary rows", %{
    config: config,
    admin_scope: admin_scope
  } do
    subscription = subscription_fixture(config, %{description: "Failures endpoint"})

    _delivered =
      delivery_fixture(config, subscription, %{
        delivery_id: "delivered_ok",
        status: "delivered",
        attempt_count: 1,
        last_http_status: 200,
        inserted_at: ~U[2026-05-06 10:00:00Z]
      })

    retrying =
      delivery_fixture(config, subscription, %{
        delivery_id: "needs_retry",
        status: "retry_scheduled",
        attempt_count: 2,
        last_error_category: "http_error",
        next_attempt_at: ~U[2026-05-06 11:00:00Z],
        inserted_at: ~U[2026-05-06 10:30:00Z]
      })

    dead_lettered =
      delivery_fixture(config, subscription, %{
        delivery_id: "dead_letter",
        status: "dead_lettered",
        attempt_count: 6,
        terminal_reason: "retries_exhausted",
        dead_lettered_at: ~U[2026-05-06 10:45:00Z],
        inserted_at: ~U[2026-05-06 10:45:00Z]
      })

    assert {:ok, {rows, _meta, normalized}} =
             Failures.list_deliveries(config, admin_scope, %{"status" => "retrying"})

    assert normalized["status"] == "retrying"
    assert Enum.map(rows, & &1.delivery.delivery_id) == [dead_lettered.delivery_id, retrying.delivery_id]
    assert Enum.all?(rows, &(&1.delivery.status in ["retry_scheduled", "dead_lettered"]))
  end

  test "create and update persist explicit event_types instead of wildcard semantics", %{
    config: config,
    admin_scope: admin_scope
  } do
    attrs = %{
      endpoint_url: "https://example.com/webhooks",
      description: "Catalog endpoint",
      enabled: true,
      signing_secret: String.duplicate("1", 32),
      event_types: [
        "user.created",
        "user.created",
        " session.created ",
        "",
        "session.created"
      ]
    }

    assert {:ok, created} = Actions.create(config, admin_scope, attrs)
    assert created.event_types == ["user.created", "session.created"]

    assert {:ok, updated} =
             Actions.update(config, admin_scope, created.id, %{
               event_types: ["session.created", "session.created", "user.created"]
             })

    assert updated.event_types == ["session.created", "user.created"]
  end

  test "reveal_secret requires an explicit action and rotate_secret replaces the active secret", %{
    config: config,
    admin_scope: admin_scope
  } do
    subscription =
      subscription_fixture(config, %{
        signing_secret: String.duplicate("a", 32),
        description: "Secret endpoint"
      })

    assert {:ok, %{signing_secret: secret}} =
             Actions.reveal_secret(config, admin_scope, subscription.id)

    assert secret == String.duplicate("a", 32)

    assert {:ok, rotated} = Actions.rotate_secret(config, admin_scope, subscription.id)
    assert rotated.signing_secret != secret
    assert byte_size(rotated.signing_secret) >= 32

    reloaded =
      config.repo.get_by!(WebhookSubscription, id: subscription.id)

    assert reloaded.signing_secret == rotated.signing_secret
  end

  defp config(repo) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: AdminUser,
      secret_key_base: String.duplicate("s", 64),
      webhooks: webhooks_config()
    )
  end

  defp webhooks_config do
    [
      enabled: false,
      webhook_subscription_schema: WebhookSubscription,
      webhook_event_schema: WebhookEvent,
      webhook_delivery_schema: WebhookDelivery,
      webhook_delivery_attempt_schema: WebhookDeliveryAttempt,
      oban_queue: "sigra_webhooks",
      signature_tolerance: 300
    ]
  end

  defp global_admin_scope do
    %Scope{
      mode: :global,
      scope: %{user: %{id: Ecto.UUID.generate(), email: "admin@example.com"}},
      organization: nil,
      organization_id: nil,
      organization_slug: nil,
      platform_admin?: true,
      admin_org_ids: []
    }
  end

  defp subscription_fixture(config, attrs) do
    base = %{
      endpoint_url: "https://example.com/hook",
      event_types: ["user.created"],
      enabled: true,
      description: "Webhook endpoint",
      signing_secret: String.duplicate("x", 32)
    }

    {:ok, subscription} = Webhooks.create_subscription(config, Map.merge(base, attrs))
    subscription
  end

  defp delivery_fixture(config, subscription, attrs) do
    event =
      %WebhookEvent{}
      |> WebhookEvent.changeset(%{
        event_id: Ecto.UUID.generate(),
        type: "user.created",
        schema_version: "2026-05-06",
        occurred_at: ~U[2026-05-06 09:00:00Z],
        payload: %{"id" => Ecto.UUID.generate()}
      })
      |> config.repo.insert!()

    inserted_at = Map.get(attrs, :inserted_at, ~U[2026-05-06 09:00:00Z])

    %WebhookDelivery{}
    |> WebhookDelivery.changeset(%{
      delivery_id: Map.get(attrs, :delivery_id, Ecto.UUID.generate()),
      status: Map.get(attrs, :status, "pending"),
      attempt_count: Map.get(attrs, :attempt_count, 0),
      endpoint_url: subscription.endpoint_url,
      dispatched_at: Map.get(attrs, :dispatched_at),
      last_attempted_at: Map.get(attrs, :last_attempted_at),
      next_attempt_at: Map.get(attrs, :next_attempt_at),
      last_http_status: Map.get(attrs, :last_http_status),
      last_error_category: Map.get(attrs, :last_error_category),
      last_error_detail: Map.get(attrs, :last_error_detail),
      dead_lettered_at: Map.get(attrs, :dead_lettered_at),
      terminal_reason: Map.get(attrs, :terminal_reason),
      webhook_subscription_id: subscription.id,
      webhook_event_id: event.id
    })
    |> config.repo.insert!()
    |> then(fn delivery ->
      from(d in WebhookDelivery, where: d.id == ^delivery.id)
      |> config.repo.update_all(set: [inserted_at: inserted_at, updated_at: inserted_at])

      config.repo.get!(WebhookDelivery, delivery.id)
    end)
  end

  defp attempt_fixture(config, delivery, attrs) do
    %WebhookDeliveryAttempt{}
    |> WebhookDeliveryAttempt.changeset(%{
      delivery_id: delivery.delivery_id,
      attempt_number: Map.fetch!(attrs, :attempt_number),
      endpoint_url: Map.get(attrs, :endpoint_url, delivery.endpoint_url),
      started_at: Map.fetch!(attrs, :started_at),
      finished_at: Map.get(attrs, :finished_at),
      response_status: Map.get(attrs, :response_status),
      retryable: Map.get(attrs, :retryable, false),
      retry_after_seconds: Map.get(attrs, :retry_after_seconds),
      error_category: Map.get(attrs, :error_category),
      error_detail: Map.get(attrs, :error_detail),
      terminal_reason: Map.get(attrs, :terminal_reason),
      webhook_delivery_id: delivery.id
    })
    |> config.repo.insert!()
  end

  defp recreate_tables!(repo) do
    Ecto.Adapters.SQL.query!(repo, ~s|CREATE EXTENSION IF NOT EXISTS "uuid-ossp"|, [])

    for statement <- [
          "DROP TABLE IF EXISTS admin_webhooks_delivery_attempts_99 CASCADE",
          "DROP TABLE IF EXISTS admin_webhooks_deliveries_99 CASCADE",
          "DROP TABLE IF EXISTS admin_webhooks_events_99 CASCADE",
          "DROP TABLE IF EXISTS admin_webhooks_subscriptions_99 CASCADE",
          "DROP TABLE IF EXISTS admin_webhooks_users_99 CASCADE",
          """
          CREATE TABLE admin_webhooks_users_99 (
            id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
            email text NOT NULL,
            display_name text,
            inserted_at timestamp(6) without time zone NOT NULL DEFAULT now(),
            updated_at timestamp(6) without time zone NOT NULL DEFAULT now(),
            CONSTRAINT admin_webhooks_users_99_email_key UNIQUE (email)
          )
          """,
          """
          CREATE TABLE admin_webhooks_subscriptions_99 (
            id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
            endpoint_url text NOT NULL,
            event_types text[] NOT NULL DEFAULT '{}',
            enabled boolean NOT NULL DEFAULT true,
            description text,
            signing_secret bytea NOT NULL,
            inserted_at timestamp(6) without time zone NOT NULL DEFAULT now(),
            updated_at timestamp(6) without time zone NOT NULL DEFAULT now()
          )
          """,
          """
          CREATE TABLE admin_webhooks_events_99 (
            id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
            event_id text NOT NULL,
            type text NOT NULL,
            schema_version text NOT NULL,
            occurred_at timestamp(6) without time zone NOT NULL,
            payload jsonb NOT NULL DEFAULT '{}'::jsonb,
            inserted_at timestamp(6) without time zone NOT NULL DEFAULT now()
          )
          """,
          "CREATE UNIQUE INDEX admin_webhooks_events_99_event_id_index ON admin_webhooks_events_99 (event_id)",
          """
          CREATE TABLE admin_webhooks_deliveries_99 (
            id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
            delivery_id text NOT NULL,
            status text NOT NULL DEFAULT 'pending',
            attempt_count integer NOT NULL DEFAULT 0,
            endpoint_url text NOT NULL,
            dispatched_at timestamp(6) without time zone,
            last_attempted_at timestamp(6) without time zone,
            next_attempt_at timestamp(6) without time zone,
            last_http_status integer,
            last_error_category text,
            last_error_detail text,
            dead_lettered_at timestamp(6) without time zone,
            terminal_reason text,
            webhook_subscription_id uuid NOT NULL REFERENCES admin_webhooks_subscriptions_99(id),
            webhook_event_id uuid NOT NULL REFERENCES admin_webhooks_events_99(id),
            inserted_at timestamp(6) without time zone NOT NULL DEFAULT now(),
            updated_at timestamp(6) without time zone NOT NULL DEFAULT now()
          )
          """,
          "CREATE UNIQUE INDEX admin_webhooks_deliveries_99_delivery_id_index ON admin_webhooks_deliveries_99 (delivery_id)",
          """
          CREATE TABLE admin_webhooks_delivery_attempts_99 (
            id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
            delivery_id text NOT NULL,
            attempt_number integer NOT NULL,
            endpoint_url text NOT NULL,
            started_at timestamp(6) without time zone NOT NULL,
            finished_at timestamp(6) without time zone,
            response_status integer,
            retryable boolean NOT NULL DEFAULT false,
            retry_after_seconds integer,
            error_category text,
            error_detail text,
            terminal_reason text,
            webhook_delivery_id uuid REFERENCES admin_webhooks_deliveries_99(id),
            inserted_at timestamp(6) without time zone NOT NULL DEFAULT now()
          )
          """,
          """
          CREATE UNIQUE INDEX admin_webhooks_delivery_attempts_99_delivery_id_attempt_number_index
          ON admin_webhooks_delivery_attempts_99 (delivery_id, attempt_number)
          """
        ] do
      Ecto.Adapters.SQL.query!(repo, statement, [])
    end
  end
end
