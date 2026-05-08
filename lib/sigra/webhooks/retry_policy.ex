defmodule Sigra.Webhooks.RetryPolicy do
  @moduledoc """
  Fixed retry policy and failure classification for webhook deliveries.

  Phase 98 keeps retry semantics library-owned and bounded: six total
  attempts, a documented nominal schedule, and explicit classification for
  retryable versus terminal outcomes.
  """

  @retry_schedule_seconds [60, 300, 900, 3600, 10_800]
  @total_attempts length(@retry_schedule_seconds) + 1

  @type http_classification :: %{
          retryable: boolean(),
          error_category: String.t(),
          terminal_reason: String.t() | nil
        }

  @type local_classification :: %{
          retryable: false,
          error_category: String.t(),
          terminal_reason: String.t()
        }

  @type next_attempt :: %{
          attempt_number: pos_integer(),
          scheduled_at: DateTime.t(),
          delay_seconds: pos_integer(),
          nominal_delay_seconds: pos_integer(),
          retry_after_seconds: pos_integer() | nil
        }

  @doc """
  Returns the fixed number of total attempts, including the first send.
  """
  @spec total_attempts() :: pos_integer()
  def total_attempts, do: @total_attempts

  @doc """
  Returns the nominal retry schedule in seconds after each failed attempt.
  """
  @spec retry_schedule_seconds() :: [pos_integer()]
  def retry_schedule_seconds, do: @retry_schedule_seconds

  @doc """
  Classifies an HTTP status into a bounded retry or terminal bucket.
  """
  @spec classify_http_status(integer()) :: http_classification()
  def classify_http_status(status) when is_integer(status) and status >= 500 and status <= 599 do
    %{retryable: true, error_category: "http_server_error", terminal_reason: nil}
  end

  def classify_http_status(429) do
    %{retryable: true, error_category: "http_backpressure", terminal_reason: nil}
  end

  def classify_http_status(408) do
    %{retryable: true, error_category: "http_timeout", terminal_reason: nil}
  end

  def classify_http_status(status) when is_integer(status) and status >= 400 and status <= 499 do
    %{retryable: false, error_category: "http_client_error", terminal_reason: "http_4xx_permanent"}
  end

  def classify_http_status(status) when is_integer(status) do
    %{retryable: false, error_category: "http_unexpected_status", terminal_reason: "unexpected_http_status"}
  end

  @doc """
  Classifies transport-layer requester failures into bounded retry buckets.
  """
  @spec classify_transport_error(term()) :: http_classification()
  def classify_transport_error(reason) do
    cond do
      timeout_reason?(reason) ->
        %{retryable: true, error_category: "transport_timeout", terminal_reason: nil}

      true ->
        %{retryable: true, error_category: "transport_error", terminal_reason: nil}
    end
  end

  @doc """
  Classifies local invariant failures that should never consume retry budget.
  """
  @spec classify_local_failure(atom()) :: local_classification()
  def classify_local_failure(:delivery_dependency_missing) do
    %{retryable: false, error_category: "local_state_error", terminal_reason: "delivery_dependency_missing"}
  end

  def classify_local_failure(:subscription_disabled) do
    %{retryable: false, error_category: "local_configuration_error", terminal_reason: "subscription_disabled"}
  end

  def classify_local_failure(:invalid_signing_secret) do
    %{retryable: false, error_category: "local_configuration_error", terminal_reason: "invalid_signing_secret"}
  end

  def classify_local_failure(:invalid_payload) do
    %{retryable: false, error_category: "local_state_error", terminal_reason: "invalid_payload"}
  end

  def classify_local_failure(:webhooks_disabled) do
    %{retryable: false, error_category: "local_configuration_error", terminal_reason: "webhooks_disabled"}
  end

  def classify_local_failure(:missing_delivery_id) do
    %{retryable: false, error_category: "local_state_error", terminal_reason: "missing_delivery_id"}
  end

  def classify_local_failure({:local_policy_error, reason, detail})
      when is_atom(reason) and is_binary(detail) do
    %{
      retryable: false,
      error_category: "local_policy_error",
      terminal_reason: Atom.to_string(reason),
      error_detail: detail
    }
  end

  def classify_local_failure(reason) when is_atom(reason) do
    %{retryable: false, error_category: "local_state_error", terminal_reason: Atom.to_string(reason)}
  end

  @doc """
  Returns the next scheduled attempt after `attempt_number`, honoring a
  longer `Retry-After` delay without expanding the attempt budget.
  """
  @spec next_attempt(pos_integer(), DateTime.t(), keyword()) :: {:ok, next_attempt()} | :exhausted
  def next_attempt(attempt_number, attempted_at, opts \\ [])

  def next_attempt(attempt_number, %DateTime{} = attempted_at, opts)
      when is_integer(attempt_number) and attempt_number >= 1 and is_list(opts) do
    with {:ok, nominal_delay_seconds} <- nominal_delay_seconds(attempt_number) do
      retry_after_seconds = Keyword.get(opts, :retry_after_seconds)
      delay_seconds = max(nominal_delay_seconds, normalize_retry_after_seconds(retry_after_seconds))

      {:ok,
       %{
         attempt_number: attempt_number + 1,
         scheduled_at: DateTime.add(attempted_at, delay_seconds, :second),
         delay_seconds: delay_seconds,
         nominal_delay_seconds: nominal_delay_seconds,
         retry_after_seconds: retry_after_seconds
       }}
    else
      :exhausted -> :exhausted
    end
  end

  def next_attempt(_attempt_number, _attempted_at, _opts), do: :exhausted

  @doc """
  Parses a `Retry-After` header value into a positive second delay.
  """
  @spec parse_retry_after(binary() | nil, DateTime.t()) :: {:ok, pos_integer()} | :error
  def parse_retry_after(nil, %DateTime{}), do: :error

  def parse_retry_after(value, %DateTime{} = now) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" ->
        :error

      true ->
        case Integer.parse(trimmed) do
          {seconds, ""} when seconds > 0 ->
            {:ok, seconds}

          _other ->
            parse_retry_after_http_date(trimmed, now)
        end
    end
  end

  def parse_retry_after(_value, _now), do: :error

  defp nominal_delay_seconds(attempt_number) do
    case Enum.fetch(@retry_schedule_seconds, attempt_number - 1) do
      {:ok, seconds} -> {:ok, seconds}
      :error -> :exhausted
    end
  end

  defp normalize_retry_after_seconds(seconds) when is_integer(seconds) and seconds > 0, do: seconds
  defp normalize_retry_after_seconds(_seconds), do: 0

  defp parse_retry_after_http_date(value, %DateTime{} = now) do
    with {:ok, datetime} <- http_date_to_datetime(value) do
      delay_seconds = max(DateTime.diff(datetime, now, :second), 0)

      if delay_seconds > 0, do: {:ok, delay_seconds}, else: :error
    else
      _error -> :error
    end
  end

  defp http_date_to_datetime(value) do
    case :httpd_util.convert_request_date(String.to_charlist(value)) do
      {{year, month, day}, {hour, minute, second}} ->
        with {:ok, naive} <- NaiveDateTime.new(year, month, day, hour, minute, second) do
          {:ok, DateTime.from_naive!(naive, "Etc/UTC")}
        else
          _error -> :error
        end

      _other ->
        :error
    end
  rescue
    _error -> :error
  end

  defp timeout_reason?(reason) do
    text = inspect(reason)
    String.contains?(text, "timeout")
  end
end
