defmodule ExampleWeb.CrosswakeController do
  use ExampleWeb, :controller

  alias Example.Accounts.CrosswakeContinuations

  @allowed_return_keys ["continuation", "state"]
  @transport_key :crosswake_pkce

  def start(conn, _params) do
    case CrosswakeContinuations.issue(get_session(conn, :user_token), DateTime.utc_now()) do
      {:ok, values} ->
        conn = store_transport(conn, values)

        query = %{
          "continuation" => values.handle,
          "state" => values.state
        }

        conn
        |> put_status(:see_other)
        |> redirect(to: "/crosswake/return?" <> URI.encode_query(query))

      {:error, _reason} ->
        deny(conn, :session_unavailable)
    end
  end

  def return(conn, params) do
    conn = put_resp_header(conn, "referrer-policy", "no-referrer")

    case scalar_return_input(params) do
      {:ok, %{"continuation" => handle, "state" => state}} ->
        complete_return(conn, handle, state)

      {:error, _reason} ->
        deny(conn, :invalid_return_evidence)
    end
  end

  defp scalar_return_input(params) when is_map(params) do
    input = Map.take(params, @allowed_return_keys)

    if Map.keys(params) |> Enum.sort() == Enum.sort(@allowed_return_keys) and
         Enum.all?(input, fn {_key, value} -> is_binary(value) and value != "" end) do
      {:ok, input}
    else
      {:error, :invalid_return_input}
    end
  end

  defp complete_return(conn, handle, state) do
    now = DateTime.utc_now()
    {conn, transport} = take_transport(conn, handle, now)

    case transport do
      %{handle: bound_handle, verifier: verifier, expires_at: %DateTime{} = expires_at}
      when is_binary(verifier) ->
        if secure_match?(handle, bound_handle) and DateTime.compare(now, expires_at) == :lt do
          complete_with_transport(conn, handle, state, verifier, now)
        else
          deny(conn, :invalid_return_evidence)
        end

      _ ->
        deny(conn, :invalid_return_evidence)
    end
  end

  defp complete_with_transport(conn, handle, state, verifier, now) do
    case get_session(conn, :user_token) do
      token when is_binary(token) ->
        case CrosswakeContinuations.complete(
               handle,
               token,
               %{"state" => state, "pkce_verifier" => verifier},
               now
             ) do
          {:allow, _result} -> allow(conn)
          {:deny, %{reason: reason}} -> deny(conn, reason)
        end

      _ ->
        deny(conn, :session_unavailable)
    end
  end

  defp store_transport(conn, %{handle: handle, pkce_verifier: verifier, expires_at: expires_at}) do
    entries = session_entries(conn)

    put_session(
      conn,
      @transport_key,
      Map.put(entries, handle, %{handle: handle, verifier: verifier, expires_at: expires_at})
    )
  end

  defp take_transport(conn, handle, now) do
    case get_session(conn, @transport_key) do
      entries when is_map(entries) ->
        entries = prune_expired(entries, now)
        {transport, entries} = Map.pop(entries, handle)
        {put_session(conn, @transport_key, entries), transport}

      _ ->
        {delete_session(conn, @transport_key), nil}
    end
  end

  defp session_entries(conn) do
    case get_session(conn, @transport_key) do
      entries when is_map(entries) -> entries
      _ -> %{}
    end
  end

  defp prune_expired(entries, now) do
    Enum.reduce(entries, %{}, fn
      {handle, %{expires_at: %DateTime{} = expires_at} = entry}, kept
      when is_binary(handle) ->
        if DateTime.compare(now, expires_at) == :lt, do: Map.put(kept, handle, entry), else: kept

      _, kept ->
        kept
    end)
  end

  defp secure_match?(left, right) when is_binary(left) and is_binary(right),
    do: byte_size(left) == byte_size(right) and Plug.Crypto.secure_compare(left, right)

  defp secure_match?(_, _), do: false

  defp allow(conn) do
    telemetry(:allow, :allowed)

    conn
    |> put_status(:see_other)
    |> redirect(to: CrosswakeContinuations.destination())
  end

  defp deny(conn, :session_unavailable) do
    telemetry(:deny, :session_unavailable)

    recovery(
      conn,
      "/users/log_in",
      "Your sign-in session is no longer available. Please sign in again."
    )
  end

  defp deny(conn, reason) do
    telemetry(:deny, reason)
    recovery(conn, "/", "We couldn't complete that return. Please try again.")
  end

  defp recovery(conn, destination, message) do
    conn
    |> put_flash(:error, message)
    |> put_status(:see_other)
    |> redirect(to: destination)
  end

  defp telemetry(outcome, reason) do
    :telemetry.execute(
      [:example, :crosswake, :continuation],
      %{count: 1},
      %{correlation_ref: nil, outcome: outcome, reason: reason}
    )
  end
end
