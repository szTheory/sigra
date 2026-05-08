defmodule Sigra.Webhooks.Signature do
  @moduledoc """
  Signing and verification helpers for Sigra's outbound webhook contract.

  Each delivery carries:

  - `Sigra-Webhook-Id`
  - `Sigra-Webhook-Timestamp`
  - `Sigra-Webhook-Signature`

  The signature input is the exact string `delivery_id.timestamp.raw_body`,
  where `raw_body` is the exact byte sequence sent on the wire.
  """

  alias Sigra.Token

  @id_header "Sigra-Webhook-Id"
  @timestamp_header "Sigra-Webhook-Timestamp"
  @signature_header "Sigra-Webhook-Signature"
  @signature_version "v1"
  @default_tolerance 300

  @type verify_error ::
          :missing_id
          | :missing_timestamp
          | :missing_signature
          | :invalid_timestamp
          | :stale_timestamp
          | :malformed_signature
          | :invalid_signature

  @doc """
  Returns the fixed header names for Sigra webhook delivery.
  """
  @spec header_names() :: %{id: String.t(), timestamp: String.t(), signature: String.t()}
  def header_names do
    %{id: @id_header, timestamp: @timestamp_header, signature: @signature_header}
  end

  @doc """
  Builds the canonical `delivery_id.timestamp.raw_body` string.
  """
  @spec canonical_string(String.t(), String.t() | integer(), binary()) :: binary()
  def canonical_string(delivery_id, timestamp, raw_body)
      when is_binary(delivery_id) and is_binary(raw_body) do
    IO.iodata_to_binary([delivery_id, ".", normalize_timestamp!(timestamp), ".", raw_body])
  end

  @doc """
  Signs the canonical string and returns the versioned header value.
  """
  @spec sign(String.t(), String.t() | integer(), binary(), binary()) :: String.t()
  def sign(delivery_id, timestamp, raw_body, secret)
      when is_binary(delivery_id) and is_binary(raw_body) and is_binary(secret) do
    digest =
      canonical_string(delivery_id, timestamp, raw_body)
      |> then(&:crypto.mac(:hmac, :sha256, secret, &1))
      |> Base.encode16(case: :lower)

    "#{@signature_version}=#{digest}"
  end

  @doc """
  Builds the outbound signature headers for a delivery.
  """
  @spec headers(String.t(), binary(), binary() | [binary()], keyword()) :: %{String.t() => String.t()}
  def headers(delivery_id, raw_body, secret_or_secrets, opts \\ [])
      when is_binary(delivery_id) and is_binary(raw_body) and is_list(opts) do
    timestamp = Keyword.get(opts, :timestamp, System.os_time(:second)) |> normalize_timestamp!()

    signature_value =
      secret_or_secrets
      |> List.wrap()
      |> Enum.filter(&(is_binary(&1) and &1 != ""))
      |> Enum.map(&sign(delivery_id, timestamp, raw_body, &1))
      |> Enum.join(", ")

    %{
      @id_header => delivery_id,
      @timestamp_header => timestamp,
      @signature_header => signature_value
    }
  end

  @doc """
  Verifies signed webhook headers against the exact raw body bytes.

  Accepts either a single secret or a list of candidate secrets to support
  rotation overlap windows on the receiver side.
  """
  @spec verify(map() | keyword() | [{term(), term()}], binary(), binary() | [binary()], keyword()) ::
          {:ok, %{delivery_id: String.t(), timestamp: integer()}} | {:error, verify_error()}
  def verify(headers, raw_body, secret_or_secrets, opts \\ [])
      when is_binary(raw_body) and is_list(opts) do
    with {:ok, delivery_id} <- fetch_header(headers, @id_header, :missing_id),
         {:ok, timestamp_header} <- fetch_header(headers, @timestamp_header, :missing_timestamp),
         {:ok, timestamp} <- parse_timestamp(timestamp_header),
         :ok <- verify_tolerance(timestamp, opts),
         {:ok, signatures} <- fetch_signatures(headers),
         true <-
           valid_signature?(
             delivery_id,
             timestamp_header,
             raw_body,
             secret_or_secrets,
             signatures
           ) do
      {:ok, %{delivery_id: delivery_id, timestamp: timestamp}}
    else
      false -> {:error, :invalid_signature}
      {:error, _reason} = error -> error
    end
  end

  defp verify_tolerance(timestamp, opts) do
    tolerance = Keyword.get(opts, :tolerance, @default_tolerance)
    now = Keyword.get(opts, :now, System.os_time(:second)) |> normalize_now!()

    if abs(now - timestamp) <= tolerance do
      :ok
    else
      {:error, :stale_timestamp}
    end
  end

  defp valid_signature?(delivery_id, timestamp, raw_body, secret_or_secrets, signatures) do
    secrets =
      secret_or_secrets
      |> List.wrap()
      |> Enum.filter(&is_binary/1)

    Enum.any?(secrets, fn secret ->
      expected = sign(delivery_id, timestamp, raw_body, secret)
      Enum.any?(signatures, &Token.secure_compare(expected, &1))
    end)
  end

  defp fetch_signatures(headers) do
    with {:ok, raw_value} <- fetch_header(headers, @signature_header, :missing_signature) do
      raw_value
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))
      |> Enum.reduce_while([], fn candidate, acc ->
        case parse_signature(candidate) do
          {:ok, value} -> {:cont, [value | acc]}
          :error -> {:halt, :error}
        end
      end)
      |> case do
        :error -> {:error, :malformed_signature}
        [] -> {:error, :malformed_signature}
        values -> {:ok, Enum.reverse(values)}
      end
    end
  end

  defp parse_signature(<<"v1=", digest::binary>>) do
    if byte_size(digest) == 64 and digest =~ ~r/\A[0-9a-fA-F]+\z/ do
      {:ok, "v1=" <> String.downcase(digest)}
    else
      :error
    end
  end

  defp parse_signature(_candidate), do: :error

  defp fetch_header(headers, target, missing_reason) do
    target_downcase = String.downcase(target)

    value =
      headers
      |> normalize_headers()
      |> Enum.find_value(fn {key, value} ->
        if String.downcase(key) == target_downcase and is_binary(value) and value != "" do
          value
        end
      end)

    if is_binary(value), do: {:ok, value}, else: {:error, missing_reason}
  end

  defp normalize_headers(headers) when is_map(headers) do
    Enum.map(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize_headers(headers) when is_list(headers) do
    Enum.flat_map(headers, fn
      {key, value} -> [{to_string(key), to_string(value)}]
      _other -> []
    end)
  end

  defp normalize_headers(_headers), do: []

  defp parse_timestamp(timestamp) when is_integer(timestamp) and timestamp >= 0,
    do: {:ok, timestamp}

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case Integer.parse(timestamp) do
      {value, ""} when value >= 0 -> {:ok, value}
      _other -> {:error, :invalid_timestamp}
    end
  end

  defp parse_timestamp(_timestamp), do: {:error, :invalid_timestamp}

  defp normalize_timestamp!(timestamp) when is_integer(timestamp) and timestamp >= 0,
    do: Integer.to_string(timestamp)

  defp normalize_timestamp!(timestamp) when is_binary(timestamp) do
    case parse_timestamp(timestamp) do
      {:ok, value} -> Integer.to_string(value)
      {:error, _reason} -> raise ArgumentError, "webhook timestamp must be a non-negative integer"
    end
  end

  defp normalize_timestamp!(_timestamp) do
    raise ArgumentError, "webhook timestamp must be a non-negative integer"
  end

  defp normalize_now!(%DateTime{} = now), do: DateTime.to_unix(now)
  defp normalize_now!(now) when is_integer(now), do: now

  defp normalize_now!(now) when is_binary(now) do
    case Integer.parse(now) do
      {value, ""} -> value
      _other -> raise ArgumentError, "webhook verification :now must be a unix timestamp"
    end
  end

  defp normalize_now!(_now) do
    raise ArgumentError, "webhook verification :now must be a unix timestamp"
  end
end
