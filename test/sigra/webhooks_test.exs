defmodule Sigra.WebhooksTest do
  use ExUnit.Case, async: true

  alias Ecto.Changeset
  alias Sigra.Webhooks

  defmodule Subscription do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "webhook_subscriptions" do
      field :endpoint_url, :string
      field :event_types, {:array, :string}, default: []
      field :enabled, :boolean, default: true
      field :description, :string
      field :signing_secret, :binary
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:endpoint_url, :event_types, :enabled, :description, :signing_secret])
      |> validate_required([:endpoint_url, :event_types, :enabled, :signing_secret])
    end
  end

  defmodule Event do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "webhook_events" do
      field :event_id, :string
    end
  end

  defmodule Delivery do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "webhook_deliveries" do
      field :delivery_id, :string
    end
  end

  defmodule MockRepo do
    def insert(changeset) do
      if changeset.valid? do
        {:ok, Ecto.Changeset.apply_changes(changeset)}
      else
        {:error, changeset}
      end
    end

    def update(changeset) do
      if changeset.valid? do
        {:ok, Ecto.Changeset.apply_changes(changeset)}
      else
        {:error, changeset}
      end
    end

    def transaction(%Ecto.Multi{} = multi), do: Sigra.Test.MultiStub.run(__MODULE__, multi)
    def all(_schema), do: Process.get(:webhook_subscriptions, [])
  end

  defp config(overrides \\ []) do
    defaults = [
      repo: MockRepo,
      user_schema: Sigra.TestUser,
      secret_key_base: String.duplicate("a", 64),
      webhooks: [
        enabled: false,
        webhook_subscription_schema: Subscription,
        webhook_event_schema: Event,
        webhook_delivery_schema: Delivery,
        oban_queue: "sigra_webhooks",
        oban_concurrency: 10,
        signature_tolerance: 300
      ]
    ]

    Sigra.Config.new!(Keyword.merge(defaults, overrides))
  end

  describe "config helpers" do
    test "exposes the public event catalog and webhook config helpers" do
      config = config()

      assert "user.created" in Webhooks.public_event_types()
      assert Webhooks.enabled?(config) == false
      assert Webhooks.queue_name(config) == "sigra_webhooks"
      assert Webhooks.signature_tolerance(config) == 300
      assert Webhooks.subscription_schema!(config) == Subscription
      assert Webhooks.event_schema!(config) == Event
      assert Webhooks.delivery_schema!(config) == Delivery
    end
  end

  describe "subscription_changeset/3" do
    test "normalizes event types, preserves localhost http, and defaults enabled" do
      changeset =
        Webhooks.subscription_changeset(config(), %Subscription{}, %{
          endpoint_url: "http://localhost:4000/webhooks",
          event_types: [" user.created ", "user.created", "session.created"],
          signing_secret: String.duplicate("s", 16)
        })

      assert changeset.valid?
      assert Changeset.get_field(changeset, :enabled) == true
      assert Changeset.get_field(changeset, :event_types) == ["user.created", "session.created"]
    end

    test "rejects unsupported event types" do
      changeset =
        Webhooks.subscription_changeset(config(), %Subscription{}, %{
          endpoint_url: "https://example.com/hooks",
          event_types: ["user.created", "user.hacked"],
          signing_secret: String.duplicate("s", 16)
        })

      refute changeset.valid?
      assert errors_on(changeset).event_types == ["contains unsupported event types: user.hacked"]
    end

    test "rejects insecure non-localhost http endpoints" do
      changeset =
        Webhooks.subscription_changeset(config(), %Subscription{}, %{
          endpoint_url: "http://example.com/hooks",
          event_types: ["user.created"],
          signing_secret: String.duplicate("s", 16)
        })

      refute changeset.valid?
      assert errors_on(changeset).endpoint_url == ["must use HTTPS unless the host is localhost"]
    end

    test "rejects short signing secrets" do
      changeset =
        Webhooks.subscription_changeset(config(), %Subscription{}, %{
          endpoint_url: "https://example.com/hooks",
          event_types: ["user.created"],
          signing_secret: "short-secret"
        })

      refute changeset.valid?
      assert errors_on(changeset).signing_secret == ["must be at least 16 bytes"]
    end

    test "adds a base error when dependent schema modules are missing" do
      bad_config =
        Sigra.Config.new!(
          repo: MockRepo,
          user_schema: Sigra.TestUser,
          secret_key_base: String.duplicate("a", 64),
          webhooks: [enabled: false, webhook_subscription_schema: Subscription]
        )

      changeset =
        Webhooks.subscription_changeset(bad_config, %Subscription{}, %{
          endpoint_url: "https://example.com/hooks",
          event_types: ["user.created"],
          signing_secret: String.duplicate("s", 16)
        })

      refute changeset.valid?

      assert errors_on(changeset).base == [
               "config.webhooks must declare webhook_subscription_schema, webhook_event_schema, and webhook_delivery_schema"
             ]
    end
  end

  describe "subscription CRUD" do
    test "create_subscription/2 persists valid subscriptions" do
      assert {:ok, subscription} =
               Webhooks.create_subscription(config(), %{
                 endpoint_url: "https://example.com/hooks",
                 event_types: ["user.created"],
                 signing_secret: String.duplicate("s", 16)
               })

      assert subscription.endpoint_url == "https://example.com/hooks"
      assert subscription.enabled == true
    end

    test "update_subscription/3 can disable a subscription" do
      subscription = %Subscription{
        endpoint_url: "https://example.com/hooks",
        event_types: ["user.created"],
        enabled: true,
        signing_secret: String.duplicate("s", 16)
      }

      assert {:ok, updated} = Webhooks.disable_subscription(config(), subscription)
      assert updated.enabled == false
    end

    test "list_subscriptions/1 delegates to the configured repo" do
      subscriptions = [%Subscription{endpoint_url: "https://example.com/hooks"}]
      Process.put(:webhook_subscriptions, subscriptions)

      assert Webhooks.list_subscriptions(config()) == subscriptions
    after
      Process.delete(:webhook_subscriptions)
    end
  end

  defp errors_on(%Changeset{} = changeset) do
    Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
