defmodule Sigra.WebhooksEgressPolicyProofTest do
  use ExUnit.Case, async: false

  alias Ecto.{Changeset, Multi}
  alias Sigra.Workers.WebhookDelivery

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
      field :next_signing_secret, :string
      field :rotation_state, Ecto.Enum,
        values: [:stable, :prepared, :overlap_active, :completed],
        default: :stable
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:endpoint_url, :enabled, :signing_secret, :next_signing_secret, :rotation_state])
      |> validate_required([:endpoint_url, :enabled, :signing_secret])
    end
  end

  defmodule Event do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "webhook_events" do
      field :payload, :map, default: %{}
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
      |> validate_required([:delivery_id, :attempt_number, :endpoint_url, :started_at, :retryable])
    end
  end

  defmodule MockRepo do
    def get_by(Delivery, delivery_id: delivery_id), do: Process.get({:delivery, delivery_id})
    def get(Subscription, id), do: Process.get({:subscription, id})
    def get(Event, id), do: Process.get({:event, id})

    def insert(%Changeset{} = changeset) do
      struct = Changeset.apply_changes(changeset)
      struct = Map.put_new(struct, :id, Ecto.UUID.generate())

      case struct do
        %DeliveryAttempt{} = attempt ->
          attempts = Process.get({:attempts, attempt.delivery_id}, [])
          Process.put({:attempts, attempt.delivery_id}, attempts ++ [attempt])
          {:ok, attempt}

        other ->
          {:ok, other}
      end
    end

    def update(%Changeset{} = changeset) do
      delivery = Changeset.apply_changes(changeset)
      Process.put({:delivery, delivery.delivery_id}, delivery)
      {:ok, delivery}
    end

    def transaction(%Multi{} = multi) do
      Enum.reduce_while(Multi.to_list(multi), {:ok, %{}}, fn
        {name, {:insert, changeset, _opts}}, {:ok, acc} ->
          {:ok, value} = insert(changeset)
          {:cont, {:ok, Map.put(acc, name, value)}}

        {name, {:update, changeset, _opts}}, {:ok, acc} ->
          {:ok, value} = update(changeset)
          {:cont, {:ok, Map.put(acc, name, value)}}
      end)
    end
  end

  setup do
    Application.put_env(:sigra, :repo, MockRepo)
    Application.put_env(:sigra, :user_schema, MockUser)
    Application.put_env(:sigra, :webhooks, webhooks_config())
    Application.put_env(:sigra, :webhook_delivery_oban, fn _changeset -> {:ok, %{}} end)

    on_exit(fn ->
      Application.delete_env(:sigra, :repo)
      Application.delete_env(:sigra, :user_schema)
      Application.delete_env(:sigra, :webhooks)
      Application.delete_env(:sigra, :webhook_delivery_requester)
      Application.delete_env(:sigra, :webhook_delivery_oban)
    end)

    :ok
  end

  test "allowed public https delivery still sends" do
    store_fixture_rows(delivery_id: "del_public", endpoint_url: "https://hooks.example.test/inbound")

    Application.put_env(:sigra, :webhook_delivery_requester, fn request ->
      send(self(), {:webhook_request, request})
      {:ok, %{status: 202}}
    end)

    assert {:ok, :delivered} =
             WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => "del_public"}})

    assert_receive {:webhook_request, request}
    assert request.url == "https://hooks.example.test/inbound"
  end

  test "blocked metadata destination fails locally before any requester call" do
    resolver = fn
      "metadata.example.test" -> {:ok, [{169, 254, 169, 254}]}
      host -> public_test_resolver(host)
    end

    Application.put_env(:sigra, :webhooks, webhooks_config(endpoint_resolver: resolver))
    store_fixture_rows(delivery_id: "del_metadata", endpoint_url: "https://metadata.example.test/inbound")

    Application.put_env(:sigra, :webhook_delivery_requester, fn request ->
      send(self(), {:webhook_request, request})
      {:ok, %{status: 202}}
    end)

    assert {:ok, :dead_lettered} =
             WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => "del_metadata"}})

    assert %Delivery{
             last_error_category: "local_policy_error",
             terminal_reason: "blocked_metadata_ip"
           } = Process.get({:delivery, "del_metadata"})

    assert [attempt] = Process.get({:attempts, "del_metadata"})
    assert attempt.error_category == "local_policy_error"
    assert attempt.terminal_reason == "blocked_metadata_ip"
    refute_receive {:webhook_request, _request}
  end

  test "host callback denial persists local_policy_error and blocks delivery" do
    policy = fn
      %{uri: %URI{host: "callback.example.test"}} ->
        {:error, :policy_denied, "blocked delivery by deployment callback"}

      _context ->
        :ok
    end

    Application.put_env(:sigra, :webhooks, webhooks_config(endpoint_policy: policy))
    store_fixture_rows(delivery_id: "del_callback", endpoint_url: "https://callback.example.test/inbound")

    Application.put_env(:sigra, :webhook_delivery_requester, fn request ->
      send(self(), {:webhook_request, request})
      {:ok, %{status: 202}}
    end)

    assert {:ok, :dead_lettered} =
             WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => "del_callback"}})

    assert %Delivery{
             last_error_category: "local_policy_error",
             last_error_detail: "blocked delivery by deployment callback",
             terminal_reason: "policy_denied"
           } = Process.get({:delivery, "del_callback"})

    refute_receive {:webhook_request, _request}
  end

  defp webhooks_config(overrides \\ []) do
    Keyword.merge(
      [
        enabled: true,
        webhook_subscription_schema: Subscription,
        webhook_event_schema: Event,
        webhook_delivery_schema: Delivery,
        webhook_delivery_attempt_schema: DeliveryAttempt,
        endpoint_resolver: &public_test_resolver/1,
        oban_queue: "sigra_webhooks"
      ],
      overrides
    )
  end

  defp store_fixture_rows(opts) do
    delivery_id = Keyword.fetch!(opts, :delivery_id)
    endpoint_url = Keyword.fetch!(opts, :endpoint_url)

    delivery =
      %Delivery{
        id: "#{delivery_id}_row",
        delivery_id: delivery_id,
        status: "pending",
        attempt_count: 0,
        endpoint_url: endpoint_url,
        webhook_subscription_id: "sub_1",
        webhook_event_id: "evt_row_1"
      }

    subscription =
      %Subscription{
        id: "sub_1",
        endpoint_url: endpoint_url,
        enabled: true,
        signing_secret: "whsec_phase105",
        rotation_state: :stable
      }

    event =
      %Event{
        id: "evt_row_1",
        payload: %{"id" => "evt_1", "type" => "user.created", "data" => %{"object" => %{"id" => "user_1"}}}
      }

    Process.put({:delivery, delivery.delivery_id}, delivery)
    Process.put({:subscription, subscription.id}, subscription)
    Process.put({:event, event.id}, event)
    Process.put({:attempts, delivery.delivery_id}, [])
  end

  defp public_test_resolver(host) do
    case host do
      "hooks.example.test" -> {:ok, [{203, 0, 113, 20}]}
      "callback.example.test" -> {:ok, [{203, 0, 113, 21}]}
      _other -> {:error, :nxdomain}
    end
  end
end
