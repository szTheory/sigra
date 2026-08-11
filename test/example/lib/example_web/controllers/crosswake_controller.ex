defmodule ExampleWeb.CrosswakeController do
  use ExampleWeb, :controller

  alias Example.Accounts.CrosswakeContinuations

  @allowed_return_keys ["continuation", "state", "pkce_verifier"]

  def start(conn, _params) do
    case CrosswakeContinuations.issue(get_session(conn, :user_token), DateTime.utc_now()) do
      {:ok, values} ->
        query = %{
          "continuation" => values.handle,
          "state" => values.state,
          "pkce_verifier" => values.pkce_verifier
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
      {:ok, %{"continuation" => handle} = input} ->
        complete_return(conn, handle, Map.delete(input, "continuation"))

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

  defp complete_return(conn, handle, input) do
    case get_session(conn, :user_token) do
      token when is_binary(token) ->
        case CrosswakeContinuations.complete(handle, token, input, DateTime.utc_now()) do
          {:allow, _result} -> allow(conn)
          {:deny, %{reason: reason}} -> deny(conn, reason)
        end

      _ ->
        deny(conn, :session_unavailable)
    end
  end

  defp allow(conn) do
    telemetry(:allow, :allowed)

    conn
    |> put_status(:see_other)
    |> redirect(to: CrosswakeContinuations.destination())
  end

  defp deny(conn, :session_unavailable) do
    telemetry(:deny, :session_unavailable)
    recovery(conn, "/users/log_in", "Your sign-in session is no longer available. Please sign in again.")
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
