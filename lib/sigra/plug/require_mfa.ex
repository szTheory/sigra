defmodule Sigra.Plug.RequireMFA do
  @moduledoc """
  MFA session gate plug.

  Checks the session type from `conn.private[:sigra_session]`. If the session
  type is `:mfa_pending`, redirects to the MFA challenge page and halts.
  Standard and remember_me sessions pass through.

  This plug must come AFTER `Sigra.Plug.RequireAuthenticated` in the pipeline.
  The ordering is: FetchSession -> RequireAuthenticated -> RequireMFA.

  ## Options

    * `:mfa_path` - Path to the MFA challenge page. Default: `"/users/mfa"`.
    * `:logout_path` - Path to the logout endpoint. Default: `"/users/log_out"`.

  ## Example

      plug Sigra.Plug.RequireMFA, mfa_path: "/users/mfa"

  """

  @behaviour Plug

  @default_mfa_path "/users/mfa"
  @default_logout_path "/users/log_out"

  @doc """
  Initialize the plug with the given options.

  Sets default `:mfa_path` to `"/users/mfa"` and `:logout_path` to
  `"/users/log_out"` if not provided.
  """
  @doc since: "0.6.0"
  @impl Plug
  def init(opts) do
    opts
    |> Keyword.put_new(:mfa_path, @default_mfa_path)
    |> Keyword.put_new(:logout_path, @default_logout_path)
  end

  @doc """
  Check session type and redirect if MFA verification is pending.

  If the session type is `:mfa_pending`, only the MFA challenge path and
  logout path are allowed. All other paths redirect to `:mfa_path`.
  If no session exists, the request passes through (unauthenticated requests
  are handled by `RequireAuthenticated`).
  """
  @doc since: "0.6.0"
  @impl Plug
  def call(conn, opts) do
    mfa_path = Keyword.fetch!(opts, :mfa_path)
    logout_path = Keyword.fetch!(opts, :logout_path)

    case conn.private[:sigra_session] do
      %Sigra.Session{type: :mfa_pending} ->
        if conn.request_path in [mfa_path, logout_path] do
          conn
        else
          conn
          |> Phoenix.Controller.redirect(to: mfa_path)
          |> Plug.Conn.halt()
        end

      _ ->
        conn
    end
  end
end
