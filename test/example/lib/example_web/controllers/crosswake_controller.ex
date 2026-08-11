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
        recovery(conn, "Your sign-in session is no longer available. Please sign in again.")
    end
  end

  def return(conn, params) do
    with {:ok, %{"continuation" => handle} = input} <- scalar_return_input(params),
         {:allow, _result} <-
           CrosswakeContinuations.complete(
             handle,
             get_session(conn, :user_token),
             Map.delete(input, "continuation"),
             DateTime.utc_now()
           ) do
      conn
      |> put_status(:see_other)
      |> redirect(to: CrosswakeContinuations.destination())
    else
      _ -> recovery(conn, "We couldn't complete that return. Please try again.")
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

  defp recovery(conn, message) do
    conn
    |> put_flash(:error, message)
    |> put_status(:see_other)
    |> redirect(to: "/users/log_in")
  end
end
