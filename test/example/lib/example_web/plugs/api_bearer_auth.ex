defmodule ExampleWeb.Plugs.ApiBearerAuth do
  @moduledoc false

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> Sigra.Plug.FetchBearer.call(
      config: Example.Accounts.sigra_config(),
      scope_module: Example.Accounts.Scope
    )
    |> Sigra.Plug.RequireAuthenticated.call(error_handler: ExampleWeb.AuthErrorHandler)
  end
end
