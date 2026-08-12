defmodule Sigra.Plug.FetchAppSession do
  @moduledoc """
  Explicit app-session pipeline foundation.

  Phase 243 establishes this public credential-selection seam only. App-session
  authentication remains fail closed until Phase 245 provides its configured
  verifier and storage contract. This Plug does not parse credentials, call
  another credential pipeline, or write credential state.
  """

  @behaviour Plug

  @impl Plug
  def init(opts) do
    _ = Keyword.fetch!(opts, :config)
    _ = Keyword.fetch!(opts, :scope_module)
    opts
  end

  @impl Plug
  def call(conn, _opts) do
    if conn.assigns[:current_scope] do
      conn
    else
      Plug.Conn.assign(conn, :current_scope, nil)
    end
  end
end
