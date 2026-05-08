if Code.ensure_loaded?(Oban.Worker) do
  defmodule Sigra.Workers.WebhookDelivery do
    @moduledoc """
    Oban worker for async outbound webhook delivery.

    Jobs store only the stable `delivery_id`. The worker reloads the
    persisted delivery row, webhook event payload, and signing secret at
    execution time so raw payload bytes and secrets never enter the jobs
    table.
    """

    use Oban.Worker,
      queue: :sigra_webhooks,
      max_attempts: 1

    alias Oban.{Job, Worker}
    alias Sigra.{OptionalDeps, Webhooks}
    alias Sigra.Webhooks.{EndpointPolicy, RetryPolicy, Signature}

    @impl Oban.Worker
    def new(args, opts) when is_map(args) and is_list(opts) do
      OptionalDeps.ensure_available!(:webhook_delivery, webhook_delivery_context(opts))

      Job.new(
        args,
        Worker.merge_opts(
          __opts__(),
          Keyword.drop(opts, [:config, :webhooks, :dependency_loaded?])
        )
      )
    end

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"delivery_id" => delivery_id}}) when is_binary(delivery_id) do
      config = resolve_config()

      cond do
        not Webhooks.enabled?(config) ->
          {:cancel, :webhooks_disabled}

        true ->
          case load_delivery_context(config, delivery_id) do
            {:ok, bundle} -> dispatch_delivery(config, bundle)
            {:delivery_only, delivery, reason} -> persist_terminal_failure(config, delivery, reason)
            {:orphan, orphan_delivery_id} -> persist_orphan_failure(config, orphan_delivery_id)
          end
      end
    end

    def perform(%Oban.Job{}), do: {:cancel, :missing_delivery_id}

    @doc false
    def default_request(%{url: url, headers: headers, body: body}) do
      with :ok <- ensure_http_client(url),
           {:ok, response} <- request(url, headers, body) do
        {:ok, %{status: response_status(response), headers: response_headers(response)}}
      else
        {:error, reason} -> {:error, reason}
      end
    end

    defp dispatch_delivery(config, %{delivery: delivery, subscription: subscription, event: event}) do
      with :ok <- enforce_endpoint_policy(config, delivery, subscription),
           {:ok, raw_body} <- encode_payload(event),
           {:ok, signed_at, request} <- build_request(delivery, subscription, raw_body),
           {:ok, response} <- execute_request(request) do
        persist_success(config, delivery, signed_at, response)
      else
        {:cancel, reason} -> persist_terminal_failure(config, delivery, reason)
        {:error, {:http_error, response, attempted_at}} ->
          persist_http_failure(config, delivery, response, attempted_at)

        {:error, {:transport_error, reason, attempted_at}} ->
          persist_transport_failure(config, delivery, reason, attempted_at)
      end
    end

    defp build_request(delivery, subscription, raw_body) do
      case Webhooks.active_signing_secrets(subscription) do
        [first_secret | _rest] = secrets when is_binary(first_secret) ->
          signed_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)
          timestamp = DateTime.to_unix(signed_at)

          headers =
            Signature.headers(Map.fetch!(delivery, :delivery_id), raw_body, secrets,
              timestamp: timestamp
            )
            |> Map.put("Content-Type", "application/json")
            |> Enum.to_list()

          {:ok, signed_at,
           %{
             url: Map.fetch!(delivery, :endpoint_url),
             headers: headers,
             body: raw_body
           }}

        _other ->
          {:cancel, :invalid_signing_secret}
      end
    end

    defp execute_request(request) do
      requester = Application.get_env(:sigra, :webhook_delivery_requester, &default_request/1)

      case requester.(request) do
        {:ok, %{status: status} = response} when is_integer(status) and status >= 200 and status < 300 ->
          {:ok, normalize_response(response)}

        {:ok, status} when is_integer(status) and status >= 200 and status < 300 ->
          {:ok, %{status: status, headers: []}}

        {:ok, %{status: status} = response} when is_integer(status) ->
          {:error, {:http_error, normalize_response(response), DateTime.utc_now() |> DateTime.truncate(:second)}}

        {:ok, status} when is_integer(status) ->
          {:error, {:http_error, %{status: status, headers: []}, DateTime.utc_now() |> DateTime.truncate(:second)}}

        {:error, reason} ->
          {:error, {:transport_error, reason, DateTime.utc_now() |> DateTime.truncate(:second)}}

        _other ->
          {:error, {:transport_error, :transport_error, DateTime.utc_now() |> DateTime.truncate(:second)}}
      end
    end

    defp load_delivery_context(config, delivery_id) do
      repo = config.repo
      delivery_schema = Webhooks.delivery_schema!(config)
      subscription_schema = Webhooks.subscription_schema!(config)
      event_schema = Webhooks.event_schema!(config)

      case repo.get_by(delivery_schema, delivery_id: delivery_id) do
        nil ->
          {:orphan, delivery_id}

        delivery ->
          case repo.get(subscription_schema, Map.fetch!(delivery, :webhook_subscription_id)) do
            nil ->
              {:delivery_only, delivery, :delivery_dependency_missing}

            subscription ->
              cond do
                not Map.get(subscription, :enabled, false) ->
                  {:delivery_only, delivery, :subscription_disabled}

                true ->
                  case repo.get(event_schema, Map.fetch!(delivery, :webhook_event_id)) do
                    nil -> {:delivery_only, delivery, :delivery_dependency_missing}
                    event -> {:ok, %{delivery: delivery, subscription: subscription, event: event}}
                  end
              end
          end
      end
    end

    defp persist_success(config, delivery, attempted_at, response) do
      case Webhooks.persist_delivery_outcome(config, delivery, %{
             attempt_number: next_attempt_number(delivery),
             attempted_at: attempted_at,
             finished_at: attempted_at,
             dispatched_at: attempted_at,
             delivered: true,
             retryable: false,
             response_status: Map.get(response, :status),
             endpoint_url: Map.get(delivery, :endpoint_url)
           }) do
        {:ok, _result} -> {:ok, :delivered}
        {:error, _reason} -> {:error, :delivery_update_failed}
      end
    end

    defp persist_http_failure(config, delivery, response, attempted_at) do
      classification = classify_http_failure(response, attempted_at)
      persist_failure(config, delivery, classification, attempted_at)
    end

    defp persist_transport_failure(config, delivery, reason, attempted_at) do
      classification = classify_transport_failure(reason)
      persist_failure(config, delivery, classification, attempted_at)
    end

    defp persist_terminal_failure(config, delivery, reason) do
      attempted_at = DateTime.utc_now() |> DateTime.truncate(:second)
      classification = RetryPolicy.classify_local_failure(reason)
      persist_failure(config, delivery, classification, attempted_at)
    end

    defp persist_orphan_failure(config, delivery_id) do
      attempted_at = DateTime.utc_now() |> DateTime.truncate(:second)

      case Webhooks.persist_orphan_terminal_issue(config, delivery_id, %{
             attempt_number: 1,
             endpoint_url: "unknown",
             started_at: attempted_at,
             finished_at: attempted_at,
             retryable: false,
             error_category: "local_state_error",
             error_detail: "delivery row missing during webhook execution",
             terminal_reason: "delivery_dependency_missing"
           }) do
        {:ok, _attempt} -> {:ok, :dead_lettered}
        {:error, _reason} -> {:error, :delivery_update_failed}
      end
    end

    defp persist_failure(config, delivery, classification, attempted_at) do
      attempt_number = next_attempt_number(delivery)

      next_attempt =
        if classification.retryable do
          Webhooks.next_retry_attempt(
            attempt_number,
            attempted_at,
            retry_after_seconds: Map.get(classification, :retry_after_seconds)
          )
        else
          :exhausted
        end

      exhausted_retry? = classification.retryable and next_attempt == :exhausted
      persist_as_retryable = classification.retryable and not exhausted_retry?

      attrs = %{
        attempt_number: attempt_number,
        attempted_at: attempted_at,
        finished_at: attempted_at,
        retryable: persist_as_retryable,
        response_status: Map.get(classification, :status),
        retry_after_seconds: Map.get(classification, :retry_after_seconds),
        error_category: classification.error_category,
        error_detail: failure_detail(classification),
        terminal_reason: terminal_reason(classification, next_attempt),
        endpoint_url: Map.get(delivery, :endpoint_url),
        next_attempt: next_attempt_value(next_attempt)
      }

      case Webhooks.persist_delivery_outcome(config, delivery, attrs) do
        {:ok, %{delivery: updated_delivery, next_attempt: next_retry}} ->
          case maybe_enqueue_retry(config, updated_delivery, next_retry) do
            :ok -> {:ok, retry_result(persist_as_retryable)}
            {:error, reason} -> {:error, reason}
          end

        {:error, _reason} ->
          {:error, :delivery_update_failed}
      end
    end

    defp next_attempt_number(delivery) do
      (Map.get(delivery, :attempt_count) || 0) + 1
    end

    defp next_attempt_value({:ok, next_attempt}), do: next_attempt
    defp next_attempt_value(:exhausted), do: nil

    defp terminal_reason(classification, {:ok, _next_attempt}) when classification.retryable, do: nil
    defp terminal_reason(classification, :exhausted), do: classification.terminal_reason || "retry_budget_exhausted"
    defp terminal_reason(classification, _other), do: classification.terminal_reason

    defp retry_result(true), do: :retry_scheduled
    defp retry_result(false), do: :dead_lettered

    defp maybe_enqueue_retry(_config, _delivery, nil), do: :ok

    defp maybe_enqueue_retry(config, delivery, _next_retry) do
      oban = Application.get_env(:sigra, :webhook_delivery_oban, Oban)

      case Webhooks.enqueue_delivery(config, delivery, oban: oban) do
        {:ok, _job} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end

    defp failure_detail(classification) do
      classification
      |> Map.get(:reason)
      |> case do
        nil -> Map.get(classification, :error_detail)
        reason -> inspect(reason)
      end
    end

    defp enforce_endpoint_policy(config, delivery, subscription) do
      case EndpointPolicy.validate_delivery(config, Map.fetch!(delivery, :endpoint_url), %{
             subscription: subscription,
             delivery: delivery
           }) do
        :ok -> :ok
        {:error, reason, detail} -> {:cancel, {:local_policy_error, reason, detail}}
      end
    end

    defp encode_payload(event) do
      case Jason.encode(Map.get(event, :payload, %{})) do
        {:ok, raw_body} -> {:ok, raw_body}
        {:error, _reason} -> {:cancel, :invalid_payload}
      end
    end

    defp resolve_config do
      case Application.get_env(:sigra, :otp_app) do
        otp_app when is_atom(otp_app) and not is_nil(otp_app) ->
          otp_app
          |> Application.fetch_env!(:sigra_config)
          |> Sigra.Config.new!()

        _other ->
          Sigra.Config.new!(
            repo: Application.fetch_env!(:sigra, :repo),
            user_schema: Application.fetch_env!(:sigra, :user_schema),
            secret_key_base: Application.get_env(:sigra, :secret_key_base),
            webhooks: Application.get_env(:sigra, :webhooks, [])
          )
      end
    end

    defp webhook_delivery_context(opts) do
      [
        config: Keyword.get(opts, :config),
        webhooks: Keyword.get(opts, :webhooks),
        dependency_loaded?: Keyword.get(opts, :dependency_loaded?, &dependency_loaded?/1)
      ]
    end

    defp dependency_loaded?(spec) do
      Enum.any?(spec.dependency_modules, &Code.ensure_loaded?/1)
    end

    defp ensure_http_client(url) do
      with {:ok, _} <- Application.ensure_all_started(:inets),
           {:ok, _} <- maybe_start_ssl(url) do
        :ok
      else
        {:error, reason} -> {:error, reason}
      end
    end

    defp maybe_start_ssl("https://" <> _rest), do: Application.ensure_all_started(:ssl)
    defp maybe_start_ssl(_url), do: {:ok, []}

    defp request(url, headers, body) do
      :httpc.request(
        :post,
        {String.to_charlist(url), http_headers(headers), ~c"application/json", body},
        [timeout: 10_000],
        body_format: :binary
      )
    end

    defp http_headers(headers) do
      Enum.map(headers, fn {key, value} ->
        {String.to_charlist(key), String.to_charlist(value)}
      end)
    end

    defp response_status({{_version, status, _reason}, _headers, _body}), do: status

    defp response_headers({{_version, _status, _reason}, headers, _body}) do
      Enum.map(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
    end

    defp normalize_response(%{status: status} = response) do
      %{status: status, headers: normalize_headers(Map.get(response, :headers, []))}
    end

    defp normalize_headers(headers) when is_list(headers) do
      Enum.flat_map(headers, fn
        {key, value} when is_binary(value) -> [{to_string(key), value}]
        {key, value} -> [{to_string(key), to_string(value)}]
        _other -> []
      end)
    end

    defp normalize_headers(headers) when is_map(headers) do
      headers
      |> Enum.map(fn {key, value} -> {to_string(key), to_string(value)} end)
      |> normalize_headers()
    end

    defp normalize_headers(_headers), do: []

    defp classify_http_failure(%{status: status, headers: headers}, %DateTime{} = attempted_at) do
      classification = RetryPolicy.classify_http_status(status)
      retry_after_seconds = retry_after_seconds(headers, attempted_at)

      Map.merge(classification, %{
        status: status,
        headers: headers,
        retry_after_seconds: retry_after_seconds
      })
    end

    defp classify_transport_failure(reason) do
      RetryPolicy.classify_transport_error(reason)
      |> Map.put(:reason, reason)
    end

    defp retry_after_seconds(headers, %DateTime{} = attempted_at) do
      headers
      |> header_value("Retry-After")
      |> case do
        nil ->
          nil

        value ->
          case RetryPolicy.parse_retry_after(value, attempted_at) do
            {:ok, seconds} -> seconds
            :error -> nil
          end
      end
    end

    defp header_value(headers, target) do
      target = String.downcase(target)

      Enum.find_value(headers, fn {key, value} ->
        if String.downcase(to_string(key)) == target, do: value
      end)
    end
  end
else
  defmodule Sigra.Workers.WebhookDelivery do
    @moduledoc """
    Stub fallback for hosts that compile Sigra without Oban.

    Webhook delivery is async-only when enabled, so the first queue-backed
    interaction (`new/2`) raises `Sigra.OptionalDeps.MissingDependencyError`
    tagged `:webhook_delivery`.
    """

    alias Sigra.OptionalDeps

    @doc false
    def new(args, opts \\ []) when is_map(args) and is_list(opts) do
      OptionalDeps.ensure_available!(:webhook_delivery, webhook_delivery_context(opts))
      raise "unreachable"
    end

    defp webhook_delivery_context(opts) do
      [
        config: Keyword.get(opts, :config),
        webhooks: Keyword.get(opts, :webhooks),
        dependency_loaded?: Keyword.get(opts, :dependency_loaded?, fn _spec -> false end)
      ]
    end
  end
end
