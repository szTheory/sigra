defmodule <%= web_module %>.AppLoginContinuation do
  @moduledoc false

  import Plug.Conn

  @session_key :sigra_app_login_continuation
  @purpose "sigra-app-login-continuation-v1"
  @max_age 300

  # The session contains only this signed handle, never ceremony parameters or credentials.
  def put(conn, continuation, profile_id) when is_binary(continuation) and is_binary(profile_id) do
    put_session(conn, @session_key, Phoenix.Token.sign(conn, @purpose, %{continuation: continuation, profile_id: profile_id}))
  end

  def fetch(conn) do
    with handle when is_binary(handle) <- get_session(conn, @session_key),
         {:ok, %{continuation: continuation, profile_id: profile_id}} <- Phoenix.Token.verify(conn, @purpose, handle, max_age: @max_age),
         true <- is_binary(continuation) do
      {:ok, continuation, profile_id}
    else
      _ -> {:error, :invalid_continuation}
    end
  end

  def take(conn) do
    result = fetch(conn)
    {delete_session(conn, @session_key), result}
  end

  def preserve(conn), do: get_session(conn, @session_key)

  def restore(conn, handle) when is_binary(handle), do: put_session(conn, @session_key, handle)
  def restore(conn, _handle), do: conn
end
