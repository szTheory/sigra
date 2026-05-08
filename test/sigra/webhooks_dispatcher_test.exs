defmodule Sigra.WebhooksDispatcherTest do
  use ExUnit.Case, async: true

  alias Ecto.Changeset
  alias Ecto.Multi
  alias Sigra.Webhooks
  alias Sigra.Webhooks.Dispatcher

  defmodule Subscription do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "webhook_subscriptions" do
      field :endpoint_url, :string
      field :event_types, {:array, :string}, default: []
      field :enabled, :boolean, default: true
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:id, :endpoint_url, :event_types, :enabled])
      |> validate_required([:endpoint_url, :event_types, :enabled])
    end
  end

  defmodule Event do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "webhook_events" do
      field :event_id, :string
      field :type, :string
      field :schema_version, :string
      field :occurred_at, :utc_datetime
      field :payload, :map
      field :actor_id, :binary_id
      field :actor_type, :string
      field :organization_id, :binary_id
      field :request_id, :string
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
    end
  end

  defmodule Delivery do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "webhook_deliveries" do
      field :delivery_id, :string
      field :status, :string
      field :endpoint_url, :string
      field :webhook_subscription_id, :binary_id
      field :webhook_event_id, :binary_id
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [
        :delivery_id,
        :status,
        :endpoint_url,
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
    end
  end

  defmodule User do
    defstruct [:id, :email, :display_name, :confirmed_at, :inserted_at, :updated_at]
  end

  defmodule UserRecord do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "users" do
      field :email, :string
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:id, :email])
      |> validate_required([:id, :email])
    end
  end

  defmodule MockRepo do
    def all(_schema), do: Process.get(:dispatcher_subscriptions, [])

    def insert(changeset) do
      if changeset.valid? do
        struct =
          changeset
          |> Changeset.apply_changes()
          |> ensure_id()

        store_insert(struct)
        {:ok, struct}
      else
        {:error, changeset}
      end
    end

    def transaction(%Multi{} = multi), do: Sigra.Test.MultiStub.run(__MODULE__, multi)

    defp store_insert(%Event{} = event) do
      Process.put(:dispatcher_events, [event | Process.get(:dispatcher_events, [])])
    end

    defp store_insert(%Delivery{} = delivery) do
      Process.put(:dispatcher_deliveries, [delivery | Process.get(:dispatcher_deliveries, [])])
    end

    defp store_insert(%Oban.Job{} = job) do
      Process.put(:dispatcher_jobs, [job | Process.get(:dispatcher_jobs, [])])
    end

    defp store_insert(%UserRecord{}), do: :ok
    defp store_insert(_struct), do: :ok

    defp ensure_id(%{id: nil} = struct), do: %{struct | id: "id-#{System.unique_integer([:positive])}"}
    defp ensure_id(struct), do: struct
  end

  setup do
    Process.put(:dispatcher_subscriptions, [])
    Process.put(:dispatcher_events, [])
    Process.put(:dispatcher_deliveries, [])
    Process.put(:dispatcher_jobs, [])

    on_exit(fn ->
      Process.delete(:dispatcher_subscriptions)
      Process.delete(:dispatcher_events)
      Process.delete(:dispatcher_deliveries)
      Process.delete(:dispatcher_jobs)
    end)

    :ok
  end

  defp config(overrides \\ []) do
    defaults = [
      repo: MockRepo,
      user_schema: Sigra.TestUser,
      secret_key_base: String.duplicate("a", 64),
      webhooks: [
        enabled: true,
        webhook_subscription_schema: Subscription,
        webhook_event_schema: Event,
        webhook_delivery_schema: Delivery
      ]
    ]

    Sigra.Config.new!(Keyword.merge(defaults, overrides))
  end

  test "matching_subscriptions/2 only returns enabled subscriptions with explicit event matches" do
    Process.put(:dispatcher_subscriptions, [
      %Subscription{id: "sub-1", enabled: true, event_types: ["user.created"], endpoint_url: "https://one.test"},
      %Subscription{id: "sub-2", enabled: true, event_types: ["session.created"], endpoint_url: "https://two.test"},
      %Subscription{id: "sub-3", enabled: false, event_types: ["user.created"], endpoint_url: "https://three.test"}
    ])

    assert [%Subscription{id: "sub-1"}] =
             Dispatcher.matching_subscriptions(config(), "user.created")
  end

  test "dispatch_multi/4 persists one public event plus one pending delivery and initial job per matching subscription" do
    Process.put(:dispatcher_subscriptions, [
      %Subscription{id: "sub-1", enabled: true, event_types: ["user.created"], endpoint_url: "https://one.test/hooks"},
      %Subscription{id: "sub-2", enabled: true, event_types: ["user.created"], endpoint_url: "https://two.test/hooks"},
      %Subscription{id: "sub-3", enabled: true, event_types: ["session.created"], endpoint_url: "https://three.test/hooks"}
    ])

    object = %User{
      id: "user-1",
      email: "user@example.com",
      display_name: "User Example",
      inserted_at: ~U[2026-05-06 12:00:00Z],
      updated_at: ~U[2026-05-06 12:00:00Z]
    }

    multi =
      Dispatcher.dispatch_multi(config(), "user.created", object,
        step_id: :register,
        event_id: "evt_123",
        occurred_at: ~U[2026-05-06 12:30:00Z],
        context: %{
          actor: %{type: "user", id: "admin-1"},
          organization: %{id: "org-1"},
          request: %{id: "req-1"}
        }
      )

    assert {:ok, changes} = MockRepo.transaction(multi)
    assert Map.has_key?(changes, {:webhook_subscriptions, :register})
    assert Map.has_key?(changes, {:webhook_event, :register})
    assert Map.has_key?(changes, {:webhook_deliveries, :register})
    assert Map.has_key?(changes, {:webhook_delivery_jobs, :register})
    assert length(changes[{:webhook_deliveries, :register}]) == 2
    assert length(changes[{:webhook_delivery_jobs, :register}]) == 2

    assert %Event{} = event = changes[{:webhook_event, :register}]
    assert event.event_id == "evt_123"
    assert event.type == "user.created"
    assert event.actor_id == "admin-1"
    assert event.organization_id == "org-1"
    assert event.request_id == "req-1"
    assert get_in(event.payload, ["data", "object", "email"]) == "user@example.com"

    assert Enum.map(changes[{:webhook_deliveries, :register}], & &1.webhook_event_id) ==
             [event.id, event.id]

    assert Enum.map(changes[{:webhook_delivery_jobs, :register}], & &1.args) ==
             Enum.map(changes[{:webhook_deliveries, :register}], fn delivery ->
               %{"delivery_id" => delivery.delivery_id}
             end)

    assert Enum.all?(changes[{:webhook_delivery_jobs, :register}], &(&1.queue == "sigra_webhooks"))
  end

  test "append_dispatch_multi/5 composes webhook persistence and initial queue handoff into an outer transaction" do
    Process.put(:dispatcher_subscriptions, [
      %Subscription{id: "sub-1", enabled: true, event_types: ["user.created"], endpoint_url: "https://one.test/hooks"}
    ])

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

    assert [%Oban.Job{args: %{"delivery_id" => delivery_id}}] =
             changes[{:webhook_delivery_jobs, :register}]

    assert [delivery] = changes[{:webhook_deliveries, :register}]
    assert delivery_id == delivery.delivery_id
  end
end
