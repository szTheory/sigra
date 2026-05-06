defmodule Sigra.Workers.WebhookDeliveryTest do
  use ExUnit.Case, async: false

  alias Ecto.{Changeset, Multi}
  alias Sigra.OptionalDeps.MissingDependencyError
  alias Sigra.Webhooks
  alias Sigra.Webhooks.Signature
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
          case insert(changeset) do
            {:ok, value} -> {:cont, {:ok, Map.put(acc, name, value)}}
            {:error, reason} -> {:halt, {:error, name, reason, acc}}
          end

        {name, {:update, changeset, _opts}}, {:ok, acc} ->
          case update(changeset) do
            {:ok, value} -> {:cont, {:ok, Map.put(acc, name, value)}}
            {:error, reason} -> {:halt, {:error, name, reason, acc}}
          end
      end)
    end
  end

  defmodule MockOban do
    def insert(%Changeset{} = changeset) do
      job = %{
        args: Changeset.get_change(changeset, :args),
        queue: Changeset.get_change(changeset, :queue)
      }

      jobs = Process.get(:queued_jobs, [])
      Process.put(:queued_jobs, jobs ++ [job])
      {:ok, job}
    end
  end

  setup do
    Application.put_env(:sigra, :repo, MockRepo)
    Application.put_env(:sigra, :user_schema, MockUser)
    Application.put_env(:sigra, :webhooks, webhooks_config())
    Application.put_env(:sigra, :webhook_delivery_oban, MockOban)
    Process.put(:queued_jobs, [])

    on_exit(fn ->
      Application.delete_env(:sigra, :repo)
      Application.delete_env(:sigra, :user_schema)
      Application.delete_env(:sigra, :webhooks)
      Application.delete_env(:sigra, :webhook_delivery_requester)
      Application.delete_env(:sigra, :webhook_delivery_oban)

      for key <- [
            {:delivery, "del_1"},
            {:delivery, "del_missing"},
            {:subscription, "sub_1"},
            {:event, "evt_row_1"},
            {:attempts, "del_1"},
            {:attempts, "del_missing"}
          ] do
        Process.delete(key)
      end

      Process.delete(:queued_jobs)
    end)

    :ok
  end

  describe "enqueue helpers" do
    test "new/2 hard-fails when webhook delivery is enabled but Oban is unavailable" do
      assert_raise MissingDependencyError, fn ->
        WebhookDelivery.new(%{"delivery_id" => "del_1"},
          webhooks: [enabled: true],
          dependency_loaded?: fn _spec -> false end
        )
      end
    end

    test "enqueue_delivery/3 stores only the delivery_id and uses the configured webhook queue" do
      delivery = %Delivery{delivery_id: "del_1"}

      assert {:ok, %{args: %{"delivery_id" => "del_1"}, queue: "sigra_webhooks"}} =
               Webhooks.enqueue_delivery(config(), delivery, oban: MockOban)
    end
  end

  describe "perform/1" do
    test "records a delivered attempt after a 2xx response" do
      secret = "whsec_phase98"
      store_fixture_rows(secret: secret)

      Application.put_env(:sigra, :webhook_delivery_requester, fn request ->
        send(self(), {:webhook_request, request})
        {:ok, %{status: 202}}
      end)

      assert {:ok, :delivered} =
               WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => "del_1"}})

      assert_receive {:webhook_request, request}

      header_map = Map.new(request.headers)
      timestamp = String.to_integer(header_map["Sigra-Webhook-Timestamp"])

      assert {:ok, %{delivery_id: "del_1", timestamp: ^timestamp}} =
               Signature.verify(header_map, request.body, secret, now: timestamp, tolerance: 0)

      assert %Delivery{status: "delivered", attempt_count: 1, last_http_status: 202} =
               Process.get({:delivery, "del_1"})

      assert [attempt] = Process.get({:attempts, "del_1"})
      assert attempt.attempt_number == 1
      assert attempt.response_status == 202
      assert attempt.retryable == false
    end

    test "schedules exactly one follow-up attempt for retryable 429 responses and honors Retry-After" do
      store_fixture_rows()

      Application.put_env(:sigra, :webhook_delivery_requester, fn _request ->
        {:ok, %{status: 429, headers: [{"Retry-After", "120"}]}}
      end)

      assert {:ok, :retry_scheduled} =
               WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => "del_1"}})

      assert %Delivery{
               status: "retry_scheduled",
               attempt_count: 1,
               last_http_status: 429,
               last_error_category: "http_backpressure",
               next_attempt_at: %DateTime{},
               terminal_reason: nil
             } = Process.get({:delivery, "del_1"})

      assert [attempt] = Process.get({:attempts, "del_1"})
      assert attempt.retryable == true
      assert attempt.retry_after_seconds == 120
      assert attempt.terminal_reason == nil
      assert [%{args: %{"delivery_id" => "del_1"}}] = Process.get(:queued_jobs)
    end

    test "dead-letters permanent 4xx responses without scheduling another job" do
      store_fixture_rows()

      Application.put_env(:sigra, :webhook_delivery_requester, fn _request ->
        {:ok, %{status: 404}}
      end)

      assert {:ok, :dead_lettered} =
               WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => "del_1"}})

      assert %Delivery{
               status: "dead_lettered",
               attempt_count: 1,
               dead_lettered_at: %DateTime{},
               terminal_reason: "http_4xx_permanent"
             } = Process.get({:delivery, "del_1"})

      assert [attempt] = Process.get({:attempts, "del_1"})
      assert attempt.retryable == false
      assert attempt.response_status == 404
      assert attempt.terminal_reason == "http_4xx_permanent"
      assert [] = Process.get(:queued_jobs)
    end

    test "persists a terminal local failure when the subscription was disabled before execution" do
      store_fixture_rows(enabled: false)

      assert {:ok, :dead_lettered} =
               WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => "del_1"}})

      assert %Delivery{status: "dead_lettered", terminal_reason: "subscription_disabled"} =
               Process.get({:delivery, "del_1"})

      assert [attempt] = Process.get({:attempts, "del_1"})
      assert attempt.retryable == false
      assert attempt.terminal_reason == "subscription_disabled"
    end

    test "persists an orphan terminal issue when the parent delivery row is missing" do
      assert {:ok, :dead_lettered} =
               WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => "del_missing"}})

      assert [attempt] = Process.get({:attempts, "del_missing"})
      assert attempt.delivery_id == "del_missing"
      assert attempt.retryable == false
      assert attempt.terminal_reason == "delivery_dependency_missing"
      assert attempt.webhook_delivery_id == nil
    end
  end

  describe "module configuration" do
    test "uses the dedicated webhook queue and stays single-shot" do
      source = File.read!("lib/sigra/workers/webhook_delivery.ex")
      assert source =~ "queue: :sigra_webhooks"
      assert source =~ "max_attempts: 1"
    end
  end

  defp config do
    Sigra.Config.new!(
      repo: MockRepo,
      user_schema: MockUser,
      webhooks: webhooks_config()
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

  defp store_fixture_rows(opts \\ []) do
    delivery =
      %Delivery{
        id: "del_row_1",
        delivery_id: "del_1",
        status: "pending",
        attempt_count: 0,
        endpoint_url: "https://hooks.example.test/inbound",
        webhook_subscription_id: "sub_1",
        webhook_event_id: "evt_row_1"
      }

    subscription =
      %Subscription{
        id: "sub_1",
        endpoint_url: "https://hooks.example.test/inbound",
        enabled: Keyword.get(opts, :enabled, true),
        signing_secret: Keyword.get(opts, :secret, "whsec_phase98")
      }

    event =
      %Event{
        id: "evt_row_1",
        payload: %{
          "id" => "evt_1",
          "type" => "user.created",
          "data" => %{"object" => %{"id" => "user_1", "email" => "user@example.com"}}
        }
      }

    Process.put({:delivery, delivery.delivery_id}, delivery)
    Process.put({:subscription, subscription.id}, subscription)
    Process.put({:event, event.id}, event)
    Process.put({:attempts, delivery.delivery_id}, [])
  end
end
