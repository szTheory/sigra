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

      has_many :webhook_deliveries, Sigra.Admin.WebhooksTest.WebhookDelivery

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
      field :replayed_from_webhook_delivery_id, :binary_id
      field :replay_root_webhook_delivery_id, :binary_id
      field :replayed_at, :utc_datetime_usec
      field :replayed_by_user_id, :binary_id
      field :replay_source, :string

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
      |> unique_constraint(:delivery_id, name: :admin_webhooks_deliveries_99_delivery_id_index)
      |> unique_constraint(:replayed_from_webhook_delivery_id,
        name: :admin_webhooks_deliveries_99_replayed_from_unique_index
      )
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

  test "list_subscriptions filters by latest delivery state before pagination and normalizes params",
       %{
         config: config,
         admin_scope: admin_scope
       } do
    matching =
      subscription_fixture(config, %{description: "Retrying endpoint", enabled: false})
      |> set_subscription_inserted_at!(config, ~U[2026-05-06 09:00:00Z])

    newer_dead_letter =
      subscription_fixture(config, %{description: "Dead letter endpoint"})
      |> set_subscription_inserted_at!(config, ~U[2026-05-06 10:00:00Z])

    newest_healthy =
      subscription_fixture(config, %{description: "Healthy endpoint"})
      |> set_subscription_inserted_at!(config, ~U[2026-05-06 11:00:00Z])

    _matching_delivery =
      delivery_fixture(config, matching, %{
        delivery_id: "del_retry",
        status: "retry_scheduled",
        attempt_count: 3,
        last_http_status: 500,
        next_attempt_at: ~U[2026-05-06 12:05:00Z],
        inserted_at: ~U[2026-05-06 12:00:00Z]
      })

    _dead_letter_delivery =
      delivery_fixture(config, newer_dead_letter, %{
        delivery_id: "del_dead_letter",
        status: "dead_lettered",
        attempt_count: 5,
        last_error_category: "http_error",
        terminal_reason: "retries_exhausted",
        inserted_at: ~U[2026-05-06 12:10:00Z]
      })

    _healthy_delivery =
      delivery_fixture(config, newest_healthy, %{
        delivery_id: "delivered_ok",
        status: "delivered",
        attempt_count: 1,
        last_http_status: 204,
        inserted_at: ~U[2026-05-06 12:15:00Z]
      })

    assert {:ok, {rows, meta, normalized}} =
             Query.list_subscriptions(config, admin_scope, %{
               "page" => "1",
               "page_size" => "1",
               "status" => "retrying",
               "enabled" => "false",
               "q" => "retrying"
             })

    assert meta.current_page == 1
    assert normalized["delivery_state"] == "retrying"
    refute Map.has_key?(normalized, "status")
    assert normalized["enabled"] == false
    assert normalized["q"] == "retrying"

    assert [%{subscription: %{id: retrying_id}} = row] = rows
    assert retrying_id == matching.id
    assert row.latest_delivery.delivery_id == "del_retry"
    assert row.latest_delivery.status == "retry_scheduled"
    assert row.delivery_summary.attempt_count == 3
    assert row.delivery_summary.next_attempt_at == ~U[2026-05-06 12:05:00.000000Z]
    assert row.delivery_summary.status == "retry_scheduled"
  end

  test "list_subscriptions uses latest delivery state instead of historical worst case", %{
    config: config,
    admin_scope: admin_scope
  } do
    recovered =
      subscription_fixture(config, %{description: "Recovered endpoint"})
      |> set_subscription_inserted_at!(config, ~U[2026-05-06 09:30:00Z])

    retrying =
      subscription_fixture(config, %{description: "Still retrying endpoint"})
      |> set_subscription_inserted_at!(config, ~U[2026-05-06 09:45:00Z])

    _older_dead_letter =
      delivery_fixture(config, recovered, %{
        delivery_id: "dead_letter_then_recovered",
        status: "dead_lettered",
        attempt_count: 5,
        terminal_reason: "retries_exhausted",
        inserted_at: ~U[2026-05-06 10:00:00Z]
      })

    _newer_success =
      delivery_fixture(config, recovered, %{
        delivery_id: "recovered_delivery",
        status: "delivered",
        attempt_count: 1,
        last_http_status: 204,
        inserted_at: ~U[2026-05-06 10:05:00Z]
      })

    _retrying_delivery =
      delivery_fixture(config, retrying, %{
        delivery_id: "still_retrying",
        status: "retry_scheduled",
        attempt_count: 2,
        inserted_at: ~U[2026-05-06 10:10:00Z]
      })

    assert {:ok, {dead_letter_rows, _meta, normalized}} =
             Query.list_subscriptions(config, admin_scope, %{"delivery_state" => "dead_lettered"})

    assert normalized["delivery_state"] == "dead_lettered"
    assert dead_letter_rows == []

    assert {:ok, {retry_rows, _meta, _normalized}} =
             Query.list_subscriptions(config, admin_scope, %{"delivery_state" => "retrying"})

    assert Enum.map(retry_rows, & &1.subscription.id) == [retrying.id]
    refute Enum.any?(retry_rows, &(&1.subscription.id == recovered.id))
  end

  test "subscription and failure summary counts share the same persisted delivery-state truth", %{
    config: config,
    admin_scope: admin_scope
  } do
    _no_delivery = subscription_fixture(config, %{description: "No delivery yet", enabled: true})
    retrying = subscription_fixture(config, %{description: "Retrying", enabled: true})
    dead_lettered = subscription_fixture(config, %{description: "Dead lettered", enabled: false})
    delivered = subscription_fixture(config, %{description: "Delivered", enabled: true})

    delivery_fixture(config, retrying, %{
      delivery_id: "retrying_delivery",
      status: "retry_scheduled",
      attempt_count: 2,
      inserted_at: ~U[2026-05-06 11:00:00Z]
    })

    delivery_fixture(config, dead_lettered, %{
      delivery_id: "dead_letter_delivery",
      status: "dead_lettered",
      attempt_count: 6,
      terminal_reason: "retries_exhausted",
      inserted_at: ~U[2026-05-06 11:05:00Z]
    })

    delivery_fixture(config, delivered, %{
      delivery_id: "delivered_delivery",
      status: "delivered",
      attempt_count: 1,
      last_http_status: 200,
      inserted_at: ~U[2026-05-06 11:10:00Z]
    })

    assert Query.summary_counts(config, admin_scope) == %{
             total: 4,
             enabled: 3,
             disabled: 1,
             retrying: 1,
             dead_lettered: 1
           }

    assert Failures.summary_counts(config, admin_scope) == %{
             total: 2,
             retrying: 1,
             dead_lettered: 1
           }
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

    assert %{
             subscription: %{id: subscription_id},
             rotation: rotation,
             recent_deliveries: [recent_delivery]
           } =
             Detail.load_subscription!(config, admin_scope, subscription.id)

    assert subscription_id == subscription.id
    assert rotation.state == :stable
    assert rotation.signing_mode =~ "current active secret"
    assert rotation.next_step =~ "Prepare a new secret"
    assert recent_delivery.delivery_id == "del_detail"
    assert recent_delivery.status == "retry_scheduled"
    assert recent_delivery.attempt_count == 2

    assert %{delivery: %{delivery_id: "del_detail"}, attempts: attempts, policy: policy} =
             Detail.load_delivery!(config, admin_scope, "del_detail")

    assert Enum.map(attempts, & &1.attempt_number) == [2, 1]
    assert policy == %{blocked?: false, reason: nil, detail: nil}
  end

  test "delivery detail and failures expose truthful local policy metadata", %{
    config: config,
    admin_scope: admin_scope
  } do
    subscription = subscription_fixture(config, %{description: "Blocked endpoint"})

    delivery =
      delivery_fixture(config, subscription, %{
        delivery_id: "del_blocked",
        status: "dead_lettered",
        attempt_count: 1,
        last_error_category: "local_policy_error",
        last_error_detail: "blocked by deployment callback",
        terminal_reason: "policy_denied",
        dead_lettered_at: ~U[2026-05-06 16:00:00Z],
        inserted_at: ~U[2026-05-06 16:00:00Z]
      })

    attempt_fixture(config, delivery, %{
      attempt_number: 1,
      retryable: false,
      error_category: "local_policy_error",
      error_detail: "blocked by deployment callback",
      terminal_reason: "policy_denied",
      started_at: ~U[2026-05-06 16:00:00Z]
    })

    assert %{policy: %{blocked?: true, reason: "policy_denied", detail: "blocked by deployment callback"}} =
             Detail.load_delivery!(config, admin_scope, "del_blocked")

    assert {:ok, {[row], _meta, _normalized}} =
             Failures.list_deliveries(config, admin_scope, %{"delivery_state" => "dead_lettered"})

    assert row.delivery.delivery_id == "del_blocked"
    assert row.policy_reason == "policy_denied"
    assert row.policy_detail == "blocked by deployment callback"
  end

  test "list_failures keeps retrying and dead-lettered rows strictly partitioned", %{
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

    assert normalized["delivery_state"] == "retrying"
    refute Map.has_key?(normalized, "status")
    assert Enum.map(rows, & &1.delivery.delivery_id) == [retrying.delivery_id]
    assert Enum.all?(rows, &(&1.delivery.status == "retry_scheduled"))

    assert {:ok, {dead_letter_rows, _meta, dead_letter_normalized}} =
             Failures.list_deliveries(config, admin_scope, %{"delivery_state" => "dead_lettered"})

    assert dead_letter_normalized["delivery_state"] == "dead_lettered"
    assert Enum.map(dead_letter_rows, & &1.delivery.delivery_id) == [dead_lettered.delivery_id]
    assert Enum.all?(dead_letter_rows, &(&1.delivery.status == "dead_lettered"))
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

  test "admin lifecycle actions prepare, start overlap, complete rotation, and reveal current secret",
       %{
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

    assert {:ok, prepared} = Actions.prepare_secret(config, admin_scope, subscription.id)
    assert prepared.rotation_state == :prepared
    assert prepared.signing_secret == secret
    assert is_binary(prepared.next_signing_secret)
    assert prepared.next_signing_secret != secret

    retire_after_at = ~U[2026-05-07 16:00:00Z]

    assert {:ok, overlap} =
             Actions.start_secret_overlap(config, admin_scope, subscription.id,
               retire_after_at: retire_after_at
             )

    assert overlap.rotation_state == :overlap_active
    assert DateTime.compare(overlap.rotation_retire_after_at, retire_after_at) == :eq

    assert {:ok, completed} =
             Actions.complete_secret_rotation(config, admin_scope, subscription.id)

    assert completed.rotation_state == :completed
    assert completed.signing_secret == prepared.next_signing_secret
    assert completed.next_signing_secret == nil

    reloaded = config.repo.get_by!(WebhookSubscription, id: subscription.id)
    assert reloaded.signing_secret == completed.signing_secret
  end

  test "replay_delivery authorizes globally and delegates the replay through the library seam", %{
    config: config,
    admin_scope: admin_scope
  } do
    config = put_in(config.webhooks[:enabled], true)
    subscription = subscription_fixture(config, %{description: "Replayable endpoint"})

    source =
      delivery_fixture(config, subscription, %{
        delivery_id: "del_replay_source",
        status: "dead_lettered",
        attempt_count: 6,
        dead_lettered_at: ~U[2026-05-06 16:00:00Z],
        terminal_reason: "retries_exhausted",
        inserted_at: ~U[2026-05-06 16:00:00Z]
      })

    assert {:ok, %{source_delivery: source_delivery, replay_delivery: replay_delivery}} =
             Actions.replay_delivery(config, admin_scope, source.delivery_id,
               source: "admin.delivery_detail"
             )

    assert source_delivery.id == source.id
    assert replay_delivery.replayed_from_webhook_delivery_id == source.id
    assert replay_delivery.replay_root_webhook_delivery_id == source.id
    assert replay_delivery.replayed_by_user_id == admin_scope.scope.user.id
    assert replay_delivery.replay_source == "admin.delivery_detail"
    assert replay_delivery.status == "pending"
    assert replay_delivery.delivery_id != source.delivery_id

    unauthorized_scope = organization_admin_scope()

    assert_raise Sigra.Admin.Authorizer.UnauthorizedError, fn ->
      Actions.replay_delivery(config, unauthorized_scope, source.delivery_id,
        source: "admin.delivery_detail"
      )
    end
  end

  test "load_delivery returns replay lineage and normalized eligibility without merging attempt ledgers",
       %{
         config: config,
         admin_scope: admin_scope
       } do
    subscription = subscription_fixture(config, %{description: "Lineage endpoint"})

    root =
      delivery_fixture(config, subscription, %{
        delivery_id: "del_root",
        status: "dead_lettered",
        attempt_count: 5,
        dead_lettered_at: ~U[2026-05-06 17:00:00Z],
        terminal_reason: "retries_exhausted",
        inserted_at: ~U[2026-05-06 17:00:00Z]
      })

    child =
      delivery_fixture(config, subscription, %{
        delivery_id: "del_child",
        status: "delivered",
        attempt_count: 1,
        last_http_status: 204,
        replayed_from_webhook_delivery_id: root.id,
        replay_root_webhook_delivery_id: root.id,
        replayed_at: ~U[2026-05-06 17:15:00Z],
        replayed_by_user_id: admin_scope.scope.user.id,
        replay_source: "admin.delivery_detail",
        inserted_at: ~U[2026-05-06 17:15:00Z]
      })

    grandchild =
      delivery_fixture(config, subscription, %{
        delivery_id: "del_grandchild",
        status: "dead_lettered",
        attempt_count: 2,
        dead_lettered_at: ~U[2026-05-06 17:30:00Z],
        terminal_reason: "retries_exhausted",
        replayed_from_webhook_delivery_id: child.id,
        replay_root_webhook_delivery_id: root.id,
        replayed_at: ~U[2026-05-06 17:30:00Z],
        replayed_by_user_id: admin_scope.scope.user.id,
        replay_source: "admin.delivery_detail",
        inserted_at: ~U[2026-05-06 17:30:00Z]
      })

    attempt_fixture(config, root, %{
      attempt_number: 1,
      response_status: 500,
      retryable: true,
      started_at: ~U[2026-05-06 17:01:00Z]
    })

    attempt_fixture(config, child, %{
      attempt_number: 1,
      response_status: 204,
      retryable: false,
      started_at: ~U[2026-05-06 17:16:00Z]
    })

    attempt_fixture(config, grandchild, %{
      attempt_number: 1,
      response_status: 500,
      retryable: true,
      started_at: ~U[2026-05-06 17:31:00Z]
    })

    assert %{
             delivery: %{id: child_id, delivery_id: "del_child"},
             attempts: attempts,
             replay: replay,
             replay_parent: replay_parent,
             replay_root: replay_root,
             replay_children: replay_children
           } = Detail.load_delivery!(config, admin_scope, child.delivery_id)

    assert child_id == child.id
    assert Enum.map(attempts, & &1.delivery_id) == [child.delivery_id]
    assert Enum.map(attempts, & &1.attempt_number) == [1]
    assert replay == %{eligible?: false, reason: :not_dead_lettered}
    assert replay_parent.id == root.id
    assert replay_root.id == root.id
    assert Enum.map(replay_children, & &1.id) == [grandchild.id]

    assert %{
             replay: root_replay,
             replay_parent: nil,
             replay_root: %{id: root_id},
             replay_children: root_children
           } = Detail.load_delivery!(config, admin_scope, root.delivery_id)

    assert root_id == root.id
    assert root_replay == %{eligible?: false, reason: :replay_already_exists}
    assert Enum.map(root_children, & &1.id) == [child.id]
  end

  test "list_failures adds replay shortcut metadata while staying delivery-row based", %{
    config: config,
    admin_scope: admin_scope
  } do
    active_subscription = subscription_fixture(config, %{description: "Replayable dead letter"})

    disabled_subscription =
      subscription_fixture(config, %{description: "Disabled endpoint", enabled: false})

    replayable =
      delivery_fixture(config, active_subscription, %{
        delivery_id: "dead_letter_replayable",
        status: "dead_lettered",
        attempt_count: 4,
        dead_lettered_at: ~U[2026-05-06 18:00:00Z],
        terminal_reason: "retries_exhausted",
        inserted_at: ~U[2026-05-06 18:00:00Z]
      })

    already_replayed =
      delivery_fixture(config, active_subscription, %{
        delivery_id: "dead_letter_already_replayed",
        status: "dead_lettered",
        attempt_count: 6,
        dead_lettered_at: ~U[2026-05-06 18:10:00Z],
        terminal_reason: "retries_exhausted",
        inserted_at: ~U[2026-05-06 18:10:00Z]
      })

    replay_child =
      delivery_fixture(config, active_subscription, %{
        delivery_id: "dead_letter_already_replayed_child",
        status: "pending",
        attempt_count: 0,
        replayed_from_webhook_delivery_id: already_replayed.id,
        replay_root_webhook_delivery_id: already_replayed.id,
        replayed_at: ~U[2026-05-06 18:12:00Z],
        replayed_by_user_id: admin_scope.scope.user.id,
        replay_source: "admin.failures_inbox",
        inserted_at: ~U[2026-05-06 18:12:00Z]
      })

    disabled =
      delivery_fixture(config, disabled_subscription, %{
        delivery_id: "dead_letter_disabled_subscription",
        status: "dead_lettered",
        attempt_count: 3,
        dead_lettered_at: ~U[2026-05-06 18:20:00Z],
        terminal_reason: "subscription_disabled",
        inserted_at: ~U[2026-05-06 18:20:00Z]
      })

    retrying =
      delivery_fixture(config, active_subscription, %{
        delivery_id: "still_retrying",
        status: "retry_scheduled",
        attempt_count: 2,
        next_attempt_at: ~U[2026-05-06 18:30:00Z],
        inserted_at: ~U[2026-05-06 18:30:00Z]
      })

    assert {:ok, {rows, _meta, normalized}} =
             Failures.list_deliveries(config, admin_scope, %{"delivery_state" => "dead_lettered"})

    assert normalized["delivery_state"] == "dead_lettered"

    assert Enum.map(rows, & &1.delivery.delivery_id) == [
             disabled.delivery_id,
             replay_child.delivery_id,
             already_replayed.delivery_id,
             replayable.delivery_id
           ]

    replayable_row = Enum.find(rows, &(&1.delivery.id == replayable.id))
    already_replayed_row = Enum.find(rows, &(&1.delivery.id == already_replayed.id))
    disabled_row = Enum.find(rows, &(&1.delivery.id == disabled.id))
    replay_child_row = Enum.find(rows, &(&1.delivery.id == replay_child.id))

    assert replayable_row.replayable? == true
    assert replayable_row.replay_reason == nil
    assert replayable_row.replay_child_delivery_id == nil

    assert already_replayed_row.replayable? == false
    assert already_replayed_row.replay_reason == :replay_already_exists
    assert already_replayed_row.replay_child_delivery_id == replay_child.delivery_id

    assert disabled_row.replayable? == false
    assert disabled_row.replay_reason == :subscription_disabled
    assert disabled_row.replay_child_delivery_id == nil

    assert replay_child_row.replayable? == false
    assert replay_child_row.replay_reason == :not_dead_lettered
    assert replay_child_row.replay_child_delivery_id == nil

    assert {:ok, {retry_rows, _meta, _normalized}} =
             Failures.list_deliveries(config, admin_scope, %{"delivery_state" => "retrying"})

    assert [
             %{
               delivery: %{id: retrying_id},
               replayable?: false,
               replay_reason: :not_dead_lettered
             }
           ] =
             retry_rows

    assert retrying_id == retrying.id
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

  defp organization_admin_scope do
    %Scope{
      mode: :organization,
      scope: %{user: %{id: Ecto.UUID.generate(), email: "org-admin@example.com"}},
      organization: %{id: Ecto.UUID.generate(), slug: "acme"},
      organization_id: Ecto.UUID.generate(),
      organization_slug: "acme",
      platform_admin?: false,
      admin_org_ids: [Ecto.UUID.generate()]
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
      replayed_from_webhook_delivery_id: Map.get(attrs, :replayed_from_webhook_delivery_id),
      replay_root_webhook_delivery_id: Map.get(attrs, :replay_root_webhook_delivery_id),
      replayed_at: Map.get(attrs, :replayed_at),
      replayed_by_user_id: Map.get(attrs, :replayed_by_user_id),
      replay_source: Map.get(attrs, :replay_source),
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

  defp set_subscription_inserted_at!(subscription, config, inserted_at) do
    from(s in WebhookSubscription, where: s.id == ^subscription.id)
    |> config.repo.update_all(set: [inserted_at: inserted_at, updated_at: inserted_at])

    config.repo.get!(WebhookSubscription, subscription.id)
  end

  defp recreate_tables!(repo) do
    Ecto.Adapters.SQL.query!(repo, ~s|CREATE EXTENSION IF NOT EXISTS "uuid-ossp"|, [])

    for statement <- [
          "DROP TABLE IF EXISTS oban_jobs CASCADE",
          "DROP TABLE IF EXISTS admin_webhooks_delivery_attempts_99 CASCADE",
          "DROP TABLE IF EXISTS admin_webhooks_deliveries_99 CASCADE",
          "DROP TABLE IF EXISTS admin_webhooks_events_99 CASCADE",
          "DROP TABLE IF EXISTS admin_webhooks_subscriptions_99 CASCADE",
          "DROP TABLE IF EXISTS admin_webhooks_users_99 CASCADE",
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
            next_signing_secret bytea,
            rotation_state text NOT NULL DEFAULT 'stable',
            rotation_prepared_at timestamp(6) without time zone,
            rotation_overlap_started_at timestamp(6) without time zone,
            rotation_retire_after_at timestamp(6) without time zone,
            rotation_completed_at timestamp(6) without time zone,
            rotation_last_changed_by_user_id uuid,
            signing_secret_fingerprint text,
            next_signing_secret_fingerprint text,
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
            replayed_from_webhook_delivery_id uuid REFERENCES admin_webhooks_deliveries_99(id),
            replay_root_webhook_delivery_id uuid REFERENCES admin_webhooks_deliveries_99(id),
            replayed_at timestamp(6) without time zone,
            replayed_by_user_id uuid,
            replay_source text,
            webhook_subscription_id uuid NOT NULL REFERENCES admin_webhooks_subscriptions_99(id),
            webhook_event_id uuid NOT NULL REFERENCES admin_webhooks_events_99(id),
            inserted_at timestamp(6) without time zone NOT NULL DEFAULT now(),
            updated_at timestamp(6) without time zone NOT NULL DEFAULT now()
          )
          """,
          "CREATE UNIQUE INDEX admin_webhooks_deliveries_99_delivery_id_index ON admin_webhooks_deliveries_99 (delivery_id)",
          "CREATE INDEX admin_webhooks_deliveries_99_replay_root_index ON admin_webhooks_deliveries_99 (replay_root_webhook_delivery_id)",
          """
          CREATE UNIQUE INDEX admin_webhooks_deliveries_99_replayed_from_unique_index
          ON admin_webhooks_deliveries_99 (replayed_from_webhook_delivery_id)
          WHERE replayed_from_webhook_delivery_id IS NOT NULL
          """,
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
