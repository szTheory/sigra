defmodule <%= web_module %>.AppLoginContinuation do
  @moduledoc false

  import Plug.Conn

  @session_key :sigra_app_login_continuation
  # The session holds the existing Sigra-signed ceremony handle and its bounded
  # public profile label. Phoenix's normal signed/encrypted session protects this
  # map across session renewal; the ceremony handle remains Sigra's sole signature.
  def put(conn, continuation, profile_id) when is_binary(continuation) and is_binary(profile_id) do
    put_session(conn, @session_key, %{continuation: continuation, profile_id: profile_id})
  end

  def fetch(conn) do
    with %{continuation: continuation, profile_id: profile_id} <- get_session(conn, @session_key),
         true <- is_binary(continuation) and is_binary(profile_id) do
      {:ok, continuation, profile_id}
    else
      _ -> {:error, :invalid_continuation}
    end
  end

  def take(conn) do
    result = fetch(conn)
    {delete_session(conn, @session_key), result}
  end

  def clear(conn), do: delete_session(conn, @session_key)

  def continue_path(_endpoint, %{continuation: continuation, profile_id: profile_id}, fallback)
      when is_binary(continuation) and is_binary(profile_id),
      do: "/users/app-login/continue"

  def continue_path(_endpoint, _handle, fallback), do: fallback

  def preserve(conn), do: get_session(conn, @session_key)

  def restore(conn, %{continuation: continuation, profile_id: profile_id} = handle)
      when is_binary(continuation) and is_binary(profile_id),
      do: put_session(conn, @session_key, handle)

  def restore(conn, _handle), do: conn
end
