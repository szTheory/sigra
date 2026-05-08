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

    test "signs one overlap-window request with both the current and next secret" do
      current_secret = "whsec_current_secret"
      next_secret = "whsec_next_secret"

      store_fixture_rows(
        secret: current_secret,
        next_secret: next_secret,
        rotation_state: :overlap_active
      )

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
               Signature.verify(header_map, request.body, current_secret, now: timestamp, tolerance: 0)

      assert {:ok, %{delivery_id: "del_1", timestamp: ^timestamp}} =
               Signature.verify(header_map, request.body, next_secret, now: timestamp, tolerance: 0)

      signatures =
        header_map["Sigra-Webhook-Signature"]
        |> String.split(",")
        |> Enum.map(&String.trim/1)

      assert length(signatures) == 2
      assert Enum.all?(signatures, &String.starts_with?(&1, "v1="))
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

    test "dead-letters a retryable failure when the retry budget is exhausted" do
      store_fixture_rows(attempt_count: 5, next_attempt_at: DateTime.utc_now() |> DateTime.truncate(:second))

      Application.put_env(:sigra, :webhook_delivery_requester, fn _request ->
        {:ok, %{status: 503}}
      end)

      assert {:ok, :dead_lettered} =
               WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => "del_1"}})

      assert %Delivery{
               status: "dead_lettered",
               attempt_count: 6,
               dead_lettered_at: %DateTime{},
               terminal_reason: "retry_budget_exhausted",
               next_attempt_at: nil
             } = Process.get({:delivery, "del_1"})

      assert attempts = Process.get({:attempts, "del_1"})
      assert List.last(attempts).terminal_reason == "retry_budget_exhausted"
      assert List.last(attempts).retryable == false
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

    test "blocks denied destinations before requester execution" do
      resolver = fn
        "private.example.test" -> {:ok, [{10, 0, 0, 8}]}
        "metadata.example.test" -> {:ok, [{169, 254, 169, 254}]}
        "mixed.example.test" -> {:ok, [{203, 0, 113, 8}, {10, 0, 0, 2}]}
        "ipv6-link-local.example.test" -> {:ok, [{0xFE80, 0, 0, 0, 0, 0, 0, 1}]}
      end

      Application.put_env(:sigra, :webhooks, webhooks_config(endpoint_resolver: resolver))
      Application.put_env(:sigra, :webhook_delivery_requester, fn request ->
        send(self(), {:webhook_request, request})
        {:ok, %{status: 202}}
      end)

      for {delivery_id, endpoint_url, terminal_reason} <- [
            {"del_private", "https://private.example.test/hooks", "blocked_private_ip"},
            {"del_metadata", "https://metadata.example.test/hooks", "blocked_metadata_ip"},
            {"del_mixed", "https://mixed.example.test/hooks", "blocked_private_ip"},
            {"del_ipv6", "https://ipv6-link-local.example.test/hooks", "blocked_link_local_ip"}
          ] do
        store_fixture_rows(delivery_id: delivery_id, endpoint_url: endpoint_url)

        assert {:ok, :dead_lettered} =
                 WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => delivery_id}})

        assert %Delivery{
                 status: "dead_lettered",
                 last_error_category: "local_policy_error",
                 terminal_reason: ^terminal_reason
               } = Process.get({:delivery, delivery_id})

        assert [attempt] = Process.get({:attempts, delivery_id})
        assert attempt.retryable == false
        assert attempt.error_category == "local_policy_error"
        assert attempt.terminal_reason == terminal_reason
        refute_received {:webhook_request, _request}
      end
    end

    test "persists callback denials as local policy errors and still allows public https delivery" do
      policy = fn
        %{uri: %URI{host: "callback.example.test"}} ->
          {:error, :policy_denied, "blocked by deployment callback"}

        _context ->
          :ok
      end

      Application.put_env(:sigra, :webhooks, webhooks_config(endpoint_policy: policy))
      Application.put_env(:sigra, :webhook_delivery_requester, fn request ->
        send(self(), {:webhook_request, request})
        {:ok, %{status: 202}}
      end)

      store_fixture_rows(delivery_id: "del_policy", endpoint_url: "https://callback.example.test/hooks")

      assert {:ok, :dead_lettered} =
               WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => "del_policy"}})

      assert %Delivery{
               status: "dead_lettered",
               last_error_category: "local_policy_error",
               terminal_reason: "policy_denied",
               last_error_detail: "blocked by deployment callback"
             } = Process.get({:delivery, "del_policy"})

      refute_received {:webhook_request, _request}

      store_fixture_rows(delivery_id: "del_public", endpoint_url: "https://hooks.example.test/inbound")

      assert {:ok, :delivered} =
               WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => "del_public"}})

      assert_receive {:webhook_request, request}
      assert request.url == "https://hooks.example.test/inbound"
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

    test "processes a replay child as a fresh first attempt without mutating the source ledger" do
      secret = "whsec_phase104"
      store_fixture_rows(secret: secret)

      source = Process.get({:delivery, "del_1"})

      replay_child =
        %Delivery{
          id: "del_row_2",
          delivery_id: "del_replay_1",
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

      Process.put({:delivery, replay_child.delivery_id}, replay_child)
      Process.put({:attempts, replay_child.delivery_id}, [])
      Process.put({:attempts, source.delivery_id}, [
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
          terminal_reason: "http_4xx_permanent",
          webhook_delivery_id: source.id
        }
      ])

      Application.put_env(:sigra, :webhook_delivery_requester, fn _request ->
        {:ok, %{status: 202}}
      end)

      assert {:ok, :delivered} =
               WebhookDelivery.perform(%Oban.Job{args: %{"delivery_id" => replay_child.delivery_id}})

      assert %Delivery{attempt_count: 0} = Process.get({:delivery, "del_1"})
      assert [%DeliveryAttempt{attempt_number: 1}] = Process.get({:attempts, "del_1"})
      assert [%DeliveryAttempt{attempt_number: 1, delivery_id: "del_replay_1"}] =
               Process.get({:attempts, "del_replay_1"})
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

  defp store_fixture_rows(opts \\ []) do
    delivery =
      %Delivery{
        id: Keyword.get(opts, :delivery_row_id, "del_row_1"),
        delivery_id: Keyword.get(opts, :delivery_id, "del_1"),
        status: "pending",
        attempt_count: Keyword.get(opts, :attempt_count, 0),
        endpoint_url: Keyword.get(opts, :endpoint_url, "https://hooks.example.test/inbound"),
        next_attempt_at: Keyword.get(opts, :next_attempt_at),
        webhook_subscription_id: "sub_1",
        webhook_event_id: "evt_row_1"
      }

    subscription =
      %Subscription{
        id: "sub_1",
        endpoint_url: Keyword.get(opts, :endpoint_url, "https://hooks.example.test/inbound"),
        enabled: Keyword.get(opts, :enabled, true),
        signing_secret: Keyword.get(opts, :secret, "whsec_phase98"),
        next_signing_secret: Keyword.get(opts, :next_secret),
        rotation_state: Keyword.get(opts, :rotation_state, :stable)
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

  defp public_test_resolver(host) do
    case host do
      "hooks.example.test" -> {:ok, [{203, 0, 113, 20}]}
      "callback.example.test" -> {:ok, [{203, 0, 113, 21}]}
      _other -> {:error, :nxdomain}
    end
  end
end
