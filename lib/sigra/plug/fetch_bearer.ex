defmodule Sigra.Plug.FetchBearer do
  @moduledoc """
  Extracts a bearer token from the `Authorization` header and assigns `current_scope`.

  This plug reads the `Authorization` header, parses the `Bearer <token>` format,
  verifies the token via the configured token verifier, and assigns the resulting
  scope to `conn.assigns.current_scope`.

  If no header is present, the format is wrong, or verification fails,
  `current_scope` is assigned as `nil`.

  ## Options

    * `:token_verifier` - Module implementing the token verifier interface
      (must export `verify/2`).

  ## Example

      plug Sigra.Plug.FetchBearer,
        token_verifier: MyApp.APITokenVerifier

  """

  @behaviour Plug

  @doc """
  Initialize the plug with the given options.
  """
  @doc since: "0.1.0"
  @impl Plug
  def init(opts), do: opts

  @doc """
  Extract bearer token from Authorization header and assign `current_scope`.
  """
  @doc since: "0.1.0"
  @impl Plug
  def call(conn, opts) do
    token_verifier = Keyword.fetch!(opts, :token_verifier)

    case extract_bearer_token(conn) do
      {:ok, token} ->
        case token_verifier.verify(token, opts) do
          {:ok, scope} -> Plug.Conn.assign(conn, :current_scope, scope)
          {:error, _reason} -> Plug.Conn.assign(conn, :current_scope, nil)
        end

      :error ->
        Plug.Conn.assign(conn, :current_scope, nil)
    end
  end

  defp extract_bearer_token(conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> :error
    end
  end
end
