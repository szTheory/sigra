defmodule Sigra.Plug.RequireScopes do
  @moduledoc """
  Route-level scope enforcement plug for API token authentication.

  Checks that the current connection's scope (from `conn.assigns.current_scope`)
  has the required scopes. Session-authenticated users bypass scope checks entirely.

  ## Options

  - `:scopes` (required) - A non-empty list of required scope strings
  - `:error_handler` (required) - Module implementing `Sigra.Plug.ErrorHandler`
  - `:match` - `:all` (default) requires all scopes, `:any` requires at least one

  ## Examples

      # Require all listed scopes (AND mode, default)
      plug Sigra.Plug.RequireScopes,
        scopes: ["profile:read", "sessions:read"],
        error_handler: MyAppWeb.AuthErrorHandler

      # Require any listed scope (OR mode)
      plug Sigra.Plug.RequireScopes,
        scopes: ["admin:write", "profile:write"],
        error_handler: MyAppWeb.AuthErrorHandler,
        match: :any

  ## Session Bypass

  When `auth_method` is `:session`, the plug passes the connection through
  without checking scopes. This enables a unified pipeline where browser
  sessions and API tokens share the same routes.
  """

  @behaviour Plug

  @doc """
  Initialize the plug with the given options.

  Validates that `:scopes` is a non-empty list and `:error_handler` is present.
  """
  @doc since: "0.7.0"
  @impl Plug
  def init(opts) do
    scopes = Keyword.fetch!(opts, :scopes)

    unless is_list(scopes) and scopes != [] do
      raise ArgumentError, "RequireScopes :scopes must be a non-empty list"
    end

    _ = Keyword.fetch!(opts, :error_handler)
    opts
  end

  @doc """
  Check scope requirements and halt if insufficient.
  """
  @doc since: "0.7.0"
  @impl Plug
  def call(conn, opts) do
    required = Keyword.fetch!(opts, :scopes)
    match_mode = Keyword.get(opts, :match, :all)
    error_handler = Keyword.fetch!(opts, :error_handler)
    scope = conn.assigns[:current_scope]

    cond do
      is_nil(scope) ->
        conn
        |> error_handler.auth_error(:unauthenticated, opts)
        |> Plug.Conn.halt()

      # Session users bypass scope checks (D-21)
      scope_auth_method(scope) == :session ->
        conn

      # Wildcard passes all
      scope_has_wildcard?(scope) ->
        conn

      has_required_scopes?(scope, required, match_mode) ->
        conn

      true ->
        error_opts =
          Keyword.merge(opts,
            required_scopes: required,
            provided_scopes: scope_token_scopes(scope)
          )

        conn
        |> error_handler.auth_error(:insufficient_scope, error_opts)
        |> Plug.Conn.halt()
    end
  end

  defp scope_auth_method(scope), do: Map.get(scope, :auth_method)

  defp scope_token_scopes(scope), do: Map.get(scope, :token_scopes, [])

  defp scope_has_wildcard?(scope) do
    "*" in scope_token_scopes(scope)
  end

  defp has_required_scopes?(scope, required, :all) do
    token_scopes = MapSet.new(scope_token_scopes(scope))
    MapSet.subset?(MapSet.new(required), token_scopes)
  end

  defp has_required_scopes?(scope, required, :any) do
    token_scopes = scope_token_scopes(scope)
    Enum.any?(required, &(&1 in token_scopes))
  end
end
