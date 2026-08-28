defmodule ExampleWeb.AppLoginContinuation do
  @moduledoc false
  import Plug.Conn

  @session_key :sigra_app_login_continuation

  def put(conn, continuation, profile_id) when is_binary(continuation) and is_binary(profile_id),
    do: put_session(conn, @session_key, %{continuation: continuation, profile_id: profile_id})

  def fetch(conn) do
    with %{continuation: continuation, profile_id: profile_id} <- get_session(conn, @session_key),
         true <- is_binary(continuation) and is_binary(profile_id) do
      {:ok, continuation, profile_id}
    else
      _ -> {:error, :invalid_continuation}
    end
  end

  def take(conn), do: {delete_session(conn, @session_key), fetch(conn)}
  def clear(conn), do: delete_session(conn, @session_key)
  def preserve(conn), do: get_session(conn, @session_key)

  def restore(conn, %{continuation: continuation, profile_id: profile_id} = handle)
      when is_binary(continuation) and is_binary(profile_id),
      do: put_session(conn, @session_key, handle)

  def restore(conn, _handle), do: conn
end
