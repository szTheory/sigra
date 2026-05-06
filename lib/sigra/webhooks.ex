defmodule Sigra.Webhooks do
  @moduledoc """
  Library-owned webhook subscription management.

  Phase 97 establishes the durable host-managed registry and validation
  surface. Delivery workers and persisted event fan-out build on these
  config and schema seams in later plans.
  """

  alias Ecto.Changeset
  alias Ecto.Multi
  alias Sigra.OptionalDeps
  alias Sigra.Webhooks.{Dispatcher, RetryPolicy}

  @type attrs :: map() | keyword()
  @type scope_like :: map() | struct() | nil

  @localhost_hosts MapSet.new(["127.0.0.1", "::1", "localhost"])

  @doc """
  Returns the explicit public webhook event catalog.
  """
  @spec public_event_types() :: [String.t()]
  def public_event_types, do: Sigra.Webhooks.EventCatalog.all()

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
  Returns the generated host webhook delivery-attempt schema module.
  """
  @spec delivery_attempt_schema!(Sigra.Config.t()) :: module()
  def delivery_attempt_schema!(%Sigra.Config{} = config) do
    config.webhooks
    |> Keyword.fetch!(:webhook_delivery_attempt_schema)
    |> validate_schema!(:webhook_delivery_attempt_schema)
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
  Returns the enabled subscriptions that explicitly include `event_type`.
  """
  @spec matching_subscriptions(Sigra.Config.t(), String.t()) :: [struct()]
  def matching_subscriptions(%Sigra.Config{} = config, event_type) when is_binary(event_type) do
    Dispatcher.matching_subscriptions(config, event_type)
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
  Builds a composable multi that persists one webhook event row and one
  pending delivery row per matching enabled subscription.
  """
  @spec dispatch_multi(Sigra.Config.t(), String.t(), term(), keyword()) :: Multi.t()
  def dispatch_multi(%Sigra.Config{} = config, event_type, object_ref, opts \\ [])
      when is_binary(event_type) and is_list(opts) do
    Dispatcher.dispatch_multi(config, event_type, object_ref, opts)
  end

  @doc """
  Appends the webhook persistence multi to an existing outer transaction.
  """
  @spec append_dispatch_multi(Multi.t(), Sigra.Config.t(), String.t(), term(), keyword()) ::
          Multi.t()
  def append_dispatch_multi(
        %Multi{} = multi,
        %Sigra.Config{} = config,
        event_type,
        object_ref,
        opts \\ []
      )
      when is_binary(event_type) and is_list(opts) do
    Multi.append(multi, dispatch_multi(config, event_type, object_ref, opts))
  end

  @doc """
  Builds an Oban job changeset for one persisted webhook delivery row.

  Webhook transport is async-only when enabled; this helper refuses to build
  jobs if the feature is disabled or its async dependency is unavailable.
  """
  @spec build_delivery_job(Sigra.Config.t(), struct() | map() | String.t(), keyword()) ::
          Ecto.Changeset.t()
  def build_delivery_job(%Sigra.Config{} = config, delivery_or_id, opts \\ [])
      when is_list(opts) do
    ensure_enabled!(config)
    delivery_id = extract_delivery_id!(delivery_or_id)
    queue = Keyword.get(opts, :queue, queue_name(config))

    worker_opts =
      opts
      |> Keyword.drop([:oban, :queue])
      |> Keyword.put(:queue, queue)
      |> Keyword.put(:config, config)

    Sigra.Workers.WebhookDelivery.new(%{"delivery_id" => delivery_id}, worker_opts)
  end

  @doc """
  Enqueues one persisted webhook delivery row for async execution.
  """
  @spec enqueue_delivery(Sigra.Config.t(), struct() | map() | String.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def enqueue_delivery(%Sigra.Config{} = config, delivery_or_id, opts \\ []) when is_list(opts) do
    changeset = build_delivery_job(config, delivery_or_id, opts)
    oban = Keyword.get(opts, :oban, Oban)

    case oban.insert(changeset) do
      {:ok, job} -> {:ok, job}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Builds a normalized webhook context map from scope plus explicit overrides.
  """
  @spec context(scope_like(), keyword()) :: map()
  def context(scope, opts \\ []) when is_list(opts) do
    %{}
    |> maybe_put_context_actor(Keyword.get(opts, :actor) || actor_from_scope(scope))
    |> maybe_put_context_organization(
      Keyword.get(opts, :organization) || organization_from_scope(scope)
    )
    |> maybe_put_context_request(Keyword.get(opts, :request_id))
  end

  @doc """
  Returns the next scheduled retry attempt for a failed delivery attempt.
  """
  @spec next_retry_attempt(pos_integer(), DateTime.t(), keyword()) ::
          {:ok, map()} | :exhausted
  def next_retry_attempt(attempt_number, %DateTime{} = attempted_at, opts \\ [])
      when is_list(opts) do
    RetryPolicy.next_attempt(attempt_number, attempted_at, opts)
  end

  @doc """
  Classifies an HTTP delivery status into the bounded retry contract.
  """
  @spec classify_delivery_http_status(integer()) :: map()
  def classify_delivery_http_status(status) when is_integer(status) do
    RetryPolicy.classify_http_status(status)
  end

  @doc """
  Persists one attempt row plus the parent delivery summary update in the
  same transaction.
  """
  @spec persist_delivery_outcome(Sigra.Config.t(), struct(), map()) ::
          {:ok, %{attempt: struct(), delivery: struct(), next_attempt: map() | nil}} | {:error, term()}
  def persist_delivery_outcome(%Sigra.Config{} = config, delivery, attrs) when is_map(attrs) do
    repo = config.repo
    attempt_schema = delivery_attempt_schema!(config)
    delivery_attrs = build_delivery_summary_attrs(delivery, attrs)
    attempt_attrs = build_attempt_attrs(delivery, attrs)

    Multi.new()
    |> Multi.insert(:attempt, attempt_schema.changeset(struct(attempt_schema), attempt_attrs))
    |> Multi.update(:delivery, delivery.__struct__.changeset(delivery, delivery_attrs))
    |> repo.transaction()
    |> case do
      {:ok, %{attempt: attempt, delivery: updated_delivery}} ->
        {:ok,
         %{
           attempt: attempt,
           delivery: updated_delivery,
           next_attempt: Map.get(attrs, :next_attempt)
         }}

      {:error, _step, reason, _changes} ->
        {:error, reason}
    end
  end

  @doc """
  Persists a terminal orphan issue row keyed only by `delivery_id`.
  """
  @spec persist_orphan_terminal_issue(Sigra.Config.t(), String.t(), map()) ::
          {:ok, struct()} | {:error, term()}
  def persist_orphan_terminal_issue(%Sigra.Config{} = config, delivery_id, attrs)
      when is_binary(delivery_id) and is_map(attrs) do
    attempt_schema = delivery_attempt_schema!(config)

    attrs =
      attrs
      |> Map.put(:delivery_id, delivery_id)
      |> Map.put_new(:attempt_number, 1)
      |> Map.put_new(:endpoint_url, "unknown")
      |> Map.put_new(:started_at, DateTime.utc_now() |> DateTime.truncate(:second))
      |> Map.put_new(:retryable, false)

    config.repo.insert(attempt_schema.changeset(struct(attempt_schema), attrs))
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

  defp normalize_multi_result(
         {:error, :subscription, %Changeset{} = changeset, _changes},
         :subscription
       ),
       do: {:error, changeset}

  defp normalize_multi_result(other, _step), do: other

  defp build_delivery_summary_attrs(delivery, attrs) do
    attempted_at = Map.fetch!(attrs, :attempted_at)
    finished_at = Map.get(attrs, :finished_at) || attempted_at
    prior_attempt_count = Map.get(delivery, :attempt_count, 0) || 0
    attempt_number = Map.get(attrs, :attempt_number, prior_attempt_count + 1)
    retryable = Map.get(attrs, :retryable, false)
    terminal_reason = Map.get(attrs, :terminal_reason)
    next_attempt = Map.get(attrs, :next_attempt)

    base = %{
      status: delivery_status(attrs),
      attempt_count: attempt_number,
      dispatched_at: Map.get(attrs, :dispatched_at),
      last_attempted_at: attempted_at,
      next_attempt_at: next_attempt && Map.get(next_attempt, :scheduled_at),
      last_http_status: Map.get(attrs, :response_status),
      last_error_category: Map.get(attrs, :error_category),
      last_error_detail: Map.get(attrs, :error_detail),
      dead_lettered_at: dead_lettered_at(attrs, retryable, terminal_reason, finished_at),
      terminal_reason: if(retryable, do: nil, else: terminal_reason)
    }

    Enum.reject(base, fn {_key, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end

  defp delivery_status(attrs) do
    cond do
      Map.get(attrs, :delivered, false) -> "delivered"
      Map.get(attrs, :retryable, false) -> "retry_scheduled"
      true -> "dead_lettered"
    end
  end

  defp dead_lettered_at(_attrs, true, _terminal_reason, _finished_at), do: nil
  defp dead_lettered_at(_attrs, false, nil, _finished_at), do: nil
  defp dead_lettered_at(_attrs, false, _terminal_reason, finished_at), do: finished_at

  defp build_attempt_attrs(delivery, attrs) do
    attempted_at = Map.fetch!(attrs, :attempted_at)

    %{
      delivery_id: Map.fetch!(delivery, :delivery_id),
      attempt_number: Map.fetch!(attrs, :attempt_number),
      endpoint_url: Map.get(attrs, :endpoint_url, Map.get(delivery, :endpoint_url)),
      started_at: attempted_at,
      finished_at: Map.get(attrs, :finished_at),
      response_status: Map.get(attrs, :response_status),
      retryable: Map.get(attrs, :retryable, false),
      retry_after_seconds: Map.get(attrs, :retry_after_seconds),
      error_category: Map.get(attrs, :error_category),
      error_detail: Map.get(attrs, :error_detail),
      terminal_reason: Map.get(attrs, :terminal_reason),
      webhook_delivery_id: Map.get(delivery, :id)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end

  defp ensure_enabled!(%Sigra.Config{} = config) do
    if enabled?(config) do
      OptionalDeps.ensure_available!(:webhook_delivery, config: config)
    else
      raise ArgumentError, "webhook delivery jobs require config.webhooks[:enabled] == true"
    end
  end

  defp extract_delivery_id!(%{delivery_id: delivery_id})
       when is_binary(delivery_id) and delivery_id != "",
       do: delivery_id

  defp extract_delivery_id!(%{"delivery_id" => delivery_id})
       when is_binary(delivery_id) and delivery_id != "",
       do: delivery_id

  defp extract_delivery_id!(delivery_id) when is_binary(delivery_id) and delivery_id != "",
    do: delivery_id

  defp extract_delivery_id!(_delivery_or_id) do
    raise ArgumentError,
          "webhook delivery jobs require a persisted delivery with a binary delivery_id"
  end

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
          Enum.reject(event_types, &Sigra.Webhooks.EventCatalog.valid?/1)
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
    _ = delivery_attempt_schema!(config)
    changeset
  rescue
    KeyError ->
      Changeset.add_error(
        changeset,
        :base,
        "config.webhooks must declare webhook_subscription_schema, webhook_event_schema, webhook_delivery_schema, and webhook_delivery_attempt_schema"
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

  defp localhost_host?(host) when is_binary(host),
    do: MapSet.member?(@localhost_hosts, String.downcase(host))

  defp localhost_host?(_host), do: false

  defp actor_from_scope(nil), do: nil

  defp actor_from_scope(%{user: user} = scope) when is_map(user) do
    actor = Map.get(scope, :impersonating_from) || user

    if is_binary(Map.get(actor, :id)) do
      %{type: "user", id: Map.get(actor, :id)}
    else
      nil
    end
  end

  defp actor_from_scope(_scope), do: nil

  defp organization_from_scope(nil), do: nil

  defp organization_from_scope(%{active_organization: organization}) when is_map(organization),
    do: organization

  defp organization_from_scope(_scope), do: nil

  defp maybe_put_context_actor(context, nil), do: context

  defp maybe_put_context_actor(context, %{id: id} = actor) when is_binary(id) and id != "" do
    type =
      actor
      |> Map.get(:type, "user")
      |> to_string()

    Map.put(context, :actor, %{type: type, id: id})
  end

  defp maybe_put_context_actor(context, _actor), do: context

  defp maybe_put_context_organization(context, nil), do: context

  defp maybe_put_context_organization(context, %{id: id}) when is_binary(id) and id != "" do
    Map.put(context, :organization, %{id: id})
  end

  defp maybe_put_context_organization(context, id) when is_binary(id) and id != "" do
    Map.put(context, :organization, %{id: id})
  end

  defp maybe_put_context_organization(context, _organization), do: context

  defp maybe_put_context_request(context, request_id)
       when is_binary(request_id) and request_id != "" do
    Map.put(context, :request, %{id: request_id})
  end

  defp maybe_put_context_request(context, _request_id), do: context
end
