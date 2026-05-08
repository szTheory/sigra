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

  defmodule DeliveryAttempt do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "webhook_delivery_attempts" do
      field :delivery_id, :string
    end
  end

  defmodule MockRepo do
    def insert(changeset) do
      if changeset.valid? do
        record = Ecto.Changeset.apply_changes(changeset)
        put_subscription(record)
        {:ok, record}
      else
        {:error, changeset}
      end
    end

    def update(changeset) do
      if changeset.valid? do
        record = Ecto.Changeset.apply_changes(changeset)
        put_subscription(record)
        {:ok, record}
      else
        {:error, changeset}
      end
    end

    def transaction(%Ecto.Multi{} = multi), do: Sigra.Test.MultiStub.run(__MODULE__, multi)
    def all(_schema), do: Process.get(:webhook_subscriptions, [])
    def get_by(_schema, id: subscription_id), do: get_subscription(subscription_id)

    defp get_subscription(subscription_id) do
      Process.get(:webhook_subscription_records, %{})
      |> Map.get(subscription_id)
    end

    defp put_subscription(%{id: subscription_id} = subscription) when is_binary(subscription_id) do
      records = Process.get(:webhook_subscription_records, %{})
      Process.put(:webhook_subscription_records, Map.put(records, subscription_id, subscription))
    end

    defp put_subscription(_subscription), do: :ok
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
        webhook_delivery_attempt_schema: DeliveryAttempt,
        endpoint_resolver: &public_test_resolver/1,
        oban_queue: "sigra_webhooks",
        oban_concurrency: 10,
        signature_tolerance: 300
      ]
    ]

    merged =
      defaults
      |> Keyword.merge(Keyword.drop(overrides, [:webhooks]))
      |> Keyword.update!(
        :webhooks,
        &Keyword.merge(&1, Keyword.get(overrides, :webhooks, []))
      )

    Sigra.Config.new!(merged)
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
      assert Webhooks.delivery_attempt_schema!(config) == DeliveryAttempt
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

    test "rejects embedded credentials and blocked resolved targets" do
      resolver = fn
        "private.example.test" -> {:ok, [{10, 0, 0, 8}]}
        "metadata.example.test" -> {:ok, [{169, 254, 169, 254}]}
        "mixed.example.test" -> {:ok, [{203, 0, 113, 10}, {10, 0, 0, 2}]}
      end

      private_changeset =
        Webhooks.subscription_changeset(config(webhooks: [endpoint_resolver: resolver]), %Subscription{}, %{
          endpoint_url: "https://private.example.test/hooks",
          event_types: ["user.created"],
          signing_secret: String.duplicate("s", 16)
        })

      metadata_changeset =
        Webhooks.subscription_changeset(config(webhooks: [endpoint_resolver: resolver]), %Subscription{}, %{
          endpoint_url: "https://metadata.example.test/hooks",
          event_types: ["user.created"],
          signing_secret: String.duplicate("s", 16)
        })

      credentials_changeset =
        Webhooks.subscription_changeset(config(), %Subscription{}, %{
          endpoint_url: "https://user:pass@example.com/hooks",
          event_types: ["user.created"],
          signing_secret: String.duplicate("s", 16)
        })

      mixed_changeset =
        Webhooks.subscription_changeset(config(webhooks: [endpoint_resolver: resolver]), %Subscription{}, %{
          endpoint_url: "https://mixed.example.test/hooks",
          event_types: ["user.created"],
          signing_secret: String.duplicate("s", 16)
        })

      refute private_changeset.valid?
      refute metadata_changeset.valid?
      refute credentials_changeset.valid?
      refute mixed_changeset.valid?
      assert errors_on(private_changeset).endpoint_url == ["resolved target points at a private address"]
      assert errors_on(metadata_changeset).endpoint_url == ["resolved target points at a metadata address"]
      assert errors_on(credentials_changeset).endpoint_url == ["must not include embedded credentials"]
      assert errors_on(mixed_changeset).endpoint_url == ["resolved target points at a private address"]
    end

    test "accepts loopback http and surfaces host callback denials" do
      policy = fn
        %{uri: %URI{host: "callback.example.test"}} ->
          {:error, :policy_denied, "custom outbound allowlist denied the destination"}

        _context ->
          :ok
      end

      localhost_changeset =
        Webhooks.subscription_changeset(config(), %Subscription{}, %{
          endpoint_url: "http://127.0.0.1:4000/hooks",
          event_types: ["user.created"],
          signing_secret: String.duplicate("s", 16)
        })

      denied_changeset =
        Webhooks.subscription_changeset(config(webhooks: [endpoint_policy: policy]), %Subscription{}, %{
          endpoint_url: "https://callback.example.test/hooks",
          event_types: ["user.created"],
          signing_secret: String.duplicate("s", 16)
        })

      assert localhost_changeset.valid?
      refute denied_changeset.valid?
      assert errors_on(denied_changeset).endpoint_url == ["custom outbound allowlist denied the destination"]
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
               "config.webhooks must declare webhook_subscription_schema, webhook_event_schema, webhook_delivery_schema, and webhook_delivery_attempt_schema"
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

  describe "rotation lifecycle" do
    test "prepare_secret/3 stages one next secret and records prepared metadata" do
      subscription = put_subscription(subscription_fixture())
      scope = %{user: %{id: Ecto.UUID.generate()}}

      assert {:ok, prepared} = Webhooks.prepare_secret(config(), subscription, scope: scope)

      assert prepared.signing_secret == subscription.signing_secret
      assert is_binary(prepared.next_signing_secret)
      assert prepared.next_signing_secret != subscription.signing_secret
      assert prepared.rotation_state == :prepared
      assert %DateTime{} = prepared.rotation_prepared_at
      assert prepared.rotation_last_changed_by_user_id == scope.user.id
      assert is_binary(prepared.signing_secret_fingerprint)
      assert is_binary(prepared.next_signing_secret_fingerprint)
      assert prepared.signing_secret_fingerprint != prepared.next_signing_secret_fingerprint
    end

    test "discard_prepared_secret/3 clears the next slot without replacing the active secret" do
      subscription =
        subscription_fixture(%{
          next_signing_secret: String.duplicate("n", 32),
          rotation_state: :prepared,
          rotation_prepared_at: DateTime.utc_now() |> DateTime.truncate(:second),
          next_signing_secret_fingerprint: "nextfingerprint"
        })
        |> put_subscription()

      scope = %{user: %{id: Ecto.UUID.generate()}}

      assert {:ok, discarded} =
               Webhooks.discard_prepared_secret(config(), subscription, scope: scope)

      assert discarded.signing_secret == subscription.signing_secret
      assert discarded.next_signing_secret == nil
      assert discarded.rotation_state == :stable
      assert discarded.rotation_prepared_at == nil
      assert discarded.rotation_overlap_started_at == nil
      assert discarded.rotation_retire_after_at == nil
      assert discarded.rotation_completed_at == nil
      assert discarded.next_signing_secret_fingerprint == nil
      assert discarded.rotation_last_changed_by_user_id == scope.user.id
    end

    test "start_secret_overlap/3 only allows the prepared state and records overlap metadata" do
      prepared =
        subscription_fixture(%{
          next_signing_secret: String.duplicate("n", 32),
          rotation_state: :prepared,
          rotation_prepared_at: DateTime.utc_now() |> DateTime.truncate(:second),
          next_signing_secret_fingerprint: "nextfingerprint"
        })
        |> put_subscription()

      retire_after_at = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      assert {:ok, overlap} =
               Webhooks.start_secret_overlap(config(), prepared,
                 retire_after_at: retire_after_at,
                 scope: %{user: %{id: Ecto.UUID.generate()}}
               )

      assert overlap.rotation_state == :overlap_active
      assert %DateTime{} = overlap.rotation_overlap_started_at
      assert DateTime.compare(overlap.rotation_retire_after_at, retire_after_at) == :eq

      assert {:error, changeset} =
               Webhooks.start_secret_overlap(config(), subscription_fixture())

      assert errors_on(changeset).rotation_state == ["can only start overlap from prepared"]
    end

    test "complete_secret_rotation/3 promotes the next secret and records completion state" do
      prepared_next = String.duplicate("n", 32)

      overlap =
        subscription_fixture(%{
          next_signing_secret: prepared_next,
          rotation_state: :overlap_active,
          rotation_prepared_at: DateTime.utc_now() |> DateTime.truncate(:second),
          rotation_overlap_started_at: DateTime.utc_now() |> DateTime.truncate(:second),
          next_signing_secret_fingerprint: "nextfingerprint"
        })
        |> put_subscription()

      assert {:ok, completed} =
               Webhooks.complete_secret_rotation(config(), overlap,
                 scope: %{user: %{id: Ecto.UUID.generate()}}
               )

      assert completed.signing_secret == prepared_next
      assert completed.next_signing_secret == nil
      assert completed.rotation_state == :completed
      assert %DateTime{} = completed.rotation_completed_at
      assert completed.rotation_prepared_at == nil
      assert completed.rotation_overlap_started_at == nil
      assert completed.rotation_retire_after_at == nil
      assert completed.next_signing_secret_fingerprint == nil
      assert is_binary(completed.signing_secret_fingerprint)
    end

    test "illegal lifecycle jumps are rejected" do
      stable = put_subscription(subscription_fixture())

      assert {:error, start_changeset} = Webhooks.start_secret_overlap(config(), stable)
      assert errors_on(start_changeset).rotation_state == ["can only start overlap from prepared"]

      assert {:error, complete_changeset} = Webhooks.complete_secret_rotation(config(), stable)
      assert errors_on(complete_changeset).rotation_state == ["can only complete rotation from overlap_active"]

      prepared =
        subscription_fixture(%{
          next_signing_secret: String.duplicate("n", 32),
          rotation_state: :prepared,
          rotation_prepared_at: DateTime.utc_now() |> DateTime.truncate(:second),
          next_signing_secret_fingerprint: "nextfingerprint"
        })
        |> put_subscription()

      assert {:error, prepare_changeset} = Webhooks.prepare_secret(config(), prepared)
      assert errors_on(prepare_changeset).rotation_state == ["can only prepare a next secret from stable or completed"]
    end
  end

  defp errors_on(%Changeset{} = changeset) do
    Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp subscription_fixture(overrides \\ %{}) do
    base = %Subscription{
      id: Ecto.UUID.generate(),
      endpoint_url: "https://example.com/hooks",
      event_types: ["user.created"],
      enabled: true,
      signing_secret: String.duplicate("s", 32),
      rotation_state: :stable,
      signing_secret_fingerprint: "activefingerprint"
    }

    struct(base, overrides)
  end

  defp put_subscription(%Subscription{} = subscription) do
    records = Process.get(:webhook_subscription_records, %{})
    Process.put(:webhook_subscription_records, Map.put(records, subscription.id, subscription))
    subscription
  end

  defp public_test_resolver(host) do
    case host do
      "example.com" -> {:ok, [{93, 184, 216, 34}]}
      "hooks.example.test" -> {:ok, [{203, 0, 113, 20}]}
      "callback.example.test" -> {:ok, [{203, 0, 113, 21}]}
      _other -> {:error, :nxdomain}
    end
  end
end
