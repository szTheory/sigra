defmodule Sigra.Webhooks do
  @moduledoc """
  Library-owned webhook subscription management.

  Phase 97 establishes the durable host-managed registry and validation
  surface. Delivery workers and persisted event fan-out build on these
  config and schema seams in later plans.
  """

  alias Ecto.Changeset
  alias Ecto.Multi

  @type attrs :: map() | keyword()

  @public_event_types [
    "organization_membership.created",
    "organization_membership.deleted",
    "organization_membership.updated",
    "service_account.created",
    "service_account.revoked",
    "session.created",
    "session.revoked",
    "user.created",
    "user.deleted",
    "user.updated"
  ]

  @localhost_hosts MapSet.new(["127.0.0.1", "::1", "localhost"])

  @doc """
  Returns the explicit public webhook event catalog.
  """
  @spec public_event_types() :: [String.t()]
  def public_event_types, do: @public_event_types

  @doc """
  Returns true when webhook delivery is enabled for the host config.
  """
  @spec enabled?(Sigra.Config.t()) :: boolean()
  def enabled?(%Sigra.Config{} = config) do
    Keyword.get(config.webhooks, :enabled, false)
  end

  @doc """
  Returns the configured webhook queue name.
  """
  @spec queue_name(Sigra.Config.t()) :: String.t()
  def queue_name(%Sigra.Config{} = config) do
    Keyword.get(config.webhooks, :oban_queue, "sigra_webhooks")
  end

  @doc """
  Returns the allowed signature timestamp skew in seconds.
  """
  @spec signature_tolerance(Sigra.Config.t()) :: pos_integer()
  def signature_tolerance(%Sigra.Config{} = config) do
    Keyword.get(config.webhooks, :signature_tolerance, 300)
  end

  @doc """
  Returns the generated host webhook subscription schema module.
  """
  @spec subscription_schema!(Sigra.Config.t()) :: module()
  def subscription_schema!(%Sigra.Config{} = config) do
    config.webhooks
    |> Keyword.fetch!(:webhook_subscription_schema)
    |> validate_schema!(:webhook_subscription_schema)
  end

  @doc """
  Returns the generated host webhook event schema module.
  """
  @spec event_schema!(Sigra.Config.t()) :: module()
  def event_schema!(%Sigra.Config{} = config) do
    config.webhooks
    |> Keyword.fetch!(:webhook_event_schema)
    |> validate_schema!(:webhook_event_schema)
  end

  @doc """
  Returns the generated host webhook delivery schema module.
  """
  @spec delivery_schema!(Sigra.Config.t()) :: module()
  def delivery_schema!(%Sigra.Config{} = config) do
    config.webhooks
    |> Keyword.fetch!(:webhook_delivery_schema)
    |> validate_schema!(:webhook_delivery_schema)
  end

  @doc """
  Creates a webhook subscription after validating endpoint and event scope.
  """
  @spec create_subscription(Sigra.Config.t(), attrs()) ::
          {:ok, struct()} | {:error, Changeset.t()}
  def create_subscription(%Sigra.Config{} = config, attrs) do
    schema = subscription_schema!(config)
    changeset = subscription_changeset(config, struct(schema), attrs)

    Multi.new()
    |> Multi.insert(:subscription, changeset)
    |> config.repo.transaction()
    |> normalize_multi_result(:subscription)
  end

  @doc """
  Updates a webhook subscription with the same validation rules as create.
  """
  @spec update_subscription(Sigra.Config.t(), struct(), attrs()) ::
          {:ok, struct()} | {:error, Changeset.t()}
  def update_subscription(%Sigra.Config{} = config, subscription, attrs) do
    changeset = subscription_changeset(config, subscription, attrs)

    Multi.new()
    |> Multi.update(:subscription, changeset)
    |> config.repo.transaction()
    |> normalize_multi_result(:subscription)
  end

  @doc """
  Lists all configured webhook subscriptions.
  """
  @spec list_subscriptions(Sigra.Config.t()) :: [struct()]
  def list_subscriptions(%Sigra.Config{} = config) do
    config.repo.all(subscription_schema!(config))
  end

  @doc """
  Enables a subscription.
  """
  @spec enable_subscription(Sigra.Config.t(), struct()) ::
          {:ok, struct()} | {:error, Changeset.t()}
  def enable_subscription(%Sigra.Config{} = config, subscription) do
    update_subscription(config, subscription, %{enabled: true})
  end

  @doc """
  Disables a subscription.
  """
  @spec disable_subscription(Sigra.Config.t(), struct()) ::
          {:ok, struct()} | {:error, Changeset.t()}
  def disable_subscription(%Sigra.Config{} = config, subscription) do
    update_subscription(config, subscription, %{enabled: false})
  end

  @doc """
  Builds a validated changeset without persisting it.
  """
  @spec subscription_changeset(Sigra.Config.t(), struct(), attrs()) :: Changeset.t()
  def subscription_changeset(%Sigra.Config{} = config, subscription, attrs) do
    attrs = normalize_attrs(attrs)
    schema = subscription.__struct__

    subscription
    |> schema.changeset(attrs)
    |> put_default_enabled()
    |> normalize_event_types()
    |> validate_event_types()
    |> validate_endpoint_url()
    |> maybe_validate_secret()
    |> maybe_validate_schema_modules(config)
  end

  defp normalize_multi_result({:ok, %{subscription: subscription}}, :subscription),
    do: {:ok, subscription}

  defp normalize_multi_result({:error, :subscription, %Changeset{} = changeset, _changes}, :subscription),
    do: {:error, changeset}

  defp normalize_multi_result(other, _step), do: other

  defp normalize_attrs(attrs) when is_list(attrs), do: Enum.into(attrs, %{})
  defp normalize_attrs(attrs) when is_map(attrs), do: attrs

  defp put_default_enabled(%Changeset{} = changeset) do
    case Changeset.get_field(changeset, :enabled) do
      nil -> Changeset.put_change(changeset, :enabled, true)
      _other -> changeset
    end
  end

  defp normalize_event_types(%Changeset{} = changeset) do
    case Changeset.get_field(changeset, :event_types) do
      event_types when is_list(event_types) ->
        normalized =
          event_types
          |> Enum.map(&normalize_event_type/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()

        Changeset.put_change(changeset, :event_types, normalized)

      _other ->
        changeset
    end
  end

  defp normalize_event_type(event_type) when is_binary(event_type) do
    event_type
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_event_type(_other), do: nil

  defp validate_event_types(%Changeset{} = changeset) do
    Changeset.validate_change(changeset, :event_types, fn :event_types, event_types ->
      invalid =
        if is_list(event_types) do
          Enum.reject(event_types, &(&1 in @public_event_types))
        else
          []
        end

      cond do
        not is_list(event_types) ->
          [event_types: "must be a list of event type strings"]

        event_types == [] ->
          [event_types: "must include at least one explicit event type"]

        invalid != [] ->
          [event_types: "contains unsupported event types: #{Enum.join(invalid, ", ")}"]

        true ->
          []
      end
    end)
  end

  defp validate_endpoint_url(%Changeset{} = changeset) do
    Changeset.validate_change(changeset, :endpoint_url, fn :endpoint_url, endpoint_url ->
      case validate_endpoint(endpoint_url) do
        :ok -> []
        {:error, reason} -> [endpoint_url: reason]
      end
    end)
  end

  defp maybe_validate_secret(%Changeset{} = changeset) do
    Changeset.validate_change(changeset, :signing_secret, fn :signing_secret, secret ->
      cond do
        is_binary(secret) and byte_size(secret) >= 16 -> []
        is_binary(secret) -> [signing_secret: "must be at least 16 bytes"]
        true -> [signing_secret: "must be a binary secret"]
      end
    end)
  end

  defp maybe_validate_schema_modules(%Changeset{} = changeset, %Sigra.Config{} = config) do
    _ = event_schema!(config)
    _ = delivery_schema!(config)
    changeset
  rescue
    KeyError ->
      Changeset.add_error(
        changeset,
        :base,
        "config.webhooks must declare webhook_subscription_schema, webhook_event_schema, and webhook_delivery_schema"
      )
  end

  defp validate_schema!(nil, key) do
    raise KeyError, key: key, term: nil
  end

  defp validate_schema!(schema, _key) when is_atom(schema), do: schema

  defp validate_schema!(_schema, key) do
    raise ArgumentError, "config.webhooks[:#{key}] must be a module"
  end

  defp validate_endpoint(endpoint_url) when is_binary(endpoint_url) do
    uri = URI.parse(endpoint_url)

    cond do
      uri.scheme == "https" and is_binary(uri.host) -> :ok
      uri.scheme == "http" and localhost_host?(uri.host) -> :ok
      uri.scheme in ["http", "https"] and is_nil(uri.host) -> {:error, "must include a host"}
      uri.scheme == "http" -> {:error, "must use HTTPS unless the host is localhost"}
      true -> {:error, "must be an absolute HTTP or HTTPS URL"}
    end
  end

  defp validate_endpoint(_other), do: {:error, "must be an absolute HTTP or HTTPS URL"}

  defp localhost_host?(host) when is_binary(host), do: MapSet.member?(@localhost_hosts, String.downcase(host))
  defp localhost_host?(_host), do: false
end
