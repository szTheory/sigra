defmodule Sigra.WebhooksReplayTest do
  use ExUnit.Case, async: false

  alias Ecto.{Changeset, Multi}
  alias Sigra.Webhooks

  defmodule MockUser do
    defstruct [:id]
  end

  defmodule Subscription do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "webhook_subscriptions" do
      field :endpoint_url, :string
      field :enabled, :boolean, default: true
      field :signing_secret, :string
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:endpoint_url, :enabled, :signing_secret])
      |> validate_required([:endpoint_url, :enabled, :signing_secret])
    end
  end

  defmodule Event do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "webhook_events" do
      field :payload, :map, default: %{}
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:payload])
      |> validate_required([:payload])
    end
  end

  defmodule Delivery do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "webhook_deliveries" do
      field :delivery_id, :string
      field :status, :string, default: "pending"
      field :attempt_count, :integer, default: 0
      field :endpoint_url, :string
      field :dispatched_at, :utc_datetime
      field :last_attempted_at, :utc_datetime
      field :next_attempt_at, :utc_datetime
      field :last_http_status, :integer
      field :last_error_category, :string
      field :last_error_detail, :string
      field :dead_lettered_at, :utc_datetime
      field :terminal_reason, :string
      field :replayed_from_webhook_delivery_id, :binary_id
      field :replay_root_webhook_delivery_id, :binary_id
      field :replayed_at, :utc_datetime
      field :replayed_by_user_id, :binary_id
      field :replay_source, :string
      field :webhook_subscription_id, :binary_id
      field :webhook_event_id, :binary_id
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
      |> unique_constraint(:delivery_id)
      |> unique_constraint(:replayed_from_webhook_delivery_id,
        name: :webhook_deliveries_replayed_from_unique_index
      )
    end
  end

  defmodule DeliveryAttempt do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "webhook_delivery_attempts" do
      field :delivery_id, :string
      field :attempt_number, :integer
      field :endpoint_url, :string
      field :started_at, :utc_datetime
      field :finished_at, :utc_datetime
      field :response_status, :integer
      field :retryable, :boolean, default: false
      field :retry_after_seconds, :integer
      field :error_category, :string
      field :error_detail, :string
      field :terminal_reason, :string
      field :webhook_delivery_id, :binary_id
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
    end
  end

  defmodule MockRepo do
    def get_by(Delivery, delivery_id: delivery_id), do: deliveries() |> Map.get(delivery_id)

    def get_by(Delivery, replayed_from_webhook_delivery_id: source_id) do
      deliveries()
      |> Map.values()
      |> Enum.find(&(&1.replayed_from_webhook_delivery_id == source_id))
    end

    def get(Subscription, id), do: Process.get({:subscription, id})
    def get(Event, id), do: Process.get({:event, id})

    def insert(%Changeset{} = changeset) do
      struct = Changeset.apply_changes(changeset)
      struct = Map.put_new(struct, :id, Ecto.UUID.generate())

      case struct do
        %Delivery{} = delivery ->
          insert_delivery(changeset, delivery)

        %DeliveryAttempt{} = attempt ->
          attempts = Process.get({:attempts, attempt.delivery_id}, [])
          Process.put({:attempts, attempt.delivery_id}, attempts ++ [attempt])
          {:ok, attempt}

        job ->
          jobs = Process.get(:queued_jobs, [])
          Process.put(:queued_jobs, jobs ++ [job])
          {:ok, job}
      end
    end

    def insert(%Changeset{} = changeset, _opts), do: insert(changeset)

    def update(%Changeset{} = changeset) do
      delivery = Changeset.apply_changes(changeset)
      Process.put({:delivery, delivery.delivery_id}, delivery)
      Process.put(:deliveries, Map.put(deliveries(), delivery.delivery_id, delivery))
      {:ok, delivery}
    end

    def transaction(%Multi{} = multi) do
      Enum.reduce_while(Multi.to_list(multi), {:ok, %{}}, fn
        {name, {:run, run}}, {:ok, acc} ->
          case run.(__MODULE__, acc) do
            {:ok, value} -> {:cont, {:ok, Map.put(acc, name, value)}}
            {:error, reason} -> {:halt, {:error, name, reason, acc}}
          end

        {name, {:insert, %Changeset{} = changeset, _opts}}, {:ok, acc} ->
          case insert(changeset) do
            {:ok, value} -> {:cont, {:ok, Map.put(acc, name, value)}}
            {:error, reason} -> {:halt, {:error, name, reason, acc}}
          end

        {name, {:insert, fun, _opts}}, {:ok, acc} when is_function(fun, 1) ->
          case insert(fun.(acc)) do
            {:ok, value} -> {:cont, {:ok, Map.put(acc, name, value)}}
            {:error, reason} -> {:halt, {:error, name, reason, acc}}
          end

        {name, {:update, %Changeset{} = changeset, _opts}}, {:ok, acc} ->
          case update(changeset) do
            {:ok, value} -> {:cont, {:ok, Map.put(acc, name, value)}}
            {:error, reason} -> {:halt, {:error, name, reason, acc}}
          end
      end)
    end

    defp insert_delivery(changeset, delivery) do
      deliveries = deliveries()

      cond do
        Map.has_key?(deliveries, delivery.delivery_id) ->
          {:error, Changeset.add_error(changeset, :delivery_id, "has already been taken")}

        delivery.replayed_from_webhook_delivery_id &&
            Enum.any?(
              Map.values(deliveries),
              &(&1.replayed_from_webhook_delivery_id == delivery.replayed_from_webhook_delivery_id)
            ) ->
          {:error,
           Changeset.add_error(
             changeset,
             :replayed_from_webhook_delivery_id,
             "has already been taken"
           )}

        true ->
          Process.put({:delivery, delivery.delivery_id}, delivery)
          Process.put(:deliveries, Map.put(deliveries, delivery.delivery_id, delivery))

          Process.put(
            {:attempts, delivery.delivery_id},
            Process.get({:attempts, delivery.delivery_id}, [])
          )

          {:ok, delivery}
      end
    end

    defp deliveries do
      Process.get(:deliveries, %{})
    end
  end

  setup do
    Application.put_env(:sigra, :repo, MockRepo)
    Application.put_env(:sigra, :user_schema, MockUser)
    Application.put_env(:sigra, :webhooks, webhooks_config())
    Process.put(:queued_jobs, [])
    Process.put(:deliveries, %{})

    on_exit(fn ->
      Application.delete_env(:sigra, :repo)
      Application.delete_env(:sigra, :user_schema)
      Application.delete_env(:sigra, :webhooks)
      Process.delete(:queued_jobs)
      Process.delete(:deliveries)
    end)

    :ok
  end

  describe "replay_delivery/4" do
    test "creates a replay child with fresh lineage and leaves the source immutable" do
      source = store_source_delivery()
      actor_id = Ecto.UUID.generate()

      assert {:ok, %{source_delivery: source_delivery, replay_delivery: replay_delivery}} =
               Webhooks.replay_delivery(
                 config(),
                 source.delivery_id,
                 %{user: %{id: actor_id}},
                 source: "admin.delivery_detail"
               )

      assert source_delivery.delivery_id == source.delivery_id
      assert source_delivery.status == "dead_lettered"
      assert source_delivery.attempt_count == 1
      assert source_delivery.delivery_id != replay_delivery.delivery_id
      assert replay_delivery.status == "pending"
      assert replay_delivery.attempt_count == 0
      assert replay_delivery.replayed_from_webhook_delivery_id == source.id
      assert replay_delivery.replay_root_webhook_delivery_id == source.id
      assert replay_delivery.replayed_by_user_id == actor_id
      assert replay_delivery.replay_source == "admin.delivery_detail"
      assert %DateTime{} = replay_delivery.replayed_at
      assert [] = Process.get({:attempts, replay_delivery.delivery_id})
      assert [job] = Process.get(:queued_jobs)
      assert job.args == %{"delivery_id" => replay_delivery.delivery_id}
    end

    test "rejects pending, retry_scheduled, and delivered source rows" do
      for status <- ~w[pending retry_scheduled delivered] do
        source =
          store_source_delivery(status: status, dead_lettered_at: nil, terminal_reason: nil)

        assert {:error, :not_dead_lettered} =
                 Webhooks.replay_delivery(
                   config(),
                   source.delivery_id,
                   %{user: %{id: Ecto.UUID.generate()}},
                   source: "admin.delivery_detail"
                 )
      end
    end

    test "rejects a source delivery that already has a replay child" do
      source = store_source_delivery()
      store_replay_child(source)

      assert {:error, :replay_already_exists} =
               Webhooks.replay_delivery(
                 config(),
                 source.delivery_id,
                 %{user: %{id: Ecto.UUID.generate()}},
                 source: "admin.delivery_detail"
               )
    end

    test "rejects truth-gap context failures and disabled runtime preconditions" do
      dependency_gap = store_source_delivery(terminal_reason: "delivery_dependency_missing")

      assert {:error, :delivery_context_incomplete} =
               Webhooks.replay_delivery(
                 config(),
                 dependency_gap.delivery_id,
                 %{user: %{id: Ecto.UUID.generate()}},
                 source: "admin.delivery_detail"
               )

      disabled_subscription =
        store_source_delivery(
          subscription_enabled: false,
          terminal_reason: "subscription_disabled"
        )

      assert {:error, :subscription_disabled} =
               Webhooks.replay_delivery(
                 config(),
                 disabled_subscription.delivery_id,
                 %{user: %{id: Ecto.UUID.generate()}},
                 source: "admin.delivery_detail"
               )

      Application.put_env(:sigra, :webhooks, Keyword.put(webhooks_config(), :enabled, false))

      assert {:error, :webhooks_disabled} =
               Webhooks.replay_delivery(
                 config(),
                 dependency_gap.delivery_id,
                 %{user: %{id: Ecto.UUID.generate()}},
                 source: "admin.delivery_detail"
               )
    end
  end

  defp config do
    Sigra.Config.new!(
      repo: MockRepo,
      user_schema: MockUser,
      webhooks: Application.fetch_env!(:sigra, :webhooks)
    )
  end

  defp webhooks_config do
    [
      enabled: true,
      webhook_subscription_schema: Subscription,
      webhook_event_schema: Event,
      webhook_delivery_schema: Delivery,
      webhook_delivery_attempt_schema: DeliveryAttempt,
      oban_queue: "sigra_webhooks"
    ]
  end

  defp store_source_delivery(opts \\ []) do
    subscription =
      %Subscription{
        id: Keyword.get(opts, :subscription_id, "sub_1"),
        endpoint_url: "https://hooks.example.test/inbound",
        enabled: Keyword.get(opts, :subscription_enabled, true),
        signing_secret: "whsec_phase104"
      }

    event =
      %Event{
        id: Keyword.get(opts, :event_id, "evt_row_1"),
        payload: %{
          "id" => "evt_1",
          "type" => "user.created",
          "data" => %{"object" => %{"id" => "user_1"}}
        }
      }

    source =
      %Delivery{
        id: Keyword.get(opts, :id, "del_row_1"),
        delivery_id: Keyword.get(opts, :delivery_id, "del_1"),
        status: Keyword.get(opts, :status, "dead_lettered"),
        attempt_count: Keyword.get(opts, :attempt_count, 1),
        endpoint_url: subscription.endpoint_url,
        last_attempted_at: DateTime.utc_now() |> DateTime.truncate(:second),
        last_http_status: Keyword.get(opts, :last_http_status, 404),
        last_error_category: Keyword.get(opts, :last_error_category, "http_client_error"),
        last_error_detail: Keyword.get(opts, :last_error_detail, "receiver rejected request"),
        dead_lettered_at:
          Keyword.get(opts, :dead_lettered_at, DateTime.utc_now() |> DateTime.truncate(:second)),
        terminal_reason: Keyword.get(opts, :terminal_reason, "http_4xx_permanent"),
        webhook_subscription_id: subscription.id,
        webhook_event_id: event.id
      }

    Process.put({:subscription, subscription.id}, subscription)
    Process.put({:event, event.id}, event)
    Process.put(:deliveries, %{source.delivery_id => source})
    Process.put({:delivery, source.delivery_id}, source)

    Process.put(
      {:attempts, source.delivery_id},
      [
        %DeliveryAttempt{
          id: "attempt_row_1",
          delivery_id: source.delivery_id,
          attempt_number: 1,
          endpoint_url: source.endpoint_url,
          started_at: DateTime.utc_now() |> DateTime.truncate(:second),
          finished_at: DateTime.utc_now() |> DateTime.truncate(:second),
          response_status: 404,
          retryable: false,
          error_category: "http_client_error",
          error_detail: "receiver rejected request",
          terminal_reason: source.terminal_reason,
          webhook_delivery_id: source.id
        }
      ]
    )

    source
  end

  defp store_replay_child(source) do
    replay =
      %Delivery{
        id: "del_row_2",
        delivery_id: "del_2",
        status: "pending",
        attempt_count: 0,
        endpoint_url: source.endpoint_url,
        replayed_from_webhook_delivery_id: source.id,
        replay_root_webhook_delivery_id: source.id,
        replayed_at: DateTime.utc_now() |> DateTime.truncate(:second),
        replayed_by_user_id: Ecto.UUID.generate(),
        replay_source: "admin.delivery_detail",
        webhook_subscription_id: source.webhook_subscription_id,
        webhook_event_id: source.webhook_event_id
      }

    Process.put(:deliveries, %{
      source.delivery_id => source,
      replay.delivery_id => replay
    })

    Process.put({:delivery, replay.delivery_id}, replay)
    Process.put({:attempts, replay.delivery_id}, [])
    replay
  end
end
